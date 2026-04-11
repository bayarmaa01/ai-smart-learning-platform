const express = require('express');
const router = express.Router();
const CertificateController = require('../controllers/certificateController');
const { authMiddleware } = require('../middleware/auth');

// Protected routes
router.use(authMiddleware);

router.post('/course/:courseId/generate', CertificateController.generateCertificate);
router.get('/my', CertificateController.getUserCertificates);

// Public routes (for verification)
router.get('/:certificateId', CertificateController.getCertificate);
router.get('/:certificateId/verify', CertificateController.verifyCertificate);
router.get('/:certificateId/download', CertificateController.downloadCertificate);

module.exports = router;
