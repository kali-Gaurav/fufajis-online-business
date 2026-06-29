#!/usr/bin/env node
'use strict';

require('dotenv').config();

const fs = require('fs');
const path = require('path');
const {
  S3Client,
  PutBucketLifecycleConfigurationCommand,
  GetBucketLifecycleConfigurationCommand,
} = require('@aws-sdk/client-s3');

/**
 * Apply (or preview) the S3 bucket lifecycle configuration defined in
 * lifecycle-policy.json to the Fufaji Store bucket.
 *
 * This implements task #45 ("Add S3 image storage lifecycle rules"):
 * automatic storage-class transitions and expirations for the
 * S3Paths prefixes used by lib/services/s3_storage_service.dart
 * (backups/, users/, orders/, marketing/, products/, vendors/, uploads/).
 *
 * See docs/S3_LIFECYCLE_POLICY.md for the rationale behind each rule.
 *
 * Usage:
 *   cd infra/s3 && npm install
 *
 *   node apply_lifecycle_policy.js --dry-run   # print current + proposed config, no changes
 *   node apply_lifecycle_policy.js             # apply lifecycle-policy.json to the bucket
 *   node apply_lifecycle_policy.js --verify    # fetch and print the bucket's current config
 *
 * Required environment variables (same convention as functions/aws_services.js,
 * i.e. `firebase functions:config:get aws` or your own .env):
 *   AWS_S3_ACCESS_KEY, AWS_S3_SECRET_KEY, AWS_S3_REGION (default ap-south-1),
 *   AWS_S3_BUCKET (default bucket-ofqh8w), AWS_S3_ENDPOINT (optional)
 */

const DEFAULT_BUCKET = 'bucket-ofqh8w';
const DEFAULT_REGION = 'ap-south-1';

function getS3Client() {
  const region = process.env.AWS_S3_REGION || DEFAULT_REGION;
  const accessKeyId = process.env.AWS_S3_ACCESS_KEY;
  const secretAccessKey = process.env.AWS_S3_SECRET_KEY;

  if (!accessKeyId || !secretAccessKey) {
    throw new Error(
      'AWS_S3_ACCESS_KEY / AWS_S3_SECRET_KEY are not set. Copy .env.example to .env and fill in ' +
        'the same credentials used by functions/aws_services.js (functions.config().aws.s3_*).'
    );
  }

  const config = { region, credentials: { accessKeyId, secretAccessKey } };
  if (process.env.AWS_S3_ENDPOINT) {
    config.endpoint = `https://${process.env.AWS_S3_ENDPOINT}`;
  }
  return new S3Client(config);
}

function getBucket() {
  return process.env.AWS_S3_BUCKET || DEFAULT_BUCKET;
}

function loadPolicy() {
  const file = path.join(__dirname, 'lifecycle-policy.json');
  const raw = JSON.parse(fs.readFileSync(file, 'utf8'));
  // Strip the documentation-only `_comment` key before sending to AWS.
  const { _comment, ...rest } = raw;
  return rest;
}

async function getCurrent(client, bucket) {
  try {
    const res = await client.send(new GetBucketLifecycleConfigurationCommand({ Bucket: bucket }));
    return res.Rules || [];
  } catch (err) {
    if (err.name === 'NoSuchLifecycleConfiguration') return [];
    throw err;
  }
}

async function main() {
  const args = process.argv.slice(2);
  const dryRun = args.includes('--dry-run') || args.includes('--dry');
  const verifyOnly = args.includes('--verify');

  const bucket = getBucket();
  const client = getS3Client();
  const policy = loadPolicy();

  if (verifyOnly) {
    const current = await getCurrent(client, bucket);
    console.log(`[s3-lifecycle] Current lifecycle rules on bucket "${bucket}":`);
    console.log(JSON.stringify(current, null, 2));
    return;
  }

  const current = await getCurrent(client, bucket);
  console.log(`[s3-lifecycle] Bucket: ${bucket} (region ${process.env.AWS_S3_REGION || DEFAULT_REGION})`);
  console.log(`[s3-lifecycle] Current rule count: ${current.length}`);
  console.log(`[s3-lifecycle] Proposed rule count: ${policy.Rules.length}`);
  console.log('[s3-lifecycle] Proposed configuration:');
  console.log(JSON.stringify(policy, null, 2));

  if (dryRun) {
    console.log('[s3-lifecycle] --dry-run: no changes applied.');
    return;
  }

  await client.send(
    new PutBucketLifecycleConfigurationCommand({
      Bucket: bucket,
      LifecycleConfiguration: policy,
    })
  );
  console.log('[s3-lifecycle] Lifecycle configuration applied successfully.');
}

main().catch((err) => {
  console.error('[s3-lifecycle] Fatal error:', err);
  process.exit(1);
});
