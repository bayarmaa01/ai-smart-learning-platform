const { query } = require('../db/connection');
const { AppError } = require('../middleware/errorHandler');
const { logger } = require('../utils/logger');
const crypto = require('crypto');

class CertificateController {
  /**
   * Generate certificate for completed course
   */
  static async generateCertificate(req, res) {
    try {
      const { courseId } = req.params;
      const userId = req.user.id;

      // Check if user has completed the course
      const enrollmentResult = await query(`
        SELECT e.progress_percentage, c.title, c.id, c.duration_minutes
        FROM enrollments e
        JOIN courses c ON e.course_id = c.id
        WHERE e.user_id = $1 AND e.course_id = $2
      `, [userId, courseId]);

      if (enrollmentResult.rows.length === 0) {
        throw new AppError('Course enrollment not found', 404);
      }

      const enrollment = enrollmentResult.rows[0];
      
      if (enrollment.progress_percentage < 100) {
        throw new AppError('Course must be completed to receive certificate', 400);
      }

      // Check if certificate already exists
      const existingCert = await query(`
        SELECT id FROM certificates
        WHERE user_id = $1 AND course_id = $2
      `, [userId, courseId]);

      if (existingCert.rows.length > 0) {
        throw new AppError('Certificate already generated', 409);
      }

      // Generate certificate URL
      const certificateId = crypto.randomUUID();
      const certificateUrl = `/certificates/${certificateId}`;

      // Create certificate record
      await query(`
        INSERT INTO certificates (id, user_id, course_id, certificate_url)
        VALUES ($1, $2, $3, $4)
      `, [certificateId, userId, courseId, certificateUrl]);

      // Get user details for certificate
      const userResult = await query(`
        SELECT first_name, last_name, email
        FROM users
        WHERE id = $1
      `, [userId]);

      const user = userResult.rows[0];

      res.json({
        success: true,
        data: {
          certificateId,
          certificateUrl,
          courseTitle: enrollment.title,
          studentName: `${user.first_name} ${user.last_name}`,
          studentEmail: user.email,
          issuedAt: new Date().toISOString(),
          duration: enrollment.duration_minutes
        }
      });
    } catch (error) {
      logger.error('Generate certificate error:', error);
      throw error;
    }
  }

  /**
   * Get user's certificates
   */
  static async getUserCertificates(req, res) {
    try {
      const userId = req.user.id;

      const result = await query(`
        SELECT 
          c.id as certificate_id,
          c.certificate_url,
          c.issued_at,
          co.title as course_title,
          co.description as course_description,
          co.level,
          co.duration_minutes,
          cat.name as category_name
        FROM certificates c
        JOIN courses co ON c.course_id = co.id
        LEFT JOIN categories cat ON co.category_id = cat.id
        WHERE c.user_id = $1
        ORDER BY c.issued_at DESC
      `, [userId]);

      res.json({
        success: true,
        data: result.rows
      });
    } catch (error) {
      logger.error('Get user certificates error:', error);
      throw new AppError('Failed to fetch certificates', 500);
    }
  }

  /**
   * Get certificate details (public endpoint)
   */
  static async getCertificate(req, res) {
    try {
      const { certificateId } = req.params;

      const result = await query(`
        SELECT 
          c.certificate_url,
          c.issued_at,
          u.first_name,
          u.last_name,
          u.email,
          co.title as course_title,
          co.description as course_description,
          co.level,
          co.duration_minutes,
          cat.name as category_name
        FROM certificates c
        JOIN users u ON c.user_id = u.id
        JOIN courses co ON c.course_id = co.id
        LEFT JOIN categories cat ON co.category_id = cat.id
        WHERE c.id = $1
      `, [certificateId]);

      if (result.rows.length === 0) {
        throw new AppError('Certificate not found', 404);
      }

      const certificate = result.rows[0];

      res.json({
        success: true,
        data: {
          ...certificate,
          studentName: `${certificate.first_name} ${certificate.last_name}`,
          issuedDate: new Date(certificate.issued_at).toLocaleDateString(),
          isValid: true
        }
      });
    } catch (error) {
      logger.error('Get certificate error:', error);
      throw error;
    }
  }

