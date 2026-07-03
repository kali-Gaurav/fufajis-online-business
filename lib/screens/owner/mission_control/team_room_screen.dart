import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/agent_model.dart';
import '../../../models/agent_task_model.dart';
import '../../../models/report_model.dart';
import '../../../models/broadcast_model.dart';
import '../../../providers/accessibility_provider.dart';
import '../../../providers/agent_provider.dart';
import '../../../providers/agent_task_provider.dart';
import '../../../providers/report_provider.dart';
import '../../../providers/broadcast_provider.dart';
import '../../../utils/app_theme.dart';
import 'broadcast_compose_screen.dart';
import 'activity_feed_screen.dart';

/// Mission Control ("Karyalay") - Team Room.
///
/// Shows the AI agent roster as "desks", the master kill switch, and
/// (in the Approvals tab) any tasks waiting on the owner. Reports and
/// Broadcasts tabs are placeholders until Sprints B-D land.
class TeamRoomScreen extends StatefulWidget {
  const TeamRoomScreen({super.key});

  @override
  State<TeamRoomScreen> createState() => _TeamRoomScreenState();
}

class _TeamRoomScreenState extends State<TeamRoomScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mission Control', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ActivityFeedScreen()),
              );
            },
            tooltip: 'Activity Feed',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Team Room'),
            Tab(text: 'Approvals'),
            Tab(text: 'Reports'),
            Tab(text: 'Broadcasts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_TeamRoomTab(), _ApprovalsTab(), _ReportsTab(), _BroadcastsTab()],
      ),
    );
  }
}

class _TeamRoomTab extends StatelessWidget {
  const _TeamRoomTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<AgentProvider>(
      builder: (context, agentProvider, _) {
        if (agentProvider.isLoading) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent));
        }

        return RefreshIndicator(
          onRefresh: () async {},
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _KillSwitchCard(agentProvider: agentProvider),
              const SizedBox(height: 16),
              if (agentProvider.agents.isEmpty)
                _EmptyRosterCard(agentProvider: agentProvider)
              else
                ...agentProvider.agents.map(
                  (agent) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _AgentDeskCard(agent: agent),
                  ),
                ),
              if (agentProvider.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  agentProvider.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _KillSwitchCard extends StatelessWidget {
  final AgentProvider agentProvider;

  const _KillSwitchCard({required this.agentProvider});

  @override
  Widget build(BuildContext context) {
    final enabled = agentProvider.masterEnabled;

    return Card(
      color: enabled
          ? AppTheme.success.withValues(alpha: 0.08)
          : Colors.grey.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              enabled ? Icons.smart_toy : Icons.power_settings_new,
              color: enabled ? AppTheme.success : Colors.grey,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    enabled ? 'AI Team is ON' : 'AI Team is OFF',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    enabled
                        ? 'Agents are running on schedule and may propose or take approved actions.'
                        : 'Master kill switch is off. No agent will run, propose, or execute anything.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            agentProvider.isTogglingKillSwitch
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Switch(
                    value: enabled,
                    onChanged: (value) async {
                      if (value) {
                        final confirmed = await _confirmEnable(context);
                        if (!confirmed) return;
                      }
                      await agentProvider.setMasterEnabled(value);
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmEnable(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Turn on AI Team?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          'Your AI employees will start running on their schedules. '
          'Actions marked "auto" will execute immediately and be logged. '
          'Everything else will wait for your approval.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Turn On')),
        ],
      ),
    );
    return result ?? false;
  }
}

class _EmptyRosterCard extends StatelessWidget {
  final AgentProvider agentProvider;

