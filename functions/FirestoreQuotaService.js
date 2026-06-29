const admin = require('firebase-admin');
const logger = require('./LoggerService');

/**
 * Firestore Quota Monitoring Service
 * Tracks daily usage against free tier limits
 *
 * Free tier limits:
 * - Reads: 50,000/day
 * - Writes: 20,000/day
 * - Deletes: 20,000/day
 * - Storage: 1GB
 */
class FirestoreQuotaService {
  constructor() {
    this.db = admin.firestore();
    this.quotaCollection = 'firestore_quota_metrics';

    // Alert thresholds
    this.alertThresholds = {
      reads: 50000,
      writes: 20000,
      deletes: 20000,
      storage: 1024 * 1024 * 1024, // 1GB in bytes
      alertAt: 0.8, // Alert when 80% used
    };

    // Counters for current session
    this.sessionCounters = {
      reads: 0,
      writes: 0,
      deletes: 0,
    };
  }

  /**
   * Initialize quota tracking
   * Call at app startup to reset daily counters
   */
  async initialize() {
    try {
      const today = this.getTodayString();
      const quotaRef = this.db
        .collection(this.quotaCollection)
        .doc(`quota_${today}`);
      const doc = await quotaRef.get();

      if (!doc.exists) {
        // Create new daily record
        await quotaRef.set({
          date: today,
          reads: 0,
          writes: 0,
          deletes: 0,
          storage: 0,
          alerts: [],
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        logger.info('Daily quota tracking initialized', {
          date: today,
        });
      }
    } catch (error) {
      logger.error('Error initializing quota tracking', error, {
        action: 'initialize',
      });
    }
  }

  /**
   * Track a read operation
   */
  async trackRead(docCount = 1) {
    this.sessionCounters.reads += docCount;
    await this.updateQuotaMetric('reads', docCount);
  }

  /**
   * Track a write operation
   */
  async trackWrite(docCount = 1) {
    this.sessionCounters.writes += docCount;
    await this.updateQuotaMetric('writes', docCount);
  }

  /**
   * Track a delete operation
   */
  async trackDelete(docCount = 1) {
    this.sessionCounters.deletes += docCount;
    await this.updateQuotaMetric('deletes', docCount);
  }

  /**
   * Update quota metrics in Firestore
   */
  async updateQuotaMetric(operation, count = 1) {
    try {
      const today = this.getTodayString();
      const quotaRef = this.db
        .collection(this.quotaCollection)
        .doc(`quota_${today}`);

      // Atomically increment counter
      const updateData = {};
      updateData[operation] = admin.firestore.FieldValue.increment(count);

      await quotaRef.update(updateData);

      // Check if alert threshold reached
      await this.checkAlertThreshold(operation);
    } catch (error) {
      logger.debug('Error updating quota metric', {
        error: error.message,
        operation,
        count,
      });
    }
  }

  /**
   * Check if quota exceeds alert threshold
   */
  async checkAlertThreshold(operation) {
    try {
      const today = this.getTodayString();
      const quotaRef = this.db
        .collection(this.quotaCollection)
        .doc(`quota_${today}`);
      const doc = await quotaRef.get();
      const data = doc.data();

      const current = data[operation] || 0;
      const limit = this.alertThresholds[operation];
      const usagePercent = (current / limit) * 100;

      if (usagePercent >= 80) {
        // Alert when >80%
        const alert = {
          operation,
          current,
          limit,
          usagePercent: Math.round(usagePercent),
          alertedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        // Log the alert
        logger.warning(`Firestore quota alert: ${operation}`, {
          current,
          limit,
          usagePercent: Math.round(usagePercent),
        });

        // Add to alerts array
        await quotaRef.update({
          alerts: admin.firestore.FieldValue.arrayUnion([alert]),
        });
      }
    } catch (error) {
      logger.debug('Error checking alert threshold', {
        error: error.message,
        operation,
      });
    }
  }

  /**
   * Get current day's quota usage
   */
  async getDayQuotaUsage() {
    try {
      const today = this.getTodayString();
      const quotaRef = this.db
        .collection(this.quotaCollection)
        .doc(`quota_${today}`);
      const doc = await quotaRef.get();

      if (!doc.exists) {
        return {
          reads: 0,
          writes: 0,
          deletes: 0,
          storage: 0,
          alerts: [],
        };
      }

      return doc.data();
    } catch (error) {
      logger.error('Error getting quota usage', error);
      return null;
    }
  }

  /**
   * Get quota usage percentage
   */
  async getQuotaPercentages() {
    try {
      const usage = await this.getDayQuotaUsage();
      if (!usage) return null;

      return {
        reads: {
          used: usage.reads || 0,
          limit: this.alertThresholds.reads,
          percent: Math.round(
            ((usage.reads || 0) / this.alertThresholds.reads) * 100
          ),
        },
        writes: {
          used: usage.writes || 0,
          limit: this.alertThresholds.writes,
          percent: Math.round(
            ((usage.writes || 0) / this.alertThresholds.writes) * 100
          ),
        },
        deletes: {
          used: usage.deletes || 0,
          limit: this.alertThresholds.deletes,
          percent: Math.round(
            ((usage.deletes || 0) / this.alertThresholds.deletes) * 100
          ),
        },
      };
    } catch (error) {
      logger.error('Error calculating percentages', error);
      return null;
    }
  }

  /**
   * Get session statistics
   */
  getSessionStats() {
    return {
      reads: this.sessionCounters.reads,
      writes: this.sessionCounters.writes,
      deletes: this.sessionCounters.deletes,
      total:
        this.sessionCounters.reads +
        this.sessionCounters.writes +
        this.sessionCounters.deletes,
    };
  }

  /**
   * Reset session counters
   */
  resetSessionStats() {
    this.sessionCounters = {
      reads: 0,
      writes: 0,
      deletes: 0,
    };
  }

  /**
   * Get today's date string for quota tracking
   */
  getTodayString() {
    const now = new Date();
    return now.toISOString().split('T')[0]; // YYYY-MM-DD
  }

  /**
   * Export quota report for given date range
   */
  async getQuotaReport(startDate, endDate) {
    try {
      const start = new Date(startDate).toISOString().split('T')[0];
      const end = new Date(endDate).toISOString().split('T')[0];

      const snapshot = await this.db
        .collection(this.quotaCollection)
        .where('date', '>=', start)
        .where('date', '<=', end)
        .orderBy('date')
        .get();

      const report = {
        period: { start, end },
        daily: [],
        totals: { reads: 0, writes: 0, deletes: 0, alerts: 0 },
      };

      snapshot.forEach((doc) => {
        const data = doc.data();
        report.daily.push(data);
        report.totals.reads += data.reads || 0;
        report.totals.writes += data.writes || 0;
        report.totals.deletes += data.deletes || 0;
        report.totals.alerts += (data.alerts || []).length;
      });

      return report;
    } catch (error) {
      logger.error('Error generating quota report', error);
      return null;
    }
  }
}

module.exports = new FirestoreQuotaService();
