const { logger } = require('../utils/logger');

class AppError extends Error {
  constructor(message, statusCode = 500, code = 'INTERNAL_ERROR', details = null) {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
    this.details = details;
    this.isOperational = true;
    Error.captureStackTrace(this, this.constructor);
  }
}

const errorHandler = (err, req, res, _next) => {
  let statusCode = err.statusCode || 500;
  let message = err.message || 'Internal Server Error';
  let code = err.code || 'INTERNAL_ERROR';

  if (err.name === 'ValidationError') {
    statusCode = 400;
    code = 'VALIDATION_ERROR';
  }

  if (err.code === '23505') {
    statusCode = 409;
    message = 'Resource already exists';
    code = 'DUPLICATE_ERROR';
  }

  if (err.code === '23503') {
    statusCode = 400;
    message = 'Referenced resource not found';
    code = 'FOREIGN_KEY_ERROR';
  }

  if (statusCode >= 500) {
    logger.error('Server Error:', {
      message: err.message,
      stack: err.stack,
      requestId: req.requestId,
      url: req.url,
      method: req.method,
      userId: req.user?.id,
    });
  }

  const response = {
    success: false,
    error: {
      code,
      message: process.env.NODE_ENV === 'production' && statusCode === 500
        ? 'Internal Server Error'
        : message,
    },
    requestId: req.requestId,
  };

  if (process.env.NODE_ENV !== 'production' && err.details) {
    response.error.details = err.details;
  }

  res.status(statusCode).json(response);
};

const notFound = (req, res, next) => {
  next(new AppError(`Route ${req.method} ${req.url} not found`, 404, 'NOT_FOUND'));
};

module.exports = { AppError, errorHandler, notFound };
