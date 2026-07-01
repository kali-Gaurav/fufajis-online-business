import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

// Initialize Firebase Admin SDK
admin.initializeApp();

// Export all Cloud Functions
export * from './inventory/deductInventoryAtomic';
export * from './inventory/releaseInventoryLock';
export * from './refunds/processRefundWithStockRestore';

// Export payment Cloud Functions (createRazorpayOrder + verifyRazorpayPayment)
export * from './payments/createRazorpayOrder';
export * from './payments/verifyRazorpayPayment';
export * from './payments/processCashbackTrigger';

// Export payment webhook handlers
export * from './webhooks/razorpay_webhook';

// Export payment retry processor
export * from './tasks/process_payment_retries';

// Export Automation Engine Cron Jobs
export * from './automation/cronJobs';

// Export Mission Control ("Karyalay") AI Agentic Employee System
export * from './runtime/agentToolExecutor';
export * from './runtime/seedMissionControl';
export * from './runtime/scheduledAgentRunner';
export * from './runtime/chiefOfStaff';
export * from './runtime/businessAnalyst';
export * from './runtime/broadcastSender';
export * from './runtime/inventoryCatalog';
