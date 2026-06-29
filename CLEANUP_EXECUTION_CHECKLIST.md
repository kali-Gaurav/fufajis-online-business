# GitHub History Cleanup - Quick Reference Checklist

**Date**: June 24, 2026  
**Executor**: [DevOps Engineer Name]  
**Duration**: ~4 hours  
**Risk**: HIGH - This rewrites git history  

---

## PRE-EXECUTION VERIFICATION

Before starting the cleanup process:

- [ ] Read `GITHUB_HISTORY_CLEANUP_PLAN.md` completely
- [ ] Review exposed secrets inventory in the plan
- [ ] Notify team lead that cleanup is starting
- [ ] Verify no active development happening
- [ ] Ensure you have administrator access to GitHub repository
- [ ] Disable branch protection temporarily (allow force-push)
- [ ] Close all IDE windows with the repository open

---

## STEP 1: BACKUP REPOSITORY (15 minutes)

```bash
# Create backup location
mkdir C:\temp\backups

# Create mirror backup
git clone --mirror https://github.com/your-username/fufaji-online-business.git C:\temp\backups\fufaji-backup.git

# Verify backup
ls -lh C:\temp\backups\fufaji-backup.git

# Backup verification checklist
```

**Checklist**:
- [ ] Backup directory created: `C:\temp\backups\fufaji-backup.git`
- [ ] Backup verified (size > 50 MB expected)
- [ ] Backup stored safely
- [ ] Backup accessibility confirmed

---

## STEP 2: SCAN GIT HISTORY (15 minutes)

**Location**: `C:\Projects\fufaji-online-business`

```powershell
cd C:\Projects\fufaji-online-business

# Scan for Razorpay keys
Write-Host "Scanning for Razorpay keys..." -ForegroundColor Yellow
git log -p --all -S "rzp_live_" 2>&1 | Select-String -Pattern "rzp_live_" | Measure-Object

# Scan for AWS keys
Write-Host "Scanning for AWS keys..." -ForegroundColor Yellow
git log -p --all -S "AKIA" 2>&1 | Measure-Object

# List .env files in history
Write-Host "Scanning for .env files..." -ForegroundColor Yellow
git log --name-only --all | Select-String "\.env" | Sort-Object -Unique

# List .jks files in history
Write-Host "Scanning for .jks files..." -ForegroundColor Yellow
git log --name-only --all | Select-String "\.jks" | Sort-Object -Unique
```

**Findings to Document**:
- [ ] Razorpay keys found in commits: _________________
- [ ] AWS keys found in commits: _________________
- [ ] .env files found in history: _________________
- [ ] .jks files found in history: _________________
- [ ] Other sensitive files: _________________

**Expected findings**:
```
- .env (main file with secrets)
- android/app/fufaji-upload-key.jks
- android/fufaji-upload-key.jks
- upload-keystore.jks
- app/fufaji-app/fufaji-upload-key.jks
- app/fufaji-app/fufaji-native.jks
```

---

## STEP 3: CREATE CLEAN REPOSITORY (2 hours)

```bash
# Create working directory
mkdir C:\temp\fufaji-clean
cd C:\temp\fufaji-clean

# Clone repository
git clone https://github.com/your-username/fufaji-online-business.git .

# Check current size
Write-Host "Original size:" -ForegroundColor Yellow
du -sh .git
$originalSize = (Get-Item -Path ".git" -Force).Length
```

**Cleanup Execution**:

