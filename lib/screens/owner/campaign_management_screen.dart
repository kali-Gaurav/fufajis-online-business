import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../providers/campaign_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/campaign_model.dart';
import '../../utils/app_theme.dart';
import '../../services/ai_campaign_generator_service.dart';

class CampaignManagementScreen extends StatefulWidget {
  const CampaignManagementScreen({super.key});

  @override
  State<CampaignManagementScreen> createState() => _CampaignManagementScreenState();
}
class _CampaignManagementScreenState extends State<CampaignManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _messageController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: const Text('Marketing Campaigns', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
        actions: [
          IconButton.filledTonal(
            tooltip: 'Notification Analytics',
            icon: const Icon(Icons.insights_outlined),
            onPressed: () => context.push('/owner/notification-analytics'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateCampaignWizard(context),
        icon: const Icon(Icons.add),
        label: const Text('New Campaign'),
      ),
      body: Consumer<CampaignProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.campaigns.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent));
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
                  const SizedBox(height: 16),
                  Text('Error loading campaigns', style: Theme.of(context).textTheme.titleLarge),
                  Text(provider.error!, style: const TextStyle(color: AppTheme.grey600)),
                ],
              ),
            );
          }

          if (provider.campaigns.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.campaign_outlined, size: 64, color: AppTheme.grey400),
                  const SizedBox(height: 16),
                  Text('No Campaigns Yet', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text('Create your first marketing campaign to boost sales!', 
                    style: TextStyle(color: AppTheme.grey600)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateCampaignWizard(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Campaign'),
                  )
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildCampaignSection('Active', provider.activeCampaigns),
              _buildCampaignSection('Scheduled', provider.scheduledCampaigns),
              _buildCampaignSection('Drafts', provider.draftCampaigns),
              _buildCampaignSection('Past', provider.pastCampaigns),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCampaignSection(String title, List<CampaignModel> campaigns) {
    if (campaigns.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.grey800),
          ),
        ),
        ...campaigns.map((c) => _CampaignCard(campaign: c)),
        const SizedBox(height: 16),
      ],
    );
  }

  void _showCreateCampaignWizard(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _CampaignWizardBottomSheet(),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final CampaignModel campaign;

  const _CampaignCard({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy - hh:mm a');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Open details or edit based on status
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      campaign.title.isNotEmpty ? campaign.title : 'Untitled Campaign',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _StatusChip(status: campaign.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                campaign.messageBody,
                style: const TextStyle(color: AppTheme.grey700, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.people_outline, size: 16, color: AppTheme.grey500),
                  const SizedBox(width: 4),
                  Text('${campaign.estimatedAudienceSize} target audience', 
                    style: const TextStyle(color: AppTheme.grey600, fontSize: 12)),
                  const Spacer(),
                  if (campaign.scheduledAt != null) ...[
                    const Icon(Icons.schedule, size: 16, color: AppTheme.grey500),
                    const SizedBox(width: 4),
                    Text(dateFormat.format(campaign.scheduledAt!), 
                      style: const TextStyle(color: AppTheme.grey600, fontSize: 12)),
                  ] else if (campaign.sentAt != null) ...[
                    const Icon(Icons.send_outlined, size: 16, color: AppTheme.grey500),
                    const SizedBox(width: 4),
                    Text(dateFormat.format(campaign.sentAt!), 
                      style: const TextStyle(color: AppTheme.grey600, fontSize: 12)),
                  ],
                ],
              ),
              if (campaign.status == CampaignStatus.completed || campaign.status == CampaignStatus.active) ...[
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatBlock('Sent', campaign.impressions.toString()),
                    _StatBlock('Clicks', campaign.clicks.toString()),
                    _StatBlock('Revenue', '₹${campaign.revenueAttributed.toStringAsFixed(0)}'),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final CampaignStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case CampaignStatus.draft:
        color = AppTheme.grey500;
        break;
      case CampaignStatus.scheduled:
        color = AppTheme.info;
        break;
      case CampaignStatus.active:
        color = AppTheme.primary;
        break;
      case CampaignStatus.completed:
        color = AppTheme.success;
        break;
      case CampaignStatus.cancelled:
        color = AppTheme.error;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;

  const _StatBlock(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: const TextStyle(color: AppTheme.grey500, fontSize: 11)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIZARD BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _CampaignWizardBottomSheet extends StatefulWidget {
  const _CampaignWizardBottomSheet();

  @override
  State<_CampaignWizardBottomSheet> createState() => _CampaignWizardBottomSheetState();
}

class _CampaignWizardBottomSheetState extends State<_CampaignWizardBottomSheet> {
  int _currentStep = 0;
  
  // Data collection
  String _goal = '';
  List<String> _selectedSegments = ['all'];
  String _offerDetails = '';
  bool _sendTimeOptimization = false;
  
  // AI Generation state
  bool _isGenerating = false;
  List<Map<String, String>> _generatedOptions = [];
  int _selectedOptionIndex = -1;
  
  // Manual text edits
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();

  Future<void> _generateWithAI() async {
    setState(() {
      _isGenerating = true;
    });
    
    try {
      final generator = AiCampaignGeneratorService();
      
      // Suggest segment if not set
      if (_selectedSegments.contains('all') && _selectedSegments.length == 1 && _offerDetails.isNotEmpty) {
        final suggestions = await generator.suggestAudienceSegment(_offerDetails);
        if (suggestions.isNotEmpty) {
          setState(() {
            _selectedSegments = suggestions;
          });
        }
      }
      
      // Generate copy
      final options = await generator.generateCampaignCopy(
        goal: _goal.isEmpty ? "Increase sales" : _goal,
        audience: _selectedSegments.join(', '),
        offerDetails: _offerDetails.isEmpty ? "General promotion" : _offerDetails,
      );
      
      setState(() {
        _generatedOptions = options;
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _isGenerating = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating AI copy: $e')));
      }
    }
  }

  void _saveDraft() async {
    final provider = context.read<CampaignProvider>();
    final auth = context.read<AuthProvider>();
    
    if (_titleController.text.isEmpty || _bodyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select or write a title and body')));
      return;
    }

    final campaign = CampaignModel(
      id: '',
      title: _titleController.text,
      messageBody: _bodyController.text,
      type: CampaignType.push,
      status: CampaignStatus.draft,
      targetSegments: _selectedSegments,
      createdAt: DateTime.now(),
      sendTimeOptimization: _sendTimeOptimization,
    );

    try {
      await provider.createDraft(
        campaign, 
        auth.currentUser?.id ?? 'admin', 
        auth.currentUser?.name ?? 'Admin'
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Campaign saved as draft')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      height: MediaQuery.of(context).size.height * 0.9,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Stepper(
              type: StepperType.horizontal,
              currentStep: _currentStep,
              onStepContinue: () {
                if (_currentStep == 0) {
                  _generateWithAI();
                  setState(() => _currentStep += 1);
                } else if (_currentStep == 1) {
                  if (_selectedOptionIndex != -1) {
                    _titleController.text = _generatedOptions[_selectedOptionIndex]['title'] ?? '';
                    _bodyController.text = _generatedOptions[_selectedOptionIndex]['body'] ?? '';
                  }
                  setState(() => _currentStep += 1);
                } else {
                  _saveDraft();
                }
              },
              onStepCancel: () {
                if (_currentStep > 0) {
                  setState(() => _currentStep -= 1);
                }
              },
              controlsBuilder: (context, details) {
                return Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: details.onStepContinue,
                          child: Text(_currentStep == 2 ? 'Save Draft' : 'Continue'),
                        ),
                      ),
                      if (_currentStep > 0) ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: details.onStepCancel,
                            child: const Text('Back'),
                          ),
                        ),
                      ]
                    ],
                  ),
                );
              },
              steps: [
                Step(
                  title: const Text('Goal', style: TextStyle(fontWeight: FontWeight.w700)),
                  isActive: _currentStep >= 0,
                  content: _buildGoalStep(),
                ),
                Step(
                  title: const Text('AI Copy', style: TextStyle(fontWeight: FontWeight.w700)),
                  isActive: _currentStep >= 1,
                  content: _buildAiCopyStep(),
                ),
                Step(
                  title: const Text('Review', style: TextStyle(fontWeight: FontWeight.w700)),
                  isActive: _currentStep >= 2,
                  content: _buildReviewStep(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.grey200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Create Campaign', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('What is the goal of this campaign?', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(
            hintText: 'e.g. Clear out expiring dairy items',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => _goal = v,
        ),
        const SizedBox(height: 24),
        const Text('What is the offer?', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(
            hintText: 'e.g. 50% off on Milk and Paneer using code FLASH50',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => _offerDetails = v,
        ),
      ],
    );
  }

  Widget _buildAiCopyStep() {
    if (_isGenerating) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(color: AppTheme.ownerAccent),
              SizedBox(height: 16),
              Text('Gemini AI is crafting the perfect message...'),
            ],
          ),
        ),
      );
    }

    if (_generatedOptions.isEmpty) {
      return const Center(child: Text('No options generated. Go back and try again.'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select AI Generated Copy:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...List.generate(_generatedOptions.length, (index) {
          final isSelected = _selectedOptionIndex == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedOptionIndex = index),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.grey300, width: isSelected ? 2 : 1),
                borderRadius: BorderRadius.circular(12),
                color: isSelected ? AppTheme.primary.withValues(alpha: 0.05) : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isSelected) const Icon(Icons.check_circle, color: AppTheme.primary, size: 20),
                      if (isSelected) const SizedBox(width: 8),
                      Expanded(child: Text(_generatedOptions[index]['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_generatedOptions[index]['body'] ?? ''),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Target Segments:', style: TextStyle(fontWeight: FontWeight.bold)),
        Wrap(
          spacing: 8,
          children: _selectedSegments.map((s) => Chip(
            label: Text(s),
            backgroundColor: AppTheme.info.withValues(alpha: 0.1),
          )).toList(),
        ),
        const SizedBox(height: 24),
        const Text('Title', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          maxLength: 40,
        ),
        const SizedBox(height: 16),
        const Text('Message Body', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _bodyController,
          maxLines: 3,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          maxLength: 120,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.grey300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Optimize send time per recipient', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: const Text(
              'Delivers this campaign to each customer at their personal best-engagement hour instead of immediately.',
              style: TextStyle(fontSize: 11, color: AppTheme.grey500),
            ),
            value: _sendTimeOptimization,
            onChanged: (v) => setState(() => _sendTimeOptimization = v),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.info.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome, size: 16, color: AppTheme.info),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Personalize with placeholders: {{firstName}}, {{name}}, {{walletBalance}}, '
                  '{{rewardPoints}}, {{membershipTier}}, {{referralCode}}.',
                  style: TextStyle(fontSize: 11, color: AppTheme.grey700),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}