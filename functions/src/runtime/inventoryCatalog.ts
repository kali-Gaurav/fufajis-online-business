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

/**
 * Perception logic: Scans products with low stock, out of stock,
 * or missing descriptions/Hindi names to trigger catalog tasks.
 */
export async function runInventoryCatalogShift(
  ctx: ToolExecutionContext = { agentId: INVENTORY_CATALOG_AGENT_ID }
): Promise<{ tasksCreated: number; scannedProducts: number }> {
  const productsSnap = await db.collection('products').get();
  let tasksCreated = 0;

  const lowStockThreshold = 5;
  const lowStockItems: Array<{ id: string; name: string; quantity: number }> = [];
  const missingDetailItems: Array<{ id: string; name: string; missing: string[] }> = [];

  productsSnap.forEach((doc) => {
    const p = doc.data();
    const productId = doc.id;
    const name = p.name ?? 'Unknown Product';
    const quantity = Number(p.stockQuantity ?? 0);

    // 1. Identify low stock / out of stock
    if (quantity <= lowStockThreshold) {
      lowStockItems.push({ id: productId, name, quantity });
    }

    // 2. Identify missing listing fields (Description or Hindi name)
    const missing: string[] = [];
    if (!p.description || p.description.trim().length === 0) {
      missing.push('description');
    }
    if (!p.nameHindi || p.nameHindi.trim().length === 0) {
      missing.push('nameHindi');
    }

    if (missing.length > 0) {
      missingDetailItems.push({ id: productId, name, missing });
    }
  });

  // Create tasks based on scanned gaps
  for (const item of lowStockItems) {
    const isOos = item.quantity === 0;
    await executeAgentTool(
      'create_task',
      {
        title: isOos ? `Out of stock: ${item.name}` : `Low stock: ${item.name}`,
        description: isOos
          ? `The item is completely out of stock. Restock immediately.`
          : `Only ${item.quantity} units remaining in inventory.`,
        type: 'inventory_alert',
        autonomy: 'advisory',
        priority: isOos ? 85 : 55,
        confidence: 0.95,
        evidence: [
          { label: 'productId', value: item.id },
          { label: 'currentStock', value: item.quantity },
        ],
        payload: { productId: item.id, stockQuantity: item.quantity },
        reasoning: `Detected inventory level of ${item.quantity} units, which is at or below the warning threshold of ${lowStockThreshold}.`,
      },
      ctx
    );
    tasksCreated++;
  }

  // Handle listing quality updates (suggest pricing/edits)
  for (const item of missingDetailItems) {
    await executeAgentTool(
      'create_task',
      {
        title: `Improve listing: ${item.name}`,
        description: `Optimize catalog quality. Missing: ${item.missing.join(', ')}.`,
        type: 'catalog_improvement',
        autonomy: 'approval',
        priority: 45,
        confidence: 0.8,
        evidence: [
          { label: 'productId', value: item.id },
          { label: 'missingFields', value: item.missing.join(',') },
        ],
        payload: {
          tool: 'update_product',
          productId: item.id,
          diff: {
            description: 'Provide an engaging product description.',
            nameHindi: item.name, // Fallback placeholder
          },
        },
        reasoning: `Product listing has missing metadata (${item.missing.join(', ')}), which reduces catalog search visibility.`,
      },
      ctx
    );
    tasksCreated++;
  }

  return {
    tasksCreated,
    scannedProducts: productsSnap.size,
  };
}
