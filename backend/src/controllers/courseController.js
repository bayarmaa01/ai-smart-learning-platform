const { query, transaction } = require('../db/connection');
const { getCache, setCache, deleteCache, deleteCachePattern } = require('../cache/redis');
const { AppError } = require('../middleware/errorHandler');
const { v4: uuidv4 } = require('uuid');

const getCourses = async (req, res) => {
  const {
    page = 1, limit = 12, search, category, level,
    sortBy = 'popular', minPrice, maxPrice, language,
  } = req.query;

  const offset = (page - 1) * limit;
  const params = [];
  const conditions = ["c.status = 'published'"];

  if (req.tenantId) {
    params.push(req.tenantId);
    conditions.push(`c.tenant_id = $${params.length}`);
  }

  if (search) {
    params.push(`%${search}%`);
    conditions.push(`(c.title ILIKE $${params.length} OR c.short_description ILIKE $${params.length})`);
  }

  if (category) {
    params.push(category);
    conditions.push(`cat.slug = $${params.length}`);
  }

  if (level) {
    params.push(level);
    conditions.push(`c.level = $${params.length}`);
  }

  if (language) {
    params.push(language);
    conditions.push(`c.language = $${params.length}`);
  }

  if (minPrice !== undefined) {
    params.push(parseFloat(minPrice));
    conditions.push(`c.price >= $${params.length}`);
  }

  if (maxPrice !== undefined) {
    params.push(parseFloat(maxPrice));
    conditions.push(`c.price <= $${params.length}`);
  }

  const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

  const orderMap = {
    popular: 'c.enrollment_count DESC',
    rating: 'c.rating_average DESC',
    newest: 'c.published_at DESC',
    price_asc: 'c.price ASC',
    price_desc: 'c.price DESC',
  };
  const orderBy = orderMap[sortBy] || orderMap.popular;

  const cacheKey = `courses:${JSON.stringify(req.query)}`;
  const cached = await getCache(cacheKey);
  if (cached) return res.json(cached);

  const [coursesResult, countResult] = await Promise.all([
    query(
      `SELECT c.id, c.title, c.short_description, c.thumbnail_url, c.level, c.language,
              c.price, c.discount_price, c.duration_hours, c.enrollment_count,
              c.rating_average, c.rating_count, c.is_free, c.tags, c.published_at,
              u.first_name || ' ' || u.last_name AS instructor_name,
              cat.name AS category_name, cat.slug AS category_slug
       FROM courses c
       LEFT JOIN users u ON c.instructor_id = u.id
       LEFT JOIN categories cat ON c.category_id = cat.id
       ${whereClause}
       ORDER BY ${orderBy}
       LIMIT $${params.length + 1} OFFSET $${params.length + 2}`,
      [...params, parseInt(limit), offset]
    ),
    query(
      `SELECT COUNT(*) FROM courses c
       LEFT JOIN categories cat ON c.category_id = cat.id
       ${whereClause}`,
      params
    ),
  ]);

  const total = parseInt(countResult.rows[0].count);
  const response = {
    success: true,
    courses: coursesResult.rows,
    total,
    page: parseInt(page),
    limit: parseInt(limit),
    totalPages: Math.ceil(total / limit),
  };

  await setCache(cacheKey, response, 300);
  res.json(response);
};

const getCourseById = async (req, res) => {
  const { id } = req.params;
  const cacheKey = `course:${id}`;
  const cached = await getCache(cacheKey);
  if (cached) {
    if (req.user) {
      const enrollment = await query(
        'SELECT id, progress_percentage FROM enrollments WHERE user_id = $1 AND course_id = $2',
        [req.user.id, id]
      );
      cached.course.isEnrolled = enrollment.rows.length > 0;
      cached.course.progress = enrollment.rows[0]?.progress_percentage || 0;
    }
    return res.json({ success: true, course: cached.course });
  }

  const result = await query(
    `SELECT c.*, u.first_name || ' ' || u.last_name AS instructor_name,
            u.avatar_url AS instructor_avatar, u.bio AS instructor_bio,
            cat.name AS category_name, cat.slug AS category_slug
     FROM courses c
     LEFT JOIN users u ON c.instructor_id = u.id
     LEFT JOIN categories cat ON c.category_id = cat.id
     WHERE c.id = $1`,
    [id]
  );

  if (!result.rows.length) {
    throw new AppError('Course not found', 404, 'COURSE_NOT_FOUND');
  }

  const course = result.rows[0];

  const sectionsResult = await query(
    `SELECT cs.id, cs.title, cs.sort_order,
            json_agg(json_build_object(
              'id', l.id, 'title', l.title, 'content_type', l.content_type,
              'video_duration', l.video_duration, 'is_free_preview', l.is_free_preview,
              'sort_order', l.sort_order
            ) ORDER BY l.sort_order) AS lessons
     FROM course_sections cs
     LEFT JOIN lessons l ON cs.id = l.section_id
     WHERE cs.course_id = $1
     GROUP BY cs.id, cs.title, cs.sort_order
     ORDER BY cs.sort_order`,
    [id]
  );

  course.curriculum = sectionsResult.rows;

  await setCache(cacheKey, { course }, 600);

  if (req.user) {
    const enrollment = await query(
      'SELECT id, progress_percentage FROM enrollments WHERE user_id = $1 AND course_id = $2',
      [req.user.id, id]
    );
    course.isEnrolled = enrollment.rows.length > 0;
    course.progress = enrollment.rows[0]?.progress_percentage || 0;
  }

  res.json({ success: true, course });
};

