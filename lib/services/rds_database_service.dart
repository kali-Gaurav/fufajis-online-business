import 'package:flutter/foundation.dart';

class RDSDatabaseService {
  static final RDSDatabaseService _instance = RDSDatabaseService._internal();

  factory RDSDatabaseService() {
    return _instance;
  }

  RDSDatabaseService._internal();

  @visibleForTesting
  RDSDatabaseService.forTesting();

  Future<List<Map<String, dynamic>>> query(
    String sql, {
    List<dynamic>? params,
    bool allowWrite = false,
  }) async {
    debugPrint('[RDSDatabaseService] Stub Query: $sql');
    return [];
  }

  Future<List<Map<String, dynamic>>> rows(String sql, {List<dynamic>? params}) async {
    debugPrint('[RDSDatabaseService] Stub Rows Query: $sql');
    return [];
  }
}
