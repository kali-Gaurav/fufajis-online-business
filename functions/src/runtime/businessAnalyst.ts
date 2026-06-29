// ============================================================
//  Mission Control - Business Analyst agent (B2)
//
//  Turns the deterministic numbers from metrics.ts into a bilingual
//  (Hindi + English) narrative report with insights, then files it
//  via the generate_report tool (agentToolExecutor). If Gemini is
//  unavailable or errors, falls back to a rule-based template so the
//  owner always gets a report (spec design principle 7: "Degrade
//  gracefully").
// ============================================================

import * as functions from 'firebase-functions';
import { MetricsComparison, ProductSalesEntry } from './metrics';
import { executeAgentTool, ToolExecutionContext } from './agentToolExecutor';

export const BUSINESS_ANALYST_AGENT_ID = 'business_analyst';

export interface AnalystNarrative {
  narrative_hi: string;
  narrative_en: string;
  insights: string[];
}

// ----------------------------------------------------------------
// Gemini client (lazy, optional)
// ----------------------------------------------------------------

function getGeminiApiKey(): string | undefined {
  // Prefer Functions config (set via `firebase functions:config:set gemini.key=...`),
  // fall back to an environment variable / Secret Manager binding.
  try {
    const cfg = functions.config();
    if (cfg?.gemini?.key) return cfg.gemini.key as string;
  } catch {
    // functions.config() may throw outside a deployed environment - ignore.
  }
  return process.env.GEMINI_API_KEY || process.env.GOOGLE_GENERATIVE_AI_API_KEY;
}

/**
 * Calls Gemini to turn the metrics comparison into a bilingual
 * narrative + insight list. Returns null if no API key is
 * configured or the call fails, so callers can fall back.
 */
async function generateNarrativeWithGemini(
  metrics: MetricsComparison
): Promise<AnalystNarrative | null> {
  const apiKey = getGeminiApiKey();
  if (!apiKey) return null;

  try {
    // Lazy import so the dependency is optional at runtime if unused.
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const { GoogleGenerativeAI } = require('@google/generative-ai');
    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });

    const prompt = buildAnalystPrompt(metrics);
    const result = await model.generateContent(prompt);
    const text = result?.response?.text?.() ?? '';

    const parsed = extractJson(text);
    if (
      parsed &&
      typeof parsed.narrative_hi === 'string' &&
      typeof parsed.narrative_en === 'string' &&
      Array.isArray(parsed.insights)
    ) {
      return {
        narrative_hi: parsed.narrative_hi,
        narrative_en: parsed.narrative_en,
        insights: parsed.insights.map((i: unknown) => String(i)).slice(0, 8),
      };
    }

    console.warn('[BusinessAnalyst] Gemini response did not match expected shape:', text);
    return null;
  } catch (err) {
    console.warn('[BusinessAnalyst] Gemini call failed, using fallback narrative:', err);
    return null;
  }
}

/** Pulls the first JSON object out of a model response, tolerating
 * markdown code fences. */
function extractJson(text: string): Record<string, unknown> | null {
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/i);
  const candidate = fenced ? fenced[1] : text;
  const start = candidate.indexOf('{');
  const end = candidate.lastIndexOf('}');
  if (start === -1 || end === -1 || end <= start) return null;
  try {
    return JSON.parse(candidate.slice(start, end + 1));
  } catch {
    return null;
  }
}

/**
 * Prompt v1 for the Business Analyst agent. Asks for a strict JSON
 * shape so the response can be parsed deterministically. Bilingual
 * output is mandatory per spec design principle 8
 * ("Bilingual & rural-first").
 */
