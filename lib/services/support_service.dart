import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/support_ticket_model.dart';

class SupportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<SupportTicket> createTicket({
    required String orderId,
    required String customerId,
    required String issueType,
    required String description,
    List<String>? photoUrls,
  }) async {
    try {
      final ticketId = _firestore.collection('support_tickets').doc().id;

      final ticket = SupportTicket(
        id: ticketId,
        orderId: orderId,
        customerId: customerId,
        issueType: issueType,
        description: description,
        photoUrls: photoUrls,
        status: 'open',
        messages: [],
        createdAt: DateTime.now(),
      );

      await _firestore.collection('support_tickets').doc(ticketId).set(ticket.toFirestore());

      // Send initial notification
      await _sendSupportNotification(customerId, 'Ticket created', 'Your support ticket #$ticketId has been created');

      return ticket;
    } catch (e) {
      print('Error creating support ticket: $e');
      rethrow;
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
      final messageId = _firestore.collection('support_messages').doc().id;

      final msg = SupportMessage(
        id: messageId,
        senderType: senderType,
        senderName: senderName,
        message: message,
        attachmentUrl: attachmentUrl,
        timestamp: DateTime.now(),
      );

      await _firestore.collection('support_messages').doc(messageId).set(msg.toMap());

      // Update ticket's updatedAt
      await _firestore.collection('support_tickets').doc(ticketId).update({
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding support message: $e');
      rethrow;
    }
  }

  Stream<SupportTicket?> watchTicket(String ticketId) {
    return _firestore.collection('support_tickets').doc(ticketId).snapshots().asyncMap((doc) async {
      if (!doc.exists) return null;

      final ticketData = doc.data()!;

      // Fetch messages
      final messagesSnapshot = await _firestore
          .collection('support_messages')
          .where('ticketId', isEqualTo: ticketId)
          .orderBy('timestamp', descending: false)
          .get();

      final messages = messagesSnapshot.docs.map((m) => SupportMessage.fromMap(m.data())).toList();

      return SupportTicket.fromFirestore({
        ...ticketData,
        'messages': messages.map((m) => m.toMap()).toList(),
      });
    });
  }

  Stream<List<SupportTicket>> watchCustomerTickets(String customerId) {
    return _firestore
        .collection('support_tickets')
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => SupportTicket.fromFirestore(doc.data())).toList();
    });
  }

  Stream<List<SupportMessage>> watchTicketMessages(String ticketId) {
    return _firestore
        .collection('support_messages')
        .where('ticketId', isEqualTo: ticketId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => SupportMessage.fromMap(doc.data())).toList();
    });
  }

  Future<void> updateTicketStatus(String ticketId, String newStatus) async {
    try {
      final updates = {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (newStatus == 'resolved' || newStatus == 'closed') {
        updates['resolvedAt'] = FieldValue.serverTimestamp();
      }

      await _firestore.collection('support_tickets').doc(ticketId).update(updates);
    } catch (e) {
      print('Error updating ticket status: $e');
      rethrow;
    }
  }

  Future<List<SupportTicket>> getOpenTickets({String? customerId}) async {
    try {
      Query query = _firestore.collection('support_tickets').where('status', isEqualTo: 'open');

      if (customerId != null) {
        query = query.where('customerId', isEqualTo: customerId);
      }

      final snapshot = await query.orderBy('createdAt', descending: false).get();

      return snapshot.docs.map((doc) => SupportTicket.fromFirestore(doc.data() as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Error fetching open tickets: $e');
      return [];
    }
  }

  Future<void> _sendSupportNotification(String userId, String title, String body) async {
    // This will be implemented with FCM integration
    print('Sending notification: $title - $body');
  }
}
