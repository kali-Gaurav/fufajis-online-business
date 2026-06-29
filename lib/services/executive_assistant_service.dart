import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/executive_insight_model.dart';
import 'audit_logger.dart';

class ExecutiveAssistantService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuditLoggerService _auditLogger = AuditLoggerService();

  /// Ask a question to the Executive AI
  Future<ExecutiveInsightModel> askQuestion(String question, String ownerId) async {
    try {
      // Log the query
      await _auditLogger.logAdminAction(
        'Executive AI Queried',
        targetUserId: ownerId,
        metadata: {'question': question},
      );

      // In production, we would invoke an HTTPS Cloud Function that connects to Gemini 
      // passing the context (orders, inventory, etc).
      // Here, we simulate the AI's response based on keywords.

      await Future.delayed(const Duration(seconds: 2)); // Simulate network / AI processing time

      String insightType = 'General Analysis';
      String summary = 'Based on the current data, operations are proceeding normally. No critical anomalies detected.';
      List<String> primaryCauses = [];

      if (question.toLowerCase().contains('revenue')) {
        insightType = 'Revenue Analysis';
        summary = 'Revenue dropped 12% compared to last week.';
        primaryCauses = [
          'Rice inventory shortage leading to stockouts',
          '8% fewer repeat customers',
          'Delivery delays increased 15% due to traffic bottlenecks'
        ];
      } else if (question.toLowerCase().contains('inventory') || question.toLowerCase().contains('stock')) {
        insightType = 'Inventory Health';
        summary = 'Inventory levels are moderately healthy, but we are facing shortages in staples.';
        primaryCauses = [
          'Supplier delays for Rice 1kg',
          'Sudden 20% spike in demand for Milk'
        ];
      } else if (question.toLowerCase().contains('employee') || question.toLowerCase().contains('staff')) {
        insightType = 'Staff Performance';
        summary = 'Overall employee efficiency is at 88%.';
        primaryCauses = [
          'High performance from evening shift',
          'Slight drop in attendance score for delivery riders'
        ];
      }

      final docRef = _firestore.collection('executive_insights').doc();
      final insight = ExecutiveInsightModel(
        id: docRef.id,
        insightType: insightType,
        summary: summary,
        primaryCauses: primaryCauses,
        timestamp: DateTime.now(),
      );

      await docRef.set(insight.toMap());
      return insight;
    } catch (e) {
      debugPrint('[ExecutiveAI] Error processing question: $e');
      throw Exception('Failed to communicate with AI Assistant.');
    }
  }
}
