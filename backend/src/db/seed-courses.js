const { Pool } = require('pg');
const { logger } = require('../utils/logger');

const NOW = 'NOW()';

const pool = new Pool({
  host: process.env.DB_HOST || 'postgres',
  port: parseInt(process.env.DB_PORT) || 5432,
  database: process.env.DB_NAME || 'eduai',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres123',
  ssl: false,
});

async function seedCoursesAndLessons() {
  try {
    logger.info('Starting to seed courses and lessons...');

    // Get instructor user
    const instructorResult = await pool.query(
      'SELECT id FROM users WHERE role = $1 LIMIT 1',
      ['instructor']
    );

    if (instructorResult.rows.length === 0) {
      // Create an instructor if none exists
      const bcrypt = require('bcrypt');
      const hashedPassword = await bcrypt.hash('instructor123', 12);
      
      const newInstructor = await pool.query(`
        INSERT INTO users (email, password_hash, first_name, last_name, role, tenant_id, is_active, is_email_verified)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        RETURNING id
      `, ['instructor@eduai.com', hashedPassword, 'John', 'Instructor', 'instructor', '00000000-0000-0000-0000-000000000001', true, true]);
      
      instructorResult.rows[0] = { id: newInstructor.rows[0].id };
    }

    const instructorId = instructorResult.rows[0].id;

    // Get categories
    const categoriesResult = await pool.query('SELECT id, name FROM categories LIMIT 3');
    
    // Create sample courses
    const courses = [
      {
        title: 'Introduction to Machine Learning',
        description: 'Learn the fundamentals of machine learning, including supervised and unsupervised learning, neural networks, and practical applications.',
        short_description: 'ML fundamentals for beginners',
        level: 'beginner',
        duration_hours: 20,
        category_id: categoriesResult.rows[0]?.id || null,
        instructor_id: instructorId
      },
      {
        title: 'Web Development with React',
        description: 'Master modern web development using React, including hooks, state management, and building production-ready applications.',
        short_description: 'Modern React development',
        level: 'intermediate',
        duration_hours: 25,
        category_id: categoriesResult.rows[1]?.id || null,
        instructor_id: instructorId
      },
      {
        title: 'DevOps Fundamentals',
        description: 'Learn DevOps practices including CI/CD, containerization with Docker, orchestration with Kubernetes, and infrastructure as code.',
        short_description: 'DevOps essentials',
        level: 'intermediate',
        duration_hours: 30,
        category_id: categoriesResult.rows[2]?.id || null,
        instructor_id: instructorId
      }
    ];

    const createdCourses = [];

    for (const course of courses) {
      const result = await pool.query(`
        INSERT INTO courses (title, slug, description, short_description, level, duration_hours, 
                           category_id, instructor_id, tenant_id, status, is_free, published_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, NOW())
        RETURNING id
      `, [
        course.title,
        course.title.toLowerCase().replace(/\s+/g, '-'),
        course.description,
        course.short_description,
        course.level,
        course.duration_hours,
        course.category_id,
        course.instructor_id,
        '00000000-0000-0000-0000-000000000001',
        'published',
        true,
        NOW()
      ]);

      createdCourses.push({ id: result.rows[0].id, title: course.title });
      logger.info(`Created course: ${course.title}`);
    }

    // Create lessons for each course
    for (const course of createdCourses) {
      const sections = await createCourseSections(course.id, course.title);
      await createLessonsForSections(course.id, sections);
    }

    // Enroll some test users in courses
    await enrollTestUsers(createdCourses);

    logger.info('Course and lesson seeding completed successfully');

  } catch (error) {
    logger.error('Failed to seed courses and lessons:', error);
    throw error;
  } finally {
    await pool.end();
  }
}

async function createCourseSections(courseId, courseTitle) {
  const sections = [
    { title: 'Introduction', description: `Getting started with ${courseTitle}` },
    { title: 'Core Concepts', description: 'Fundamental concepts and principles' },
    { title: 'Practical Examples', description: 'Hands-on examples and exercises' },
    { title: 'Advanced Topics', description: 'More advanced concepts and techniques' },
    { title: 'Conclusion', description: 'Summary and next steps' }
  ];

  const createdSections = [];

  for (let i = 0; i < sections.length; i++) {
    const result = await pool.query(`
      INSERT INTO course_sections (course_id, title, description, sort_order)
      VALUES ($1, $2, $3, $4)
      RETURNING id
    `, [courseId, sections[i].title, sections[i].description, i]);

    createdSections.push({ id: result.rows[0].id, title: sections[i].title });
  }

  return createdSections;
}

async function createLessonsForSections(courseId, sections) {
  for (const section of sections) {
    const lessonCount = section.title === 'Introduction' ? 2 : 3;
    
    for (let i = 1; i <= lessonCount; i++) {
      await pool.query(`
        INSERT INTO lessons (section_id, course_id, title, description, content_type, 
                              video_duration, sort_order, is_free_preview)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
      `, [
        section.id,
        courseId,
        `${section.title} - Lesson ${i}`,
        `Learn about ${section.title.toLowerCase()} in this comprehensive lesson`,
        'video',
        600 + (i * 300), // 10-20 minutes per lesson
        i - 1,
        i === 1 && section.title === 'Introduction' // First lesson of intro is free
      ]);
    }
  }
}

async function enrollTestUsers(courses) {
  // Get test users
  const usersResult = await pool.query(
    'SELECT id FROM users WHERE role = $1 LIMIT 3',
    ['student']
  );

  for (const user of usersResult.rows) {
    for (const course of courses) {
      try {
        await pool.query(`
          INSERT INTO enrollments (user_id, course_id, progress_percentage, enrolled_at)
          VALUES ($1, $2, $3, NOW())
          ON CONFLICT (user_id, course_id) DO NOTHING
        `, [user.id, course.id, Math.random() * 50]); // Random progress up to 50%
      } catch (error) {
        // Ignore duplicate enrollment errors
      }
    }
  }
}

// Run seeding if called directly
if (require.main === module) {
  seedCoursesAndLessons()
    .then(() => {
      logger.info('Course seeding completed');
      process.exit(0);
    })
    .catch((error) => {
      logger.error('Course seeding failed:', error);
      process.exit(1);
    });
}

module.exports = { seedCoursesAndLessons };
