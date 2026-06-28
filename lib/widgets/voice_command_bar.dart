import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/speech_to_text_service.dart';
import '../services/voice_command_executor.dart';
import '../services/voice_command_service.dart';
import '../utils/app_theme.dart';

// ─────────────── STATES ───────────────

enum _VoiceBarState { idle, listening, parsed, executing, result }

// ─────────────── WIDGET ───────────────

class VoiceCommandBar extends StatefulWidget {
  /// Called when executing completes; passes back the result string.
  final void Function(String result)? onResult;

  const VoiceCommandBar({super.key, this.onResult});

  @override
  State<VoiceCommandBar> createState() => _VoiceCommandBarState();
}

class _VoiceCommandBarState extends State<VoiceCommandBar>
    with TickerProviderStateMixin {
  final SpeechToTextService _stt = SpeechToTextService();
  final VoiceCommandService _commandService = VoiceCommandService();

  _VoiceBarState _barState = _VoiceBarState.idle;
  String _recognizedText = '';
  VoiceCommand? _parsedCommand;
  String _resultMessage = '';
  bool _isExpanded = false;

  // Animation controllers
  late AnimationController _waveController;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _waveController.dispose();
    _expandController.dispose();
    _stt.stopListening();
    super.dispose();
  }

  // ── Listening ──────────────────────────────────

  Future<void> _startListening() async {
    if (_barState != _VoiceBarState.idle &&
        _barState != _VoiceBarState.result) {
      return;
    }

    setState(() {
      _barState = _VoiceBarState.listening;
      _recognizedText = '';
      _parsedCommand = null;
      _resultMessage = '';
      _isExpanded = true;
    });
    _expandController.forward();

    await _stt.startListening(
      onResult: (text) {
        if (mounted) {
          setState(() => _recognizedText = text);
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() {
            _barState = _VoiceBarState.idle;
            _isExpanded = false;
          });
          _expandController.reverse();
          _showSnackBar('Mic error: $err', isError: true);
        }
      },
    );

    // Wait a moment for final result
    await Future.delayed(const Duration(seconds: 6));
    if (mounted && _barState == _VoiceBarState.listening) {
      await _stopAndParse();
    }
  }

  Future<void> _stopAndParse() async {
    final text = await _stt.stopListening();
    final finalText = text.isNotEmpty ? text : _recognizedText;

    if (finalText.trim().isEmpty) {
      setState(() {
        _barState = _VoiceBarState.idle;
        _isExpanded = false;
      });
      _expandController.reverse();
      return;
    }

    setState(() {
      _barState = _VoiceBarState.parsed;
      _recognizedText = finalText;
    });

    final command = await _commandService.parse(finalText);
    if (mounted) {
      setState(() => _parsedCommand = command);
    }
  }

  Future<void> _confirmAndExecute() async {
    if (_parsedCommand == null) return;

    setState(() => _barState = _VoiceBarState.executing);

    try {
      final result =
          await VoiceCommandExecutor.execute(_parsedCommand!, context);
      if (mounted) {
        setState(() {
          _barState = _VoiceBarState.result;
          _resultMessage = result;
        });
        widget.onResult?.call(result);

        // Auto-close after 3s
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) _resetBar();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _barState = _VoiceBarState.result;
          _resultMessage = 'Error: $e';
        });
      }
    }
  }

  void _cancelCommand() {
    _stt.stopListening();
    _resetBar();
  }

  void _resetBar() {
    setState(() {
      _barState = _VoiceBarState.idle;
      _recognizedText = '';
      _parsedCommand = null;
      _resultMessage = '';
      _isExpanded = false;
    });
    _expandController.reverse();
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppTheme.error : AppTheme.success,
      ),
    );
  }

  // ── Build ────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Expanded panel
        if (_isExpanded)
          SizeTransition(
            sizeFactor: _expandAnimation,
            axisAlignment: 1.0,
            child: _buildExpandedPanel(),
          ),

        const SizedBox(height: 8),

        // Mic FAB
        _buildMicButton(),
      ],
    );
  }

  Widget _buildMicButton() {
    final bool isListening = _barState == _VoiceBarState.listening;

    return GestureDetector(
      onTap: isListening ? _stopAndParse : _startListening,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: isListening ? 72 : 60,
        height: isListening ? 72 : 60,
        decoration: BoxDecoration(
          color: isListening ? AppTheme.error : AppTheme.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (isListening ? AppTheme.error : AppTheme.primary)
                  .withValues(alpha: 0.4),
              blurRadius: isListening ? 20 : 8,
              spreadRadius: isListening ? 4 : 0,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isListening) _buildSoundWaves(),
            Icon(
              isListening ? Icons.stop : Icons.mic,
              color: Colors.white,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoundWaves() {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return CustomPaint(
          painter: _SoundWavePainter(_waveController.value),
          size: const Size(72, 72),
        );
      },
    );
  }

  Widget _buildExpandedPanel() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.cardShadows,
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppTheme.radiusLg),
                topRight: Radius.circular(AppTheme.radiusLg),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.mic, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  _barStateLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _cancelCommand,
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildPanelContent(),
          ),
        ],
      ),
    );
  }

  String get _barStateLabel {
    switch (_barState) {
      case _VoiceBarState.listening:
        return 'Sun raha hun...';
      case _VoiceBarState.parsed:
        return 'Samajh gaya!';
      case _VoiceBarState.executing:
        return 'Kar raha hun...';
      case _VoiceBarState.result:
        return 'Ho gaya!';
      default:
        return 'Voice Command';
    }
  }

  Widget _buildPanelContent() {
    switch (_barState) {
      case _VoiceBarState.listening:
        return _buildListeningContent();
      case _VoiceBarState.parsed:
        return _buildParsedContent();
      case _VoiceBarState.executing:
        return _buildExecutingContent();
      case _VoiceBarState.result:
        return _buildResultContent();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildListeningContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sound wave visualization
        Center(
          child: AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(7, (i) {
                  final phase = (_waveController.value + i * 0.15) % 1.0;
                  final height =
                      20.0 + 20.0 * math.sin(phase * math.pi);
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 4,
                    height: height,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.4 + 0.6 * (height / 40)),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        if (_recognizedText.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.grey100,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Text(
              '"$_recognizedText"',
              style: const TextStyle(
                fontStyle: FontStyle.italic,
                color: AppTheme.grey700,
                fontSize: 15,
              ),
            ),
          )
        else
          const Text(
            'Boliye... (jaise: "aloo ka stock 50 kilo kar")',
            style: TextStyle(color: AppTheme.grey500, fontSize: 13),
          ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: _stopAndParse,
            child: const Text('Done bolna'),
          ),
        ),
      ],
    );
  }

  Widget _buildParsedContent() {
    if (_parsedCommand == null) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recognized text
        Text(
          '"$_recognizedText"',
          style: const TextStyle(
            color: AppTheme.grey600,
            fontStyle: FontStyle.italic,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 12),

        // Confirmation message
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _parsedCommand!.type == VoiceCommandType.unknown
                ? AppTheme.warning.withValues(alpha: 0.1)
                : AppTheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: _parsedCommand!.type == VoiceCommandType.unknown
                  ? AppTheme.warning.withValues(alpha: 0.3)
                  : AppTheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            _parsedCommand!.confirmationText,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: _parsedCommand!.type == VoiceCommandType.unknown
                  ? AppTheme.grey700
                  : AppTheme.grey900,
              fontSize: 15,
            ),
          ),
        ),

        if (_parsedCommand!.type != VoiceCommandType.unknown) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _cancelCommand,
                  icon: const Icon(Icons.close),
                  label: const Text('Nahi'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.grey700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _confirmAndExecute,
                  icon: const Icon(Icons.check),
                  label: const Text('Haan, Karo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ] else ...[
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton(
              onPressed: _cancelCommand,
              child: const Text('Phir se boliye'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildExecutingContent() {
    return const Column(
      children: [
        Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
        SizedBox(height: 12),
        Center(
          child: Text(
            'Kaam ho raha hai...',
            style: TextStyle(color: AppTheme.grey600),
          ),
        ),
      ],
    );
  }

  Widget _buildResultContent() {
    final isError =
        _resultMessage.toLowerCase().contains('nahi') ||
        _resultMessage.toLowerCase().contains('error');

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (isError ? AppTheme.error : AppTheme.success)
                .withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? AppTheme.error : AppTheme.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _resultMessage,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isError ? AppTheme.error : AppTheme.grey900,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────── SOUND WAVE PAINTER ───────────────

class _SoundWavePainter extends CustomPainter {
  final double progress;

  _SoundWavePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 1; i <= 3; i++) {
      final phase = (progress + i * 0.25) % 1.0;
      final radius = size.width * 0.3 * (0.4 + phase * 0.6);
      final opacity = 1.0 - phase;
      paint.color = Colors.white.withValues(alpha: opacity * 0.3);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_SoundWavePainter old) => old.progress != progress;
}
