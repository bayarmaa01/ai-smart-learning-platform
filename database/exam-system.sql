-- Exam System Database Migration
-- This file creates all required tables for the Secure Exam Platform

-- Create exams table
CREATE TABLE IF NOT EXISTS exams (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(500) NOT NULL,
    description TEXT,
    course_id UUID REFERENCES courses(id) ON DELETE CASCADE,
    instructor_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    duration_minutes INTEGER NOT NULL CHECK (duration_minutes > 0),
    start_time TIMESTAMPTZ,
    end_time TIMESTAMPTZ,
    status VARCHAR(50) DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'ongoing', 'completed', 'archived')),
    instructions TEXT,
    max_attempts INTEGER DEFAULT 1 CHECK (max_attempts > 0),
    passing_score INTEGER DEFAULT 60 CHECK (passing_score >= 0 AND passing_score <= 100),
    shuffle_questions BOOLEAN DEFAULT FALSE,
    show_results BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create questions table
CREATE TABLE IF NOT EXISTS questions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    exam_id UUID NOT NULL REFERENCES exams(id) ON DELETE CASCADE,
    question_text TEXT NOT NULL,
    question_type VARCHAR(50) DEFAULT 'multiple_choice' CHECK (question_type IN ('multiple_choice', 'true_false', 'short_answer', 'essay')),
    options JSONB, -- For MCQ: ["Option A", "Option B", "Option C", "Option D"]
    correct_answer TEXT NOT NULL, -- For MCQ: index or text; For essay: reference answer
    explanation TEXT,
    points INTEGER DEFAULT 1 CHECK (points > 0),
    order_index INTEGER NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create attempts table (CRITICAL)
CREATE TABLE IF NOT EXISTS attempts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    exam_id UUID NOT NULL REFERENCES exams(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    answers JSONB, -- Store user answers as JSON: {"question_id": "answer", ...}
    score INTEGER CHECK (score >= 0),
    max_score INTEGER DEFAULT 0,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    submitted_at TIMESTAMPTZ,
    status VARCHAR(50) DEFAULT 'in_progress' CHECK (status IN ('in_progress', 'submitted', 'graded', 'expired')),
    time_taken_minutes INTEGER,
    ip_address INET,
    user_agent TEXT,
    is_suspicious BOOLEAN DEFAULT FALSE,
    cheating_flags JSONB, -- Store cheating detection flags
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(exam_id, user_id, started_at) -- One active attempt per exam per user
);

-- Create proctoring_warnings table
CREATE TABLE IF NOT EXISTS proctoring_warnings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    attempt_id UUID NOT NULL REFERENCES attempts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    exam_id UUID NOT NULL REFERENCES exams(id) ON DELETE CASCADE,
    warning_type VARCHAR(50) NOT NULL CHECK (warning_type IN ('tab_switch', 'fullscreen_exit', 'no_face', 'multiple_faces', 'suspicious_behavior')),
    severity VARCHAR(20) DEFAULT 'medium' CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    details JSONB, -- Additional context about the warning
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    is_acknowledged BOOLEAN DEFAULT FALSE
);

-- Create exam_analytics table
CREATE TABLE IF NOT EXISTS exam_analytics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    exam_id UUID NOT NULL REFERENCES exams(id) ON DELETE CASCADE,
    total_attempts INTEGER DEFAULT 0,
    average_score DECIMAL(5,2) DEFAULT 0,
    highest_score INTEGER DEFAULT 0,
    lowest_score INTEGER DEFAULT 0,
    pass_rate DECIMAL(5,2) DEFAULT 0,
    average_time_minutes DECIMAL(8,2) DEFAULT 0,
    suspicious_attempts INTEGER DEFAULT 0,
    last_updated TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_exams_course ON exams(course_id);
