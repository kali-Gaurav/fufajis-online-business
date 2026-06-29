// production-ready Auth Middleware for Fufaji Store.
// Verifies Firebase ID tokens and enforces role-based access control.

const { auth, db } = require('./services/firebaseAdmin');

/**
 * Middleware: Verify Firebase ID Token.
 * Extracted from Authorization: Bearer <token>
 */
async function verifyToken(req, res, next) {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        error: 'unauthenticated',
        message: 'No authorization token provided'
      });
    }

    const idToken = authHeader.split('Bearer ')[1];
    const decodedToken = await auth().verifyIdToken(idToken);

    // Attach user context to request
    req.user = decodedToken;
    next();
  } catch (error) {
    console.error('[auth] token verification failed:', error.message);
    return res.status(401).json({
      success: false,
      error: 'invalid-token',
      message: 'Failed to verify authentication token'
    });
  }
}

/**
 * Middleware: Require specific User Roles.
 * Usage: requireRole('UserRole.admin', 'UserRole.owner')
 */
function requireRole(...allowedRoles) {
  return async (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ success: false, error: 'unauthenticated' });
    }

    try {
      // 1. Check custom claims first (performance optimization)
      const userRole = req.user.role;
      if (userRole && allowedRoles.includes(userRole)) {
        req.currentRole = userRole;
        return next();
      }

      // 2. Fallback to Firestore check (source of truth)
      const userDoc = await db().collection('users').doc(req.user.uid).get();
      const role = userDoc.exists ? userDoc.data().role : null;

      if (!role || !allowedRoles.includes(role)) {
        return res.status(403).json({
          success: false,
          error: 'permission-denied',
          message: `Required role missing. Allowed: ${allowedRoles.join(', ')}`
        });
      }

      req.currentRole = role;
      next();
    } catch (error) {
      console.error('[auth] role verification failed:', error.message);
      return res.status(500).json({ success: false, error: 'internal-server-error' });
    }
  };
}

module.exports = {
  verifyToken,
  requireRole
};
