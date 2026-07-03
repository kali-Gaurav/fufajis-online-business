import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'chat_service.dart';

/// Task #70 — Chat history export for compliance.
///
/// Generates a CSV transcript of a conversation and shares it via the
/// native share sheet. Includes all messages (customer, staff, system)
/// with timestamp, sender, role, text, and sentiment score.
class ChatExportService {
  static final ChatExportService _instance = ChatExportService._internal();
  factory ChatExportService() => _instance;
  ChatExportService._internal();

  final SupportChatService _svc = SupportChatService();
  final DateFormat _fmt = DateFormat('yyyy-MM-dd HH:mm:ss');

  /// Export chat as CSV and open the share sheet.
  Future<void> exportAsCsv(String chatId) async {
    final conv = await _svc.fetchConversation(chatId);
    final msgs = await _svc.fetchAllMessages(chatId);

    final buffer = StringBuffer();

    // ── Header block ─────────────────────────────────────────────────────────
    buffer.writeln('FUFAJI STORE — CHAT EXPORT (COMPLIANCE COPY)');
    buffer.writeln('Generated: ${_fmt.format(DateTime.now())}');
    buffer.writeln('');
    if (conv != null) {
      buffer.writeln('Conversation ID,${conv.chatId}');
      buffer.writeln('Customer,${conv.customerName}');
      buffer.writeln('Phone,${conv.customerPhone}');
      if (conv.orderId != null) buffer.writeln('Order ID,${conv.orderId}');
      if (conv.orderNumber != null) buffer.writeln('Order #,${conv.orderNumber}');
      buffer.writeln('Status,${conv.status.name}');
      if (conv.assignedToName != null) buffer.writeln('Assigned To,${conv.assignedToName}');
      buffer.writeln('Opened,${_fmt.format(conv.createdAt)}');
      buffer.writeln('Last Updated,${_fmt.format(conv.lastUpdated)}');
      if (conv.overallSentiment != null) {
        buffer.writeln(
          'Overall Sentiment,${conv.overallSentiment!.label} (${conv.sentimentScore.toStringAsFixed(2)})',
        );
      }
    }
    buffer.writeln('');

    // ── CSV column headers ────────────────────────────────────────────────────
    buffer.writeln('Timestamp,SenderName,Role,Type,Sentiment,Text');

    // ── Messages ──────────────────────────────────────────────────────────────
    for (final msg in msgs) {
      final ts = _fmt.format(msg.timestamp);
      final role = msg.isInternalNote ? 'internal_note' : msg.senderRole.name;
      final type = msg.messageType.name;
      final sentiment = msg.sentimentLabel != null
          ? '${msg.sentimentLabel!.label}(${msg.sentimentScore?.toStringAsFixed(2) ?? ""})'
          : '';
      final text = _escapeCsv(msg.text);
      buffer.writeln('$ts,${_escapeCsv(msg.senderName)},$role,$type,$sentiment,$text');
    }

    // ── Write to temp file ────────────────────────────────────────────────────
    final dir = await getTemporaryDirectory();
    final safeId = chatId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/chat_${safeId}_$dateStr.csv');
    await file.writeAsString(buffer.toString());

    // ── Share ─────────────────────────────────────────────────────────────────
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'text/csv')],
      subject: 'Chat Export — ${conv?.customerName ?? chatId}',
      text: 'Chat transcript for compliance. Generated ${_fmt.format(DateTime.now())}.',
    ));
  }

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