const enrollCourse = async (req, res) => {
  const { id: courseId } = req.params;
  const userId = req.user.id;

  const courseResult = await query(
    'SELECT id, price, is_free FROM courses WHERE id = $1 AND status = $2',
    [courseId, 'published']
  );

  if (!courseResult.rows.length) {
    throw new AppError('Course not found', 404, 'COURSE_NOT_FOUND');
  }

  const course = courseResult.rows[0];

  const existingEnrollment = await query(
    'SELECT id FROM enrollments WHERE user_id = $1 AND course_id = $2',
    [userId, courseId]
  );

  if (existingEnrollment.rows.length > 0) {
    throw new AppError('Already enrolled in this course', 409, 'ALREADY_ENROLLED');
  }

  if (course.price > 0 && !course.is_free) {
    throw new AppError('Payment required to enroll', 402, 'PAYMENT_REQUIRED');
  }

  await transaction(async (client) => {
    await client.query(
      'INSERT INTO enrollments (user_id, course_id) VALUES ($1, $2)',
      [userId, courseId]
    );
    await client.query(
      'UPDATE courses SET enrollment_count = enrollment_count + 1 WHERE id = $1',
      [courseId]
    );
  });

  await deleteCachePattern(`course:${courseId}*`);

  res.status(201).json({ success: true, message: 'Enrolled successfully' });
};

const getEnrolledCourses = async (req, res) => {
  const userId = req.user.id;

  const result = await query(
    `SELECT c.id, c.title, c.thumbnail_url, c.level, c.duration_hours,
            e.progress_percentage, e.enrolled_at, e.completed_at,
            u.first_name || ' ' || u.last_name AS instructor_name
     FROM enrollments e
     JOIN courses c ON e.course_id = c.id
     JOIN users u ON c.instructor_id = u.id
     WHERE e.user_id = $1
     ORDER BY e.last_accessed_at DESC NULLS LAST, e.enrolled_at DESC`,
    [userId]
  );

  res.json({ success: true, courses: result.rows });
};

const updateProgress = async (req, res) => {
  const { id: courseId } = req.params;
  const { lessonId, watchTimeSeconds, isCompleted } = req.body;
  const userId = req.user.id;

  await query(
    `INSERT INTO lesson_progress (user_id, lesson_id, course_id, is_completed, watch_time_seconds, completed_at)
     VALUES ($1, $2, $3, $4, $5, $6)
     ON CONFLICT (user_id, lesson_id) DO UPDATE SET
       is_completed = EXCLUDED.is_completed,
       watch_time_seconds = GREATEST(lesson_progress.watch_time_seconds, EXCLUDED.watch_time_seconds),
       completed_at = CASE WHEN EXCLUDED.is_completed THEN NOW() ELSE lesson_progress.completed_at END,
       updated_at = NOW()`,
    [userId, lessonId, courseId, isCompleted, watchTimeSeconds, isCompleted ? new Date() : null]
  );

  const progressResult = await query(
    `SELECT
       COUNT(DISTINCT lp.lesson_id) FILTER (WHERE lp.is_completed) AS completed,
       COUNT(DISTINCT l.id) AS total
     FROM lessons l
     LEFT JOIN lesson_progress lp ON l.id = lp.lesson_id AND lp.user_id = $1
     WHERE l.course_id = $2`,
    [userId, courseId]
  );

  const { completed, total } = progressResult.rows[0];
  const progressPct = total > 0 ? Math.round((completed / total) * 100) : 0;

  await query(
    `UPDATE enrollments SET progress_percentage = $1, last_accessed_at = NOW(),
     completed_at = CASE WHEN $1 = 100 THEN NOW() ELSE completed_at END
     WHERE user_id = $2 AND course_id = $3`,
    [progressPct, userId, courseId]
  );

  res.json({ success: true, progress: progressPct });
};

