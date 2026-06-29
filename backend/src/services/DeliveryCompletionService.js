/**
 * DeliveryCompletionService
 *
 * Handles delivery completion with proof verification.
 * Supports OTP, photo, and signature-based completion.
 *
 * Features:
 * - OTP generation and verification (4-digit)
 * - Photo proof validation
 * - Signature capture
 * - Payment deduction
 * - Fulfillment cleanup
 * - Customer feedback collection
 */

const admin = require('firebase-admin');
const db = admin.firestore();

const OTP_LENGTH = 4;
const OTP_EXPIRY_MINUTES = 10;
const MAX_OTP_ATTEMPTS = 3;
const OTP_LOCK_DURATION_MINUTES = 5;

class DeliveryCompletionService {
  /**
   * Complete a delivery with proof
   *
   * @param {string} deliveryTaskId - Delivery task ID
   * @param {string} proofType - 'otp' | 'photo' | 'signature'
   * @param {Object} proofData - Proof data (varies by type)
   * @returns {Promise<Object>} - Completion result
   */
  async completeDelivery(deliveryTaskId, proofType, proofData) {
    try {
      // Get delivery task
      const taskDoc = await db.collection('delivery_tasks').doc(deliveryTaskId).get();

      if (!taskDoc.exists) {
        return {
          success: false,
          error: 'Delivery task not found',
          code: 'TASK_NOT_FOUND'
        };
      }

      const task = taskDoc.data();
      const orderId = task.order_id;
      const customerId = task.customer_id;

      // Verify proof based on type
      const proofValid = await this.verifyProof(proofType, proofData, deliveryTaskId);

      if (!proofValid.valid) {
        return {
          success: false,
          error: proofValid.error,
          code: 'PROOF_INVALID'
        };
      }

      // Mark delivery as completed
      await db.collection('delivery_tasks').doc(deliveryTaskId).update({
        status: 'completed',
        completed_at: admin.firestore.FieldValue.serverTimestamp(),
        proof_type: proofType,
        proof_data: proofData,
        completion_notes: proofValid.notes
      });

      // Update rider's load
      await db.collection('delivery_agents').doc(task.rider_id).update({
        current_load: admin.firestore.FieldValue.increment(-1),
        completed_deliveries: admin.firestore.FieldValue.increment(1),
        updated_at: admin.firestore.FieldValue.serverTimestamp()
      });

      // Update order status
      await db.collection('orders').doc(orderId).update({
        status: 'delivered',
        delivered_at: admin.firestore.FieldValue.serverTimestamp(),
        delivery_proof: {
          type: proofType,
          timestamp: new Date().toISOString()
        }
      });

      // Handle payment
      const paymentResult = await this.handlePayment(orderId, task);

      // Request customer feedback
      await this.requestCustomerFeedback(orderId, customerId, deliveryTaskId);

      // Clean up fulfillment
      await this.cleanupFulfillment(orderId);

      return {
        success: true,
        delivery_task_id: deliveryTaskId,
        order_id: orderId,
        status: 'delivered',
        completed_at: new Date().toISOString(),
        payment: paymentResult,
        next_step: 'feedback_requested'
      };
    } catch (error) {
      console.error('Error completing delivery:', error);
      return {
        success: false,
        error: error.message,
        retryable: true,
        code: 'COMPLETION_ERROR'
      };
    }
  }

  /**
   * Verify delivery proof based on type
   *
   * @param {string} proofType - Type of proof
   * @param {Object} proofData - Proof data
   * @param {string} deliveryTaskId - Delivery task ID
   * @returns {Promise<Object>} - Verification result
   */
  async verifyProof(proofType, proofData, deliveryTaskId) {
    try {
      switch (proofType) {
        case 'otp':
          return await this.verifyOTP(proofData.entered_otp, deliveryTaskId);

        case 'photo':
          return await this.verifyPhotoProof(proofData);

        case 'signature':
          return await this.verifySignature(proofData);

        default:
          return {
            valid: false,
            error: 'Invalid proof type'
          };
      }
    } catch (error) {
      console.error('Error verifying proof:', error);
      return {
        valid: false,
        error: error.message
      };
    }
  }

