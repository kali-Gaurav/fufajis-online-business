/**
 * ADMIN USER MANAGEMENT
 * Admin-only endpoints for:
 * - Creating Owner accounts
 * - Creating Employee/Rider/Supplier accounts
 * - Managing user status & permissions
 * - Audit logging of user changes
 *
 * Created: 2026-07-11
 */

const express = require('express');
const router = express.Router();
const supabase = require('../db/supabase');
const jwt = require('jsonwebtoken');
const { auth, db } = require('../services/firebaseAdmin');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');

// ============================================================================
// MIDDLEWARE
// ============================================================================

/**
 * Verify admin privileges (supports both Firebase and Supabase auth)
 */
const requireAdmin = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
    }

    const token = authHeader.split('Bearer ')[1];
    let userId = null;

    // Try Firebase token first
    try {
      const decodedToken = await auth().verifyIdToken(token);
      userId = decodedToken.uid;
      req.user = decodedToken;
    } catch (firebaseErr) {
      // Firebase verification failed - try Supabase JWT
      try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        userId = decoded.sub || decoded.id;
        req.user = decoded;
      } catch (jwtErr) {
        return res.status(401).json({
          success: false,
          error: 'Invalid token'
        });
      }
    }

    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
    }

    // Check if user is admin
    const { data: adminUser } = await supabase
      .from('admin_accounts')
      .select('admin_level, is_active')
      .eq('id', userId)
      .single();

    if (!adminUser || !adminUser.is_active) {
      return res.status(403).json({
        success: false,
        error: 'Admin privileges required'
      });
    }

    req.adminLevel = adminUser.admin_level;
    next();
  } catch (err) {
    console.error('Admin verification error:', err);
    return res.status(500).json({
      success: false,
      error: 'Authorization check failed'
    });
  }
};

// Apply admin check to all routes
router.use(requireAdmin);

// ============================================================================
// HELPERS
// ============================================================================

/**
 * Hash password using bcrypt
 */
const hashPassword = async (password) => {
  return await bcrypt.hash(password, 12);
};

/**
 * Generate temporary password (for new accounts)
 */
const generateTemporaryPassword = () => {
  return crypto.randomBytes(6).toString('hex').toUpperCase();
};

/**
 * Log admin action
 */
const logAdminAction = async (adminId, action, targetUserId, details) => {
  try {
    await supabase
      .from('admin_audit_log')
      .insert({
        admin_id: adminId,
        action,
        target_user_id: targetUserId,
        details,
        created_at: new Date()
      })
      .catch(err => {
        // Table might not exist yet - that's okay, just log to console
        console.log('Admin action:', action, targetUserId, details);
      });
  } catch (err) {
    console.error('Failed to log admin action:', err);
  }
};

/**
 * Sync operational user to Firestore (for real-time UI consistency)
 */
const syncUserToFirestore = async (user, collection = 'employees') => {
  try {
    const firestore = db();

    // Map user_type to Firestore collection
    let firestoreCollection = 'employees';
    if (user.user_type === 'owner') {
      firestoreCollection = 'owners';
    } else if (user.user_type === 'supplier') {
      firestoreCollection = 'suppliers';
    } else if (user.user_type === 'rider') {
      firestoreCollection = 'riders';
    }

    // Prepare data for Firestore (exclude password hash)
    const firestoreData = {
      id: user.id,
      email: user.email,
      full_name: user.full_name,
      phone: user.phone,
      user_type: user.user_type,
      owner_id: user.owner_id,
      is_active: user.is_active,
      is_verified: user.is_verified,
      created_at: new Date(user.created_at),
      last_login_at: user.last_login_at ? new Date(user.last_login_at) : null,
      synced_at: new Date()
    };

    // Write to Firestore
    await firestore.collection(firestoreCollection).doc(user.id).set(firestoreData, { merge: true });

    return { success: true };
  } catch (err) {
    console.error('Firestore sync error:', err);
    // Don't fail the request if Firestore sync fails (eventual consistency)
    return { success: false, error: err.message };
  }
};

