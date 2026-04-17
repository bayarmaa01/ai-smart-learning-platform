const client = require('prom-client');

// Create a Registry to register the metrics
const register = new client.Registry();

// Add a default label which can be used to identify metrics
register.setDefaultLabels({
  app: 'ai-smart-learning-platform'
});

// Enable the collection of default metrics
client.collectDefaultMetrics({ register });

// Custom metrics for exam system
const examMetrics = {
  // Exam metrics
  examActiveTotal: new client.Gauge({
    name: 'exam_active_total',
    help: 'Total number of active exams',
    labelNames: ['status', 'course_id']
  }),

  examTotal: new client.Gauge({
    name: 'exam_total',
    help: 'Total number of exams',
    labelNames: ['status', 'instructor_id']
  }),

  // Attempt metrics
  attemptsTotal: new client.Counter({
    name: 'attempts_total',
    help: 'Total number of exam attempts',
    labelNames: ['exam_id', 'user_id', 'status']
  }),

  attemptsActive: new client.Gauge({
    name: 'attempts_active',
    help: 'Number of currently active exam attempts',
    labelNames: ['exam_id']
  }),

  submissionsTotal: new client.Counter({
    name: 'submissions_total',
    help: 'Total number of exam submissions',
    labelNames: ['exam_id', 'passed']
  }),

  averageScore: new client.Gauge({
    name: 'average_score',
    help: 'Average exam score',
    labelNames: ['exam_id']
  }),

  // Proctoring metrics
  warningsTotal: new client.Counter({
    name: 'warnings_total',
    help: 'Total number of proctoring warnings',
    labelNames: ['exam_id', 'user_id', 'warning_type', 'severity']
  }),

  cheatingDetectedTotal: new client.Counter({
    name: 'cheating_detected_total',
    help: 'Total number of cheating detections',
    labelNames: ['exam_id', 'user_id']
  }),

  suspiciousAttemptsTotal: new client.Gauge({
    name: 'suspicious_attempts_total',
    help: 'Number of suspicious exam attempts',
    labelNames: ['exam_id']
  }),

  // System metrics
  questionTotal: new client.Gauge({
    name: 'question_total',
    help: 'Total number of questions',
    labelNames: ['exam_id', 'question_type']
  }),

  enrollmentExamMetrics: new client.Gauge({
    name: 'enrollment_exam_metrics',
    help: 'Enrollment metrics for exams',
    labelNames: ['exam_id', 'metric_type'] // metric_type: enrolled, completed, passed
  }),

  // Performance metrics
  examSubmissionDuration: new client.Histogram({
    name: 'exam_submission_duration_seconds',
    help: 'Duration of exam submissions in seconds',
    labelNames: ['exam_id'],
    buckets: [60, 300, 600, 900, 1200, 1500, 1800, 2400, 3000] // 1min to 50min
  }),

  apiRequestDuration: new client.Histogram({
    name: 'api_request_duration_seconds',
    help: 'Duration of API requests in seconds',
    labelNames: ['method', 'route', 'status_code'],
    buckets: [0.1, 0.5, 1, 2, 5, 10]
  }),

  apiRequestTotal: new client.Counter({
    name: 'api_requests_total',
    help: 'Total number of API requests',
    labelNames: ['method', 'route', 'status_code']
  })
};

// Register all metrics
Object.values(examMetrics).forEach(metric => {
  register.registerMetric(metric);
});

