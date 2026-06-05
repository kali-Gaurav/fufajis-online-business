import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../utils/app_theme.dart';

class VoiceLandmarkWidget extends StatefulWidget {
  final Function(String) onRecordingComplete;

  const VoiceLandmarkWidget({
    super.key,
    required this.onRecordingComplete,
  });

  @override
  State<VoiceLandmarkWidget> createState() => _VoiceLandmarkWidgetState();
}

class _VoiceLandmarkWidgetState extends State<VoiceLandmarkWidget> {
  late AudioRecorder _audioRecorder;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/landmark_${DateTime.now().millisecondsSinceEpoch}.m4a';

        const config = RecordConfig();
        await _audioRecorder.start(config, path: path);

        setState(() {
          _isRecording = true;
        });
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });
      if (path != null) {
        widget.onRecordingComplete(path);
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.mic, color: AppTheme.primary),
              SizedBox(width: 8),
              Text(
                'Add Voice Directions',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Tell the delivery agent how to find your door (e.g. "Behind the red gate")',
            style: TextStyle(fontSize: 12, color: AppTheme.grey600),
          ),
          const SizedBox(height: 16),
          Center(
            child: GestureDetector(
              onLongPressStart: (_) => _startRecording(),
              onLongPressEnd: (_) => _stopRecording(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _isRecording ? Colors.red : AppTheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isRecording ? Colors.red : AppTheme.primary)
                          .withValues(alpha: 0.4),
                      blurRadius: _isRecording ? 20 : 10,
                      spreadRadius: _isRecording ? 5 : 0,
                    ),
                  ],
                ),
                child: Icon(
                  _isRecording ? Icons.stop : Icons.mic,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _isRecording ? 'Recording... Release to stop' : 'Hold to record directions',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _isRecording ? Colors.red : AppTheme.grey700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
