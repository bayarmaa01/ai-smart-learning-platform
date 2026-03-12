const bcrypt = require('bcryptjs');
const { query } = require('./connection');
const { logger } = require('../utils/logger');

class DatabaseSeeder {
  constructor() {
    this.tenantId = '00000000-0000-0000-0000-000000000001';
  }

  async seedAll() {
    try {
      logger.info('Starting database seeding...');
      
      await this.seedUsers();
      await this.seedCourses();
      await this.seedEnrollments();
      
      logger.info('Database seeding completed successfully');
      return true;
    } catch (error) {
      logger.error('Database seeding failed:', error);
      throw error;
    }
  }

  async seedUsers() {
    try {
      logger.info('Seeding users...');
      
      // Check if users already exist
      const existingUsers = await query('SELECT COUNT(*) as count FROM users');
      
      if (parseInt(existingUsers.rows[0].count) > 2) {
        logger.info('Users already exist, skipping user seeding');
        return;
      }
      
      // Create demo instructors
      const instructors = [
        {
          email: 'john.instructor@eduai.com',
          firstName: 'John',
          lastName: 'Smith',
          bio: 'Experienced software developer with 10+ years in web development',
          avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=john'
        },
        {
          email: 'sarah.instructor@eduai.com',
          firstName: 'Sarah',
          lastName: 'Johnson',
          bio: 'Data scientist and ML engineer specializing in deep learning',
          avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=sarah'
        },
        {
          email: 'mike.instructor@eduai.com',
          firstName: 'Mike',
          lastName: 'Wilson',
          bio: 'DevOps expert with extensive cloud infrastructure experience',
          avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=mike'
        }
      ];
      
      for (const instructor of instructors) {
        const hashedPassword = await bcrypt.hash('Instructor@1234', 12);
        
        await query(`
          INSERT INTO users (tenant_id, email, password_hash, first_name, last_name, role, bio, avatar_url, is_email_verified, is_active)
          VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
          ON CONFLICT (tenant_id, email) DO NOTHING
        `, [
          this.tenantId,
          instructor.email,
          hashedPassword,
          instructor.firstName,
          instructor.lastName,
          'instructor',
          instructor.bio,
          instructor.avatar,
          true,
          true
        ]);
      }
      
      // Create demo students
      const students = [
        {
          email: 'alice.student@eduai.com',
          firstName: 'Alice',
          lastName: 'Brown',
          placementLevel: 'intermediate'
        },
        {
          email: 'bob.student@eduai.com',
          firstName: 'Bob',
          lastName: 'Davis',
          placementLevel: 'beginner'
        },
        {
          email: 'carol.student@eduai.com',
          firstName: 'Carol',
          lastName: 'Miller',
          placementLevel: 'advanced'
        }
      ];
      
      for (const student of students) {
        const hashedPassword = await bcrypt.hash('Student@1234', 12);
        
        await query(`
          INSERT INTO users (tenant_id, email, password_hash, first_name, last_name, role, placement_level, is_email_verified, is_active)
          VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
          ON CONFLICT (tenant_id, email) DO NOTHING
        `, [
          this.tenantId,
          student.email,
          hashedPassword,
          student.firstName,
          student.lastName,
          'student',
          student.placementLevel,
          true,
          true
        ]);
      }
      
      logger.info('Users seeded successfully');
    } catch (error) {
      logger.error('Failed to seed users:', error);
      throw error;
    }
  }

