/**
 * SYSTEM FLAGS ROUTES — Operational Kill Switches
 *
 * Allows instant disable/enable of workers without redeployment
 * Example: If a worker is broken, disable it in <1s instead of waiting 5-10 min for redeploy
 *
 * File: /backend/src/routes/system-flags.js
 */

const express = require('express');
const router = express.Router();
const supabaseService = require('../config/supabase');
const Sentry = require('@sentry/node');

// Middleware: Check admin role
const requireAdmin = (req, res, next) => {
  if (req.user?.role !== 'admin') {
    return res.status(403).json({ error: 'Admin access required' });
  }
  next();
};

// Valid flag names
const VALID_FLAGS = [
  'inventory_sync_enabled',
  'product_sync_enabled',
  'order_replication_enabled',
  'search_cache_refresh_enabled',
  'drift_detection_enabled',
  'retry_jobs_enabled',
  'dlq_processing_enabled',
];

// =====================================================
// GET /system-flags — List all flags
// =====================================================
/**
 * Get current state of all system flags
 * Admin only
 */
router.get('/', requireAdmin, async (req, res) => {
  try {
    const { data: flags, error } = await supabaseService.query(
      'system_flags',
      'select'
    );

    if (error) {
      return res.status(500).json({ error: error.message });
    }

    res.status(200).json({
      success: true,
      flags: flags || [],
      count: flags?.length || 0,
    });
  } catch (error) {
    console.error('[GET /system-flags] Error:', error.message);
    Sentry.captureException(error);
    res.status(500).json({ error: error.message });
  }
});

// =====================================================
// GET /system-flags/:flag_name — Get single flag
// =====================================================
/**
 * Get state of a specific flag
 * Admin only
 */
router.get('/:flag_name', requireAdmin, async (req, res) => {
  try {
    const { flag_name } = req.params;

    if (!VALID_FLAGS.includes(flag_name)) {
      return res.status(400).json({
        error: `Invalid flag: ${flag_name}`,
        valid_flags: VALID_FLAGS,
      });
    }

    const { data: flags, error } = await supabaseService.query(
      'system_flags',
      'select',
      { filters: { flag_name } }
    );

    if (error) {
      return res.status(500).json({ error: error.message });
    }

    if (!flags || flags.length === 0) {
      return res.status(404).json({ error: 'Flag not found' });
    }

    res.status(200).json({
      success: true,
      flag: flags[0],
    });
  } catch (error) {
    console.error('[GET /system-flags/:flag_name] Error:', error.message);
    Sentry.captureException(error);
    res.status(500).json({ error: error.message });
  }
});

// =====================================================
// POST /system-flags/:flag_name/disable — Disable flag
// =====================================================
/**
 * Disable a flag (worker will check and exit gracefully)
 * Admin only
 */
router.post('/:flag_name/disable', requireAdmin, async (req, res) => {
  try {
    const { flag_name } = req.params;
    const { reason, re_enable_at } = req.body;
    const userEmail = req.user?.email || 'unknown';

    if (!VALID_FLAGS.includes(flag_name)) {
      return res.status(400).json({
        error: `Invalid flag: ${flag_name}`,
        valid_flags: VALID_FLAGS,
      });
    }

    // Log the change to audit trail
    console.log(`[SYSTEM FLAG] Disabling ${flag_name}. Reason: ${reason || 'not specified'}. By: ${userEmail}`);

    // Update flag
    const { data, error } = await supabaseService.query(
      'system_flags',
      'update',
      {
        filters: { flag_name },
        payload: {
          enabled: false,
          reason: reason || 'Disabled by admin',
          disabled_by: userEmail,
          disabled_at: new Date().toISOString(),
          re_enable_at: re_enable_at ? new Date(re_enable_at).toISOString() : null,
          updated_at: new Date().toISOString(),
        },
      }
    );

    if (error) {
      return res.status(500).json({ error: error.message });
    }

    // Alert ops team
    console.warn(`⚠️  ALERT: System flag disabled: ${flag_name}. Workers will exit gracefully.`);
    // TODO: Send to PagerDuty / Slack

    res.status(200).json({
      success: true,
      flag_name,
      enabled: false,
      disabled_by: userEmail,
      disabled_at: new Date().toISOString(),
      reason: reason || 'Disabled by admin',
      message: `${flag_name} disabled. Workers will check this flag and exit gracefully.`,
    });
  } catch (error) {
    console.error('[POST /system-flags/:flag_name/disable] Error:', error.message);
    Sentry.captureException(error, { tags: { operation: 'disable_flag' } });
    res.status(500).json({ error: error.message });
  }
});

