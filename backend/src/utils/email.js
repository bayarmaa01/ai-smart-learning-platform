const nodemailer = require('nodemailer');
let logger;
try {
  ({ logger } = require('./logger'));
} catch (e) {
  // Fallback logger for test environment
  logger = {
    error: () => {},
    info: () => {},
    warn: () => {},
    debug: () => {},
    http: () => {}
  };
}

let transporter = null;

function getTransporter() {
  if (transporter) return transporter;

  if (process.env.SMTP_HOST) {
    transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port: parseInt(process.env.SMTP_PORT || '587'),
      secure: process.env.SMTP_PORT === '465',
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS,
      },
    });
  } else if (process.env.SENDGRID_API_KEY) {
    transporter = nodemailer.createTransport({
      service: 'SendGrid',
      auth: {
        user: 'apikey',
        pass: process.env.SENDGRID_API_KEY,
      },
    });
  } else {
    // Development: log emails to console instead of sending
    transporter = {
      sendMail: async (opts) => {
        logger.info('📧 [DEV EMAIL] Would send email:', {
          to: opts.to,
          subject: opts.subject,
          text: opts.text?.substring(0, 200),
        });
        return { messageId: `dev-${Date.now()}` };
      },
    };
  }

  return transporter;
}

async function sendEmail({ to, subject, html, text }) {
  try {
    const t = getTransporter();
    const info = await t.sendMail({
      from: process.env.FROM_EMAIL || '"EduAI Platform" <noreply@eduai.com>',
      to,
      subject,
      html,
      text,
    });
    logger.info(`Email sent to ${to}: ${info.messageId}`);
    return true;
  } catch (err) {
    logger.error('Failed to send email:', err);
    return false;
  }
}

async function sendPasswordResetEmail(email, resetToken, firstName) {
  const resetUrl = `${process.env.FRONTEND_URL || 'http://localhost:3000'}/reset-password?token=${resetToken}`;
  return sendEmail({
    to: email,
    subject: 'Reset Your EduAI Password',
    html: `
      <div style="font-family:sans-serif;max-width:600px;margin:0 auto;background:#0f172a;color:#f1f5f9;padding:40px;border-radius:12px;">
        <h1 style="color:#3b82f6;margin-bottom:8px;">EduAI Platform</h1>
        <h2 style="color:#f1f5f9;margin-bottom:24px;">Reset Your Password</h2>
        <p>Hi ${firstName},</p>
        <p>You requested a password reset. Click the button below to set a new password. This link expires in <strong>1 hour</strong>.</p>
        <div style="text-align:center;margin:32px 0;">
          <a href="${resetUrl}" style="background:#3b82f6;color:white;padding:14px 32px;border-radius:8px;text-decoration:none;font-weight:600;display:inline-block;">
            Reset Password
          </a>
        </div>
        <p style="color:#94a3b8;font-size:14px;">If you didn't request this, you can safely ignore this email.</p>
        <p style="color:#64748b;font-size:12px;margin-top:32px;">Or copy this link: ${resetUrl}</p>
      </div>
    `,
    text: `Hi ${firstName},\n\nReset your password here: ${resetUrl}\n\nThis link expires in 1 hour.\n\nIf you didn't request this, ignore this email.`,
  });
}

async function sendWelcomeEmail(email, firstName) {
  return sendEmail({
    to: email,
    subject: 'Welcome to EduAI Platform!',
    html: `
      <div style="font-family:sans-serif;max-width:600px;margin:0 auto;background:#0f172a;color:#f1f5f9;padding:40px;border-radius:12px;">
        <h1 style="color:#3b82f6;margin-bottom:8px;">EduAI Platform</h1>
        <h2 style="color:#f1f5f9;margin-bottom:24px;">Welcome, ${firstName}! 🎉</h2>
        <p>Your account has been created successfully. You can now:</p>
        <ul style="color:#94a3b8;line-height:2;">
          <li>Browse 200+ courses in AI, Programming, DevOps & more</li>
          <li>Chat with our multilingual AI assistant (English & Mongolian)</li>
          <li>Track your progress and earn certificates</li>
        </ul>
        <div style="text-align:center;margin:32px 0;">
          <a href="${process.env.FRONTEND_URL || 'http://localhost:3000'}/dashboard" 
             style="background:#3b82f6;color:white;padding:14px 32px;border-radius:8px;text-decoration:none;font-weight:600;display:inline-block;">
            Start Learning
          </a>
        </div>
      </div>
    `,
    text: `Welcome to EduAI, ${firstName}! Start learning at ${process.env.FRONTEND_URL || 'http://localhost:3000'}/dashboard`,
  });
}

async function sendVerificationEmail(email, firstName, token) {
  const verifyUrl = `${process.env.FRONTEND_URL || 'http://localhost:3000'}/verify-email?token=${token}`;
  return sendEmail({
    to: email,
    subject: 'Verify Your EduAI Email Address',
    html: `
      <div style="font-family:sans-serif;max-width:600px;margin:0 auto;background:#0f172a;color:#f1f5f9;padding:40px;border-radius:12px;">
        <h1 style="color:#3b82f6;margin-bottom:8px;">EduAI Platform</h1>
        <h2 style="color:#f1f5f9;margin-bottom:24px;">Verify Your Email</h2>
        <p>Hi ${firstName}, please verify your email address to activate your account.</p>
        <div style="text-align:center;margin:32px 0;">
          <a href="${verifyUrl}" style="background:#10b981;color:white;padding:14px 32px;border-radius:8px;text-decoration:none;font-weight:600;display:inline-block;">
            Verify Email
          </a>
        </div>
        <p style="color:#64748b;font-size:12px;">Or copy: ${verifyUrl}</p>
      </div>
    `,
    text: `Hi ${firstName}, verify your email: ${verifyUrl}`,
  });
}

module.exports = { sendEmail, sendPasswordResetEmail, sendWelcomeEmail, sendVerificationEmail };
