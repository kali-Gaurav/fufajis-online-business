import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/qna_model.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../services/qna_service.dart';
import '../utils/app_theme.dart';

/// Enhanced Q&A Section widget with full functionality
class QnaSection extends StatefulWidget {
  final String productId;
  final bool isShopOwner;
  final String? shopId;

  const QnaSection({super.key, required this.productId, this.isShopOwner = false, this.shopId});

  @override
  State<QnaSection> createState() => _QnaSectionState();
}

class _QnaSectionState extends State<QnaSection> {
  final QnaService _qnaService = QnaService();
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _sortBy = 'recent';
  QnaStatus? _filterStatus;
  String? _answeringQuestionId;
  bool _isLoading = false;

  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUserId = authProvider.currentUser?.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with search and filter
        _buildHeader(currentUserId),

        const SizedBox(height: 16),

        // Search and filter bar
        _buildSearchAndFilter(),

        const SizedBox(height: 16),

        // Q&A list
        _buildQnaList(currentUserId),

        const SizedBox(height: 16),

        // Ask question button (for customers)
        if (!widget.isShopOwner) _buildAskQuestionButton(),
      ],
    );
  }

  Widget _buildHeader(String? currentUserId) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text(
                'Questions & Answers',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey900,
                ),
              ),
              const SizedBox(width: 8),
              // Unanswered badge
              FutureBuilder<int>(
                future: _qnaService.getUnansweredCount(widget.productId),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data! > 0) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${snapshot.data!} unanswered',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),

          // Sort dropdown
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort, color: AppTheme.grey600),
            onSelected: (value) {
              setState(() => _sortBy = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'recent', child: Text('Most Recent')),
              const PopupMenuItem(value: 'helpful', child: Text('Most Helpful')),
              const PopupMenuItem(value: 'unanswered', child: Text('Unanswered First')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Search field
          TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
            decoration: InputDecoration(
              hintText: 'Search questions...',
              prefixIcon: const Icon(Icons.search, color: AppTheme.grey400),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppTheme.grey400),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.grey300),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),

          const SizedBox(height: 8),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', null),
                const SizedBox(width: 8),
                _buildFilterChip('Pending', QnaStatus.pending),
                const SizedBox(width: 8),
                _buildFilterChip('Answered', QnaStatus.answered),
                const SizedBox(width: 8),
                _buildFilterChip('Resolved', QnaStatus.resolved),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, QnaStatus? status) {
    final isSelected = _filterStatus == status;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filterStatus = selected ? status : null);
      },
      selectedColor: AppTheme.primary.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primary : AppTheme.grey600,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildQnaList(String? currentUserId) {
    return StreamBuilder<List<QnaModel>>(
      stream: _qnaService.getQuestions(
        productId: widget.productId,
        status: _filterStatus,
        sortBy: _sortBy,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState();
        }

        // Filter by search query
        final questions = snapshot.data!.where((qna) {
          if (_searchQuery.isEmpty) return true;
          final query = _searchQuery.toLowerCase();
          return qna.question.toLowerCase().contains(query) ||
              (qna.answer?.toLowerCase().contains(query) ?? false) ||
              qna.customerName.toLowerCase().contains(query);
        }).toList();

        if (questions.isEmpty) {
          return _buildEmptySearchState();
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: questions.length,
          itemBuilder: (context, index) {
            return _buildQuestionCard(questions[index], currentUserId);
          },
        );
      },
    );
  }

  Widget _buildQuestionCard(QnaModel qna, String? currentUserId) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: qna.isFlagged ? Border.all(color: AppTheme.error.withValues(alpha: 0.3)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Q icon
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                    'Q',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          qna.customerName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        if (qna.isVerifiedPurchase) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified, size: 14, color: AppTheme.info),
                        ],
                        const Spacer(),
                        Text(
                          qna.timeAgo,
                          style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      qna.question,
                      style: const TextStyle(fontSize: 15, color: AppTheme.grey900),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Answer section
          if (qna.answer != null) ...[const SizedBox(height: 16), _buildAnswerSection(qna)],

          // Shop owner answer form
          if (widget.isShopOwner &&
              widget.shopId != null &&
              qna.answer == null &&
              _answeringQuestionId != qna.id) ...[
            const SizedBox(height: 16),
            _buildAnswerForm(qna),
          ],

          // Actions row
          const SizedBox(height: 16),
          _buildActionsRow(qna, currentUserId),
        ],
      ),
    );
  }

  Widget _buildAnswerSection(QnaModel qna) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.grey100.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storefront, size: 16, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text(
                qna.shopOwnerName ?? 'Shop Owner',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppTheme.primary,
                ),
              ),
              if (qna.answeredAt != null) ...[
                const SizedBox(width: 8),
                Text(
                  '• ${qna.answerTimeAgo}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(qna.answer!, style: const TextStyle(fontSize: 14, color: AppTheme.grey800)),
        ],
      ),
    );
  }

  Widget _buildAnswerForm(QnaModel qna) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Write your answer',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _answerController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Type your answer here...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() => _answeringQuestionId = null);
                  _answerController.clear();
                },
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _answerController.text.trim().isEmpty ? null : () => _submitAnswer(qna),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Submit Answer'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionsRow(QnaModel qna, String? currentUserId) {
    return Row(
      children: [
        // Helpful vote
        _buildVoteButton(
          icon: qna.hasUserVotedHelpful(currentUserId ?? '')
              ? Icons.thumb_up
              : Icons.thumb_up_outlined,
          count: qna.helpfulVotes,
          label: 'Helpful',
          isActive: qna.hasUserVotedHelpful(currentUserId ?? ''),
          onTap: currentUserId != null && qna.canUserVote(currentUserId)
              ? () => _voteHelpful(qna)
              : null,
        ),
        const SizedBox(width: 16),

        // Unhelpful vote
        _buildVoteButton(
          icon: qna.hasUserVotedUnhelpful(currentUserId ?? '')
              ? Icons.thumb_down
              : Icons.thumb_down_outlined,
          count: qna.unhelpfulVotes,
          label: 'Not Helpful',
          isActive: qna.hasUserVotedUnhelpful(currentUserId ?? ''),
          onTap: currentUserId != null && qna.canUserVote(currentUserId)
              ? () => _voteUnhelpful(qna)
              : null,
        ),

        const Spacer(),

        // Report button
        if (currentUserId != null && currentUserId != qna.customerId)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppTheme.grey400),
            onSelected: (value) => _showReportDialog(qna),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag, color: AppTheme.error, size: 20),
                    SizedBox(width: 8),
                    Text('Report'),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildVoteButton({
    required IconData icon,
    required int count,
    required String label,
    required bool isActive,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isActive ? AppTheme.primary : AppTheme.grey500),
            const SizedBox(width: 4),
            Text(
              '$count $label',
              style: TextStyle(fontSize: 13, color: isActive ? AppTheme.primary : AppTheme.grey600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: AppTheme.grey100, borderRadius: BorderRadius.circular(16)),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.question_answer_outlined, size: 48, color: AppTheme.grey400),
            SizedBox(height: 16),
            Text(
              'No questions yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.grey600),
            ),
            SizedBox(height: 8),
            Text(
              'Be the first to ask a question about this product!',
              style: TextStyle(fontSize: 14, color: AppTheme.grey500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySearchState() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: AppTheme.grey100, borderRadius: BorderRadius.circular(16)),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.search_off, size: 48, color: AppTheme.grey400),
            SizedBox(height: 16),
            Text(
              'No matching questions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.grey600),
            ),
            SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(fontSize: 14, color: AppTheme.grey500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAskQuestionButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _showAskQuestionModal(context),
          icon: const Icon(Icons.help_outline, color: Colors.white),
          label: const Text(
            'Ask a Question',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  void _showAskQuestionModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.grey300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  const Text(
                    'Ask a Question',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.grey900,
                    ),
                  ),
                  const SizedBox(height: 8),

                  const Text(
                    'Get answers from the shop owner and other customers',
                    style: TextStyle(fontSize: 14, color: AppTheme.grey600),
                  ),
                  const SizedBox(height: 24),

                  // Question input
                  TextField(
                    controller: _questionController,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Your question',
                      hintText: 'e.g., Is this product organic? How long does it last?',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit button
                  ElevatedButton(
                    onPressed: _questionController.text.trim().isEmpty
                        ? null
                        : () => _submitQuestion(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Submit Question',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showReportDialog(QnaModel qna) {
    final reportController = TextEditingController();
    final reasons = [
      'Spam or misleading',
      'Inappropriate content',
      'Harassment or bullying',
      'Incorrect information',
      'Other',
    ];
    String? selectedReason;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Report Question'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...reasons.map(
                    (reason) => RadioListTile<String>(
                      title: Text(reason),
                      value: reason,
                      groupValue: selectedReason,
                      onChanged: (value) {
                        setDialogState(() => selectedReason = value);
                      },
                    ),
                  ),
                  if (selectedReason == 'Other')
                    TextField(
                      controller: reportController,
                      decoration: const InputDecoration(labelText: 'Specify reason'),
                    ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => context.pop(), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: selectedReason == null
                      ? null
                      : () {
                          _flagQuestion(
                            qna,
                            selectedReason == 'Other' ? reportController.text : selectedReason!,
                          );
                          context.pop();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Report'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitQuestion(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please login to ask a question')));
      return;
    }

    setState(() => _isLoading = true);

    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final isVerified = orderProvider.hasPurchasedProduct(widget.productId);

    try {
      await _qnaService.askQuestion(
        productId: widget.productId,
        customerId: currentUser.id,
        customerName: currentUser.name ?? 'Customer',
        customerImage: currentUser.profileImage ?? '',
        question: _questionController.text.trim(),
        isVerifiedPurchase: isVerified,
      );

      if (mounted) {
        _questionController.clear();
        context.pop(); // Close modal
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Question submitted!'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit question: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitAnswer(QnaModel qna) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;

    if (currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      await _qnaService.answerQuestion(
        productId: widget.productId,
        questionId: qna.id,
        shopOwnerId: currentUser.id,
        shopOwnerName: currentUser.name ?? 'Fufaji Store',
        answer: _answerController.text.trim(),
      );

      if (mounted) {
        _answerController.clear();
        setState(() => _answeringQuestionId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Answer submitted!'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit answer: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _voteHelpful(QnaModel qna) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id;

    if (currentUserId == null) return;

    try {
      await _qnaService.voteHelpful(
        productId: widget.productId,
        questionId: qna.id,
        userId: currentUserId,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to vote: $e')));
    }
  }

  Future<void> _voteUnhelpful(QnaModel qna) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id;

    if (currentUserId == null) return;

    try {
      await _qnaService.voteUnhelpful(
        productId: widget.productId,
        questionId: qna.id,
        userId: currentUserId,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to vote: $e')));
    }
  }

  Future<void> _flagQuestion(QnaModel qna, String reason) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id;

    if (currentUserId == null) return;

    try {
      await _qnaService.flagQuestion(
        productId: widget.productId,
        questionId: qna.id,
        userId: currentUserId,
        reason: reason,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Question reported for review'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to report: $e'), backgroundColor: AppTheme.error),
      );
    }
  }
}
