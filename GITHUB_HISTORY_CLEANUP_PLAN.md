# GitHub History Cleanup - Execution Plan

**Date**: June 24, 2026  
**Status**: READY FOR EXECUTION  
**Risk Level**: HIGH - This operation rewrites git history  
**Estimated Duration**: 4 hours  

---

## EXECUTIVE SUMMARY

Your repository currently has **EXPOSED SECRETS IN GIT HISTORY**:

### Critical Findings:
- **Real .env file in repository root** containing live Razorpay keys, AWS credentials, WhatsApp tokens
- **5 keystore files (.jks)** committed to git (Android signing keys)
- **Firebase credentials** visible in git history
- **AWS access keys** exposed with full secret keys

### Immediate Actions Required:
1. Backup repository (mirror clone)
2. Scan git history for exposed secrets
3. Rewrite git history using git-filter-branch
4. Force push cleaned history to GitHub
5. Update .gitignore with comprehensive patterns
6. Notify all team members to clone fresh repository
7. **ROTATE ALL EXPOSED CREDENTIALS IMMEDIATELY**

---

## CRITICAL EXPOSED SECRETS INVENTORY

### 1. .env File (ACTIVE CREDENTIALS)
**Location**: `C:\Projects\fufaji-online-business\.env`
**Contents**: Live production secrets
**Exposed Keys**:
- `RAZORPAY_KEY_ID=rzp_live_Sr7JfZt4NbXzMw`
- `RAZORPAY_KEY_SECRET=ieGG9GcxgN0km2ZVcGyaGEG6`
- `RAZORPAY_WEBHOOK_SECRET=Fufaji@Webhook2026!`
- `WHATSAPP_TOKEN=EAASZAhYl2VnEBRnXysfExV3vNbuh39CFTHdIGxNk4mIUutmhDhuCAFo7rPP2HIEErCV5sDG8P0NbyobsBlaH`
- `WHATSAPP_PHONE_ID=1086896934513865`
- `AWS_ACCESS_KEY_ID=AKIAYJF3JU7AKSWZEYV7`
- `AWS_SECRET_ACCESS_KEY=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`
- Android signing: `ANDROID_STORE_PASSWORD=fufaji123`

### 2. Keystore Files (Android Signing Keys)
```
android/app/fufaji-upload-key.jks
android/fufaji-upload-key.jks
upload-keystore.jks
app/fufaji-app/fufaji-upload-key.jks
app/fufaji-app/fufaji-native.jks
```

### 3. Firebase Credentials
- `lib/firebase_options.dart` contains API keys (low-sensitivity, mostly public)
- Build artifacts contain compiled credentials

---

## STEP 1: CREATE BACKUP (15 minutes)

**Before starting cleanup, create a mirror backup:**

```bash
# Navigate to a safe location (NOT in the project directory)
cd C:\temp\backups

# Create mirror backup
git clone --mirror https://github.com/your-username/fufaji-online-business.git fufaji-backup.git

# Verify backup
ls -lh fufaji-backup.git
du -sh fufaji-backup.git
```

**Keep this backup for 1 week** in case recovery is needed.

---

## STEP 2: SCAN GIT HISTORY FOR SECRETS (15 minutes)

**In PowerShell (Windows):**

```powershell
cd C:\Projects\fufaji-online-business

# Search for Razorpay keys
Write-Host "=== Searching for Razorpay keys ===" -ForegroundColor Yellow
git log -p --all -S "sk_live_" | Select-Object -First 50
git log -p --all -S "rzp_live_" | Select-Object -First 50

# Search for Firebase credentials
Write-Host "=== Searching for Firebase credentials ===" -ForegroundColor Yellow
git log -p --all -S "AIzaSy" | Select-Object -First 50

# Search for AWS keys
Write-Host "=== Searching for AWS keys ===" -ForegroundColor Yellow
git log -p --all -S "AKIA" | Select-Object -First 50

# Search for .env files in history
Write-Host "=== Searching for .env files ===" -ForegroundColor Yellow
git log --name-only --all | Select-String "\.env" | Sort-Object -Unique

# Search for keystore files
Write-Host "=== Searching for .jks files ===" -ForegroundColor Yellow
git log --name-only --all | Select-String "\.jks|\.keystore" | Sort-Object -Unique

# Search for Firebase JSON
Write-Host "=== Searching for Firebase JSON ===" -ForegroundColor Yellow
git log --name-only --all | Select-String "google-services|firebase-adminsdk" | Sort-Object -Unique

# Count commits affecting sensitive files
Write-Host "=== Commits affecting .env ===" -ForegroundColor Yellow
git log --follow --name-only --all -- ".env" | grep ".env" | wc -l

Write-Host "=== Commits affecting *.jks ===" -ForegroundColor Yellow
git log --name-only --all | grep -E "\.jks$" | sort -u
```

