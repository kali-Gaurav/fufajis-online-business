import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/broadcast_model.dart';

class BroadcastProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'asia-south1');

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _broadcastsSub;

  List<BroadcastModel> _broadcasts = [];
  bool _isLoading = true;
  String? _errorMessage;
  final Set<String> _sendingIds = {};

  List<BroadcastModel> get broadcasts => _broadcasts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool isSending(String id) => _sendingIds.contains(id);

  BroadcastProvider() {
    _listen();
  }

  void _listen() {
    _broadcastsSub = _firestore
        .collection('broadcasts')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .listen((snap) {
      _broadcasts = snap.docs.map(BroadcastModel.fromFirestore).toList();
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    }, onError: (err) {
      _errorMessage = err.toString();
      _isLoading = false;
      notifyListeners();
    });
  }

  /// Sends a broadcast immediately using the backend function.
  Future<bool> sendBroadcast(String broadcastId) async {
    _sendingIds.add(broadcastId);
    notifyListeners();
    try {
      final callable = _functions.httpsCallable('sendBroadcastCallable');
      await callable.call({'broadcastId': broadcastId});
      return true;
    } catch (err) {
      _errorMessage = err.toString();
      return false;
    } finally {
      _sendingIds.remove(broadcastId);
      notifyListeners();
    }
  }

  /// Saves or updates a broadcast draft.
  Future<bool> saveDraft({
    String? id,
    required String title,
    required String body,
    String? deepLink,
    String? imageUrl,
    required String type,
    String? segmentId,
  }) async {
    try {
      final data = {
        'title': title,
        'body': body,
        'deepLink': deepLink,
        'imageUrl': imageUrl,
        'audience': {
          'type': type,
          if (segmentId != null) 'segmentId': segmentId,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (id != null) {
        await _firestore.collection('broadcasts').doc(id).update(data);
      } else {
        await _firestore.collection('broadcasts').add({
          ...data,
          'status': 'draft',
          'channel': 'push',
          'createdBy': 'owner',
          'createdAt': FieldValue.serverTimestamp(),
          'stats': {'delivered': 0, 'opened': 0, 'clicked': 0, 'optOuts': 0},
        });
      }
      return true;
    } catch (err) {
      _errorMessage = err.toString();
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _broadcastsSub?.cancel();
    super.dispose();
  }
}
