/**
 * ═══════════════════════════════════════════════════════════════════════
 * AUTOMATION / WORKFLOW RULES ENGINE
 * ═══════════════════════════════════════════════════════════════════════
 *
 * A lightweight, admin-configurable "if this happens, then do that" engine.
 * Owners create rules in the `automation_rules` Firestore collection via the
 * AutomationRulesScreen (Flutter). Each rule has:
 *
 *   {
 *     name: string,
 *     description: string,
 *     enabled: bool,
 *     trigger: { type: 'order_status_changed' | 'low_stock' | 'cart_abandoned'
 *                     | 'customer_inactive' | 'order_delayed',
 *                config: { ...trigger-specific options } },
 *     conditions: [ { field: 'status', operator: '==', value: 'delivered' }, ... ],
 *     actions: [ { type: 'send_push' | 'send_email' | 'apply_coupon'
 *                       | 'add_user_tag' | 'notify_owner',
 *                  config: { ...action-specific options, supports {{field}} templating } },
 *                ... ],
 *     stats: { triggeredCount: number, lastTriggeredAt: Timestamp },
 *   }
 *
 * Two integration points exist:
 *  1. `runAutomationRules(triggerType, eventData)` — called synchronously
 *     from existing Firestore triggers (e.g. onOrderUpdate, lowStockAlerts)
 *     to evaluate "event" style rules.
 *  2. `checkTimeBasedAutomationRules` — an hourly scheduled function that
 *     evaluates "time" style rules (cart_abandoned, customer_inactive),
 *     which don't have a natural Firestore-write trigger.
 *
 * This module is intentionally additive: it never throws out of
 * `runAutomationRules`, so a misconfigured rule can never break the
 * order/notification flow that called it.
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

function db() {
    return admin.firestore();
}

/**
 * Read a dot-path value out of a plain object, e.g. getPath({a:{b:1}}, 'a.b') -> 1
 */
function getPath(obj, path) {
    if (!obj || !path) return undefined;
    return path.split('.').reduce((acc, key) => (acc == null ? undefined : acc[key]), obj);
}

/**
 * Evaluate a single condition against the event data.
 */