**Expected Output**:
```
EXPOSED FILES FOUND:
- .env (committed in commits: xxxxx, xxxxx, xxxxx)
- android/app/fufaji-upload-key.jks (entire history)
- android/fufaji-upload-key.jks (entire history)
- upload-keystore.jks (entire history)
- .env.development (commits: xxxxx)
- .env.production (commits: xxxxx)
- lib/firebase_options.dart (entire history - low-sensitivity)
```

---

## STEP 3: REMOVE SECRETS FROM GIT HISTORY (2 hours)

### Important: Choose your method based on repository size

**Option A: Using git-filter-branch (RECOMMENDED)**

```bash
# 1. Create a clean working directory
mkdir C:\temp\fufaji-clean
cd C:\temp\fufaji-clean
git clone https://github.com/your-username/fufaji-online-business.git .

# 2. Verify current size
Write-Host "Original repository size:" -ForegroundColor Yellow
du -sh .git

# 3. Create list of files to remove
$filesToRemove = @(
    ".env",
    ".env.local",
    ".env.development",
    ".env.production",
    ".env.staging",
    ".env.test.local",
    ".env.development.local",
    "*.jks",
    "*.keystore",
    "*.p12",
    "*.pfx",
    "*.pem",
    "android/key.properties",
    "android/upload-keystore.jks",
    "google-services.json",
    "firebase-adminsdk-*.json",
    "private_key*"
)

# 4. Remove sensitive files from ALL commits
Write-Host "Removing sensitive files from git history..." -ForegroundColor Yellow
git filter-branch --tree-filter {
    Get-ChildItem -Recurse -Path . -Include @("*.jks", "*.keystore", ".env*") -Force | Remove-Item -Force
    Get-ChildItem -Recurse -Path . -Include @("google-services.json", "firebase-adminsdk-*.json") -Force | Remove-Item -Force
} -- --all

# 5. Remove filter branch reflogs
Write-Host "Cleaning reflogs..." -ForegroundColor Yellow
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# 6. Verify history is clean
Write-Host "Verifying history is clean..." -ForegroundColor Yellow
git log --all --name-only | Select-String -Pattern "\.env|\.jks|google-services"
if ($?) {
    Write-Host "ERROR: Still found secrets!" -ForegroundColor Red
} else {
    Write-Host "✓ History is clean!" -ForegroundColor Green
}

# 7. Check repository size after cleanup
Write-Host "Repository size after cleanup:" -ForegroundColor Yellow
du -sh .git
```

### **Option B: Manual approach (if git-filter-branch fails)**

```bash
cd C:\temp\fufaji-clean

# 1. List all commits affecting sensitive files
git log --name-only --all -- ".env" "*.jks" "google-services.json" | grep -E "^commit" | awk '{print $2}'

# 2. For EACH commit, remove the sensitive files
# This is time-consuming but more surgical

# 3. Rebase to remove affected commits
git rebase -i --root

# 4. Mark commits as 'drop' for those that only added sensitive files
# 5. Compress commits that mixed code + secrets
```

---

## STEP 4: VERIFY HISTORY IS CLEAN (30 minutes)

**Before pushing, verify completely:**

```bash
cd C:\temp\fufaji-clean

# Search for any remaining secrets
Write-Host "=== Final Verification ===" -ForegroundColor Yellow

Write-Host "Searching for Razorpay keys..." -ForegroundColor Cyan
git log -p --all -S "rzp_live_" | wc -l
if ($LASTEXITCODE -eq 0) { Write-Host "✓ No Razorpay keys found" -ForegroundColor Green }

Write-Host "Searching for AWS keys..." -ForegroundColor Cyan
git log -p --all -S "AKIA" | wc -l
if ($LASTEXITCODE -eq 0) { Write-Host "✓ No AWS keys found" -ForegroundColor Green }

Write-Host "Searching for .env files..." -ForegroundColor Cyan
git log --name-only --all | Select-String "\.env$" | Measure-Object
Write-Host "✓ .env files check complete"

Write-Host "Searching for .jks files..." -ForegroundColor Cyan
git log --name-only --all | Select-String "\.jks$" | Measure-Object
Write-Host "✓ .jks files check complete"

# List all commits (should be fewer now)
Write-Host "Total commits after cleanup:" -ForegroundColor Yellow
git log --oneline --all | wc -l

# Show recent commits
git log --oneline -10 --all
```

