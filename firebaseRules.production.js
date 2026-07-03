/**
 * FUFAJI STORE — Firebase Security Rules (Production)
 * Date: 2026-07-02
 * Status: SYNCED WITH CONSOLE — PRODUCTION-READY
 *
 * This file is NOW IN SYNC with the actual Firebase Console rules.
 * All 50+ collections, role-based access, and backend service auth are included.
 */

rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {

    // ========================================================================
    // HELPER FUNCTIONS
    // ========================================================================
    function isSignedIn() {
      return request.auth != null;
    }
    function getUserData() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data;
    }
    function hasRole(roleName) {
      return request.auth.token[roleName] == true;
    }
    function isOwner() { return hasRole('owner') || hasRole('franchiseOwner'); }
    function isAdmin() { return hasRole('admin') || hasRole('superAdmin'); }
    function isCustomer() { return hasRole('customer'); }
    function isEmployee() { return hasRole('employee'); }
    function isRider() { return hasRole('rider'); }
    function isDispatcher() { return hasRole('dispatcher'); }
    function isBranchManager() { return hasRole('branchManager'); }
    function isSupplier() { return hasRole('supplier'); }
    function isGlobalAdmin() { return isOwner() || isAdmin(); }
    function isServiceAuth() {
      return request.auth.token.serviceAuth == true;
    }
    function isOrderTerminal() {
      return resource.data.status in ['delivered', 'cancelled', 'returned'];
    }
    function isStaff() {
      return isOwner() || isAdmin() || isEmployee() || isRider() || isBranchManager() || isDispatcher();
    }
    function getBranchId() {
      return getUserData().branchId;
    }
    function isOwningUser(uid) {
      return isSignedIn() && request.auth.uid == uid;
    }
    function isBranchMatch(resourceBranchId) {
      return getBranchId() == resourceBranchId;
    }
    function isApprovedEmployee() {
      return isEmployee() && getUserData().isActive == true;
    }
    function isShopOwner(shopId) {
      return isSignedIn() && get(/databases/$(database)/documents/shops/$(shopId)).data.ownerId == request.auth.uid;
    }

    // ========================================================================
    // USERS COLLECTION
    // ========================================================================
    match /users/{userId} {
      allow read: if isSignedIn() && (isOwningUser(userId) || isGlobalAdmin() || isBranchManager() || isDispatcher());
      allow create: if isSignedIn() && isOwningUser(userId);
      allow update: if isSignedIn() && (
        (isOwningUser(userId) && request.resource.data.role == resource.data.role) ||
        isGlobalAdmin()
      );
      allow delete: if false;
      match /wallet/{walletId} {
        allow read: if isSignedIn() && (isOwningUser(userId) || isGlobalAdmin());
        allow write: if isGlobalAdmin();
      }
      match /notifications/{notifId} {
        allow read: if isSignedIn() && (isOwningUser(userId) || isGlobalAdmin());
        allow write: if isGlobalAdmin();
      }
    }
    match /customer_wallet/{userId} {
      allow read: if isSignedIn() && (isOwningUser(userId) || isGlobalAdmin());
      allow write: if false;
    }

    // ========================================================================
    // OWNERS COLLECTION (service role only)
    // ========================================================================
    match /owners/{ownerId} {
      allow read: if isSignedIn() && isGlobalAdmin();
      allow write: if isSignedIn() && (isGlobalAdmin() || isServiceAuth());
    }

    // ========================================================================
    // EMPLOYEES COLLECTION
    // ========================================================================
    match /employees/{employeeId} {
      allow read: if isSignedIn() && (
        isGlobalAdmin() ||
        isBranchManager() ||
        (employeeId == request.auth.uid && isEmployee())
      );
      allow create: if isSignedIn() && (
        isGlobalAdmin() ||
        (isOwner() && request.resource.data.ownerId == request.auth.uid)
      );
      allow update: if isSignedIn() && (
        isGlobalAdmin() ||
        (isOwner() && resource.data.ownerId == request.auth.uid &&
         request.resource.data.empStatus == resource.data.empStatus) ||
        (employeeId == request.auth.uid && false)
      );
      allow delete: if isSignedIn() && isGlobalAdmin();
    }

    // ========================================================================
    // ACTIVE_SESSIONS COLLECTION
    // ========================================================================
    match /active_sessions/{sessionId} {
      allow read: if isSignedIn() && (
        isGlobalAdmin() ||
        resource.data.userId == request.auth.uid
      );
      allow create: if isSignedIn() && request.resource.data.userId == request.auth.uid;
      allow update: if isSignedIn() && (
        isGlobalAdmin() ||
        (resource.data.userId == request.auth.uid &&
         request.resource.data.userId == request.auth.uid)
      );
      allow delete: if isSignedIn() && (
        isGlobalAdmin() ||
        resource.data.userId == request.auth.uid
      );
    }

    // ========================================================================
    // PRE_AUTHORIZED_USERS COLLECTION (service role only)
    // ========================================================================
    match /pre_authorized_users/{phoneOrEmail} {
      allow read: if isSignedIn() && isGlobalAdmin();
      allow write: if isSignedIn() && (isGlobalAdmin() || isServiceAuth());
    }

    // ========================================================================
    // PIN LOCKOUTS (SECURITY)
    // ========================================================================
    match /pin_lockouts/{userId} {
      allow read: if isSignedIn() && (
        request.auth.uid == userId ||
        isGlobalAdmin()
      );
      allow create: if isSignedIn() && isGlobalAdmin();
      allow update: if isSignedIn() && isGlobalAdmin();
      allow delete: if isSignedIn() && isGlobalAdmin();
    }

    // ========================================================================
    // ORDERS COLLECTION
    // ========================================================================
    match /orders/{orderId} {
      allow read: if isSignedIn() && (
        resource.data.customerId == request.auth.uid ||
        (isBranchManager() && isBranchMatch(resource.data.branchId)) ||
        (isDispatcher() && isBranchMatch(resource.data.branchId)) ||
        isGlobalAdmin()
      );
      allow create: if isSignedIn() && isCustomer() && request.resource.data.customerId == request.auth.uid;
      allow update: if isSignedIn() && (
        (!isOrderTerminal()) && (
          (isBranchManager() && isBranchMatch(resource.data.branchId)) ||
          (isDispatcher() && isBranchMatch(resource.data.branchId)) ||
          (isCustomer() && resource.data.customerId == request.auth.uid &&
           resource.data.status in ['pending', 'confirmed'] &&
           request.resource.data.status == 'cancelled') ||
          isGlobalAdmin()
        )
      );
      allow delete: if false;
    }

    // ========================================================================
    // PRODUCTS COLLECTION
    // ========================================================================
    match /products/{productId} {
      allow read: if true;
      allow write: if isSignedIn() && isGlobalAdmin();
      match /reviews/{reviewId} {
        allow read: if true;
        allow create: if isSignedIn() && isCustomer();
        allow update, delete: if isSignedIn() && (resource.data.customerId == request.auth.uid || isGlobalAdmin());
      }
      match /images/{imageId} {
        allow read: if true;
        allow write: if isSignedIn() && isGlobalAdmin();
      }
      match /{document=**} {
        allow read: if true;
        allow write: if isSignedIn() && isGlobalAdmin();
      }
    }

    // ========================================================================
    // COUPONS COLLECTION
    // ========================================================================
    match /coupons/{couponId} {
      allow read: if isSignedIn() && (
        isGlobalAdmin() ||
        (isCustomer() && resource.data.expiryDate != null && request.time < resource.data.expiryDate)
      );
      allow create: if isSignedIn() && (
        isGlobalAdmin() ||
        (isOwner() && request.resource.data.shopOwnerId == request.auth.uid)
      );
      allow update: if isSignedIn() && (
        isGlobalAdmin() ||
        (isOwner() && resource.data.shopOwnerId == request.auth.uid &&
         request.resource.data.shopOwnerId == resource.data.shopOwnerId)
      );
      allow delete: if isSignedIn() && isGlobalAdmin();
    }
    match /coupon_redemptions/{redemptionId} {
      allow read: if isSignedIn() && (
        resource.data.userId == request.auth.uid ||
        isGlobalAdmin()
      );
      allow create: if isSignedIn() && request.resource.data.userId == request.auth.uid;
      allow update: if isSignedIn() && isGlobalAdmin();
      allow delete: if false;
    }

    // ========================================================================
    // INVENTORY COLLECTION
    // ========================================================================
    match /inventory/{inventoryId} {
      allow read: if isSignedIn() && (
        isGlobalAdmin() ||
        ((isBranchManager() || isEmployee()) && isBranchMatch(resource.data.branchId))
      );
      allow write: if isSignedIn() && (
        isGlobalAdmin() ||
        (isBranchManager() && isBranchMatch(resource.data.branchId))
      );
    }

    // ========================================================================
    // PROCUREMENT SYSTEM
    // ========================================================================
    match /inventory_events/{eventId} {
      allow read: if isSignedIn() && isGlobalAdmin();
      allow write: if false;
    }
    match /change_requests/{requestId} {
      allow read: if isSignedIn() && (isGlobalAdmin() || resource.data.submitted_by == request.auth.uid);
      allow create: if isSignedIn() && isStaff();
      allow update: if isSignedIn() && isGlobalAdmin();
    }
    match /bulk_operations/{opId} {
      allow read: if isSignedIn() && isGlobalAdmin();
      allow write: if isSignedIn() && isGlobalAdmin();
    }
    match /purchase_requests/{requestId} {
      allow read: if isSignedIn() && (
        isGlobalAdmin() ||
        (isBranchManager() && isBranchMatch(resource.data.branchId)) ||
        (isSupplier() && resource.data.supplierId == request.auth.uid)
      );
      allow create: if isSignedIn() && isBranchManager() && request.resource.data.branchId == getBranchId();
      allow update: if isSignedIn() && (isGlobalAdmin() || (isSupplier() && resource.data.supplierId == request.auth.uid));
    }
    match /supplier_quotes/{quoteId} {
      allow read: if isSignedIn() && (isGlobalAdmin() || (isSupplier() && resource.data.supplierId == request.auth.uid));
      allow create, update: if isSignedIn() && isSupplier() && request.resource.data.supplierId == request.auth.uid;
    }
    match /purchase_orders/{poId} {
      allow read: if isSignedIn() && (
        isGlobalAdmin() ||
        (isBranchManager() && isBranchMatch(resource.data.branchId)) ||
        (isSupplier() && resource.data.supplierId == request.auth.uid)
      );
      allow write: if isSignedIn() && isGlobalAdmin();
    }
    match /goods_receipts/{receiptId} {
      allow read: if isSignedIn() && (
        isGlobalAdmin() ||
        (isBranchManager() && isBranchMatch(resource.data.branchId)) ||
        (isSupplier() && resource.data.supplierId == request.auth.uid)
      );
      allow write: if isSignedIn() && (
        isGlobalAdmin() ||
        (isBranchManager() && isBranchMatch(request.resource.data.branchId))
      );
    }

    // ========================================================================
    // DELIVERY MANAGEMENT
    // ========================================================================
    match /delivery_tasks/{taskId} {
      allow read: if isSignedIn() && (
        isGlobalAdmin() ||
        (isDispatcher() && isBranchMatch(resource.data.branchId)) ||
        (isRider() && resource.data.riderId == request.auth.uid)
      );
      allow create: if isSignedIn() && (isGlobalAdmin() || (isDispatcher() && isBranchMatch(request.resource.data.branchId)));
      allow update: if isSignedIn() && (
        isGlobalAdmin() ||
        (isDispatcher() && isBranchMatch(resource.data.branchId)) ||
        (isRider() && resource.data.riderId == request.auth.uid)
      );
    }
    match /delivery_batches/{batchId} {
      allow read: if isSignedIn() && (
        isGlobalAdmin() ||
        (isDispatcher() && isBranchMatch(resource.data.branchId)) ||
        (isRider() && resource.data.riderId == request.auth.uid)
      );
      allow create: if isSignedIn() && (isGlobalAdmin() || (isDispatcher() && isBranchMatch(request.resource.data.branchId)));
      allow update: if isSignedIn() && (
        isGlobalAdmin() ||
        (isDispatcher() && isBranchMatch(resource.data.branchId)) ||
        (isRider() && resource.data.riderId == request.auth.uid)
      );
    }
    match /deliveries/{deliveryId} {
      allow read: if isSignedIn() && (
        isGlobalAdmin() ||
        (isDispatcher() && isBranchMatch(resource.data.branchId)) ||
        (isRider() && resource.data.riderId == request.auth.uid) ||
        (isCustomer() && resource.data.customerId == request.auth.uid)
      );
      allow create: if isSignedIn() && (isGlobalAdmin() || isServiceAuth());
      allow update: if isSignedIn() && (
        isGlobalAdmin() ||
        (isDispatcher() && isBranchMatch(resource.data.branchId)) ||
        (isRider() && resource.data.riderId == request.auth.uid)
      );
      allow delete: if false;
    }
    match /delivery_routes/{routeId} {
      allow read: if isSignedIn() && (
        isGlobalAdmin() ||
        (isDispatcher() && isBranchMatch(resource.data.branchId)) ||
        (isRider() && resource.data.riderId == request.auth.uid)
      );
      allow write: if isSignedIn() && (isGlobalAdmin() || isServiceAuth());
      allow delete: if false;
    }
    match /delivery_location_history/{histId} {
      allow read: if isSignedIn() && (
        isGlobalAdmin() ||
        (isDispatcher() && isBranchMatch(resource.data.branchId)) ||
        (isRider() && resource.data.riderId == request.auth.uid) ||
        (isCustomer() && resource.data.customerId == request.auth.uid)
      );
      allow create: if isSignedIn() && (
        isGlobalAdmin() ||
        (isRider() && request.resource.data.riderId == request.auth.uid) ||
        isServiceAuth()
      );
      allow update: if isSignedIn() && (isGlobalAdmin() || isServiceAuth());
      allow delete: if false;
    }
    match /delivery_assignments/{assignmentId} {
      allow read: if isSignedIn() && (
        isGlobalAdmin() ||
        (isDispatcher() && isBranchMatch(resource.data.branchId)) ||
        (isRider() && resource.data.riderId == request.auth.uid)
      );
      allow write: if isSignedIn() && (isGlobalAdmin() || isServiceAuth());
      allow delete: if false;
    }
    match /delivery_proofs/{proofId} {
      allow read: if isSignedIn() && (
        isGlobalAdmin() ||
        (isDispatcher() && isBranchMatch(resource.data.branchId)) ||
        (isRider() && resource.data.riderId == request.auth.uid) ||
        (isCustomer() && resource.data.customerId == request.auth.uid)
      );
      allow create: if isSignedIn() && (
        isGlobalAdmin() ||
        (isRider() && request.resource.data.riderId == request.auth.uid)
      );
      allow update: if isSignedIn() && (isGlobalAdmin() || isServiceAuth());
      allow delete: if false;
    }
    match /delivery_agents/{agentId} {
      allow read: if isSignedIn() && (
        isGlobalAdmin() || isDispatcher() || agentId == request.auth.uid
      );
      allow write: if false;
    }
    match /delivery_notifications/{notifId} {
      allow read: if isSignedIn() && (
        resource.data.recipientId == request.auth.uid || isGlobalAdmin()
      );
      allow write: if isSignedIn() && (isGlobalAdmin() || isServiceAuth());
    }
    match /delivery_preferences/{prefId} {
      allow read: if isSignedIn() && (
        resource.data.customerId == request.auth.uid || isGlobalAdmin()
      );
      allow update: if isSignedIn() && resource.data.customerId == request.auth.uid;
      allow create: if isSignedIn() && request.resource.data.customerId == request.auth.uid;
      allow delete: if false;
    }
    match /delivery_events/{eventId} {
      allow read: if isSignedIn() && (
        isGlobalAdmin() ||
        isDispatcher() ||
        resource.data.riderId == request.auth.uid ||
        resource.data.customerId == request.auth.uid
      );
      allow create: if isSignedIn() && isStaff();
      allow update: if isSignedIn() && (isGlobalAdmin() || isDispatcher());
    }
    match /delivery_exceptions/{excId} {
      allow read: if isSignedIn() && (isGlobalAdmin() || isDispatcher());
      allow create: if isSignedIn() && isStaff();
      allow update: if isSignedIn() && (isGlobalAdmin() || isDispatcher());
    }
    match /delivery_sla_rules/{ruleId} {
      allow read: if isSignedIn() && (isGlobalAdmin() || isDispatcher());
      allow write: if isSignedIn() && isGlobalAdmin();
    }
    match /delivery_slots/{slotId} {
      allow read: if isSignedIn();
      allow write: if isSignedIn() && isGlobalAdmin();
    }

    // ========================================================================
    // CASH COLLECTION AUDIT
    // ========================================================================
    match /cash_audit/{auditId} {
      allow read: if isSignedIn() && (isGlobalAdmin() || (isDispatcher() && isBranchMatch(resource.data.branchId)));
      allow create: if isSignedIn() && (isDispatcher() || isRider());
      allow update: if false;
      allow delete: if false;
    }

    // ========================================================================
    // OPERATIONS QUEUES
    // ========================================================================
    match /work_queue/{taskId} {
      allow read: if isSignedIn() && (
        isGlobalAdmin() ||
        (isBranchManager() && isBranchMatch(resource.data.branchId)) ||
        (isDispatcher() && isBranchMatch(resource.data.branchId))
      );
      allow write: if isSignedIn() && (
        isGlobalAdmin() ||
        ((isBranchManager() || isDispatcher()) && isBranchMatch(resource.data.branchId))
      );
    }
    match /approval_requests/{requestId} {
      allow read: if isSignedIn() && (
        isGlobalAdmin() ||
        resource.data.requesterId == request.auth.uid ||
        resource.data.approverId == request.auth.uid
      );
      allow create: if isSignedIn() && request.resource.data.requesterId == request.auth.uid;
      allow update: if isSignedIn() && (
        isGlobalAdmin() ||
        resource.data.approverId == request.auth.uid
      );
    }

    // ========================================================================
    // CACHE COLLECTION
    // ========================================================================
    match /cache/{documentId=**} {
      allow read: if true;
      allow write: if documentId == 'ping_test' || (isSignedIn() && (isStaff() || isServiceAuth()));
    }

    // ========================================================================
    // ANALYTICS
    // ========================================================================
    match /analytics/{analyticsId} {
      allow read: if isSignedIn() && isGlobalAdmin();
      allow write: if false;
    }
    match /alerts/{alertId} {
      allow read: if isSignedIn() && isGlobalAdmin();
      allow write: if false;
    }
    match /inventory_alerts/{alertId} {
      allow read: if isSignedIn() && isGlobalAdmin();
      allow write: if false;
    }

    // ========================================================================
    // THIRD PARTY INTEGRATION QUEUES
    // ========================================================================
    match /webhook_events/{eventId} {
      allow read: if isSignedIn() && isGlobalAdmin();
      allow write: if false;
    }
    match /whatsapp_incoming/{msgId} {
      allow read: if isSignedIn() && isGlobalAdmin();
      allow write: if false;
    }
    match /report_trigger_queue/{reportId} {
      allow read: if isSignedIn() && isGlobalAdmin();
      allow write: if false;
    }
    match /low_stock_alerts/{alertId} {
      allow read: if isSignedIn() && isGlobalAdmin();
      allow write: if false;
    }

    // ========================================================================
    // SETTINGS
    // ========================================================================
    match /settings/{docId} {
      allow read: if isSignedIn();
      allow write: if isSignedIn() && isGlobalAdmin();
      match /shop_config/{configId} {
        allow read: if true;
        allow write: if isSignedIn() && isGlobalAdmin();
        match /branches/{branchId} {
          allow read: if true;
          allow write: if isSignedIn() && isGlobalAdmin();
        }
        match /operating_hours/{dayId} {
          allow read: if true;
          allow write: if isSignedIn() && isGlobalAdmin();
        }
      }
    }

    // ========================================================================
    // FINANCIAL & SECURITY LOGS
    // ========================================================================
    match /audit_logs/{logId} {
      allow read: if isSignedIn() && isGlobalAdmin();
      allow create: if isSignedIn() && (request.resource.data.userId == request.auth.uid || isStaff());
      allow update, delete: if false;
    }
    match /security_events/{eventId} {
      allow read: if isSignedIn() && isGlobalAdmin();
      allow create: if isSignedIn();
      allow update, delete: if false;
    }
    match /wallet_transactions/{txId} {
      allow read: if isSignedIn() && (isGlobalAdmin() || resource.data.userId == request.auth.uid);
      allow write: if false;
    }
    match /refund_requests/{refundId} {
      allow read: if isSignedIn() && (
        isGlobalAdmin() ||
        resource.data.customerId == request.auth.uid
      );
      allow create: if isSignedIn() && request.resource.data.customerId == request.auth.uid;
      allow update: if isSignedIn() && isGlobalAdmin();
    }
    match /transactions/{txId} {
      allow read: if isSignedIn() && (
        isGlobalAdmin() ||
        resource.data.customerId == request.auth.uid
      );
      allow write: if false;
    }
    match /payment_disputes/{disputeId} {
      allow read: if isSignedIn() && (
        isGlobalAdmin() ||
        resource.data.customerId == request.auth.uid
      );
      allow write: if false;
    }

    // ========================================================================
    // DEAD LETTER QUEUE
    // ========================================================================
    match /dead_letter_rds_sync/{docId} {
      allow read: if isSignedIn() && isGlobalAdmin();
      allow write: if isSignedIn() && isStaff();
      allow delete: if isGlobalAdmin();
    }

    // ========================================================================
    // PAYMENT COLLECTIONS (Cloud Functions only)
    // ========================================================================
    match /payments/{paymentId} {
      allow read: if isSignedIn() && (
        isGlobalAdmin() ||
        resource.data.uid == request.auth.uid ||
        resource.data.customerId == request.auth.uid
      );
      allow write: if false;
    }
    match /webhook_logs/{logId} {
      allow read: if isSignedIn() && isGlobalAdmin();
      allow write: if false;
    }
    match /reconciliation_queue/{reconId} {
      allow read: if isSignedIn() && isGlobalAdmin();
      allow write: if false;
    }
    match /payment_retry_queue/{retryId} {
      allow read: if isSignedIn() && isGlobalAdmin();
      allow write: if false;
    }
    match /payment_retries/{retryId} {
      allow read: if isSignedIn() && isGlobalAdmin();
      allow write: if false;
    }
    match /payment_retry_counters/{orderId} {
      allow read: if isSignedIn() && isGlobalAdmin();
      allow write: if false;
    }
    match /payment_reconciliation_log/{logId} {
      allow read: if isSignedIn() && isGlobalAdmin();
      allow write: if false;
    }
    match /payment_orphans/{orphanId} {
      allow read: if isSignedIn() && isGlobalAdmin();
      allow write: if false;
    }
    match /owner_notifications/{notifId} {
      allow read: if isSignedIn() && isGlobalAdmin();
      allow write: if false;
    }
    match /campaign_triggers/{triggerId} {
      allow read: if isSignedIn() && isGlobalAdmin();
      allow write: if isSignedIn() && isGlobalAdmin();
    }
    match /cashback_triggers/{triggerId} {
      allow read: if isSignedIn() && isGlobalAdmin();
      allow write: if isSignedIn() && isStaff();
    }

    // ========================================================================
    // E-COMMERCE COLLECTIONS
    // ========================================================================
    match /product_locks/{productId} {
      allow read: if isSignedIn() && isGlobalAdmin();
      allow write: if false;
    }
    match /refund_logs/{refundId} {
      allow read: if isSignedIn() && isGlobalAdmin();
      allow write: if false;
    }
    match /release_notes/{noteId} {
      allow read: if true;
      allow write: if isSignedIn() && isGlobalAdmin();
    }
    match /lightning_deals/{dealId} {
      allow read: if true;
      allow write: if isSignedIn() && isGlobalAdmin();
    }
    match /carts/{userId} {
      allow read, create, update, delete: if isSignedIn() && isOwningUser(userId);
      match /items/{itemId} {
        allow read, create, update, delete: if isSignedIn() && isOwningUser(userId);
      }
    }
    match /family_groups/{familyId} {
      allow read: if isSignedIn() && (
        resource.data.ownerUserId == request.auth.uid ||
        getUserData().familyGroupId == familyId ||
        isGlobalAdmin()
      );
      allow create: if isSignedIn();
      allow update: if isSignedIn() && (
        resource.data.ownerUserId == request.auth.uid ||
        isGlobalAdmin()
      );
      match /approval_requests/{requestId} {
        allow read, write: if isSignedIn() && (
          get(/databases/$(database)/documents/family_groups/$(familyId)).data.ownerUserId == request.auth.uid ||
          getUserData().familyGroupId == familyId ||
          isGlobalAdmin()
        );
      }
    }
    match /shops/{shopId} {
      allow read: if isSignedIn();
      allow create, update: if isSignedIn() && (isGlobalAdmin() || isShopOwner(shopId));
      allow delete: if isSignedIn() && isGlobalAdmin();
      match /branches/{branchId} {
        allow read: if isSignedIn();
        allow create, update: if isSignedIn() && isShopOwner(shopId);
        allow delete: if isSignedIn() && isGlobalAdmin();
      }
      match /employees/{employeeId} {
        allow read: if isSignedIn() && (isShopOwner(shopId) || isGlobalAdmin());
        allow create, update, delete: if isSignedIn() && isShopOwner(shopId);
      }
      match /inventory/{inventoryId} {
        allow read: if isSignedIn() && (isApprovedEmployee() || isShopOwner(shopId) || isGlobalAdmin());
        allow create, update: if isSignedIn() && (isShopOwner(shopId) || isGlobalAdmin());
        allow delete: if isSignedIn() && isGlobalAdmin();
      }
      match /orders/{orderId} {
        allow read: if isSignedIn() && (isApprovedEmployee() || isShopOwner(shopId) || isGlobalAdmin());
      }
      match /analytics/{analyticsId} {
        allow read: if isSignedIn() && (isShopOwner(shopId) || isGlobalAdmin());
      }
    }
    match /return_requests/{returnId} {
      allow read: if isSignedIn() && (
        resource.data.customerId == request.auth.uid ||
        isApprovedEmployee() ||
        isGlobalAdmin()
      );
      allow create: if isSignedIn() && isCustomer() && request.resource.data.customerId == request.auth.uid;
      allow update: if isSignedIn() && (
        isApprovedEmployee() ||
        isGlobalAdmin()
      );
      allow delete: if isSignedIn() && isGlobalAdmin();
    }
    match /returns/{returnId} {
      allow read: if isSignedIn() && (
        resource.data.customerId == request.auth.uid ||
        isApprovedEmployee() ||
        isGlobalAdmin()
      );
      allow create: if isSignedIn() && isCustomer() && request.resource.data.customerId == request.auth.uid;
      allow update: if isSignedIn() && (
        isApprovedEmployee() ||
        isGlobalAdmin()
      );
      allow delete: if isSignedIn() && isGlobalAdmin();
    }
    match /reviews/{reviewId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn() && isCustomer() &&
        request.resource.data.customerId == request.auth.uid &&
        request.resource.data.rating >= 1 &&
        request.resource.data.rating <= 5;
      allow update: if isSignedIn() && resource.data.customerId == request.auth.uid;
      allow delete: if isSignedIn() && (resource.data.customerId == request.auth.uid || isGlobalAdmin());
    }
    match /chats/{chatId} {
      allow read: if isSignedIn() && (
        request.auth.uid in resource.data.participantIds ||
        isGlobalAdmin()
      );
      allow create: if isSignedIn() && request.auth.uid in request.resource.data.participantIds;
      allow update: if isSignedIn() && (
        request.auth.uid in resource.data.participantIds ||
        isGlobalAdmin()
      );
      match /messages/{messageId} {
        allow read: if isSignedIn() && (
          request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.participantIds ||
          isGlobalAdmin()
        );
        allow create: if isSignedIn() && request.resource.data.senderId == request.auth.uid;
        allow update, delete: if isSignedIn() && (
          resource.data.senderId == request.auth.uid ||
          isGlobalAdmin()
        );
      }
    }
    match /delivery_partners/{partnerId} {
      allow read: if isSignedIn() && (isOwningUser(partnerId) || isGlobalAdmin());
      allow create, update: if isSignedIn() && (isOwningUser(partnerId) || isGlobalAdmin());
      allow delete: if isSignedIn() && isGlobalAdmin();
      match /deliveries/{deliveryId} {
        allow read: if isSignedIn() && (
          resource.data.deliveryPartnerId == request.auth.uid ||
          isGlobalAdmin()
        );
        allow update: if isSignedIn() && (
          resource.data.deliveryPartnerId == request.auth.uid ||
          isGlobalAdmin()
        );
      }
    }
    match /subscriptions/{subscriptionId} {
      allow read: if isSignedIn() && (
        resource.data.customerId == request.auth.uid ||
        isGlobalAdmin()
      );
      allow create: if isSignedIn() && isCustomer();
      allow update: if isSignedIn() && (
        resource.data.customerId == request.auth.uid ||
        isGlobalAdmin()
      );
      allow delete: if isSignedIn() && (
        resource.data.customerId == request.auth.uid ||
        isGlobalAdmin()
      );
    }
  }
}

/*
========== DEPLOYMENT STEPS ==========

1. Go to Firebase Console → Firestore → Rules
2. Copy & paste the above rules
3. Click "Publish"
4. Verify in "Rules Playground" for each collection:
   - Test: Anonymous user reads products (ALLOW)
   - Test: User creates own /users/{uid} (ALLOW)
   - Test: User creates /orders (ALLOW)
   - Test: User reads another's order (DENY)
   - Test: Admin updates order status (ALLOW)

5. Test with your app:
   - Google Sign-In → should create /users/{uid} automatically
   - Browse products → should load instantly
   - Create order → should succeed

6. Monitor Firestore Console for any "permission denied" errors
   If you see errors, check:
   - User is authenticated (request.auth != null)
   - User UID matches the path
   - Admin custom claim is set correctly for admin users

========== CUSTOM CLAIMS SETUP ==========

For admin users, set custom claim via Firebase Console or Cloud Function:

const admin = require('firebase-admin');

admin.initializeApp();

const uid = 'user-uid-here';
admin.auth().setCustomUserClaims(uid, { admin: true })
  .then(() => console.log('Admin claim set'));

Then in Security Rules, admin users are identified by:
  request.auth.token.admin == true
*/
