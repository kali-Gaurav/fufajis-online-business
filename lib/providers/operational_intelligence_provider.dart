import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_queue_model.dart';
import '../models/operational_health_model.dart';
import '../services/task_queue_service.dart';

class OperationalIntelligenceProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TaskQueueService _taskQueueService = TaskQueueService();

  // Dispatcher State
  List<TaskQueueModel> _dispatchQueue = [];
  int _unassignedOrdersCount = 0;
  int _activeRidersCount = 0;
  int _slaRisksCount = 0;

  // Branch Manager State
  List<TaskQueueModel> _branchManagerQueue = [];
  OperationalHealthModel? _branchHealth;

  // Owner State
  List<TaskQueueModel> _ownerQueue = [];

  bool _isLoading = false;
  String? _errorMessage;

  List<TaskQueueModel> get dispatchQueue => _dispatchQueue;
  int get unassignedOrdersCount => _unassignedOrdersCount;
  int get activeRidersCount => _activeRidersCount;
  int get slaRisksCount => _slaRisksCount;
  List<TaskQueueModel> get branchManagerQueue => _branchManagerQueue;
  OperationalHealthModel? get branchHealth => _branchHealth;
  List<TaskQueueModel> get ownerQueue => _ownerQueue;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  StreamSubscription? _dispatchQueueSub;
  StreamSubscription? _ordersSub;
  StreamSubscription? _ridersSub;
  StreamSubscription? _branchManagerQueueSub;
  StreamSubscription? _branchHealthSub;
  StreamSubscription? _ownerQueueSub;

  void initDispatcher(String branchId) {
    _isLoading = true;
    notifyListeners();

    _listenToDispatchQueue(branchId);
    _listenToOrderMetrics(branchId);
    _listenToRiderMetrics(branchId);

    _isLoading = false;
    notifyListeners();
  }

  void initBranchManager(String branchId) {
    _isLoading = true;
    notifyListeners();

    _listenToBranchManagerQueue(branchId);
    _listenToBranchHealth(branchId);

    _isLoading = false;
    notifyListeners();
  }

  void initOwner() {
    _isLoading = true;
    notifyListeners();

    _listenToOwnerQueue();

    _isLoading = false;
    notifyListeners();
  }

  void _listenToDispatchQueue(String branchId) {
    _dispatchQueueSub?.cancel();
    _dispatchQueueSub = _taskQueueService
        .streamTasks(branchId: branchId)
        .listen(
          (tasks) {
            _dispatchQueue = tasks;
            // We can also compute SLA risks count from tasks if taskType is sla_breach_risk
            _slaRisksCount = tasks.where((t) => t.taskType == TaskQueueType.sla_breach_risk).length;
            notifyListeners();
          },
          onError: (e) {
            _errorMessage = e.toString();
            notifyListeners();
          },
        );
  }

  void _listenToOrderMetrics(String branchId) {
    _ordersSub?.cancel();
    // Assuming 'branchId' exists on orders, or we just listen to all packed orders
    _ordersSub = _db
        .collection('orders')
        .where('status', isEqualTo: 'packed')
        .where('deliveryAgentId', isNull: true)
        .snapshots()
        .listen((snapshot) {
          _unassignedOrdersCount = snapshot.docs.length;
          notifyListeners();
        });
  }

  void _listenToRiderMetrics(String branchId) {
    _ridersSub?.cancel();
    // Assuming 'deliveryAgents' collection has active status
    _ridersSub = _db
        .collection('users')
        .where('role', isEqualTo: 'rider')
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
          _activeRidersCount = snapshot.docs.length;
          notifyListeners();
        });
  }

  void _listenToOwnerQueue() {
    _ownerQueueSub?.cancel();
    _ownerQueueSub = _taskQueueService
        .streamTasks(assignedRole: 'owner')
        .listen(
          (tasks) {
            _ownerQueue = tasks;
            notifyListeners();
          },
          onError: (e) {
            _errorMessage = e.toString();
            notifyListeners();
          },
        );
  }

  void _listenToBranchManagerQueue(String branchId) {
    _branchManagerQueueSub?.cancel();
    _branchManagerQueueSub = _taskQueueService
        .streamTasks(branchId: branchId, assignedRole: 'branchManager')
        .listen(
          (tasks) {
            _branchManagerQueue = tasks;
            notifyListeners();
          },
          onError: (e) {
            _errorMessage = e.toString();
            notifyListeners();
          },
        );
  }

  void _listenToBranchHealth(String branchId) {
    _branchHealthSub?.cancel();
    _branchHealthSub = _db
        .collection('branches')
        .doc(branchId)
        .collection('health')
        .doc('latest')
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists && snapshot.data() != null) {
            // Fallback for missing mapping
            _branchHealth = OperationalHealthModel(
              branchId: branchId,
              inventoryHealth: ((snapshot.data()!['inventoryHealth'] as num?) ?? 80).toDouble(),
              deliveryHealth: ((snapshot.data()!['deliveryHealth'] as num?) ?? 90).toDouble(),
              employeeHealth: ((snapshot.data()!['employeeHealth'] as num?) ?? 85).toDouble(),
              supplierHealth: ((snapshot.data()!['supplierHealth'] as num?) ?? 95).toDouble(),
              customerHealth: ((snapshot.data()!['customerHealth'] as num?) ?? 88).toDouble(),
              financialHealth: ((snapshot.data()!['financialHealth'] as num?) ?? 92).toDouble(),
              lastUpdated: DateTime.now(),
            );
          } else {
            // Mock fallback if doesn't exist
            _branchHealth = OperationalHealthModel(
              branchId: branchId,
              inventoryHealth: 82.0,
              deliveryHealth: 95.0,
              employeeHealth: 88.0,
              supplierHealth: 100.0,
              customerHealth: 91.0,
              financialHealth: 94.0,
              lastUpdated: DateTime.now(),
            );
          }
          notifyListeners();
        });
  }

  Future<void> resolveTask(String taskId) async {
    try {
      await _taskQueueService.resolveTask(taskId);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _dispatchQueueSub?.cancel();
    _ordersSub?.cancel();
    _ridersSub?.cancel();
    _branchManagerQueueSub?.cancel();
    _branchHealthSub?.cancel();
    _ownerQueueSub?.cancel();
    super.dispose();
  }
}
