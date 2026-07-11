/**
 * OPERATIONAL USERS AUTHENTICATION
 * Handles: Owner, Employee, Rider, Supplier login
 * NOT using Firebase Auth - credentials stored in Supabase operational_users table
 *
 * Created: 2026-07-11
 */

const express = require('express');
const router = express.Router();
const supabase = require('../db/supabase');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');
const rateLimit = require('express-rate-limit');

// ============================================================================
// RATE LIMITERS
// ============================================================================

const loginLimiter = rateLimit({
  windowMs: 5 * 60 * 1000, // 5 minutes
  max: 10, // max 10 attempts
  message: 'Too many login attempts, please try again later',
  skip: (req) => {
    // Don't rate limit successful logins
    return req.body.success === true;
  }
});

const passwordResetLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 3, // max 3 reset requests
  message: 'Too many password reset requests, please try again in 1 hour'
});

// ============================================================================
// HELPERS
// ============================================================================

/**
 * Generate JWT token for operational user
 */
const generateOperationalToken = (user) => {
  const token = jwt.sign(
    {
      sub: user.id,
      email: user.email,
      user_type: user.user_type,
      owner_id: user.owner_id,
      role: user.user_type, // Map to standard 'role' claim
      iat: Math.floor(Date.now() / 1000)
    },
    process.env.JWT_SECRET,
    { expiresIn: '8h' } // 8 hour expiry for operational users (vs 24h for customers)
  );
  return token;
};

/**
 * Hash password using bcrypt
 */
const hashPassword = async (password) => {
  return await bcrypt.hash(password, 12); // 12 salt rounds
};

/**
 * Compare password with hash
 */
const comparePassword = async (password, hash) => {
  return await bcrypt.compare(password, hash);
};

/**
 * Check if account is locked
 */
const checkAccountLocked = (user) => {
  if (!user.locked_until) return false;

  const lockedUntil = new Date(user.locked_until);
  const now = new Date();

  return lockedUntil > now;
};

/**
 * Log login attempt to audit table
 */
const logLoginAttempt = async (email, status, userType, ipAddress) => {
  try {
    await supabase
      .from('login_audit_log')
      .insert({
        user_email: email,
        login_status: status,
        user_type: userType,
        ip_address: ipAddress,
        user_agent: null
      });
  } catch (err) {
    console.error('Failed to log login attempt:', err);
  }
};

/**
 * Increment failed login attempts and lock if needed
 */
const incrementLoginAttempts = async (userId, userType) => {
  const table = userType === 'admin' ? 'admin_accounts' : 'operational_users';

  const { data: user } = await supabase
    .from(table)
    .select('login_attempts')
    .eq('id', userId)
    .single();

  const newAttempts = (user?.login_attempts || 0) + 1;
  const lockoutTime = newAttempts >= 5
    ? new Date(Date.now() + 15 * 60 * 1000) // 15 minutes
    : null;

  await supabase
    .from(table)
    .update({
      login_attempts: newAttempts,
      locked_until: lockoutTime
    })
    .eq('id', userId);
};

/**
 * Reset login attempts after successful login
 */
const resetLoginAttempts = async (userId, userType) => {
  const table = userType === 'admin' ? 'admin_accounts' : 'operational_users';

  await supabase
    .from(table)
    .update({
      login_attempts: 0,
      locked_until: null,
      last_login_at: new Date()
    })
    .eq('id', userId);
};

// ============================================================================
// ENDPOINTS
// ============================================================================

/**
 * POST /api/auth/operational/login
 * Login for Owner, Employee, Rider, Supplier
 *
 * Request:
 * {
 *   "email": "owner@shop.com",
 *   "password": "SecurePassword123!"
 * }
 */
router.post('/operational/login', loginLimiter, async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        error: 'Email and password are required'
      });
    }

    // Query operational_users table
    const { data: user, error } = await supabase
      .from('operational_users')
      .select('*')
      .eq('email', email)
      .single();

    // User not found
    if (error || !user) {
      await logLoginAttempt(email, 'failed_not_found', 'operational', req.ip);
      return res.status(401).json({
        success: false,
        error: 'Invalid email or password'
      });
    }

    // Check if account is active
    if (!user.is_active) {
      await logLoginAttempt(email, 'failed_not_found', 'operational', req.ip);
      return res.status(401).json({
        success: false,
        error: 'Account is disabled'
      });
    }

    // Check if account is locked
    if (checkAccountLocked(user)) {
      await logLoginAttempt(email, 'account_locked', 'operational', req.ip);
      return res.status(429).json({
        success: false,
        error: 'Account locked due to too many failed attempts. Try again later.'
      });
    }

    // Verify password
    const passwordMatch = await comparePassword(password, user.password_hash);

    if (!passwordMatch) {
      // Increment failed attempts
      await incrementLoginAttempts(user.id, 'operational');
      await logLoginAttempt(email, 'failed_password', 'operational', req.ip);

      return res.status(401).json({
        success: false,
        error: 'Invalid email or password'
      });
    }

    // Check if email is verified (optional, can be enforced)
    if (!user.is_verified) {
      console.log(`Note: User ${email} logged in without email verification`);
    }

    // Success: Reset attempts and generate token
    await resetLoginAttempts(user.id, 'operational');
    await logLoginAttempt(email, 'success', 'operational', req.ip);

    const token = generateOperationalToken(user);

    return res.json({
      success: true,
      token,
      user: {
        id: user.id,
        email: user.email,
        full_name: user.full_name,
        user_type: user.user_type,
        owner_id: user.owner_id
      }
    });

  } catch (err) {
    console.error('Operational login error:', err);
    return res.status(500).json({
      success: false,
      error: 'Authentication failed'
    });
  }
});

