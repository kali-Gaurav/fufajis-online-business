# Fufaji Production Deployment Checklist
**Status:** 🔴 BLOCKED — Must complete Section 1 before proceeding  
**Last Updated:** 2026-06-25

---

## 🔴 SECTION 1: SECURITY REMEDIATION (MUST DO FIRST)

### Step 1a: Purge secrets from git history
**STATUS:** ⏳ PENDING (requires git-filter-repo)
**RUN IN WINDOWS POWERSHELL:**

```powershell
# Install git-filter-repo (one time only)
pip install git-filter-repo

# Navigate to repo
cd C:\Projects\fufaji-online-business

# Purge secrets from ALL git history
git filter-repo --invert-paths --path functions/.runtimeconfig.json --path scripts/setup_functions_config.bat --path LIVE_SETUP_GUIDE.md --path firebase-deploy.sh --path keystore_base64.txt

# Force push (OVERWRITES GITHUB HISTORY)
git push origin --force --all
git push origin --force --tags

# Verify (should show 0 results)
git log --all --full-history --oneline -- functions/.runtimeconfig.json | wc -l
```

**Expected output:** `0` (no secrets in history)

---

### Step 1b: Make GitHub repo PRIVATE
**STATUS:** ⏳ MANUAL
**ACTION:** Go to https://github.com/kali-Gaurav/fufajis-online-business
- Settings → Danger Zone → Make Private

---

### Step 1c: Rotate ALL exposed credentials
**STATUS:** ⏳ MANUAL (requires dashboard access)
**ROTATE AT EACH PROVIDER'S DASHBOARD:**

| Provider | Action | Get NEW |
|---|---|---|
| **Razorpay** | Dashboard → API Keys → Regenerate | KEY_ID, KEY_SECRET, WEBHOOK_SECRET |
| **Twilio** | Console → Account → Auth Token → Rotate | ACCOUNT_SID, AUTH_TOKEN |
| **WhatsApp/Meta** | System User → Tokens → Revoke + Issue new | WHATSAPP_TOKEN |
| **Gemini** | Google AI Studio → Delete old → Create new | GEMINI_API_KEY |
| **Supabase** | Settings → S3 Keys → Rotate | S3_ACCESS_KEY, S3_SECRET_KEY |
| **Upstash** | Dashboard → Rotate REST token | UPSTASH_REDIS_REST_TOKEN |
| **AWS** | IAM → Access Keys → Create new | AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY |

---

### Step 1d: Set rotated secrets in Firebase Secret Manager
**STATUS:** ⏳ MANUAL
**RUN IN WINDOWS POWERSHELL:**

```powershell
firebase login
firebase functions:secrets:set RAZORPAY_KEY_ID
firebase functions:secrets:set RAZORPAY_KEY_SECRET
firebase functions:secrets:set RAZORPAY_WEBHOOK_SECRET
firebase functions:secrets:set TWILIO_ACCOUNT_SID
firebase functions:secrets:set TWILIO_AUTH_TOKEN
firebase functions:secrets:set TWILIO_PHONE_NUMBER
firebase functions:secrets:set WHATSAPP_TOKEN
firebase functions:secrets:set GEMINI_API_KEY
firebase functions:secrets:set RDS_CONNECTION_STRING
firebase functions:secrets:set AWS_S3_ACCESS_KEY
firebase functions:secrets:set AWS_S3_SECRET_KEY
firebase functions:secrets:set SENDGRID_API_KEY
firebase functions:secrets:set UPSTASH_REDIS_REST_TOKEN
firebase functions:secrets:set SUPABASE_S3_ACCESS_KEY
firebase functions:secrets:set SUPABASE_S3_SECRET_KEY
```

---

## ✅ SECTION 2: VERIFY PRODUCTION READINESS

### Step 2a: Verify Firestore
- [ ] Log into Firebase Console
- [ ] Firestore database exists
- [ ] Collections visible (products, orders, users)
- [ ] Backup enabled
- [ ] Security rules deployed from `functions/firestore.rules`

### Step 2b: Verify Cloud Functions
```powershell
cd C:\Projects\fufaji-online-business\functions
node -c index.js
firebase deploy --only functions --force
```

### Step 2c: Verify Flutter app builds
```powershell
flutter build apk --release \
  --dart-define=RAZORPAY_KEY_ID=<ROTATED_KEY>
```

---

## 🚀 SECTION 3: PRODUCTION DEPLOYMENT

```powershell
firebase deploy --only functions,firestore:rules --force
```

---

## 📋 VERIFICATION CHECKLIST

- [ ] Git history clean (no secrets in history)
- [ ] GitHub repo is PRIVATE
- [ ] All credentials rotated
- [ ] Firebase Secret Manager has 15+ secrets set
- [ ] Firestore rules deployed
- [ ] Cloud Functions deployed
- [ ] Flutter APK builds successfully
- [ ] Payment flow tested
- [ ] Monitoring configured
- [ ] Rollback plan documented

9. **User Data Privacy & Security**
   - GDPR, CCPA compliance verified (legal sign-off)
   - Encryption: AES-256 at rest, TLS 1.3 in transit
   - Data retention policy: user deletion within 30 days of request
   - Third-party audit completed (SOC 2 Type I minimum)

