// Operational User Authentication Service
// Handles: owner, admin, employee, delivery agent login + token management

const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { db } = require('./firebaseAdmin');
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

class OperationalAuthService {
  /**
   * Verify staff credentials (login_id + PIN)
   * @param {string} loginId - Email, phone, or custom ID
   * @param {string} pin - PIN (will be bcrypt-compared)
   * @returns {Promise<Object>} Staff record if valid, null if invalid
   */
  async verifyCredentials(loginId, pin) {
    try {
      // Query staff table (parameterized to prevent SQL injection)
      const { data, error } = await supabase
        .from('staff')
        .select('id, shop_id, login_id, pin_hash, role, phone, email, name, is_active, locked_until')
        .eq('login_id', loginId)
        .eq('is_active', true)
        .single();

      if (error || !data) {
        console.warn(`[OperationalAuth] Staff not found: ${loginId}`);
        return null;
      }

      // Check if account is locked
      if (data.locked_until && new Date(data.locked_until) > new Date()) {
        console.warn(`[OperationalAuth] Account locked: ${loginId}`);
        return null; // Return null (don't distinguish "locked" vs "invalid")
      }

      // Constant-time PIN comparison (prevent timing attacks)
      const pinValid = await bcrypt.compare(pin, data.pin_hash);
      if (!pinValid) {
        // Increment failed login count
        await this._incrementFailedLogins(data.id, loginId);
        return null;
      }

      // Clear failed login count on success
      await this._clearFailedLogins(data.id);

      // Update last_login timestamp
      await supabase
        .from('staff')
        .update({ last_login: new Date().toISOString() })
        .eq('id', data.id);

      return data;
    } catch (error) {
      console.error(`[OperationalAuth] verifyCredentials error:`, error);
      throw error;
    }
  }

  /**
   * Generate JWT token for operational user
   * @param {string} userId - Staff ID
   * @param {string} role - owner|admin|employee|delivery
   * @returns {string} JWT token
   */
  generateAccessToken(userId, role) {
    const secret = process.env.OPERATIONAL_JWT_SECRET;
    if (!secret) {
      throw new Error('OPERATIONAL_JWT_SECRET not configured');
    }

    const payload = {
      sub: userId,
      role: role,
      type: 'access',
      iat: Math.floor(Date.now() / 1000),
    };

    return jwt.sign(payload, secret, {
      expiresIn: '7d',
      algorithm: 'HS256',
      header: { kid: 'v1' }, // Key version for rotation
    });
  }

  /**
   * Generate refresh token for operational user
   * @param {string} userId - Staff ID
   * @returns {string} Refresh JWT token
   */
  generateRefreshToken(userId) {
    const secret = process.env.OPERATIONAL_JWT_SECRET;
    if (!secret) {
      throw new Error('OPERATIONAL_JWT_SECRET not configured');
    }

    const payload = {
      sub: userId,
      type: 'refresh',
      iat: Math.floor(Date.now() / 1000),
    };

    return jwt.sign(payload, secret, {
      expiresIn: '30d',
      algorithm: 'HS256',
    });
  }

  /**
   * Verify JWT token (access or refresh)
   * @param {string} token - JWT token
   * @returns {Promise<Object>} Decoded token payload
   */
  async verifyToken(token) {
    try {
      const secret = process.env.OPERATIONAL_JWT_SECRET;
      if (!secret) {
        throw new Error('OPERATIONAL_JWT_SECRET not configured');
      }

      let decoded;
      // Try current secret first
      try {
        decoded = jwt.verify(token, secret, { algorithms: ['HS256'] });
      } catch (err) {
        // Try old secret (during rotation grace period)
        const oldSecret = process.env.OPERATIONAL_JWT_SECRET_OLD;
        if (oldSecret) {
          decoded = jwt.verify(token, oldSecret, { algorithms: ['HS256'] });
        } else {
          throw err;
        }
      }

      // Check blacklist
      const isBlacklisted = await this.isTokenBlacklisted(token);
      if (isBlacklisted) {
        throw new Error('Token has been revoked');
      }

      return decoded;
    } catch (error) {
      console.error(`[OperationalAuth] Token verification failed:`, error.message);
      throw new Error('Invalid or expired token');
    }
  }

  /**
   * Revoke token by adding to blacklist
   * @param {string} userId - Staff ID
   * @param {string} token - JWT token to revoke
   * @param {string} reason - Reason for revocation (logout|password_change|security_event|admin_revoke)
   */
  async revokeToken(userId, token, reason = 'logout') {
    try {
      const decoded = await this.verifyToken(token);
      const tokenHash = require('crypto')
        .createHash('sha256')
        .update(token)
        .digest('hex');

      const expiresAt = new Date(decoded.exp * 1000);

      const { error } = await supabase
        .from('token_blacklist')
        .insert({
          user_id: userId,
          token_hash: tokenHash,
          reason: reason,
          expires_at: expiresAt.toISOString(),
        });

      if (error) {
        console.error(`[OperationalAuth] Failed to revoke token:`, error);
        throw error;
      }

      console.log(`[OperationalAuth] Token revoked for user ${userId}`);
    } catch (error) {
      console.error(`[OperationalAuth] revokeToken error:`, error);
      throw error;
    }
  }

  /**
   * Check if token is blacklisted
   * @param {string} token - JWT token
   * @returns {Promise<boolean>} True if blacklisted
   */
  async isTokenBlacklisted(token) {
    try {
      const tokenHash = require('crypto')
        .createHash('sha256')
        .update(token)
        .digest('hex');

      const { data } = await supabase
        .from('token_blacklist')
        .select('id')
        .eq('token_hash', tokenHash)
        .single();

      return !!data;
    } catch (error) {
      // Assume not blacklisted if lookup fails (prefer availability)
      console.warn(`[OperationalAuth] Blacklist lookup failed:`, error);
      return false;
    }
  }

  /**
   * Internal: Increment failed login count and lock if needed
   */
  async _incrementFailedLogins(staffId, loginId) {
    try {
      const { data } = await supabase
        .from('staff')
        .select('failed_login_count')
        .eq('id', staffId)
        .single();

      const newCount = (data?.failed_login_count || 0) + 1;
      const lockedUntil = newCount >= 5 ? new Date(Date.now() + 15 * 60 * 1000) : null;

      await supabase
        .from('staff')
        .update({
          failed_login_count: newCount,
          locked_until: lockedUntil?.toISOString(),
        })
        .eq('id', staffId);

      if (lockedUntil) {
        console.warn(`[OperationalAuth] Account locked after 5 failures: ${loginId}`);
      }
    } catch (error) {
      console.error(`[OperationalAuth] Failed to increment failed logins:`, error);
    }
  }

  /**
   * Internal: Clear failed login count on successful login
   */
  async _clearFailedLogins(staffId) {
    try {
      await supabase
        .from('staff')
        .update({
          failed_login_count: 0,
          locked_until: null,
        })
        .eq('id', staffId);
    } catch (error) {
      console.error(`[OperationalAuth] Failed to clear failed logins:`, error);
    }
  }
}

module.exports = new OperationalAuthService();
