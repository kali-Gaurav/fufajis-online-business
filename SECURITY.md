# SECURITY POLICY - Fufaji Online Business

## Sensitive Information Handling

### ⚠️ CRITICAL RULES

**NEVER commit to git:**
- `.env` files or any files containing secrets
- `.jks` or `.keystore` files (Android signing keys)
- `google-services.json` or Firebase credentials files
- `*.pem`, `*.p12`, `*.pfx` or other private key files
- AWS access keys, API tokens, or webhook secrets
- WhatsApp, Stripe, Razorpay, or Twilio credentials

**ALWAYS use `.env.example`:**
- Copy `.env.example` to `.env`
- Fill in YOUR LOCAL development credentials only
- `.env` is in `.gitignore` and will not be committed

**NEVER hardcode secrets:**
- Do not put credentials in source code
- Do not put credentials in configuration files
- Do not put credentials in comments
- Use environment variables exclusively

---

## Environment Variables Setup

### Local Development Setup

```bash
# 1. Copy template
cp .env.example .env

# 2. Fill in YOUR LOCAL credentials
nano .env  # or use your editor

# 3. Load environment in your shell
export $(cat .env | xargs)  # Linux/macOS
# Windows: Use IDE environment management
```

### Credentials to Obtain

Contact your DevOps lead or team lead for:
- [ ] Razorpay test key ID and secret
- [ ] WhatsApp Business API token (if working on messaging)
- [ ] AWS access key (if working on storage)
- [ ] Android keystore file and passwords

**DO NOT use production credentials locally** - use test/sandbox APIs only.

---

## Git Security

### Pre-commit Checklist

Before committing, verify:

```bash
# 1. Check for .env files
git status | grep ".env"
# Should return nothing (they're gitignored)

# 2. Check for keystore files
git status | grep "\.jks\|\.keystore"
# Should return nothing

# 3. Review your changes for secrets
git diff --cached
# Look for any API keys, tokens, or credentials
```

### .gitignore Protection

The repository `.gitignore` file prevents commits of:

```
# Environment files
.env
.env.*

# Signing keys
*.jks
*.keystore
*.p12
*.pfx
*.pem

# Credentials
google-services.json
firebase-adminsdk-*.json
private_key*
```

### Pre-commit Hooks (Recommended)

To add automatic secret detection:

```bash
# Install git-secrets globally
brew install git-secrets  # macOS
# or from: https://github.com/awslabs/git-secrets

# Initialize for this repository
git secrets --install
git secrets --register-aws

# Add patterns for Razorpay
git secrets --add 'razorpay_key'
git secrets --add 'rzp_live_'
```

---

## Credential Management

### Razorpay Keys

**Live Production Keys**: Stored in Firebase Secret Manager (server-side only)
- Public Key ID: Safe to use with `--dart-define` in app
- Secret Key: Server-side only, never in app
- Webhook Secret: Server-side only

**Test Keys**: Used for local development
- Never commit test keys
- Can be safely stored in `.env` (which is gitignored)

### Firebase Credentials

**Public APIs**: `lib/firebase_options.dart`
- API keys: Used for client-side Firebase access (intentionally public)
- Project ID: Public knowledge
- Storage bucket: Public knowledge

**Private APIs**: Firebase Secret Manager
- Service account JSON: Server-side only
- Admin SDK credentials: Server-side only
- Custom claims secrets: Server-side only

### AWS Credentials

**Never store in repository** - use:
- IAM roles for EC2/Lambda instances
- AWS profiles for local development
- `.env` file (gitignored) for local dev only

### Android Signing Keys

**Critical**: Keystore files MUST NOT be committed

**Storage**:
- Keep only on secure CI/CD system
- Keep local backup in encrypted storage
- Never share via Slack, email, or git

**Local Development**:
- Generate your own debug keystore
- Store passwords locally only
- Never use production keystore locally

---

## Incident Response

### If Secrets Are Exposed

**IMMEDIATE ACTIONS** (within 5 minutes):

1. **Stop all activity** - pause deployments
2. **Rotate credentials** - generate new keys
3. **Disable old credentials** - revoke access
4. **Notify team** - brief all developers
5. **Log incident** - document what happened

### If Secret Reaches Git History

**Call DevOps lead IMMEDIATELY**

The fix requires:
1. Rewriting git history (git-filter-branch)
2. Force-pushing to GitHub
3. All developers cloning fresh repository
4. Rotating all exposed credentials

See `GITHUB_HISTORY_CLEANUP_PLAN.md` for detailed procedures.

### Audit Trail

Check git history for secret exposure:

```bash
# Search for Razorpay keys
git log -p --all -S "rzp_live_" | head -50

# Search for AWS access keys
git log -p --all -S "AKIA" | head -50

# Search for .env files
git log --name-only --all | grep "\.env"

# Search for keystore files
git log --name-only --all | grep "\.jks"
```

---

## Code Review Best Practices

### During PR Review