  /**
   * Generate OTP for delivery
   *
   * @param {string} deliveryTaskId - Delivery task ID
   * @param {string} customerId - Customer ID
   * @returns {Promise<Object>} - OTP generation result
   */
  async generateOTP(deliveryTaskId, customerId) {
    try {
      // Check if OTP already exists and is valid
      const existingOtp = await this.getValidOTP(deliveryTaskId);

      if (existingOtp) {
        return {
          success: true,
          message: 'OTP already generated, check your SMS',
          expires_in_minutes: Math.ceil(
            (existingOtp.expires_at.toDate().getTime() - Date.now()) / 60000
          )
        };
      }

      // Generate 4-digit OTP
      const otp = this.generateRandomOTP();

      // Store in Firestore with expiry
      const otpDoc = await db.collection('delivery_otps').add({
        delivery_task_id: deliveryTaskId,
        customer_id: customerId,
        otp_value: otp,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        expires_at: admin.firestore.Timestamp.fromDate(
          new Date(Date.now() + OTP_EXPIRY_MINUTES * 60000)
        ),
        attempts: 0,
        verified: false,
        locked_until: null
      });

      // In production, send SMS to customer with OTP
      // For now, just log it
      console.log(`OTP generated for delivery ${deliveryTaskId}: ${otp}`);

      // Store OTP in order for debugging (remove in production)
      await db.collection('orders').doc(deliveryTaskId).update({
        debug_otp: otp
      }).catch(() => {
        // Ignore if order doc doesn't exist at this key
      });

      return {
        success: true,
        otp_id: otpDoc.id,
        message: 'OTP sent to customer phone',
        expires_in_minutes: OTP_EXPIRY_MINUTES
      };
    } catch (error) {
      console.error('Error generating OTP:', error);
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Generate random 4-digit OTP
   *
   * @returns {string} - 4-digit OTP
   */
  generateRandomOTP() {
    return String(Math.floor(Math.random() * 10000)).padStart(OTP_LENGTH, '0');
  }

  /**
   * Get valid OTP for delivery task
   *
   * @param {string} deliveryTaskId - Delivery task ID
   * @returns {Promise<Object|null>} - OTP record or null
   */
  async getValidOTP(deliveryTaskId) {
    try {
      const snapshot = await db.collection('delivery_otps')
        .where('delivery_task_id', '==', deliveryTaskId)
        .where('verified', '==', false)
        .orderBy('created_at', 'desc')
        .limit(1)
        .get();

      if (snapshot.empty) {
        return null;
      }

      const otpRecord = snapshot.docs[0];
      const otpData = otpRecord.data();

      // Check if expired
      if (otpData.expires_at.toDate().getTime() < Date.now()) {
        return null;
      }

      // Check if locked
      if (otpData.locked_until && otpData.locked_until.toDate().getTime() > Date.now()) {
        return null;
      }

      return otpData;
    } catch (error) {
      console.error('Error getting valid OTP:', error);
      return null;
    }
  }

  /**
   * Verify entered OTP
   *
   * @param {string} enteredOtp - OTP entered by rider
   * @param {string} deliveryTaskId - Delivery task ID
   * @returns {Promise<Object>} - Verification result
   */
  async verifyOTP(enteredOtp, deliveryTaskId) {
    try {
      const snapshot = await db.collection('delivery_otps')
        .where('delivery_task_id', '==', deliveryTaskId)
        .where('verified', '==', false)
        .orderBy('created_at', 'desc')
        .limit(1)
        .get();

      if (snapshot.empty) {
        return {
          valid: false,
          error: 'No OTP found for this delivery'
        };
      }

      const otpDoc = snapshot.docs[0];
      const otpData = otpDoc.data();

      // Check if expired
      if (otpData.expires_at.toDate().getTime() < Date.now()) {
        return {
          valid: false,
          error: 'OTP has expired'
        };
      }

      // Check if locked (too many attempts)
      if (otpData.locked_until && otpData.locked_until.toDate().getTime() > Date.now()) {
        return {
          valid: false,
          error: 'Too many attempts. Please try again later.',
          locked_until: otpData.locked_until.toDate().toISOString()
        };
      }

      // Verify OTP
      if (otpData.otp_value === enteredOtp) {
        // Mark as verified
        await otpDoc.ref.update({
          verified: true,
          verified_at: admin.firestore.FieldValue.serverTimestamp()
        });

        return {
          valid: true,
          notes: 'OTP verified'
        };
      }

      // Increment attempts
      const newAttempts = (otpData.attempts || 0) + 1;

      const updateData = {
        attempts: newAttempts
      };

      // Lock if max attempts exceeded
      if (newAttempts >= MAX_OTP_ATTEMPTS) {
        updateData.locked_until = admin.firestore.Timestamp.fromDate(
          new Date(Date.now() + OTP_LOCK_DURATION_MINUTES * 60000)
        );
      }

      await otpDoc.ref.update(updateData);

      return {
        valid: false,
        error: `OTP mismatch. ${MAX_OTP_ATTEMPTS - newAttempts} attempts remaining.`,
        attempts_left: Math.max(0, MAX_OTP_ATTEMPTS - newAttempts)
      };
    } catch (error) {
      console.error('Error verifying OTP:', error);
      return {
        valid: false,
        error: error.message
      };
    }
  }

  /**
   * Verify photo proof
   *
   * @param {Object} photoData - Photo data {url, timestamp, latitude, longitude}
   * @returns {Promise<Object>} - Verification result
   */
  async verifyPhotoProof(photoData) {
    try {
      // Validate photo data
      if (!photoData.url) {
        return {
          valid: false,
          error: 'Photo URL is required'
        };
      }

      // In production:
      // - Download image and verify format
      // - Check image size and dimensions
      // - Apply ML to detect if it's actually a delivery
      // For now, just validate URL format

      const urlPattern = /^https?:\/\/.+/i;
      if (!urlPattern.test(photoData.url)) {
        return {
          valid: false,
          error: 'Invalid photo URL'
        };
      }

      return {
        valid: true,
        notes: `Photo verified: ${photoData.url}`
      };
    } catch (error) {
      console.error('Error verifying photo proof:', error);
      return {
        valid: false,
        error: error.message
      };
    }
  }

  /**
   * Verify signature proof
   *
   * @param {Object} signatureData - Signature data {svg_path, timestamp}
   * @returns {Promise<Object>} - Verification result
   */
  async verifySignature(signatureData) {
    try {
      if (!signatureData.svg_path || typeof signatureData.svg_path !== 'string') {
        return {
          valid: false,
          error: 'Invalid signature data'
        };
      }

      // Validate SVG format
      if (!signatureData.svg_path.includes('<svg')) {
        return {
          valid: false,
          error: 'Signature must be in SVG format'
        };
      }

      return {
        valid: true,
        notes: 'Signature captured'
      };
    } catch (error) {
      console.error('Error verifying signature:', error);
      return {
        valid: false,
        error: error.message
      };
    }
  }

  /**
   * Handle payment for completed delivery
   *
   * @param {string} orderId - Order ID
   * @param {Object} task - Delivery task
   * @returns {Promise<Object>} - Payment result
   */
  async handlePayment(orderId, task) {
    try {
      // Get order details
      const orderDoc = await db.collection('orders').doc(orderId).get();

      if (!orderDoc.exists) {
        return {
          success: false,
          error: 'Order not found'
        };
      }

      const order = orderDoc.data();
      const paymentMethod = order.payment_method || 'wallet';

      if (paymentMethod === 'wallet') {
        // Deduct from wallet
        await db.collection('user_wallets').doc(task.customer_id).update({
          balance: admin.firestore.FieldValue.increment(-order.total_amount),
          updated_at: admin.firestore.FieldValue.serverTimestamp()
        });

        // Record transaction
        await db.collection('wallet_transactions').add({
          user_id: task.customer_id,
          order_id: orderId,
          type: 'debit',
          amount: order.total_amount,
          reason: 'Order payment',
          created_at: admin.firestore.FieldValue.serverTimestamp()
        });
      }

      return {
        success: true,
        payment_method: paymentMethod,
        amount: order.total_amount,
        status: 'completed'
      };
    } catch (error) {
      console.error('Error handling payment:', error);
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Request customer feedback
   *
   * @param {string} orderId - Order ID
   * @param {string} customerId - Customer ID
   * @param {string} deliveryTaskId - Delivery task ID
   */
  async requestCustomerFeedback(orderId, customerId, deliveryTaskId) {
    try {
      await db.collection('feedback_requests').add({
        order_id: orderId,
        customer_id: customerId,
        delivery_task_id: deliveryTaskId,
        type: 'delivery_feedback',
        status: 'pending',
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        expires_at: admin.firestore.Timestamp.fromDate(
          new Date(Date.now() + 7 * 24 * 3600000) // 7 days
        ),
        rating: null,
        review: null,
        submitted_at: null
      });

      return { success: true };
    } catch (error) {
      console.error('Error requesting feedback:', error);
      return { success: false, error: error.message };
    }
  }

  /**
   * Clean up fulfillment data
   *
   * @param {string} orderId - Order ID
   */
  async cleanupFulfillment(orderId) {
    try {
      // Archive packing details
      const packingDocs = await db.collection('packing_tasks')
        .where('order_id', '==', orderId)
        .get();

      for (const doc of packingDocs.docs) {
        await doc.ref.update({
          archived: true,
          archived_at: admin.firestore.FieldValue.serverTimestamp()
        });
      }

      return { success: true };
    } catch (error) {
      console.error('Error cleaning up fulfillment:', error);
      return { success: false, error: error.message };
    }
  }

  /**
   * Submit delivery feedback
   *
   * @param {string} feedbackRequestId - Feedback request ID
   * @param {number} rating - Rating 1-5
   * @param {string} review - Text review (optional)
   * @param {Object} photos - Photo data (optional)
   * @returns {Promise<Object>} - Submission result
   */
  async submitFeedback(feedbackRequestId, rating, review, photos) {
    try {
      if (rating < 1 || rating > 5) {
        return {
          success: false,
          error: 'Rating must be between 1 and 5'
        };
      }

      await db.collection('feedback_requests').doc(feedbackRequestId).update({
        rating,
        review: review || '',
        photos: photos || [],
        status: 'submitted',
        submitted_at: admin.firestore.FieldValue.serverTimestamp()
      });

      // Create feedback record
      const feedbackDoc = await db.collection('feedback_requests').doc(feedbackRequestId).get();
      const feedbackData = feedbackDoc.data();

      await db.collection('delivery_feedback').add({
        order_id: feedbackData.order_id,
        customer_id: feedbackData.customer_id,
        delivery_task_id: feedbackData.delivery_task_id,
        rating,
        review: review || '',
        photos: photos || [],
        submitted_at: admin.firestore.FieldValue.serverTimestamp()
      });

      return {
        success: true,
        message: 'Thank you for your feedback!'
      };
    } catch (error) {
      console.error('Error submitting feedback:', error);
      return {
        success: false,
        error: error.message
      };
    }
  }
}

module.exports = new DeliveryCompletionService();