```powershell
# Method 1: Using PowerShell (Windows)
Write-Host "Removing sensitive files..." -ForegroundColor Cyan

git filter-branch --tree-filter {
    # Remove .env files
    Get-ChildItem -Path . -Filter ".env*" -Recurse -Force -ErrorAction SilentlyContinue | 
        Remove-Item -Force -ErrorAction SilentlyContinue
    
    # Remove keystore files
    Get-ChildItem -Path . -Filter "*.jks" -Recurse -Force -ErrorAction SilentlyContinue | 
        Remove-Item -Force -ErrorAction SilentlyContinue
    
    Get-ChildItem -Path . -Filter "*.keystore" -Recurse -Force -ErrorAction SilentlyContinue | 
        Remove-Item -Force -ErrorAction SilentlyContinue
    
    # Remove Firebase credentials
    Get-ChildItem -Path . -Filter "google-services.json" -Recurse -Force -ErrorAction SilentlyContinue | 
        Remove-Item -Force -ErrorAction SilentlyContinue
} -- --all 2>&1 | Tee-Object -Variable filterOutput

# Cleanup reflogs
Write-Host "Cleaning reflogs..." -ForegroundColor Cyan
git reflog expire --expire=now --all

# Aggressive garbage collection
Write-Host "Running garbage collection..." -ForegroundColor Cyan
git gc --prune=now --aggressive
```

**Checklist**:
- [ ] Clean repository created at `C:\temp\fufaji-clean`
- [ ] git filter-branch completed without errors
- [ ] Reflogs expired
- [ ] Garbage collection completed
- [ ] New size calculated: _________

```bash
# Calculate size reduction
du -sh .git
# Compare with original size and document percentage
```

---

## STEP 4: VERIFICATION (30 minutes)

**In `C:\temp\fufaji-clean` directory:**

```powershell
# Verify no .env files in history
Write-Host "Verifying .env files removed..." -ForegroundColor Cyan
$envCheck = git log --name-only --all | Select-String "\.env$"
if ($envCheck) {
    Write-Host "❌ ERROR: .env files still found!" -ForegroundColor Red
} else {
    Write-Host "✓ .env files removed" -ForegroundColor Green
}

# Verify no .jks files in history
Write-Host "Verifying .jks files removed..." -ForegroundColor Cyan
$jksCheck = git log --name-only --all | Select-String "\.jks$"
if ($jksCheck) {
    Write-Host "❌ ERROR: .jks files still found!" -ForegroundColor Red
} else {
    Write-Host "✓ .jks files removed" -ForegroundColor Green
}

# Verify no Razorpay keys in history
Write-Host "Verifying Razorpay keys removed..." -ForegroundColor Cyan
$razorpayCheck = git log -p --all -S "rzp_live_" 2>/dev/null | Measure-Object
if ($razorpayCheck.Count -gt 0) {
    Write-Host "❌ ERROR: Razorpay keys still found!" -ForegroundColor Red
} else {
    Write-Host "✓ Razorpay keys removed" -ForegroundColor Green
}

# Verify no AWS keys in history
Write-Host "Verifying AWS keys removed..." -ForegroundColor Cyan
$awsCheck = git log -p --all -S "AKIA" 2>/dev/null | Measure-Object
if ($awsCheck.Count -gt 0) {
    Write-Host "❌ ERROR: AWS keys still found!" -ForegroundColor Red
} else {
    Write-Host "✓ AWS keys removed" -ForegroundColor Green
}

# Show commit count
Write-Host "Total commits after cleanup:" -ForegroundColor Yellow
git log --oneline --all | Measure-Object

# Show last 5 commits
Write-Host "Last 5 commits:" -ForegroundColor Yellow
git log --oneline -5
```

**Verification Checklist**:
- [ ] ✓ All .env files removed from history
- [ ] ✓ All .jks files removed from history
- [ ] ✓ All Razorpay keys removed from history
- [ ] ✓ All AWS keys removed from history
- [ ] ✓ Repository is clean and ready to push
- [ ] ✓ Commit count verified: _________

---

## STEP 5: FORCE PUSH TO GITHUB (30 minutes)

**POINT OF NO RETURN - Verify everything is clean before proceeding!**

