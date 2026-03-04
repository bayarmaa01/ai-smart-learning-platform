const express = require('express');
const router = express.Router();
const { body, query: queryValidator, param } = require('express-validator');
const courseController = require('../controllers/courseController');
const { verifyToken, authorize, optionalAuth } = require('../middleware/auth');
const { validate } = require('../middleware/validate');

router.get('/', optionalAuth, courseController.getCourses);
router.get('/enrolled', verifyToken, courseController.getEnrolledCourses);
router.get('/:id', optionalAuth, courseController.getCourseById);
router.post('/:id/enroll', verifyToken, courseController.enrollCourse);
router.post('/:id/progress', verifyToken, courseController.updateProgress);
router.get('/:id/progress', verifyToken, courseController.getCourseProgress);

router.post('/', verifyToken, authorize('instructor', 'admin', 'super_admin'), [
  body('title').trim().isLength({ min: 3, max: 500 }),
  body('description').trim().isLength({ min: 10 }),
  body('level').isIn(['beginner', 'intermediate', 'advanced']),
  body('price').isFloat({ min: 0 }),
], validate, courseController.createCourse);

router.put('/:id', verifyToken, authorize('instructor', 'admin', 'super_admin'), courseController.updateCourse);
router.delete('/:id', verifyToken, authorize('admin', 'super_admin'), courseController.deleteCourse);
router.patch('/:id/publish', verifyToken, authorize('admin', 'super_admin'), courseController.publishCourse);

module.exports = router;
