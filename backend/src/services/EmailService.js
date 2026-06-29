/**
 * ============================================================================
 * EmailService.js - SendGrid Email Integration
 * ============================================================================
 * Handles:
 * - Email delivery via SendGrid
 * - Email template rendering
 * - Personalized order confirmation, delivery tracking, refund emails
 * - Review request emails with deep links
 * - Weekly summary emails
 * - Bounce/delivery tracking
 * ============================================================================
 */

const sgMail = require('@sendgrid/mail');
const { admin, db } = require('../firestore');

class EmailService {
  constructor() {
    const apiKey = process.env.SENDGRID_API_KEY;
    if (!apiKey) {
      console.warn('[EmailService] SENDGRID_API_KEY not configured. Mocking sgMail.send to avoid runtime crashes.');
      sgMail.send = async (msg) => {
        console.log(`[EmailService Mock] Mock send called for email to: ${Array.isArray(msg.to) ? msg.to.join(', ') : msg.to}`);
        return [{ statusCode: 202, body: 'Mocked email sent successfully' }];
      };
    } else {
      sgMail.setApiKey(apiKey);
    }
  }

  /**
   * Send order confirmation email
   *
   * @param {string} customerId - Customer ID
   * @param {string} orderId - Order ID
   * @param {object} orderData - { items: [...], total, deliveryAddress, estimatedTime }
   * @returns {Promise}
   */
  async sendOrderConfirmation(customerId, orderId, orderData) {
    const firestore = db();

    try {
      // 1. Get customer email
      const customerRef = firestore.collection('users').doc(customerId);
      const customerDoc = await customerRef.get();

      if (!customerDoc.exists) {
        throw new Error(`Customer ${customerId} not found`);
      }

      const customer = customerDoc.data();
      const customerEmail = customer.email;
      const customerName = customer.name || 'Valued Customer';

      // 2. Build email content
      const itemsHtml = orderData.items
        .map(
          (item) => `
            <tr>
              <td style="padding: 8px; border-bottom: 1px solid #eee;">
                <strong>${item.name}</strong>
              </td>
              <td style="padding: 8px; border-bottom: 1px solid #eee; text-align: center;">
                ${item.quantity}
              </td>
              <td style="padding: 8px; border-bottom: 1px solid #eee; text-align: right;">
                ₹${item.price.toFixed(2)}
              </td>
              <td style="padding: 8px; border-bottom: 1px solid #eee; text-align: right;">
                ₹${(item.quantity * item.price).toFixed(2)}
              </td>
            </tr>
          `
        )
        .join('');

      const htmlContent = `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <style>
            body { font-family: Arial, sans-serif; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background: #2563eb; color: white; padding: 20px; border-radius: 8px 8px 0 0; }
            .content { background: #f9fafb; padding: 20px; border-radius: 0 0 8px 8px; }
            .order-item { margin: 15px 0; }
            .total { font-size: 18px; font-weight: bold; color: #2563eb; margin-top: 20px; }
            .button { 
              display: inline-block; 
              background: #2563eb; 
              color: white; 
              padding: 12px 24px; 
              border-radius: 6px; 
              text-decoration: none; 
              margin-top: 20px;
            }
            table { width: 100%; border-collapse: collapse; margin: 20px 0; }
            th { background: #e5e7eb; padding: 10px; text-align: left; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1 style="margin: 0;">Order Confirmed!</h1>
              <p style="margin: 5px 0 0 0;">Order #${orderId.slice(-6)}</p>
            </div>
            
            <div class="content">
              <p>Hi ${customerName},</p>
              
              <p>Your order has been confirmed and is being prepared for dispatch.</p>
              
              <table>
                <thead>
                  <tr>
                    <th>Item</th>
                    <th style="text-align: center;">Quantity</th>
                    <th style="text-align: right;">Price</th>
                    <th style="text-align: right;">Total</th>
                  </tr>
                </thead>
                <tbody>
                  ${itemsHtml}
                </tbody>
              </table>
              
              <div style="background: #f0f9ff; padding: 15px; border-radius: 6px; margin: 20px 0;">
                <p><strong>Delivery Address:</strong><br>${orderData.deliveryAddress}</p>
                <p><strong>Estimated Delivery:</strong><br>${orderData.estimatedTime} minutes</p>
              </div>
              
              <div class="total">
                Total: ₹${orderData.total.toFixed(2)}
              </div>
              
              <a href="https://fufaji.app/order/${orderId}" class="button">Track Your Order</a>
              
              <hr style="margin: 30px 0; border: none; border-top: 1px solid #ddd;">
              <p style="color: #666; font-size: 12px;">
                If you have any questions, reply to this email or contact our support team.
              </p>
            </div>
          </div>
        </body>
        </html>
      `;

      // 3. Send via SendGrid
      const msg = {
        to: customerEmail,
        from: process.env.SENDGRID_FROM_EMAIL || 'shop@fufaji.com',
        subject: `Order Confirmed: #${orderId.slice(-6)}`,
        html: htmlContent,
        categories: ['order_confirmation'],
      };

      await sgMail.send(msg);

      // 4. Log in email history
      await this._logEmail(customerId, 'order_confirmation', {
        orderId,
        recipient: customerEmail,
        status: 'sent',
      });

      console.log(`[EmailService] Order confirmation sent to ${customerEmail}`);

      return { success: true };
    } catch (error) {
      console.error('[EmailService] Error sending order confirmation:', error.message);
      throw error;
    }
  }

