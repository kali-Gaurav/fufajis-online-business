import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../errors/app_exceptions.dart';

class RetryConfig {
  final int maxRetries;
  final List<Duration> backoffIntervals;

  const RetryConfig({
    this.maxRetries = 4,
    this.backoffIntervals = const [
      Duration(seconds: 1),
      Duration(seconds: 5),
      Duration(seconds: 15),
      Duration(seconds: 60),
    ],
  });
}

class RetryEngine {
  final FirebaseFirestore _db;

  RetryEngine({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  Future<T> executeWithRetry<T>({
    required String operationName,
    required Future<T> Function() operation,
    required Map<String, dynamic> payload,
    RetryConfig config = const RetryConfig(),
  }) async {
    int attempts = 0;

    while (attempts <= config.maxRetries) {
      try {
        if (attempts > 0) {
          debugPrint('[$operationName] Retry attempt $attempts...');
        }
        return await operation();
      } catch (e, stackTrace) {
        if (attempts >= config.maxRetries) {
          debugPrint(
            '[$operationName] Exhausted all ${config.maxRetries} retries. Moving to Dead Letter Queue.',
          );
          await _sendToDeadLetterQueue(
            operationName: operationName,
            payload: payload,
            error: e,
            stackTrace: stackTrace,
          );
          throw ErrorMapper.map(e, stackTrace);
        }

        final waitTime = attempts < config.backoffIntervals.length
            ? config.backoffIntervals[attempts]
            : config.backoffIntervals.last;

        debugPrint('[$operationName] Failed: $e. Retrying in ${waitTime.inSeconds} seconds...');
        await Future.delayed(waitTime);
        attempts++;
      }
    }

    throw AppExceptionWrapper('Unexpected exit from RetryEngine');
  }

  Future<void> _sendToDeadLetterQueue({
    required String operationName,
    required Map<String, dynamic> payload,
    required dynamic error,
    required StackTrace stackTrace,
  }) async {
    try {
      final docRef = _db.collection('failed_operations').doc();
      await docRef.set({
        'operationName': operationName,
        'payload': jsonEncode(payload),
        'error': error.toString(),
        'stackTrace': stackTrace.toString(),
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'PENDING_MANUAL_REVIEW',
      });
      debugPrint('[RetryEngine] Successfully wrote to Dead Letter Queue: ${docRef.id}');
    } catch (e) {
      // If the dead letter queue write fails, we log it to console.
      // In a real environment, you might write this to local SQLite to sync later.
      debugPrint('[RetryEngine] CRITICAL: Failed to write to Dead Letter Queue! Error: $e');
    }
  }
}
