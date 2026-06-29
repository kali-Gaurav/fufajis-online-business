# Launch Support Plan - Fufaji's Online

**Effective Date**: June 22, 2026
**Duration**: Phase 1 Launch (Week 1-4)

---

## 1. Support Strategy Overview

The support system must scale from 0 to 1000+ users in the first month while maintaining high customer satisfaction (>4.0 stars). This plan defines channels, response times, team structure, and escalation procedures.

**Primary Goals**:
- Resolve 90% of issues within 24 hours
- Maintain customer satisfaction > 4.0/5
- Reduce support tickets through proactive FAQs
- Empower customers to self-serve

---

## 2. Support Channels

### 2.1 Email Support (Primary)

**Address**: support@fufaji.com

**Features**:
- Professional, documented responses
- Good for complex issues
- Ticket tracking available
- Time to create permanent FAQ entries

**Response Times**:
- Critical (App crash, payment failure): < 1 hour
- High (Missing items, order issues): < 4 hours
- Medium (General questions): < 8 hours
- Low (Feature requests, feedback): < 24 hours

**Tools**:
- Gmail or Helpdesk software (e.g., Zendesk, HelpScout)
- Can start with shared Gmail inbox for simplicity

**Team**:
- Launch week: 1-2 dedicated support staff
- Monitoring: 9 AM - 9 PM IST (7 days/week for first 2 weeks)

---

### 2.2 In-App Chat (Secondary)

**Implementation**:
- Firebase Cloud Messaging or third-party chat service
- Available in app under Settings > Help

**Features**:
- Real-time chat with support team
- Quick response possible
- Good for urgent issues
- Context from order history available

**Response Times**:
- Critical: < 15 minutes
- Urgent: < 30 minutes
- Regular: < 1 hour
- Offline: Respond when online

**Team**:
- Initially: 1 person during business hours
- Monitor messages every 15 minutes
- Set auto-reply for after-hours

---

### 2.3 WhatsApp Support (Optional)

**Use Case**: Emergency escalations only

**Number**: [To be determined]

**Features**:
- Direct contact with support manager
- For P0 issues only
- Personal touch for angry customers

**Response Time**:
- < 30 minutes (if available)
- May not be 24/7 initially

**Team**: Support lead only

---

### 2.4 FAQ & Help Section (Proactive)

**Location**: In-app (Settings > Help & FAQ)

**Content**:
- Getting started guide
- Common troubleshooting
- FAQ document
- Video tutorials (future)

**Initial Topics**:
1. How to register and login
2. How to place an order
3. How to track my delivery
4. Payment methods and security
5. Refunds and returns
6. Loyalty program
7. How to refer friends
8. Privacy and data security

**Maintenance**:
- Update weekly with new FAQs from support tickets
- Review customer feedback for gaps

---

## 3. Support Team Structure

### Week 1-2: Core Team

| Role | Person | Availability | Responsibilities |
|------|--------|--------------|------------------|
| Support Lead | TBD | 24/7 (on-call) | Overall strategy, escalations, critical issues |
| Support Specialist | TBD | 9 AM - 9 PM IST, 7 days | Email, chat, FAQ updates |
| Backup Support | Marketing person | 4 PM - 9 PM IST | Coverage, spillover |

**Total Capacity**: ~100-150 emails/day during Week 1

### Week 3-4: Scaled Team

| Role | Person | Availability | Responsibilities |
|------|--------|--------------|------------------|
| Support Lead | TBD | 24/7 (on-call) | Overall strategy, escalations, critical issues |
| Support Specialist 1 | TBD | 9 AM - 6 PM IST, 7 days | Email, in-app chat |
| Support Specialist 2 | TBD | 5 PM - 12 AM IST, 7 days | Email, in-app chat, evening coverage |
| Backup/Escalation | Team lead | On-call | Critical issues only |

**Total Capacity**: ~300+ emails/day

---

## 4. Common Issues & Solutions

### Issue Category: Account & Login

**Q: I can't login to my account**