  /**
   * Send delivery tracking email
   *
   * @param {string} customerId
   * @param {string} orderId
   * @param {string} riderName
   * @param {string} riderPhone - Optional
   * @param {string} eta - ETA text (e.g., "2:30 PM")
   * @returns {Promise}
   */
  async sendDeliveryTracking(customerId, orderId, riderName, riderPhone, eta) {
    const firestore = db();

    try {
      const customerRef = firestore.collection('users').doc(customerId);
      const customerDoc = await customerRef.get();

      if (!customerDoc.exists) {
        throw new Error(`Customer ${customerId} not found`);
      }

      const customer = customerDoc.data();
      const customerEmail = customer.email;
      const customerName = customer.name || 'Valued Customer';

      const htmlContent = `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <style>
            body { font-family: Arial, sans-serif; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background: #10b981; color: white; padding: 20px; border-radius: 8px 8px 0 0; }
            .content { background: #f0fdf4; padding: 20px; border-radius: 0 0 8px 8px; }
            .rider-info { background: white; border: 2px solid #10b981; padding: 15px; border-radius: 6px; margin: 20px 0; }
            .button { 
              display: inline-block; 
              background: #10b981; 
              color: white; 
              padding: 12px 24px; 
              border-radius: 6px; 
              text-decoration: none; 
              margin-top: 20px;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1 style="margin: 0;">Out for Delivery!</h1>
              <p style="margin: 5px 0 0 0;">Order #${orderId.slice(-6)}</p>
            </div>
            
            <div class="content">
              <p>Hi ${customerName},</p>
              
              <p>Your order is out for delivery. Here are your rider details:</p>
              
              <div class="rider-info">
                <p style="margin: 0;"><strong>Rider:</strong> ${riderName}</p>
                ${riderPhone ? `<p style="margin: 5px 0;"><strong>Contact:</strong> ${riderPhone}</p>` : ''}
                <p style="margin: 5px 0;"><strong>Estimated Arrival:</strong> ${eta}</p>
              </div>
              
              <p>You can track your order in real-time using the link below:</p>
              
              <a href="https://fufaji.app/order/${orderId}" class="button">Live Tracking</a>
              
              <hr style="margin: 30px 0; border: none; border-top: 1px solid #ddd;">
              <p style="color: #666; font-size: 12px;">
                Questions? Contact our support team or reply to this email.
              </p>
            </div>
          </div>
        </body>
        </html>
      `;

      const msg = {
        to: customerEmail,
        from: process.env.SENDGRID_FROM_EMAIL || 'shop@fufaji.com',
        subject: `Your order is on the way! - #${orderId.slice(-6)}`,
        html: htmlContent,
        categories: ['delivery_tracking'],
      };

      await sgMail.send(msg);

      await this._logEmail(customerId, 'delivery_tracking', {
        orderId,
        recipient: customerEmail,
        riderName,
      });

      console.log(`[EmailService] Delivery tracking sent to ${customerEmail}`);

      return { success: true };
    } catch (error) {
      console.error('[EmailService] Error sending delivery tracking:', error.message);
      throw error;
    }
  }

