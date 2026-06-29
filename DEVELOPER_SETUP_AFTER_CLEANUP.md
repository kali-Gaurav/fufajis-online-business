# Developer Setup Guide - After GitHub History Cleanup

**For All Development Team Members**

**Date**: June 24, 2026  
**Status**: Complete this guide after receiving cleanup notification  
**Estimated Time**: 30 minutes  

---

## ⚠️ IMPORTANT: Read This Carefully

Our GitHub repository underwent a security cleanup today. This **requires all developers to complete a fresh setup**. 

**Old credentials are now DISABLED.** You will need new credentials to continue working.

---

## STEP 1: SAVE YOUR WORK (5 minutes)

**If you have uncommitted changes:**

```bash
cd ~/fufaji-online-business

# Save all your work
git stash

# Verify stash saved
git stash list
```

**Note**: Your stashed work will still be accessible after setup is complete.

---

## STEP 2: DELETE OLD REPOSITORY CLONE (2 minutes)

**Delete your current local clone completely:**

```bash
# Navigate away from the directory
cd ~

# Remove old clone (COMPLETELY - this deletes everything)
rm -rf fufaji-online-business

# Verify it's gone
ls -la | grep fufaji  # Should show nothing
```

**Why?** The old history has been rewritten. Keeping the old clone will cause conflicts.

---

## STEP 3: CLONE FRESH REPOSITORY (5 minutes)

**Clone the new, clean repository:**

```bash
# Clone fresh repository
git clone https://github.com/your-username/fufaji-online-business.git

# Navigate into it
cd fufaji-online-business

# Verify you're on main branch
git branch  # Should show: * main

# Show recent commits (should be clean)
git log --oneline -5
```

**Expected Output**:
```
6f8e3d2 Security: Update .gitignore to prevent future credential leaks
a4b5c6d Feature: Add new payment gateway
... (commits should look normal, no rewrite artifacts)
```

---

## STEP 4: REQUEST NEW CREDENTIALS (varies)

**You CANNOT use old credentials** - they have been disabled.

**Contact your DevOps lead to request:**

- [ ] Razorpay API credentials (test key for local dev)
- [ ] AWS access keys (if you work with storage)
- [ ] WhatsApp token (if you work with messaging)
- [ ] Android signing credentials (if you build APKs)

**Form a request like this:**

```
Hi [DevOps Lead],

I need to update my local environment after the git cleanup.

Please provide:
- Razorpay test credentials (key ID and secret)
- AWS credentials (if needed for my work)
- WhatsApp token (if needed for my work)
- Android signing info

My local .env will use these credentials ONLY - never committed to git.

Thanks!
```

**Keep credentials SECURE:**
- Never share via Slack, email, or chat
- Request via secure channel (1-on-1, voice call, or password manager)
- Store locally ONLY, never in git

---

## STEP 5: SET UP LOCAL ENVIRONMENT FILE (5 minutes)

**Create your local .env file:**

```bash
# Copy the template
cp .env.example .env

# Edit with your editor
nano .env  # Linux/macOS
# or use your IDE: Open .env in VSCode, IntelliJ, etc.
```

**Fill in your credentials from Step 4:**

```env
# Your values here (example with placeholders):

# Razorpay - Use TEST credentials locally
RAZORPAY_KEY_ID=rzp_test_xxxxx_provided_by_devops
RAZORPAY_KEY_SECRET=xxxxx_provided_by_devops
RAZORPAY_WEBHOOK_SECRET=xxxxx_provided_by_devops

# AWS (only if you work with storage)
AWS_ACCESS_KEY_ID=xxxxx_provided_by_devops
AWS_SECRET_ACCESS_KEY=xxxxx_provided_by_devops
AWS_REGION=ap-south-1

# WhatsApp (only if you work with messaging)
WHATSAPP_TOKEN=xxxxx_provided_by_devops

# Android Signing (only if you build APKs locally)
ANDROID_STORE_PASSWORD=xxxxx_provided_by_devops
ANDROID_KEY_PASSWORD=xxxxx_provided_by_devops

# Keep other values as-is
API_BASE_URL=https://fufaji-api.render.com
NODE_ENV=development
```

