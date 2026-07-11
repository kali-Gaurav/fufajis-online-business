/**
 * ============================================================================
 * routes/commissions.js - Vendor Commission Management
 * ============================================================================
 * GET    /commissions/pending           Get pending commissions (vendor)
 * GET    /commissions/ledger            Get commission ledger (audit trail)
 * GET    /commissions/stats             Get commission statistics (dashboard)
 * POST   /commissions/mark-paid         Mark commissions as paid (admin)
 * ============================================================================
 */

const express = require('express');
const router = express.Router();
const CommissionService = require('../services/CommissionService');
const { authMiddleware, requireRole } = require('../middleware/validation');

/**
 * GET /commissions/pending
 * Get pending commissions for authenticated vendor
 */
router.get('/pending', authMiddleware, async (req, res) => {
  try {
    const vendorId = req.user.id;
    const limit = Math.min(parseInt(req.query.limit) || 50, 200);

    // Verify user is a vendor
    if (req.user.role !== 'UserRole.vendor' && req.user.role !== 'UserRole.shopOwner') {
      return res.status(403).json({
        success: false,
        error: 'UNAUTHORIZED',
        message: 'Only vendors can view commissions'
      });
    }

    const result = await CommissionService.getPendingCommissions(vendorId, limit);

    res.json({
      success: true,
      data: {
        commissions: result.commissions,
        totalPending: result.totalPending,
        count: result.count
      }
    });
  } catch (err) {
    console.error('[commissions] ❌ Get pending failed:', err.message);
    res.status(500).json({
      success: false,
      error: 'GET_FAILED',
      message: err.message
    });
  }
});

/**
 * GET /commissions/ledger
 * Get commission ledger with pagination (vendor view)
 */
router.get('/ledger', authMiddleware, async (req, res) => {
  try {
    const vendorId = req.user.id;
    const limit = Math.min(parseInt(req.query.limit) || 50, 200);
    const offset = parseInt(req.query.offset) || 0;

    // Verify user is a vendor
    if (req.user.role !== 'UserRole.vendor' && req.user.role !== 'UserRole.shopOwner') {
      return res.status(403).json({
        success: false,
        error: 'UNAUTHORIZED',
        message: 'Only vendors can view ledger'
      });
    }

    const ledger = await CommissionService.getCommissionLedger(vendorId, limit, offset);

    res.json({
      success: true,
      data: {
        ledger: ledger,
        count: ledger.length,
        limit: limit,
        offset: offset
      }
    });
  } catch (err) {
    console.error('[commissions] ❌ Get ledger failed:', err.message);
    res.status(500).json({
      success: false,
      error: 'GET_FAILED',
      message: err.message
    });
  }
});

/**
 * GET /commissions/stats
 * Get commission statistics and dashboard data (vendor view)
 */
router.get('/stats', authMiddleware, async (req, res) => {
  try {
    const vendorId = req.user.id;

    // Verify user is a vendor
    if (req.user.role !== 'UserRole.vendor' && req.user.role !== 'UserRole.shopOwner') {
      return res.status(403).json({
        success: false,
        error: 'UNAUTHORIZED',
        message: 'Only vendors can view stats'
      });
    }

    const stats = await CommissionService.getCommissionStats(vendorId);

    res.json({
      success: true,
      data: stats
    });
  } catch (err) {
    console.error('[commissions] ❌ Get stats failed:', err.message);
    res.status(500).json({
      success: false,
      error: 'GET_FAILED',
      message: err.message
    });
  }
});

/**
 * POST /commissions/mark-paid
 * Mark commissions as paid (admin-only after payout processed)
 */
router.post('/mark-paid', requireRole('UserRole.admin', 'UserRole.shopOwner'), async (req, res) => {
  try {
    const { vendorId, commissionIds } = req.body;

    if (!vendorId) {
      return res.status(400).json({
        success: false,
        error: 'INVALID_REQUEST',
        message: 'vendorId is required'
      });
    }

    const result = await CommissionService.markCommissionsAsPaid(
      vendorId,
      commissionIds || []
    );

    console.log(`[commissions] ✅ Marked ${result.paid} commissions as paid`);

    res.json({
      success: true,
      data: {
        paid: result.paid,
        totalPaid: result.totalPaid,
        message: `Marked ${result.paid} commissions as paid`
      }
    });
  } catch (err) {
    console.error('[commissions] ❌ Mark paid failed:', err.message);
    res.status(500).json({
      success: false,
      error: 'MARK_PAID_FAILED',
      message: err.message
    });
  }
});

module.exports = router;
