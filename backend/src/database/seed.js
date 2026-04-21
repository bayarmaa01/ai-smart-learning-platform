const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');
const { query } = require('../config/database');
const logger = require('../utils/logger');

const seedData = async () => {
  try {
    logger.info('Starting database seeding...');
    
    // Clear existing data
    await query('DELETE FROM reviews');
    await query('DELETE FROM progress');
    await query('DELETE FROM chat_sessions');
    await query('DELETE FROM enrollments');
    await query('DELETE FROM lessons');
    await query('DELETE FROM courses');
    await query('DELETE FROM categories');
    await query('DELETE FROM users');

    // Hash passwords
    const adminPassword = await bcrypt.hash('Admin@1234', 12);
    const teacherPassword = await bcrypt.hash('Teacher@1234', 12);
    const studentPassword = await bcrypt.hash('Student@1234', 12);

    // Insert users
    const users = [
      {
        id: uuidv4(),
        email: 'admin@eduai.com',
        password_hash: adminPassword,
        first_name: 'Admin',
        last_name: 'User',
        role: 'admin',
        is_email_verified: true,
        is_active: true
      },
      {
        id: uuidv4(),
        email: 'teacher@eduai.com',
        password_hash: teacherPassword,
        first_name: 'Teacher',
        last_name: 'User',
        role: 'instructor',
        is_email_verified: true,
        is_active: true
      },
      {
        id: uuidv4(),
        email: 'student@eduai.com',
        password_hash: studentPassword,
        first_name: 'Student',
        last_name: 'User',
        role: 'student',
        is_email_verified: true,
        is_active: true
      }
    ];

    for (const user of users) {
      await query(`
        INSERT INTO users (id, email, password_hash, first_name, last_name, role, is_email_verified, is_active)
        VALUES ($1, $2, $3, $4, $5, $6, $7)
      `, [user.id, user.email, user.password_hash, user.first_name, user.last_name, user.role, user.is_email_verified, user.is_active]);
    }

    // Insert categories
    const categories = [
      {
        id: uuidv4(),
        name: 'Programming',
        slug: 'programming',
        description: 'Programming and development courses',
        icon: 'code',
        sort_order: 1
      },
      {
        id: uuidv4(),
        name: 'Data Science',
        slug: 'data-science',
        description: 'Data science and machine learning courses',
        icon: 'chart',
        sort_order: 2
      },
      {
        id: uuidv4(),
        name: 'Web Development',
        slug: 'web-development',
        description: 'Frontend and backend web development',
        icon: 'globe',
        sort_order: 3
      }
    ];

    for (const category of categories) {
      await query(`
        INSERT INTO categories (id, name, slug, description, icon, sort_order)
        VALUES ($1, $2, $3, $4, $5)
      `, [category.id, category.name, category.slug, category.description, category.icon, category.sort_order]);
    }

    // Get inserted users and categories for foreign key references
    const instructorResult = await query('SELECT id FROM users WHERE role = $1', ['instructor']);
    const instructorId = instructorResult.rows[0].id;

    const categoryResult = await query('SELECT id FROM categories WHERE slug = $1', ['programming']);
    const categoryId = categoryResult.rows[0].id;

    // Insert courses
    const courses = [
      {
        id: uuidv4(),
        instructor_id: instructorId,
        category_id: categoryId,
        title: 'Introduction to Web Development',
        slug: 'intro-web-dev',
        description: 'Learn the basics of web development with HTML, CSS, and JavaScript',
        short_description: 'Basic web development course',
        level: 'beginner',
        price: 0,
        duration_hours: 20,
        status: 'published',
        is_featured: true,
        is_free: true
      },
      {
        id: uuidv4(),
        instructor_id: instructorId,
        category_id: categoryId,
        title: 'Advanced JavaScript',
        slug: 'advanced-javascript',
        description: 'Master advanced JavaScript concepts and patterns',
        short_description: 'Advanced JavaScript programming',
        level: 'advanced',
        price: 99.99,
        duration_hours: 40,
        status: 'published',
        is_featured: true,
        is_free: false
      },
      {
        id: uuidv4(),
        instructor_id: instructorId,
        category_id: categoryId,
        title: 'React Development',
        slug: 'react-development',
        description: 'Build modern web applications with React',
        short_description: 'React framework course',
        level: 'intermediate',
        price: 79.99,
        duration_hours: 35,
        status: 'published',
        is_featured: false,
        is_free: false
      }
    ];

    for (const course of courses) {
      await query(`
        INSERT INTO courses (id, instructor_id, category_id, title, slug, description, short_description, level, price, duration_hours, status, is_featured, is_free)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
      `, [course.id, course.instructor_id, course.category_id, course.title, course.slug, course.description, course.short_description, course.level, course.price, course.duration_hours, course.status, course.is_featured, course.is_free]);
    }

    // Get courses for lessons
    const coursesResult = await query('SELECT id FROM courses');
    const courseIds = coursesResult.rows;

    // Insert lessons for each course
    for (let i = 0; i < courseIds.length; i++) {
      const courseId = courseIds[i].id;
      
      for (let j = 1; j <= 5; j++) {
        await query(`
          INSERT INTO lessons (id, course_id, title, content, duration_minutes, order_index, is_published)
          VALUES ($1, $2, $3, $4, $5, $6)
        `, [
          uuidv4(),
          courseId,
          `Lesson ${j}: ${['HTML & CSS Basics', 'JavaScript Fundamentals', 'DOM Manipulation', 'Async JavaScript', 'Project Building'][j-1]}`,
          `This is lesson ${j} covering ${['HTML & CSS basics', 'JavaScript fundamentals', 'DOM manipulation techniques', 'Asynchronous programming', 'Building a complete project'][j-1]}`,
          30 + (j * 10),
          j,
          true
        ]);
      }
    }

    logger.info('Database seeding completed successfully');
    logger.info(`Created ${users.length} users, ${categories.length} categories, ${courses.length} courses with lessons`);
    
  } catch (error) {
    logger.error('Database seeding failed:', error);
    throw error;
  }
};

// Run seeding if this file is executed directly
if (require.main === module) {
  seedData()
    .then(() => {
      logger.info('Seeding completed');
      process.exit(0);
    })
    .catch((error) => {
      logger.error('Seeding failed:', error);
      process.exit(1);
    });
}

module.exports = { seedData };
