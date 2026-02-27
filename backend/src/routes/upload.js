const express = require('express');
const router = express.Router();
const multer = require('multer');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const { v4: uuidv4 } = require('uuid');
const { verifyToken } = require('../middleware/auth');
const { AppError } = require('../middleware/errorHandler');

const s3 = new S3Client({
  region: process.env.AWS_REGION || 'us-east-1',
  endpoint: process.env.S3_ENDPOINT,
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  },
  forcePathStyle: !!process.env.S3_ENDPOINT,
});

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 50 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const allowed = ['image/jpeg', 'image/png', 'image/webp', 'video/mp4', 'application/pdf'];
    if (allowed.includes(file.mimetype)) cb(null, true);
    else cb(new AppError('File type not allowed', 400, 'INVALID_FILE_TYPE'));
  },
});

router.post('/image', verifyToken, upload.single('file'), async (req, res) => {
  if (!req.file) throw new AppError('No file provided', 400, 'NO_FILE');

  const key = `uploads/${req.user.id}/${uuidv4()}-${req.file.originalname}`;
  const bucket = process.env.S3_BUCKET || 'eduai-uploads';

  await s3.send(new PutObjectCommand({
    Bucket: bucket,
    Key: key,
    Body: req.file.buffer,
    ContentType: req.file.mimetype,
    ACL: 'public-read',
  }));

  const url = process.env.S3_ENDPOINT
    ? `${process.env.S3_ENDPOINT}/${bucket}/${key}`
    : `https://${bucket}.s3.${process.env.AWS_REGION}.amazonaws.com/${key}`;

  res.json({ success: true, url, key });
});

module.exports = router;
