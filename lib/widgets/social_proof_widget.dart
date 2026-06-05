import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_theme.dart';

/// Social Proof Widget — "X people bought this in last 24 hours"
///
/// Drives urgency and trust by showing real-time purchase activity.
/// Updates every 60 seconds using Firestore count aggregation.
/// Falls back to cached value if offline.
class SocialProofWidget extends StatefulWidget {
  final String productId;
  final bool compact;

  const SocialProofWidget({
    super.key,
    required this.productId,
    this.compact = false,
  });

  @override
  State<SocialProofWidget> createState() => _SocialProofWidgetState();
}

class _SocialProofWidgetState extends State<SocialProofWidget> {
  int _count = 0;
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchCount();
    // Refresh every 60 s
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 60), (_) => _fetchCount());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchCount() async {
    try {
      final cutoff = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(hours: 24)),
      );
      final snap = await FirebaseFirestore.instance
          .collection('order_items')
          .where('productId', isEqualTo: widget.productId)
          .where('createdAt', isGreaterThan: cutoff)
          .count()
          .get();

      if (mounted) {
        setState(() {
          _count = snap.count ?? 0;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _count == 0) return const SizedBox.shrink();

    final label = _count == 1
        ? '1 person bought this today'
        : '$_count people bought this in 24h';

    if (widget.compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department,
              size: 14, color: Color(0xFFFF5722)),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFFF5722),
                  fontWeight: FontWeight.w600)),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department,
              size: 16, color: Color(0xFFFF5722)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFFE64A19),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Live viewer count — "X people are viewing this right now"
/// Uses Firestore ephemeral presence tracking.
class LiveViewerCount extends StatefulWidget {
  final String productId;
  const LiveViewerCount({super.key, required this.productId});

  @override
  State<LiveViewerCount> createState() => _LiveViewerCountState();
}

class _LiveViewerCountState extends State<LiveViewerCount> {
  StreamSubscription? _sub;
  int _viewers = 0;

  @override
  void initState() {
    super.initState();
    _trackPresence();
  }

  void _trackPresence() {
    final ref = FirebaseFirestore.instance
        .collection('product_presence')
        .doc(widget.productId);

    // Register this viewer
    final visitorId = DateTime.now().millisecondsSinceEpoch.toString();
    ref.collection('viewers').doc(visitorId).set({
      'activeAt': FieldValue.serverTimestamp(),
    });

    // Watch viewer count (last 2 min)
    final cutoff = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(minutes: 2)),
    );
    _sub = ref
        .collection('viewers')
        .where('activeAt', isGreaterThan: cutoff)
        .snapshots()
        .listen((snap) {
      if (mounted) setState(() => _viewers = snap.docs.length);
    });

    // Cleanup on dispose
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_viewers < 2) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.visibility_outlined, size: 13, color: AppTheme.grey500),
        const SizedBox(width: 4),
        Text(
          '$_viewers viewing now',
          style:
              const TextStyle(fontSize: 11, color: AppTheme.grey500),
        ),
      ],
    );
  }
}
