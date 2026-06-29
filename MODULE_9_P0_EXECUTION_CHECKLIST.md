# Module 9 P0 - Delivery Collections Consolidation - Execution Checklist

**Project**: Fufaji Store  
**Issue**: 10 orphaned delivery collections with no security rules  
**Solution**: Consolidate into single `delivery_tasks` collection with RLS  
**Timeline**: 2.5 hours total  
**Risk**: LOW  
**Date Created**: 2026-06-23  

---

## PRE-EXECUTION SIGN-OFF

### Required Approvals
- [ ] Product Manager approval (Gaurav)
- [ ] Engineering Lead approval
- [ ] Security Team approval
- [ ] DevOps Team approval
- [ ] Backend Team notification

### Stakeholder Communication
- [ ] Notify affected teams 2 hours before execution
- [ ] Schedule maintenance window
- [ ] Prepare rollback plan documentation
- [ ] Brief on-call engineer about changes

---

## PHASE 1: PREPARATION (30 minutes)

### 1.1 Backup & Safety
- [ ] Create Firestore backup via Cloud Datastore export
  ```
  gcloud firestore export gs://[bucket-name]/delivery-consolidation-[timestamp]
  ```
- [ ] Verify backup completed successfully
- [ ] Store backup path in this document: `[BACKUP_PATH]`
- [ ] Confirm backup is at least 1 day old (not relying on this migration's backup)

### 1.2 Code Review
- [ ] Code review completed for all files:
  - [ ] `lib/constants/firestore_collections.dart`
  - [ ] `lib/migrations/consolidate_delivery_collections_module9_p0.dart`
  - [ ] `lib/scripts/admin_run_delivery_consolidation.dart`
  - [ ] `firestore.rules`
- [ ] Security team reviewed RLS rules
- [ ] PR approved and merged to main branch

### 1.3 Environment Setup
- [ ] Staging environment ready with latest code
- [ ] Production environment has backup plan
- [ ] Firebase CLI authenticated with correct credentials
- [ ] Terminal session prepared with logs directory
- [ ] Monitoring dashboards open (error logs, latency metrics)

### 1.4 Team Assembly
- [ ] Primary executor on call
- [ ] DevOps engineer on standby
- [ ] On-call engineer monitoring
- [ ] Product manager available for decisions
- [ ] Communications channel open (Slack/Discord)

---

## PHASE 2: STAGING EXECUTION (30 minutes)

### 2.1 Pre-Migration Status
In Firestore Console (staging):
- [ ] Check document counts in each orphaned collection
  - [ ] `delivery_tracking`: [COUNT] docs
  - [ ] `delivery_routes`: [COUNT] docs
  - [ ] `delivery_assignments`: [COUNT] docs
  - [ ] `delivery_otp`: [COUNT] docs
  - [ ] `delivery_agents`: [COUNT] docs
  - [ ] `delivery_locations`: [COUNT] docs
  - [ ] `delivery_status`: [COUNT] docs
  - [ ] `delivery_history`: [COUNT] docs
  - [ ] `delivery_notifications`: [COUNT] docs
  - [ ] `delivery_preferences`: [COUNT] docs
  - [ ] `delivery_tasks`: [COUNT] docs (before migration)

Record timestamp: `[START_TIME]`

### 2.2 Run Migration Script
```bash
# In staging project only
cd /path/to/fufaji-online-business
dart run lib/scripts/admin_run_delivery_consolidation.dart
```

- [ ] Script started successfully
- [ ] Phase 1 status check passed
- [ ] Phase 2 confirmation acknowledged
- [ ] Phase 3 migration started

Wait for completion (typically 5-10 minutes)

- [ ] Phase 3 "MIGRATION COMPLETE" message appears
- [ ] All 7 collection migrations succeeded
- [ ] No error messages in logs
- [ ] Phase 4 post-migration verification shown
- [ ] Phase 5 next steps printed

Capture output to file:
```bash
# Save logs
dart run lib/scripts/admin_run_delivery_consolidation.dart > migration_staging_$(date +%s).log 2>&1
```

### 2.3 Post-Migration Verification
In Firestore Console (staging), verify `delivery_tasks`:
- [ ] `delivery_tasks` document count increased
- [ ] Sample documents have `migratedFrom_*` fields
- [ ] Sample documents have `migrationTimestamp` field
- [ ] `locationHistory` array populated (if applicable)
- [ ] `route` object populated (if applicable)
- [ ] `assignment` object populated (if applicable)
- [ ] `preferences` object populated (if applicable)
- [ ] `history` array populated (if applicable)

Sample spot checks:
- [ ] Random delivery_task #1: verify structure
- [ ] Random delivery_task #2: verify structure
- [ ] Random delivery_task #3: verify structure

### 2.4 Deploy Rules to Staging
```bash
firebase --project staging-project deploy --only firestore:rules
```

- [ ] Rules deployment successful
- [ ] No syntax errors
- [ ] Rules applied to staging Firestore

### 2.5 Test Delivery Module in Staging
Create test cases:

#### Test Case 1: Rider Can See Own Delivery
- [ ] Login as rider
- [ ] View own delivery (should succeed)
- [ ] View another rider's delivery (should fail - no permission)
- [ ] Log: No permission errors in console

#### Test Case 2: Customer Can See Own Delivery
- [ ] Login as customer
- [ ] View own delivery (should succeed)
- [ ] View another customer's delivery (should fail - no permission)
- [ ] Log: No permission errors in console

#### Test Case 3: Dispatcher Can See Branch Deliveries
- [ ] Login as dispatcher
- [ ] View own branch deliveries (should succeed)
- [ ] View another branch's deliveries (should fail - branchId mismatch)
- [ ] Log: No permission errors in console

#### Test Case 4: Admin Can See All Deliveries
- [ ] Login as admin
- [ ] View any delivery (should succeed)
- [ ] View all deliveries dashboard (should succeed)
- [ ] Log: No permission errors in console

#### Test Case 5: Location Tracking
- [ ] Start delivery
- [ ] Submit location update
- [ ] Verify `locationHistory` array updated
- [ ] Log: No Firestore write errors

#### Test Case 6: OTP Verification
- [ ] Generate OTP
- [ ] Verify OTP works
- [ ] Try invalid OTP (should fail)
- [ ] Try expired OTP (should fail)
- [ ] Log: Verification logic works correctly

### 2.6 Monitoring in Staging
- [ ] Error logs: No new errors
- [ ] Firestore: No quota errors
- [ ] API latency: Normal (no spike)
- [ ] User reports: None

---

## PHASE 3: PRODUCTION DEPLOYMENT (1 hour)

### 3.1 Final Pre-Production Checks
- [ ] Staging tests all passed
- [ ] Rules verified in staging
- [ ] Backup verified exists
- [ ] Team ready
- [ ] Maintenance window announced
- [ ] All approvals obtained

### 3.2 Deploy Rules to Production
```bash
firebase --project production-project deploy --only firestore:rules
```

- [ ] Rules deployment successful
- [ ] No syntax errors
- [ ] Rules applied to production Firestore

**IMPORTANT**: Do NOT run migration until rules are deployed!

### 3.3 Run Migration in Production
```bash
dart run lib/scripts/admin_run_delivery_consolidation.dart
```

- [ ] Migration script started
- [ ] Pre-migration status check shows document counts
- [ ] Phase 3 migration started
- [ ] Timestamp: `[PRODUCTION_MIGRATION_START]`

Wait for completion (typically 10-30 minutes depending on data volume)

- [ ] Migration complete message appears
- [ ] All collections migrated successfully
- [ ] No error messages in logs
- [ ] Timestamp: `[PRODUCTION_MIGRATION_END]`

### 3.4 Production Verification
In Firestore Console (production):
- [ ] `delivery_tasks` document count increased
- [ ] Sample documents have migration tracking fields
- [ ] Data structure correct (nested objects, arrays)
- [ ] No obvious data loss

### 3.5 Production Monitoring (1 hour)
Monitor these metrics continuously:

#### Error Logs
- [ ] No spike in delivery-related errors
- [ ] No authentication errors
- [ ] No Firestore rule violations
- [ ] No "permission denied" errors

Command:
```bash
gcloud logging read "resource.type=cloud_firestore AND jsonPayload.message=~'delivery'" \
  --limit 50 --format json
```

#### API Latency
- [ ] Delivery endpoints response time normal
- [ ] No spike in p95 latency
- [ ] No timeouts

Check in Cloud Monitoring dashboard

#### User Reports
- [ ] No user complaints in Slack
- [ ] No customer support tickets about delivery
- [ ] Rider app working normally
- [ ] Customer app working normally

#### Specific Tests
- [ ] Place test order with delivery
- [ ] Assign to test rider
- [ ] Update location (verify locationHistory updates)
- [ ] Complete delivery with OTP
- [ ] Check delivery_tasks document has all data

### 3.6 Success Confirmation
At 1-hour mark:
- [ ] No critical errors
- [ ] System stable
- [ ] All tests passing
- [ ] Ready to proceed with cleanup
- [ ] Timestamp: `[PRODUCTION_VERIFICATION_COMPLETE]`

---

## PHASE 4: MANUAL CLEANUP (15 minutes)

### 4.1 Delete Orphaned Collections
In Firestore Console (Production), delete these collections:
- [ ] `delivery_tracking`
  - Confirm: 0 documents (all migrated to delivery_tasks.completedAt)
  - Delete
- [ ] `delivery_routes`
  - Confirm: 0 documents (all migrated to delivery_tasks.route)
  - Delete
- [ ] `delivery_assignments`
  - Confirm: 0 documents (all migrated to delivery_tasks.assignment)
  - Delete
- [ ] `delivery_otp`
  - Confirm: 0 documents (all migrated to delivery_tasks.otp)
  - Delete
- [ ] `delivery_agents`
  - Confirm: Status (may have recent writes)
  - Decision: [KEEP/DELETE] (discuss with team)
- [ ] `delivery_locations`
  - Confirm: 0 documents (all migrated to delivery_tasks.locationHistory)
  - Delete
- [ ] `delivery_status`
  - Confirm: 0 documents (all migrated to delivery_tasks.status)
  - Delete
- [ ] `delivery_history`
  - Confirm: 0 documents (all migrated to delivery_tasks.history)
  - Delete
- [ ] `delivery_notifications`
  - Confirm: May have documents (move to notifications collection)
  - Decision: [KEEP/DELETE] (discuss with team)
- [ ] `delivery_preferences`
  - Confirm: 0 documents (all migrated to delivery_tasks.preferences)
  - Delete

**NOTE**: Some collections may have recent writes. If so:
1. Add 1 more document to migration service
2. Re-run migration for that collection
3. Verify migration
4. Then delete

### 4.2 Final Verification
- [ ] All orphaned collections deleted
- [ ] Delivery module still working
- [ ] No error spikes after deletion
- [ ] Firestore quota normal

---

## PHASE 5: POST-EXECUTION (15 minutes)

### 5.1 Documentation
- [ ] Update deployment notes
- [ ] Record execution timeline
- [ ] Document any issues encountered
- [ ] Update MODULE_9_P0_DELIVERY_CONSOLIDATION.md with actual timeline

### 5.2 Team Communication
- [ ] Notify team of completion
- [ ] Share results and metrics
- [ ] Close maintenance notification
- [ ] Schedule post-mortem if needed

### 5.3 Critical Action - OTP Hashing
- [ ] Implement bcrypt hashing in DeliveryService
  ```dart
  import 'package:bcrypt/bcrypt.dart';
  
  // In assignOrderToDelivery()
  final hashedOtp = BCrypt.hashpw(otp, BCrypt.gensaltSync());
  ```
- [ ] Update OTP verification logic
  ```dart
  if (!BCrypt.checkpw(enteredOtp, delivery.otpGenerated)) {
    throw Exception('Invalid OTP');
  }
  ```
- [ ] Test OTP hashing in staging
- [ ] Deploy to production

### 5.4 Archive & Cleanup
- [ ] Save migration logs to archive
- [ ] Update memory files with completion status
- [ ] Close GitHub issue
- [ ] Update roadmap

---

## ISSUE RESOLUTION CHECKLIST

### Technical Resolution
- [x] All 10 orphaned collections consolidated into delivery_tasks
- [x] Security rules deployed with proper RLS
- [x] Orphaned collections marked as deprecated (read-only)
- [x] Migration service created and tested
- [x] Admin script created for easy execution
- [ ] OTP hashing implemented (CRITICAL ACTION)
- [ ] Delivery module tested end-to-end
- [ ] Production data migrated and verified

### Documentation
- [x] Implementation guide created (MODULE_9_P0_DELIVERY_CONSOLIDATION.md)
- [x] Summary document created (MODULE_9_P0_IMPLEMENTATION_SUMMARY.md)
- [x] Quick reference created (MODULE_9_P0_QUICK_REFERENCE.txt)
- [x] Execution checklist created (this file)
- [ ] Post-execution report written
- [ ] Issue closed in GitHub

### Stakeholder Communication
- [ ] Product Manager notified of completion
- [ ] Engineering team updated
- [ ] Security team sign-off
- [ ] DevOps team updated
- [ ] Customer support briefed on changes

---

## ROLLBACK PROCEDURE (IF NEEDED)

If migration fails or causes issues:

### Immediate Actions
1. [ ] Stop any ongoing operations
2. [ ] Restore Firestore from backup:
   ```bash
   gcloud firestore import gs://[BUCKET]/delivery-consolidation-[TIMESTAMP]
   ```
3. [ ] Verify restoration successful
4. [ ] Investigate failure in logs
5. [ ] Notify team of rollback

### Investigation
- [ ] Check migration logs for errors
- [ ] Check Firestore quota/limits
- [ ] Check network/connectivity issues
- [ ] Check rule syntax errors

### Fix & Retry
1. [ ] Address root cause
2. [ ] Create new backup
3. [ ] Re-run migration with fixes
4. [ ] Verify success
5. [ ] Document what went wrong

---

## EXECUTION LOG

### Timeline
- **Pre-Execution**: [START_TIME] - [END_TIME]
- **Staging Migration**: [START_TIME] - [END_TIME]
- **Production Migration**: [PRODUCTION_MIGRATION_START] - [PRODUCTION_MIGRATION_END]
- **Verification**: [PRODUCTION_VERIFICATION_START] - [PRODUCTION_VERIFICATION_COMPLETE]
- **Cleanup**: [START_TIME] - [END_TIME]
- **Post-Execution**: [START_TIME] - [END_TIME]

### Metrics
- **Backup Path**: [BACKUP_PATH]
- **Staging Migration Duration**: [DURATION] minutes
- **Production Migration Duration**: [DURATION] minutes
- **Documents Migrated**: [TOTAL_COUNT]
- **Errors Encountered**: [COUNT]
- **Issues**: [NONE/DESCRIBE]

### Sign-Off
- **Primary Executor**: [NAME] - [SIGNATURE] - [DATE]
- **DevOps Lead**: [NAME] - [SIGNATURE] - [DATE]
- **Product Manager**: [NAME] - [SIGNATURE] - [DATE]
- **Security Lead**: [NAME] - [SIGNATURE] - [DATE]

---

## NEXT STEPS (AFTER THIS CHECKLIST)

1. **OTP Hashing** (CRITICAL)
   - Implement bcrypt in DeliveryService
   - Test thoroughly
   - Deploy to production

2. **Code Cleanup**
   - Remove @deprecated comments from constants (after grace period)
   - Remove legacy collection references
   - Update queries to use consolidated fields

3. **Monitoring**
   - Add alerts for delivery collection access patterns
   - Monitor for any regression
   - Track RLS rule effectiveness

4. **Training**
   - Brief team on consolidated collection structure
   - Update API documentation
   - Share best practices for unified collection queries

5. **Audit**
   - Review final state of delivery_tasks collection
   - Verify RLS prevents unauthorized access
   - Document any permission issues

---

## CONTACTS & ESCALATION

### Primary Contact
- **Name**: [PRIMARY_EXECUTOR]
- **Phone**: [PHONE]
- **Slack**: [HANDLE]

### Escalation
- **DevOps Lead**: [NAME] [CONTACT]
- **Security Lead**: [NAME] [CONTACT]
- **Product Manager**: [NAME] [CONTACT]
- **On-Call Engineer**: [NAME] [CONTACT]

### Emergency Rollback
If critical issues arise:
1. Page primary executor
2. If unresponsive, page DevOps lead
3. Restore from backup immediately
4. Notify product manager

---

## FINAL NOTES

**BACKUP CRITICAL**: Do not proceed without verified backup
**OTP HASHING CRITICAL**: Implement before next production deployment
**READ LOGS CAREFULLY**: Detailed error messages guide troubleshooting
**COMMUNICATE**: Keep team informed at each phase
**MONITOR**: Watch for 1 hour minimum after production migration

---

**Document Version**: 1.0  
**Created**: 2026-06-23  
**Last Updated**: [COMPLETION_DATE]  
**Status**: [READY_FOR_EXECUTION / IN_PROGRESS / COMPLETED]  

---

**READY TO EXECUTE!**

Print this checklist and check off items as you go.
Keep logs and document any deviations.
