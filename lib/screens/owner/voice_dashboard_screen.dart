import '../../services/logging_service.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/app_theme.dart';
import '../../widgets/voice_command_fab.dart';
import '../../services/voice_command_executor.dart';
import '../../services/voice_command_service.dart';

/// Owner screen: shows voice command history + quick-tap command shortcuts.
class VoiceDashboardScreen extends StatefulWidget {
  final String? shopId;

  const VoiceDashboardScreen({super.key, this.shopId});

  @override
  State<VoiceDashboardScreen> createState() => _VoiceDashboardScreenState();
}

class _VoiceDashboardScreenState extends State<VoiceDashboardScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoadingHistory = true;
  bool _isRunningQuick = false;
  String? _quickResult;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList('voice_command_history') ?? [];
      final parsed = raw
          .map((s) {
            try {
              return jsonDecode(s) as Map<String, dynamic>;
            } catch (_) {
              return <String, dynamic>{};
            }
          })
          .where((m) => m.isNotEmpty)
          .toList();
      setState(() {
        _history = parsed;
        _isLoadingHistory = false;
      });
    } catch (e) {
      setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('History Clear Karein?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Saari voice command history delete ho jayegi.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('voice_command_history');
      setState(() => _history = []);
    }
  }

  // ─── QUICK COMMANDS ───────────────────────────────────────────────────────

  Future<void> _runQuickCommand(String commandText) async {
    setState(() {
      _isRunningQuick = true;
      _quickResult = null;
    });

    try {
      final command = await VoiceCommandService().parse(commandText);

      final result = await VoiceCommandExecutor.execute(command, context);

      // Reload history after execution
      await _loadHistory();

      setState(() {
        _isRunningQuick = false;
        _quickResult = result;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result),
            backgroundColor: AppTheme.info,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isRunningQuick = false;
        _quickResult = 'Error: $e';
      });
    }
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: const Text('Voice Commands', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              onPressed: _clearHistory,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear History',
              color: AppTheme.error,
            ),
        ],
      ),
      floatingActionButton: VoiceCommandFab(shopId: widget.shopId),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        color: AppTheme.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildQuickCommandsSection(),
              const SizedBox(height: 24),
              _buildHistorySection(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── QUICK COMMANDS ───────────────────────────────────────────────────────

  Widget _buildQuickCommandsSection() {
    final quickCommands = [
      const _QuickCommand(
        label: 'Check Stock',
        subtitle: 'Low stock items dekho',
        icon: Icons.inventory_2_outlined,
        color: AppTheme.info,
        command: 'Low stock items kaun kaun se hain',
      ),
      const _QuickCommand(
        label: "Today's Orders",
        subtitle: 'Aaj ke orders kitne hain',
        icon: Icons.receipt_long_outlined,
        color: AppTheme.info,
        command: 'Aaj ke orders kitne hain',
      ),
      const _QuickCommand(
        label: 'Low Stock Alert',
        subtitle: 'Stock check karo',
        icon: Icons.warning_amber_outlined,
        color: AppTheme.warning,
        command: 'Stock report do',
      ),
      const _QuickCommand(
        label: 'Revenue Report',
        subtitle: "Aaj ki kamai",
        icon: Icons.attach_money,
        color: AppTheme.primary,
        command: 'Aaj ki total kamai kitni hai',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.bolt, color: AppTheme.primary, size: 20),
            SizedBox(width: 6),
            Text(
              'Quick Commands',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.grey900),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isRunningQuick)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(
              color: AppTheme.primary,
              backgroundColor: AppTheme.grey200,
            ),
          ),
        if (_quickResult != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.info.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: AppTheme.info, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _quickResult!,
                    style: const TextStyle(
                      color: AppTheme.grey900,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: quickCommands.map((qc) => _buildQuickCommandCard(qc)).toList(),
        ),
      ],
    );
  }

  Widget _buildQuickCommandCard(_QuickCommand qc) {
    return GestureDetector(
      onTap: _isRunningQuick ? null : () => _runQuickCommand(qc.command),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.cardShadows,
          border: Border.all(color: qc.color.withOpacity(0.2)),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: qc.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(qc.icon, color: qc.color, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  qc.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppTheme.grey900,
                  ),
                ),
                Text(qc.subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.grey500)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── HISTORY ──────────────────────────────────────────────────────────────

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.history, color: AppTheme.primary, size: 20),
                SizedBox(width: 6),
                Text(
                  'Recent Commands',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.grey900,
                  ),
                ),
              ],
            ),
            if (_history.isNotEmpty)
              Text(
                '${_history.length} items',
                style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingHistory)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),
          )
        else if (_history.isEmpty)
          _buildEmptyHistory()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _history.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _buildHistoryItem(_history[i]),
          ),
      ],
    );
  }

  Widget _buildEmptyHistory() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.mic_none, size: 48, color: AppTheme.grey300),
            SizedBox(height: 12),
            Text(
              'Koi voice commands nahi',
              style: TextStyle(color: AppTheme.grey500, fontSize: 14),
            ),
            SizedBox(height: 4),
            Text(
              'Neeche mic button press karein',
              style: TextStyle(color: AppTheme.grey400, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> item) {
    final command = item['command'] as String? ?? '';
    final result = item['result'] as String? ?? '';
    final tsRaw = item['timestamp'] as String?;
    DateTime? ts;
    if (tsRaw != null) {
      try {
        ts = DateTime.parse(tsRaw);
      } catch (e, stack) {
        LoggingService().error('Silent error caught', e, stack);
      }
    }

    final isSuccess =
        !result.toLowerCase().contains('error') && !result.toLowerCase().contains('nahi mila');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSuccess
                ? AppTheme.info.withOpacity(0.12)
                : AppTheme.error.withOpacity(0.12),
          ),
          child: Icon(
            isSuccess ? Icons.check : Icons.error_outline,
            color: isSuccess ? AppTheme.info : AppTheme.error,
            size: 20,
          ),
        ),
        title: Text(
          command,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.grey900,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              result,
              style: TextStyle(fontSize: 12, color: isSuccess ? AppTheme.info : AppTheme.error),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (ts != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  _formatTimestamp(ts),
                  style: const TextStyle(fontSize: 10, color: AppTheme.grey400),
                ),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.grey300, size: 18),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'abhi abhi';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min pehle';
    if (diff.inHours < 24) return '${diff.inHours} ghante pehle';
    return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─── HELPER MODEL ─────────────────────────────────────────────────────────────

class _QuickCommand {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String command;

  const _QuickCommand({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.command,
  });
}