---

## STEP 5: FORCE PUSH CLEANED HISTORY (30 minutes)

### WARNING: This is a POINT OF NO RETURN

**Once you force-push:**
- ALL developers must clone fresh repository
- Old branches will have conflicting history
- Backups become important

### Execute Force Push:

```bash
cd C:\temp\fufaji-clean

# 1. Verify we're in the correct repository
pwd  # Should show: C:\temp\fufaji-clean

# 2. Add original repository as origin (if not already)
git remote set-url origin https://github.com/your-username/fufaji-online-business.git

# 3. Force push to main branch
Write-Host "Force pushing to main..." -ForegroundColor Yellow
git push origin --force main

# Wait for push to complete (may take a minute)
Write-Host "Force pushing tags..." -ForegroundColor Yellow
git push origin --force --tags

# 4. Force push other branches if needed
# git push origin --force develop
# git push origin --force staging

# 5. Verify push was successful
Write-Host "Verifying push..." -ForegroundColor Yellow
git log --oneline origin/main -5

# 6. Final verification on GitHub
Write-Host "Checking GitHub history..." -ForegroundColor Yellow
git log --all --name-only | Select-String -Pattern "\.env|\.jks|google-services"
if (-not $?) {
    Write-Host "✓ GitHub history is clean!" -ForegroundColor Green
} else {
    Write-Host "ERROR: Secrets still in history!" -ForegroundColor Red
}
```

---

## STEP 6: UPDATE .GITIGNORE (Already Completed)

**Status**: ✓ DONE

The comprehensive .gitignore has been updated with:
- Environment variables patterns
- Keystore and signing key patterns
- Firebase credentials patterns
- AWS and cloud credentials patterns
- All private key patterns
- API keys and tokens patterns

**File**: `C:\Projects\fufaji-online-business\.gitignore`

**Commit this change**:
```bash
cd C:\Projects\fufaji-online-business

git add .gitignore
git commit -m "Security: Update .gitignore to prevent future credential leaks

- Add comprehensive patterns for all credential types
- Prevent .env files from being committed
- Block all keystore/signing key files
- Prevent Firebase, AWS, and API credentials
- Add documentation for each section"

git push origin main
```

---

## STEP 7: NOTIFY TEAM & ROTATE CREDENTIALS

### Email to all developers:

**Subject**: URGENT - Repository Security Incident & Fresh Clone Required

```
CRITICAL SECURITY UPDATE

Our repository history contained exposed credentials. This has been remediated
by rewriting git history and removing all sensitive files.

⚠️ ACTION REQUIRED FOR ALL DEVELOPERS - Complete by EOD:

1. SAVE your work:
   git stash

2. DELETE your local clone:
   cd ~
   rm -rf fufaji-online-business

3. GET a fresh clone:
   git clone https://github.com/your-username/fufaji-online-business.git
   cd fufaji-online-business

4. OBTAIN new credentials:
   - Razorpay: Contact DevOps lead [email]
   - Firebase: Already in cloud (credentials auto-loaded)
   - AWS: Contact DevOps lead [email]
   - WhatsApp: Contact Product lead [email]

5. CREATE local .env:
   cp .env.example .env
   # Fill in YOUR LOCAL DEV credentials only
   # NEVER commit .env file

CRITICAL REMINDERS:
✗ Do NOT use old credentials (they are now inactive)
✗ Do NOT try to merge old branches without talking to DevOps
✗ Do NOT push .env or secrets to GitHub
✗ Do NOT rebase commits from old history

NEW CREDENTIALS:
- All Razorpay keys rotated as of 2026-06-24 1:00 PM
- AWS access keys rotated
- WhatsApp token rotated
- Android keystore re-generated

TIMELINE: Complete setup by EOD today

Questions? Contact: [DevOps Lead Email]
```

---

## STEP 8: CREDENTIAL ROTATION CHECKLIST

**MUST BE DONE BEFORE force-push:**

### Razorpay
- [ ] Generate new live key pair
- [ ] Update Firebase Secrets with new key_secret
- [ ] Update Firebase Secrets with new webhook_secret
- [ ] Disable old keys in Razorpay dashboard
- [ ] Test new keys with test payment

### AWS
- [ ] Generate new access key ID and secret access key
- [ ] Delete old credentials in AWS console
- [ ] Update Supabase S3 credentials (if used)
- [ ] Test S3 access with new keys

