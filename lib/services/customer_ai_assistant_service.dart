import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_ai/firebase_ai.dart';
import '../models/cart_item.dart' as model;

class CustomerAiAssistantService {
  late GenerativeModel _model;
  ChatSession? _chatSession;

  CustomerAiAssistantService() {
    _model = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-1.5-flash',
      generationConfig: GenerationConfig(temperature: 0.7),
    );
  }

  /// Initializes the chat session with system instructions and current cart context
  void initializeSession(String userName, List<model.CartItem> cartItems) {
    String cartContext = cartItems.isEmpty
        ? "The user's cart is currently empty."
        : "The user currently has these items in their cart: ${cartItems.map((i) => '${i.quantity}x ${i.productName}').join(', ')}.";

    final systemPrompt =
        '''
You are "Fufaji AI", a friendly, helpful, and highly intelligent shopping assistant for the Fufaji Online Business app (a hyperlocal grocery and daily needs delivery service in India).
You speak primarily in a warm, conversational tone (Hinglish or English).

Current Context:
User Name: $userName
$cartContext

Capabilities & Rules:
1. Suggest recipes based on the ingredients currently in their cart.
2. Recommend missing ingredients they should buy to complete a recipe.
3. Help them find products or answer general cooking/shopping queries.
4. Keep responses concise and formatted nicely.
5. If they ask about orders or delivery, politely tell them to check the "Track Order" or "Support" screen.
''';

    // Restart chat session
    _chatSession = _model.startChat(
      history: [
        Content.text(systemPrompt),
        Content.model([
          const TextPart("Understood. I am Fufaji AI and I am ready to help the user."),
        ]),
      ],
    );
  }

  /// Send a message and get response
  Future<String> sendMessage(String text, {List<model.CartItem>? currentCart}) async {
    if (_chatSession == null) {
      initializeSession('Customer', currentCart ?? []);
    }

    try {
      // If we have an updated cart, we can inject a subtle context reminder,
      // but for simplicity, we just send the user text.
      final response = await _chatSession!.sendMessage(Content.text(text));
      return response.text ?? "Sorry, I couldn't understand the response.";
    } catch (e) {
      debugPrint('[CustomerAiAssistantService] Error: $e');
      return "Oops! I'm having a little trouble connecting right now. Please try again later.";
    }
  }

  /// Specifically analyzes cart and suggests a recipe without needing a chat prompt
  Future<Map<String, dynamic>> suggestRecipeFromCart(List<model.CartItem> cartItems) async {
    if (cartItems.isEmpty) return {'error': 'Add some items to your cart first!'};

    final ingredients = cartItems.map((i) => i.productName).join(', ');
    final prompt =
        '''
I have these ingredients: $ingredients.
Suggest exactly ONE quick Indian recipe I can make. 
Also, list up to 3 additional ingredients I might need to buy.
Return ONLY JSON format:
{
  "recipeName": "Name of Recipe",
  "instructions": "Brief 2-3 step instruction",
  "missingIngredients": ["item 1", "item 2"]
}
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final cleaned = (response.text ?? '').replaceAll('```json', '').replaceAll('```', '').trim();
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[CustomerAiAssistantService] Recipe Error: $e');
      return {'error': 'Could not generate recipe. Try adding more items!'};
    }
  }
}
