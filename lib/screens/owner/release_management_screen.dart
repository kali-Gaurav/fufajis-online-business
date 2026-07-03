import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/release_note_model.dart';
import '../../services/remote_config_service.dart';
import '../../utils/app_theme.dart';

class ReleaseManagementScreen extends StatefulWidget {
  const ReleaseManagementScreen({super.key});

  @override
  State<ReleaseManagementScreen> createState() => _ReleaseManagementScreenState();
}

class _ReleaseManagementScreenState extends State<ReleaseManagementScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final RemoteConfigService _remoteConfig = RemoteConfigService();

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Release & Adoption', style: TextStyle(fontWeight: FontWeight.w700)),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Adoption Stats'),
              Tab(text: 'Release Notes'),
              Tab(text: 'Remote Config'),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildAdoptionStatsTab(), _buildReleaseNotesTab(), _buildRemoteConfigTab()],
        ),
      ),
    );
  }

  Widget _buildAdoptionStatsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent));

        final users = snapshot.data!.docs;
        final Map<String, int> versionCounts = {};

        for (var doc in users) {
          final data = doc.data() as Map<String, dynamic>;
          final version = data['appVersion'] ?? 'Unknown';
          versionCounts[version] = (versionCounts[version] ?? 0) + 1;
        }

        final sortedVersions = versionCounts.entries.toList()
          ..sort((a, b) => b.key.compareTo(a.key));

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildStatSummaryCard(users.length, versionCounts),
            const SizedBox(height: 24),
            const Text(
              'Version Distribution',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...sortedVersions.map(
              (entry) => _buildVersionRow(entry.key, entry.value, users.length),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatSummaryCard(int totalUsers, Map<String, int> counts) {
    final latestVersion = _remoteConfig.latestAppVersion;
    final updatedUsers = counts[latestVersion] ?? 0;
    final adoptionRate = totalUsers > 0 ? (updatedUsers / totalUsers * 100) : 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _statItem('Total Users', totalUsers.toString()),
              _statItem('On Latest (v$latestVersion)', updatedUsers.toString()),
            ],
          ),
          const Divider(color: Colors.white24, height: 32),
          Text(
            '${adoptionRate.toStringAsFixed(1)}% Adoption Rate',
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: adoptionRate / 100,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildVersionRow(String version, int count, int total) {
    final percent = (count / total * 100).toStringAsFixed(1);
    final isLatest = version == _remoteConfig.latestAppVersion;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 80,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isLatest ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.grey200,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'v$version',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isLatest ? AppTheme.success : AppTheme.grey700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppTheme.grey100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: count / total,
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: isLatest ? AppTheme.success : AppTheme.primary.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text('$count ($percent%)', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildReleaseNotesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('release_notes').orderBy('date', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent));

        final notes = snapshot.data!.docs
            .map((doc) => ReleaseNote.fromMap(doc.data() as Map<String, dynamic>))
            .toList();

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ElevatedButton.icon(
              onPressed: _showAddReleaseNoteDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Release Note'),
            ),
            const SizedBox(height: 20),
            ...notes.map(
              (note) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text('v${note.version} - ${note.title}'),
                  subtitle: Text(DateFormat('dd MMM yyyy').format(note.date)),
                  trailing: const Icon(Icons.edit),
                  onTap: () => _showAddReleaseNoteDialog(note: note),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAddReleaseNoteDialog({ReleaseNote? note}) {
    final versionController = TextEditingController(text: note?.version);
    final titleController = TextEditingController(text: note?.title);
    final notesController = TextEditingController(text: note?.notes.join('\n'));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(note == null ? 'Add Release Note' : 'Edit Release Note'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: versionController,
                decoration: const InputDecoration(labelText: 'Version (e.g. 1.3.0)'),
              ),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: notesController,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Notes (one per line)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newNote = ReleaseNote(
                version: versionController.text,
                date: DateTime.now(),
                title: titleController.text,
                notes: notesController.text.split('\n').where((s) => s.trim().isNotEmpty).toList(),
              );
              await _db.collection('release_notes').doc(newNote.version).set(newNote.toMap());
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildRemoteConfigTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Active Controls (Read Only)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _configItem('Latest Version', _remoteConfig.latestAppVersion),
        _configItem('Minimum Version', _remoteConfig.minAppVersion),
        _configItem('Maintenance Mode', _remoteConfig.isMaintenanceMode.toString()),
        _configItem('Show Ads', _remoteConfig.showAds.toString()),
        const SizedBox(height: 24),
        const Text(
          'Note: To change these, update values in the Firebase Remote Config Console.',
          style: TextStyle(fontSize: 12, color: AppTheme.grey500),
        ),
      ],
    );
  }

  Widget _configItem(String label, String value) {
    return ListTile(
      title: Text(label),
      trailing: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
      ),
    );
  }
}