// =====================================================
// POST /system-flags/:flag_name/enable — Enable flag
// =====================================================
/**
 * Enable a flag (resume processing)
 * Admin only
 */
router.post('/:flag_name/enable', requireAdmin, async (req, res) => {
  try {
    const { flag_name } = req.params;
    const userEmail = req.user?.email || 'unknown';

    if (!VALID_FLAGS.includes(flag_name)) {
      return res.status(400).json({
        error: `Invalid flag: ${flag_name}`,
        valid_flags: VALID_FLAGS,
      });
    }

    console.log(`[SYSTEM FLAG] Enabling ${flag_name}. By: ${userEmail}`);

    // Update flag
    const { data, error } = await supabaseService.query(
      'system_flags',
      'update',
      {
        filters: { flag_name },
        payload: {
          enabled: true,
          reason: null,
          disabled_by: null,
          disabled_at: null,
          re_enable_at: null,
          updated_at: new Date().toISOString(),
        },
      }
    );

    if (error) {
      return res.status(500).json({ error: error.message });
    }

    // Alert ops team
    console.info(`✅ System flag enabled: ${flag_name}. Workers will resume.`);
    // TODO: Send to PagerDuty / Slack

    res.status(200).json({
      success: true,
      flag_name,
      enabled: true,
      enabled_by: userEmail,
      enabled_at: new Date().toISOString(),
      message: `${flag_name} enabled. Workers will resume processing.`,
    });
  } catch (error) {
    console.error('[POST /system-flags/:flag_name/enable] Error:', error.message);
    Sentry.captureException(error, { tags: { operation: 'enable_flag' } });
    res.status(500).json({ error: error.message });
  }
});

// =====================================================
// GET /system-flags/audit/log — Audit log
// =====================================================
/**
 * Get audit trail of flag changes
 * Admin only
 */
router.get('/audit/log', requireAdmin, async (req, res) => {
  try {
    // Query flag changes from system_flags table
    const { data: flags, error } = await supabaseService.query(
      'system_flags',
      'select',
      { order: 'updated_at:desc', limit: 100 }
    );

    if (error) {
      return res.status(500).json({ error: error.message });
    }

    // Format as audit log
    const auditLog = (flags || []).map(flag => ({
      flag_name: flag.flag_name,
      enabled: flag.enabled,
      reason: flag.reason,
      disabled_by: flag.disabled_by,
      disabled_at: flag.disabled_at,
      re_enable_at: flag.re_enable_at,
      updated_at: flag.updated_at,
    }));

    res.status(200).json({
      success: true,
      audit_log: auditLog,
      count: auditLog.length,
    });
  } catch (error) {
    console.error('[GET /system-flags/audit/log] Error:', error.message);
    Sentry.captureException(error);
    res.status(500).json({ error: error.message });
  }
});

// =====================================================
// ERROR HANDLER
// =====================================================

router.use((error, req, res, next) => {
  console.error('[/system-flags/*] Unhandled error:', error);
  Sentry.captureException(error);
  res.status(500).json({
    error: 'Internal server error',
    message: process.env.NODE_ENV === 'development' ? error.message : undefined,
  });
});

module.exports = router;
