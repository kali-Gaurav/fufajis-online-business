const { admin } = require('../firestore');

function getPath(obj, path) {
  if (!obj || !path) return undefined;
  return path.split('.').reduce((acc, key) => (acc == null ? undefined : acc[key]), obj);
}

function evaluateCondition(condition, eventData) {
  const { field, operator, value } = condition || {};
  if (!field || !operator) return true;

  const actual = getPath(eventData, field);

  switch (operator) {
    case '==':
      // eslint-disable-next-line eqeqeq
      return actual == value;
    case '!=':
      // eslint-disable-next-line eqeqeq
      return actual != value;
    case '>':
      return Number(actual) > Number(value);
    case '>=':
      return Number(actual) >= Number(value);
    case '<':
      return Number(actual) < Number(value);
    case '<=':
      return Number(actual) <= Number(value);
    case 'contains':
      if (Array.isArray(actual)) return actual.includes(value);
      return String(actual ?? '').toLowerCase().includes(String(value ?? '').toLowerCase());
    case 'exists':
      return actual !== undefined && actual !== null;
    case 'not_exists':
      return actual === undefined || actual === null;
    default:
      return true;
  }
}

function evaluateConditions(conditions, eventData) {
  if (!Array.isArray(conditions) || conditions.length === 0) return true;
  return conditions.every((c) => evaluateCondition(c, eventData));
}

function renderTemplate(template, eventData) {
  if (typeof template !== 'string') return template;
  return template.replace(/\{\{\s*([\w.]+)\s*\}\}/g, (match, path) => {
    const val = getPath(eventData, path);
    return val === undefined || val === null ? '' : String(val);
  });
}

// ── Action Handlers ─────────────────────────────────────────────────────────

async function actionSendPush(config, eventData) {
  const db = admin.firestore();
  const userId = getPath(eventData, config.userField || 'customerId') || getPath(eventData, 'userId');
  if (!userId) {
    console.warn('[AutomationEngine] send_push: no userId resolved');
    return;
  }

  const userDoc = await db.collection('users').doc(userId).get();
  const fcmToken = userDoc.exists ? userDoc.data().fcmToken : null;

  const title = renderTemplate(config.title || 'Fufaji Update', eventData);
  const body = renderTemplate(config.body || '', eventData);

  await db.collection('notification_queue').add({
    userId,
    fcmToken: fcmToken || null,
    title,
    body,
    type: 'automation',
    orderId: getPath(eventData, 'orderId') || '',
    source: 'automation_rule',
    status: 'pending',
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });

  await db.collection('users').doc(userId).collection('notifications').add({
    title,
    body,
    type: 'automation',
    read: false,
    source: 'automation_rule',
    data: { orderId: getPath(eventData, 'orderId') || '' },
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });
}

async function actionSendEmail(config, eventData, deps) {
  const db = admin.firestore();
  let to = getPath(eventData, config.emailField || 'email');

  if (!to) {
    const userId = getPath(eventData, config.userField || 'customerId') || getPath(eventData, 'userId');
    if (userId) {
      const userDoc = await db.collection('users').doc(userId).get();
      to = userDoc.exists ? userDoc.data().email : null;
    }
  }

  if (!to) {
    console.warn('[AutomationEngine] send_email: no recipient email resolved');
    return;
  }

  const subject = renderTemplate(config.subject || 'Fufaji Update', eventData);
  const html = renderTemplate(config.html || `<p>${config.body || ''}</p>`, eventData);

  try {
    await deps.sendEmailViaSendGrid({ to, subject, html, categories: ['automation_rule'] });
  } catch (e) {
    console.error('[AutomationEngine] send_email failed:', e.message);
  }
}

async function actionApplyCoupon(config, eventData) {
  const db = admin.firestore();
  const userId = getPath(eventData, config.userField || 'customerId') || getPath(eventData, 'userId');
  if (!userId) {
    console.warn('[AutomationEngine] apply_coupon: no userId resolved');
    return;
  }

  const expiryDays = Number(config.expiryDays) || 7;
  const expiresAt = new Date();
  expiresAt.setDate(expiresAt.getDate() + expiryDays);

  const codePrefix = config.codePrefix || 'AUTO';
  const code = `${codePrefix}-${userId.substring(0, 6).toUpperCase()}-${Date.now().toString(36).toUpperCase()}`;

  await db.collection('coupons').add({
    code,
    userId,
    discountPercent: config.discountPercent ?? null,
    discountFlat: config.discountFlat ?? null,
    source: 'automation_rule',
    status: 'active',
    expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });
}