A: 
```
We're sorry you're having trouble logging in. Here are some steps:

1. Clear app cache (Settings > Apps > Fufaji > Storage > Clear Cache)
2. Restart your phone
3. Try logging in again
4. If OTP doesn't arrive, check:
   - Phone has internet connection
   - Check SMS inbox for OTP code
   - Wait 1-2 minutes for SMS
5. If still not working, please reply with:
   - Your registered phone number
   - Phone model and Android version
   
We'll help you get back in!

Note: For security, we'll verify your account before resetting.
```

**Q: How do I reset my password?**

A:
```
We use phone-based login for security. Here's how to regain access:

1. On login screen, tap "Trouble logging in?"
2. Enter your registered phone number
3. Verify with OTP sent to your phone
4. You're logged back in!

If you've changed your phone number, email us at support@fufaji.com 
with your old phone number and we can help.
```

---

### Issue Category: Orders & Delivery

**Q: My order hasn't arrived yet. It's been 1 hour!**

A:
```
We're sorry for the delay! Orders typically arrive in 30-45 minutes. 
Here's how to check status:

1. Open the app and go to "My Orders"
2. Tap your current order to see real-time tracking
3. You can see your rider's location on the map
4. If no rider is assigned yet, order may still be being packed

If your order is significantly delayed:
- Check if there are any messages from the rider
- Try contacting the rider via chat in the app
- If there's a real issue, contact us and we'll help resolve

Usually delivery will happen soon. Patience appreciated!
```

**Q: I received the wrong item / Items are missing**

A:
```
We apologize for the inconvenience. Here's how to get a refund:

1. Open the app and go to "My Orders"
2. Find the order with wrong/missing items
3. Tap "Request Return" 
4. Select the items that were wrong/missing
5. Submit the return request with photos if possible
6. Our team will verify within 24 hours
7. Once approved, you'll get a full refund to your Fufaji wallet

Alternatively:
- Email us a photo of the issue to support@fufaji.com
- Include your order number
- We'll process immediately

If you need the item urgently, we can often re-deliver the correct item 
on your next order with a discount!
```

---

### Issue Category: Payment

**Q: My payment failed. What do I do?**

A:
```
Payment failures can happen for several reasons. Here's what to do:

1. Check your bank/card balance and available limit
2. Verify your card details are entered correctly
3. Try a different payment method:
   - Use UPI instead of card
   - Try a different card if you have one
   - Use Fufaji wallet if you have credit

If all else fails:
- Restart the app
- Try again in 5 minutes (sometimes it's a temporary issue)
- If still failing, contact your bank to check for blocks
- Email us with your order number for support

We only charge you if the payment is successful, so you're safe!
```

**Q: My payment went through but I didn't receive ₹50 off**

A:
```
The ₹50 discount should apply automatically at checkout.

If it didn't:
1. Check your order confirmation - discount should be listed
2. If discount was applied but not shown on receipt, it's still credited
3. Check your Fufaji Wallet - you'll see any credits there

If still missing:
- Reply with your order number
- Tell us what discount code you used
- We'll manually credit ₹50 to your account immediately

We want to make sure you get every reward!
```

---

### Issue Category: Loyalty & Rewards

**Q: I'm not seeing my loyalty points**

A:
```
Loyalty points are added immediately after each order is delivered. 
Here's how to check:

1. Tap your profile icon (top left)
2. Scroll to "Loyalty Points"
3. You should see your current points

If points are missing:
- Points are added when order is DELIVERED (not when ordered)
- Wait for delivery to complete
- Refresh the app (pull down)
- Log out and back in

If still missing after delivery:
- Provide your order number
- We'll manually verify and add points within 24 hours
```

**Q: How do I use my loyalty points?**

A:
```
Great question! You can use points to get discounts:

1. Earn 1 point for every ₹1 spent
2. When you have 100+ points:
   - Go to Wallet in the app
   - Tap "Redeem Points"
   - Choose how many to redeem (minimum 100)
   - 100 points = ₹100 credit
3. Credit is instantly added to your Fufaji Wallet
4. Use it on your next order!

Also:
- Refer friends and get ₹25 per referral
- Complete tiers (Bronze → Silver → Gold) for extra benefits
```

