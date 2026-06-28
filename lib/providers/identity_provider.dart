import 'package:flutter/material.dart';
import '../models/contact_model.dart';
import '../services/identity_service.dart';

class IdentityProvider with ChangeNotifier {
  final IdentityService _identityService = IdentityService();
  
  List<ContactModel> _contacts = [];
  bool _isLoading = false;
  String? _error;

  List<ContactModel> get contacts => _contacts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadContacts(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _contacts = await _identityService.getContactsForUser(userId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addContact(ContactModel contact) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _identityService.addContact(contact);
      if (success) {
        await loadContacts(contact.userId);
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteContact(String contactId, String userId) async {
    try {
      final success = await _identityService.deleteContact(contactId);
      if (success) {
        await loadContacts(userId);
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