  /**
   * Verify certificate (public endpoint)
   */
  static async verifyCertificate(req, res) {
    try {
      const { certificateId } = req.params;

      const result = await query(`
        SELECT 
          c.issued_at,
          u.first_name,
          u.last_name,
          co.title as course_title,
          co.level
        FROM certificates c
        JOIN users u ON c.user_id = u.id
        JOIN courses co ON c.course_id = co.id
        WHERE c.id = $1
      `, [certificateId]);

      if (result.rows.length === 0) {
        return res.json({
          success: false,
          message: 'Certificate not found'
        });
      }

      const certificate = result.rows[0];

      res.json({
        success: true,
        data: {
          valid: true,
          studentName: `${certificate.first_name} ${certificate.last_name}`,
          courseTitle: certificate.course_title,
          courseLevel: certificate.level,
          issuedDate: new Date(certificate.issued_at).toLocaleDateString()
        }
      });
    } catch (error) {
      logger.error('Verify certificate error:', error);
      throw new AppError('Failed to verify certificate', 500);
    }
  }

  /**
   * Download certificate PDF (placeholder)
   */
  static async downloadCertificate(req, res) {
    try {
      const { certificateId } = req.params;

      const result = await query(`
        SELECT 
          c.certificate_url,
          c.issued_at,
          u.first_name,
          u.last_name,
          co.title as course_title
        FROM certificates c
        JOIN users u ON c.user_id = u.id
        JOIN courses co ON c.course_id = co.id
        WHERE c.id = $1
      `, [certificateId]);

      if (result.rows.length === 0) {
        throw new AppError('Certificate not found', 404);
      }

      const certificate = result.rows[0];

      // For now, return a simple HTML certificate
      // In production, you would generate a PDF using libraries like puppeteer or pdfkit
      const htmlCertificate = `
<!DOCTYPE html>
<html>
<head>
    <title>Certificate of Completion</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
        .certificate { 
            max-width: 800px; 
            margin: 0 auto; 
            background: white; 
            padding: 40px; 
            border: 2px solid #gold; 
            box-shadow: 0 4px 8px rgba(0,0,0,0.1);
        }
        .header { text-align: center; margin-bottom: 30px; }
        .title { font-size: 32px; color: #2c3e50; margin: 0; }
        .subtitle { font-size: 18px; color: #7f8c8d; margin: 10px 0; }
        .content { text-align: center; margin: 30px 0; }
        .student-name { font-size: 24px; font-weight: bold; color: #2c3e50; margin: 20px 0; }
        .course-info { font-size: 16px; color: #34495e; margin: 10px 0; }
        .date { font-size: 14px; color: #7f8c8d; margin-top: 30px; }
        .signature { margin-top: 50px; text-align: right; }
    </style>
</head>
<body>
    <div class="certificate">
        <div class="header">
            <h1 class="title">Certificate of Completion</h1>
            <p class="subtitle">This is to certify that</p>
        </div>
        <div class="content">
            <div class="student-name">${certificate.first_name} ${certificate.last_name}</div>
            <div class="course-info">has successfully completed the course</div>
            <div class="course-info" style="font-weight: bold; font-size: 18px;">"${certificate.course_title}"</div>
            <div class="date">Issued on ${new Date(certificate.issued_at).toLocaleDateString()}</div>
        </div>
        <div class="signature">
            <p>AI Smart Learning Platform</p>
        </div>
    </div>
</body>
</html>
      `;

      res.setHeader('Content-Type', 'text/html');
      res.setHeader('Content-Disposition', `attachment; filename="certificate-${certificateId}.html"`);
      res.send(htmlCertificate);
    } catch (error) {
      logger.error('Download certificate error:', error);
      throw error;
    }
  }
}

module.exports = CertificateController;
