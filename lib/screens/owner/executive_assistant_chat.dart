import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/executive_insight_model.dart';
import '../../services/executive_assistant_service.dart';
import 'package:intl/intl.dart';

import '../../utils/app_theme.dart';

class ExecutiveAssistantChat extends StatefulWidget {
  const ExecutiveAssistantChat({super.key});

  @override
  State<ExecutiveAssistantChat> createState() => _ExecutiveAssistantChatState();
}

class _ExecutiveAssistantChatState extends State<ExecutiveAssistantChat> {
  final TextEditingController _controller = TextEditingController();
  final ExecutiveAssistantService _assistantService = ExecutiveAssistantService();

  final List<dynamic> _messages =
      []; // Contains Strings (user questions) and ExecutiveInsightModels (AI responses)
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initial greeting
    _messages.add(
      ExecutiveInsightModel(
        id: 'greeting',
        insightType: 'Greeting',
        summary:
            'Hello Owner! I am your Fufaji Business AI. Ask me anything about revenue, inventory, or employees.',
        primaryCauses: [],
        timestamp: DateTime.now(),
      ),
    );
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.insert(0, text);
      _isLoading = true;
    });

    _controller.clear();

    try {
      final ownerId = FirebaseAuth.instance.currentUser?.uid ?? 'system';
      final insight = await _assistantService.askQuestion(text, ownerId);

      setState(() {
        _messages.insert(0, insight);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Executive AI Assistant', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true, // Start from bottom
              padding: const EdgeInsets.all(16.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                if (message is String) {
                  return _buildUserMessage(message);
                } else if (message is ExecutiveInsightModel) {
                  return _buildAiMessage(message);
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(color: AppTheme.ownerAccent),
            ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildUserMessage(String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16.0, left: 64.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: AppTheme.info.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16).copyWith(bottomRight: const Radius.circular(0)),
        ),
        child: Text(text, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _buildAiMessage(ExecutiveInsightModel insight) {
    final dateFormat = DateFormat.jm();

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16.0, right: 64.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16).copyWith(bottomLeft: const Radius.circular(0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.deepPurple, size: 20),
                const SizedBox(width: 8),
                Text(
                  insight.insightType,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
                ),
                const Spacer(),
                Text(
                  dateFormat.format(insight.timestamp),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(insight.summary, style: const TextStyle(fontSize: 16)),
            if (insight.primaryCauses.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Primary Causes:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              ...insight.primaryCauses.map(
                (c) => Padding(
                  padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                  child: Text('• $c', style: const TextStyle(fontSize: 14)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Ask the Business AI...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24.0)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: AppTheme.info,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