  const _EmptyRosterCard({required this.agentProvider});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.groups_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('No AI employees set up yet', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Set up the starter team: Chief of Staff, Business Analyst, '
              'Inventory & Catalog, and Marketing & Comms.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                final ok = await agentProvider.seedRosterIfNeeded();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? 'Team set up.' : 'Could not set up team. Try again.'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.rocket_launch),
              label: const Text('Set Up AI Team'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgentDeskCard extends StatelessWidget {
  final AgentModel agent;

  const _AgentDeskCard({required this.agent});

  Color _statusColor(AgentStatus status) {
    switch (status) {
      case AgentStatus.working:
        return AppTheme.ownerAccent;
      case AgentStatus.waitingOwner:
        return AppTheme.warning;
      case AgentStatus.blocked:
        return AppTheme.error;
      case AgentStatus.disabled:
        return Colors.grey;
      case AgentStatus.idle:
        return AppTheme.success;
    }
  }

  String _statusLabel(AgentStatus status) {
    switch (status) {
      case AgentStatus.working:
        return 'Working';
      case AgentStatus.waitingOwner:
        return 'Waiting on you';
      case AgentStatus.blocked:
        return 'Blocked';
      case AgentStatus.disabled:
        return 'Disabled';
      case AgentStatus.idle:
        return 'Idle';
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(agent.status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: statusColor.withValues(alpha: 0.15),
              child: Text(agent.emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          agent.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _statusLabel(agent.status),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(agent.role, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      _kpiChip(Icons.task_alt, '${agent.kpis.tasksDone} tasks'),
                      _kpiChip(
                        Icons.thumb_up_alt_outlined,
                        '${(agent.kpis.approvalRate * 100).toStringAsFixed(0)}% approved',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

class _ApprovalsTab extends StatelessWidget {
  const _ApprovalsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<AgentTaskProvider>(
      builder: (context, taskProvider, _) {
        if (taskProvider.isLoading) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent));
        }

        final pending = taskProvider.awaitingApproval;
        final advisory = taskProvider.tasks
            .where(
              (t) =>
                  t.autonomy == AgentAutonomyTier.advisory && t.status == AgentTaskStatus.proposed,
            )
            .toList();

        if (pending.isEmpty && advisory.isEmpty) {
          return const _PlaceholderTab(
            icon: Icons.inbox_outlined,
            title: 'Nothing waiting on you',
            subtitle:
                'When an agent proposes something that needs your OK or a new idea, it will show up here.',
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (pending.isNotEmpty) ...[
              const Text(
                'AWAITING YOUR APPROVAL',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.2,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              ...pending.map(
                (task) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ApprovalCard(task: task, taskProvider: taskProvider),
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (advisory.isNotEmpty) ...[
              const Text(
                'IDEAS & ALERTS',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.2,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              ...advisory.map(
                (task) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AdvisoryCard(task: task),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _AdvisoryCard extends StatelessWidget {
  final AgentTaskModel task;

  const _AdvisoryCard({required this.task});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                const Icon(Icons.lightbulb_outline, size: 18, color: Colors.amber),
              ],
            ),
            const SizedBox(height: 4),
            Text(task.description, style: Theme.of(context).textTheme.bodySmall),
            if (task.reasoning.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Reasoning: ${task.reasoning}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  final AgentTaskModel task;
  final AgentTaskProvider taskProvider;

  const _ApprovalCard({required this.task, required this.taskProvider});

  Widget _buildDiffPreview(BuildContext context, AgentTaskModel task) {
    final payload = task.payload;
    final diff =
        (payload['diff'] as Map<String, dynamic>?) ??
        (payload['productDraft'] as Map<String, dynamic>?);

    if (diff == null || diff.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PROPOSED CHANGES',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
          ),
          const SizedBox(height: 8),
          ...diff.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.key}: ',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  Expanded(child: Text('${entry.value}', style: const TextStyle(fontSize: 12))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final acting = taskProvider.isActingOn(task.id);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(task.description),
            if (task.reasoning.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Why: ${task.reasoning}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
            if (task.type == 'catalog_improvement' || task.type == 'product_draft') ...[
              const SizedBox(height: 12),
              _buildDiffPreview(context, task),
            ],
            if (task.evidence.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: task.evidence
                    .map(
                      (e) => Chip(
                        label: Text('${e.label}: ${e.value}', style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: acting ? null : () => taskProvider.rejectTask(task.id),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: acting ? null : () => taskProvider.approveTask(task.id),
                  child: acting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Approve'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportsTab extends StatelessWidget {
  const _ReportsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportProvider>(
      builder: (context, reportProvider, _) {
        if (reportProvider.isLoading) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent));
        }

        if (reportProvider.reports.isEmpty) {
          return const _PlaceholderTab(
            icon: Icons.bar_chart,
            title: 'No reports yet',
            subtitle:
                'The Business Analyst posts a daily report every morning '
                'and a weekly report on Mondays. Check back soon.',
          );
        }

        final isHindi = Provider.of<AccessibilityProvider>(context).isHindi;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reportProvider.reports.length,
          itemBuilder: (context, index) {
            final report = reportProvider.reports[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ReportCard(report: report, isHindi: isHindi),
            );
          },
        );
      },
    );
  }
}

class _ReportCard extends StatelessWidget {
  final ReportModel report;
  final bool isHindi;

  const _ReportCard({required this.report, required this.isHindi});

  @override
  Widget build(BuildContext context) {
    final dateStr = report.generatedAt != null
        ? DateFormat('EEE, d MMM • h:mm a').format(report.generatedAt!.toLocal())
        : '';

    final narrative = isHindi ? report.narrativeHi : report.narrativeEn;
    final snippet = narrative.length > 140 ? '${narrative.substring(0, 140)}…' : narrative;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => _ReportReaderScreen(report: report)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    report.isWeekly ? Icons.calendar_view_week : Icons.today,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      report.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  if (report.anomalies.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 14,
                            color: AppTheme.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${report.anomalies.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              if (dateStr.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(dateStr, style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 8),
              Text(snippet, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      label: 'Revenue',
                      value: '₹${report.revenue.toStringAsFixed(0)}',
                      pct: report.revenuePctDelta,
                    ),
                  ),
                  Expanded(
                    child: _MiniStat(
                      label: 'Orders',
                      value: '${report.orderCount}',
                      pct: report.orderCountPctDelta,
                    ),
                  ),
                  Expanded(
                    child: _MiniStat(
                      label: 'AOV',
                      value: '₹${report.aov.toStringAsFixed(0)}',
                      pct: report.aovPctDelta,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final double? pct;

  const _MiniStat({required this.label, required this.value, this.pct});

  @override
  Widget build(BuildContext context) {
    Color? pctColor;
    String pctStr = '';
    if (pct != null) {
      pctColor = pct! >= 0 ? AppTheme.success : AppTheme.error;
      pctStr = '${pct! >= 0 ? '+' : ''}${pct!.toStringAsFixed(1)}%';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        if (pctStr.isNotEmpty)
          Text(
            pctStr,
            style: TextStyle(fontSize: 11, color: pctColor, fontWeight: FontWeight.w600),
          ),
      ],
    );
  }
}

class _ReportReaderScreen extends StatefulWidget {
  final ReportModel report;

  const _ReportReaderScreen({required this.report});

  @override
  State<_ReportReaderScreen> createState() => _ReportReaderScreenState();
}

class _ReportReaderScreenState extends State<_ReportReaderScreen> {
  late bool _isHindi;

  @override
  void initState() {
    super.initState();
    _isHindi = Provider.of<AccessibilityProvider>(context, listen: false).isHindi;
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final dateStr = report.generatedAt != null
        ? DateFormat('EEEE, d MMMM yyyy • h:mm a').format(report.generatedAt!.toLocal())
        : '';
    final narrative = _isHindi ? report.narrativeHi : report.narrativeEn;

    return Scaffold(
      appBar: AppBar(
        title: Text(report.title),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: ToggleButtons(
                isSelected: [!_isHindi, _isHindi],
                onPressed: (index) => setState(() => _isHindi = index == 1),
                borderRadius: BorderRadius.circular(8),
                constraints: const BoxConstraints(minHeight: 32, minWidth: 44),
                children: const [Text('EN'), Text('हिं')],
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (dateStr.isNotEmpty) Text(dateStr, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          if (narrative.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(narrative, style: const TextStyle(fontSize: 15, height: 1.4)),
              ),
            ),
          if (report.anomalies.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Things to watch', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...report.anomalies.map((a) => _AnomalyTile(anomaly: a, isHindi: _isHindi)),
          ],
          if (report.insights.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Insights', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: report.insights
                      .map(
                        (insight) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.lightbulb_outline, size: 20),
                          title: Text(insight),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text('This period vs previous', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _ComparisonBar(
                    label: 'Revenue',
                    current: report.revenue,
                    previous: report.previousRevenue,
                    prefix: '₹',
                  ),
                  const SizedBox(height: 12),
                  _ComparisonBar(
                    label: 'Orders',
                    current: report.orderCount.toDouble(),
                    previous: report.previousOrderCount.toDouble(),
                  ),
                  const SizedBox(height: 12),
                  _ComparisonBar(
                    label: 'Avg. Order Value',
                    current: report.aov,
                    previous: report.previousAov,
                    prefix: '₹',
                  ),
                ],
              ),
            ),
          ),
          if (report.topProducts.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Top products', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (var i = 0; i < report.topProducts.length; i++)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: i == report.topProducts.length - 1 ? 0 : 12,
                        ),
                        child: _ProductBar(
                          entry: report.topProducts[i],
                          maxValue: report.topProducts
                              .map((p) => p.revenue)
                              .reduce((a, b) => a > b ? a : b),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatTile(label: 'New customers', value: '${report.newCustomers}'),
              ),
              Expanded(
                child: _StatTile(label: 'Low stock items', value: '${report.lowStockCount}'),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _AnomalyTile extends StatelessWidget {
  final ReportAnomaly anomaly;
  final bool isHindi;

  const _AnomalyTile({required this.anomaly, required this.isHindi});

  Color _severityColor() {
    switch (anomaly.severity) {
      case 'critical':
        return AppTheme.error;
      case 'high':
        return AppTheme.warning;
      default:
        return AppTheme.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = isHindi ? anomaly.messageHi : anomaly.messageEn;
    final color = _severityColor();

    return Card(
      color: color.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message.isNotEmpty ? message : anomaly.type)),
          ],
        ),
      ),
    );
  }
}

class _ComparisonBar extends StatelessWidget {
  final String label;
  final double current;
  final double previous;
  final String prefix;

  const _ComparisonBar({
    required this.label,
    required this.current,
    required this.previous,
    this.prefix = '',
  });

  @override
  Widget build(BuildContext context) {
    final maxValue = [current, previous, 1.0].reduce((a, b) => a > b ? a : b);
    final currentRatio = (current / maxValue).clamp(0.0, 1.0);
    final previousRatio = (previous / maxValue).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(
          children: [
            SizedBox(width: 64, child: Text('Now', style: Theme.of(context).textTheme.bodySmall)),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: currentRatio,
                  minHeight: 10,
                  backgroundColor: Colors.grey.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('$prefix${_fmt(current)}'),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            SizedBox(
              width: 64,
              child: Text('Before', style: Theme.of(context).textTheme.bodySmall),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: previousRatio,
                  minHeight: 10,
                  backgroundColor: Colors.grey.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation(Colors.grey),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('$prefix${_fmt(previous)}'),
          ],
        ),
      ],
    );
  }

  String _fmt(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }
}

class _ProductBar extends StatelessWidget {
  final ReportProductEntry entry;
  final double maxValue;

  const _ProductBar({required this.entry, required this.maxValue});

  @override
  Widget build(BuildContext context) {
    final ratio = maxValue > 0 ? (entry.revenue / maxValue).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                entry.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '₹${entry.revenue.toStringAsFixed(0)} · ${entry.quantity.toStringAsFixed(0)} units',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: Colors.grey.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PlaceholderTab({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _BroadcastsTab extends StatelessWidget {
  const _BroadcastsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<BroadcastProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent));
        }

        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BroadcastComposeScreen()),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Compose'),
            backgroundColor: AppTheme.ownerAccent,
            foregroundColor: Colors.white,
          ),
          body: provider.broadcasts.isEmpty
              ? const _PlaceholderTab(
                  icon: Icons.campaign_outlined,
                  title: 'No Broadcasts Yet',
                  subtitle:
                      'Use Compose to write a message, or wait for the Comms agent to draft one.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.broadcasts.length,
                  itemBuilder: (context, index) {
                    final broadcast = provider.broadcasts[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _BroadcastCard(broadcast: broadcast, provider: provider),
                    );
                  },
                ),
        );
      },
    );
  }
}

class _BroadcastCard extends StatelessWidget {
  final BroadcastModel broadcast;
  final BroadcastProvider provider;

  const _BroadcastCard({required this.broadcast, required this.provider});

  @override
  Widget build(BuildContext context) {
    final dateStr = broadcast.createdAt != null
        ? DateFormat('d MMM • h:mm a').format(broadcast.createdAt!.toLocal())
        : '';

    final sending = provider.isSending(broadcast.id);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    broadcast.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(broadcast.status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    broadcast.status.name.toUpperCase(),
                    style: TextStyle(
                      color: _statusColor(broadcast.status),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (dateStr.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(dateStr, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            Text(broadcast.body),
            const SizedBox(height: 12),
            Row(
              children: [
                _miniMetric('Sent', '${broadcast.stats.delivered}'),
                const SizedBox(width: 16),
                _miniMetric('Opened', '${broadcast.stats.opened}'),
                const SizedBox(width: 16),
                _miniMetric('Clicked', '${broadcast.stats.clicked}'),
                const Spacer(),
                if (broadcast.status == BroadcastStatus.draft)
                  FilledButton(
                    onPressed: sending ? null : () => _send(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.ownerAccent,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Send Now'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Color _statusColor(BroadcastStatus status) {
    switch (status) {
      case BroadcastStatus.sent:
        return AppTheme.success;
      case BroadcastStatus.sending:
        return AppTheme.ownerAccent;
      case BroadcastStatus.scheduled:
        return AppTheme.warning;
      case BroadcastStatus.cancelled:
        return Colors.red;
      case BroadcastStatus.draft:
        return Colors.grey;
    }
  }

  Future<void> _send(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Send', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Send this broadcast to all targeted users immediately?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Send')),
        ],
      ),
    );

    if (confirmed == true) {
      final ok = await provider.sendBroadcast(broadcast.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? 'Broadcast triggered.' : 'Failed to trigger broadcast.')),
        );
      }
    }
  }
}