function buildAnalystPrompt(m: MetricsComparison): string {
  const periodLabel = m.period === 'daily' ? "yesterday" : 'the last 7 days';
  const topProducts = m.current.topProducts
    .map((p) => `${p.name} (qty ${p.quantity}, revenue ₹${p.revenue.toFixed(0)})`)
    .join(', ') || 'none';

  return `You are the Business Analyst AI employee for a small Indian neighbourhood store ("Fufaji's Online").
Write a short business report for the owner covering ${periodLabel}.

Data (already computed, do not recompute or contradict these numbers):
- Revenue: ₹${m.current.revenue.toFixed(0)} (previous period: ₹${m.previous.revenue.toFixed(0)})
- Orders: ${m.current.orderCount} (previous period: ${m.previous.orderCount})
- Average order value: ₹${m.current.aov.toFixed(0)} (previous period: ₹${m.previous.aov.toFixed(0)})
- New customers: ${m.current.newCustomers}
- Low stock products: ${m.current.lowStockCount}
- Top products: ${topProducts}
- Revenue change: ${formatPct(m.deltas.revenuePct)}
- Order count change: ${formatPct(m.deltas.orderCountPct)}
- AOV change: ${formatPct(m.deltas.aovPct)}
- Anomalies detected: ${m.anomalies.length ? m.anomalies.map((a) => a.message_en).join('; ') : 'none'}

Respond with ONLY a JSON object (no markdown, no extra text) with this exact shape:
{
  "narrative_en": "2-4 sentence summary in plain English, warm and direct, mentioning the key numbers",
  "narrative_hi": "same summary in simple conversational Hindi (Devanagari script), suitable for a shopkeeper who is more comfortable in Hindi than English",
  "insights": ["short actionable bullet point", "..."]
}
Keep insights to at most 4 items, each one sentence, practical and specific to the numbers above.`;
}

function formatPct(pct: number | null): string {
  if (pct === null) return 'n/a';
  const sign = pct >= 0 ? '+' : '';
  return `${sign}${pct.toFixed(1)}%`;
}

// ----------------------------------------------------------------
// Rule-based fallback narrative
// ----------------------------------------------------------------

function formatTopProducts(products: ProductSalesEntry[]): string {
  if (!products.length) return 'No products sold.';
  return products
    .slice(0, 3)
    .map((p) => `${p.name} (${p.quantity} units, ₹${p.revenue.toFixed(0)})`)
    .join(', ');
}

export function buildFallbackNarrative(m: MetricsComparison): AnalystNarrative {
  const periodLabel = m.period === 'daily' ? 'Yesterday' : 'In the last 7 days';
  const periodLabelHi = m.period === 'daily' ? 'कल' : 'पिछले 7 दिनों में';

  const revenueTrend =
    m.deltas.revenuePct === null
      ? ''
      : m.deltas.revenuePct >= 0
      ? ` (up ${m.deltas.revenuePct.toFixed(1)}% vs. before)`
      : ` (down ${Math.abs(m.deltas.revenuePct).toFixed(1)}% vs. before)`;

  const revenueTrendHi =
    m.deltas.revenuePct === null
      ? ''
      : m.deltas.revenuePct >= 0
      ? ` (पहले से ${m.deltas.revenuePct.toFixed(1)}% ज़्यादा)`
      : ` (पहले से ${Math.abs(m.deltas.revenuePct).toFixed(1)}% कम)`;

  const narrative_en =
    `${periodLabel}, the store made ₹${m.current.revenue.toFixed(0)} from ${m.current.orderCount} order(s)` +
    `${revenueTrend}, with an average order value of ₹${m.current.aov.toFixed(0)}. ` +
    `Top sellers: ${formatTopProducts(m.current.topProducts)}.` +
    (m.current.lowStockCount > 0
      ? ` ${m.current.lowStockCount} product(s) are running low on stock.`
      : '');

  const narrative_hi =
    `${periodLabelHi} दुकान ने ${m.current.orderCount} ऑर्डर से ₹${m.current.revenue.toFixed(0)} की कमाई की${revenueTrendHi}, ` +
    `और औसत ऑर्डर वैल्यू ₹${m.current.aov.toFixed(0)} रही। ` +
    `सबसे ज़्यादा बिकने वाले: ${formatTopProducts(m.current.topProducts)}।` +
    (m.current.lowStockCount > 0
      ? ` ${m.current.lowStockCount} प्रोडक्ट्स का स्टॉक कम है।`
      : '');

  const insights: string[] = [];

  if (m.deltas.revenuePct !== null && m.deltas.revenuePct < 0) {
    insights.push(
      `Revenue is down ${Math.abs(m.deltas.revenuePct).toFixed(1)}% - consider a promotion or checking for stockouts on popular items.`
    );
  } else if (m.deltas.revenuePct !== null && m.deltas.revenuePct > 0) {
    insights.push(
      `Revenue is up ${m.deltas.revenuePct.toFixed(1)}% - whatever changed recently seems to be working, keep it going.`
    );
  }

  if (m.current.lowStockCount > 0) {
    insights.push(
      `${m.current.lowStockCount} product(s) are low on stock - restock soon to avoid losing sales.`
    );
  }

  if (m.current.topProducts.length > 0) {
    insights.push(
      `"${m.current.topProducts[0].name}" is your top seller - make sure it's always in stock and well displayed.`
    );
  }

  if (m.current.newCustomers > 0) {
    insights.push(`${m.current.newCustomers} new customer(s) joined - a welcome offer could turn them into regulars.`);
  }

  if (insights.length === 0) {
    insights.push('No major changes detected - business is steady.');
  }

  return { narrative_hi, narrative_en, insights: insights.slice(0, 4) };
}