/**
 * Send email via Supabase Edge Function
 */
const sendEmail = async (to, templateId, dynamicTemplateData) => {
  try {
    const supabaseUrl = process.env.SUPABASE_URL;
    const supabaseAnonKey = process.env.SUPABASE_ANON_KEY;

    if (!supabaseUrl) {
      console.error('SUPABASE_URL not configured');
      return { success: false, error: 'Email service not configured' };
    }

    const response = await fetch(`${supabaseUrl}/functions/v1/send-email`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${supabaseAnonKey}`
      },
      body: JSON.stringify({
        to,
        templateId,
        dynamicTemplateData
      })
    });

    if (!response.ok) {
      const errorData = await response.json();
      console.error('Email send failed:', errorData);
      return { success: false, error: errorData.error || 'Failed to send email' };
    }

    const result = await response.json();
    return { success: true, messageId: result.messageId };
  } catch (err) {
    console.error('Email service error:', err);
    return { success: false, error: err.message };
  }
};

// ============================================================================
// ENDPOINTS
// ============================================================================

/**
 * POST /api/admin/create-owner
 * Admin creates an Owner account
 *
 * Request:
 * {
 *   "email": "owner@business.com",
 *   "phone": "+919999999999",
 *   "full_name": "Shop Owner Name",
 *   "shop_id": "uuid"
 * }
 *
 * Returns:
 * {
 *   "success": true,
 *   "temporary_password": "ABC123DEF456",
 *   "message": "Owner account created. Email has been sent with login credentials."
 * }
 */
router.post('/create-owner', async (req, res) => {
  try {
    const { email, phone, full_name, shop_id } = req.body;

    // Validation
    if (!email || !full_name || !shop_id) {
      return res.status(400).json({
        success: false,
        error: 'Email, full_name, and shop_id are required'
      });
    }

    // Pre-authorization check: verify email is authorized to be owner
    const { data: preAuthUser } = await supabase
      .from('pre_authorized_users')
      .select('*')
      .eq('email', email)
      .eq('role', 'owner')
      .eq('shop_id', shop_id)
      .single();

    if (!preAuthUser) {
      return res.status(403).json({
        success: false,
        error: 'Email is not pre-authorized to create owner account for this shop'
      });
    }

    // Check if email already exists
    const { data: existingUser } = await supabase
      .from('operational_users')
      .select('id')
      .eq('email', email)
      .single();

    if (existingUser) {
      return res.status(400).json({
        success: false,
        error: 'Email already registered'
      });
    }

    // Verify shop exists
    const { data: shop } = await supabase
      .from('shops')
      .select('id, name')
      .eq('id', shop_id)
      .single();

    if (!shop) {
      return res.status(400).json({
        success: false,
        error: 'Shop not found'
      });
    }

    // Generate temporary password
    const tempPassword = generateTemporaryPassword();
    const passwordHash = await hashPassword(tempPassword);

    // Create operational user (Owner)
    const { data: newOwner, error } = await supabase
      .from('operational_users')
      .insert({
        user_type: 'owner',
        owner_id: shop_id,
        email,
        phone,
        full_name,
        password_hash: passwordHash,
        is_active: true,
        is_verified: false,
        created_by: req.user.id,
        created_at: new Date()
      })
      .select()
      .single();

    if (error) {
      console.error('Create owner error:', error);
      return res.status(500).json({
        success: false,
        error: 'Failed to create owner account'
      });
    }

    // Update shop owner info
    await supabase
      .from('shops')
      .update({
        owner_email: email,
        owner_phone: phone
      })
      .eq('id', shop_id);

    // Log admin action
    await logAdminAction(req.user.id, 'CREATE_OWNER', newOwner.id, {
      email,
      shop_id,
      shop_name: shop.name
    });

    // Mark pre-authorized user as used
    await supabase
      .from('pre_authorized_users')
      .update({
        used_at: new Date(),
        user_id: newOwner.id
      })
      .eq('id', preAuthUser.id);

    // Send welcome email with credentials
    const loginUrl = `${process.env.APP_BASE_URL || 'https://app.fufaji.com'}/login`;
    await sendEmail(
      email,
      process.env.SENDGRID_OWNER_WELCOME_TEMPLATE_ID || 'd-OWNER_WELCOME_TEMPLATE',
      {
        full_name: full_name,
        email: email,
        temporary_password: tempPassword,
        login_url: loginUrl,
        shop_name: shop.name
      }
    );

    // Sync to Firestore for real-time UI updates
    await syncUserToFirestore(newOwner, 'owners');

    return res.json({
      success: true,
      user: {
        id: newOwner.id,
        email: newOwner.email,
        full_name: newOwner.full_name,
        user_type: 'owner'
      },
      message: 'Owner account created successfully. Welcome email sent with login credentials.'
    });

  } catch (err) {
    console.error('Create owner error:', err);
    return res.status(500).json({
      success: false,
      error: 'Failed to create owner account'
    });
  }
});

/**
 * POST /api/admin/create-employee
 * Admin or Owner creates Employee/Rider/Supplier account
 *
 * Request:
 * {
 *   "email": "emp@business.com",
 *   "full_name": "Employee Name",
 *   "phone": "+919999999999",
 *   "user_type": "employee|rider|supplier",
 *   "owner_id": "uuid"
 * }
 */
router.post('/create-employee', async (req, res) => {
  try {
    const { email, full_name, phone, user_type, owner_id } = req.body;

    // Validation
    if (!email || !full_name || !user_type || !owner_id) {
      return res.status(400).json({
        success: false,
        error: 'Email, full_name, user_type, and owner_id are required'
      });
    }

    if (!['employee', 'rider', 'supplier'].includes(user_type)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid user_type. Must be: employee, rider, or supplier'
      });
    }

    // Authorization: Check if user is admin or owner
    const isAdmin = !!req.adminLevel;

    let isOwnerOfShop = false;
    if (!isAdmin) {
      // If not admin, check if user is owner of the specified shop
      const { data: ownerUser } = await supabase
        .from('operational_users')
        .select('owner_id')
        .eq('id', req.user.id)
        .eq('user_type', 'owner')
        .single();

      if (ownerUser && ownerUser.owner_id === owner_id) {
        isOwnerOfShop = true;
      }
    }

    // Only allow if user is admin OR owner of the shop
    if (!isAdmin && !isOwnerOfShop) {
      return res.status(403).json({
        success: false,
        error: 'You must be an admin or owner of this shop to create employees'
      });
    }

    // Check if email already exists
    const { data: existingUser } = await supabase
      .from('operational_users')
      .select('id')
      .eq('email', email)
      .single();

    if (existingUser) {
      return res.status(400).json({
        success: false,
        error: 'Email already registered'
      });
    }

    // Verify owner exists
    const { data: ownerShop } = await supabase
      .from('shops')
      .select('id, name')
      .eq('id', owner_id)
      .single();

    if (!ownerShop) {
      return res.status(400).json({
        success: false,
        error: 'Owner/Shop not found'
      });
    }

    // Generate temporary password
    const tempPassword = generateTemporaryPassword();
    const passwordHash = await hashPassword(tempPassword);

    // Create employee
    const { data: newEmployee, error } = await supabase
      .from('operational_users')
      .insert({
        user_type,
        owner_id,
        email,
        phone,
        full_name,
        password_hash: passwordHash,
        is_active: true,
        is_verified: false,
        created_by: req.user.id,
        created_at: new Date()
      })
      .select()
      .single();

    if (error) {
      console.error('Create employee error:', error);
      return res.status(500).json({
        success: false,
        error: 'Failed to create employee account'
      });
    }

    // Log admin action
    await logAdminAction(req.user.id, 'CREATE_EMPLOYEE', newEmployee.id, {
      email,
      user_type,
      owner_id,
      shop_name: ownerShop.name
    });

    // Sync to Firestore for real-time UI updates
    await syncUserToFirestore(newEmployee);

    // TODO: Send email with credentials

    return res.json({
      success: true,
      user: {
        id: newEmployee.id,
        email: newEmployee.email,
        full_name: newEmployee.full_name,
        user_type
      },
      temporary_password: tempPassword,
      message: `${user_type} account created successfully.`
    });

  } catch (err) {
    console.error('Create employee error:', err);
    return res.status(500).json({
      success: false,
      error: 'Failed to create employee account'
    });
  }
});

/**
 * PUT /api/admin/users/:userId/disable
 * Disable a user account
 */
router.put('/users/:userId/disable', async (req, res) => {
  try {
    const { userId } = req.params;

    // Determine user type from request or auto-detect
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

    // Authorization check
    if (req.adminLevel > 1 && user.owner_id !== req.user.id) {
      return res.status(403).json({
        success: false,
        error: 'You can only disable users under your supervision'
      });
    }

    // Disable user
    const { data: disabledUser } = await supabase
      .from('operational_users')
      .update({
        is_active: false
      })
      .eq('id', userId)
      .select()
      .single();

    // Log admin action
    await logAdminAction(req.user.id, 'DISABLE_USER', userId, {
      email: user.email,
      user_type: user.user_type
    });

    // Sync to Firestore
    if (disabledUser) {
      await syncUserToFirestore(disabledUser);
    }

    return res.json({
      success: true,
      message: 'User account disabled'
    });

  } catch (err) {
    console.error('Disable user error:', err);
    return res.status(500).json({
      success: false,
      error: 'Failed to disable user'
    });
  }
});

/**
 * PUT /api/admin/users/:userId/enable
 * Re-enable a disabled user account
 */
router.put('/users/:userId/enable', async (req, res) => {
  try {
    const { userId } = req.params;

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

    // Authorization check
    if (req.adminLevel > 1 && user.owner_id !== req.user.id) {
      return res.status(403).json({
        success: false,
        error: 'You can only enable users under your supervision'
      });
    }

    // Enable user
    const { data: enabledUser } = await supabase
      .from('operational_users')
      .update({
        is_active: true
      })
      .eq('id', userId)
      .select()
      .single();

    // Log admin action
    await logAdminAction(req.user.id, 'ENABLE_USER', userId, {
      email: user.email
    });

    // Sync to Firestore
    if (enabledUser) {
      await syncUserToFirestore(enabledUser);
    }

    return res.json({
      success: true,
      message: 'User account enabled'
    });

  } catch (err) {
    console.error('Enable user error:', err);
    return res.status(500).json({
      success: false,
      error: 'Failed to enable user'
    });
  }
});

/**
 * GET /api/admin/users
 * List all operational users (filtered by admin level)
 */
router.get('/users', async (req, res) => {
  try {
    const { user_type, owner_id, page = 1, limit = 50 } = req.query;

    let query = supabase
      .from('operational_users')
      .select('id, email, full_name, user_type, owner_id, is_active, last_login_at, created_at');

    // Authorization: Non-superadmins can only see their team
    if (req.adminLevel > 1) {
      const { data: ownerShops } = await supabase
        .from('shops')
        .select('id')
        .eq('owner_id', req.user.id);

      const shopIds = ownerShops.map(s => s.id);
      query = query.in('owner_id', shopIds);
    } else if (owner_id) {
      // Superadmin can filter by owner_id
      query = query.eq('owner_id', owner_id);
    }

    if (user_type) {
      query = query.eq('user_type', user_type);
    }

    const offset = (parseInt(page) - 1) * parseInt(limit);
    const { data: users, error } = await query
      .order('created_at', { ascending: false })
      .range(offset, offset + parseInt(limit) - 1);

    if (error) {
      throw error;
    }

    return res.json({
      success: true,
      users,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: users.length
      }
    });

  } catch (err) {
    console.error('List users error:', err);
    return res.status(500).json({
      success: false,
      error: 'Failed to list users'
    });
  }
});

module.exports = router;
