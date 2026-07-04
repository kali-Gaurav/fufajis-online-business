import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FIREBASE_API_KEY = Deno.env.get("FIREBASE_API_KEY")!;

interface CreateProductRequest {
  name: string;
  hindiName: string;
  productCode: string;
  sku: string;
  categoryId: string;
  brandId?: string;
  description?: string;
  productType: "packaged" | "loose" | "fresh" | "frozen";
  unitType: "weight" | "volume" | "count";
  unit: string;
  quantity: number;
  mrp: number;
  sellingPrice: number;
  gst: number;
  aliases?: string[];
  hindiAliases?: string[];
  voicePatterns?: string[];
  imageUrl?: string;
  barcode?: string;
}

serve(async (req: Request) => {
  // CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST",
        "Access-Control-Allow-Headers": "authorization, content-type",
      },
    });
  }

  try {
    // Verify auth token
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing authorization header" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    const token = authHeader.replace("Bearer ", "");
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    // Verify JWT
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Check admin role
    const { data: profile } = await supabase
      .from("user_profiles")
      .select("role")
      .eq("user_id", user.id)
      .single();

    if (profile?.role !== "admin" && profile?.role !== "super_admin") {
      return new Response(JSON.stringify({ error: "Admin access required" }), {
        status: 403,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Parse request
    const body: CreateProductRequest = await req.json();

    // Validate required fields
    if (!body.name || !body.productCode || !body.categoryId) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: name, productCode, categoryId" }),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    // Generate search tokens
    const searchTokens = generateSearchTokens(body.name, body.hindiName);
    const phoneticTokens = generatePhoneticTokens(body.name, body.hindiAliases || []);

    // Create product in Supabase
    const { data: product, error: createError } = await supabase
      .from("catalog_products")
      .insert({
        product_code: body.productCode,
        name: body.name,
        hindi_name: body.hindiName,
        brand_id: body.brandId || null,
        category_id: body.categoryId,
        product_type: body.productType,
        unit_type: body.unitType,
        description: body.description,
        search_tokens: searchTokens,
        phonetic_tokens: phoneticTokens,
        aliases: body.aliases || [],
        hindi_aliases: body.hindiAliases || [],
        voice_enabled: true,
        voice_patterns: body.voicePatterns || [],
        is_active: true,
        created_at: new Date().toISOString(),
      })
      .select()
      .single();

    if (createError) {
      throw createError;
    }

    // Create variant
    const { data: variant, error: variantError } = await supabase
      .from("catalog_variants")
      .insert({
        product_id: product.id,
        variant_code: `${body.productCode}-1`,
        quantity: body.quantity,
        unit: body.unit,
        mrp: body.mrp,
        default_selling_price: body.sellingPrice,
        gst: body.gst,
        barcode: body.barcode || null,
        is_active: true,
      })
      .select()
      .single();

    if (variantError) {
      throw variantError;
    }

    // Sync to Firestore immediately
    await syncToFirestore(product, variant);

    return new Response(
      JSON.stringify({
        success: true,
        productId: product.id,
        variantId: variant.id,
        message: "Product created and synced to Firestore",
      }),
      {
        status: 201,
        headers: { "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("Error creating product:", error);
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : "Unknown error" }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      }
    );
  }
});

function generateSearchTokens(name: string, hindiName: string): string[] {
  const tokens = new Set<string>();

  // English tokens
  name.split(" ").forEach((word) => {
    if (word.length > 2) {
      tokens.add(word.toLowerCase());
    }
  });

  // Hindi tokens
  hindiName.split(" ").forEach((word) => {
    if (word.length > 0) {
      tokens.add(word);
    }
  });

  return Array.from(tokens);
}

function generatePhoneticTokens(name: string, aliases: string[]): string[] {
  const tokens = new Set<string>();

  // Add name and aliases
  tokens.add(name.toLowerCase());
  aliases.forEach((alias) => tokens.add(alias.toLowerCase()));

  // Add phonetic variants (simplified Soundex)
  tokens.forEach((token) => {
    if (token.length > 0) {
      // Simple phonetic variants
      tokens.add(token.replace(/[aeiou]/g, "").substring(0, 4));
    }
  });

  return Array.from(tokens);
}

async function syncToFirestore(
  product: any,
  variant: any
) {
  try {
    const firestoreUrl = `https://firestore.googleapis.com/v1/projects/_/databases/(default)/documents/products/${product.id}`;

    const payload = {
      fields: {
        id: { stringValue: product.id },
        sku: { stringValue: variant.variant_code },
        name: { stringValue: product.name },
        hindiName: { stringValue: product.hindi_name },
        categoryId: { stringValue: product.category_id },
        categoryName: { stringValue: product.category_id },
        mrp: { doubleValue: variant.mrp },
        sellingPrice: { doubleValue: variant.default_selling_price },
        stock: { integerValue: "0" },
        voiceEnabled: { booleanValue: product.voice_enabled },
        active: { booleanValue: product.is_active },
        createdAt: { timestampValue: product.created_at },
        updatedAt: { timestampValue: new Date().toISOString() },
      },
    };

    await fetch(
      `${firestoreUrl}?key=${FIREBASE_API_KEY}`,
      {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      }
    );
  } catch (error) {
    // Firestore sync is best-effort; don't fail the request
    console.warn("Firestore sync warning:", error);
  }
}
