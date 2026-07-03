import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/rider_shift_model.dart';

// import 'rider_map_screen.dart';

class RiderShell extends StatefulWidget {
  final Widget child;
  const RiderShell({super.key, required this.child});

  @override
  State<RiderShell> createState() => _RiderShellState();
}

class _RiderShellState extends State<RiderShell> {
  int _currentIndex = 0;
  final bool _isOfflineSynced = true; // Mock state
  RiderShiftState _shiftState = RiderShiftState.offline;

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;

    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(
        title: const Text(
          'Rider Command Center',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppTheme.cream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.sos, color: AppTheme.error, size: 30),
          onPressed: () {
            // Trigger SOS Workflow
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('SOS Triggered. Dispatcher Alerted.')));
          },
        ),
        actions: [
          // Offline Sync Indicator
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Icon(
              _isOfflineSynced ? Icons.cloud_done : Icons.cloud_sync,
              color: _isOfflineSynced ? AppTheme.success : AppTheme.warning,
              size: 20,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                Text(
                  _shiftState == RiderShiftState.offline ? 'Offline' : 'Online',
                  style: TextStyle(
                    color: _shiftState == RiderShiftState.offline ? Colors.grey : AppTheme.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: _shiftState != RiderShiftState.offline,
                  onChanged: (val) async {
                    setState(() {
                      _shiftState = val ? RiderShiftState.available : RiderShiftState.offline;
                    });
                    if (user != null) {
                      try {
                        await Provider.of<AuthProvider>(
                          context,
                          listen: false,
                        ).updateOnlineStatus(val);
                      } catch (e) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(const SnackBar(content: Text('Failed to update status')));
                      }
                    }
                  },
                  activeThumbColor: AppTheme.success,
                ),
              ],
            ),
          ),
        ],
      ),
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: AppTheme.grey400,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Tasks'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Earnings'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.route), label: 'History'),
        ],
      ),
    );
  }
}