  /**
   * Send refund notification
   *
   * @param {string} customerId
   * @param {string} orderId
   * @param {number} refundAmount
   * @param {string} reason - Refund reason
   * @returns {Promise}
   */
  async sendRefundNotification(customerId, orderId, refundAmount, reason) {
    const firestore = db();

    try {
      const customerRef = firestore.collection('users').doc(customerId);
      const customerDoc = await customerRef.get();

      if (!customerDoc.exists) {
        throw new Error(`Customer ${customerId} not found`);
      }

      const customer = customerDoc.data();
      const customerEmail = customer.email;
      const customerName = customer.name || 'Valued Customer';

      const htmlContent = `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <style>
            body { font-family: Arial, sans-serif; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background: #8b5cf6; color: white; padding: 20px; border-radius: 8px 8px 0 0; }
            .content { background: #faf5ff; padding: 20px; border-radius: 0 0 8px 8px; }
            .amount { 
              font-size: 32px; 
              font-weight: bold; 
              color: #8b5cf6; 
              text-align: center; 
              margin: 20px 0;
            }
            .button { 
              display: inline-block; 
              background: #8b5cf6; 
              color: white; 
              padding: 12px 24px; 
              border-radius: 6px; 
              text-decoration: none; 
              margin-top: 20px;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1 style="margin: 0;">Refund Processed</h1>
              <p style="margin: 5px 0 0 0;">Order #${orderId.slice(-6)}</p>
            </div>
            
            <div class="content">
              <p>Hi ${customerName},</p>
              
              <p>We've processed a refund for your order:</p>
              
              <div class="amount">₹${refundAmount.toFixed(2)}</div>
              
              <p><strong>Reason:</strong> ${reason}</p>
              
              <p>The amount has been credited to your Fufaji wallet and will be available to use on your next order.</p>
              
              <a href="https://fufaji.app/wallet" class="button">View Wallet</a>
              
              <hr style="margin: 30px 0; border: none; border-top: 1px solid #ddd;">
              <p style="color: #666; font-size: 12px;">
                If you have any questions about this refund, please reach out to our support team.
              </p>
            </div>
          </div>
        </body>
        </html>
      `;

      const msg = {
        to: customerEmail,
        from: process.env.SENDGRID_FROM_EMAIL || 'shop@fufaji.com',
        subject: `Refund Processed: ₹${refundAmount.toFixed(2)}`,
        html: htmlContent,
        categories: ['refund_notification'],
      };

      await sgMail.send(msg);

      await this._logEmail(customerId, 'refund_notification', {
        orderId,
        recipient: customerEmail,
        amount: refundAmount,
        reason,
      });

      console.log(`[EmailService] Refund notification sent to ${customerEmail}`);

      return { success: true };
    } catch (error) {
      console.error('[EmailService] Error sending refund notification:', error.message);
      throw error;
    }
  }