async function actionAddUserTag(config, eventData) {
  const db = admin.firestore();
  const userId = getPath(eventData, config.userField || 'customerId') || getPath(eventData, 'userId');
  if (!userId || !config.tag) return;

  await db.collection('users').doc(userId).update({
    tags: admin.firestore.FieldValue.arrayUnion(config.tag)
  });
}

async function actionNotifyOwner(config, eventData) {
  const db = admin.firestore();
  const title = renderTemplate(config.title || 'Automation Alert', eventData);
  const body = renderTemplate(config.body || '', eventData);

  await db.collection('alerts').add({
    type: 'automation_rule',
    title,
    message: body,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    isRead: false
  });

  const staffSnap = await db.collection('users').where('role', 'in', ['UserRole.owner', 'UserRole.manager']).get();

  const tokens = [];
  staffSnap.forEach((doc) => {
    const t = doc.data().fcmToken;
    if (t) tokens.push(t);
  });

  if (tokens.length > 0) {
    const messages = tokens.map((token) => ({
      token,
      notification: { title, body },
      data: { type: 'automation_alert' }
    }));
    await Promise.all(messages.map((msg) => admin.messaging().send(msg).catch(() => {})));
  }
}

const ACTION_HANDLERS = {
  send_push: actionSendPush,
  send_email: actionSendEmail,
  apply_coupon: actionApplyCoupon,
  add_user_tag: actionAddUserTag,
  notify_owner: actionNotifyOwner
};

async function executeActions(actions, eventData, deps) {
  if (!Array.isArray(actions)) return;
  for (const action of actions) {
    const handler = ACTION_HANDLERS[action?.type];
    if (!handler) {
      console.warn(`[AutomationEngine] Unknown action type: ${action?.type}`);
      continue;
    }
    try {
      await handler(action.config || {}, eventData, deps);
    } catch (e) {
      console.error(`[AutomationEngine] Action '${action.type}' failed:`, e.message);
    }
  }
}

// ── Main Callable Engine ───────────────────────────────────────────────────

async function runAutomationRules(triggerType, eventData, deps = {}) {
  try {
    const db = admin.firestore();
    const snap = await db
      .collection('automation_rules')
      .where('enabled', '==', true)
      .where('trigger.type', '==', triggerType)
      .get();

    if (snap.empty) return;

    const resolvedDeps = {
      sendEmailViaSendGrid:
        deps.sendEmailViaSendGrid ||
        (async (opts) => {
          try {
            const { sendEmailViaSendGrid } = require('../jobs');
            await sendEmailViaSendGrid(opts);
          } catch (e) {
            console.warn('[AutomationEngine] sendEmailViaSendGrid not available; skipping send_email action.');
          }
        })
    };

    for (const doc of snap.docs) {
      const rule = doc.data();

      const triggerConfig = rule.trigger?.config || {};
      if (triggerConfig.status && triggerConfig.status !== '*' && triggerConfig.status !== getPath(eventData, 'status')) {
        continue;
      }
      if (triggerConfig.severity && triggerConfig.severity !== '*' && triggerConfig.severity !== getPath(eventData, 'severity')) {
        continue;
      }

      if (!evaluateConditions(rule.conditions, eventData)) continue;

      console.log(`[AutomationEngine] Rule "${rule.name}" (${doc.id}) matched for trigger '${triggerType}'`);

      await executeActions(rule.actions, eventData, resolvedDeps);

      await doc.ref
        .update({
          'stats.triggeredCount': admin.firestore.FieldValue.increment(1),
          'stats.lastTriggeredAt': admin.firestore.FieldValue.serverTimestamp()
        })
        .catch((e) => console.error('[AutomationEngine] Failed to update rule stats:', e.message));

      await db
        .collection('automation_rule_logs')
        .add({
          ruleId: doc.id,
          ruleName: rule.name || '',
          triggerType,
          eventSummary: JSON.stringify(eventData).slice(0, 1000),
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        })
        .catch((e) => console.error('[AutomationEngine] Failed to write rule log:', e.message));
    }
  } catch (e) {
    console.error(`[AutomationEngine] runAutomationRules('${triggerType}') failed:`, e.message);
  }
}