```powershell
# 1. Verify we're in clean repository
Write-Host "Current directory:" -ForegroundColor Yellow
pwd  # Should show: C:\temp\fufaji-clean

# 2. Set origin remote (should already be set)
git remote -v
# Should show: origin -> https://github.com/your-username/fufaji-online-business.git

# 3. FINAL VERIFICATION before force push
Write-Host "FINAL VERIFICATION" -ForegroundColor Red
Write-Host "=================" -ForegroundColor Red
git log --all --name-only | Select-String -Pattern "\.env|\.jks|google-services|AKIA|rzp_live_"
Write-Host ""
Write-Host "If anything above showed matches, STOP - do not proceed!" -ForegroundColor Red
Write-Host ""
Read-Host "Press ENTER to continue with force push (type 'ABORT' to stop)"

# 4. Force push main branch
Write-Host "Force pushing main branch..." -ForegroundColor Yellow
git push origin --force main

# Wait for push to complete
Start-Sleep -Seconds 5

# 5. Force push tags
Write-Host "Force pushing tags..." -ForegroundColor Yellow
git push origin --force --tags

# 6. Verify push succeeded
Write-Host "Verifying GitHub was updated..." -ForegroundColor Yellow
git log --oneline origin/main -5

# 7. Final check - can we see secrets on GitHub?
Write-Host "FINAL CHECK: Verifying GitHub history is clean..." -ForegroundColor Cyan
$githubCheck = git log --all --name-only | Select-String "\.env|\.jks"
if ($githubCheck) {
    Write-Host "❌ CRITICAL ERROR: Secrets still visible on GitHub!" -ForegroundColor Red
    Write-Host "Immediate action required!" -ForegroundColor Red
} else {
    Write-Host "✓ GitHub history is clean!" -ForegroundColor Green
}
```

**Push Checklist**:
- [ ] Current directory is `C:\temp\fufaji-clean`
- [ ] Origin remote is correctly configured
- [ ] Final verification completed (no secrets found)
- [ ] Main branch force-pushed successfully
- [ ] Tags force-pushed successfully
- [ ] GitHub updated and verified

---

## STEP 6: UPDATE .GITIGNORE (Already Completed)

**Status**: ✓ DONE in previous step

**Commit the update**:

```bash
cd C:\Projects\fufaji-online-business

# Already updated, but ensure it's committed
git status | Select-String ".gitignore"
git add .gitignore
git commit -m "Security: Update .gitignore to prevent future credential leaks"
git push origin main
```

**Checklist**:
- [ ] .gitignore updated with comprehensive patterns
- [ ] Committed and pushed to main

---

## STEP 7: ROTATE ALL CREDENTIALS (1 hour)

**CRITICAL**: Execute this BEFORE notifying team

### Razorpay
```
- [ ] Log in to Razorpay Dashboard
- [ ] Generate new live key pair
- [ ] Update Firebase Secrets with new keys
- [ ] Disable old keys
- [ ] Test with new keys
```

### AWS
```
- [ ] Log in to AWS Console
- [ ] Create new access key in IAM
- [ ] Delete old access key
- [ ] Update systems using AWS keys
```

### WhatsApp
```
- [ ] Log in to Meta Business Console
- [ ] Generate new access token
- [ ] Update Firebase Secrets
- [ ] Disable old token
```

### Android Keystore
```
- [ ] Backup old keystore (if needed for existing apps)
- [ ] Generate new keystore with new password
- [ ] Update android/key.properties with new keystore path/password
- [ ] Test APK signing with new keystore
```

**Credential Rotation Checklist**:
- [ ] Razorpay keys rotated and verified
- [ ] AWS credentials rotated and verified
- [ ] WhatsApp token rotated and verified
- [ ] Android keystore regenerated
- [ ] All old credentials disabled in systems
- [ ] New credentials documented securely

---

## STEP 8: NOTIFY TEAM (30 minutes)

**Send to all developers:**

1. **Email**: GitHub History Rewritten - Action Required
2. **Slack**: Post in #general and #development channels
3. **One-on-one**: Brief calls with each developer

**Message Template**:

```
URGENT: GitHub Repository Rewritten - Fresh Clone Required

Your immediate action required by EOD today:

1. git stash (save any uncommitted work)
2. Delete your local clone: rm -rf ~/fufaji-online-business
3. Fresh clone: git clone https://github.com/your-user/fufaji-online-business.git
4. Get new credentials from [Contact]
5. cp .env.example .env (and fill in your LOCAL dev credentials)

DO NOT:
- Push old branches
- Merge old commits
- Use old credentials

Questions? Contact [DevOps Lead]
```