class ExamMetricsCollector {
  static async updateExamMetrics() {
    try {
      const { query } = require('../db/connection');
      
      // Update exam counts by status
      const examStatusResult = await query(`
        SELECT status, COUNT(*) as count
        FROM exams
        GROUP BY status
      `);

      examStatusResult.rows.forEach(row => {
        examMetrics.examTotal.set({ status: row.status }, row.count);
      });

      // Update active exams (published + ongoing)
      const activeExamsResult = await query(`
        SELECT COUNT(*) as count
        FROM exams
        WHERE status IN ('published', 'ongoing')
      `);

      examMetrics.examActiveTotal.set({}, activeExamsResult.rows[0].count);

      // Update attempt metrics
      const attemptStatusResult = await query(`
        SELECT status, COUNT(*) as count
        FROM attempts
        GROUP BY status
      `);

      attemptStatusResult.rows.forEach(row => {
        examMetrics.attemptsActive.set({ status: row.status }, row.count);
      });

      // Update submission metrics
      const submissionResult = await query(`
        SELECT exam_id, 
               COUNT(*) as total_submissions,
               COUNT(CASE WHEN score >= (e.passing_score * max_score / 100) THEN 1 END) as passed_submissions
        FROM attempts a
        JOIN exams e ON a.exam_id = e.id
        WHERE a.status = 'submitted'
        GROUP BY exam_id
      `);

      submissionResult.rows.forEach(row => {
        examMetrics.submissionsTotal.set({ exam_id: row.exam_id, passed: 'true' }, row.passed_submissions);
        examMetrics.submissionsTotal.set({ exam_id: row.exam_id, passed: 'false' }, row.total_submissions - row.passed_submissions);
      });

      // Update average scores
      const avgScoreResult = await query(`
        SELECT exam_id, AVG(score::float / NULLIF(max_score, 0)) * 100 as avg_score
        FROM attempts
        WHERE status = 'submitted' AND max_score > 0
        GROUP BY exam_id
      `);

      avgScoreResult.rows.forEach(row => {
        examMetrics.averageScore.set({ exam_id: row.exam_id }, row.avg_score);
      });

      // Update proctoring metrics
      const warningResult = await query(`
        SELECT exam_id, warning_type, severity, COUNT(*) as count
        FROM proctoring_warnings
        GROUP BY exam_id, warning_type, severity
      `);

      warningResult.rows.forEach(row => {
        for (let i = 0; i < row.count; i++) {
          examMetrics.warningsTotal.inc({
            exam_id: row.exam_id,
            warning_type: row.warning_type,
            severity: row.severity
          });
        }
      });

      // Update suspicious attempts
      const suspiciousResult = await query(`
        SELECT exam_id, COUNT(*) as count
        FROM attempts
        WHERE is_suspicious = true
        GROUP BY exam_id
      `);

      suspiciousResult.rows.forEach(row => {
        examMetrics.suspiciousAttemptsTotal.set({ exam_id: row.exam_id }, row.count);
      });

      // Update question metrics
      const questionResult = await query(`
        SELECT exam_id, question_type, COUNT(*) as count
        FROM questions
        GROUP BY exam_id, question_type
      `);

      questionResult.rows.forEach(row => {
        examMetrics.questionTotal.set({ exam_id: row.exam_id, question_type: row.question_type }, row.count);
      });

    } catch (error) {
      console.error('Error updating exam metrics:', error);
    }
  }

  static recordAttemptStart(examId, userId) {
    examMetrics.attemptsTotal.inc({ exam_id: examId, user_id: userId, status: 'in_progress' });
  }

  static recordAttemptSubmission(examId, userId, passed, duration) {
    examMetrics.attemptsTotal.inc({ exam_id: examId, user_id: userId, status: 'submitted' });
    examMetrics.submissionsTotal.inc({ exam_id: examId, passed: passed.toString() });
    
    if (duration) {
      examMetrics.examSubmissionDuration.observe({ exam_id: examId }, duration);
    }
  }

  static recordProctoringWarning(examId, userId, warningType, severity) {
    examMetrics.warningsTotal.inc({
      exam_id: examId,
      user_id: userId,
      warning_type: warningType,
      severity: severity
    });
  }

  static recordCheatingDetection(examId, userId) {
    examMetrics.cheatingDetectedTotal.inc({ exam_id: examId, user_id: userId });
  }

  static recordApiRequest(method, route, statusCode, duration) {
    examMetrics.apiRequestTotal.inc({ method, route, status_code: statusCode.toString() });
    if (duration) {
      examMetrics.apiRequestDuration.observe({ method, route, status_code: statusCode.toString() }, duration);
    }
  }

  static getRegister() {
    return register;
  }
}

// Update metrics every 30 seconds
setInterval(() => {
  ExamMetricsCollector.updateExamMetrics();
}, 30000);

module.exports = {
  examMetrics,
  ExamMetricsCollector,
  register
};