function evaluateCondition(condition, eventData) {
    const { field, operator, value } = condition || {};
    if (!field || !operator) return true; // malformed condition -> don't block the rule

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

/**
 * Replace {{field.path}} placeholders in a string with values from eventData.
 */
function renderTemplate(template, eventData) {
    if (typeof template !== 'string') return template;
    return template.replace(/\{\{\s*([\w.]+)\s*\}\}/g, (match, path) => {
        const val = getPath(eventData, path);
        return val === undefined || val === null ? '' : String(val);
    });
}

// ─── ACTION HANDLERS ────────────────────────────────────────────────────

/**
 * send_push: queue a push + in-app notification for a user.
 * config: { title, body, userField (default 'customerId' / falls back to 'userId') }
 */
async function actionSendPush(config, eventData) {
    const userId = getPath(eventData, config.userField || 'customerId') || getPath(eventData, 'userId');
    if (!userId) {
        console.warn('[AutomationEngine] send_push: no userId resolved from event data');
        return;
    }

    const userDoc = await db().collection('users').doc(userId).get();
    const fcmToken = userDoc.exists ? userDoc.data().fcmToken : null;

    const title = renderTemplate(config.title || 'Fufaji Update', eventData);
    const body = renderTemplate(config.body || '', eventData);

    // Queue via notification_queue so existing processNotificationQueue handles delivery + fallback.
    await db().collection('notification_queue').add({
        userId,
        fcmToken: fcmToken || null,
        title,
        body,
        type: 'automation',
        orderId: getPath(eventData, 'orderId') || '',
        source: 'automation_rule',
        status: 'pending',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Always also write an in-app notification, even if FCM delivery fails later.
    await db().collection('users').doc(userId).collection('notifications').add({
        title,
        body,
        type: 'automation',
        read: false,
        source: 'automation_rule',
        data: { orderId: getPath(eventData, 'orderId') || '' },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
}

/**
 * send_email: send a transactional email via SendGrid (best-effort).
 * config: { subject, html, userField, emailField (default 'email') }
 */
async function actionSendEmail(config, eventData, deps) {
    let to = getPath(eventData, config.emailField || 'email');

    if (!to) {
        const userId = getPath(eventData, config.userField || 'customerId') || getPath(eventData, 'userId');
        if (userId) {
            const userDoc = await db().collection('users').doc(userId).get();
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

/**
 * apply_coupon: write a personalized coupon doc for the user.
 * config: { codePrefix, discountPercent, discountFlat, expiryDays, userField }
 */
async function actionApplyCoupon(config, eventData) {
    const userId = getPath(eventData, config.userField || 'customerId') || getPath(eventData, 'userId');
    if (!userId) {
        console.warn('[AutomationEngine] apply_coupon: no userId resolved from event data');
        return;
    }

    const expiryDays = Number(config.expiryDays) || 7;
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + expiryDays);

    const codePrefix = config.codePrefix || 'AUTO';
    const code = `${codePrefix}-${userId.substring(0, 6).toUpperCase()}-${Date.now().toString(36).toUpperCase()}`;

    await db().collection('coupons').add({
        code,
        userId,
        discountPercent: config.discountPercent ?? null,
        discountFlat: config.discountFlat ?? null,
        source: 'automation_rule',
        status: 'active',
        expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
}

/**
 * add_user_tag: append a tag to users/{uid}.tags (used for later segmentation).
 * config: { tag, userField }
 */
async function actionAddUserTag(config, eventData) {
    const userId = getPath(eventData, config.userField || 'customerId') || getPath(eventData, 'userId');
    if (!userId || !config.tag) return;

    await db().collection('users').doc(userId).update({
        tags: admin.firestore.FieldValue.arrayUnion(config.tag),
    });
}

/**
 * notify_owner: write an alert doc + push to owner/manager roles.
 * config: { title, body }
 */
async function actionNotifyOwner(config, eventData) {
    const title = renderTemplate(config.title || 'Automation Alert', eventData);
    const body = renderTemplate(config.body || '', eventData);

    await db().collection('alerts').add({
        type: 'automation_rule',
        title,
        message: body,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        isRead: false,
    });

    const staffSnap = await db().collection('users')
        .where('role', 'in', ['UserRole.owner', 'UserRole.manager'])
        .get();

    const tokens = [];
    staffSnap.forEach((doc) => {
        const t = doc.data().fcmToken;
        if (t) tokens.push(t);
    });

    if (tokens.length > 0) {
        await admin.messaging().sendMulticast({
            tokens,
            notification: { title, body },
            data: { type: 'automation_alert' },
        });
    }
}

const ACTION_HANDLERS = {
    send_push: actionSendPush,
    send_email: actionSendEmail,
    apply_coupon: actionApplyCoupon,
    add_user_tag: actionAddUserTag,
    notify_owner: actionNotifyOwner,
};

/**
 * Execute every action in a rule, logging failures per-action without
 * aborting the remaining actions.
 */
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

/**
 * Main entry point: evaluate and run all enabled rules for a given trigger
 * type against the supplied event data. Never throws.
 *
 * @param {string} triggerType - e.g. 'order_status_changed', 'low_stock'
 * @param {object} eventData - flat-ish object the conditions/templates read from
 * @param {object} [deps] - injectable deps (for sendEmailViaSendGrid reuse); optional
 */
async function runAutomationRules(triggerType, eventData, deps = {}) {
    try {
        const snap = await db().collection('automation_rules')
            .where('enabled', '==', true)
            .where('trigger.type', '==', triggerType)
            .get();

        if (snap.empty) return;

        // Lazily resolve sendEmailViaSendGrid if not injected, to avoid a
        // hard circular require with index.js.
        const resolvedDeps = {
            sendEmailViaSendGrid: deps.sendEmailViaSendGrid || (async () => {
                console.warn('[AutomationEngine] sendEmailViaSendGrid not provided; skipping send_email action.');
            }),
        };

        for (const doc of snap.docs) {
            const rule = doc.data();

            // Optional trigger-level config matching (e.g. specific status / severity).
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

            await doc.ref.update({
                'stats.triggeredCount': admin.firestore.FieldValue.increment(1),
                'stats.lastTriggeredAt': admin.firestore.FieldValue.serverTimestamp(),
            }).catch((e) => console.error('[AutomationEngine] Failed to update rule stats:', e.message));

            await db().collection('automation_rule_logs').add({
                ruleId: doc.id,
                ruleName: rule.name || '',
                triggerType,
                eventSummary: JSON.stringify(eventData).slice(0, 1000),
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            }).catch((e) => console.error('[AutomationEngine] Failed to write rule log:', e.message));
        }
    } catch (e) {
        console.error(`[AutomationEngine] runAutomationRules('${triggerType}') failed:`, e.message);
    }
}

// ─── TIME-BASED TRIGGERS ────────────────────────────────────────────────

/**
 * Hourly scan for rules whose trigger has no natural Firestore-write hook:
 *  - cart_abandoned: cart not updated for trigger.config.hours (default 3)
 *  - customer_inactive: user.lastOrderAt older than trigger.config.days (default 14)
 */
exports.checkTimeBasedAutomationRules = functions.pubsub
    .schedule('every 60 minutes')
    .onRun(async () => {
        try {
            const rulesSnap = await db().collection('automation_rules')
                .where('enabled', '==', true)
                .where('trigger.type', 'in', ['cart_abandoned', 'customer_inactive'])
                .get();

            if (rulesSnap.empty) return null;

            for (const ruleDoc of rulesSnap.docs) {
                const rule = ruleDoc.data();
                const triggerType = rule.trigger.type;
                const triggerConfig = rule.trigger?.config || {};

                if (triggerType === 'cart_abandoned') {
                    const hours = Number(triggerConfig.hours) || 3;
                    const cutoff = new Date(Date.now() - hours * 60 * 60 * 1000);

                    let cartsSnap;
                    try {
                        cartsSnap = await db().collection('carts')
                            .where('updatedAt', '<=', admin.firestore.Timestamp.fromDate(cutoff))
                            .where('status', '==', 'active')
                            .limit(50)
                            .get();
                    } catch (e) {
                        // 'carts' collection may not exist in all deployments - skip quietly.
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

                        await executeActions(rule.actions, eventData, {});
                        await cartDoc.ref.update({ automationLastNotifiedAt: admin.firestore.FieldValue.serverTimestamp() }).catch(() => {});

                        await ruleDoc.ref.update({
                            'stats.triggeredCount': admin.firestore.FieldValue.increment(1),
                            'stats.lastTriggeredAt': admin.firestore.FieldValue.serverTimestamp(),
                        }).catch(() => {});
                    }
                }

                if (triggerType === 'customer_inactive') {
                    const days = Number(triggerConfig.days) || 14;
                    const cutoff = new Date(Date.now() - days * 24 * 60 * 60 * 1000);

                    const usersSnap = await db().collection('users')
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

                        await executeActions(rule.actions, eventData, {});
                        await userDoc.ref.update({ automationLastNotifiedAt: admin.firestore.FieldValue.serverTimestamp() }).catch(() => {});

                        await ruleDoc.ref.update({
                            'stats.triggeredCount': admin.firestore.FieldValue.increment(1),
                            'stats.lastTriggeredAt': admin.firestore.FieldValue.serverTimestamp(),
                        }).catch(() => {});
                    }
                }
            }
        } catch (e) {
            console.error('[AutomationEngine] checkTimeBasedAutomationRules failed:', e.message);
        }
        return null;
    });

exports.runAutomationRules = runAutomationRules;
exports.evaluateConditions = evaluateConditions;
exports.renderTemplate = renderTemplate;
