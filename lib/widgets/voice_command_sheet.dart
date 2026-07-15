import 'dart:math';
import 'package:flutter/material.dart';
import '../services/speech_to_text_service.dart';
import '../services/voice_command_executor.dart';
import '../services/voice_command_service.dart';
import '../utils/app_theme.dart';

// ─────────────── PUBLIC HELPER ───────────────

/// Show the voice command bottom sheet from anywhere.
void showVoiceCommandSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const VoiceCommandSheet(),
  );
}

// ─────────────── SHEET WIDGET ───────────────

class VoiceCommandSheet extends StatefulWidget {
  const VoiceCommandSheet({super.key});

  @override
  State<VoiceCommandSheet> createState() => _VoiceCommandSheetState();
}

enum _SheetState { idle, listening, processing, confirm, result, error }

class _VoiceCommandSheetState extends State<VoiceCommandSheet> with TickerProviderStateMixin {
  final SpeechToTextService _stt = SpeechToTextService();
  final VoiceCommandService _vc = VoiceCommandService();

  _SheetState _state = _SheetState.idle;
  String _liveText = '';
  VoiceCommand? _parsedCommand;
  String _resultText = '';

  // Pulse animation for mic
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  // Wave animation bars
  late final AnimationController _waveCtrl;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.85,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _waveCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _waveCtrl.dispose();
    _stt.stopListening();
    super.dispose();
  }

  // ── Lifecycle ────────────────────────────────────────────────────────

  Future<void> _startListening() async {
    setState(() {
      _state = _SheetState.listening;
      _liveText = '';
      _parsedCommand = null;
      _resultText = '';
    });

    await _stt.startListening(
      onResult: (text) {
        if (mounted) setState(() => _liveText = text);
      },
      onError: (err) {
        if (mounted) setState(() => _state = _SheetState.error);
      },
    );
  }

  Future<void> _stopListeningAndParse() async {
    final text = await _stt.stopListening();
    if (!mounted) return;

    if (text.trim().isEmpty) {
      setState(() {
        _state = _SheetState.error;
        _resultText = 'Kuch sun nahi aaya. Phir se try karein.';
      });
      return;
    }

    setState(() => _state = _SheetState.processing);
    final cmd = await _vc.parse(text.isEmpty ? _liveText : text);
    if (!mounted) return;

    if (cmd.type == VoiceCommandType.unknown) {
      setState(() {
        _state = _SheetState.error;
        _resultText = 'Samajh nahi aaya: "$text"\nExample: "Aloo ka stock 50 kilo kar"';
      });
    } else {
      setState(() {
        _state = _SheetState.confirm;
        _parsedCommand = cmd;
      });
    }
  }

  Future<void> _executeCommand() async {
    if (_parsedCommand == null) return;
    setState(() => _state = _SheetState.processing);

    final result = await VoiceCommandExecutor.execute(_parsedCommand!, context);
    if (!mounted) return;

    setState(() {
      _state = _SheetState.result;
      _resultText = result;
    });
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.grey300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    const SizedBox(height: 16),
                    _buildHeader(),
                    const SizedBox(height: 28),
                    _buildContent(),
                    const SizedBox(height: 24),
                    _buildExampleCommands(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.mic, color: AppTheme.primary),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Voice Command',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey900,
                ),
              ),
              Text(
                'Hindi ya English mein boliye',
                style: TextStyle(fontSize: 13, color: AppTheme.grey500),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close, color: AppTheme.grey400),
        ),
      ],
    );
  }

  Widget _buildContent() {
    switch (_state) {
      case _SheetState.idle:
        return _buildIdleState();
      case _SheetState.listening:
        return _buildListeningState();
      case _SheetState.processing:
        return _buildProcessingState();
      case _SheetState.confirm:
        return _buildConfirmState();
      case _SheetState.result:
        return _buildResultState(success: true);
      case _SheetState.error:
        return _buildResultState(success: false);
    }
  }

  Widget _buildIdleState() {
    return Column(
      children: [
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _startListening,
          child: ScaleTransition(
            scale: _pulseAnim,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.4),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.mic, color: Colors.white, size: 44),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Mic tap karein aur boliye',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.grey700),
        ),
      ],
    );
  }

  Widget _buildListeningState() {
    return Column(
      children: [
        const SizedBox(height: 8),
        // Waveform bars
        AnimatedBuilder(
          animation: _waveCtrl,
          builder: (_, __) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(9, (i) {
                final phase = (i / 9) * 2 * pi;
                final val = (sin(_waveCtrl.value * 2 * pi + phase) + 1) / 2;
                final barH = 8.0 + val * 44;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 8,
                  height: barH,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.4 + val * 0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            );
          },
        ),
        const SizedBox(height: 20),

        // Stop button
        GestureDetector(
          onTap: _stopListeningAndParse,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.error,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.error.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(Icons.stop, color: Colors.white, size: 36),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Sun raha hoon...',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.primary),
        ),
        if (_liveText.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.grey50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.grey200),
            ),
            child: Text(
              '"$_liveText"',
              style: const TextStyle(
                fontStyle: FontStyle.italic,
                color: AppTheme.grey700,
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _stopListeningAndParse,
          style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.primary)),
          child: const Text('Ruk jao — Process karo'),
        ),
      ],
    );
  }

  Widget _buildProcessingState() {
    return const Column(
      children: [
        SizedBox(height: 32),
        CircularProgressIndicator(color: AppTheme.primary),
        SizedBox(height: 20),
        Text(
          'Samajh raha hoon...',
          style: TextStyle(fontSize: 15, color: AppTheme.grey600, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        Text('Thoda sa ruko bhaiya! 🙏', style: TextStyle(fontSize: 13, color: AppTheme.grey400)),
      ],
    );
  }

  Widget _buildConfirmState() {
    final cmd = _parsedCommand!;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              const Icon(Icons.record_voice_over, color: AppTheme.primary, size: 32),
              const SizedBox(height: 12),
              Text(
                cmd.confirmationText,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.grey900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Confidence: ${(cmd.confidence * 100).round()}%',
                style: const TextStyle(fontSize: 12, color: AppTheme.grey400),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() {
                  _state = _SheetState.idle;
                  _parsedCommand = null;
                }),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Dobara bolo'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _executeCommand,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Haan, karo!'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResultState({required bool success}) {
    final isSuccess = _state == _SheetState.result;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: (isSuccess ? AppTheme.success : AppTheme.error).withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: (isSuccess ? AppTheme.success : AppTheme.error).withOpacity(0.25),
            ),
          ),
          child: Column(
            children: [
              Icon(
                isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                color: isSuccess ? AppTheme.success : AppTheme.error,
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(
                _resultText,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isSuccess ? AppTheme.success : AppTheme.error,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() {
                  _state = _SheetState.idle;
                  _liveText = '';
                  _parsedCommand = null;
                  _resultText = '';
                }),
                icon: const Icon(Icons.mic, size: 18),
                label: const Text('Phir se bolo'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Band karo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.grey700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExampleCommands() {
    final examples = [
      ('📦', 'Stock update', '"Aloo ka stock 50 kilo kar"'),
      ('✅', 'Order deliver', '"Order number 47 deliver ho gaya"'),
      ('📊', 'Aaj ke orders', '"Aaj kitne order hain"'),
      ('💰', 'Revenue check', '"Aaj kitni kamai hui"'),
      ('🔍', 'Stock check', '"Kitna aloo bacha hai"'),
      ('📉', 'Low stock', '"Kya khatam ho raha hai"'),
      ('⏱️', 'Expiring soon', '"Kya expire hone wala hai"'),
      ('🏷️', 'Set price', '"Aloo ka price 40 rupaye kar"'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        const Text(
          'Ye bol sakte ho 👇',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.grey600),
        ),
        const SizedBox(height: 10),
        ...examples.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(e.$1, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.$2,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.grey500,
                        ),
                      ),
                      Text(
                        e.$3,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.grey700,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
