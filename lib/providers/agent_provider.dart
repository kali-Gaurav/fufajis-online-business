import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/agent_model.dart';

/// Streams the Mission Control ("Karyalay") agent roster and global
/// config (incl. master kill switch) for the Owner Control Room.
class AgentProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _agentsSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _configSub;

  List<AgentModel> _agents = [];
  AgentGlobalConfig _config = AgentGlobalConfig.empty();
  bool _isLoading = true;
  String? _errorMessage;
  bool _isTogglingKillSwitch = false;

  List<AgentModel> get agents => _agents;
  AgentGlobalConfig get config => _config;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get masterEnabled => _config.masterEnabled;
  bool get isTogglingKillSwitch => _isTogglingKillSwitch;

  AgentProvider() {
    _listen();
  }

  void _listen() {
    _agentsSub = _firestore
        .collection('agents')
        .orderBy('name')
        .snapshots()
        .listen((snap) {
      _agents = snap.docs.map(AgentModel.fromFirestore).toList();
      _isLoading = false;
      notifyListeners();
    }, onError: (err) {
      _errorMessage = err.toString();
      _isLoading = false;
      notifyListeners();
    });

    _configSub = _firestore
        .collection('agent_config')
        .doc('global')
        .snapshots()
        .listen((snap) {
      _config = snap.exists ? AgentGlobalConfig.fromFirestore(snap) : AgentGlobalConfig.empty();
      notifyListeners();
    }, onError: (err) {
      _errorMessage = err.toString();
      notifyListeners();
    });
  }

  /// Flips the Mission Control master kill switch via direct Firestore write.
  Future<bool> setMasterEnabled(bool enabled) async {
    _isTogglingKillSwitch = true;
    notifyListeners();
    try {
      await _firestore.collection('agent_config').doc('global').set({
        'masterEnabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (err) {
      _errorMessage = err.toString();
      return false;
    } finally {
      _isTogglingKillSwitch = false;
      notifyListeners();
    }
  }

  /// One-time/idempotent seed of agent_config/global + MVP agent
  /// roster docs. Safe to call repeatedly.
  Future<bool> seedRosterIfNeeded() async {
    try {
      // Stubbed out client-side since configuration is centralized
      return true;
    } catch (err) {
      _errorMessage = err.toString();
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _agentsSub?.cancel();
    _configSub?.cancel();
    super.dispose();
  }
}
