import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/broadcast_provider.dart';
import '../../../utils/app_theme.dart';

class BroadcastComposeScreen extends StatefulWidget {
  final String? broadcastId;
  final String? initialTitle;
  final String? initialBody;

  const BroadcastComposeScreen({super.key, this.broadcastId, this.initialTitle, this.initialBody});

  @override
  State<BroadcastComposeScreen> createState() => _BroadcastComposeScreenState();
}

class _BroadcastComposeScreenState extends State<BroadcastComposeScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final TextEditingController _deepLinkController;
  String _audienceType = 'all';
  String? _segmentId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _bodyController = TextEditingController(text: widget.initialBody);
    _deepLinkController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _deepLinkController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final provider = Provider.of<BroadcastProvider>(context, listen: false);

    final ok = await provider.saveDraft(
      id: widget.broadcastId,
      title: _titleController.text.trim(),
      body: _bodyController.text.trim(),
      deepLink: _deepLinkController.text.trim().isEmpty ? null : _deepLinkController.text.trim(),
      type: _audienceType,
      segmentId: _audienceType == 'segment' ? _segmentId : null,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (ok) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Broadcast draft saved.')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(provider.errorMessage ?? 'Failed to save draft.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.broadcastId == null ? 'New Broadcast' : 'Edit Broadcast'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save Draft', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Audience Selector
            const Text(
              'Who should receive this?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            _buildAudienceCard(),
            const SizedBox(height: 24),

            // Content Section
            const Text(
              'Message Content',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g., Festival Sale is Live! 🪔',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Title is required' : null,
              maxLength: 60,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bodyController,
              decoration: const InputDecoration(
                labelText: 'Body Text',
                hintText: 'Keep it short and exciting...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              validator: (v) => v == null || v.isEmpty ? 'Body is required' : null,
              maxLength: 200,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _deepLinkController,
              decoration: const InputDecoration(
                labelText: 'Deep Link (Optional)',
                hintText: 'app://product/PROD_ID or /customer/home',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 32),

            // Preview Section
            _buildPreviewCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildAudienceCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            RadioListTile<String>(
              title: const Text('All Verified Customers'),
              subtitle: const Text('Send to everyone with the app installed'),
              value: 'all',
              groupValue: _audienceType,
              onChanged: (v) => setState(() => _audienceType = v!),
            ),
            RadioListTile<String>(
              title: const Text('Target Segment'),
              subtitle: const Text('Target specific groups (e.g., Inactive users)'),
              value: 'segment',
              groupValue: _audienceType,
              onChanged: (v) => setState(() {
                _audienceType = v!;
                _segmentId = 'recent_buyers'; // Default
              }),
            ),
            if (_audienceType == 'segment')
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: DropdownButtonFormField<String>(
                  initialValue: _segmentId,
                  decoration: const InputDecoration(labelText: 'Choose Segment', isDense: true),
                  items: const [
                    DropdownMenuItem(
                      value: 'recent_buyers',
                      child: Text('Recent Buyers (30 days)'),
                    ),
                    DropdownMenuItem(
                      value: 'inactive_users',
                      child: Text('Lapsed Users (90+ days)'),
                    ),
                    DropdownMenuItem(
                      value: 'platinum_members',
                      child: Text('Platinum Members Only'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _segmentId = v),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mobile Preview',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.notifications_active, color: AppTheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _titleController.text.isEmpty ? 'Notification Title' : _titleController.text,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _bodyController.text.isEmpty
                          ? 'Message body will appear here...'
                          : _bodyController.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