Check for secrets:
- [ ] No `.env` files in diff
- [ ] No hardcoded API keys
- [ ] No plaintext credentials in comments
- [ ] No keystore files
- [ ] No private key files
- [ ] Secrets loaded from environment variables only

### Approval Criteria

Only approve if:
1. **No secrets in code**: All credentials from environment
2. **No new sensitive files**: Only source code changes
3. **Proper error handling**: Secrets not logged on error
4. **Configuration**: Follows `.env.example` pattern

---

## Deployment Security

### Build-Time Secrets Injection

**Using `--dart-define`** (safe for public keys):

```bash
flutter build apk \
  --dart-define=RAZORPAY_KEY_ID=rzp_live_xxx \
  --dart-define=API_BASE_URL=https://api.example.com
```

**Using environment variables** (for CI/CD):

```bash
export RAZORPAY_KEY_SECRET=xxx
export WEBHOOK_SECRET=xxx
# Build process reads from environment
```

**Using Firebase Secret Manager** (recommended):

```dart
final secret = await FirebaseAppCheck.instance.getToken();
// Retrieve secrets from Firebase Secret Manager at runtime
```

### APK Distribution

**Considerations**:
- APK will contain public API keys (intentional)
- Secret keys are NOT in APK (server-side only)
- Private keys are NOT in APK
- Environment-specific values use `--dart-define`

---

## Docker & Container Security

### Dockerfile Best Practices

```dockerfile
# ✓ GOOD: Secrets from build args, not in image
ARG RAZORPAY_KEY_ID
ENV RAZORPAY_KEY_ID=$RAZORPAY_KEY_ID

# ✗ BAD: Secrets in image layers
RUN export RAZORPAY_KEY_SECRET=xxx

# ✓ GOOD: Secrets from environment at runtime
ENV RAZORPAY_KEY_SECRET=${RAZORPAY_KEY_SECRET}
```

### Docker Compose

```yaml
services:
  backend:
    environment:
      # ✗ Don't do this:
      # RAZORPAY_KEY_SECRET: "sk_live_xxx"
      
      # ✓ Do this instead:
      RAZORPAY_KEY_SECRET: ${RAZORPAY_KEY_SECRET}
      
    env_file:
      # ✓ Load from .env (which is gitignored)
      - .env.local
```

---

## Monitoring & Alerting

### Secrets Detection

Enable automatic scanning:
- [ ] GitHub Advanced Security (if available)
- [ ] GitHub Secret Scanning (alerts on exposed keys)
- [ ] Pre-commit hooks with git-secrets
- [ ] CI/CD pipeline scanning

### Audit Logging

Track access to:
- [ ] Environment variables
- [ ] Firebase Secret Manager
- [ ] AWS credentials
- [ ] Deployment logs

---

## Compliance & Standards

### OWASP Recommendations

- [OWASP: Secrets Management](https://owasp.org/www-community/Secrets_Leak)
- [OWASP: A02:2021 Cryptographic Failures](https://owasp.org/Top10/A02_2021-Cryptographic_Failures/)

### Google Best Practices

- [Google Cloud: Managing Secrets](https://cloud.google.com/docs/authentication/external/managing-keys)
- [Firebase: Best Practices](https://firebase.google.com/docs/projects/secrets)

### Android Security

- [Android: App Signing](https://developer.android.com/studio/publish/app-signing)
- [Android: Storing Data Securely](https://developer.android.com/training/articles/keystore)

---

## Tools & Resources

### Recommended Tools

1. **git-secrets**: Detect secrets in git history
   ```bash
   brew install git-secrets
   git secrets --install
   ```

2. **talisman**: Secret detection in pre-commit
   ```bash
   curl -L https://github.com/thoughtworks-spike/talisman/releases/download/v1.28.0/talisman_linux_amd64 -o talisman
   chmod +x talisman
   ```

3. **TruffleHog**: Scan git history for secrets
   ```bash
   pip install truffleHog
   trufflehog git https://github.com/your/repo
   ```

4. **FirebaseSecretManager**: Manage server-side secrets
   - Use Firebase console to manage secrets
   - Access via `firebase functions:secrets:set`

### Documentation

- [Firebase Secret Manager](https://cloud.google.com/secret-manager/docs)
- [Dart Secrets Package](https://pub.dev/packages/flutter_secure_storage)
- [Git Secrets](https://github.com/awslabs/git-secrets)

---

## Questions & Support

For security questions or to report a vulnerability:

1. **Do NOT open a public issue** with security details
2. **Contact DevOps lead**: [devops-email@example.com]
3. **Email security**: security@fufaji.com (if established)
4. **Internal Slack**: #security channel

---

## Acknowledgments

This security policy is based on:
- OWASP Top 10
- Google Cloud Security Best Practices
- Firebase Security Recommendations
- Industry standard credential management

---

**Last Updated**: June 24, 2026
**Next Review**: September 24, 2026
**Owner**: DevOps Lead & Security Team