  /**
   * Send review request email
   *
   * @param {string} customerId
   * @param {string} orderId
   * @returns {Promise}
   */
  async sendReviewRequest(customerId, orderId) {
    const firestore = db();

    try {
      const customerRef = firestore.collection('users').doc(customerId);
      const customerDoc = await customerRef.get();

      if (!customerDoc.exists) {
        throw new Error(`Customer ${customerId} not found`);
      }

      const customer = customerDoc.data();
      const customerEmail = customer.email;
      const customerName = customer.name || 'Valued Customer';

      const htmlContent = `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <style>
            body { font-family: Arial, sans-serif; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background: #f59e0b; color: white; padding: 20px; border-radius: 8px 8px 0 0; }
            .content { background: #fffbf0; padding: 20px; border-radius: 0 0 8px 8px; }
            .stars { 
              font-size: 28px; 
              text-align: center; 
              margin: 20px 0;
              letter-spacing: 10px;
            }
            .button { 
              display: inline-block; 
              background: #f59e0b; 
              color: white; 
              padding: 12px 24px; 
              border-radius: 6px; 
              text-decoration: none; 
              text-align: center;
              margin-top: 20px;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1 style="margin: 0;">How was your delivery?</h1>
            </div>
            
            <div class="content">
              <p>Hi ${customerName},</p>
              
              <p>We'd love to hear about your experience with your recent order.</p>
              
              <div class="stars">★ ★ ★ ★ ★</div>
              
              <p style="text-align: center;">
                <a href="https://fufaji.app/order/${orderId}/review?stars=5" class="button">
                  Share Your Feedback
                </a>
              </p>
              
              <p>Your reviews help us improve and assist other customers in making the right choices.</p>
              
              <div style="background: #fef3c7; border-left: 4px solid #f59e0b; padding: 15px; border-radius: 6px; margin: 20px 0;">
                <p style="margin: 0;"><strong>Bonus:</strong> Earn 50 reward points for every review you post!</p>
              </div>
              
              <hr style="margin: 30px 0; border: none; border-top: 1px solid #ddd;">
              <p style="color: #666; font-size: 12px;">
                Thank you for choosing Fufaji!
              </p>
            </div>
          </div>
        </body>
        </html>
      `;

      const msg = {
        to: customerEmail,
        from: process.env.SENDGRID_FROM_EMAIL || 'shop@fufaji.com',
        subject: 'Share Your Feedback & Earn Rewards',
        html: htmlContent,
        categories: ['review_request'],
      };

      await sgMail.send(msg);

      await this._logEmail(customerId, 'review_request', {
        orderId,
        recipient: customerEmail,
      });

      console.log(`[EmailService] Review request sent to ${customerEmail}`);

      return { success: true };
    } catch (error) {
      console.error('[EmailService] Error sending review request:', error.message);
      throw error;
    }
  }

