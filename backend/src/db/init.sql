-- AI Smart Learning Platform Database Schema
-- PostgreSQL initialization script

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    role VARCHAR(20) DEFAULT 'student' CHECK (role IN ('student', 'instructor', 'admin')),
    email_verified BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    subscription_plan VARCHAR(20) DEFAULT 'free' CHECK (subscription_plan IN ('free', 'basic', 'pro', 'enterprise')),
    language_preference VARCHAR(10) DEFAULT 'en',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Categories table
CREATE TABLE IF NOT EXISTS categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    icon_url VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Courses table
CREATE TABLE IF NOT EXISTS courses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    category_id UUID REFERENCES categories(id),
    instructor_id UUID REFERENCES users(id),
    level VARCHAR(20) DEFAULT 'beginner' CHECK (level IN ('beginner', 'intermediate', 'advanced')),
    thumbnail_url VARCHAR(255),
    price DECIMAL(10,2) DEFAULT 0.00,
    status VARCHAR(20) DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'archived')),
    enrollment_count INTEGER DEFAULT 0,
    rating_average DECIMAL(3,2) DEFAULT 0.00,
    duration_minutes INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Lessons table
CREATE TABLE IF NOT EXISTS lessons (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    course_id UUID REFERENCES courses(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    content TEXT,
    video_url VARCHAR(255),
    duration_minutes INTEGER DEFAULT 0,
    order_index INTEGER NOT NULL,
    is_free BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enrollments table
CREATE TABLE IF NOT EXISTS enrollments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id),
    course_id UUID REFERENCES courses(id),
    enrolled_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    progress_percentage DECIMAL(5,2) DEFAULT 0.00,
    UNIQUE(user_id, course_id)
);

-- Lesson progress table
CREATE TABLE IF NOT EXISTS lesson_progress (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id),
    lesson_id UUID REFERENCES lessons(id),
    completed_at TIMESTAMP WITH TIME ZONE,
    watch_time_seconds INTEGER DEFAULT 0,
    UNIQUE(user_id, lesson_id)
);

-- Placement tests table
CREATE TABLE IF NOT EXISTS placement_tests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    questions JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User placement test results
CREATE TABLE IF NOT EXISTS placement_test_results (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id),
    test_id UUID REFERENCES placement_tests(id),
    score INTEGER NOT NULL,
    max_score INTEGER NOT NULL,
    recommended_level VARCHAR(20) CHECK (recommended_level IN ('beginner', 'intermediate', 'advanced')),
    completed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Certificates table
CREATE TABLE IF NOT EXISTS certificates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id),
    course_id UUID REFERENCES courses(id),
    certificate_url VARCHAR(255),
    issued_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, course_id)
);

-- AI Chat sessions table
CREATE TABLE IF NOT EXISTS ai_chat_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id VARCHAR(255) UNIQUE NOT NULL,
    user_id UUID REFERENCES users(id),
    message_count INTEGER DEFAULT 0,
    last_message_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- AI Chat messages table
CREATE TABLE IF NOT EXISTS ai_chat_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id VARCHAR(255) REFERENCES ai_chat_sessions(session_id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL CHECK (role IN ('user', 'assistant')),
    content TEXT NOT NULL,
    detected_language VARCHAR(10),
    tokens_used INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for better performance
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_courses_category ON courses(category_id);
CREATE INDEX IF NOT EXISTS idx_courses_instructor ON courses(instructor_id);
CREATE INDEX IF NOT EXISTS idx_courses_status ON courses(status);
CREATE INDEX IF NOT EXISTS idx_lessons_course ON lessons(course_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_user ON enrollments(user_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_course ON enrollments(course_id);
CREATE INDEX IF NOT EXISTS idx_lesson_progress_user ON lesson_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_ai_chat_sessions_user ON ai_chat_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_ai_chat_messages_session ON ai_chat_messages(session_id);

-- Insert default admin user (password: admin123)
INSERT INTO users (email, password_hash, first_name, last_name, role, email_verified, is_active)
VALUES (
    'admin@ailearn.com',
    '$2a$10$rOzJqQjQjQjQjQjQjQjQuOzJqQjQjQjQjQjQjQjQjQuOzJqQjQjQjQjQjQjQjQuO',
    'Admin',
    'User',
    'admin',
    TRUE,
    TRUE
) ON CONFLICT (email) DO NOTHING;

-- Insert default categories
INSERT INTO categories (name, description) VALUES
('Programming', 'Learn various programming languages and frameworks'),
('Data Science', 'Master data analysis, machine learning, and AI'),
('Web Development', 'Build modern web applications'),
('Mobile Development', 'Create native and cross-platform mobile apps'),
('DevOps', 'Learn infrastructure, deployment, and operations'),
('Design', 'UI/UX design and graphic design principles')
ON CONFLICT DO NOTHING;

-- Insert sample placement test
INSERT INTO placement_tests (title, description, questions) VALUES
('General Programming Assessment', 'Assess your current programming knowledge', 
'[
  {
    "question": "What is the time complexity of binary search?",
    "options": ["O(n)", "O(log n)", "O(n²)", "O(1)"],
    "correct": 1
  },
  {
    "question": "Which of the following is a NoSQL database?",
    "options": ["MySQL", "PostgreSQL", "MongoDB", "SQLite"],
    "correct": 2
  },
  {
    "question": "What does REST stand for?",
    "options": ["Representational State Transfer", "Remote State Transfer", "Resource State Transfer", "Representational Service Transfer"],
    "correct": 0
  }
]'
) ON CONFLICT DO NOTHING;

-- Insert sample courses
INSERT INTO courses (title, description, category_id, instructor_id, level, price, status)
SELECT 
    'Introduction to JavaScript',
    'Learn the fundamentals of JavaScript programming',
    id,
    (SELECT id FROM users WHERE email = 'admin@ailearn.com' LIMIT 1),
    'beginner',
    0.00,
    'published'
FROM categories WHERE name = 'Programming' LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO courses (title, description, category_id, instructor_id, level, price, status)
SELECT 
    'React.js Fundamentals',
    'Master React.js from scratch',
    id,
    (SELECT id FROM users WHERE email = 'admin@ailearn.com' LIMIT 1),
    'intermediate',
    29.99,
    'published'
FROM categories WHERE name = 'Web Development' LIMIT 1
ON CONFLICT DO NOTHING;
