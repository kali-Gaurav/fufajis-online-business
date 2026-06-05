// ============================================================
//  DeviceManagementScreen — Owner Security › Devices
//
//  Shows all registered devices for this owner account.
//  Actions per device:
//  • Approve pending device
//  • Rename device
//  • Revoke / remove device (triggers remote logout + audit log)
//
//  Real-time update via AuthProvider stream (Firestore-backed).
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../services/owner_auth_service.dart';
import '../../services/audit_service.dart';
import '../../services/security_event_service.dart';
import '../../services/device_security_service.dart';
import '../../utils/app_theme.dart';

class DeviceManagementScreen extends StatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  State<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  String? _currentDeviceId;

  @override
  void initState() {
    super.initState();
    _loadCurrentDevice();
  }

  Future<void> _loadCurrentDevice() async {
    final id = await DeviceSecurityService.getDeviceId();
    if (mounted) setState(() => _currentDeviceId = id);
  }

  // ── Approve pending device ─────────────────────────────────
  Future<void> _approveDevice(
      String email, String deviceId, String deviceName) async {
    final confirmed = await _confirm(
      title: 'Approve Device',
      content:
          'Allow "$deviceName" to access Fufaji Business?\n\n'
          'This device will be able to log in once approved.',
      confirmLabel: 'Approve',
      confirmColor: Colors.green,
    );
    if (!confirmed) return;

    await OwnerAuthService.approveDevice(email, deviceId);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    await AuditService().logDeviceApproved(
      byUserId: auth.currentUser?.id ?? '',
      byUserName: auth.currentUser?.name ?? 'Owner',
      deviceId: deviceId,
      deviceName: deviceName,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$deviceName" approved.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // ── Revoke / remove device ─────────────────────────────────
  Future<void> _revokeDevice(
      String email, String deviceId, String deviceName) async {
    final confirmed = await _confirm(
      title: 'Remove Device',
      content:
          'Remove "$deviceName"?\n\n'
          'This device will be logged out immediately and will require '
          're-approval to access again.',
      confirmLabel: 'Remove',
      confirmColor: AppTheme.error,
    );
    if (!confirmed) return;

    await OwnerAuthService.removeDevice(email, deviceId);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    await AuditService().logDeviceRevoked(
      byUserId: auth.currentUser?.id ?? '',
      byUserName: auth.currentUser?.name ?? 'Owner',
      deviceId: deviceId,
      deviceName: deviceName,
    );
    await SecurityEventService().logEvent(
      event: SecurityEventType.deviceRevoked,
      userId: auth.currentUser?.id,
      metadata: {'deviceId': deviceId, 'deviceName': deviceName},
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$deviceName" removed.'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  // ── Rename device ──────────────────────────────────────────
  Future<void> _renameDevice(
      String email, String deviceId, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Device'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Device Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == currentName) return;
    await OwnerAuthService.renameDevice(email, deviceId, newName);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device renamed.')),
      );
    }
  }

  // ── Confirm dialog ─────────────────────────────────────────
  Future<bool> _confirm({
    required String title,
    required String content,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(content, style: const TextStyle(height: 1.5)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: confirmColor,
                    foregroundColor: Colors.white),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final auth    = Provider.of<AuthProvider>(context);
    final email   = auth.currentUser?.email ?? '';
    final devices = auth.currentUser?.approvedDevices ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trusted Devices'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Device Management'),
                content: const Text(
                  'Only approved devices can access the Owner Dashboard.\n\n'
                  'Removing a device logs it out immediately and requires '
                  're-approval before it can log in again.',
                  style: TextStyle(height: 1.5),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Got it'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: devices.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: devices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final device = devices[i];
                final isCurrent = device.deviceId == _currentDeviceId;
                final isPending = !device.approved;
                return _DeviceTile(
                  device: device,
                  isCurrent: isCurrent,
                  isPending: isPending,
                  onApprove: isPending
                      ? () => _approveDevice(email, device.deviceId, device.deviceName)
                      : null,
                  onRename: (!isPending && !isCurrent)
                      ? () => _renameDevice(email, device.deviceId, device.deviceName)
                      : null,
                  onRevoke: !isCurrent
                      ? () => _revokeDevice(email, device.deviceId, device.deviceName)
                      : null,
                );
              },
            ),
    );
  }
}

// ── Device tile ────────────────────────────────────────────────
class _DeviceTile extends StatelessWidget {
  final DeviceFingerprint device;
  final bool isCurrent;
  final bool isPending;
  final VoidCallback? onApprove;
  final VoidCallback? onRename;
  final VoidCallback? onRevoke;

  const _DeviceTile({
    required this.device,
    required this.isCurrent,
    required this.isPending,
    this.onApprove,
    this.onRename,
    this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isPending
              ? AppTheme.warning
              : isCurrent
                  ? AppTheme.primary
                  : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──────────────────────────────────
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isPending
                      ? AppTheme.warning.withValues(alpha: 0.15)
                      : AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.phone_android,
                  color: isPending ? AppTheme.warning : AppTheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          device.deviceName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      if (isCurrent)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'This device',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 3),
                    Row(children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isPending ? AppTheme.warning : Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isPending ? 'Pending Approval' : 'Approved',
                        style: TextStyle(
                            fontSize: 12,
                            color: isPending ? AppTheme.warning : Colors.green,
                            fontWeight: FontWeight.w600),
                      ),
                    ]),
                    const SizedBox(height: 2),
                    Text(
                      'Added ${device.registeredAt.day}/${device.registeredAt.month}/${device.registeredAt.year}',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.grey500),
                    ),
                  ],
                ),
              ),
            ]),

            // ── Action row ───────────────────────────────────
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            if (isCurrent)
              const Text(
                'You cannot remove the device you are currently using.',
                style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.grey400,
                    fontStyle: FontStyle.italic),
              )
            else
              Row(children: [
                if (onApprove != null) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check_circle_outline,
                          size: 18, color: Colors.green),
                      label: const Text('Approve',
                          style: TextStyle(color: Colors.green)),
                      style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.green)),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (onRename != null) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onRename,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Rename'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.grey700),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (onRevoke != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onRevoke,
                      icon: const Icon(Icons.remove_circle_outline,
                          size: 18, color: AppTheme.error),
                      label: const Text('Remove',
                          style: TextStyle(color: AppTheme.error)),
                      style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.error)),
                    ),
                  ),
              ]),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.devices_other, size: 72, color: AppTheme.grey300),
            SizedBox(height: 20),
            Text(
              'No devices registered',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey700),
            ),
            SizedBox(height: 8),
            Text(
              'Devices appear here when you log in from new devices.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.grey500, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
