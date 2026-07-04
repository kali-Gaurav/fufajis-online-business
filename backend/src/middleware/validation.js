/**
 * Validation & Authentication Middleware
 * ✅ CRITICAL FIX: Implemented proper auth instead of hardcoded dummy user
 */
const admin = require('firebase-admin');

/**
 * Validate HTTP request structure
 */
const validateRequest = (schema) => {
  return (req, res, next) => {
    // Basic request validation
    if (!req.body || typeof req.body !== 'object') {
      return res.status(400).json({
        success: false,
        error: 'INVALID_REQUEST',
        message: 'Request body must be valid JSON',
      });
    }

    // If schema provided, validate against it
    if (schema) {
      const errors = [];
      for (const field of schema.required || []) {
        if (!(field in req.body)) {
          errors.push(`Missing required field: ${field}`);
        }
      }

      if (errors.length > 0) {
        return res.status(400).json({
          success: false,
          error: 'VALIDATION_ERROR',
          message: errors[0],
          details: errors,
        });
      }
    }

    next();
  };
};

/**
 * Authentication Middleware
 * ✅ FIX: Verify Firebase ID token instead of using dummy user
 * Extracts user ID from token and attaches to req.user
 */
const authMiddleware = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      console.warn('[Auth] Missing or invalid Authorization header');
      return res.status(401).json({
        success: false,
        error: 'UNAUTHORIZED',
        message: 'Authorization header required (Bearer token)',
      });
    }

    const token = authHeader.substring('Bearer '.length);

    if (!token) {
      return res.status(401).json({
        success: false,
        error: 'UNAUTHORIZED',
        message: 'Invalid token format',
      });
    }

    // ✅ FIX: Verify Firebase token
    try {
      const decodedToken = await admin.auth().verifyIdToken(token);
      req.user = {
        id: decodedToken.uid,
        email: decodedToken.email || '',
        iat: decodedToken.iat,
      };

      console.log(`[Auth] ✅ User authenticated: ${req.user.id}`);
      next();
    } catch (err) {
      console.error('[Auth] ❌ Token verification failed:', err.message);

      if (err.code === 'auth/id-token-expired') {
        return res.status(401).json({
          success: false,
          error: 'TOKEN_EXPIRED',
          message: 'Authentication token has expired',
        });
      }

      return res.status(401).json({
        success: false,
        error: 'UNAUTHORIZED',
        message: 'Invalid or tampered token',
      });
    }
  } catch (err) {
    console.error('[Auth] ❌ Authentication middleware error:', err.message);
    return res.status(500).json({
      success: false,
      error: 'AUTH_ERROR',
      message: 'Authentication check failed',
    });
  }
};

/**
 * Optional Auth - attach user if token provided, but don't require it
 */
const optionalAuthMiddleware = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.substring('Bearer '.length);

      try {
        const decodedToken = await admin.auth().verifyIdToken(token);
        req.user = {
          id: decodedToken.uid,
          email: decodedToken.email || '',
          iat: decodedToken.iat,
        };
        console.log(`[Auth] ✅ User authenticated: ${req.user.id}`);
      } catch (err) {
        console.warn('[Auth] Token verification failed (optional), proceeding unauthenticated');
        req.user = null;
      }
    } else {
      req.user = null;
    }

    next();
  } catch (err) {
    console.error('[Auth] Optional auth middleware error:', err.message);
    req.user = null;
    next();
  }
};

module.exports = {
  validateRequest,
  authMiddleware,
  optionalAuthMiddleware,
};
