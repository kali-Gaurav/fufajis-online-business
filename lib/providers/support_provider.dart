import 'package:flutter/foundation.dart';
import '../models/support_ticket_model.dart';
import '../services/support_service.dart';

class SupportProvider extends ChangeNotifier {
  final SupportService _supportService = SupportService();

  List<SupportTicket> _tickets = [];
  SupportTicket? _currentTicket;
  bool _loading = false;
  String? _error;

  List<SupportTicket> get tickets => _tickets;
  SupportTicket? get currentTicket => _currentTicket;
  bool get loading => _loading;
  String? get error => _error;

  Future<SupportTicket> createTicket({
    required String orderId,
    required String issueType,
    required String description,
    List<String>? photoUrls,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // TODO: Get customer ID from auth provider
      final customerId = 'current_user'; // Placeholder

      final ticket = await _supportService.createTicket(
        orderId: orderId,
        customerId: customerId,
        issueType: issueType,
        description: description,
        photoUrls: photoUrls,
      );

      _currentTicket = ticket;
      _tickets.insert(0, ticket);
      return ticket;
    } catch (e) {
      _error = e.toString();
      print('Error creating support ticket: $e');
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> addMessage({
    required String ticketId,
    required String senderType,
    required String senderName,
    required String message,
    String? attachmentUrl,
  }) async {
    try {
      await _supportService.addMessage(
        ticketId: ticketId,
        senderType: senderType,
        senderName: senderName,
        message: message,
        attachmentUrl: attachmentUrl,
      );
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Stream<SupportTicket?> watchTicket(String ticketId) {
    return _supportService.watchTicket(ticketId);
  }

  Stream<List<SupportTicket>> watchCustomerTickets(String customerId) {
    return _supportService.watchCustomerTickets(customerId);
  }

  Stream<List<SupportMessage>> watchTicketMessages(String ticketId) {
    return _supportService.watchTicketMessages(ticketId);
  }

  Future<void> updateTicketStatus(String ticketId, String newStatus) async {
    try {
      await _supportService.updateTicketStatus(ticketId, newStatus);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loadOpenTickets({String? customerId}) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _tickets = await _supportService.getOpenTickets(customerId: customerId);
    } catch (e) {
      _error = e.toString();
      print('Error loading tickets: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
