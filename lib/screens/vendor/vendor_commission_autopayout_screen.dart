import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/app_theme.dart';
import '../../services/vendor_service.dart';
import '../../providers/auth_provider.dart';

class VendorCommissionAutoPayoutScreen extends StatefulWidget {
  final String vendorId;

  const VendorCommissionAutoPayoutScreen({Key? key, required this.vendorId})
      : super(key: key);

  @override
  State<VendorCommissionAutoPayoutScreen> createState() =>
      _VendorCommissionAutoPayoutScreenState();
}

class _VendorCommissionAutoPayoutScreenState
    extends State<VendorCommissionAutoPayoutScreen> {
  bool _autoPayoutEnabled = false;
  String _payoutFrequency = 'weekly'; // weekly, biweekly, monthly
  double _minimumThreshold = 500.0;
  String _payoutMethod = 'bank'; // bank, upi
  bool _isLoading = false;
  final _vendorService = VendorService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto-Payout Settings'),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEnableSection(),
            const SizedBox(height: 24),
            if (_autoPayoutEnabled) ...[
              _buildFrequencySection(),
              const SizedBox(height: 24),
              _buildThresholdSection(),
              const SizedBox(height: 24),
              _buildPayoutMethodSection(),
              const SizedBox(height: 24),
              _buildSchedulePreview(),
              const SizedBox(height: 24),
            ],
            _buildInfoCard(),
            const SizedBox(height: 32),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildEnableSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Automatic Payouts',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _autoPayoutEnabled
                          ? 'Payouts are automatically initiated'
                          : 'Manual payouts only',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.grey600,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: _autoPayoutEnabled,
                  onChanged: (val) {
                    setState(() => _autoPayoutEnabled = val);
                  },
                  activeColor: AppTheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue[600], size: 18),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Enable this to automatically process commission payouts based on your configured schedule',
                      style: TextStyle(fontSize: 12, color: AppTheme.grey700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrequencySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payout Frequency',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'weekly', label: Text('Weekly')),
            ButtonSegment(value: 'biweekly', label: Text('Bi-Weekly')),
            ButtonSegment(value: 'monthly', label: Text('Monthly')),
          ],
          selected: {_payoutFrequency},
          onSelectionChanged: (Set<String> selected) {
            setState(() => _payoutFrequency = selected.first);
          },
        ),
        const SizedBox(height: 12),
        Text(
          _getFrequencyDescription(_payoutFrequency),
          style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
        ),
      ],
    );
  }

  Widget _buildThresholdSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Minimum Payout Threshold',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        TextField(
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            prefixText: '₹ ',
            hintText: 'Minimum amount to trigger payout',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          controller: TextEditingController(text: _minimumThreshold.toString()),
          onChanged: (val) {
            setState(() {
              _minimumThreshold = double.tryParse(val) ?? 500.0;
            });
          },
        ),
        const SizedBox(height: 12),
        Text(
          'Payouts will only be initiated when pending commission exceeds ₹${_minimumThreshold.toStringAsFixed(0)}',
          style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
        ),
      ],
    );
  }

  Widget _buildPayoutMethodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Default Payout Method',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        RadioListTile<String>(
          title: const Text('Bank Transfer'),
          subtitle: const Text('Direct transfer to your bank account'),
          value: 'bank',
          groupValue: _payoutMethod,
          onChanged: (val) {
            if (val != null) setState(() => _payoutMethod = val);
          },
        ),
        RadioListTile<String>(
          title: const Text('UPI'),
          subtitle: const Text('Instant transfer via UPI'),
          value: 'upi',
          groupValue: _payoutMethod,
          onChanged: (val) {
            if (val != null) setState(() => _payoutMethod = val);
          },
        ),
      ],
    );
  }

  Widget _buildSchedulePreview() {
    final nextPayout = _calculateNextPayout();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Next Scheduled Payout',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            nextPayout,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          const Text(
            'Your commissions will be automatically processed on this date, provided they meet the minimum threshold.',
            style: TextStyle(fontSize: 12, color: AppTheme.grey600),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info, color: Colors.amber[700], size: 20),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Important Information',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '• Processing may take 1-2 business days\n'
            '• You can manually request payouts anytime\n'
            '• Your banking details must be verified\n'
            '• No fee for automatic payouts (Razorpay Route)',
            style: TextStyle(fontSize: 12, color: AppTheme.grey700, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: _isLoading ? null : _saveSettings,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Save Settings', style: TextStyle(fontSize: 16)),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    try {
      // Get vendor ID from auth provider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final vendorId = authProvider.currentUser?.id ?? widget.vendorId;

      await _vendorService.updateAutoPayoutSettings(
        vendorId: vendorId,
        enabled: _autoPayoutEnabled,
        frequency: _payoutFrequency,
        minimumThreshold: _minimumThreshold,
        payoutMethod: _payoutMethod,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Auto-payout settings saved successfully'),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: ${e.toString()}'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getFrequencyDescription(String freq) {
    switch (freq) {
      case 'weekly':
        return 'Payouts will be initiated every Monday';
      case 'biweekly':
        return 'Payouts will be initiated every 2 weeks';
      case 'monthly':
        return 'Payouts will be initiated on the 1st of every month';
      default:
        return '';
    }
  }

  String _calculateNextPayout() {
    final now = DateTime.now();
    DateTime nextDate;

    switch (_payoutFrequency) {
      case 'weekly':
        // Next Monday
        nextDate = now.add(Duration(days: (8 - now.weekday) % 7));
        break;
      case 'biweekly':
        // 2 weeks from now
        nextDate = now.add(const Duration(days: 14));
        break;
      case 'monthly':
        // 1st of next month
        if (now.day < 1) {
          nextDate = DateTime(now.year, now.month, 1);
        } else {
          nextDate = DateTime(now.year, now.month + 1, 1);
        }
        break;
      default:
        nextDate = now;
    }

    return '${nextDate.day}/${nextDate.month}/${nextDate.year}';
  }
}