10. **Transactional Integrity**
    - Payment data: PCI-DSS Level 1 compliance
    - Trip booking atomicity: no orphaned bookings
    - Refund mechanics: automatic within 3 business days
    - Audit trail: 100% of transactions logged for 7 years

---

## SAFETY & EMERGENCY SUPPORT (11-15)

11. **Emergency Alert System**
    - 24/7 monitoring for traveler safety incidents
    - SOS button triggers: GPS tracking + emergency contact notification + local support agent
    - Response time: support agent contact within 30 seconds
    - Integration with local emergency services in all operating cities

12. **Traveler Verification & Trust**
    - Identity verification: Government ID or phone verification (2FA)
    - Fraud detection: ML model catches 95%+ of suspicious bookings
    - Driver/operator background checks: complete, verified
    - Rating system: transparent with verified reviews only

13. **Real-Time Support Availability**
    - Support team: available 24/7 in user's native language
    - Response SLA: <2 minutes for urgent issues
    - Support channels: chat, call, email, in-app messaging
    - Escalation to management: within 5 minutes for unresolved issues

14. **Incident Response Protocol**
    - Documented playbooks for: accidents, delays >30min, lost luggage, medical emergencies
    - Crisis management team trained and on-call
    - Communication template: auto-notify affected users within 5 minutes
    - Post-incident review within 24 hours

15. **Insurance & Liability Coverage**
    - Traveler protection insurance: included, minimum coverage defined
    - Product liability coverage: active and verified
    - Third-party operator insurance validation: confirmed before partnerships
    - Terms & conditions: legal liability boundaries clear

---

## PLATFORM PERFORMANCE & STABILITY (16-20)

16. **App & Web Performance**
    - App load time: <3 seconds on 4G, <1 second on WiFi
    - Web page load: <2 seconds on standard connections
    - 99.9% uptime SLA verified over 30 days of production testing
    - Zero crashes in stress test (10k concurrent users)

17. **API Stability & Rate Limiting**
    - All endpoints: <200ms response time at p99
    - Rate limiting: prevents abuse without blocking legitimate users
    - Graceful degradation: service continues even if 1 component fails
    - Circuit breaker: automatically switches to failover for downed services

18. **Search & Booking Speed**
    - Search results: returned within 1.5 seconds
    - Booking confirmation: within 2 seconds
    - Payment processing: within 5 seconds
    - No timeouts under normal load

19. **Scalability Tested**
    - Tested at 10x expected launch-day load
    - Auto-scaling: works correctly for all components
    - Database performance: no slowdown at 2x expected data volume
    - Can handle 100,000+ simultaneous search queries

20. **Monitoring & Alerting**
    - Real-time dashboard: system health, error rates, user activity
    - Automated alerts: triggered before SLA breach (not after)
    - Logging: centralized, searchable, retained for 90 days
    - Metrics tracked: latency, errors, throughput, resource usage

---

## COMPLIANCE, LEGAL & FINANCIAL (21-25)

21. **Regulatory Compliance**
    - Operating license: obtained for all cities/states where service runs
    - Transport partnerships: legally compliant agreements in place
    - Terms of Service: reviewed by legal, user-friendly version published
    - Accessibility compliance: WCAG 2.1 AA minimum for app/web

22. **Payment & Financial Operations**
    - Payment gateway: PCI-DSS certified, tested with real transactions
    - Pricing model: transparent, no hidden charges
    - Refund policy: clear, automated, dispute resolution process documented
    - Financial reporting: audit-ready, reconciliation procedures tested

23. **Marketing & User Acquisition Readiness**
    - Marketing materials: fact-checked, no false claims
    - CAC calculation: unit economics validated for profitability
    - User onboarding: tested with 500+ beta users, <2% drop-off target
    - Retention metrics: baseline set (target 40%+ 30-day retention)

24. **Team Capability & Operations**
    - Support team: trained on 50+ common issues, SOP documented
    - Engineering on-call: 24/7 rotation established, escalation clear
    - Data team: monitoring algorithm performance, can push updates
    - Product team: bug triage process defined, hotfix procedures tested

25. **Go-Live Contingency & Rollback**
    - Rollback plan: can revert any feature within 30 minutes
    - Kill switch: can disable non-critical features instantly
    - Status page: live, communicates outages to users in real-time
    - Post-launch support: team availability 24/7 for first 7 days

---

## Validation Sign-Off

- [ ] CEO/Founder sign-off: All 25 criteria met
- [ ] CTO sign-off: Infrastructure, algorithm, monitoring ready
- [ ] Legal review: Compliance, privacy, liability cleared
- [ ] Finance review: Unit economics, payment systems verified
- [ ] Customer support lead sign-off: Team, processes, tooling ready
- [ ] QA sign-off: Testing completed, critical path covered

**Launch Date: ___________**
**Prepared By: ___________**
**Date: ___________**

---

## Notes
These criteria ensure your startup launches safely, reliably, and credibly. Prioritize items 6-15 (data/safety) — these differentiate you in the competitive travel space and protect users. Items 1-5 are your core product. Items 16-25 are operationally critical but can be iterated post-launch if necessary.
