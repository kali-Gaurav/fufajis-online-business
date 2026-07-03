import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import { executeAgentTool, ToolExecutionContext } from './agentToolExecutor';

const db = admin.firestore();

export const INVENTORY_CATALOG_AGENT_ID = 'inventory_catalog';

function getGeminiApiKey(): string | undefined {
  try {
    const cfg = functions.config();
    if (cfg?.gemini?.key) return cfg.gemini.key as string;
  } catch {
    // Ignore config loading errors in local/emulator environments
  }
  return process.env.GEMINI_API_KEY || process.env.GOOGLE_GENERATIVE_AI_API_KEY;
}

interface ProductDraft {
  name: string;
  nameHindi: string;
  description: string;
  category: string;
  price: number;
  unit: string;
  reasoning: string;
}

/**
 * Calls Gemini to generate a high-quality product description and
 * Hindi translation for a listing improvement or new draft.
 */
async function generateProductEnhancements(
  name: string,
  category: string,
  existingDesc?: string
): Promise<{ description: string; nameHindi: string; reasoning: string } | null> {
  const apiKey = getGeminiApiKey();
  if (!apiKey) return null;

  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const { GoogleGenerativeAI } = require('@google/generative-ai');
    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });

    const prompt = `You are a Retail Catalog Expert for Fufaji's Online, a grocery store in Baran, Rajasthan.
Optimize the following product listing:
Name: ${name}
Category: ${category}
Current Description: ${existingDesc || 'None'}

Provide:
1. A 2-sentence engaging description (English).
2. The product name in simple Hindi (Devanagari).
3. A brief internal rationale for the changes.

Respond with ONLY JSON:
{
  "description": "...",
  "nameHindi": "...",
  "reasoning": "..."
}`;

    const result = await model.generateContent(prompt);
    const text = result?.response?.text?.() ?? '';

    // Simple JSON extraction
    const start = text.indexOf('{');
    const end = text.lastIndexOf('}');
    if (start !== -1 && end !== -1) {
      return JSON.parse(text.substring(start, end + 1));
    }
    return null;
  } catch (err) {
    console.warn('[InventoryCatalog] Gemini enhancement failed:', err);
    return null;
  }
}

/**
 * Perception logic: Scans products with low stock, out of stock,
 * or missing descriptions/Hindi names to trigger catalog tasks.
 * Also scans "missed_searches" to suggest new products (spec §5).
 */
export async function runInventoryCatalogShift(
  ctx: ToolExecutionContext = { agentId: INVENTORY_CATALOG_AGENT_ID }
): Promise<{ tasksCreated: number; scannedProducts: number }> {
  const productsSnap = await db.collection('products').get();
  let tasksCreated = 0;

  const lowStockThreshold = 5;
  const lowStockItems: Array<{ id: string; name: string; quantity: number }> = [];
  const missingDetailItems: Array<{ id: string; name: string; category: string; missing: string[] }> = [];

  productsSnap.forEach((doc) => {
    const p = doc.data();
    const productId = doc.id;
    const name = p.name ?? 'Unknown Product';
    const quantity = Number(p.stockQuantity ?? 0);

    if (quantity <= lowStockThreshold) {
      lowStockItems.push({ id: productId, name, quantity });
    }

    const missing: string[] = [];
    if (!p.description || p.description.trim().length < 10) missing.push('description');
    if (!p.nameHindi) missing.push('nameHindi');

    if (missing.length > 0) {
      missingDetailItems.push({ id: productId, name, category: p.category || 'General', missing });
    }
  });

  // 1. Create alerts for Low Stock / OOS
  for (const item of lowStockItems) {
    const isOos = item.quantity === 0;
    await executeAgentTool(
      'create_task',
      {
        title: isOos ? `Out of stock: ${item.name}` : `Low stock: ${item.name}`,
        description: isOos ? `Restock required immediately.` : `Only ${item.quantity} left.`,
        type: 'inventory_alert',
        autonomy: 'advisory',
        priority: isOos ? 85 : 55,
        evidence: [{ label: 'qty', value: item.quantity }],
        payload: { productId: item.id, tool: 'set_stock_status', inStock: false },
        reasoning: `Stock level (${item.quantity}) is critical.`,
      },
      ctx
    );
    tasksCreated++;
  }

  // 2. Proactively improve weak listings using Gemini
  for (const item of missingDetailItems.slice(0, 3)) { // Cap at 3 per shift for cost
    const enhancement = await generateProductEnhancements(item.name, item.category);
    if (enhancement) {
      await executeAgentTool(
        'create_task',
        {
          title: `Optimize: ${item.name}`,
          description: `AI-generated description and Hindi name for better visibility.`,
          type: 'catalog_improvement',
          autonomy: 'approval',
          priority: 40,
          payload: {
            tool: 'update_product',
            productId: item.id,
            diff: {
              description: enhancement.description,
              nameHindi: enhancement.nameHindi,
            }
          },
          reasoning: enhancement.reasoning,
        },
        ctx
      );
      tasksCreated++;
    }
  }

  // 3. Scan for missed searches to suggest NEW products (Spec §5)
  try {
    const missedSnap = await db.collection('missed_searches')
      .where('processed', '==', false)
      .limit(10)
      .get();

    if (!missedSnap.empty) {
      const searchTerms = missedSnap.docs.map(d => d.data().query);
      // In a real run, we'd use Gemini to group terms and suggest a product.
      // For MVP, we'll flag the top one.
      const topTerm = searchTerms[0];
      await executeAgentTool(
        'create_task',
        {
          title: `New Product Opportunity: ${topTerm}`,
          description: `Multiple customers searched for "${topTerm}" but couldn't find it.`,
          type: 'new_product_suggestion',
          autonomy: 'advisory',
          priority: 70,
          evidence: [{ label: 'searches', value: missedSnap.size }],
          reasoning: `High demand detected via search logs for unlisted item: ${topTerm}.`,
        },
        ctx
      );
      tasksCreated++;
    }
  } catch (e) {
    // missed_searches collection might not exist yet, skip silently
  }

  return { tasksCreated, scannedProducts: productsSnap.size };
}