// ── Time-Based Cron Engine ─────────────────────────────────────────────────

async function checkTimeBasedAutomationRules(db) {
  try {
    const rulesSnap = await db
      .collection('automation_rules')
      .where('enabled', '==', true)
      .where('trigger.type', 'in', ['cart_abandoned', 'customer_inactive'])
      .get();

    if (rulesSnap.empty) return null;

    const resolvedDeps = {
      sendEmailViaSendGrid: async (opts) => {
        try {
          const { sendEmailViaSendGrid } = require('../jobs');
          await sendEmailViaSendGrid(opts);
        } catch (e) {
          console.warn('[AutomationEngine] sendEmailViaSendGrid failed to load.');
        }
      }
    };

    for (const ruleDoc of rulesSnap.docs) {
      const rule = ruleDoc.data();
      const triggerType = rule.trigger.type;
      const triggerConfig = rule.trigger?.config || {};

      if (triggerType === 'cart_abandoned') {
        const hours = Number(triggerConfig.hours) || 3;
        const cutoff = new Date(Date.now() - hours * 60 * 60 * 1000);

        let cartsSnap;
        try {
          cartsSnap = await db
            .collection('carts')
            .where('updatedAt', '<=', admin.firestore.Timestamp.fromDate(cutoff))
            .where('status', '==', 'active')
            .limit(50)
            .get();
        } catch (e) {
          // carts collection might not exist in all deployments
          continue;
        }

        for (const cartDoc of cartsSnap.docs) {
          const cart = cartDoc.data();
          if (cart.automationLastNotifiedAt) {
            const last = cart.automationLastNotifiedAt.toDate();
            if (Date.now() - last.getTime() < hours * 60 * 60 * 1000) continue;
          }

          const eventData = { ...cart, cartId: cartDoc.id, userId: cart.userId || cart.customerId };
          if (!evaluateConditions(rule.conditions, eventData)) continue;

          await executeActions(rule.actions, eventData, resolvedDeps);
          await cartDoc.ref
            .update({ automationLastNotifiedAt: admin.firestore.FieldValue.serverTimestamp() })
            .catch(() => {});

          await ruleDoc.ref
            .update({
              'stats.triggeredCount': admin.firestore.FieldValue.increment(1),
              'stats.lastTriggeredAt': admin.firestore.FieldValue.serverTimestamp()
            })
            .catch(() => {});
        }
      }

      if (triggerType === 'customer_inactive') {
        const days = Number(triggerConfig.days) || 14;
        const cutoff = new Date(Date.now() - days * 24 * 60 * 60 * 1000);

        const usersSnap = await db
          .collection('users')
          .where('role', '==', 'UserRole.customer')
          .where('lastOrderAt', '<=', admin.firestore.Timestamp.fromDate(cutoff))
          .limit(50)
          .get();

        for (const userDoc of usersSnap.docs) {
          const user = userDoc.data();
          if (user.automationLastNotifiedAt) {
            const last = user.automationLastNotifiedAt.toDate();
            if (Date.now() - last.getTime() < days * 24 * 60 * 60 * 1000) continue;
          }

          const eventData = { ...user, userId: userDoc.id, customerId: userDoc.id };
          if (!evaluateConditions(rule.conditions, eventData)) continue;

          await executeActions(rule.actions, eventData, resolvedDeps);
          await userDoc.ref
            .update({ automationLastNotifiedAt: admin.firestore.FieldValue.serverTimestamp() })
            .catch(() => {});

          await ruleDoc.ref
            .update({
              'stats.triggeredCount': admin.firestore.FieldValue.increment(1),
              'stats.lastTriggeredAt': admin.firestore.FieldValue.serverTimestamp()
            })
            .catch(() => {});
        }
      }
    }
  } catch (e) {
    console.error('[AutomationEngine] checkTimeBasedAutomationRules failed:', e.message);
  }
}

module.exports = {
  runAutomationRules,
  checkTimeBasedAutomationRules
};
