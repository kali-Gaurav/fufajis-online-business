import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/cart_provider.dart';
import '../../utils/app_theme.dart';
import 'product_detail_screen.dart';
import 'barcode_scanner_screen.dart';
import 'package:flutter/services.dart';
import '../../services/gemini_service.dart' show GeminiService;
class SearchScreen extends StatefulWidget {
  final String? initialQuery;
  const SearchScreen({super.key, this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}



class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final GeminiService _geminiService = GeminiService();
  
  // Voice search variables
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _voiceLocale = 'hi_IN'; // Default to Hindi, can toggle to English
  double _soundLevel = 0.0;
  String _transcription = '';
  bool _speechInitialized = false;
  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  String _searchQuery = '';
  final List<String> _recentSearches = [];
  final List<String> _popularSearches = [
    'Rice', 'Wheat Flour', 'Sugar', 'Milk', 'Bread', 
    'Vegetables', 'Fruits', 'Oil', 'Spices', 'Dal',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performSearch(widget.initialQuery!);
      });
    } else {
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchQuery = query;
    });

    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    _searchResults = productProvider.searchProducts(query);

    if (_searchQuery.isNotEmpty && !_recentSearches.contains(_searchQuery)) {
      _recentSearches.insert(0, _searchQuery);
      if (_recentSearches.length > 10) {
        _recentSearches.removeLast();
      }
    }

    setState(() => _isSearching = false);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _searchQuery = '';
    });
    _focusNode.requestFocus();
  }

  Future<bool> _initSpeech() async {
    if (_speechInitialized) return true;
    try {
      _speechInitialized = await _speech.initialize(
        onStatus: (status) {
          debugPrint('Speech status changed: $status');
          if (status == 'notListening' || status == 'done') {
            setState(() => _isListening = false);
          }
        },
        onError: (errorNotification) {
          debugPrint('Speech error: $errorNotification');
          setState(() => _isListening = false);
        },
      );
      return _speechInitialized;
    } catch (e) {
      debugPrint('Error initializing speech: $e');
      return false;
    }
  }

  void _startVoiceSearch() async {
    final initialized = await _initSpeech();
    if (!initialized) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Speech recognition is not available on this device.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    _transcription = '';
    _soundLevel = 0.0;
    var didStartListening = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateBottomSheet) {
            if (!didStartListening) {
              didStartListening = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _startListening(setStateBottomSheet);
              });
            }

            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.45,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppTheme.grey300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Language Selection Toggle Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLanguageToggle('hi_IN', 'à¤¹à¤¿à¤¨à¥à¤¦à¥€ (Hindi)', setStateBottomSheet),
                        const SizedBox(width: 12),
                        _buildLanguageToggle('en_US', 'English', setStateBottomSheet),
                      ],
                    ),
                    const Spacer(),

                    // Animated Mic & Soundwaves
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Ripple rings based on sound level
                        for (int i = 1; i <= 3; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 100),
                            width: 80 + (i * 30) + (_soundLevel * 15 * i),
                            height: 80 + (i * 30) + (_soundLevel * 15 * i),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primary.withValues(
                                alpha: (0.15 / i) * (_isListening ? 1.0 : 0.2)
                              ),
                            ),
                          ),
                        
                        // Central Glowing Mic Button
                        GestureDetector(
                          onLongPressStart: (_) {
                            HapticFeedback.heavyImpact();
                            _startListening(setStateBottomSheet);
                            setStateBottomSheet(() => _isListening = true);
                          },
                          onLongPressEnd: (_) {
                            HapticFeedback.selectionClick();
                            _stopListening();
                            setStateBottomSheet(() => _isListening = false);
                            
                            // Step 6.5: Auto-trigger search on speech end
                            if (_transcription.trim().isNotEmpty) {
                              _processVoiceResult();
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: _isListening
                                    ? [AppTheme.primary, const Color(0xFFFF8A65)]
                                    : [AppTheme.grey400, AppTheme.grey500],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (_isListening ? AppTheme.primary : AppTheme.grey500)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Icon(
                              _isListening ? Icons.mic : Icons.mic_none,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),

                    // Live Transcription display
                    Text(
                      _transcription.isEmpty
                          ? (_isListening ? 'Listening... बोलिए...' : 'Hold Mic to Speak')
                          : _transcription,
                      style: TextStyle(
                        fontSize: _transcription.isEmpty ? 16 : 20,
                        fontWeight: _transcription.isEmpty ? FontWeight.normal : FontWeight.bold,
                        color: _transcription.isEmpty ? AppTheme.grey500 : AppTheme.grey900,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 24),

                    // Quick Action Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            _stopListening();
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.close, color: AppTheme.grey600),
                          label: const Text('Cancel', style: TextStyle(color: AppTheme.grey700)),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            _stopListening();
                            if (_transcription.trim().isNotEmpty) {
                              _searchController.text = _transcription;
                              _performSearch(_transcription);
                            }
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          icon: const Icon(Icons.search),
                          label: const Text('Search Now'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      // Clean up when bottom sheet closes
      _stopListening();
    });
  }

  Widget _buildLanguageToggle(String localeCode, String label, StateSetter setStateBottomSheet) {
    final bool isSelected = _voiceLocale == localeCode;
    return GestureDetector(
      onTap: () {
        setStateBottomSheet(() {
          _voiceLocale = localeCode;
        });
        if (_isListening) {
          // Restart listening with new locale
          _stopListening();
          Future.delayed(const Duration(milliseconds: 100), () {
            _startListening(setStateBottomSheet);
            setStateBottomSheet(() {});
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withValues(alpha: 0.15) : AppTheme.grey100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.primary : AppTheme.grey700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  void _processVoiceResult() async {
    if (_transcription.trim().isEmpty) return;

    // Step 6.3: Gemini parser to extract keywords
    final keywords = await _geminiService.extractKeywordsForSearch(_transcription);
    
    if (mounted) {
      final query = keywords.isNotEmpty ? keywords.join(' ') : _transcription;
      _searchController.text = query;
      _performSearch(query);
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  void _startListening([StateSetter? setStateBottomSheet]) async {
    setState(() {
      _isListening = true;
      _transcription = '';
    });

    await _speech.listen(
      onResult: (result) {
        setState(() {
          _transcription = result.recognizedWords;
        });
        setStateBottomSheet?.call(() {
          _transcription = result.recognizedWords;
        });
        
        // Auto search if fully finalized result
        if (result.finalResult && _transcription.trim().isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted && Navigator.canPop(context)) {
              _searchController.text = _transcription;
              _performSearch(_transcription);
              Navigator.pop(context);
            }
          });
        }
      },
      onSoundLevelChange: (level) {
        setState(() => _soundLevel = level);
        setStateBottomSheet?.call(() => _soundLevel = level);
      },
      listenOptions: stt.SpeechListenOptions(
        cancelOnError: true,
        partialResults: true,
      ),
      localeId: _voiceLocale,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
    );
  }

  void _stopListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() {
        _isListening = false;
        _soundLevel = 0.0;
      });
    }
  }

  void _startBarcodeScanner() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const BarcodeScannerScreen(),
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      final query = result.trim();
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      final matchedProducts = productProvider.searchProducts(query);
      
      if (matchedProducts.isNotEmpty) {
        // Step 7.4: Instant "Add to Cart" pop-up
        _showInstantAddDialog(matchedProducts.first);
      } else {
        // Step 7.5: Fallback to "Product Not Found" form for owners
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.currentUser?.role == UserRole.shopOwner) {
          _showProductNotFoundForOwner(query);
        } else {
          _searchController.text = query;
          _performSearch(query);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Barcode '$query' scanned. No exact match."),
              backgroundColor: AppTheme.primary,
            ),
          );
        }
      }
    }
  }

  void _showInstantAddDialog(dynamic product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Product Found!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Price: ₹${product.price}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Provider.of<CartProvider>(context, listen: false).addToCart(product);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('Add to Cart', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showProductNotFoundForOwner(String barcode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Product Not Found'),
        content: Text('The product with barcode $barcode was not found in our catalog. Would you like to add it to your shop?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to add product screen with pre-filled barcode
              // context.push('/owner/add-product?barcode=$barcode');
            },
            child: const Text('Add Product'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            _buildSearchBar(),
            // Content
            Expanded(
              child: _searchQuery.isEmpty
                  ? _buildInitialContent()
                  : _isSearching
                      ? const Center(child: CircularProgressIndicator())
                      : _searchResults.isEmpty
                          ? _buildNoResults()
                          : _buildSearchResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.go('/customer/home'),
            icon: const Icon(Icons.arrow_back),
          ),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              autofocus: true,
              onChanged: _performSearch,
              decoration: InputDecoration(
                hintText: 'Search products...',
                hintStyle: const TextStyle(color: AppTheme.grey500),
                prefixIcon: const Icon(Icons.search, color: AppTheme.grey500),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        onPressed: _clearSearch,
                        icon: const Icon(Icons.close, color: AppTheme.grey500),
                      ),
                    IconButton(
                      onPressed: _startVoiceSearch,
                      icon: const Icon(Icons.mic, color: AppTheme.primary),
                    ),
                    IconButton(
                      onPressed: _startBarcodeScanner,
                      icon: const Icon(Icons.qr_code_scanner, color: AppTheme.primary),
                    ),
                    IconButton(
                      onPressed: () => context.push('/customer/snap-to-shop'),
                      icon: const Icon(Icons.camera_alt, color: AppTheme.primary),
                    ),
                  ],
                ),
                filled: true,
                fillColor: AppTheme.grey100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recent Searches
          if (_recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Searches',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.grey900,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _recentSearches.clear());
                  },
                  child: const Text(
                    'Clear All',
                    style: TextStyle(color: AppTheme.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recentSearches.map((search) {
                return ActionChip(
                  label: Text(search),
                  onPressed: () {
                    _searchController.text = search;
                    _performSearch(search);
                  },
                  backgroundColor: AppTheme.grey100,
                  labelStyle: const TextStyle(color: AppTheme.grey700),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],
          // Popular Searches
          const Text(
            'Popular Searches',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.grey900,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _popularSearches.map((search) {
              return ActionChip(
                label: Text(search),
                onPressed: () {
                  _searchController.text = search;
                  _performSearch(search);
                },
                backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                labelStyle: const TextStyle(color: AppTheme.primary),
                avatar: const Icon(
                  Icons.trending_up,
                  size: 16,
                  color: AppTheme.primary,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: AppTheme.grey300,
          ),
          const SizedBox(height: 16),
          const Text(
            'No products found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.grey700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try different keywords or browse categories',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.grey500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final product = _searchResults[index];
        return _buildSearchResultItem(product);
      },
    );
  }

  Widget _buildSearchResultItem(dynamic product) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    
    return GestureDetector(
      onTap: () => context.go('/customer/product/${product.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppTheme.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Product Image
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.grey100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: product.imageUrl.isNotEmpty
                  ? Image.network(
                      product.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.image_not_supported),
                    )
                  : const Icon(Icons.image, color: AppTheme.grey400),
            ),
            const SizedBox(width: 12),
            // Product Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.grey900,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.unit,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.grey500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (product.originalPrice != null &&
                              product.originalPrice! > product.price)
                            Text(
                              '₹${product.originalPrice!.round()}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.grey500,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          Text(
                            '₹${product.price.round()}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => cartProvider.addToCart(product),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