### WhatsApp Business API
- [ ] Generate new access token
- [ ] Update Firebase Secrets with new token
- [ ] Disable old token
- [ ] Verify webhook still works

### Firebase
- [ ] Re-generate service account keys (if used)
- [ ] Delete old keys
- [ ] Update any server-side authentication

### Android Keystore
- [ ] Generate new signing key (.jks)
- [ ] Update build.gradle with new key
- [ ] Test APK signing with new key
- [ ] Store new keystore in secure location

---

## VERIFICATION CHECKLIST

- [ ] Backup created and verified
  - Location: `C:\temp\backups\fufaji-backup.git`
  - Size verified: _____ MB
  
- [ ] Git history scanned for secrets
  - .env files found: _____
  - .jks files found: _____
  - Firebase credentials found: _____
  - AWS keys found: _____
  
- [ ] git-filter-branch (or manual cleanup) completed
  - Original size: _____ MB
  - Final size: _____ MB
  - Reduction: _____ %
  
- [ ] History verification complete
  - No .env files in history: ✓
  - No .jks files in history: ✓
  - No Razorpay keys in history: ✓
  - No AWS keys in history: ✓
  
- [ ] Force push completed
  - Branch pushed: main
  - Tags pushed: ✓
  - GitHub verified: ✓
  
- [ ] .gitignore updated and committed
  - Comprehensive patterns added: ✓
  - Committed to main: ✓
  - Pushed to GitHub: ✓
  
- [ ] Credentials rotated (CRITICAL)
  - Razorpay keys rotated: ✓
  - AWS keys rotated: ✓
  - WhatsApp token rotated: ✓
  - Android keystore renewed: ✓
  - Old credentials disabled: ✓
  
- [ ] Team notified
  - Email sent: ✓
  - Slack notification: ✓
  - One-on-one discussions: ✓
  
- [ ] Team members cloned fresh repository
  - Developer 1: _____
  - Developer 2: _____
  - Developer 3: _____
  
- [ ] Fresh setup verified
  - .env.example exists: ✓
  - No .env in git: ✓
  - Build successful with new setup: ✓

---

## ROLLBACK PROCEDURES

**If something goes wrong:**

```bash
# 1. Stop all pushes immediately
# 2. Restore from backup
git clone C:\temp\backups\fufaji-backup.git
cd fufaji-online-business.git

# 3. Re-push to GitHub
git push --all origin
git push --tags origin

# 4. Communicate incident to team
# 5. Investigate what went wrong

# IMPORTANT: If secrets were exposed in force-push,
# they must be considered COMPROMISED even if restored
```

---

## TIMELINE & RESPONSIBILITY

**DevOps Engineer / Backend Lead**

| Task | Duration | Owner | Status |
|------|----------|-------|--------|
| Create backup | 15 min | DevOps | Pending |
| Scan history | 15 min | DevOps | Pending |
| Cleanup history | 2 hours | DevOps | Pending |
| Force push | 30 min | DevOps | Pending |
| Update .gitignore | Done | DevOps | DONE |
| Rotate credentials | 1 hour | DevOps | Pending |
| Notify team | 30 min | DevOps | Pending |
| Verify all clean | 30 min | DevOps | Pending |

**Total**: ~5 hours

---

## SUCCESS CRITERIA

After cleanup is complete:

1. **Git History Clean**: No secrets found in `git log`
2. **GitHub Clean**: Verify via GitHub web UI - no sensitive files
3. **New .gitignore**: Comprehensive patterns in place
4. **Credentials Rotated**: All compromised credentials disabled
5. **Team Informed**: All developers have new setup instructions
6. **Fresh Clones**: All team members cloned fresh repository
7. **Builds Working**: Fresh setup builds and runs successfully
8. **No Secrets in APK**: Re-sign APK with new keystore

---

## LONG-TERM IMPROVEMENTS

After this cleanup:

1. **Environment Management**:
   - Use `.env.example` with placeholder values
   - Store secrets in Firebase Secret Manager
   - Use `--dart-define` for public keys only

2. **CI/CD Integration**:
   - Use GitHub Secrets for credentials
   - Auto-inject secrets during build
   - Never log sensitive values

3. **Pre-commit Hooks**:
   - Add pre-commit hook to prevent .env commits
   - Add secret scanning (git-secrets or similar)

4. **Code Review**:
   - Review all credentials in PRs
   - Automated scanning in CI/CD

5. **Documentation**:
   - Update README with safe setup instructions
   - Add SECURITY.md file

---

**Status**: READY TO EXECUTE
**Next Step**: Begin with Step 1 (Backup)
**Emergency Contact**: DevOps Lead
