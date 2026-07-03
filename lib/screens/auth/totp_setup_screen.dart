import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../services/mfa_service.dart';
import '../../utils/app_theme.dart';

/// Guides the user through connecting an authenticator app (TOTP-based 2FA).
/// Flow: Show QR + secret → user scans → enters code → confirm.
class TotpSetupScreen extends StatefulWidget {
  const TotpSetupScreen({super.key});

  @override
  State<TotpSetupScreen> createState() => _TotpSetupScreenState();
}

class _TotpSetupScreenState extends State<TotpSetupScreen> {
  final _mfa = MfaService();
  final _codeController = TextEditingController();

  int _step = 0; // 0=loading, 1=scan, 2=verify, 3=backup, 4=done
  String? _otpauthUri;
  String? _secret;
  List<String>? _backupCodes;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initSetup();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _initSetup() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    final result = await _mfa.initiateTOTPSetup(userId: user.id, userEmail: user.email ?? '');

    if (!mounted) return;
    if (result.success) {
      setState(() {
        _otpauthUri = result.otpauthUri;
        _secret = result.totpSecret;
        _step = 1;
      });
    } else {
      setState(() => _error = result.message);
    }
  }

  Future<void> _confirm() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from your authenticator app.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    final result = await _mfa.confirmTOTPSetup(
      userId: user.id,
      userEmail: user.email ?? '',
      code: code,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result.success) {
      setState(() {
        _backupCodes = result.backupCodes;
        _step = 3;
      });
    } else {
      setState(() => _error = result.message);
      _codeController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(
        title: const Text(
          'Set Up Authenticator App',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    switch (_step) {
      case 0:
        return _buildLoading();
      case 1:
        return _buildScanStep();
      case 2:
        return _buildVerifyStep();
      case 3:
        return _buildBackupCodesStep();
      default:
        return _buildLoading();
    }
  }

  Widget _buildLoading() => const Center(
    child: Padding(
      padding: EdgeInsets.all(48),
      child: CircularProgressIndicator(color: AppTheme.primary),
    ),
  );

  Widget _buildScanStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        _stepIndicator(1),
        const SizedBox(height: 24),
        Text(
          'Scan with Authenticator App',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.grey900),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Open Google Authenticator, Microsoft Authenticator, or any TOTP app and scan the QR code below.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.grey600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        if (_otpauthUri != null) ...[
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 8)],
            ),
            padding: const EdgeInsets.all(16),
            child: QrImageView(
              data: _otpauthUri!,
              version: QrVersions.auto,
              size: 220,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF1F2937)),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Or enter the key manually:', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: _secret ?? ''));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Secret copied to clipboard')));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.grey100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.grey300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _secret ?? '',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.copy, size: 16, color: AppTheme.grey600),
                ],
              ),
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppTheme.error)),
        ],
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => setState(() => _step = 2),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('I\'ve Scanned the Code', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildVerifyStep() {
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.grey300),
        borderRadius: BorderRadius.circular(12),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        _stepIndicator(2),
        const SizedBox(height: 24),
        Text(
          'Enter the 6-digit code',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.grey900),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Enter the code shown in your authenticator app to confirm setup.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.grey600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        Pinput(
          controller: _codeController,
          length: 6,
          defaultPinTheme: defaultPinTheme,
          focusedPinTheme: defaultPinTheme.copyWith(
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.primary, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onCompleted: (_) => _confirm(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(
            _error!,
            style: const TextStyle(color: AppTheme.error),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submitting ? null : _confirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Verify', style: TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => _step = 1),
          child: const Text('Back to QR code'),
        ),
      ],
    );
  }

  Widget _buildBackupCodesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        _stepIndicator(3),
        const SizedBox(height: 24),
        Text(
          'Save Your Backup Codes',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.grey900),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryLight,
            border: Border.all(color: AppTheme.warning),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppTheme.warning),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Store these in a safe place. Each code can only be used once.',
                  style: TextStyle(color: AppTheme.warning, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (_backupCodes != null) ...[
          ...List.generate(
            _backupCodes!.length,
            (i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.grey100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.grey300),
                ),
                child: Row(
                  children: [
                    Text(
                      '${i + 1}. ',
                      style: const TextStyle(color: AppTheme.grey500, fontSize: 13),
                    ),
                    Expanded(
                      child: Text(
                        _backupCodes![i],
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _backupCodes!.join('\n')));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Backup codes copied to clipboard')));
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy All'),
          ),
        ],
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Done — I\'ve Saved My Codes', style: TextStyle(fontSize: 15)),
          ),
        ),
      ],
    );
  }

  Widget _stepIndicator(int current) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [1, 2, 3].map((step) {
        final active = step == current;
        final done = step < current;
        return Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: done
                  ? AppTheme.success
                  : active
                  ? AppTheme.primary
                  : AppTheme.grey300,
              child: done
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : Text(
                      '$step',
                      style: TextStyle(
                        color: active ? Colors.white : AppTheme.grey600,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
            ),
            if (step < 3)
              Container(width: 40, height: 2, color: done ? AppTheme.success : AppTheme.grey300),
          ],
        );
      }).toList(),
    );
  }
}
