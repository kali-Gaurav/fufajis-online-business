import 'package:flutter/material.dart';
import '../../services/vendor_service.dart';
import '../../utils/app_theme.dart';

class VendorDisputeResolutionScreen extends StatefulWidget {
  final String vendorId;

  const VendorDisputeResolutionScreen({Key? key, required this.vendorId})
      : super(key: key);

  @override
  State<VendorDisputeResolutionScreen> createState() =>
      _VendorDisputeResolutionScreenState();
}

class _VendorDisputeResolutionScreenState
    extends State<VendorDisputeResolutionScreen> {
  final _vendorService = VendorService();
  List<VendorDispute> _disputes = [];
  bool _isLoading = true;
  int _selectedTabIndex = 0;

  final List<String> _tabs = ['Open', 'In Review', 'Resolved', 'All'];
  final List<String> _statusFilters = ['open', 'in_review', 'resolved', 'all'];

  @override
  void initState() {
    super.initState();
    _loadDisputes();
  }

  Future<void> _loadDisputes() async {
    setState(() => _isLoading = true);
    try {
      final disputes = await _vendorService.getVendorDisputes(widget.vendorId);
      if (mounted) {
        setState(() {
          _disputes = disputes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  List<VendorDispute> _getFilteredDisputes() {
    final status = _statusFilters[_selectedTabIndex];
    if (status == 'all') return _disputes;
    return _disputes.where((d) => d.status == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Disputes & Conflicts'),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDisputes,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildTabBar(),
                Expanded(
                  child: _disputes.isEmpty
                      ? _buildEmptyState()
                      : _getFilteredDisputes().isEmpty
                          ? Center(
                              child: Text(
                                'No ${_tabs[_selectedTabIndex].toLowerCase()} disputes',
                                style: const TextStyle(color: AppTheme.grey600),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _getFilteredDisputes().length,
                              itemBuilder: (_, index) =>
                                  _buildDisputeCard(_getFilteredDisputes()[index]),
                            ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDisputeDialog,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add),
        label: const Text('Raise Dispute'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.gavel, size: 80, color: Colors.green[300]),
            const SizedBox(height: 24),
            const Text(
              'No Disputes',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            const Text(
              'Great! You don\'t have any open disputes',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.grey600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(
            _tabs.length,
            (index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                selected: _selectedTabIndex == index,
                onSelected: (_) => setState(() => _selectedTabIndex = index),
                label: Text(_tabs[index]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDisputeCard(VendorDispute dispute) {
    final statusColor = _getStatusColor(dispute.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dispute.subject,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${dispute.id.substring(0, 8)}',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.grey600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    dispute.status.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.grey50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                dispute.description,
                style: const TextStyle(fontSize: 12, color: AppTheme.grey700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Type',
                      style: TextStyle(fontSize: 10, color: AppTheme.grey600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dispute.disputeType,
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Created',
                      style: TextStyle(fontSize: 10, color: AppTheme.grey600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(dispute.createdAt),
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _viewDisputeDetails(dispute),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View Details'),
                  ),
                ),
                if (dispute.status == 'open' || dispute.status == 'in_review')
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showAddEvidenceDialog(dispute),
                        icon: const Icon(Icons.attach_file, size: 16),
                        label: const Text('Add Evidence'),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _viewDisputeDetails(VendorDispute dispute) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Dispute Details',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Dispute ID', dispute.id.substring(0, 12)),
            _buildDetailRow('Subject', dispute.subject),
            _buildDetailRow('Type', dispute.disputeType),
            _buildDetailRow('Status', dispute.status.toUpperCase()),
            _buildDetailRow('Created', _formatDate(dispute.createdAt)),
            const SizedBox(height: 16),
            const Text(
              'Description',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              dispute.description,
              style: const TextStyle(color: AppTheme.grey700, fontSize: 12),
            ),
            if (dispute.resolution != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Resolution',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Text(
                  dispute.resolution!,
                  style: TextStyle(color: Colors.green[700], fontSize: 12),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.grey600, fontSize: 12)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateDisputeDialog() async {
    final subjectController = TextEditingController();
    final descriptionController = TextEditingController();
    String disputeType = 'commission';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Raise New Dispute'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Dispute Type:'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: disputeType,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: const [
                  DropdownMenuItem(value: 'commission', child: Text('Commission Issue')),
                  DropdownMenuItem(value: 'payment', child: Text('Payment Issue')),
                  DropdownMenuItem(value: 'order', child: Text('Order Issue')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (val) {
                  if (val != null) disputeType = val;
                },
              ),
              const SizedBox(height: 16),
              const Text('Subject:'),
              const SizedBox(height: 8),
              TextField(
                controller: subjectController,
                decoration: InputDecoration(
                  hintText: 'Brief subject of the dispute',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Description:'),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Provide detailed information...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _createDispute(
                disputeType,
                subjectController.text,
                descriptionController.text,
              );
            },
            child: const Text('Create Dispute'),
          ),
        ],
      ),
    );
  }

  Future<void> _createDispute(
    String type,
    String subject,
    String description,
  ) async {
    if (subject.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    try {
      await _vendorService.createDispute(
        vendorId: widget.vendorId,
        disputeType: type,
        subject: subject,
        description: description,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dispute created successfully')),
        );
        _loadDisputes();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _showAddEvidenceDialog(VendorDispute dispute) async {
    final evidenceController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Evidence'),
        content: TextField(
          controller: evidenceController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Provide evidence details or file descriptions...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Evidence added. Please wait for review.')),
              );
              _loadDisputes();
            },
            child: const Text('Submit Evidence'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return Colors.orange;
      case 'in_review':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
