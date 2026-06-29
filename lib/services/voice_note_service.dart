import 'dart:io';
import 'package:record/record.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Voice Note Service
/// Records, uploads, and manages voice notes for chat
class VoiceNoteService {
  static final VoiceNoteService _instance = VoiceNoteService._internal();
  factory VoiceNoteService() => _instance;
  VoiceNoteService._internal();

  final _audioRecorder = AudioRecorder();
  final _storage = FirebaseStorage.instance;
  final _firestore = FirebaseFirestore.instance;

  bool _isRecording = false;
  String? _recordingPath;
  int _recordingDuration = 0;

  bool get isRecording => _isRecording;
  int get recordingDuration => _recordingDuration;

  /// Start recording voice note
  Future<bool> startRecording() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        debugPrint('[VoiceNote] Microphone permission denied');
        return false;
      }

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.wav';

      await _audioRecorder.start(
        path: path,
        encoder: AudioEncoder.wav,
      );

      _recordingPath = path;
      _isRecording = true;
      _recordingDuration = 0;
      debugPrint('[VoiceNote] Recording started: $path');
      return true;
    } catch (e) {
      debugPrint('[VoiceNote] Error starting recording: $e');
      return false;
    }
  }

  /// Stop and save recording
  Future<String?> stopRecording() async {
    try {
      if (!_isRecording) return null;

      final path = await _audioRecorder.stop();
      _isRecording = false;

      debugPrint('[VoiceNote] Recording stopped: $path');
      return path;
    } catch (e) {
      debugPrint('[VoiceNote] Error stopping recording: $e');
      return null;
    }
  }

  /// Upload voice note to Firebase Storage
  Future<String?> uploadVoiceNote({
    required String filePath,
    required String chatId,
    required String userId,
  }) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        debugPrint('[VoiceNote] File not found: $filePath');
        return null;
      }

      final fileSize = file.lengthSync();
      final fileName = 'voice_note_${DateTime.now().millisecondsSinceEpoch}.wav';
      final ref = _storage.ref().child('chat_voice_notes/$chatId/$fileName');

      final uploadTask = ref.putFile(
        file,
        SettableMetadata(
          contentType: 'audio/wav',
          customMetadata: {
            'userId': userId,
            'chatId': chatId,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      await uploadTask.whenComplete(() {});
      final downloadUrl = await ref.getDownloadURL();

      debugPrint('[VoiceNote] ✅ Uploaded: $fileName ($fileSize bytes)');
      return downloadUrl;
    } catch (e) {
      debugPrint('[VoiceNote] ❌ Error uploading: $e');
      return null;
    }
  }

  /// Send voice note as chat message
  Future<void> sendVoiceNote({
    required String chatId,
    required String userId,
    required String voiceNoteUrl,
    required int durationSeconds,
  }) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'type': 'voice_note',
        'content': 'Voice message',
        'voiceNoteUrl': voiceNoteUrl,
        'durationSeconds': durationSeconds,
        'senderId': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      debugPrint('[VoiceNote] ✅ Voice note sent to chat');
    } catch (e) {
      debugPrint('[VoiceNote] ❌ Error sending voice note: $e');
    }
  }

  /// Delete voice note file
  Future<bool> deleteLocalFile(String filePath) async {
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        await file.delete();
        debugPrint('[VoiceNote] Local file deleted: $filePath');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[VoiceNote] Error deleting file: $e');
      return false;
    }
  }

  /// Cancel recording
  Future<void> cancelRecording() async {
    try {
      if (_isRecording) {
        await _audioRecorder.stop();
        if (_recordingPath != null) {
          await deleteLocalFile(_recordingPath!);
        }
      }
      _isRecording = false;
      _recordingPath = null;
      _recordingDuration = 0;
      debugPrint('[VoiceNote] Recording cancelled');
    } catch (e) {
      debugPrint('[VoiceNote] Error cancelling recording: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _audioRecorder.dispose();
  }
}
