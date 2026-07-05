// POST /auth/operational-login endpoint
// Login for operational users (owner, admin, employee, delivery)

const express = require('express');
const router = express.Router();
const OperationalAuthService = require('../services/OperationalAuthService');
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

/**
 * POST /auth/operational-login
 * Login endpoint for operational users
 *
 * Request:
 * {
 *   "login_id": "owner@fufaji.local",
 *   "pin": "1234",
 *   "role": "owner" (optional, derived from login_id if not provided)
 * }
 *
 * Response (200):
 * {
 *   "success": true,
 *   "token": "JWT token",
 *   "refreshToken": "JWT refresh token",
 *   "user": { "id", "name", "phone", "email", "role" },
 *   "permissions": ["view_orders", "manage_staff", ...],
 *   "expiresIn": 3600
 * }
 *
 * Error Responses:
 * 400: Missing login_id or pin
 * 401: Invalid credentials or account locked
 * 429: Rate limited (too many attempts)
 */
router.post('/operational-login', async (req, res) => {
  try {
    const { login_id, pin, role } = req.body;

    // Validation
    if (!login_id || !pin) {
      return res.status(400).json({
        success: false,
        error: 'missing_credentials',
        message: 'login_id and pin are required',
      });
    }

    // Rate limiting: check if IP is rate-limited
    const ip = req.ip || req.connection.remoteAddress;
    const rateLimitKey = `login_attempt:${login_id}`;
    // TODO: Implement Redis rate limiting check here
    // For now, defer to OperationalAuthService which tracks per-user attempts

    // Verify credentials
    const staff = await OperationalAuthService.verifyCredentials(login_id, pin);
    if (!staff) {
      // Log failed attempt
      await logSecurityEvent(login_id, 'login_failure', 'warning', `Failed login attempt`, ip);

      // Don't distinguish between "user not found" vs "wrong PIN" (security)
      return res.status(401).json({
        success: false,
        error: 'invalid_credentials',
        message: 'Login ID or PIN incorrect',
      });
    }

    // Verify role matches if provided
    if (role && staff.role !== role) {
      await logSecurityEvent(login_id, 'login_failure', 'warning', `Role mismatch: ${role} vs ${staff.role}`, ip);
      return res.status(401).json({
        success: false,
        error: 'invalid_credentials',
        message: 'Login ID or PIN incorrect',
      });
    }

    // Generate tokens
    const accessToken = OperationalAuthService.generateAccessToken(staff.id, staff.role);
    const refreshToken = OperationalAuthService.generateRefreshToken(staff.id);

    // Build permissions list based on role
    const permissions = buildPermissions(staff.role);

    // Log successful login
    await logSecurityEvent(login_id, 'login_success', 'info', `Successful login`, ip, staff.id);

    // Return response
    return res.json({
      success: true,
      token: accessToken,
      refreshToken: refreshToken,
      user: {
        id: staff.id,
        name: staff.name,
        phone: staff.phone,
        email: staff.email,
        role: staff.role,
        shop_id: staff.shop_id,
      },
      permissions: permissions,
      expiresIn: 7 * 24 * 60 * 60, // 7 days in seconds
    });
  } catch (error) {
    console.error('[auth/operational-login] Error:', error);
    return res.status(500).json({
      success: false,
      error: 'internal_server_error',
      message: 'Login failed due to server error',
    });
  }
});

/**
 * POST /auth/operational-logout
 * Logout endpoint (revoke token)
 */
router.post('/operational-logout', async (req, res) => {
  try {
    const token = req.headers.authorization?.split('Bearer ')[1];
    const { revokeAll } = req.body;

    if (!token) {
      return res.status(401).json({
        success: false,
        error: 'unauthenticated',
        message: 'Token required',
      });
    }

    // Verify token to get user ID
    const decoded = await OperationalAuthService.verifyToken(token);
    const userId = decoded.sub;

    if (revokeAll) {
      // Revoke all tokens for user
      // TODO: Set user_id-level blacklist in Redis/database
      console.log(`[auth/operational-logout] Revoking all tokens for user ${userId}`);
    } else {
      // Revoke only current token
      await OperationalAuthService.revokeToken(userId, token, 'logout');
    }

    await logSecurityEvent(userId, 'logout', 'info', revokeAll ? 'Logout (all devices)' : 'Logout', req.ip);

    return res.json({
      success: true,
      message: 'Logged out successfully',
    });
  } catch (error) {
    console.error('[auth/operational-logout] Error:', error);
    return res.status(500).json({
      success: false,
      error: 'internal_server_error',
    });
  }
});

/**
 * POST /auth/operational-refresh
 * Refresh access token using refresh token
 */
router.post('/operational-refresh', async (req, res) => {
  try {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      return res.status(400).json({
        success: false,
        error: 'missing_refresh_token',
      });
    }

    // Verify refresh token
    const decoded = await OperationalAuthService.verifyToken(refreshToken);
    if (decoded.type !== 'refresh') {
      return res.status(401).json({
        success: false,
        error: 'invalid_token',
        message: 'Not a refresh token',
      });
    }

    const userId = decoded.sub;

    // Get user to verify still active
    const { data: staff } = await supabase
      .from('staff')
      .select('id, role, is_active')
      .eq('id', userId)
      .single();

    if (!staff || !staff.is_active) {
      return res.status(401).json({
        success: false,
        error: 'user_inactive',
      });
    }

    // Generate new access token
    const newAccessToken = OperationalAuthService.generateAccessToken(userId, staff.role);

    return res.json({
      success: true,
      token: newAccessToken,
      expiresIn: 7 * 24 * 60 * 60,
    });
  } catch (error) {
    console.error('[auth/operational-refresh] Error:', error);
    return res.status(401).json({
      success: false,
      error: 'invalid_token',
    });
  }
});

// ═══════════════════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════

/**
 * Build permission array based on role
 */
function buildPermissions(role) {
  const rolePermissions = {
    owner: [
      'view_all_orders',
      'manage_orders',
      'manage_staff',
      'manage_products',
      'manage_inventory',
      'view_reports',
      'manage_settings',
    ],
    admin: [
      'view_all_orders',
      'manage_orders',
      'manage_staff',
      'manage_products',
      'manage_inventory',
      'view_reports',
    ],
    employee: [
      'view_assigned_orders',
      'manage_orders',
      'manage_inventory',
    ],
    delivery: [
      'view_assigned_deliveries',
      'update_delivery_status',
    ],
  };

  return rolePermissions[role] || [];
}

/**
 * Log security event to security_events table
 */
async function logSecurityEvent(identifier, eventType, severity, description, ip, userId = null) {
  try {
    await supabase
      .from('security_events')
      .insert({
        event_type: eventType,
        user_id: userId,
        severity: severity,
        description: description,
        ip_address: ip,
        user_agent: null, // Could extract from headers
        metadata: { identifier },
      });
  } catch (error) {
    console.error('[auth] Failed to log security event:', error);
    // Don't fail the request if logging fails
  }
}

module.exports = router;
