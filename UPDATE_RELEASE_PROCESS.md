# 🔄 FUFAJI STORE - UPDATE RELEASE PROCESS & VERSION MANAGEMENT

**Last Updated:** June 28, 2026  
**Version:** 1.0.0  
**Cadence:** Weekly updates (optional) or on-demand

---

## 📋 TABLE OF CONTENTS

1. [Version Numbering System](#version-numbering-system)
2. [Pre-Release Checklist](#pre-release-checklist)
3. [Backend Update Process](#backend-update-process)
4. [Mobile App Update Process](#mobile-app-update-process)
5. [Database Migration Process](#database-migration-process)
6. [Release Notes Creation](#release-notes-creation)
7. [Rollback Procedures](#rollback-procedures)
8. [Post-Release Monitoring](#post-release-monitoring)

---

## 📦 VERSION NUMBERING SYSTEM

Use **Semantic Versioning: MAJOR.MINOR.PATCH**

### Version Format: X.Y.Z

- **MAJOR (X)**: Breaking changes (database schema, API breaking changes)
  - Example: 1.0.0 → 2.0.0
  - Requires customer notification

- **MINOR (Y)**: New features, non-breaking changes
  - Example: 1.0.0 → 1.1.0
  - Safe to auto-update

- **PATCH (Z)**: Bug fixes, security patches
  - Example: 1.0.0 → 1.0.1
  - Critical updates, force deploy

### Current Versions:

```
Mobile App Version: 1.0.0 (Build: 1)
Backend API Version: 1.0.0
Database Schema Version: 1.0.0
```

---

## ✅ PRE-RELEASE CHECKLIST

Before EVERY release, verify:

- [ ] All code committed to git
- [ ] All tests passing locally
- [ ] Git branch is `main` (not feature branches)
- [ ] Latest `main` pulled from remote
- [ ] No uncommitted changes
- [ ] Backend secrets still valid
- [ ] Firebase console shows no errors
- [ ] Sentry shows no critical errors
- [ ] Database backups created
- [ ] Rollback procedure documented
- [ ] Release notes written
- [ ] QA sign-off received

**Pre-Release Commands:**
```bash
# Check git status
git status

# Should show: On branch main, nothing to commit, working tree clean

# Pull latest
git pull origin main

# Verify no uncommitted changes
git diff HEAD

# Backup database (if major update)
pg_dump -h mxjtgpunctckovtuyfmz.supabase.co \
        -U postgres \
        -d fufaji_store > backup_2026-06-28.sql

# Verify tests pass
flutter test
npm test
```

---

## 🔧 BACKEND UPDATE PROCESS

### Option 1: Supabase Edge Functions Update

**Step 1: Update Function Code**

```bash
cd C:\Projects\fufaji-online-business

# Edit function (example)
# supabase/functions/auth-endpoints/index.ts
# [Make your code changes]

# Stage changes
git add supabase/functions/

# Commit
git commit -m "feat(auth): add phone OTP rate limiting"

# Push to main
git push origin main
```

**Step 2: Test Locally (Optional)**

```bash
# Start local Supabase instance (if needed)
supabase start

# Test function locally
supabase functions serve auth-endpoints --env-file .env

# Expected: Server running at http://localhost:54321

# Test with curl in another terminal
curl -X POST http://localhost:54321/functions/v1/auth-endpoints \
  -H "Content-Type: application/json" \
  -d '{"action":"test"}'
```

**Step 3: Deploy to Production**

```bash
# Verify you're logged in
supabase status

# Deploy single function
supabase functions deploy auth-endpoints

# Or deploy all functions
supabase functions deploy

# Expected output:
# ✓ Function auth-endpoints deployed successfully
# Endpoint: https://mxjtgpunctckovtuyfmz.supabase.co/functions/v1/auth-endpoints
```

**Step 4: Verify Deployment**

```bash
# List deployed functions
supabase functions list

# Test production endpoint
curl -X POST "https://mxjtgpunctckovtuyfmz.supabase.co/functions/v1/auth-endpoints" \
  -H "Content-Type: application/json" \
  -d '{"action":"test"}'

# Check Sentry for errors
# Go to: https://sentry.io/organizations/your-org/issues/
```

### Option 2: Railway.app Backend Update

**Step 1: Update Code**

```bash
# Make code changes
# [Edit files]

# Commit changes
git add .
git commit -m "feat: add email verification"

# Push to main
git push origin main
```

**Step 2: Deploy to Railway**

```bash
# If using GitHub integration (automatic):
# Railway automatically deploys on git push to main

# Or manual deploy via CLI:
railway up

# Expected: Deployment successful
```

**Step 3: Verify Deployment**

```bash
# View deployment logs
railway logs

# Expected output:
# Server listening on port 3000
# Database connected
# Ready to serve requests

# Test endpoint
curl -X GET https://your-railway-domain.railway.app/health

# Expected: { "status": "ok" }
```

### Option 3: Render.com Backend Update

**Step 1: Update Code**

```bash
# Make code changes
# [Edit files]

# Commit changes
git add .
git commit -m "fix: resolve payment webhook race condition"

# Push to main
git push origin main
```

**Step 2: Deploy to Render**

```bash
# If using GitHub integration (automatic):
# Render automatically deploys on git push

# Or trigger manual deploy in Dashboard:
# Dashboard → Web Service → Manual Deploy
```

**Step 3: Verify Deployment**

```bash
# View deployment logs
# Dashboard → Logs

# Expected:
# Build successful
# App started on port 3000

# Test endpoint
curl https://your-render-domain.onrender.com/health

# Expected: { "status": "ok" }
```

---

## 📱 MOBILE APP UPDATE PROCESS

### Step 1: Update Version Numbers

**Location:** `pubspec.yaml`

```yaml
version: 1.0.1+2  # major.minor.patch+build_number
# Increment when:
# - 1.0.1: Patch fix (1.0.0 → 1.0.1)
# - 1.1.0: New feature (1.0.1 → 1.1.0)
# - 2.0.0: Breaking change (1.1.0 → 2.0.0)
# - Build number: Always increment (1 → 2 → 3)
```

**Location:** `android/app/build.gradle`

```gradle
defaultConfig {
    applicationId "com.fufaji.store"
    minSdkVersion 21
    targetSdkVersion 33
    versionCode 2           // increment from 1
    versionName "1.0.1"     // match pubspec.yaml
}
```

### Step 2: Update App Code

```bash
cd C:\Projects\fufaji-online-business

# Make necessary changes
# [Edit lib/ files]

# Get latest packages
flutter pub get

# Run tests
flutter test

# Expected: All tests pass
```

### Step 3: Build Release APK/AAB

```bash
# Set environment variables
$env:KEYSTORE_PASSWORD = "your-keystore-password"
$env:KEY_ALIAS = "fufaji-store"
$env:KEY_PASSWORD = "your-key-password"

# Build AAB (preferred for Play Store)
flutter build appbundle --release

# Output: build/app/outputs/bundle/release/app-release.aab

# OR build APK (for direct distribution)
flutter build apk --release

# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Step 4: Verify APK/AAB

```bash
# Check file exists
ls -l build/app/outputs/bundle/release/app-release.aab

# Expected: ~20-30 MB for AAB

# Install on test device (APK only)
adb install build/app/outputs/flutter-apk/app-release.apk

# Test on device:
# 1. Login with all 3 auth methods
# 2. Create test order
# 3. Test payment
# 4. Verify no crashes in logcat
flutter logs
```

### Step 5: Upload to Google Play Store

**For Production Release:**

1. Go to: https://play.google.com/console
2. Select "Fufaji Store" app
3. Release → Production
4. Create Release
5. Upload AAB: `build/app/outputs/bundle/release/app-release.aab`
6. Fill Release Notes:
   ```
   Version 1.0.1 - Bug Fixes and Improvements
   
   • Fixed payment webhook processing
   • Added email verification
   • Improved error messages
   • Performance optimizations
   
   Known issues: None
   ```
7. Review everything
8. Click "Start rollout to production"

**For Beta Testing (Recommended First):**

1. Release → Open testing (or Closed testing)
2. Upload AAB
3. Add testers
4. Wait 2-24 hours for review
5. Send to testers
6. Collect feedback
7. Move to production after testing

### Step 6: Monitor Rollout

**Google Play Console:**

1. Release → Production → Rollout details
2. Watch metrics:
   - Install growth
   - Crash rate (should stay <0.1%)
   - Rating change
3. If issues found:
   - Pause rollout
   - Investigate via Sentry
   - Publish hotfix

**Sentry Dashboard:**

1. Go to: https://sentry.io
2. Select "Fufaji Store Mobile"
3. Monitor crash rate during rollout
4. Expected: No new errors

---

## 🗄️ DATABASE MIGRATION PROCESS

### Step 1: Create Migration File

**Location:** `supabase/migrations/[timestamp]_[description].sql`

Example: `supabase/migrations/20260628120000_add_email_verification.sql`

```sql
-- Description: Add email verification support
-- Created: 2026-06-28
-- Breaking: No

-- Add new column
ALTER TABLE users ADD COLUMN email_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN email_verified_at TIMESTAMPTZ;

-- Create index
CREATE INDEX idx_users_email_verified ON users(email_verified);

-- Create audit log
INSERT INTO audit_log (action, table_name, description)
VALUES ('schema_change', 'users', 'Added email verification columns');

-- Rollback command (save for emergencies):
-- ALTER TABLE users DROP COLUMN email_verified;
-- ALTER TABLE users DROP COLUMN email_verified_at;
-- DROP INDEX idx_users_email_verified;
```

### Step 2: Test Migration Locally (Optional)

```bash
# Start local Supabase
supabase start

# Push migration to local database
supabase db push

# Verify table structure
supabase db diff
```

### Step 3: Deploy Migration

**Before deploying, backup database:**

```bash
# Create backup
pg_dump -h mxjtgpunctckovtuyfmz.supabase.co \
        -U postgres \
        -d fufaji_store > backup_before_migration_$(date +%s).sql

# Upload backup to secure location
# Google Drive / USB Drive / Secure Server
```

**Deploy migration:**

```bash
# Push migration to production database
supabase db push

# Expected output:
# ✓ Running migration [timestamp]_add_email_verification.sql

# Verify migration applied
# In Supabase SQL Editor, run:
# \d users  -- shows table structure
```

### Step 4: Verify Migration

```sql
-- In Supabase SQL Editor, verify:

-- Check new columns exist
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'users' AND column_name IN ('email_verified', 'email_verified_at');

-- Should return 2 rows

-- Check data integrity
SELECT COUNT(*) FROM users;
-- Compare with previous count (should match)

-- Check indexes
SELECT indexname FROM pg_indexes WHERE tablename = 'users' AND indexname LIKE '%email%';
```

---

## 📝 RELEASE NOTES CREATION

### Template for Release Notes

**Location:** `RELEASE_NOTES_v1.0.1.md` (create new file for each release)

```markdown
# Fufaji Store - Version 1.0.1

**Release Date:** June 28, 2026  
**Build Number:** 2  
**Status:** Production

## What's New

### Features ✨
- Email verification for new signups
- Real-time order status tracking
- Delivery GPS map with ETA

### Fixes 🐛
- Fixed payment webhook processing race condition
- Fixed wallet stock deduction for wallet orders
- Fixed return/damage form photo upload
- Fixed rider order query mismatch with live packing status

### Improvements 🚀
- Improved error messages for better user guidance
- Faster checkout process (2s → 1s)
- Better performance on low-bandwidth connections
- Improved Sentry error reporting

### Known Issues ⚠️
- Return requests may take 24 hours to process
- GPS tracking requires location permission
- Email delivery may be delayed during high load

## Security Updates 🔒
- HMAC-SHA256 signature verification for all Razorpay webhooks
- Field-level access control for user roles
- Rate limiting on OTP endpoints (3 per hour per phone)

## Technical Details

### Backend Changes
- Supabase Edge Functions: 3 updates
- Database schema: 1 migration
- API version: 1.0.0 (no breaking changes)

### Mobile App Changes
- Flutter: No version update
- Target SDK: 33
- Min SDK: 21

### Database Schema
- Added columns: `users.email_verified`, `users.email_verified_at`
- Migrations run: 1 (20260628120000_add_email_verification)

## How to Update

### Mobile App Users
- Update from Google Play Store
- Or download APK from: https://github.com/kali-Gaurav/fufajis-online-business/releases

### Developers
- Pull latest from `main` branch
- Run `flutter pub get`
- Run `supabase db push` for migrations

## Support
- Report bugs: https://github.com/kali-Gaurav/fufajis-online-business/issues
- Email: support@fufaji.com
- Chat: In-app help

## Acknowledgments
Thanks to all testers and contributors who made this release possible!

---

**Previous Versions:**
- [1.0.0 Release Notes](RELEASE_NOTES_v1.0.0.md)
```

### Generate Release Notes

```bash
# Generate from git log
git log v1.0.0..HEAD --oneline --pretty=format:"%h - %s" > RELEASE_NOTES_DRAFT.txt

# Categories (manually edit):
# - Features (feat:)
# - Bug fixes (fix:)
# - Improvements (perf:, refactor:)
# - Security (security:)
```

---

## 🔙 ROLLBACK PROCEDURES

### Scenario: Critical Bug After Release

#### Step 1: Identify Issue

```bash
# Check Sentry for errors
# Look for crash rate spike
# If crash rate > 5%, trigger rollback

# Example Sentry spike:
# - Crash rate jumped from 0.1% to 5% after 1.0.1 release
# - 1000+ users affected
# - Error: "NullPointerException in PaymentService"
```

#### Step 2: Immediate Mitigation

**For Mobile App:**

```bash
# Pause rollout in Google Play Console:
# 1. Release → Production → Rollout details
# 2. Click "Pause rollout"
# 3. Wait 30 minutes for all users to stop updating
```

**For Backend:**

```bash
# Revert function code
git revert [commit-hash]
git push origin main

# Deploy previous version
supabase functions deploy auth-endpoints
```

#### Step 3: Rollback Database (If Needed)

```bash
# Restore from backup
# Only if migration caused data corruption

psql -h mxjtgpunctckovtuyfmz.supabase.co \
     -U postgres \
     -d fufaji_store < backup_before_migration_timestamp.sql

# Verify restoration
SELECT COUNT(*) FROM users;
# Compare with backup count
```

#### Step 4: Communication

Send notification to users:

```
Subject: Fufaji Store - Version 1.0.1 Pause

Hello,

We temporarily paused the rollout of version 1.0.1 due to a critical issue. 
If you've already updated, please clear app cache and restart.

We're working on a fix and will release version 1.0.2 within 24 hours.

Sorry for the inconvenience!
Fufaji Team
```

#### Step 5: Root Cause Analysis

```bash
# Review error logs
# Analyze Sentry full stack trace
# Check git diff between v1.0.0 and v1.0.1
git diff v1.0.0 v1.0.1

# Find the problematic commit
git bisect start
git bisect bad v1.0.1
git bisect good v1.0.0
# Follow git bisect prompts

# Once found, create hotfix
git checkout -b hotfix/payment-service-nullpointer
# Fix the issue
git commit -am "fix: handle null payment in PaymentService"
git push origin hotfix/...
# Merge to main
git checkout main
git merge hotfix/...
```

#### Step 6: Release Hotfix

```bash
# Increment patch version: 1.0.1 → 1.0.2
# In pubspec.yaml: version: 1.0.2+3

# Build new release
flutter build appbundle --release

# Upload to Play Store (expedited review requested)

# Notify users:
# "Version 1.0.2 with critical fix now available"
```

---

## 📊 POST-RELEASE MONITORING

### First 24 Hours

**Metrics to Track:**

```
1. Crash Rate
   - Target: < 0.1%
   - Alert: > 1%
   - Check every 30 minutes

2. Install Growth
   - Target: 100+ installs/hour
   - Alert: < 50/hour (indicates problems)

3. 1-Star Reviews
   - Watch for spike
   - Read recent reviews
   - If > 5 new 1-star: investigate

4. Server Load
   - CPU usage (should stay < 50%)
   - Memory usage (should stay < 60%)
   - Request latency (should stay < 500ms)

5. Database Health
   - Connection count (should stay < 100)
   - Query latency (should stay < 100ms)
   - Replication lag (should stay < 1s)
```

### Monitoring Commands

```bash
# Check Sentry
# https://sentry.io/organizations/your-org/issues/

# Check Firebase Analytics
# https://console.firebase.google.com/project/[id]/analytics

# Check Database Logs
# Supabase Dashboard → Logs → Database

# Check Edge Function Logs
# Supabase Dashboard → Edge Functions → Logs

# Check Railway/Render Logs
# Railway: railway logs
# Render: Dashboard → Logs
```

### Daily Metrics Report (Template)

**Create:** `MONITORING_REPORT_2026-06-28.txt`

```
DATE: June 28, 2026
VERSION: 1.0.1
BUILD: 2

STABILITY
- Crash Rate: 0.05% ✅
- ANRs: 0 ✅
- Server Downtime: 0s ✅

GROWTH
- New Installs: 523 ✅
- Active Users: 2,341 ✅
- Average Session: 8 min 23 sec ✅

PERFORMANCE
- App Start Time: 2.3s ✅
- Checkout Completion: 45 sec ✅
- Payment Processing: 1.2s ✅

ERRORS
- Critical: 0 ✅
- Major: 2 ⚠️ (being investigated)
- Minor: 15 (expected)

API HEALTH
- Auth Endpoint: 99.9% uptime ✅
- Payment Endpoint: 99.8% uptime ✅
- Error Rate: 0.1% ✅

DATABASE
- Replication Lag: 0.2s ✅
- Connection Count: 45/100 ✅
- Query Latency: 85ms ✅

ALERTS
- None at this moment

NEXT ACTIONS
- Monitor "major" errors from session XX
- Verify wallet payment fix in v1.0.1
```

### Weekly Review

**Schedule:** Every Monday at 10 AM

```bash
# Generate weekly report
# Compare metrics from previous week
# Identify trends

# Checklist:
- [ ] Crash rate trending down?
- [ ] User base growing?
- [ ] No new critical issues?
- [ ] Performance within SLA?
- [ ] Database healthy?
- [ ] All Edge Functions responding?

# If all pass: Release notes for week
# If issues: Create urgent tickets
```

---

## 🎯 RELEASE SCHEDULE

### Recommended Cadence

**Security Patches:** Every 2 weeks (or on-demand)
**Bug Fixes:** Weekly
**Features:** Every 2-4 weeks

### Example Schedule

```
Week of June 28, 2026:
- Jun 28 (Today): Release 1.0.1 (bug fixes)
- Jul 05: Release 1.1.0 (features: email verification, delivery map)
- Jul 12: Release 1.0.2 (security: rate limiting, HMAC verification)

Week of July 12, 2026:
- Jul 19: Release 1.1.1 (bug fixes from 1.1.0)
- Jul 26: Release 1.2.0 (features: loyalty program, cart sharing)

Q3 2026:
- Aug XX: Release 2.0.0 (major: new database schema, breaking API changes)
```

---

## 📞 RELEASE COORDINATOR ROLE

### Responsibilities

- [ ] Verify pre-release checklist
- [ ] Write release notes
- [ ] Create git tags
- [ ] Build APK/AAB
- [ ] Upload to Play Store
- [ ] Deploy backend functions
- [ ] Monitor first 24 hours
- [ ] Create incident tickets if needed
- [ ] Send release communication

### Release Communication Template

**To:** Team (Slack, Email)
**Subject:** 🚀 Fufaji Store v1.0.1 Released

```
Version 1.0.1 is now live!

📱 Mobile App: Available on Google Play Store
🔧 Backend: Deployed to production
📊 Database: Schema updated (1 migration)

🎯 Highlights:
- Fixed payment webhook race condition
- Added email verification
- Improved error messages

📈 Rollout Progress:
- 0% (Paused for testing)
- Will gradually increase to 100% over 7 days

⏰ Monitoring:
- Crash rate: 0.05% ✅
- Server health: 99.9% ✅
- No critical errors ✅

🆘 Report issues: Create GitHub issue or email support@fufaji.com

🙏 Thanks for using Fufaji Store!
```

---

**Ready for your next release? Follow this guide step-by-step and you'll ship safely and confidently!**
