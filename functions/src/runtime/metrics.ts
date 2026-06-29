// ============================================================
//  Mission Control - deterministic business metrics
//
//  Pure(ish) read-only aggregations over orders/products/users for
//  a given time period. No Gemini, no writes - the Business Analyst
//  agent (B2) feeds these numbers to the LLM for narration and uses
//  them directly for anomaly detection. Kept deterministic so the
//  report's numbers are always trustworthy even if the LLM call
//  degrades (spec design principle 7).
// ============================================================

import * as admin from 'firebase-admin';

const db = admin.firestore();

export interface ProductSalesEntry {
  productId: string;
  name: string;
  quantity: number;
  revenue: number;
}

export interface PeriodMetrics {
  startDate: string; // ISO date
  endDate: string; // ISO date (exclusive)
  revenue: number;
  orderCount: number;
  aov: number; // average order value
  topProducts: ProductSalesEntry[];
  newCustomers: number;
  lowStockCount: number;
}

export interface AnomalyFlag {
  type: string;
  severity: 'low' | 'medium' | 'high' | 'critical';
  message_en: string;
  message_hi: string;
  value: number;
  threshold: number;
}

export interface MetricsComparison {
  period: 'daily' | 'weekly';
  current: PeriodMetrics;
  previous: PeriodMetrics;
  deltas: {
    revenuePct: number | null;
    orderCountPct: number | null;
    aovPct: number | null;
  };
  anomalies: AnomalyFlag[];
}

/** Order statuses (stored as either 'delivered'/'completed' or the
 * Dart enum's toString() form 'OrderStatus.delivered') that count
 * towards revenue. */
function isCompletedStatus(status: unknown): boolean {
  const s = String(status ?? '').toLowerCase();
  return s.includes('delivered') || s.includes('completed');
}

function pctChange(current: number, previous: number): number | null {
  if (previous === 0) return current === 0 ? 0 : null;
  return ((current - previous) / previous) * 100;
}

/**
 * Aggregates revenue, order count, AOV, and top products for the
 * half-open interval [start, end).
 */
export async function computePeriodMetrics(start: Date, end: Date): Promise<PeriodMetrics> {
  const ordersSnap = await db
    .collection('orders')
    .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(start))
    .where('createdAt', '<', admin.firestore.Timestamp.fromDate(end))
    .get();

  let revenue = 0;
  let orderCount = 0;
  const productAgg: Record<string, ProductSalesEntry> = {};

  ordersSnap.forEach((doc) => {
    const order = doc.data();
    if (!isCompletedStatus(order.status)) return;

    revenue += Number(order.totalAmount ?? 0);
    orderCount += 1;

    const items = Array.isArray(order.items) ? order.items : [];
    for (const item of items) {
      const productId = String(item.productId ?? 'unknown');
      const name = String(item.productName ?? productId);
      const qty = Number(item.quantity ?? 0);
      const lineRevenue = Number(item.totalPrice ?? (item.price ?? 0) * qty);

      if (!productAgg[productId]) {
        productAgg[productId] = { productId, name, quantity: 0, revenue: 0 };
      }
      productAgg[productId].quantity += qty;
      productAgg[productId].revenue += lineRevenue;
    }
  });

  const topProducts = Object.values(productAgg)
    .sort((a, b) => b.revenue - a.revenue)
    .slice(0, 5);

  const aov = orderCount > 0 ? revenue / orderCount : 0;

  // New customers: users created in the window.
  let newCustomers = 0;
  try {
    const usersSnap = await db
      .collection('users')
      .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(start))
      .where('createdAt', '<', admin.firestore.Timestamp.fromDate(end))
      .get();
    newCustomers = usersSnap.size;
  } catch (err) {
    console.warn('[Metrics] Could not compute newCustomers (missing index/field?):', err);
  }

  const lowStockCount = await computeLowStockCount();

  return {
    startDate: start.toISOString(),
    endDate: end.toISOString(),
    revenue,
    orderCount,
    aov,
    topProducts,
    newCustomers,
    lowStockCount,
  };
}

/** Number of products with stockQuantity <= 5 (mirrors the existing
 * lowStockAlerts cron threshold). */
export async function computeLowStockCount(): Promise<number> {
  try {
    const snap = await db.collection('products').where('stockQuantity', '<=', 5).get();
    return snap.size;
  } catch (err) {
    console.warn('[Metrics] Could not compute lowStockCount:', err);
    return 0;
  }
}

