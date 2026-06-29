import 'package:flutter/foundation.dart';
import '../models/campaign_model.dart';
import '../services/campaign_service.dart';

class CampaignProvider with ChangeNotifier {
  final CampaignService _service = CampaignService();
  
  List<CampaignModel> _campaigns = [];
  bool _isLoading = false;
  String? _error;

  List<CampaignModel> get campaigns => _campaigns;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  List<CampaignModel> get activeCampaigns => _campaigns.where((c) => c.status == CampaignStatus.active).toList();
  List<CampaignModel> get scheduledCampaigns => _campaigns.where((c) => c.status == CampaignStatus.scheduled).toList();
  List<CampaignModel> get draftCampaigns => _campaigns.where((c) => c.status == CampaignStatus.draft).toList();
  List<CampaignModel> get pastCampaigns => _campaigns.where((c) => c.status == CampaignStatus.completed || c.status == CampaignStatus.cancelled).toList();

  CampaignProvider() {
    _init();
  }

  void _init() {
    _isLoading = true;
    notifyListeners();
    
    _service.watchCampaigns().listen(
      (data) {
        _campaigns = data;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      }
    );
  }

  Future<void> createDraft(CampaignModel campaign, String adminId, String adminName) async {
    try {
      await _service.createCampaign(campaign, adminId, adminName);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateCampaign(CampaignModel campaign, String adminId, String adminName) async {
    try {
      await _service.updateCampaign(campaign, adminId, adminName);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }
  
  Future<void> launchCampaign(String campaignId, String adminId, String adminName) async {
    try {
      await _service.launchCampaign(campaignId, adminId, adminName);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }
  
  Future<void> cancelCampaign(String campaignId, String adminId, String adminName) async {
    try {
      await _service.cancelCampaign(campaignId, adminId, adminName);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }
  
  Future<void> deleteCampaign(String campaignId, String adminId, String adminName) async {
    try {
      await _service.deleteCampaign(campaignId, adminId, adminName);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }
}