  async seedCourses() {
    try {
      logger.info('Seeding courses...');
      
      // Check if courses already exist
      const existingCourses = await query('SELECT COUNT(*) as count FROM courses');
      
      if (parseInt(existingCourses.rows[0].count) > 0) {
        logger.info('Courses already exist, skipping course seeding');
        return;
      }
      
      // Get instructor IDs
      const instructorResult = await query('SELECT id, email FROM users WHERE role = $1', ['instructor']);
      const instructors = instructorResult.rows;
      
      // Get category IDs
      const categoryResult = await query('SELECT id, slug FROM categories');
      const categories = categoryResult.rows;
      
      const getCategory = (slug) => categories.find(cat => cat.slug === slug)?.id;
      const getInstructor = (email) => instructors.find(inst => inst.email === email)?.id;
      
      const courses = [
        {
          title: 'Complete Web Development Bootcamp',
          slug: 'complete-web-development-bootcamp',
          description: 'Learn web development from scratch with HTML, CSS, JavaScript, React, Node.js and more',
          shortDescription: 'Comprehensive web development course for beginners',
          instructorEmail: 'john.instructor@eduai.com',
          categorySlug: 'programming',
          level: 'beginner',
          price: 89.99,
          durationHours: 40,
          whatYouLearn: [
            'HTML5 & CSS3 fundamentals',
            'JavaScript ES6+ features',
            'React.js and modern frameworks',
            'Node.js and Express.js',
            'Database design with SQL',
            'RESTful API development'
          ],
          requirements: [
            'Basic computer skills',
            'No programming experience required',
            'A computer with internet access'
          ],
          tags: ['web', 'javascript', 'react', 'nodejs', 'html', 'css'],
          isFree: false,
          isFeatured: true
        },
        {
          title: 'Python for Data Science',
          slug: 'python-for-data-science',
          description: 'Master Python programming for data analysis, visualization, and machine learning',
          shortDescription: 'Complete Python data science course',
          instructorEmail: 'sarah.instructor@eduai.com',
          categorySlug: 'data-science',
          level: 'intermediate',
          price: 129.99,
          durationHours: 60,
          whatYouLearn: [
            'Python programming fundamentals',
            'NumPy and Pandas for data analysis',
            'Data visualization with Matplotlib',
            'Machine learning with Scikit-learn',
            'Statistical analysis and hypothesis testing'
          ],
          requirements: [
            'Basic programming knowledge',
            'Understanding of basic statistics',
            'Python installed on your computer'
          ],
          tags: ['python', 'data-science', 'pandas', 'numpy', 'machine-learning'],
          isFree: false,
          isFeatured: true
        },
        {
          title: 'Docker and Kubernetes Fundamentals',
          slug: 'docker-kubernetes-fundamentals',
          description: 'Learn containerization and orchestration with Docker and Kubernetes',
          shortDescription: 'Complete container orchestration guide',
          instructorEmail: 'mike.instructor@eduai.com',
          categorySlug: 'devops',
          level: 'advanced',
          price: 149.99,
          durationHours: 35,
          whatYouLearn: [
            'Docker containerization',
            'Kubernetes orchestration',
            'Microservices architecture',
            'CI/CD pipeline setup',
            'Cloud deployment strategies'
          ],
          requirements: [
            'Linux command line basics',
            'Understanding of web applications',
            'Basic networking knowledge'
          ],
          tags: ['docker', 'kubernetes', 'devops', 'containers', 'microservices'],
          isFree: false,
          isFeatured: false
        },
        {
          title: 'Introduction to Machine Learning',
          slug: 'introduction-to-machine-learning',
          description: 'Get started with machine learning concepts and algorithms',
          shortDescription: 'ML fundamentals for beginners',
          instructorEmail: 'sarah.instructor@eduai.com',
          categorySlug: 'ai-ml',
          level: 'beginner',
          price: 0,
          durationHours: 25,
          whatYouLearn: [
            'Machine learning fundamentals',
            'Supervised and unsupervised learning',
            'Linear regression and classification',
            'Decision trees and random forests',
            'Model evaluation and validation'
          ],
          requirements: [
            'Basic Python programming',
            'High school mathematics',
            'Understanding of basic statistics'
          ],
          tags: ['machine-learning', 'ai', 'python', 'algorithms', 'data-science'],
          isFree: true,
          isFeatured: true
        },
        {
          title: 'UI/UX Design Principles',
          slug: 'ui-ux-design-principles',
          description: 'Learn the fundamentals of user interface and user experience design',
          shortDescription: 'Complete UI/UX design course',
          instructorEmail: 'john.instructor@eduai.com',
          categorySlug: 'design',
          level: 'beginner',
          price: 79.99,
          durationHours: 30,
          whatYouLearn: [
            'Design thinking process',
            'User research methodologies',
            'Wireframing and prototyping',
            'Visual design principles',
            'Usability testing'
          ],
          requirements: [
            'No design experience required',
            'Creative mindset',
            'Basic computer skills'
          ],
          tags: ['ui', 'ux', 'design', 'figma', 'prototyping'],
          isFree: false,
          isFeatured: false
        }
      ];
      
      for (const course of courses) {
        const courseId = require('uuid').v4();
        
        await query(`
          INSERT INTO courses (
            id, tenant_id, instructor_id, category_id, title, slug, description, 
            short_description, level, price, duration_hours, what_you_learn, 
            requirements, tags, is_free, is_featured, status, published_at
          ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18)
          ON CONFLICT (slug) DO NOTHING
        `, [
          courseId,
          this.tenantId,
          getInstructor(course.instructorEmail),
          getCategory(course.categorySlug),
          course.title,
          course.slug,
          course.description,
          course.shortDescription,
          course.level,
          course.price,
          course.durationHours,
          JSON.stringify(course.whatYouLearn),
          JSON.stringify(course.requirements),
          JSON.stringify(course.tags),
          course.isFree,
          course.isFeatured,
          'published',
          new Date().toISOString()
        ]);
        
        // Create course sections and lessons
        await this.createCourseContent(courseId, course);
      }
      
      logger.info('Courses seeded successfully');
    } catch (error) {
      logger.error('Failed to seed courses:', error);
      throw error;
    }
  }