function detectAnomalies(current: PeriodMetrics, previous: PeriodMetrics): AnomalyFlag[] {
  const anomalies: AnomalyFlag[] = [];
  const revenuePct = pctChange(current.revenue, previous.revenue);
  const orderCountPct = pctChange(current.orderCount, previous.orderCount);

  if (revenuePct !== null && revenuePct <= -20) {
    anomalies.push({
      type: 'revenue_drop',
      severity: revenuePct <= -40 ? 'critical' : 'high',
      message_en: `Revenue dropped ${Math.abs(revenuePct).toFixed(1)}% vs. previous period.`,
      message_hi: `पिछली अवधि की तुलना में बिक्री ${Math.abs(revenuePct).toFixed(1)}% घट गई है।`,
      value: revenuePct,
      threshold: -20,
    });
  }

  if (orderCountPct !== null && orderCountPct <= -25) {
    anomalies.push({
      type: 'orders_drop',
      severity: orderCountPct <= -50 ? 'high' : 'medium',
      message_en: `Order count dropped ${Math.abs(orderCountPct).toFixed(1)}% vs. previous period.`,
      message_hi: `पिछली अवधि की तुलना में ऑर्डर की संख्या ${Math.abs(orderCountPct).toFixed(1)}% घट गई है।`,
      value: orderCountPct,
      threshold: -25,
    });
  }

  if (current.lowStockCount >= 5) {
    anomalies.push({
      type: 'low_stock',
      severity: current.lowStockCount >= 15 ? 'high' : 'medium',
      message_en: `${current.lowStockCount} products are low on stock (5 units or fewer).`,
      message_hi: `${current.lowStockCount} प्रोडक्ट्स का स्टॉक कम है (5 या उससे कम यूनिट)।`,
      value: current.lowStockCount,
      threshold: 5,
    });
  }

  if (current.orderCount === 0 && previous.orderCount > 0) {
    anomalies.push({
      type: 'zero_orders',
      severity: 'critical',
      message_en: 'No orders were placed in this period.',
      message_hi: 'इस अवधि में कोई ऑर्डर नहीं आया।',
      value: 0,
      threshold: 0,
    });
  }

  return anomalies;
}

/** Yesterday vs. the day before, in Asia/Kolkata. `referenceDate`
 * defaults to "now" and the daily window is [yesterday 00:00,
 * today 00:00) so the report can run early in the morning and
 * cover a full completed day. */
export async function computeDailyMetrics(referenceDate: Date = new Date()): Promise<MetricsComparison> {
  const todayStart = startOfDayIST(referenceDate);
  const yesterdayStart = new Date(todayStart.getTime() - 24 * 60 * 60 * 1000);
  const dayBeforeStart = new Date(yesterdayStart.getTime() - 24 * 60 * 60 * 1000);

  const [current, previous] = await Promise.all([
    computePeriodMetrics(yesterdayStart, todayStart),
    computePeriodMetrics(dayBeforeStart, yesterdayStart),
  ]);

  return {
    period: 'daily',
    current,
    previous,
    deltas: {
      revenuePct: pctChange(current.revenue, previous.revenue),
      orderCountPct: pctChange(current.orderCount, previous.orderCount),
      aovPct: pctChange(current.aov, previous.aov),
    },
    anomalies: detectAnomalies(current, previous),
  };
}

/** Last 7 days vs. the 7 days before that. */
export async function computeWeeklyMetrics(referenceDate: Date = new Date()): Promise<MetricsComparison> {
  const todayStart = startOfDayIST(referenceDate);
  const weekStart = new Date(todayStart.getTime() - 7 * 24 * 60 * 60 * 1000);
  const prevWeekStart = new Date(weekStart.getTime() - 7 * 24 * 60 * 60 * 1000);

  const [current, previous] = await Promise.all([
    computePeriodMetrics(weekStart, todayStart),
    computePeriodMetrics(prevWeekStart, weekStart),
  ]);

  return {
    period: 'weekly',
    current,
    previous,
    deltas: {
      revenuePct: pctChange(current.revenue, previous.revenue),
      orderCountPct: pctChange(current.orderCount, previous.orderCount),
      aovPct: pctChange(current.aov, previous.aov),
    },
    anomalies: detectAnomalies(current, previous),
  };
}

/** Midnight in Asia/Kolkata (UTC+5:30) for the given instant,
 * returned as a UTC Date. */
function startOfDayIST(date: Date): Date {
  const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000;
  const shifted = new Date(date.getTime() + IST_OFFSET_MS);
  shifted.setUTCHours(0, 0, 0, 0);
  return new Date(shifted.getTime() - IST_OFFSET_MS);
}
