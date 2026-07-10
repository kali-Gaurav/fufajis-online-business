import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/support_provider.dart';

class IssueReportScreen extends StatefulWidget {
  final String orderId;

  const IssueReportScreen({Key? key, required this.orderId}) : super(key: key);

  @override
  State<IssueReportScreen> createState() => _IssueReportScreenState();
}

class _IssueReportScreenState extends State<IssueReportScreen> {
  String? selectedIssueType;
  final descriptionController = TextEditingController();
  final List<String> photoUrls = [];
  final Set<String> selectedEvidence = {};
  bool isSubmitting = false;

  final List<Map<String, String>> issueTypes = [
    {'type': 'missing', 'label': 'Item Missing', 'icon': '📦'},
    {'type': 'damaged', 'label': 'Item Damaged', 'icon': '💔'},
    {'type': 'wrong', 'label': 'Wrong Item Delivered', 'icon': '❌'},
    {'type': 'quantity', 'label': 'Quantity Mismatch', 'icon': '⚖️'},
    {'type': 'delivery', 'label': 'Poor Delivery Experience', 'icon': '😞'},
    {'type': 'other', 'label': 'Other', 'icon': '❓'},
  ];

  final List<String> evidenceOptions = [
    'Damaged packaging',
    'Item quality issue',
    'Quantity discrepancy',
  ];

  @override
  void dispose() {
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Issue'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order ID
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Order #${widget.orderId.substring(0, 8)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
            const SizedBox(height: 24),

            // Issue Type Selection
            Text(
              'Select Issue Type:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ...issueTypes.map((issue) {
              final isSelected = selectedIssueType == issue['type'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  color: isSelected ? Colors.blue.shade50 : null,
                  child: RadioListTile(
                    value: issue['type']!,
                    groupValue: selectedIssueType,
                    onChanged: (value) {
                      setState(() {
                        selectedIssueType = value;
                      });
                    },
                    title: Row(
                      children: [
                        Text(issue['icon']!, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 12),
                        Text(issue['label']!),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 24),

            // Description
            Text(
              'Description (max 500 chars):',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descriptionController,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Describe the issue in detail...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                counterText: '${descriptionController.text.length}/500',
              ),
              onChanged: (_) {
                setState(() {});
              },
            ),
            const SizedBox(height: 24),

            // Photo Upload
            Text(
              'Attach Photo (optional):',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Photo'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.image),
                    label: const Text('Upload'),
                  ),
                ),
              ],
            ),
            if (photoUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: photoUrls.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey.shade200,
                            ),
                            child: Image.network(
                              photoUrls[index],
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  photoUrls.removeAt(index);
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Evidence Checkboxes
            Text(
              'Add Evidence (optional):',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: evidenceOptions.map((option) {
                  return CheckboxListTile(
                    value: selectedEvidence.contains(option),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          selectedEvidence.add(option);
                        } else {
                          selectedEvidence.remove(option);
                        }
                      });
                    },
                    title: Text(option),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSubmitting || selectedIssueType == null || descriptionController.text.isEmpty
                    ? null
                    : _submitReport,
                child: isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('SUBMIT & ESCALATE'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      // TODO: Implement image picker and upload to Firebase Storage
      // For now, just show a message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image picker coming soon')),
      );
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  Future<void> _submitReport() async {
    if (selectedIssueType == null || descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select issue type and add description')),
      );
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      await context.read<SupportProvider>().createTicket(
            orderId: widget.orderId,
            issueType: selectedIssueType!,
            description: descriptionController.text,
            photoUrls: photoUrls.isNotEmpty ? photoUrls : null,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Issue reported successfully. Support team will contact you soon.')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }
}
