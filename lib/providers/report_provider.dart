import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/report_model.dart';

/// Streams the latest `reports/{id}` documents produced by the
/// Business Analyst agent for the Mission Control Reports tab.
class ReportProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _reportsSub;

  List<ReportModel> _reports = [];
  bool _isLoading = true;
  String? _errorMessage;

  List<ReportModel> get reports => _reports;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  ReportModel? get latest => _reports.isNotEmpty ? _reports.first : null;

  ReportProvider() {
    _listen();
  }

  void _listen() {
    _reportsSub = _firestore
        .collection('reports')
        .orderBy('generatedAt', descending: true)
        .limit(30)
        .snapshots()
        .listen(
          (snap) {
            _reports = snap.docs.map(ReportModel.fromFirestore).toList();
            _isLoading = false;
            _errorMessage = null;
            notifyListeners();
          },
          onError: (err) {
            _errorMessage = err.toString();
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  @override
  void dispose() {
    _reportsSub?.cancel();
    super.dispose();
  }
}