---

### Issue Category: Referrals

**Q: How do I refer a friend?**

A:
```
Referrals are easy and rewarding!

Steps:
1. Open the app and go to "Account" > "Referral"
2. Tap "Share My Code"
3. You'll see your unique referral code
4. Share the code with friends via:
   - WhatsApp
   - Message
   - Email
   - Social media
5. When they download and enter your code, you BOTH get ₹25!

Unlimited referrals:
- Share as many times as you want
- Each referral = ₹25 for you
- Each friend also gets ₹25 on their first order

Make sure they enter your code during signup to get the credit!
```

---

### Issue Category: Technical Issues

**Q: The app keeps crashing**

A:
```
We're sorry for this frustration! Here are steps to fix:

1. Force stop the app:
   - Settings > Apps > Fufaji > Force Stop
2. Clear app cache:
   - Settings > Apps > Fufaji > Storage > Clear Cache
3. Restart your phone
4. Open the app again

If it still crashes:
5. Uninstall the app
6. Restart your phone again
7. Reinstall from Google Play Store

If crashes persist:
- Please email us with:
  - Your phone model
  - Android version (Settings > About Phone)
  - What you were doing when it crashed
- We can help or provide a workaround

Usually these steps fix it! Sorry for the trouble.
```

**Q: The app is very slow**

A:
```
Slow performance can have several causes:

1. Check your internet:
   - Switch between WiFi and mobile data
   - Check speed at speedtest.net
   - You need at least 2 Mbps

2. Free up phone space:
   - Go to Settings > Storage
   - Delete unused apps or media
   - Clear cached data

3. Force refresh the app:
   - Pull down at the top of the app to refresh
   - Close and reopen the app

4. Restart your phone

5. Update the app:
   - Open Google Play Store
   - Tap Menu > My Apps & Games
   - Update Fufaji if update available

If still slow, let us know:
- We can look at what's happening
- Usually it's a network issue on your end
```

---

## 5. Escalation Procedures

### Priority Levels & Escalation

| Priority | Definition | First Response | Resolution | Escalate To |
|----------|------------|-----------------|-----------|------------|
| **P0** | Critical - App unusable | < 15 min | < 1 hour | Engineering Lead |
| **P1** | High - Major feature broken | < 30 min | < 4 hours | Engineering Lead |
| **P2** | Medium - Workaround exists | < 2 hours | < 24 hours | Support Lead |
| **P3** | Low - Nice to fix | < 4 hours | < 48 hours | Support Staff |

### Escalation Decision Tree

```
┌─ Is the app completely broken?
│  └─ YES → P0 (Escalate immediately)
│  └─ NO → Next question
│
├─ Can the user complete their order/use the app at all?
│  └─ NO → P1 (Escalate within 30 min)
│  └─ YES → Next question
│
├─ Does this affect many users or just this one?
│  └─ MANY → P1 (Escalate, may be production bug)
│  └─ ONE → Next question
│
├─ Is there a workaround the user can use?
│  └─ YES → P2 (Escalate if workaround is complex)
│  └─ NO → P1 (Escalate)
│
└─ P3 (Respond within SLA, no immediate escalation)
```

### Escalation Template

When escalating to engineering, include:

```
ESCALATION: [P0/P1/P2]

Issue: [One-line summary]
User: [Name, phone number]
Order ID: [If applicable]
Reproduction Steps:
1. [Step 1]
2. [Step 2]
3. [Step 3]

Device: [Phone model, Android version]
App Version: [Version number]
Last Error: [Any error messages seen]

Expected Outcome: [What should happen]
Actual Outcome: [What's happening instead]

Timestamp: [When reported]
```

---

## 6. Issue Resolution Workflows

### Workflow: Missing Items Refund

```
User Reports → Support Verifies → Photo Check → Approve/Deny → 
Refund to Wallet → Confirmation Email
```

**Timeline**: 24-48 hours

