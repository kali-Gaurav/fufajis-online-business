const express = require('express');
const router = express.Router();
const secrets = require('../secrets');
const { verifyToken, requireRole } = require('../auth');

router.post(
  '/rider',
  verifyToken,
  requireRole('UserRole.admin', 'UserRole.shopOwner'),
  async (req, res) => {
    try {
      const { riderAccountId, amount, currency } = req.body || {};

      if (!riderAccountId || !amount) {
        return res.status(400).json({
          success: false,
          error: 'Missing required parameters: riderAccountId, amount'
        });
      }

      console.log(`Initiating secure transfer of ₹${amount} to Razorpay account: ${riderAccountId}`);

      const keyId = secrets.get('razorpay/key_id') || process.env.RAZORPAY_KEY_ID;
      const keySecret = secrets.get('razorpay/key_secret');

      if (!keyId || !keySecret) {
        return res.status(500).json({
          success: false,
          error: 'Razorpay is not configured with key_id or key_secret on the backend.'
        });
      }

      const auth = Buffer.from(`${keyId}:${keySecret}`).toString('base64');
      const postData = JSON.stringify({
        account: riderAccountId,
        amount: Math.round(amount * 100), // convert to paise
        currency: currency || 'INR',
        notes: {
          info: 'Rider Payout Transfer via Route API'
        }
      });

      const https = require('https');
      const result = await new Promise((resolve, reject) => {
        const r = https.request(
          {
            hostname: 'api.razorpay.com',
            port: 443,
            path: '/v1/transfers',
            method: 'POST',
            headers: {
              'Authorization': `Basic ${auth}`,
              'Content-Type': 'application/json',
              'Content-Length': Buffer.byteLength(postData)
            }
          },
          (response) => {
            let responseBody = '';
            response.on('data', (chunk) => (responseBody += chunk));
            response.on('end', () => {
              try {
                resolve({ statusCode: response.statusCode, body: JSON.parse(responseBody) });
              } catch (e) {
                resolve({ statusCode: response.statusCode, body: responseBody });
              }
            });
          }
        );

        r.on('error', (err) => reject(err));
        r.write(postData);
        r.end();
      });

      if (result.statusCode >= 200 && result.statusCode < 300) {
        console.log(`Rider payout transfer successful: ${result.body.id}`);
        return res.json({
          success: true,
          transferId: result.body.id,
          message: 'Transfer processed successfully via Razorpay Route API'
        });
      } else {
        console.error('Razorpay Route Transfer Error Response:', result.body);
        const errDescription =
          result.body && result.body.error ? result.body.error.description : 'Failed to process payout';
        return res.json({
          success: false,
          error: errDescription,
          message: errDescription
        });
      }
    } catch (error) {
      console.error('Error initiating rider payout:', error);
      return res.status(500).json({
        success: false,
        error: 'Failed to process payout: ' + error.message
      });
    }
  }
);

module.exports = router;