  async createCourseContent(courseId, course) {
    try {
      // Create sections
      const sections = [
        { title: 'Introduction', order: 1 },
        { title: 'Getting Started', order: 2 },
        { title: 'Core Concepts', order: 3 },
        { title: 'Advanced Topics', order: 4 },
        { title: 'Project', order: 5 }
      ];
      
      for (const section of sections) {
        const sectionId = require('uuid').v4();
        
        await query(`
          INSERT INTO course_sections (id, course_id, title, sort_order)
          VALUES ($1, $2, $3, $4)
          ON CONFLICT DO NOTHING
        `, [sectionId, courseId, section.title, section.order]);
        
        // Create lessons for each section
        const lessonCount = section.order === 5 ? 3 : 4; // Project section has fewer lessons
        
        for (let i = 1; i <= lessonCount; i++) {
          const lessonId = require('uuid').v4();
          const isVideo = Math.random() > 0.3; // 70% video lessons
          
          await query(`
            INSERT INTO lessons (
              id, section_id, course_id, title, description, 
              content_type, video_duration, sort_order
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
            ON CONFLICT DO NOTHING
          `, [
            lessonId,
            sectionId,
            courseId,
            `Lesson ${section.order}.${i}: ${section.title} Topic ${i}`,
            `Detailed description for lesson ${section.order}.${i}`,
            isVideo ? 'video' : 'article',
            isVideo ? Math.floor(Math.random() * 30) + 10 : 0, // 10-40 minutes for videos
            i
          ]);
        }
      }
    } catch (error) {
      logger.error('Failed to create course content:', error);
      throw error;
    }
  }

  async seedEnrollments() {
    try {
      logger.info('Seeding enrollments...');
      
      // Get students and courses
      const students = await query('SELECT id FROM users WHERE role = $1', ['student']);
      const courses = await query('SELECT id FROM courses WHERE status = $1', ['published']);
      
      if (students.rows.length === 0 || courses.rows.length === 0) {
        logger.info('No students or courses found, skipping enrollment seeding');
        return;
      }
      
      // Enroll each student in 2-4 random courses
      for (const student of students.rows) {
        const enrollmentCount = Math.floor(Math.random() * 3) + 2; // 2-4 courses
        const shuffledCourses = courses.rows.sort(() => Math.random() - 0.5);
        
        for (let i = 0; i < Math.min(enrollmentCount, shuffledCourses.length); i++) {
          const course = shuffledCourses[i];
          
          // Check if already enrolled
          const existing = await query(
            'SELECT id FROM enrollments WHERE user_id = $1 AND course_id = $2',
            [student.id, course.id]
          );
          
          if (existing.rows.length === 0) {
            await query(`
              INSERT INTO enrollments (user_id, course_id, progress_percentage)
              VALUES ($1, $2, $3)
              ON CONFLICT (user_id, course_id) DO NOTHING
            `, [
              student.id,
              course.id,
              Math.floor(Math.random() * 100) // Random progress 0-99%
            ]);
          }
        }
      }
      
      logger.info('Enrollments seeded successfully');
    } catch (error) {
      logger.error('Failed to seed enrollments:', error);
      throw error;
    }
  }

  async reset() {
    try {
      logger.warn('Resetting seeded data...');
      
      // Delete enrollments
      await query('DELETE FROM enrollments');
      
      // Delete lessons and sections
      await query('DELETE FROM lesson_progress');
      await query('DELETE FROM lessons');
      await query('DELETE FROM course_sections');
      
      // Delete courses (except keep categories and plans)
      await query('DELETE FROM courses');
      
      // Delete demo users (keep admin and student demo accounts)
      await query("DELETE FROM users WHERE email LIKE '%@eduai.com' AND email NOT IN ('admin@eduai.com', 'student@eduai.com')");
      
      logger.info('Seeded data reset completed');
      return true;
    } catch (error) {
      logger.error('Failed to reset seeded data:', error);
      throw error;
    }
  }

  async getStatus() {
    try {
      const users = await query('SELECT COUNT(*) as count FROM users');
      const courses = await query('SELECT COUNT(*) as count FROM courses');
      const enrollments = await query('SELECT COUNT(*) as count FROM enrollments');
      
      return {
        users: parseInt(users.rows[0].count),
        courses: parseInt(courses.rows[0].count),
        enrollments: parseInt(enrollments.rows[0].count)
      };
    } catch (error) {
      logger.error('Failed to get seeder status:', error);
      throw error;
    }
  }
}

// Export singleton instance
const seeder = new DatabaseSeeder();

module.exports = {
  seeder,
  seedDatabase: () => seeder.seedAll(),
  resetSeededData: () => seeder.reset(),
  getSeederStatus: () => seeder.getStatus()
};

// CLI support
if (require.main === module) {
  const command = process.argv[2];
  
  switch (command) {
    case 'seed':
      seeder.seedAll();
      break;
    case 'reset':
      seeder.reset();
      break;
    case 'status':
      seeder.getStatus().then(console.log);
      break;
    default:
      console.log('Usage: node seed.js [seed|reset|status]');
  }
}
