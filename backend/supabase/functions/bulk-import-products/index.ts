import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

interface BulkImportRequest {
  products: Array<{
    name: string;
    hindiName: string;
    productCode: string;
    categoryId: string;
    unitType: "weight" | "volume" | "count";
    unit: string;
    quantity: number;
    mrp: number;
    sellingPrice: number;
    gst?: number;
    aliases?: string[];
    hindiAliases?: string[];
    voicePatterns?: string[];
  }>;
}

interface BulkImportResponse {
  success: boolean;
  totalProducts: number;
  createdCount: number;
  failedCount: number;
  failedProducts: Array<{
    productCode: string;
    error: string;
  }>;
}

serve(async (req: Request) => {
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
    // Verify auth
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing authorization" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    const token = authHeader.replace("Bearer ", "");
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Check admin
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

    const { products }: BulkImportRequest = await req.json();

    if (!Array.isArray(products) || products.length === 0) {
      return new Response(
        JSON.stringify({ error: "Invalid products array" }),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    const results: BulkImportResponse = {
      success: true,
      totalProducts: products.length,
      createdCount: 0,
      failedCount: 0,
      failedProducts: [],
    };

    // Process each product
    for (const productData of products) {
      try {
        const searchTokens = generateSearchTokens(productData.name, productData.hindiName);
        const phoneticTokens = generatePhoneticTokens(
          productData.name,
          productData.hindiAliases || []
        );

        // Create product
        const { data: product, error: productError } = await supabase
          .from("catalog_products")
          .insert({
            product_code: productData.productCode,
            name: productData.name,
            hindi_name: productData.hindiName,
            category_id: productData.categoryId,
            product_type: "packaged",
            unit_type: productData.unitType,
            search_tokens: searchTokens,
            phonetic_tokens: phoneticTokens,
            aliases: productData.aliases || [],
            hindi_aliases: productData.hindiAliases || [],
            voice_enabled: true,
            voice_patterns: productData.voicePatterns || [],
            is_active: true,
          })
          .select()
          .single();

        if (productError) throw productError;

        // Create variant
        const { error: variantError } = await supabase
          .from("catalog_variants")
          .insert({
            product_id: product.id,
            variant_code: `${productData.productCode}-1`,
            quantity: productData.quantity,
            unit: productData.unit,
            mrp: productData.mrp,
            default_selling_price: productData.sellingPrice,
            gst: productData.gst || 18,
            is_active: true,
          });

        if (variantError) throw variantError;

        results.createdCount++;
      } catch (error) {
        results.failedCount++;
        results.failedProducts.push({
          productCode: productData.productCode,
          error: error instanceof Error ? error.message : "Unknown error",
        });
      }
    }

    return new Response(JSON.stringify(results), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Bulk import error:", error);
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
  name.split(" ").forEach((word) => {
    if (word.length > 2) tokens.add(word.toLowerCase());
  });
  hindiName.split(" ").forEach((word) => {
    if (word.length > 0) tokens.add(word);
  });
  return Array.from(tokens);
}

function generatePhoneticTokens(name: string, aliases: string[]): string[] {
  const tokens = new Set<string>();
  tokens.add(name.toLowerCase());
  aliases.forEach((alias) => tokens.add(alias.toLowerCase()));
  return Array.from(tokens);
}
