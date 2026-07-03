import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/gemini_service.dart';
import '../utils/app_theme.dart';
import '../providers/product_provider.dart';

class AIShoppingAssistant extends StatefulWidget {
  const AIShoppingAssistant({super.key});

  @override
  State<AIShoppingAssistant> createState() => _AIShoppingAssistantState();
}

class _AIShoppingAssistantState extends State<AIShoppingAssistant> {
  bool _isOpen = false;
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [
    {
      'role': 'assistant',
      'content': 'Hello! I am Fufaji\'s AI assistant. How can I help you today?',
    },
  ];
  bool _isTyping = false;

  void _toggleChat() {
    setState(() => _isOpen = !_isOpen);
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    final userMessage = _controller.text.trim();
    _controller.clear();

    setState(() {
      _messages.add({'role': 'user', 'content': userMessage});
      _isTyping = true;
    });

    try {
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      final products = productProvider.products.map((p) => p.name).join(', ');

      final prompt =
          """
      You are Fufaji's Shopping Assistant. 
      The user is asking: "$userMessage"
      Available products are: $products
      Respond concisely and suggest matching products if possible.
      """;

      final response = await GeminiService.generateText(prompt);

      setState(() {
        _messages.add({'role': 'assistant', 'content': response});
        _isTyping = false;
      });
    } catch (e) {
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': 'Sorry, I am having trouble connecting. Try again?',
        });
        _isTyping = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_isOpen)
          Positioned(
            bottom: 160 + MediaQuery.of(context).padding.bottom,
            right: 16,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 300,
                height: 400,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.smart_toy_outlined, color: Colors.white),
                          const SizedBox(width: 8),
                          const Text(
                            'AI Shopping Assistant',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: _toggleChat,
                            icon: const Icon(Icons.close, color: Colors.white, size: 20),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isUser = msg['role'] == 'user';
                          return Align(
                            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isUser ? AppTheme.primaryColor : Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                msg['content']!,
                                style: TextStyle(
                                  color: isUser ? Colors.white : Colors.black87,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (_isTyping)
                      const Padding(
                        padding: EdgeInsets.only(left: 16, bottom: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Fufaji AI is typing...',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              decoration: InputDecoration(
                                hintText: 'Ask Fufaji AI...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          IconButton(
                            onPressed: _sendMessage,
                            icon: const Icon(Icons.send, color: AppTheme.primaryColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Positioned(
          bottom: 96 + MediaQuery.of(context).padding.bottom,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'ai_assistant',
            onPressed: _toggleChat,
            backgroundColor: AppTheme.primaryColor,
            child: _isOpen
                ? const Icon(Icons.close, color: Colors.white)
                : const Icon(Icons.smart_toy_outlined, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
