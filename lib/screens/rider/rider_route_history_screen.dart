import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';

/// Task #97 — Rider Route History Screen
///
/// Shows the current rider's completed trips grouped by day:
///  - Delivery count per trip
///  - Earnings per trip
///  - Duration
///  - Date/time
class RiderRouteHistoryScreen extends StatefulWidget {
  const RiderRouteHistoryScreen({super.key});

  @override
  State<RiderRouteHistoryScreen> createState() => _RiderRouteHistoryScreenState();
}

class _RiderRouteHistoryScreenState extends State<RiderRouteHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final authP = context.read<AuthProvider>();
    final riderId = authP.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Delivery History')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('delivery_trips')
            .where('riderId', isEqualTo: riderId)
            .where('status', isEqualTo: 'completed')
            .orderBy('endedAt', descending: true)
            .limit(60)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.route, size: 64, color: Colors.grey),
                SizedBox(height: 12),
                Text('No completed trips yet', style: TextStyle(color: Colors.grey)),
              ]),
            );
          }

          // Group by date
          final Map<String, List<QueryDocumentSnapshot>> byDate = {};
          for (final doc in docs) {
            final d = doc.data() as Map<String, dynamic>;
            final dt = (d['endedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            final key = DateFormat('yyyy-MM-dd').format(dt);
            byDate.putIfAbsent(key, () => []).add(doc);
          }

          final sortedDates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: sortedDates.length,
            itemBuilder: (ctx, i) {
              final dateKey = sortedDates[i];
              final trips = byDate[dateKey]!;
              final parsedDate = DateTime.parse(dateKey);
              final isToday = dateKey == DateFormat('yyyy-MM-dd').format(DateTime.now());

              // Day totals
              double dayEarnings = 0;
              int dayDeliveries = 0;
              for (final t in trips) {
                final td = t.data() as Map<String, dynamic>;
                dayEarnings += (td['earnings'] as num?)?.toDouble() ?? 0;
                dayDeliveries += (td['deliveryCount'] as num?)?.toInt() ?? 0;
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Row(children: [
                      Text(
                        isToday ? 'Today' : DateFormat('EEE, dd MMM').format(parsedDate),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const Spacer(),
                      Text(
                        '$dayDeliveries deliveries · ₹${dayEarnings.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ]),
                  ),
                  ...trips.map((t) {
                    final td = t.data() as Map<String, dynamic>;
                    final startedAt = (td['startedAt'] as Timestamp?)?.toDate();
                    final endedAt   = (td['endedAt']   as Timestamp?)?.toDate();
                    final earnings = (td['earnings'] as num?)?.toDouble() ?? 0;
                    final deliveries = (td['deliveryCount'] as num?)?.toInt() ?? 0;
                    final duration = (startedAt != null && endedAt != null)
                        ? endedAt.difference(startedAt).inMinutes
                        : 0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 42, height: 42,
                              decoration: BoxDecoration(
                                color: AppTheme.ownerAccent.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text('$deliveries',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18,
                                        color: AppTheme.ownerAccent)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$deliveries deliver${deliveries == 1 ? 'y' : 'ies'}',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    startedAt != null
                                        ? '${DateFormat('HH:mm').format(startedAt)} – '
                                          '${endedAt != null ? DateFormat('HH:mm').format(endedAt) : '?'}'
                                          '  ($duration min)'
                                        : 'Time not recorded',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${earnings.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800, fontSize: 16,
                                      color: AppTheme.success),
                                ),
                                const Text('earned',
                                    style: TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