  /**
   * Send weekly summary email
   *
   * @param {string} customerId
   * @param {object} summaryData - { totalOrders, totalSpent, favoriteItem, nextPromo }
   * @returns {Promise}
   */
  async sendWeeklySummary(customerId, summaryData) {
    const firestore = db();

    try {
      const customerRef = firestore.collection('users').doc(customerId);
      const customerDoc = await customerRef.get();

      if (!customerDoc.exists) {
        throw new Error(`Customer ${customerId} not found`);
      }

      const customer = customerDoc.data();
      const customerEmail = customer.email;
      const customerName = customer.name || 'Valued Customer';

      const htmlContent = `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <style>
            body { font-family: Arial, sans-serif; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background: #1e40af; color: white; padding: 20px; border-radius: 8px 8px 0 0; }
            .content { background: #f0f9ff; padding: 20px; border-radius: 0 0 8px 8px; }
            .stats { display: grid; grid-template-columns: 1fr 1fr; gap: 15px; margin: 20px 0; }
            .stat-box { background: white; padding: 15px; border-radius: 6px; border-left: 4px solid #1e40af; }
            .stat-value { font-size: 24px; font-weight: bold; color: #1e40af; }
            .stat-label { color: #666; font-size: 12px; margin-top: 5px; }
            .button { 
              display: inline-block; 
              background: #1e40af; 
              color: white; 
              padding: 12px 24px; 
              border-radius: 6px; 
              text-decoration: none; 
              margin-top: 20px;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1 style="margin: 0;">Your Weekly Summary</h1>
              <p style="margin: 5px 0 0 0;">Week of ${new Date().toLocaleDateString()}</p>
            </div>
            
            <div class="content">
              <p>Hi ${customerName},</p>
              
              <p>Here's a snapshot of your activity this week:</p>
              
              <div class="stats">
                <div class="stat-box">
                  <div class="stat-value">${summaryData.totalOrders}</div>
                  <div class="stat-label">Orders</div>
                </div>
                <div class="stat-box">
                  <div class="stat-value">₹${summaryData.totalSpent.toFixed(2)}</div>
                  <div class="stat-label">Spent</div>
                </div>
              </div>
              
              ${
                summaryData.favoriteItem
                  ? `
                <div style="background: white; padding: 15px; border-radius: 6px; margin: 20px 0;">
                  <p style="margin: 0;"><strong>Your Favorite:</strong> ${summaryData.favoriteItem}</p>
                </div>
              `
                  : ''
              }
              
              ${
                summaryData.nextPromo
                  ? `
                <div style="background: #fef3c7; border-left: 4px solid #f59e0b; padding: 15px; border-radius: 6px; margin: 20px 0;">
                  <p style="margin: 0;"><strong>Next Offer:</strong> ${summaryData.nextPromo}</p>
                </div>
              `
                  : ''
              }
              
              <a href="https://fufaji.app/orders" class="button">View All Orders</a>
              
              <hr style="margin: 30px 0; border: none; border-top: 1px solid #ddd;">
              <p style="color: #666; font-size: 12px;">
                See you next week!
              </p>
            </div>
          </div>
        </body>
        </html>
      `;

      const msg = {
        to: customerEmail,
        from: process.env.SENDGRID_FROM_EMAIL || 'shop@fufaji.com',
        subject: `Your Fufaji Weekly Summary - ${new Date().toLocaleDateString()}`,
        html: htmlContent,
        categories: ['weekly_summary'],
      };

      await sgMail.send(msg);

      await this._logEmail(customerId, 'weekly_summary', {
        recipient: customerEmail,
        stats: summaryData,
      });

      console.log(`[EmailService] Weekly summary sent to ${customerEmail}`);

      return { success: true };
    } catch (error) {
      console.error('[EmailService] Error sending weekly summary:', error.message);
      throw error;
    }
  }

  /**
   * Get email history for user
   *
   * @param {string} customerId
   * @param {number} limit
   * @returns {Promise<array>}
   */
  async getEmailHistory(customerId, limit = 50) {
    const firestore = db();

    try {
      const historyRef = firestore
        .collection('users')
        .doc(customerId)
        .collection('email_history')
        .orderBy('timestamp', 'desc')
        .limit(limit);

      const snapshot = await historyRef.get();
      const history = [];

      snapshot.forEach((doc) => {
        history.push({
          id: doc.id,
          ...doc.data(),
        });
      });

      return history;
    } catch (error) {
      console.error('[EmailService] Error fetching email history:', error.message);
      throw error;
    }
  }

  // ========== PRIVATE HELPERS ==========

  /**
   * Log email sent
   * @private
   */
  async _logEmail(customerId, type, details = {}) {
    const firestore = db();
    const FieldValue = admin.firestore.FieldValue;

    try {
      const historyRef = firestore
        .collection('users')
        .doc(customerId)
        .collection('email_history')
        .doc();

      await historyRef.set({
        type,
        ...details,
        timestamp: FieldValue.serverTimestamp(),
      });
    } catch (error) {
      console.error('[EmailService] Error logging email:', error.message);
    }
  }
}

module.exports = EmailService;
