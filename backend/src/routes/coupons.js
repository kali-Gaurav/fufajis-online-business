const express = require('express');
const router = express.Router();
const CouponService = require('../services/CouponService');
const { authMiddleware, adminMiddleware } = require('../middleware/validation');

// GET all active coupons
router.get('/active', async (req, res) => {
  try {
    const coupons = await CouponService.getActiveCoupons();
    res.json({ success: true, data: coupons });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// POST validate and apply coupon
router.post('/validate', authMiddleware, async (req, res) => {
  try {
    const { couponCode, orderTotal, items } = req.body;

    const result = await CouponService.validateAndApply({
      couponCode,
      orderTotal,
      userId: req.user.id,
      items,
    });

    res.json({ success: true, data: result });
  } catch (err) {
    res.status(400).json({ success: false, error: err.message });
  }
});

// POST create coupon (admin only)
router.post('/', adminMiddleware, async (req, res) => {
  try {
    const {
      code,
      type,
      discountValue,
      maxUsage,
      validFrom,
      validTo,
      minOrderValue,
      maxDiscount,
      applicableCategories,
    } = req.body;

    const coupon = await CouponService.createCoupon({
      code,
      type,
      discountValue,
      maxUsage,
      validFrom,
      validTo,
      minOrderValue,
      maxDiscount,
      applicableCategories,
      createdBy: req.user.id,
    });

    res.json({ success: true, data: coupon });
  } catch (err) {
    res.status(400).json({ success: false, error: err.message });
  }
});

// DELETE disable coupon (admin only)
router.delete('/:couponId', adminMiddleware, async (req, res) => {
  try {
    const { couponId } = req.params;
    const coupon = await CouponService.disableCoupon(couponId);

    res.json({ success: true, data: coupon });
  } catch (err) {
    res.status(400).json({ success: false, error: err.message });
  }
});

module.exports = router;
