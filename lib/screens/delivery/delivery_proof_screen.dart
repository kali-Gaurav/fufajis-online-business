import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../models/delivery_task_model.dart';
import '../../models/proof_of_delivery_model.dart';
import '../../providers/delivery_last_mile_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/otp_input_field.dart';
import '../../widgets/delivery_progress_stepper.dart';

class DeliveryProofScreen extends StatefulWidget {
  final DeliveryTaskModel delivery;

  const DeliveryProofScreen({
    super.key,
    required this.delivery,
  });

  @override
  State<DeliveryProofScreen> createState() => _DeliveryProofScreenState();
}

class _DeliveryProofScreenState extends State<DeliveryProofScreen> {
  int _currentStep = 0; // 0: OTP, 1: Photo, 2: Signature, 3: Complete
  final List<bool> _completedSteps = [false, false, false, false];

  bool _otpVerified = false;
  bool _photoTaken = false;
  bool _signatureProvided = false;
  bool _checkboxConfirmed = false;

  String? _photoPath;

  final int _otpResendCountdown = 0;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _generateOTP();
  }

  Future<void> _generateOTP() async {
    final provider = context.read<DeliveryLastMileProvider>();
    await provider.generateOTP(widget.delivery.deliveryId);
  }

  void _handleOTPComplete(String otp) async {
    final provider = context.read<DeliveryLastMileProvider>();
    final isValid = await provider.verifyOTP(widget.delivery.deliveryId, otp);

    if (isValid) {
      setState(() {
        _otpVerified = true;
        _completedSteps[0] = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP Verified Successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } else {
      if (mounted) {
        final remainingAttempts = provider.otpAttemptsRemaining;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid OTP. $remainingAttempts attempts remaining.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _moveToNextStep() {
    if (_currentStep < 3) {
      setState(() {
        _currentStep++;
      });
    }
  }

  void _moveToPreviousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  Future<void> _completeDelivery() async {
    final provider = context.read<DeliveryLastMileProvider>();

    VerificationMethod method = VerificationMethod.otp;
    if (!_otpVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please verify OTP first'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final success = await provider.completeDelivery(
      widget.delivery.deliveryId,
      method,
    );

    if (success && mounted) {
      // Show success animation
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.success,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: AppTheme.success,
                    size: 50,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Delivery Completed!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Order #${widget.delivery.orderNumber} delivered successfully',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.of(context).pop(); // Close screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${widget.delivery.orderNumber}'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress stepper
            Padding(
              padding: const EdgeInsets.all(16),
              child: DeliveryProgressStepper(
                currentStep: _currentStep,
                completedSteps: _completedSteps,
              ),
            ),
            const Divider(),

            // Step content
            Expanded(
              child: PageView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildOTPStep(),
                  _buildPhotoStep(),
                  _buildSignatureStep(),
                  _buildCompleteStep(),
                ],
              ),
            ),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _moveToPreviousStep,
                        child: const Text('Back'),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _currentStep < 3 ? _moveToNextStep : _completeDelivery,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.info,
                      ),
                      child: Text(
                        _currentStep < 3 ? 'Next' : 'Complete Delivery',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOTPStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Step 1: OTP Verification',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the 6-digit OTP shared with the customer',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),

          // OTP input fields
          OTPInputField(
            length: 6,
            onComplete: _handleOTPComplete,
          ),
          const SizedBox(height: 32),

          // Attempts remaining
          Consumer<DeliveryLastMileProvider>(
            builder: (context, provider, _) => Text(
              '${provider.otpAttemptsRemaining} attempts remaining',
              style: TextStyle(
                fontSize: 12,
                color: provider.otpAttemptsRemaining <= 1 ? AppTheme.error : Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Resend button
          if (!_otpVerified)
            Center(
              child: TextButton(
                onPressed: _otpResendCountdown == 0 ? _generateOTP : null,
                child: Text(
                  _otpResendCountdown > 0
                      ? 'Resend OTP in ${_otpResendCountdown}s'
                      : 'Resend OTP',
                ),
              ),
            ),

          const SizedBox(height: 32),

          // Success indicator
          if (_otpVerified)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.1),
                border: Border.all(color: AppTheme.success),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: AppTheme.success),
                  SizedBox(width: 12),
                  Text(
                    'OTP Verified Successfully',
                    style: TextStyle(
                      color: AppTheme.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhotoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Step 2: Photo Proof (Optional)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Take a photo of the package for proof',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),

          if (_photoPath == null)
            Center(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final XFile? image = await _picker.pickImage(source: ImageSource.camera);
                  if (image != null) {
                    setState(() {
                      _photoTaken = true;
                      _photoPath = image.path;
                    });
                  }
                },
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Photo'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            )
          else
            Column(
              children: [
                Container(
                  width: double.infinity,
                  height: 300,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: FileImage(File(_photoPath!)),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _photoPath = null;
                            _photoTaken = false;
                          });
                        },
                        child: const Text('Retake'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _completedSteps[1] = true;
                          });
                        },
                        child: const Text('Use Photo'),
                      ),
                    ),
                  ],
                ),
              ],
            ),

          if (_photoTaken)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: AppTheme.success),
                  SizedBox(width: 8),
                  Text(
                    'Photo added',
                    style: TextStyle(color: AppTheme.success),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSignatureStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Step 3: Signature/Confirmation',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),

          // Option 1: Signature
          if (!_checkboxConfirmed)
            Column(
              children: [
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(Icons.edit, size: 48, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _signatureProvided = false;
                          });
                        },
                        child: const Text('Clear'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _signatureProvided = true;
                            _completedSteps[2] = true;
                          });
                        },
                        child: const Text('Save Signature'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),
              ],
            ),

          // Option 2: Checkbox
          CheckboxListTile(
            title: const Text('I confirm receipt of the order', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Check if customer received the package', style: TextStyle(fontWeight: FontWeight.w700)),
            value: _checkboxConfirmed,
            onChanged: (value) {
              setState(() {
                _checkboxConfirmed = value ?? false;
                if (_checkboxConfirmed) {
                  _completedSteps[2] = true;
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delivery Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Order details
          _buildSummaryItem(
            'Order Number',
            '#${widget.delivery.orderNumber}',
          ),
          const SizedBox(height: 16),
          _buildSummaryItem(
            'Customer',
            widget.delivery.customerName,
          ),
          const SizedBox(height: 16),
          _buildSummaryItem(
            'Address',
            widget.delivery.customerAddress,
          ),
          const SizedBox(height: 24),

          // Verification checklist
          const Text(
            'Delivery Verified',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildChecklistItem('OTP Verification', _otpVerified),
          _buildChecklistItem('Photo Proof', _photoTaken),
          _buildChecklistItem('Signature/Confirmation', _signatureProvided || _checkboxConfirmed),
          const SizedBox(height: 24),

          // Final note
          if (_otpVerified && (_photoTaken || _signatureProvided || _checkboxConfirmed))
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.1),
                border: Border.all(color: AppTheme.success),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, color: AppTheme.success),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'All verification steps completed. Ready to submit.',
                      style: TextStyle(color: AppTheme.success),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildChecklistItem(String label, bool isCompleted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isCompleted ? AppTheme.success : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isCompleted ? Colors.black : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
