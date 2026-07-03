import 'package:cloud_firestore/cloud_firestore.dart';

/// A top product entry inside `metrics.topProducts` / `chartData.topProducts`.
class ReportProductEntry {
  final String name;
  final double quantity;
  final double revenue;

  const ReportProductEntry({required this.name, this.quantity = 0, this.revenue = 0});

  factory ReportProductEntry.fromMap(Map<String, dynamic> map) {
    return ReportProductEntry(
      name: map['name']?.toString() ?? map['productId']?.toString() ?? 'Unknown',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
      revenue: (map['revenue'] as num?)?.toDouble() ?? (map['value'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// A flagged anomaly from `metrics.anomalies`.
class ReportAnomaly {
  final String type;
  final String severity;
  final String messageEn;
  final String messageHi;

  const ReportAnomaly({
    required this.type,
    required this.severity,
    required this.messageEn,
    required this.messageHi,
  });

  factory ReportAnomaly.fromMap(Map<String, dynamic> map) {
    return ReportAnomaly(
      type: map['type']?.toString() ?? '',
      severity: map['severity']?.toString() ?? 'low',
      messageEn: map['message_en']?.toString() ?? '',
      messageHi: map['message_hi']?.toString() ?? '',
    );
  }
}

/// A `reports/{id}` document produced by the Business Analyst agent
/// (see `runGenerateReport` in agentToolExecutor.ts).
class ReportModel {
  final String id;
  final String? period; // 'daily' | 'weekly' | null
  final String type; // 'daily_summary' | 'weekly_summary' | 'adhoc'
  final DateTime? generatedAt;
  final String agentId;
  final String narrativeEn;
  final String narrativeHi;
  final List<String> insights;

  // Flattened metrics commonly used by the UI.
  final double revenue;
  final double previousRevenue;
  final int orderCount;
  final int previousOrderCount;
  final double aov;
  final double previousAov;
  final int newCustomers;
  final int lowStockCount;
  final List<ReportProductEntry> topProducts;
  final List<ReportAnomaly> anomalies;
  final double? revenuePctDelta;
  final double? orderCountPctDelta;
  final double? aovPctDelta;

  const ReportModel({
    required this.id,
    this.period,
    required this.type,
    this.generatedAt,
    required this.agentId,
    required this.narrativeEn,
    required this.narrativeHi,
    required this.insights,
    required this.revenue,
    required this.previousRevenue,
    required this.orderCount,
    required this.previousOrderCount,
    required this.aov,
    required this.previousAov,
    required this.newCustomers,
    required this.lowStockCount,
    required this.topProducts,
    required this.anomalies,
    this.revenuePctDelta,
    this.orderCountPctDelta,
    this.aovPctDelta,
  });

  factory ReportModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final metrics = data['metrics'] as Map<String, dynamic>? ?? const {};
    final chartData = data['chartData'] as Map<String, dynamic>? ?? const {};
    final deltas = metrics['deltas'] as Map<String, dynamic>? ?? const {};

    final rawTopProducts =
        metrics['topProducts'] as List<dynamic>? ??
        (chartData['topProducts'] as List<dynamic>?) ??
        const [];

    final rawInsights = data['insights'] as List<dynamic>? ?? const [];
    final rawAnomalies = metrics['anomalies'] as List<dynamic>? ?? const [];

    final revenueChart = chartData['revenue'] as Map<String, dynamic>?;
    final orderCountChart = chartData['orderCount'] as Map<String, dynamic>?;
    final aovChart = chartData['aov'] as Map<String, dynamic>?;

    return ReportModel(
      id: doc.id,
      period: data['period'] as String?,
      type: data['type']?.toString() ?? 'adhoc',
      generatedAt: (data['generatedAt'] as Timestamp?)?.toDate(),
      agentId: data['agentId']?.toString() ?? '',
      narrativeEn: data['narrative_en']?.toString() ?? '',
      narrativeHi: data['narrative_hi']?.toString() ?? '',
      insights: rawInsights.map((e) => e.toString()).toList(),
      revenue:
          (metrics['revenue'] as num?)?.toDouble() ??
          (revenueChart?['current'] as num?)?.toDouble() ??
          0,
      previousRevenue: (revenueChart?['previous'] as num?)?.toDouble() ?? 0,
      orderCount:
          (metrics['orderCount'] as num?)?.toInt() ??
          (orderCountChart?['current'] as num?)?.toInt() ??
          0,
      previousOrderCount: (orderCountChart?['previous'] as num?)?.toInt() ?? 0,
      aov: (metrics['aov'] as num?)?.toDouble() ?? (aovChart?['current'] as num?)?.toDouble() ?? 0,
      previousAov: (aovChart?['previous'] as num?)?.toDouble() ?? 0,
      newCustomers: (metrics['newCustomers'] as num?)?.toInt() ?? 0,
      lowStockCount: (metrics['lowStockCount'] as num?)?.toInt() ?? 0,
      topProducts: rawTopProducts
          .whereType<Map<String, dynamic>>()
          .map(ReportProductEntry.fromMap)
          .toList(),
      anomalies: rawAnomalies.whereType<Map<String, dynamic>>().map(ReportAnomaly.fromMap).toList(),
      revenuePctDelta: (deltas['revenuePct'] as num?)?.toDouble(),
      orderCountPctDelta: (deltas['orderCountPct'] as num?)?.toDouble(),
      aovPctDelta: (deltas['aovPct'] as num?)?.toDouble(),
    );
  }

  bool get isDaily => period == 'daily';
  bool get isWeekly => period == 'weekly';

  String get title {
    if (isDaily) return 'Daily Report';
    if (isWeekly) return 'Weekly Report';
    return 'Report';
  }
}