// ----------------------------------------------------------------
// Chart data + report assembly
// ----------------------------------------------------------------

function buildChartData(m: MetricsComparison): Record<string, unknown> {
  return {
    revenue: { current: m.current.revenue, previous: m.previous.revenue },
    orderCount: { current: m.current.orderCount, previous: m.previous.orderCount },
    aov: { current: m.current.aov, previous: m.previous.aov },
    topProducts: m.current.topProducts.map((p) => ({ name: p.name, value: p.revenue })),
  };
}

/**
 * Runs one Business Analyst shift: computes (already-computed)
 * metrics into a narrative, then files a `reports/{id}` document via
 * the generate_report tool. Returns the new report id and whether
 * any anomalies were flagged.
 */
export async function runBusinessAnalystShift(
  metrics: MetricsComparison,
  ctx: ToolExecutionContext = { agentId: BUSINESS_ANALYST_AGENT_ID }
): Promise<{ reportId: string; anomalyCount: number; usedAI: boolean }> {
  let narrative = await generateNarrativeWithGemini(metrics);
  const usedAI = narrative !== null;
  if (!narrative) {
    narrative = buildFallbackNarrative(metrics);
  }

  // Surface anomaly messages alongside the LLM/template insights so
  // the owner sees them even if the narrative misses them.
  const insights = [
    ...metrics.anomalies.map((a) => a.message_en),
    ...narrative.insights,
  ].slice(0, 8);

  const result = await executeAgentTool(
    'generate_report',
    {
      period: metrics.period,
      type: metrics.period === 'daily' ? 'daily_summary' : 'weekly_summary',
      metrics: {
        revenue: metrics.current.revenue,
        orderCount: metrics.current.orderCount,
        aov: metrics.current.aov,
        newCustomers: metrics.current.newCustomers,
        lowStockCount: metrics.current.lowStockCount,
        topProducts: metrics.current.topProducts,
        deltas: metrics.deltas,
        anomalies: metrics.anomalies,
        startDate: metrics.current.startDate,
        endDate: metrics.current.endDate,
      },
      narrative_hi: narrative.narrative_hi,
      narrative_en: narrative.narrative_en,
      insights,
      chartData: buildChartData(metrics),
    },
    {
      ...ctx,
      reasoning: `Scheduled ${metrics.period} business analysis shift.`,
    }
  );

  return {
    reportId: String(result.result.reportId),
    anomalyCount: metrics.anomalies.length,
    usedAI,
  };
}
