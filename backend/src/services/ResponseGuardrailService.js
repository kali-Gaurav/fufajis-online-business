/**
 * ResponseGuardrailService.js
 * Sanitizes all bot-generated support replies. Ensures the bot never promises
 * refund approval, free items, or overrides store policies automatically.
 */

class ResponseGuardrailService {
  /**
   * Validate and sanitize bot reply
   * @param {string} rawReply - The raw output from the LLM
   * @returns {Object} - { sanitizedReply, guardrailTriggered, violations }
   */
  static sanitizeResponse(rawReply) {
    const replyLower = rawReply.toLowerCase();
    let sanitizedReply = rawReply;
    let guardrailTriggered = false;
    const violations = [];

    // Define forbidden promise patterns and their replacement messages
    const rules = [
      {
        pattern: /(refund\s+(is\s+)?(approved|processed|completed|done|ok|given))|(paise\s+(wapas|refund)\s+(ho\s+gaye|mil\s+gaye))/i,
        replacement: 'Aapka refund request log kar diya gaya hai aur humare store manager iski janch kar rahe hain. Standard processing time 3-5 working days hai.',
        reason: 'Unauthorized refund approval promise.'
      },
      {
        pattern: /(free\s+(order|delivery|item|coupon|voucher|gift|shipping))|((order|delivery|item|coupon|voucher|gift|shipping)\s+free)|(muft\s+ka\s+order|gift\s+milega)/i,
        replacement: 'Humare pass transparent pricing hai aur koi hidden or free gimmicks nahi hain. Hum aapko behtareen quality aur rates ensure karenge. (Security Guardrail: Reply sanitized to match pricing promise).',
        reason: 'Unauthorized free goods/compensations promise.'
      },
      {
        pattern: /(instantly\s+refunded|turant\s+paise\s+milenge)/i,
        replacement: 'Refund processing me 3 se 5 working days ka samay lagta hai. Kripaya thoda dhyan rakhein.',
        reason: 'Incorrect instant refund guarantee.'
      }
    ];

    // Check each pattern and replace if found
    for (const rule of rules) {
      if (rule.pattern.test(replyLower)) {
        guardrailTriggered = true;
        violations.push(rule.reason);
        console.warn(`[ResponseGuardrail] Violated rule: ${rule.reason}`);
        
        // We replace the matched sentence or the entire response with the policy-compliant alternative
        // To be safe, we substitute the compliant text directly
        sanitizedReply = rule.replacement;
        break; // Stop at first trigger to avoid mixed outputs
      }
    }

    return {
      sanitizedReply,
      guardrailTriggered,
      violations
    };
  }
}

module.exports = ResponseGuardrailService;
