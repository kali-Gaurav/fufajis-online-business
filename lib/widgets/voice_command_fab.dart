import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/speech_to_text_service.dart';
import '../services/gemini_service.dart';
import '../services/voice_command_executor.dart';
import '../utils/app_theme.dart';

/// Persistent floating action button for owner voice commands.
/// Supports Hindi + English. Handles ADD / UPDATE / DELETE / ORDER_STATUS / REPORT.
class VoiceCommandFab extends StatefulWidget {
  final String? shopId;

  const VoiceCommandFab({Key? key, this.shopId}) : super(key: key);

  @override
  State<VoiceCommandFab> createState() => _VoiceCommandFabState();
}

class _VoiceCommandFabState extends State<VoiceCommandFab>
    with TickerProviderStateMixin {
  // Services
  final SpeechToTextService _sttService = SpeechToTextService();
  final GeminiService _geminiService = GeminiService();
  final VoiceCommandExecutor _executor = VoiceCommandExecutor();

  // State
  bool _isListening = false;
  bool _isProcessing = false;
  String _transcribedText = '';
  String _statusMessage = 'Boliye...';

  // Animations
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _waveController;
  late Animation<double> _waveAnimation;

  // Fallback
  final TextEditingController _fallbackTextController = TextEditingController();
  bool _showFallback = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _waveAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _fallbackTextController.dispose();
    _sttService.stopListening();
    super.dispose();
  }

  // ─── RECORDING LOGIC ──────────────────────────────────────────────────────

  Future<void> _startListening() async {
    setState(() {
      _isListening = true;
      _transcribedText = '';
      _statusMessage = 'Sun raha hoon...';
      _showFallback = false;
    });
    _pulseController.repeat(reverse: true);
    _waveController.repeat(reverse: true);

    _showListeningOverlay();

    try {
      await _sttService.startListening(
        onResult: (text) {
          if (mounted) {
            setState(() {
              _transcribedText = text;
              _statusMessage = text.isEmpty ? 'Sun raha hoon...' : text;
            });
          }
        },
        onError: (err) {
          debugPrint('[VoiceCommandFab] STT Error: $err');
          if (mounted) {
            setState(() {
              _isListening = false;
              _statusMessage = 'Error: $err';
            });
            _showFallback = true;
          }
        },
      );
    } catch (e) {
      debugPrint('[VoiceCommandFab] startListening exception: $e');
      if (mounted) {
        setState(() {
          _isListening = false;
          _showFallback = true;
          _statusMessage = 'Mic error aaya.';
        });
      }
    }
  }

  Future<void> _stopAndProcess() async {
    _pulseController.stop();
    _waveController.stop();

    final spokenText = await _sttService.stopListening();
    final finalText = spokenText.isNotEmpty ? spokenText : _transcribedText;

    if (mounted) {
      setState(() {
        _isListening = false;
        _isProcessing = true;
        _statusMessage = 'Samajh raha hoon...';
        _transcribedText = finalText;
      });
    }

    if (finalText.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _showFallback = true;
          _statusMessage = 'Kuch sunai nahi diya.';
        });
      }
      return;
    }

    await _processCommand(finalText);
  }

  Future<void> _processCommand(String text) async {
    if (mounted) {
      setState(() {
        _isProcessing = true;
        _statusMessage = 'Gemini se puch raha hoon...';
      });
    }

    try {
      final parsed = await _geminiService.parseVoiceInventoryCommand(text);

      if (parsed == null) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _showFallback = true;
            _statusMessage = 'Samajh nahi aaya. Type karein:';
          });
        }
        return;
      }

      if (mounted) {
        setState(() => _statusMessage = 'Execute ho raha hai...');
        final confirmationMsg = await _executor.execute(parsed, context);

        // Save to history
        await _saveCommandToHistory(text, confirmationMsg);

        setState(() {
          _isProcessing = false;
          _statusMessage = confirmationMsg;
        });

        Navigator.of(context).pop(); // dismiss overlay

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    confirmationMsg,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.secondary,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[VoiceCommandFab] processCommand error: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _showFallback = true;
          _statusMessage = 'Error aaya. Type karein:';
        });
      }
    }
  }

  Future<void> _saveCommandToHistory(String command, String result) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList('voice_command_history') ?? [];
      final entry = jsonEncode({
        'command': command,
        'result': result,
        'timestamp': DateTime.now().toIso8601String(),
      });
      existing.insert(0, entry);
      // Keep last 10
      if (existing.length > 10) existing.removeRange(10, existing.length);
      await prefs.setStringList('voice_command_history', existing);
    } catch (e) {
      debugPrint('[VoiceCommandFab] save history error: $e');
    }
  }

  // ─── OVERLAY ──────────────────────────────────────────────────────────────

  void _showListeningOverlay() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      isDismissible: true,
      builder: (ctx) => _buildListeningSheet(),
    ).then((_) {
      if (_isListening) {
        _stopAndProcess();
      }
    });
  }

  Widget _buildListeningSheet() {
    return StatefulBuilder(
      builder: (ctx, setSheetState) {
        return AnimatedBuilder(
          animation: Listenable.merge([_pulseController, _waveController]),
          builder: (_, __) {
            return Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.grey300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Animated mic
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer pulse ring
                      if (_isListening)
                        Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primary.withOpacity(0.15),
                            ),
                          ),
                        ),
                      // Inner circle
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isListening ? AppTheme.primary : AppTheme.grey300,
                        ),
                        child: Icon(
                          _isProcessing ? Icons.auto_awesome : Icons.mic,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Waveform bars (animated)
                  if (_isListening)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(7, (i) {
                        final heights = [12.0, 20.0, 28.0, 36.0, 28.0, 20.0, 12.0];
                        final delay = i * 0.14;
                        final value = (_waveAnimation.value + delay) % 1.0;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: 5,
                          height: heights[i] * (0.4 + 0.6 * value),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.7 + 0.3 * value),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),

                  const SizedBox(height: 16),

                  // Status / transcribed text
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (_, __) => Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.grey900,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Hint
                  Text(
                    '"Aloo ka stock 50 kilo kar" • "Order 47 deliver ho gaya"',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.grey500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Fallback text field
                  if (_showFallback) ...[
                    TextField(
                      controller: _fallbackTextController,
                      decoration: InputDecoration(
                        hintText: 'Type command here...',
                        prefixIcon: const Icon(Icons.keyboard, color: AppTheme.primary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final text = _fallbackTextController.text.trim();
                        if (text.isEmpty) return;
                        Navigator.of(ctx).pop();
                        await _processCommand(text);
                      },
                      icon: const Icon(Icons.send),
                      label: const Text('Execute'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Stop button
                  if (_isListening && !_showFallback)
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _stopAndProcess();
                      },
                      icon: const Icon(Icons.stop_circle, color: AppTheme.error),
                      label: const Text(
                        'Stop & Process',
                        style: TextStyle(color: AppTheme.error),
                      ),
                    ),

                  if (_isProcessing)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(
                        color: AppTheme.primary,
                        backgroundColor: AppTheme.grey200,
                      ),
                    ),

                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) {
        return Transform.scale(
          scale: _isListening ? _pulseAnimation.value : 1.0,
          child: FloatingActionButton(
            onPressed: () {
              if (_isListening) {
                _stopAndProcess();
              } else {
                _startListening();
              }
            },
            backgroundColor: _isListening ? AppTheme.error : AppTheme.primary,
            elevation: 6,
            tooltip: 'Voice Command (Hindi/English)',
            child: Icon(
              _isListening ? Icons.stop : Icons.mic,
              color: Colors.white,
              size: 28,
            ),
          ),
        );
      },
    );
  }
}
