const express = require('express');
const router = express.Router();
const { verifyToken } = require('../auth');
const { getAI } = require('../services/genkitService');
const { db } = require('../firestore');
const z = require('zod');
const { findBestMatches, resolveAmbiguity } = require('../lib/fuzzy_matcher');

// ── Voice to Cart Flow (Hinglish/Hindi Natural Language Parsing) ───────────
// Uses Genkit to define a traceable flow for parsing shopping lists.

const CartItemSchema = z.object({
  item: z.string(),
  quantity: z.number().optional().default(1),
  unit: z.string().optional().default('piece'),
});

router.post('/voice-to-cart', verifyToken, async (req, res) => {
  const { transcript } = req.body || {};

  if (!transcript) {
    return res.status(400).json({ success: false, error: 'Transcript is required.' });
  }

  try {
    const ai = await getAI();
    const startTime = Date.now();

    // 1. Define and Execute Genkit Flow for parsing
    const voiceToCartFlow = ai.defineFlow(
      {
        name: 'voiceToCartFlow',
        inputSchema: z.string(),
        outputSchema: z.array(CartItemSchema),
      },
      async (input) => {
        const { output } = await ai.generate({
          prompt: `
            You are an expert shopping assistant for "Fufaji Online Business".
            The user will give you a shopping list in Hindi, Hinglish, or English.
            Extract the products, quantities, and units.
            If the unit is not specified, guess it based on common sense (e.g., Milk is usually 'litre', Flour is 'kg').

            User Transcript: "${input}"
          `,
          output: { schema: z.array(CartItemSchema) },
        });
        return output;
      }
    );

    const parsedList = await voiceToCartFlow(transcript);
    console.log(`[voiceToCart] Flow parsed ${parsedList.length} items`);

    // 2. Fetch product catalog from Firestore (Caching optimized)
    const productsSnap = await db().collection('products').get();
    const productCatalog = productsSnap.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    // 3. Smart fuzzy matching with resolved list
    const enrichedList = parsedList.map((entry) => {
      const matches = findBestMatches(entry.item, productCatalog, 0.4);

      if (matches.length === 0) {
        return { ...entry, matchFound: false, confidence: 0 };
      }

      const resolved = resolveAmbiguity(matches, entry.item, 1);
      const bestMatch = resolved[0];

      return {
        ...entry,
        productId: bestMatch.id,
        matchFound: true,
        confidence: Math.round(bestMatch.matchScore * 100),
        price: bestMatch.price,
        originalName: bestMatch.name,
        image: bestMatch.productImage,
        stockQuantity: bestMatch.stockQuantity || 0,
      };
    });

    const processingTime = Date.now() - startTime;
    return res.json({
      success: true,
      cartItems: enrichedList,
      metadata: {
        totalItems: enrichedList.length,
        matchedCount: enrichedList.filter((i) => i.matchFound).length,
        processingTimeMs: processingTime,
      },
    });
  } catch (error) {
    console.error('[voiceToCart] Flow Error:', error);
    return res.status(500).json({ success: false, error: error.message });
  }
});

// ── Generic Gemini Call (Traceable via Genkit) ───────────────────────────────
router.post('/gemini', verifyToken, async (req, res) => {
  const { prompt } = req.body || {};
  if (!prompt) return res.status(400).json({ success: false, error: 'Missing prompt.' });

  try {
    const ai = await getAI();
    const { text } = await ai.generate(prompt);
    return res.json({ success: true, text });
  } catch (error) {
    console.error('[gemini] Error:', error);
    return res.status(500).json({ success: false, error: error.message });
  }
});

// ── Voice Transcription (Google Cloud Speech-to-Text) ──────────────────────
router.post('/transcribe', verifyToken, async (req, res) => {
  const { audioBase64, language = 'hi-IN' } = req.body || {};

  if (!audioBase64) {
    return res.status(400).json({ success: false, error: 'audioBase64 is required.' });
  }

  try {
    const speech = require('@google-cloud/speech');
    const client = new speech.SpeechClient();

    const request = {
      config: {
        encoding: 'LINEAR16',
        sampleRateHertz: 16000,
        languageCode: language,
        enableAutomaticPunctuation: true,
      },
      audio: { content: audioBase64 },
    };

    const [response] = await client.recognize(request);
    const transcription = response.results
      .map((result) => (result.alternatives[0] ? result.alternatives[0].transcript : ''))
      .join('\n');

    return res.json({ success: true, transcript: transcription });
  } catch (error) {
    console.error('[transcribe] Error:', error.message);
    return res.status(500).json({ success: false, error: error.message });
  }
});

// ── Analyze Intent Flow ─────────────────────────────────────────────────────
router.post('/analyze-intent', verifyToken, async (req, res) => {
  const { text } = req.body || {};
  if (!text) return res.status(400).json({ success: false, error: 'text is required.' });

  try {
    const ai = await getAI();

    const IntentSchema = z.object({
      intent: z.enum(['add_to_cart', 'check_stock', 'remove_from_cart', 'view_cart', 'checkout', 'other']),
      confidence: z.number(),
      isHinglish: z.boolean(),
    });

    const { output } = await ai.generate({
      prompt: `Analyze this shopping-related text and identify the intent: "${text}"`,
      output: { schema: IntentSchema },
    });

    return res.json({ success: true, intent: output });
  } catch (error) {
    console.error('[analyze-intent] Error:', error.message);
    return res.status(500).json({ success: false, error: error.message });
  }
});

module.exports = router;
