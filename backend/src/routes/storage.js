// Ported from aws_services.js:
//   getS3UploadUrl   -> POST /storage/upload-url   (any signed-in user)
//   getS3DownloadUrl -> POST /storage/download-url (any signed-in user)
//   deleteS3Object   -> POST /storage/delete       (admin / shop owner)
//
// Response field names match the old callables so s3_storage_service.dart works
// after its base URL is switched: { success, uploadUrl, key, bucket, publicUrl,
// expiresIn } / { success, downloadUrl, ... }.

const express = require('express');
const router = express.Router();
const s3 = require('../lib/s3');
const { verifyToken, requireRole } = require('../auth');

router.post('/upload-url', verifyToken, async (req, res) => {
  try {
    const { key, contentType, expiresIn } = req.body || {};
    if (!key) return res.status(400).json({ success: false, error: 'Missing key' });
    const r = await s3.presignUpload({ key, contentType, expiresIn });
    return res.json({
      success: true,
      uploadUrl: r.url,
      key: r.key,
      bucket: r.bucket,
      publicUrl: r.publicUrl,
      expiresIn: expiresIn || 900,
    });
  } catch (e) {
    console.error('[S3 upload-url]', e);
    return res.status(500).json({ success: false, error: e.message });
  }
});

router.post('/download-url', verifyToken, async (req, res) => {
  try {
    const { key, expiresIn } = req.body || {};
    if (!key) return res.status(400).json({ success: false, error: 'Missing key' });
    const r = await s3.presignDownload({ key, expiresIn });
    return res.json({ success: true, downloadUrl: r.url, key: r.key, bucket: r.bucket, expiresIn: expiresIn || 900 });
  } catch (e) {
    console.error('[S3 download-url]', e);
    return res.status(500).json({ success: false, error: e.message });
  }
});

router.post(
  '/delete',
  verifyToken,
  requireRole('UserRole.admin', 'UserRole.shopOwner'),
  async (req, res) => {
    try {
      const { key } = req.body || {};
      if (!key) return res.status(400).json({ success: false, error: 'Missing key' });
      await s3.deleteObject(key);
      return res.json({ success: true });
    } catch (e) {
      console.error('[S3 delete]', e);
      return res.status(500).json({ success: false, error: e.message });
    }
  }
);

module.exports = router;