**Process**:
1. Customer opens app > My Orders > Request Return
2. Selects missing items
3. Can upload photo evidence
4. Support team receives notification
5. Support verifies with shop owner
6. If valid: Approve return, credit ₹X to wallet
7. Customer gets notification + email with credit info
8. Follow-up email after 3 days asking about satisfaction

---

### Workflow: Payment Failure Recovery

```
Payment Fails → Notification to User → Support Retry Option → 
Success/Alternative Method Suggested → Confirmation
```

**Timeline**: Immediate to 4 hours

**Process**:
1. User attempts payment → Fails
2. User gets error message with troubleshooting steps
3. Option to retry or try different method
4. If user contacts support:
   - Check transaction logs
   - Verify no duplicate charges
   - Offer wallet credit if they want to wait for resolution
   - Help them retry with different method
5. Once order goes through: Confirmation email

---

### Workflow: Delivery Delay

```
Delay Reported → Real-Time Status Check → Rider Contact → 
ETA Update / Escalation → Resolution
```

**Timeline**: Varies (real-time tracking helps prevent escalations)

**Process**:
1. Customer sees delay (or proactively we alert them)
2. Support checks live tracking
3. If rider approaching: Reassure customer with ETA
4. If rider stuck: Try to contact via app
5. If no rider assigned: Order might still be packing
6. If > 60 min delay: Offer discount or send additional order credit
7. Follow-up: "How was your delivery experience?"

---

## 7. Feedback & Continuous Improvement

### Collecting Feedback

**In-App Survey** (shown after delivery):
```
How was your experience?
[1★] [2★] [3★] [4★] [5★]

Any comments?
[Text field]

Would you recommend Fufaji?
[Yes] [No] [Maybe]
```

**Feedback Sources**:
- In-app surveys
- Play Store reviews
- Email responses
- Support conversation tone
- Social media comments

### Feedback Analysis

**Weekly Review** (Friday):
- [ ] Summarize all feedback received
- [ ] Identify top 3 recurring issues
- [ ] Identify top 3 positive feedback points
- [ ] Assign to product/engineering if action needed
- [ ] Update FAQ with new learnings

**Example Issues to Track**:
- Payment failures (track rate)
- Delivery delays (track reasons)
- Missing/wrong items (track shop or pattern)
- App crashes (track on which flow)
- Unclear features (update onboarding)

### FAQ Update Cadence

- **Weekly**: Add 2-3 new FAQs based on support tickets
- **Bi-weekly**: Update existing FAQs based on feedback
- **Monthly**: Archive solved issues, refresh high-traffic topics

---

## 8. Customer Satisfaction Targets

### Week 1 Targets

| Metric | Target | Current |
|--------|--------|---------|
| Avg Response Time (Email) | < 4 hrs | TBD |
| Issue Resolution Rate | 80% | TBD |
| Customer Satisfaction | 4.0+ / 5 | TBD |
| Repeat Support Tickets | < 10% | TBD |
| App Store Rating | 4.0+ | TBD |

### Week 2-4 Targets

| Metric | Target | Current |
|--------|--------|---------|
| Avg Response Time (Email) | < 2 hrs | TBD |
| Issue Resolution Rate | 90% | TBD |
| Customer Satisfaction | 4.2+ / 5 | TBD |
| Repeat Support Tickets | < 5% | TBD |
| App Store Rating | 4.2+ | TBD |

---

## 9. Support Team Training

### Pre-Launch Training (June 21)

All support staff must complete:

- [ ] Product walkthrough (30 min)
  - How to use app as customer
  - How to use app as rider
  - Loyalty program mechanics
  
- [ ] Payment system training (20 min)
  - How Razorpay works
  - Common payment failures
  - Refund process
  
- [ ] Common issues review (30 min)
  - Review all issues in this document
  - Practice responses
  - Role-play difficult customers
  
- [ ] Escalation procedures (20 min)
  - When to escalate
  - How to document for engineering
  - Urgency levels
  
- [ ] Support systems (20 min)
  - Email system
  - In-app chat
  - Knowledge base
  - Ticket tracking

**Total**: ~2 hours per person

---

## 10. Communication Templates

### Template: Issue Resolved