CREATE INDEX IF NOT EXISTS idx_exams_instructor ON exams(instructor_id);
CREATE INDEX IF NOT EXISTS idx_exams_status ON exams(status);
CREATE INDEX IF NOT EXISTS idx_exams_start_time ON exams(start_time);
CREATE INDEX IF NOT EXISTS idx_questions_exam ON questions(exam_id);
CREATE INDEX IF NOT EXISTS idx_attempts_exam ON attempts(exam_id);
CREATE INDEX IF NOT EXISTS idx_attempts_user ON attempts(user_id);
CREATE INDEX IF NOT EXISTS idx_attempts_status ON attempts(status);
CREATE INDEX IF NOT EXISTS idx_attempts_exam_user ON attempts(exam_id, user_id);
CREATE INDEX IF NOT EXISTS idx_proctoring_warnings_attempt ON proctoring_warnings(attempt_id);
CREATE INDEX IF NOT EXISTS idx_proctoring_warnings_user ON proctoring_warnings(user_id);
CREATE INDEX IF NOT EXISTS idx_proctoring_warnings_exam ON proctoring_warnings(exam_id);
CREATE INDEX IF NOT EXISTS idx_exam_analytics_exam ON exam_analytics(exam_id);

-- Triggers for updated_at timestamps
CREATE TRIGGER update_exams_updated_at BEFORE UPDATE ON exams
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_questions_updated_at BEFORE UPDATE ON questions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to automatically update exam status based on time
CREATE OR REPLACE FUNCTION update_exam_status()
RETURNS TRIGGER AS $$
BEGIN
    -- Auto-update exam status based on current time
    IF NEW.start_time IS NOT NULL AND NEW.end_time IS NOT NULL THEN
        IF NOW() < NEW.start_time THEN
            NEW.status := 'published';
        ELSIF NOW() >= NEW.start_time AND NOW() < NEW.end_time THEN
            NEW.status := 'ongoing';
        ELSIF NOW() >= NEW.end_time THEN
            NEW.status := 'completed';
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER auto_update_exam_status BEFORE UPDATE ON exams
    FOR EACH ROW EXECUTE FUNCTION update_exam_status();

-- Function to update exam analytics after attempt submission
CREATE OR REPLACE FUNCTION update_exam_analytics()
RETURNS TRIGGER AS $$
BEGIN
    -- Update analytics when an attempt is submitted
    IF NEW.status = 'submitted' AND OLD.status != 'submitted' THEN
        INSERT INTO exam_analytics (exam_id, total_attempts, average_score, highest_score, lowest_score, pass_rate)
        VALUES (
            NEW.exam_id,
            1,
            NEW.score,
            NEW.score,
            NEW.score,
            CASE WHEN NEW.score >= (SELECT passing_score FROM exams WHERE id = NEW.exam_id) THEN 100 ELSE 0 END
        )
        ON CONFLICT (exam_id) DO UPDATE SET
            total_attempts = exam_analytics.total_attempts + 1,
            average_score = (
                (exam_analytics.average_score * exam_analytics.total_attempts + NEW.score) / 
                (exam_analytics.total_attempts + 1)
            ),
            highest_score = GREATEST(exam_analytics.highest_score, NEW.score),
            lowest_score = LEAST(exam_analytics.lowest_score, NEW.score),
            pass_rate = (
                (SELECT COUNT(*) FROM attempts WHERE exam_id = NEW.exam_id AND status = 'submitted' AND 
                 score >= (SELECT passing_score FROM exams WHERE id = NEW.exam_id)) * 100.0 / 
                (exam_analytics.total_attempts + 1)
            ),
            last_updated = NOW();
    END IF;
    
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_analytics_on_attempt_submit AFTER UPDATE ON attempts
    FOR EACH ROW EXECUTE FUNCTION update_exam_analytics();

-- Function to expire ongoing attempts when exam ends
CREATE OR REPLACE FUNCTION expire_ongoing_attempts()
RETURNS void AS $$
BEGIN
    UPDATE attempts 
    SET status = 'expired', submitted_at = NOW()
    WHERE status = 'in_progress' 
    AND exam_id IN (
        SELECT id FROM exams 
        WHERE end_time < NOW() AND status = 'ongoing'
    );
END;
$$ language 'plpgsql';

-- Create a scheduled job to run this function (requires pg_cron extension)
-- SELECT cron.schedule('expire-attempts', '*/5 * * * *', 'SELECT expire_ongoing_attempts();');

-- Insert sample data for testing (optional)
-- This will be handled by the seed data script
