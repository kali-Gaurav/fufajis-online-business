import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';

class WhatsAppSyncSetupScreen extends StatelessWidget {
  const WhatsAppSyncSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final phoneNumber = user?.phoneNumber ?? 'Not Registered';

    return Scaffold(
      appBar: AppBar(
        title: const Text('WhatsApp Inventory Sync'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 30),
            _buildStatusCard(phoneNumber),
            const SizedBox(height: 30),
            const Text(
              'How it works',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 15),
            _buildStep(
              number: '1',
              title: 'Save our Number',
              description:
                  'Save +91 98765 43210 in your contacts as "Fufaji Inventory".',
              icon: Icons.contact_phone,
            ),
            _buildStep(
              number: '2',
              title: 'Send a Photo',
              description:
                  'Take a clear photo of your purchase bill or handwritten list.',
              icon: Icons.camera_alt,
            ),
            _buildStep(
              number: '3',
              title: 'AI Magic',
              description:
                  'Our AI will read the bill and automatically update your inventory.',
              icon: Icons.auto_awesome,
            ),
            const SizedBox(height: 40),
            _buildTestButton(context),
            const SizedBox(height: 20),
            _buildFAQ(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat, size: 80, color: Colors.green),
          ),
        ),
        const SizedBox(height: 15),
        const Center(
          child: Text(
            'Sync your inventory effortlessly\nusing WhatsApp',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(String phone) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.verified, color: Colors.green),
              const SizedBox(width: 10),
              const Text(
                'Registration Status',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'ACTIVE',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Registered Phone:'),
              Text(phone, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: phone));
              // Show snack bar
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy ID'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade100,
              foregroundColor: Colors.black87,
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep({
    required String number,
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 20, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(description, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          const message =
              "Hi Fufaji, I want to sync my inventory via WhatsApp. Please guide me.";
          final url = Uri.parse(
            "https://wa.me/919999999999?text=${Uri.encodeComponent(message)}",
          );
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: const Text(
          'Try it on WhatsApp',
          style: TextStyle(fontSize: 18, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildFAQ() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Frequently Asked Questions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        _FAQItem(
          question: 'Does it support Hindi bills?',
          answer: 'Yes, our AI supports Hindi, English, and Hinglish.',
        ),
        _FAQItem(
          question: 'How long does it take?',
          answer: 'Usually under 30 seconds to process a full bill.',
        ),
      ],
    );
  }
}

class _FAQItem extends StatelessWidget {
  final String question;
  final String answer;

  const _FAQItem({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(answer, style: const TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}