**Important Rules:**
- [ ] Use TEST/DEV credentials locally (never production)
- [ ] Never commit this file (it's in .gitignore)
- [ ] Don't share these values
- [ ] Keep them secure locally

---

## STEP 6: VERIFY SETUP (10 minutes)

**Verify everything is working:**

```bash
# 1. Get Flutter dependencies
flutter pub get

# 2. Get Dart packages
cd backend  # if you work on backend
pub get
cd ..

# 3. Verify environment is loaded
echo $RAZORPAY_KEY_ID  # Should show your key (if using shell)

# 4. Run tests (if available)
flutter test

# 5. Build debug APK (to test Android signing)
flutter build apk --debug

# 6. If backend work:
cd backend
dart pub get
dart run build_runner build  # if you use build_runner
cd ..
```

**Expected Success:**
- ✓ `flutter pub get` completes without errors
- ✓ No "secret not found" errors
- ✓ APK builds successfully
- ✓ All tests pass (if you run them)

---

## STEP 7: RESTORE YOUR WORK (2 minutes)

**If you stashed work in Step 1:**

```bash
# See what's in your stash
git stash list

# Restore your work
git stash pop

# If multiple stashes, pick the right one:
# git stash pop stash@{0}

# Verify your files are back
git status
```

---

## STEP 8: VERIFY .ENV IS NOT TRACKED (2 minutes)

**Confirm .env is properly ignored:**

```bash
# This MUST be empty (no .env file listed)
git status

# This should show .env in gitignore
cat .gitignore | grep ".env"

# This must NOT show your .env file
git ls-files | grep ".env"  # Should return nothing

# Double-check by trying to add it (should warn)
git add .env
# You should get: "The following paths are ignored by one of your .gitignore files"
```

**If .env was accidentally committed:**
- Notify DevOps lead immediately
- Do NOT push your .env file
- Contact support for remediation

---

## TROUBLESHOOTING

### Issue: "Could not find git repository"
**Solution**: Make sure you're in the correct directory
```bash
cd fufaji-online-business
git status  # Should work now
```

### Issue: "Permission denied" when building APK
**Solution**: Check Android signing credentials in .env
```bash
# Verify these exist and are correct:
echo $ANDROID_STORE_PASSWORD
echo $ANDROID_KEY_PASSWORD
echo $ANDROID_KEY_ALIAS

# Verify keystore file exists:
ls -la android/app/fufaji-upload-key.jks
```

### Issue: "Razorpay key not found" error
**Solution**: Reload environment variables
```bash
# Reload your shell profile
source ~/.bashrc  # Linux
source ~/.zshrc   # macOS

# Or in your IDE: Restart the development server
flutter run --verbose
```

### Issue: "This branch is X commits behind main"
**Solution**: This is normal after cleanup - your old branches won't match
```bash
# Check which branch you're on
git branch

# If you need to update a feature branch:
git checkout main
git pull origin main
git checkout your-feature-branch
git rebase main
# Resolve any conflicts, then continue
```

### Issue: ".env file in git status but not in gitignore"
**Solution**: Clear git cache
```bash
# Remove .env from git cache (but not your local file)
git rm --cached .env

# Verify it's removed
git status

# Check gitignore
cat .gitignore | grep "\.env"
```

### Issue: "Old commits appear in git log"
**Solution**: This is normal - repository history was rewritten
```bash
# Don't worry about this, it's expected
git log --oneline -10

# The cleanup is working correctly if you don't see old secrets
git log -p --all -S "rzp_live_"  # Should find nothing
```

---

## COMMON MISTAKES TO AVOID

### ✗ DON'T:

```bash
# Don't use git add -A with .env in current directory
git add .env  # WRONG - This could commit secrets

# Don't push old branches without talking to DevOps
git push origin old-feature  # WRONG - Old history is gone

# Don't try to merge code from before the cleanup
git merge ancient-branch  # WRONG - Conflicting history

# Don't commit .env.development or .env.production
git add .env.development  # WRONG - These are also secrets files

# Don't hardcode credentials in code
RAZORPAY_SECRET = "sk_live_xxxx"  # WRONG - Use environment variables only
```

### ✓ DO:

```bash
# Always use .env.example as template
cp .env.example .env

# Always load from environment variables
const secret = process.env.RAZORPAY_KEY_SECRET;

# Always check .gitignore before adding files
git add .  # Check status first

# Always verify .env is not in git before committing
git status | grep ".env"  # Should be empty

# Always keep credentials in .env (which is gitignored)
# Never put them anywhere else
```

---

## SECURITY REMINDERS

### Your Responsibilities:

1. **Keep .env private**:
   - Never commit it to git
   - Never share via Slack, email, or chat
   - Never put it in a repo or documentation

2. **Use test credentials locally**:
   - Use test Razorpay keys (rzp_test_*, not rzp_live_*)
   - Use test AWS credentials (not production)
   - Use test WhatsApp tokens (not production)

3. **Report security issues immediately**:
   - If you accidentally commit secrets → Contact DevOps NOW
   - If you see suspicious commits → Report immediately
   - If credentials feel compromised → Escalate immediately

4. **Follow the security policy**:
   - Read `SECURITY.md` in the repository root
   - Follow the rules outlined there
   - Ask questions if anything is unclear

---

## WHAT IF CLEANUP DIDN'T WORK FOR YOU?

**Contact your DevOps lead immediately with:**

```
Current Issue:
- What error message are you seeing?
- What step are you stuck on?
- What have you already tried?

Your Environment:
- OS: (Windows/macOS/Linux)
- Flutter version: (run: flutter --version)
- Git version: (run: git --version)

Reproduction Steps:
1. 
2. 
3. 

Error Output:
(paste the full error message here)
```

---

## GETTING HELP

### If you need help:

1. **First**: Check this guide (Ctrl+F to search for your issue)
2. **Second**: Check `SECURITY.md` for security-related questions
3. **Third**: Ask in #development Slack channel
4. **Finally**: Contact [DevOps Lead] directly with details

### Support Contacts:

- **DevOps Lead**: [Email] / [Slack]
- **Tech Lead**: [Email] / [Slack]
- **Security Team**: [Email] / #security channel

---

## NEXT STEPS

After completing this setup:

1. ✓ Continue with your assigned tasks
2. ✓ Report any issues to DevOps lead
3. ✓ Read `SECURITY.md` for policies going forward
4. ✓ Never commit .env files
5. ✓ Always use `--dart-define` for app build credentials

---

## SUMMARY CHECKLIST

- [ ] Old repository deleted
- [ ] Fresh clone completed
- [ ] Credentials received from DevOps
- [ ] .env file created from .env.example
- [ ] .env filled with new credentials (LOCAL ONLY)
- [ ] Flutter pub get completed
- [ ] Build test successful
- [ ] Stashed work restored
- [ ] .env verified not in git
- [ ] Ready to continue development

---

## QUESTIONS?

**Most Common Questions:**

**Q: Can I use my old credentials?**  
A: No. Old credentials have been disabled. Request new ones from DevOps.

**Q: Will I lose my work?**  
A: No. If you stashed your work, it's safe. Restore it with `git stash pop`.

**Q: How long will setup take?**  
A: About 30 minutes for a full setup.

**Q: What if I already deleted my old clone?**  
A: Just do a fresh clone. No problem.

**Q: Can I use production credentials locally?**  
A: No. Always use test/development credentials locally. Never use production locally.

**Q: What if I see old commits?**  
A: History was rewritten. Don't be alarmed. This is expected and secure.

**Q: When should I run the cleanup setup?**  
A: Today. Don't wait. Old credentials are already disabled.

---

**STATUS**: Ready to start setup

**Estimated Time**: 30 minutes

**Good luck with your fresh setup!**

If anything goes wrong, contact [DevOps Lead] immediately.