const getCourseProgress = async (req, res) => {
  const { id: courseId } = req.params;
  const userId = req.user.id;

  const result = await query(
    `SELECT lp.lesson_id, lp.is_completed, lp.watch_time_seconds, lp.last_position_seconds
     FROM lesson_progress lp
     WHERE lp.user_id = $1 AND lp.course_id = $2`,
    [userId, courseId]
  );

  const enrollment = await query(
    'SELECT progress_percentage FROM enrollments WHERE user_id = $1 AND course_id = $2',
    [userId, courseId]
  );

  res.json({
    success: true,
    progress: enrollment.rows[0]?.progress_percentage || 0,
    lessonProgress: result.rows,
  });
};

const createCourse = async (req, res) => {
  const {
    title, description, shortDescription, categoryId, level, price,
    language, whatYouLearn, requirements, tags,
  } = req.body;

  const slug = title.toLowerCase().replace(/[^a-z0-9]+/g, '-') + '-' + Date.now();

  const result = await query(
    `INSERT INTO courses (title, slug, description, short_description, category_id, level, price,
      language, what_you_learn, requirements, tags, instructor_id, tenant_id, is_free)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
     RETURNING id, title, slug, status`,
    [title, slug, description, shortDescription, categoryId, level, price || 0,
     language || 'en', JSON.stringify(whatYouLearn || []), JSON.stringify(requirements || []),
     JSON.stringify(tags || []), req.user.id, req.tenantId, price === 0]
  );

  res.status(201).json({ success: true, course: result.rows[0] });
};

const updateCourse = async (req, res) => {
  const { id } = req.params;

  const courseResult = await query('SELECT instructor_id FROM courses WHERE id = $1', [id]);
  if (!courseResult.rows.length) throw new AppError('Course not found', 404, 'COURSE_NOT_FOUND');

  if (req.user.role === 'instructor' && courseResult.rows[0].instructor_id !== req.user.id) {
    throw new AppError('Not authorized to update this course', 403, 'FORBIDDEN');
  }

  const fields = ['title', 'description', 'short_description', 'level', 'price', 'language', 'what_you_learn', 'requirements', 'tags'];
  const updates = [];
  const values = [];

  fields.forEach((field) => {
    const camelField = field.replace(/_([a-z])/g, (_, l) => l.toUpperCase());
    if (req.body[camelField] !== undefined) {
      values.push(typeof req.body[camelField] === 'object' ? JSON.stringify(req.body[camelField]) : req.body[camelField]);
      updates.push(`${field} = $${values.length}`);
    }
  });

  if (!updates.length) throw new AppError('No fields to update', 400, 'NO_UPDATES');

  values.push(id);
  const result = await query(
    `UPDATE courses SET ${updates.join(', ')}, updated_at = NOW() WHERE id = $${values.length} RETURNING id, title, status`,
    values
  );

  await deleteCachePattern(`course:${id}*`);
  res.json({ success: true, course: result.rows[0] });
};

const deleteCourse = async (req, res) => {
  const { id } = req.params;
  await query('UPDATE courses SET status = $1 WHERE id = $2', ['archived', id]);
  await deleteCachePattern(`course:${id}*`);
  res.json({ success: true, message: 'Course archived successfully' });
};

const publishCourse = async (req, res) => {
  const { id } = req.params;
  const result = await query(
    `UPDATE courses SET status = 'published', published_at = NOW() WHERE id = $1 RETURNING id, title, status`,
    [id]
  );
  if (!result.rows.length) throw new AppError('Course not found', 404, 'COURSE_NOT_FOUND');
  await deleteCachePattern(`course:${id}*`);
  res.json({ success: true, course: result.rows[0] });
};

module.exports = {
  getCourses, getCourseById, enrollCourse, getEnrolledCourses,
  updateProgress, getCourseProgress, createCourse, updateCourse,
  deleteCourse, publishCourse,
};