/**
 * POST /api/auth/operational/request-password-reset
 * Request password reset link via email
 */
router.post('/operational/request-password-reset', passwordResetLimiter, async (req, res) => {
  try {
    const { email } = req.body;

    if (!email) {
      return res.status(400).json({
        success: false,
        error: 'Email is required'
      });
    }

    // Find user
    const { data: user } = await supabase
      .from('operational_users')
      .select('*')
      .eq('email', email)
      .single();

    // For security, always return success even if user not found
    // (prevents email enumeration attacks)
    if (!user) {
      return res.json({
        success: true,
        message: 'If account exists, password reset link will be sent to email'
      });
    }

    // Generate reset token
    const resetToken = require('crypto').randomBytes(32).toString('hex');
    const tokenHash = await hashPassword(resetToken);

    // Store token (expires in 1 hour)
    await supabase
      .from('password_reset_tokens')
      .insert({
        token_hash: tokenHash,
        user_id: user.id,
        user_type: 'operational',
        expires_at: new Date(Date.now() + 60 * 60 * 1000)
      });

    // TODO: Send email with reset link
    // const resetLink = `${process.env.APP_BASE_URL}/auth/reset-password?token=${resetToken}`;
    // await sendEmail(email, 'Password Reset', `Click here to reset: ${resetLink}`);

    return res.json({
      success: true,
      message: 'Password reset link sent to email (check spam folder)',
      // TODO: Remove in production - for testing only
      _test_token: resetToken
    });

  } catch (err) {
    console.error('Password reset request error:', err);
    return res.status(500).json({
      success: false,
      error: 'Password reset request failed'
    });
  }
});

/**
 * POST /api/auth/operational/reset-password
 * Reset password using reset token
 */
router.post('/operational/reset-password', async (req, res) => {
  try {
    const { reset_token, new_password } = req.body;

    if (!reset_token || !new_password) {
      return res.status(400).json({
        success: false,
        error: 'Reset token and new password are required'
      });
    }

    // Validate password strength
    if (new_password.length < 8) {
      return res.status(400).json({
        success: false,
        error: 'Password must be at least 8 characters'
      });
    }

    // Find valid reset token
    const { data: tokenRecord } = await supabase
      .from('password_reset_tokens')
      .select('*')
      .eq('token_hash', reset_token)
      .single();

    if (!tokenRecord || tokenRecord.used_at) {
      return res.status(401).json({
        success: false,
        error: 'Invalid or expired reset token'
      });
    }

    // Check expiry
    if (new Date(tokenRecord.expires_at) < new Date()) {
      return res.status(401).json({
        success: false,
        error: 'Reset token has expired'
      });
    }

    // Hash new password
    const newPasswordHash = await hashPassword(new_password);

    // Update password
    await supabase
      .from('operational_users')
      .update({
        password_hash: newPasswordHash,
        password_changed_at: new Date(),
        login_attempts: 0,
        locked_until: null
      })
      .eq('id', tokenRecord.user_id);

    // Mark token as used
    await supabase
      .from('password_reset_tokens')
      .update({ used_at: new Date() })
      .eq('id', tokenRecord.id);

    return res.json({
      success: true,
      message: 'Password reset successfully. You can now login with your new password.'
    });

  } catch (err) {
    console.error('Password reset error:', err);
    return res.status(500).json({
      success: false,
      error: 'Password reset failed'
    });
  }
});

/**
 * POST /api/auth/operational/change-password
 * Change password for authenticated operational user
 */
router.post('/operational/change-password', async (req, res) => {
  try {
    const { current_password, new_password } = req.body;
    const userId = req.user?.id; // From middleware

    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
    }

    if (!current_password || !new_password) {
      return res.status(400).json({
        success: false,
        error: 'Current and new passwords are required'
      });
    }

    // Get current user
    const { data: user } = await supabase
      .from('operational_users')
      .select('*')
      .eq('id', userId)
      .single();

    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'User not found'
      });
    }

    // Verify current password
    const currentPasswordMatch = await comparePassword(current_password, user.password_hash);

    if (!currentPasswordMatch) {
      return res.status(401).json({
        success: false,
        error: 'Current password is incorrect'
      });
    }

    // Hash new password
    const newPasswordHash = await hashPassword(new_password);

    // Update password
    await supabase
      .from('operational_users')
      .update({
        password_hash: newPasswordHash,
        password_changed_at: new Date()
      })
      .eq('id', userId);

    return res.json({
      success: true,
      message: 'Password changed successfully'
    });

  } catch (err) {
    console.error('Password change error:', err);
    return res.status(500).json({
      success: false,
      error: 'Password change failed'
    });
  }
});

/**
 * GET /api/auth/operational/me
 * Get current authenticated user info
 */
router.get('/operational/me', async (req, res) => {
  try {
    const userId = req.user?.id;

    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
    }

    const { data: user } = await supabase
      .from('operational_users')
      .select('id, email, full_name, user_type, owner_id, is_active, is_verified, last_login_at')
      .eq('id', userId)
      .single();

    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'User not found'
      });
    }

    return res.json({
      success: true,
      user
    });

  } catch (err) {
    console.error('Get user error:', err);
    return res.status(500).json({
      success: false,
      error: 'Failed to get user info'
    });
  }
});

module.exports = router;
