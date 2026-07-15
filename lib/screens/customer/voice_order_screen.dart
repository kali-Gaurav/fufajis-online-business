import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../models/product_model.dart';
import '../../providers/product_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/accessibility_provider.dart';
import '../../services/speech_to_text_service.dart';
import '../../services/voice_order_parser.dart';
import '../../utils/app_theme.dart';

enum _Phase { idle, listening, processing, review }

/// Full-screen voice ordering:
///   tap mic -> speak a long list -> live transcription ->
///   stop -> parse + match -> review list (qty +/- , tick) -> add to cart.
class VoiceOrderScreen extends StatefulWidget {
  const VoiceOrderScreen({super.key});

  @override
  State<VoiceOrderScreen> createState() => _VoiceOrderScreenState();
}

class _VoiceOrderScreenState extends State<VoiceOrderScreen> with SingleTickerProviderStateMixin {
  final SpeechToTextService _stt = SpeechToTextService();
  final VoiceOrderParser _parser = VoiceOrderParser();

  late final AnimationController _pulse;

  _Phase _phase = _Phase.idle;
  String _liveText = '';
  String _finalText = '';
  String _error = '';
  List<ParsedVoiceItem> _items = [];

  bool _hindi = true; // locale: Hindi by default (Hinglish friendly)

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ap = context.read<AccessibilityProvider>();
      _hindi = ap.preferredLanguage != 'en';
      _stt.setLocale(_hindi ? SpeechToTextService.localeHindi : SpeechToTextService.localeEnglish);
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _stt.cancel();
    super.dispose();
  }

  String _t(String en, String hi) => _hindi ? hi : en;

  // ─────────────── mic control ───────────────

  Future<void> _startListening() async {
    setState(() {
      _phase = _Phase.listening;
      _liveText = '';
      _finalText = '';
      _error = '';
      _items = [];
    });
    await _stt.startListening(
      longForm: true,
      overrideLocale: _hindi ? SpeechToTextService.localeHindi : SpeechToTextService.localeEnglish,
      onPartialResult: (text) {
        if (mounted) setState(() => _liveText = text);
      },
      onResult: (text) {
        if (mounted) {
          _finalText = text;
          _process(text);
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() {
            _phase = _Phase.idle;
            _error = _t('Mic error. Please try again.', 'माइक में दिक्कत। दोबारा कोशिश करें।');
          });
        }
      },
    );
  }

  Future<void> _stopAndProcess() async {
    final text = await _stt.stopListening();
    final finalText = text.trim().isNotEmpty ? text : _liveText;
    _process(finalText);
  }

  Future<void> _process(String text) async {
    if (text.trim().isEmpty) {
      setState(() {
        _phase = _Phase.idle;
        _error = _t('I did not catch that. Try again.', 'सुनाई नहीं दिया। दोबारा बोलें।');
      });
      return;
    }
    setState(() {
      _phase = _Phase.processing;
      _finalText = text;
    });
    final catalog = context.read<ProductProvider>().products;
    final items = await _parser.parse(text, catalog);
    if (!mounted) return;
    setState(() {
      _items = items;
      _phase = _Phase.review;
    });
  }

  void _reset() {
    _stt.cancel();
    setState(() {
      _phase = _Phase.idle;
      _liveText = '';
      _finalText = '';
      _items = [];
      _error = '';
    });
  }

  // ─────────────── cart ───────────────

  int get _selectedCount => _items.where((i) => i.selected && i.isMatched).length;
  double get _selectedTotal =>
      _items.where((i) => i.selected && i.isMatched).fold(0.0, (s, i) => s + i.lineTotal);

  void _addToCart() {
    final cart = context.read<CartProvider>();
    int added = 0;
    for (final it in _items) {
      if (it.selected && it.product != null) {
        cart.addToCart(it.product!, quantity: it.quantity);
        added++;
      }
    }
    if (added == 0) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_t('$added items added to cart', '$added आइटम कार्ट में जुड़े')),
        backgroundColor: AppTheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
    context.push('/customer/cart');
  }

  // ─────────────── build ───────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
        title: Text(_t('Voice Order', 'बोलकर ऑर्डर करें')),
        actions: [if (_phase == _Phase.idle) _buildLangToggle()],
      ),
      body: SafeArea(child: _buildBody()),
      bottomNavigationBar: _phase == _Phase.review ? _buildBottomBar() : null,
    );
  }

  Widget _buildLangToggle() {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Center(
        child: GestureDetector(
          onTap: () {
            setState(() => _hindi = !_hindi);
            _stt.setLocale(
              _hindi ? SpeechToTextService.localeHindi : SpeechToTextService.localeEnglish,
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _hindi ? 'हिंदी' : 'EN',
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case _Phase.idle:
        return _buildIdle();
      case _Phase.listening:
        return _buildListening();
      case _Phase.processing:
        return _buildProcessing();
      case _Phase.review:
        return _buildReview();
    }
  }

  // ---- idle ----
  Widget _buildIdle() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          _micButton(active: false, onTap: _startListening),
          const SizedBox(height: 28),
          Text(
            _t('Tap the mic and say your order', 'माइक दबाएँ और अपना ऑर्डर बोलें'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.grey900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _t('You can say a whole list at once.', 'आप एक साथ पूरी लिस्ट बोल सकते हैं।'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppTheme.grey600),
          ),
          const SizedBox(height: 24),
          _exampleCard(),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              _error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.error, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _exampleCard() {
    final ex = _hindi
        ? '"दो किलो आलू, पाँच प्याज़, एक पैकेट दूध और तीन किलो चीनी"'
        : '"2 kg potato, 5 onions, 1 packet milk and 3 kg sugar"';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadows,
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline, color: AppTheme.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('Example', 'उदाहरण'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.grey700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ex,
                  style: const TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: AppTheme.grey800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- listening ----
  Widget _buildListening() {
    return Column(
      children: [
        const SizedBox(height: 24),
        _micButton(active: true, onTap: _stopAndProcess),
        const SizedBox(height: 16),
        Text(
          _t('Listening… tap to finish', 'सुन रहे हैं… रोकने के लिए दबाएँ'),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.cardShadows,
            ),
            child: SingleChildScrollView(
              child: Text(
                _liveText.isEmpty ? _t('Speak now…', 'अब बोलें…') : _liveText,
                style: TextStyle(
                  fontSize: 20,
                  height: 1.4,
                  color: _liveText.isEmpty ? AppTheme.grey400 : AppTheme.grey900,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _stopAndProcess,
              icon: const Icon(Icons.stop_circle_outlined),
              label: Text(_t('Stop & Review', 'रोकें और देखें')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---- processing ----
  Widget _buildProcessing() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppTheme.primary),
          const SizedBox(height: 20),
          Text(
            _t('Understanding your order…', 'आपका ऑर्डर समझ रहे हैं…'),
            style: const TextStyle(fontSize: 15, color: AppTheme.grey700),
          ),
          if (_finalText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                '"$_finalText"',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: AppTheme.grey500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---- review ----
  Widget _buildReview() {
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 56, color: AppTheme.grey400),
            const SizedBox(height: 12),
            Text(
              _t('No items recognised', 'कोई आइटम नहीं मिला'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.grey800,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.mic),
              label: Text(_t('Try again', 'दोबारा बोलें')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '"$_finalText"',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                    color: AppTheme.grey600,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.mic, size: 16),
                label: Text(_t('Redo', 'फिर से')),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _itemCard(i),
          ),
        ),
      ],
    );
  }

  Widget _itemCard(int index) {
    final item = _items[index];
    final matched = item.isMatched;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.selected && matched ? AppTheme.info.withOpacity(0.5) : AppTheme.grey200,
        ),
        boxShadow: AppTheme.cardShadows,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // checkbox
          SizedBox(
            width: 32,
            child: Checkbox(
              value: item.selected && matched,
              onChanged: matched ? (v) => setState(() => item.selected = v ?? false) : null,
              activeColor: AppTheme.primary,
            ),
          ),
          // thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: matched && item.product!.imageUrl.isNotEmpty
                ? Image.network(
                    item.product!.imageUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _thumbFallback(),
                  )
                : _thumbFallback(),
          ),
          const SizedBox(width: 12),
          // details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  matched ? item.product!.name : item.spokenName,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.grey900,
                  ),
                ),
                const SizedBox(height: 2),
                if (matched)
                  Text(
                    '₹${item.product!.price.toStringAsFixed(0)} · ${_t('you said', 'आपने कहा')} "${item.quantity} ${item.unit}"',
                    style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
                  )
                else
                  Text(
                    _t('Not found — tap to pick', 'नहीं मिला — चुनने के लिए दबाएँ'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 6),
                _confidenceBar(item.confidence, matched),
                if (matched && item.alternatives.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _alternatives(item),
                ],
                if (!matched) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _openPicker(item),
                    icon: const Icon(Icons.search, size: 16),
                    label: Text(_t('Choose product', 'प्रोडक्ट चुनें')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.primary),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      minimumSize: const Size(0, 32),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // qty stepper
          if (matched) _qtyStepper(item),
        ],
      ),
    );
  }

  Widget _thumbFallback() => Container(
    width: 48,
    height: 48,
    color: AppTheme.grey100,
    child: const Icon(Icons.shopping_basket_outlined, color: AppTheme.grey400, size: 24),
  );

  Widget _confidenceBar(double c, bool matched) {
    if (!matched) {
      return _confChip(_t('Low match', 'कम मेल'), AppTheme.error);
    }
    if (c >= 0.75) return _confChip(_t('Good match', 'अच्छा मेल'), AppTheme.info);
    if (c >= 0.5) return _confChip(_t('Likely match', 'संभावित मेल'), AppTheme.warning);
    return _confChip(_t('Check this', 'जाँच लें'), AppTheme.warning);
  }

  Widget _confChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _alternatives(ParsedVoiceItem item) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: item.alternatives.take(3).map((p) {
        return GestureDetector(
          onTap: () => setState(() => item.product = p),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.grey100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.grey200),
            ),
            child: Text(p.name, style: const TextStyle(fontSize: 11.5, color: AppTheme.grey800)),
          ),
        );
      }).toList(),
    );
  }

  Widget _qtyStepper(ParsedVoiceItem item) {
    return Container(
      decoration: BoxDecoration(color: AppTheme.grey100, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepBtn(Icons.remove, () {
            setState(() {
              if (item.quantity > 1) item.quantity--;
            });
          }),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '${item.quantity}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.grey900,
              ),
            ),
          ),
          _stepBtn(Icons.add, () {
            setState(() {
              if (item.quantity < 99) item.quantity++;
            });
          }),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 18, color: AppTheme.primary),
      ),
    );
  }

  Widget _buildBottomBar() {
    final n = _selectedCount;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$n ${_t('items selected', 'आइटम चुने')}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
                  ),
                  Text(
                    '₹${_selectedTotal.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.grey900,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: n == 0 ? null : _addToCart,
              icon: const Icon(Icons.add_shopping_cart),
              label: Text(_t('Add to Cart', 'कार्ट में डालें')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- manual product picker ----
  void _openPicker(ParsedVoiceItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ProductPickerSheet(
        initialQuery: item.spokenName,
        onPick: (p) {
          setState(() {
            item.product = p;
            item.selected = true;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _micButton({required bool active, required VoidCallback onTap}) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (active)
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) {
                  return Container(
                    width: 100 + (_pulse.value * 40),
                    height: 100 + (_pulse.value * 40),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primary.withOpacity(0.2 * (1.0 - _pulse.value)),
                    ),
                  );
                },
              ),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: active ? AppTheme.primary : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (active ? AppTheme.primary : AppTheme.grey300).withOpacity(active ? 0.3 : 0.1,),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
                border: Border.all(color: active ? Colors.white : AppTheme.primary, width: 3),
              ),
              child: Icon(
                active ? Icons.stop : Icons.mic,
                size: 42,
                color: active ? Colors.white : AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Search-and-pick sheet for replacing an unmatched / wrong item.
class _ProductPickerSheet extends StatefulWidget {
  const _ProductPickerSheet({required this.initialQuery, required this.onPick});
  final String initialQuery;
  final void Function(ProductModel) onPick;

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  late final TextEditingController _ctrl;
  List<ProductModel> _results = [];

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialQuery);
    WidgetsBinding.instance.addPostFrameCallback((_) => _search(widget.initialQuery));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _search(String q) {
    final pp = context.read<ProductProvider>();
    setState(() {
      _results = q.trim().isEmpty ? pp.products.take(20).toList() : pp.searchProducts(q);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 12,
        left: 16,
        right: 16,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Search products…',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.grey800
                    : AppTheme.grey100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _results.isEmpty
                  ? const Center(
                      child: Text('No products found', style: TextStyle(color: AppTheme.grey500)),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (_, i) {
                        final p = _results[i];
                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: p.imageUrl.isNotEmpty
                                ? Image.network(
                                    p.imageUrl,
                                    width: 44,
                                    height: 44,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.shopping_basket_outlined,
                                      color: AppTheme.grey400,
                                    ),
                                  )
                                : const Icon(
                                    Icons.shopping_basket_outlined,
                                    color: AppTheme.grey400,
                                  ),
                          ),
                          title: Text(
                            p.name,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '₹${p.price.toStringAsFixed(0)} · ${p.unit}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onTap: () => widget.onPick(p),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
