// Real AWS S3 presign helpers. Replaces the old aws_services.js S3 code, which
// actually pointed at Supabase Storage's S3-compatible endpoint. We're dropping
// Supabase, so this targets the real AWS bucket (bucket-ofqh8w).
//
// No static access keys: the S3Client uses the Lambda execution role (granted
// s3:PutObject/GetObject/DeleteObject in template.yaml), so there are no S3
// secrets to store or rotate.

const {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
  DeleteObjectCommand,
} = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');

const REGION = process.env.AWS_REGION || 'ap-south-1';
const BUCKET = process.env.S3_BUCKET || 'bucket-ofqh8w';
const MAX_EXPIRY = 3600; // 1 hour cap, same as old backend

const client = new S3Client({ region: REGION });

async function presignUpload({ key, contentType, expiresIn }) {
  const cmd = new PutObjectCommand({ Bucket: BUCKET, Key: key, ContentType: contentType });
  const url = await getSignedUrl(client, cmd, { expiresIn: Math.min(expiresIn || 900, MAX_EXPIRY) });
  const publicUrl = `https://${BUCKET}.s3.${REGION}.amazonaws.com/${key}`;
  return { url, key, bucket: BUCKET, publicUrl };
}

async function presignDownload({ key, expiresIn }) {
  const cmd = new GetObjectCommand({ Bucket: BUCKET, Key: key });
  const url = await getSignedUrl(client, cmd, { expiresIn: Math.min(expiresIn || 900, MAX_EXPIRY) });
  return { url, key, bucket: BUCKET };
}

async function deleteObject(key) {
  await client.send(new DeleteObjectCommand({ Bucket: BUCKET, Key: key }));
}

module.exports = { presignUpload, presignDownload, deleteObject, BUCKET };
