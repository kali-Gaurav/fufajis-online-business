const functions = require('firebase-functions');
const admin = require('firebase-admin');
const quotaService = require('./FirestoreQuotaService');
const logger = require('./LoggerService');
const { requestLogger } = require('./requestLogger');

/**
 * Health Check Endpoint
 * Returns system status and quota metrics
 */
exports.health = functions.https.onRequest(
  requestLogger(async (req, res) => {
    if (req.method !== 'GET') {
      return res.status(405).json({ error: 'Method Not Allowed' });
    }

    try {
      // Initialize quota service if needed
      await quotaService.initialize();

      // Get quota usage
      const quotaUsage = await quotaService.getDayQuotaUsage();
      const quotaPercentages = await quotaService.getQuotaPercentages();
      const sessionStats = quotaService.getSessionStats();

      // Build health response
      const healthStatus = {
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        environment: process.env.NODE_ENV || 'development',
        firebase: {
          project: admin.app().options.projectId || 'unknown',
        },
        quota: {
          reads: {
            used: quotaPercentages?.reads?.used || 0,
            limit: quotaPercentages?.reads?.limit || 50000,
            usage: quotaPercentages?.reads?.percent || 0,
            status: getQuotaStatus(quotaPercentages?.reads?.percent || 0),
          },
          writes: {
            used: quotaPercentages?.writes?.used || 0,
            limit: quotaPercentages?.writes?.limit || 20000,
            usage: quotaPercentages?.writes?.percent || 0,
            status: getQuotaStatus(quotaPercentages?.writes?.percent || 0),
          },
          deletes: {
            used: quotaPercentages?.deletes?.used || 0,
            limit: quotaPercentages?.deletes?.limit || 20000,
            usage: quotaPercentages?.deletes?.percent || 0,
            status: getQuotaStatus(quotaPercentages?.deletes?.percent || 0),
          },
          alerts: (quotaUsage?.alerts || []).length,
        },
        sessionStats: {
          reads: sessionStats.reads,
          writes: sessionStats.writes,
          deletes: sessionStats.deletes,
          total: sessionStats.total,
        },
        checks: {
          firestore: 'ok',
          timestamp: 'ok',
        },
      };

      // Log health check
      logger.info('Health check', {
        status: healthStatus.status,
        quotaUsageReads: quotaPercentages?.reads?.percent || 0,
        quotaUsageWrites: quotaPercentages?.writes?.percent || 0,
      });

      return res.status(200).json(healthStatus);
    } catch (error) {
      logger.error('Health check failed', error);

      return res.status(503).json({
        status: 'unhealthy',
        timestamp: new Date().toISOString(),
        error: error.message,
      });
    }
  })
);

/**
 * Detailed Quota Report Endpoint
 * GET /quota-report?days=7
 */
exports.quotaReport = functions.https.onRequest(
  requestLogger(async (req, res) => {
    if (req.method !== 'GET') {
      return res.status(405).json({ error: 'Method Not Allowed' });
    }

    try {
      // Get days parameter from query (default 7)
      const days = parseInt(req.query.days) || 7;

      // Calculate date range
      const endDate = new Date();
      const startDate = new Date(endDate);
      startDate.setDate(startDate.getDate() - days);

      // Get quota report
      const report = await quotaService.getQuotaReport(
        startDate,
        endDate
      );

      if (!report) {
        return res.status(500).json({
          error: 'Failed to generate report',
        });
      }

      // Add summary
      const summary = {
        period: report.period,
        days,
        totals: report.totals,
        dailyAverage: {
          reads: Math.round(report.totals.reads / days),
          writes: Math.round(report.totals.writes / days),
          deletes: Math.round(report.totals.deletes / days),
        },
        projectedDaily: {
          reads: (report.totals.reads / days) * 50000,
          writes: (report.totals.writes / days) * 20000,
          deletes: (report.totals.deletes / days) * 20000,
        },
        alertCount: report.totals.alerts,
      };

      logger.info('Quota report generated', {
        days,
        totalReads: report.totals.reads,
        totalWrites: report.totals.writes,
        alerts: report.totals.alerts,
      });

      return res.status(200).json({
        summary,
        daily: report.daily,
      });
    } catch (error) {
      logger.error('Quota report failed', error);

      return res.status(500).json({
        error: 'Failed to generate quota report',
        message: error.message,
      });
    }
  })
);

/**
 * Helper function to determine quota status
 */
function getQuotaStatus(percent) {
  if (percent < 50) return 'ok';
  if (percent < 80) return 'warning';
  if (percent < 95) return 'critical';
  return 'exceeded';
}

module.exports = { health: exports.health, quotaReport: exports.quotaReport };
