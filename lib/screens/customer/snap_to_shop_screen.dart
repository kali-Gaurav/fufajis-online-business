import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/product_provider.dart';
import '../../models/product_model.dart';
import '../../services/ai_search_service.dart';
import '../../utils/app_theme.dart';

class SnapToShopScreen extends StatefulWidget {
  const SnapToShopScreen({super.key});

  @override
  State<SnapToShopScreen> createState() => _SnapToShopScreenState();
}

class _SnapToShopScreenState extends State<SnapToShopScreen> with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final AISearchService _aiService = AISearchService();
  
  XFile? _selectedImage;
  bool _isAnalyzing = false;
  List<String> _analysisLogs = [];
  List<ProductModel> _matchedProducts = [];
  late AnimationController _laserController;
  
  // Debug mode simulation label selection
  String? _selectedSimulationLabel;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _laserController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _selectedImage = image;
          _matchedProducts.clear();
        });
        _runImageAnalysis();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error choosing image: $e')),
      );
    }
  }

  Future<void> _runImageAnalysis() async {
    if (_selectedImage == null) return;

    setState(() {
      _isAnalyzing = true;
      _analysisLogs = [
        '[AI] Starting vision model...',
      ];
    });
    _laserController.repeat(reverse: true);

    // Simulate progressive log messages
    final logs = [
      '[AI] Adjusting image exposure...',
      '[AI] Analyzing colors & textures...',
      '[AI] Running boundary contour detector...',
      '[AI] Matching features with catalog tags...',
    ];

    for (var i = 0; i < logs.length; i++) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() {
        _analysisLogs.add(logs[i]);
      });
    }

    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final catalog = productProvider.products;

    final results = await _aiService.identifyProductFromImage(
      _selectedImage!,
      catalog,
      simulatedLabel: _selectedSimulationLabel,
    );

    if (!mounted) return;

    setState(() {
      _isAnalyzing = false;
      _matchedProducts = results;
      _laserController.stop();
      _analysisLogs.add(results.isNotEmpty 
          ? '[AI] Successfully matched ${results.length} item(s)!' 
          : '[AI] No direct matches found in local store.');
    });
  }

  void _resetPicker() {
    setState(() {
      _selectedImage = null;
      _isAnalyzing = false;
      _matchedProducts.clear();
      _analysisLogs.clear();
      _selectedSimulationLabel = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppTheme.grey900,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Snap to Shop'),
        centerTitle: true,
        actions: [
          if (_selectedImage != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetPicker,
            )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _selectedImage == null 
                  ? _buildImageSelectionView() 
                  : _buildAnalysisViewport(size),
            ),
            if (_selectedImage != null && !_isAnalyzing)
              _buildResultsContainer(),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSelectionView() {
    final mockKeywords = ['Potato', 'Tomato', 'Onion', 'Paneer', 'Milk', 'Bread', 'Apple'];
    
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt_outlined,
                size: 64,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Identify Products instantly',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Snap a picture or upload an image of any product to instantly find it on Fufaji\'s online store.',
              style: TextStyle(color: AppTheme.grey400, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            
            // Camera Button
            ElevatedButton.icon(
              onPressed: () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt, color: Colors.white),
              label: const Text('Take a Photo', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 16),
            
            // Gallery Button
            OutlinedButton.icon(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library, color: AppTheme.primary),
              label: const Text('Upload from Gallery', style: TextStyle(fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                minimumSize: const Size(double.infinity, 54),
                side: const BorderSide(color: AppTheme.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 36),

            // Simulation / Testing Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.bug_report_outlined, color: AppTheme.warning, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Demo Simulation Tool',
                        style: TextStyle(color: AppTheme.warning, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select a target item below to simulate a successful AI identification of that product:',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: mockKeywords.map((label) {
                      final isSelected = _selectedSimulationLabel == label;
                      return ChoiceChip(
                        label: Text(label),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedSimulationLabel = selected ? label : null;
                          });
                        },
                        selectedColor: AppTheme.primary,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppTheme.grey300,
                          fontSize: 12,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisViewport(Size size) {
    final analysisAreaSize = size.width * 0.8;

    return Stack(
      children: [
        // Uploaded/Snapped Image
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              width: analysisAreaSize,
              height: analysisAreaSize,
              child: Image.file(
                File(_selectedImage!.path),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),

        // Scanning Laser overlay
        if (_isAnalyzing)
          Center(
            child: SizedBox(
              width: analysisAreaSize,
              height: analysisAreaSize,
              child: AnimatedBuilder(
                animation: _laserController,
                builder: (context, child) {
                  final laserOffset = _laserController.value * (analysisAreaSize - 4);
                  return Stack(
                    children: [
                      Positioned(
                        top: laserOffset,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.9),
                                blurRadius: 10,
                                spreadRadius: 3,
                              ),
                            ],
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

        // Live logs container overlay
        Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'AI VISION PIPELINE STATUS',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    if (_isAnalyzing)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._analysisLogs.map((log) => Padding(
                  padding: const EdgeInsets.only(bottom: 2.0),
                  child: Text(
                    log,
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsContainer() {
    if (_matchedProducts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.grey800,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const Icon(Icons.info_outline, color: AppTheme.warning, size: 48),
            const SizedBox(height: 12),
            const Text(
              'No items detected',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'We couldn\'t find matches in the Fufaji store catalog.',
              style: TextStyle(color: AppTheme.grey400, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _resetPicker,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              child: const Text('Try Another Photo'),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppTheme.grey800,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MATCHING CATALOG PRODUCTS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _matchedProducts.length,
            itemBuilder: (context, index) {
              final product = _matchedProducts[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        product.imageUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(
                          width: 50,
                          height: 50,
                          color: AppTheme.grey700,
                          child: const Icon(Icons.image, color: Colors.white30),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '₹${product.price.toStringAsFixed(0)} / ${product.unit}',
                            style: const TextStyle(color: AppTheme.primary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        // Navigate directly to detail screen
                        context.go('/customer/product/${product.id}');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: const Text('View Product'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