**Notification Checklist**:
- [ ] Email sent to all developers
- [ ] Slack notifications posted
- [ ] Credentials rotation documented
- [ ] New setup instructions provided
- [ ] Support contact information clear

---

## STEP 9: VERIFY CLEANUP SUCCESS

**Verify each of these**:

1. **GitHub Repository Clean**:
   - [ ] Visit https://github.com/your-username/fufaji-online-business
   - [ ] View recent commits - no .env or .jks files
   - [ ] Search git history for "rzp_live_" - should find nothing

2. **Team Members Updated**:
   - [ ] Developer 1 cloned fresh: _________
   - [ ] Developer 2 cloned fresh: _________
   - [ ] Developer 3 cloned fresh: _________

3. **Credentials Rotated**:
   - [ ] Razorpay old keys disabled
   - [ ] AWS old keys deleted
   - [ ] WhatsApp old token revoked
   - [ ] Android app rebuild with new keystore

4. **Documentation Updated**:
   - [ ] GITHUB_HISTORY_CLEANUP_PLAN.md created
   - [ ] SECURITY.md created
   - [ ] .env.example verified as template

---

## TROUBLESHOOTING

### If cleanup fails midway:

```bash
# 1. Stop immediately
# 2. Check if filter-branch is still running
ps aux | grep git

# 3. Kill if needed
kill -9 <pid>

# 4. Restore from backup
cd C:\temp\fufaji-clean
git reflog

# 5. Reset to pre-filter-branch state
git reset --hard <original-head>

# 6. Diagnose issue
git log --oneline -10
```

### If secrets remain after force-push:

**CRITICAL - Escalate immediately**:

```bash
# 1. Notify security team immediately
# 2. Consider credentials compromised
# 3. Rotate ALL credentials
# 4. Contact GitHub support

# Verify what's exposed
curl -s https://api.github.com/repos/your-user/fufaji-online-business/commits | jq '.[] | .commit.message'
```

### If developers have push conflicts:

```bash
# For each developer:
# 1. Backup their branch
git branch backup/my-feature

# 2. Delete their local clone and clone fresh
rm -rf fufaji-online-business
git clone https://github.com/your-user/fufaji-online-business.git

# 3. Re-apply their changes on fresh clone
# Rebase backup branch on new clean main
git rebase --onto main backup/my-feature
```

---

## POST-CLEANUP (24 hours)

**Verify everything is stable**:

- [ ] All team members successfully cloned fresh repo
- [ ] All builds working with new setup
- [ ] No push conflicts or merge issues
- [ ] No remaining credential errors
- [ ] Backup safely stored
- [ ] Incident documented

**If everything is good**:
- [ ] Delete temporary directories: `C:\temp\fufaji-clean`
- [ ] Keep backup for 1 week: `C:\temp\backups\fufaji-backup.git`
- [ ] Document lessons learned

---

## SUCCESS METRICS

Cleanup is successful if:

✓ No secrets in current git history  
✓ No secrets in any branch  
✓ GitHub web UI shows clean history  
✓ All developers cloned fresh repository  
✓ All credentials rotated  
✓ New .gitignore in place  
✓ All systems working with new credentials  
✓ Team informed and updated  

---

## SIGN-OFF

```
Executed By: _________________________  Date: ____________

Backup Location: _____________________________

Original Repository Size: _____  MB

Cleaned Repository Size: _____  MB

Reduction: _____ %

All Secrets Removed: ☐ YES ☐ NO

Force Push Completed: ☐ YES ☐ NO

Team Notified: ☐ YES ☐ NO

All Credentials Rotated: ☐ YES ☐ NO

Overall Status: ☐ SUCCESS ☐ PARTIAL ☐ FAILED

Notes:
_____________________________________________
_____________________________________________
_____________________________________________
```

---

**Total Estimated Time**: 4 hours
**Difficulty Level**: HIGH
**Risk Level**: HIGH
**Rollback Possible**: YES (within 24 hours using backup)

Good luck! Remember to take breaks and verify each step.
