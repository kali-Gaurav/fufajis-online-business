import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/agent_task_model.dart';

/// Streams `agent_tasks` for the Owner Control Room and exposes
/// approve/reject actions backed by Firestore updates.
class AgentTaskProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _tasksSub;

  List<AgentTaskModel> _tasks = [];
  bool _isLoading = true;
  String? _errorMessage;
  final Set<String> _actingOnTaskIds = {};

  List<AgentTaskModel> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<AgentTaskModel> get awaitingApproval => _tasks.where((t) => t.isAwaitingApproval).toList();

  bool isActingOn(String taskId) => _actingOnTaskIds.contains(taskId);

  AgentTaskProvider() {
    _listen();
  }

  void _listen() {
    _tasksSub = _firestore
        .collection('agent_tasks')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .listen(
          (snap) {
            _tasks = snap.docs.map(AgentTaskModel.fromFirestore).toList();
            _isLoading = false;
            notifyListeners();
          },
          onError: (err) {
            _errorMessage = err.toString();
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  List<AgentTaskModel> tasksForAgent(String agentId) =>
      _tasks.where((t) => t.agentId == agentId).toList();

  Future<bool> approveTask(String taskId) => _act(taskId, 'approveAgentTask', {'taskId': taskId});

  Future<bool> rejectTask(String taskId, {String? reason}) =>
      _act(taskId, 'rejectAgentTask', {'taskId': taskId, if (reason != null) 'reason': reason});

  Future<bool> _act(String taskId, String action, Map<String, dynamic> data) async {
    _actingOnTaskIds.add(taskId);
    notifyListeners();
    try {
      await _firestore.collection('agent_tasks').doc(taskId).update({
        'status': action == 'approveAgentTask' ? 'approved' : 'rejected',
        if (data.containsKey('reason')) 'rejectionReason': data['reason'],
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (err) {
      _errorMessage = err.toString();
      return false;
    } finally {
      _actingOnTaskIds.remove(taskId);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _tasksSub?.cancel();
    super.dispose();
  }
}