```
Hi [Name],

Great news! We've resolved your issue.

[Brief explanation of what was wrong]

[Solution provided]

Your [refund/credit/replacement] has been processed and should 
appear in your account within [timeframe].

Thank you for your patience, and we're sorry for the inconvenience.

If you have any other questions, just reply to this email.

Best regards,
Fufaji Support Team
```

### Template: Further Investigation Needed

```
Hi [Name],

Thanks for reaching out. We're looking into your issue.

We need a bit more information:
1. [Question 1]
2. [Question 2]
3. [Question 3]

Once we have these details, we should be able to resolve this 
within [24-48 hours].

Reply with the info and we'll get back to you shortly!

Thanks,
Fufaji Support Team
```

### Template: Feature Request / Feedback

```
Hi [Name],

Thanks for the suggestion! We really appreciate feedback like this.

We've documented your feature request and will consider it for 
future releases.

In the meantime, [workaround if applicable].

Keep the suggestions coming!

Best regards,
Fufaji Support Team
```

---

## 11. Knowledge Base Structure

**Categories**:
1. Getting Started
2. Account & Profile
3. Browsing & Shopping
4. Checkout & Payment
5. Orders & Delivery
6. Returns & Refunds
7. Loyalty Program
8. Referrals
9. App Troubleshooting
10. Privacy & Security

**Each Article Should Include**:
- Clear title
- Problem statement
- Step-by-step solution
- Screenshots (when helpful)
- Related topics
- Link to contact support if not resolved

---

## 12. Escalation Contacts

### Engineering Team (For P0/P1 Bugs)

**Contact**: engineering@fufaji.com or Slack #urgent-support

**On-Call Developer**: [Name & Phone]

**Response Time**: < 15 min for P0, < 30 min for P1

### Operations Team (For Delivery/Shop Issues)

**Contact**: ops@fufaji.com or Slack #support-escalations

**On-Call Operations**: [Name & Phone]

**Response Time**: < 30 min

### Finance Team (For Payment/Refund Issues)

**Contact**: finance@fufaji.com

**Response Time**: < 1 hour

---

## 13. Support Metrics Dashboard

**Daily Tracking**:
- Total tickets received
- Tickets resolved
- Average response time
- Average resolution time
- Customer satisfaction rating
- Escalations to engineering
- Top 5 issues

**Tools for Tracking**:
- Google Sheet (manual entry)
- Gmail labels/filters
- Analytics scripts (if using help desk software)

**Dashboard Template**:
```
DATE: June 22, 2026
TOTAL TICKETS: 15
RESOLVED: 12 (80%)
AVG RESPONSE TIME: 45 minutes
AVG RESOLUTION TIME: 2.5 hours
SATISFACTION: 4.2/5
ESCALATIONS: 2 (P1: App crash)

TOP ISSUES:
1. Order tracking questions (5 tickets)
2. First-order discount not applying (3 tickets)
3. App startup crashes (2 tickets)
4. Payment method not working (2 tickets)
5. Loyalty points not updating (2 tickets)

ACTIONS TAKEN:
- Updated FAQ with order tracking steps
- Engineering fixed app crash, deploying hotfix
- Tested payment methods with all banks
```

---

## 14. Measuring Support Quality

### NPS Score (Monthly)

Email sent to random sample of 50 recent customers:

```
How likely are you to recommend Fufaji to a friend?
[0] [1] [2] [3] [4] [5] [6] [7] [8] [9] [10]

Comments: [Text field]
```

**Scoring**:
- 9-10 = Promoter
- 7-8 = Passive
- 0-6 = Detractor

**Target NPS**: 40+ (considered good for new startups)

---

## 15. Support Handover Plan

### If Support Lead is Unavailable

1. Backup person takes over
2. Check email and in-app messages first thing
3. Prioritize P0/P1 issues
4. Respond to P0 immediately
5. Escalate to engineering if needed
6. Document all actions taken
7. Brief main support lead when they return

---

**Document Status**: Ready for Launch
**Last Updated**: June 22, 2026
**Review Cycle**: Weekly during first month
