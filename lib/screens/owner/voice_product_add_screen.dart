import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../providers/auth_provider.dart';
import '../../services/gemini_service.dart';
import '../../services/speech_to_text_service.dart';
import '../../services/image_processing_service.dart';
import '../../providers/product_provider.dart';
import '../../models/product_model.dart';
import '../../utils/app_theme.dart';

/// Voice Product Add Screen - Allows shop owners to add products via voice
/// Supports Hindi and English voice input with AI-powered parsing
class VoiceProductAddScreen extends StatefulWidget {
  const VoiceProductAddScreen({super.key});

  @override
  State<VoiceProductAddScreen> createState() => _VoiceProductAddScreenState();
}

class _VoiceProductAddScreenState extends State<VoiceProductAddScreen> {
  final SpeechToTextService _speechService = SpeechToTextService();
  final GeminiService _geminiService = GeminiService();
  final ImageProcessingService _imageService = ImageProcessingService();

  bool _isProcessing = false;
  String _transcribedText = '';
  String _statusMessage = 'Tap the microphone and describe your product';

  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();

  String _selectedCategory = 'groceries';
  File? _productImage;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _unitController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    // Request permissions
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      _showError('Microphone permission is required');
      return;
    }

    setState(() {
      _isListening = true;
      _statusMessage = 'Listening... Speak clearly about your product';
      _transcribedText = '';
    });

    try {
      await _speechService.startListening(
        onResult: (text) {
          if (mounted) {
            setState(() {
              _transcribedText = text;
              _statusMessage = 'Heard: "$text"';
            });
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _isListening = false;
              _statusMessage = 'Error: $error';
            });
          }
        },
      );
    } catch (e) {
      setState(() {
        _isListening = false;
        _statusMessage = 'Failed to start recording: $e';
      });
    }
  }

  Future<void> _stopRecording() async {
    setState(() {
      _isListening = false;
      _statusMessage = 'Processing your voice input...';
    });

    try {
      final text = await _speechService.stopListening();

      if (text.isNotEmpty) {
        setState(() {
          _transcribedText = text;
          _statusMessage = 'Processing: "$text"';
        });

        // Parse the transcribed text using Gemini
        await _parseVoiceInput(text);
      } else {
        setState(() {
          _statusMessage = 'No speech detected. Try again.';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error processing speech: $e';
      });
    }
  }

  Future<void> _parseVoiceInput(String text) async {
    setState(() => _isProcessing = true);

    try {
      // Use Gemini to parse the voice input into product details
      final productData = await _geminiService.parseProductFromVoice(
        text,
        context: 'Hindi/English Indian grocery context',
      );

      if (mounted) {
        setState(() {
          _statusMessage = 'Product details extracted! Review and edit below.';

          // Populate form fields
          _nameController.text = productData.name;
          _descriptionController.text = productData.description;
          _priceController.text = productData.price.toString();
          _stockController.text = productData.stockQuantity.toString();
          _unitController.text = productData.unit;
          _selectedCategory = productData.category;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage =
              'Failed to parse: $e. Please enter details manually.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final image = await _imageService.pickAndProcessImage(context);
      if (image != null && mounted) {
        setState(() => _productImage = image);
      }
    } catch (e) {
      _showError('Failed to process image: $e');
    }
  }

  Future<void> _saveProduct() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;

    if (currentUser == null) {
      _showError('Please login first');
      return;
    }

    // Validate required fields
    if (_nameController.text.isEmpty) {
      _showError('Product name is required');
      return;
    }

    final price = double.tryParse(_priceController.text);
    if (price == null || price <= 0) {
      _showError('Please enter a valid price');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final productProvider = Provider.of<ProductProvider>(
        context,
        listen: false,
      );

      // Create product model
      final product = ProductModel(
        id: const Uuid().v4(),
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        price: price,
        originalPrice: price,
        unit: _unitController.text.trim().isNotEmpty
            ? _unitController.text.trim()
            : 'piece',
        category: _selectedCategory,
        shopId: currentUser.id,
        shopName: currentUser.name ?? 'Shop',
        imageUrl: '',
        images: _productImage != null ? [_productImage!.path] : [],
        stockQuantity: int.tryParse(_stockController.text) ?? 0,
        isAvailable: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        district: currentUser.district ?? 'Jaipur',
        village: currentUser.village ?? '',
      );

      // Add to Firestore via Provider
      await productProvider.addProduct(product);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product added successfully to your shop!'),
            backgroundColor: AppTheme.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      _showError('Failed to save product: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Add Product'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Voice input section
            _buildVoiceInputSection(),

            const SizedBox(height: 24),

            // Transcribed text display
            if (_transcribedText.isNotEmpty) _buildTranscribedTextDisplay(),

            const SizedBox(height: 24),

            // Product form
            _buildProductForm(),

            const SizedBox(height: 24),

            // Image picker
            _buildImagePicker(),

            const SizedBox(height: 32),

            // Save button
            _buildSaveButton(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceInputSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.1),
            AppTheme.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // Microphone button
          GestureDetector(
            onTap: _isListening ? _stopRecording : _startRecording,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: _isListening ? AppTheme.error : AppTheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_isListening ? AppTheme.error : AppTheme.primary)
                        .withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                _isListening ? Icons.stop : Icons.mic,
                size: 48,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Status message
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: _isListening ? AppTheme.primary : AppTheme.grey600,
              fontWeight: _isListening ? FontWeight.w600 : FontWeight.normal,
            ),
          ),

          const SizedBox(height: 16),

          // Example phrases
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.grey200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 16,
                      color: AppTheme.warning,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Try saying:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildExamplePhrase(
                  '"Add 20 kg organic apples priced at 150 rupees"',
                ),
                _buildExamplePhrase(
                  '"Add 1 liter Amul milk, 50 rupees, 10 in stock"',
                ),
                _buildExamplePhrase(
                  '"Add 500g Tata salt, 25 rupees, 50 packets"',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamplePhrase(String phrase) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, bottom: 4),
      child: Text(
        phrase,
        style: const TextStyle(
          fontSize: 12,
          color: AppTheme.grey600,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildTranscribedTextDisplay() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.success, size: 20),
              SizedBox(width: 8),
              Text(
                'Transcribed Text',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '"$_transcribedText"',
            style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildProductForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Product Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.grey900,
          ),
        ),
        const SizedBox(height: 16),

        // Product name
        _buildTextField(
          controller: _nameController,
          label: 'Product Name *',
          hint: 'e.g., Organic Apples',
          icon: Icons.inventory_2,
        ),

        const SizedBox(height: 12),

        // Description
        _buildTextField(
          controller: _descriptionController,
          label: 'Description',
          hint: 'Describe your product...',
          icon: Icons.description,
          maxLines: 3,
        ),

        const SizedBox(height: 12),

        // Price and Stock row
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _priceController,
                label: 'Price (₹) *',
                hint: '0.00',
                icon: Icons.attach_money,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(
                controller: _stockController,
                label: 'Stock Qty',
                hint: '0',
                icon: Icons.inventory,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Unit and Category row
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _unitController,
                label: 'Unit',
                hint: 'e.g., kg, piece, liter',
                icon: Icons.straighten,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _buildCategoryDropdown()),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppTheme.grey400),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    final categories = [
      'groceries',
      'vegetables',
      'fruits',
      'dairy',
      'bakery',
      'snacks',
      'beverages',
      'household',
      'personalCare',
      'other',
    ];

    return DropdownButtonFormField<String>(
      initialValue: _selectedCategory,
      decoration: InputDecoration(
        labelText: 'Category',
        prefixIcon: const Icon(Icons.category, color: AppTheme.grey400),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.all(16),
      ),
      items: categories.map((category) {
        return DropdownMenuItem(
          value: category,
          child: Text(category[0].toUpperCase() + category.substring(1)),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() => _selectedCategory = value);
        }
      },
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Product Image',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.grey800,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.grey100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.grey300),
            ),
            child: _productImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_productImage!, fit: BoxFit.cover),
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt, size: 40, color: AppTheme.grey400),
                      SizedBox(height: 8),
                      Text(
                        'Tap to add photo',
                        style: TextStyle(color: AppTheme.grey500),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _isProcessing ? null : _saveProduct,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _isProcessing
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text(
              'Add Product',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('How to use Voice Add'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHelpItem('1', 'Tap the microphone button'),
              _buildHelpItem('2', 'Speak clearly about your product'),
              _buildHelpItem('3', 'Include: name, price, quantity, unit'),
              _buildHelpItem('4', 'Review and edit the extracted details'),
              _buildHelpItem('5', 'Tap "Add Product" to save'),
              const SizedBox(height: 16),
              const Text(
                'Tip: Speak in Hindi or English. Example: "Add 1 kg potatoes at 40 rupees"',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: AppTheme.grey600,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHelpItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
