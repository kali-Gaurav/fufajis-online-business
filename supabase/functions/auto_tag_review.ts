import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Quality issue keywords
const QUALITY_KEYWORDS = [
  "rotten",
  "bad",
  "poor",
  "damaged",
  "spoiled",
  "moldy",
  "bruised",
  "broken",
];
const FRESHNESS_KEYWORDS = [
  "fresh",
  "old",
  "stale",
  "wilted",
  "expired",
  "dry",
];
const PACKAGING_KEYWORDS = [
  "package",
  "box",
  "container",
  "wrapper",
  "broken",
];
const DAMAGE_KEYWORDS = [
  "damage",
  "broken",
  "crushed",
  "leak",
  "torn",
];
const WRONG_KEYWORDS = [
  "wrong",
  "different",
  "not",
  "incorrect",
  "different",
];

function autoTagReview(reviewText: string): string[] {
  if (!reviewText) return [];

  const text = reviewText.toLowerCase();
  const tags: string[] = [];

  if (QUALITY_KEYWORDS.some((kw) => text.includes(kw))) {
    tags.push("quality");
  }
  if (FRESHNESS_KEYWORDS.some((kw) => text.includes(kw))) {
    tags.push("freshness");
  }
  if (PACKAGING_KEYWORDS.some((kw) => text.includes(kw))) {
    tags.push("packaging");
  }
  if (DAMAGE_KEYWORDS.some((kw) => text.includes(kw))) {
    tags.push("damage");
  }
  if (WRONG_KEYWORDS.some((kw) => text.includes(kw))) {
    tags.push("wrong_item");
  }

  return tags;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { reviewId, reviewText } = await req.json();

    if (!reviewId || !reviewText) {
      return new Response(
        JSON.stringify({ error: "Missing reviewId or reviewText" }),
        { status: 400, headers: corsHeaders }
      );
    }

    const tags = autoTagReview(reviewText);

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const { data, error } = await supabase
      .from("product_reviews")
      .update({
        tags: tags,
        character_count: reviewText.length,
      })
      .eq("id", reviewId);

    if (error) {
      throw error;
    }

    return new Response(JSON.stringify({ success: true, tags }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
