import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../catalog/domain/models/gift_model.dart';
import '../../../catalog/domain/repositories/gift_repository.dart';
import '../../../catalog/presentation/screens/catalog_screen.dart' show ProductItem;
import '../../../profile/domain/models/shop_settings_model.dart';
import '../../../profile/domain/repositories/shop_settings_repository.dart';

class CustomerProductDetailScreen extends StatefulWidget {
  final ProductItem? product;
  final String? shopId;
  final List<ProductItem>? allProducts;
  const CustomerProductDetailScreen({super.key, this.product, this.shopId, this.allProducts});

  @override
  State<CustomerProductDetailScreen> createState() => _CustomerProductDetailScreenState();
}

class _CustomerProductDetailScreenState extends State<CustomerProductDetailScreen> {
  int _selectedImageIndex = 0;
  late int _currentProductIndex;

  // Settings
  ShopSettingsModel? _shopSettings;

  // Gifts
  final _giftRepo = GiftRepository();
  List<GiftItem> _gifts = [];
  final Set<String> _selectedGiftIds = {};

  List<ProductItem> get _all => widget.allProducts ?? [];

  ProductItem get _currentProduct =>
      _currentProductIndex >= 0 && _currentProductIndex < _all.length
          ? _all[_currentProductIndex]
          : widget.product!;

  List<String> get _images {
    final p = widget.product == null ? null : _currentProduct;
    if (p == null || p.imageUrls.isEmpty) return [];
    return p.imageUrls;
  }

  @override
  void initState() {
    super.initState();
    final idx = _all.indexWhere((p) => p.id == widget.product?.id);
    _currentProductIndex = idx >= 0 ? idx : 0;
    if (widget.shopId != null) _loadGifts();
    if (widget.shopId != null) _loadShopSettings();
  }

  Future<void> _loadShopSettings() async {
    try {
      final s = await ShopSettingsRepository().getSettings(widget.shopId!);
      if (mounted) setState(() => _shopSettings = s);
    } catch (_) {}
  }

  Future<void> _loadGifts() async {
    try {
      final data = await _giftRepo.getPublicGifts(widget.shopId!);
      if (mounted) {
        setState(() {
          _gifts = data.map((j) => GiftItem.fromJson(j)).take(20).toList();
        });
      }
    } catch (e) {
    }
  }

  void _toggleGift(String giftId) {
    setState(() {
      if (_selectedGiftIds.contains(giftId)) {
        _selectedGiftIds.remove(giftId);
      } else {
        _selectedGiftIds.add(giftId);
      }
    });
  }

  void _goToProduct(int index) {
    if (index < 0 || index >= _all.length) return;
    setState(() {
      _currentProductIndex = index;
      _selectedImageIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.product == null && _all.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Producto no encontrado')),
        body: const Center(child: Text('La información del producto no está disponible.')),
      );
    }

    final product = _currentProduct;
    final currentImage = _images.isNotEmpty ? _images[_selectedImageIndex] : '';
    final hasPrev = _currentProductIndex > 0;
    final hasNext = _currentProductIndex < _all.length - 1;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Detalles del Producto',
          style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
           icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
           onPressed: () => context.pop(),
        ),
        actions: const [],
      ),
      // ── Use Stack so the CTA button is always visible on Flutter web mobile.
      body: Stack(
        children: [
          // Scrollable product content — with generous bottom padding for the button
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Main Image with prev/next arrows overlaid ──
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: currentImage.isNotEmpty
                       ? Image.network(
                          currentImage,
                          height: 450,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => _buildPlaceholderImage(),
                        )
                       : _buildPlaceholderImage(),
                    ),
                    // Previous arrow
                    if (hasPrev)
                      Positioned(
                        left: 10,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: _NavArrowButton(
                            icon: Icons.chevron_left_rounded,
                            onTap: () => _goToProduct(_currentProductIndex - 1),
                          ),
                        ),
                      ),
                    // Next arrow
                    if (hasNext)
                      Positioned(
                        right: 10,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: _NavArrowButton(
                            icon: Icons.chevron_right_rounded,
                            onTap: () => _goToProduct(_currentProductIndex + 1),
                          ),
                        ),
                      ),
                    // Position indicator (e.g. 3 / 12)
                    if (_all.length > 1)
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_currentProductIndex + 1} / ${_all.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Gallery thumbnails
                if (_images.length > 1)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_images.length, (index) {
                      return _buildGalleryThumbnail(index);
                    }),
                  ),
                const SizedBox(height: 24),

                // SKU
                if (product.sku != null && product.sku!.isNotEmpty) ...[
                  Text(
                    product.sku!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                ],

                // Title
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Price
                Text(
                  '${_shopSettings?.currencySymbol ?? '\$'}${product.price.toStringAsFixed(2)} ${_shopSettings?.currencyCode ?? 'MXN'}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00C853),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Tags
                if (product.tags.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: product.tags.map((t) => _buildTagChip(t.startsWith('#') ? t : '#$t')).toList(),
                  ),
                if (product.tags.isNotEmpty)
                  const SizedBox(height: 24),

                // Descripción Corta
                if (product.description?.isNotEmpty == true) ...[
                  Text(
                    product.description!,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                ],

                // Composición del arreglo (recipe)
                if (product.recipe.isNotEmpty) ...[
                  _buildRecipeWidget(product.recipe),
                  const SizedBox(height: 20),
                ],

                if (product.description?.isNotEmpty != true && product.recipe.isEmpty)
                  const SizedBox(height: 12),

                const SizedBox(height: 12),

                // ── Productos similares ────────────────────────────────
                _buildRelatedProducts(),
                const SizedBox(height: 16),

                // ── Regalos ─────────────────────────────────────────────
                if (_gifts.isNotEmpty) ...[
                  _buildGiftsSection(),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),

          // ── Sticky CTA button (always visible, not affected by SafeArea issues) ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              child: ElevatedButton.icon(
                onPressed: () {
                  final selectedGifts = _selectedGiftIds.map((id) {
                    final g = _gifts.firstWhere((g) => g.id == id);
                    return {
                      'id': g.id,
                      'name': g.name,
                      'sku': g.sku ?? '',
                      'price': g.price,
                      'quantity': 1,
                      'image': g.imageUrl ?? '',
                    };
                  }).toList();
                  context.push('/shop/checkout', extra: {
                    'product': product,
                    'shopId': widget.shopId,
                    'giftProducts': selectedGifts,
                  });
                },
                icon: const Icon(Icons.shopping_cart, color: Colors.white, size: 22),
                label: const Text(
                  'Realiza tu Compra',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      height: 450,
      width: double.infinity,
      color: Colors.grey[200],
      child: const Icon(Icons.local_florist, size: 80, color: Colors.grey),
    );
  }

  Widget _buildGalleryThumbnail(int index) {
     bool isSelected = _selectedImageIndex == index;
     return GestureDetector(
       onTap: () {
         setState(() {
           _selectedImageIndex = index;
         });
       },
       child: Container(
         margin: const EdgeInsets.symmetric(horizontal: 4),
         height: 80,
         width: 80,
         decoration: BoxDecoration(
           borderRadius: BorderRadius.circular(12),
           border: Border.all(
             color: isSelected ? const Color(0xFF00E676) : Colors.transparent,
             width: 2,
           ),
         ),
         child: ClipRRect(
           borderRadius: BorderRadius.circular(10),
           child: Image.network(
             _images[index],
             fit: BoxFit.cover,
             errorBuilder: (ctx, err, stack) => Container(
                color: Colors.grey[200],
                child: const Icon(Icons.local_florist, color: Colors.grey),
             ),
           ),
         ),
       ),
     );
  }

  Widget _buildRecipeWidget(List<Map<String, dynamic>> recipe) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FFF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_florist, size: 16, color: Color(0xFF00C853)),
              const SizedBox(width: 6),
              const Text(
                'Composición del arreglo',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00A040),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...recipe.map((item) {
            final qty = item['qty'];
            final name = (item['name'] as String? ?? '').trim();
            final color = (item['color'] as String? ?? '').trim();
            final quality = (item['quality'] as String? ?? '').trim();
            final type = (item['type'] as String? ?? 'flor').trim();
            final typeEmoji = switch (type) {
              'follaje' => '🌿',
              'florero' => '🏺',
              'extra'   => '✨',
              _         => '🌸',
            };
            if (name.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        qty != null ? '$qty' : '—',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00A040),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$typeEmoji ${[name, if (color.isNotEmpty) color].join(' · ')}',
                      style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (quality.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        quality,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF00A040), fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  List<ProductItem> get _relatedProducts {
    final others = _all.where((p) => p.id != _currentProduct.id).toList();
    others.shuffle(Random());
    return others.take(3).toList();
  }

  Widget _buildRelatedProducts() {
    final related = _relatedProducts;
    if (related.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, color: Color(0xFFEEEEEE)),
        const SizedBox(height: 20),
        const Text(
          'También te puede gustar',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 14),
        Row(
          children: related.map((p) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: p == related.last ? 0 : 10),
              child: _buildRelatedCard(p),
            ),
          )).toList(),
        ),
      ],
    );
  }

  // ── Gifts section ─────────────────────────────────────────────────────────

  Widget _buildGiftsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, color: Color(0xFFEEEEEE)),
        const SizedBox(height: 20),
        Row(
          children: [
            const Text('🎁', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            const Text(
              'Agregar un regalo',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Selecciona uno o más para complementar tu arreglo',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 14),
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: _gifts.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.70,
          ),
          itemBuilder: (_, i) => _buildGiftCard(_gifts[i]),
        ),
      ],
    );
  }

  Widget _buildGiftCard(GiftItem gift) {
    final isSelected = _selectedGiftIds.contains(gift.id);
    return GestureDetector(
      onTap: () => _toggleGift(gift.id!),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00E676)
                : Colors.grey.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF00E676).withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image — LayoutBuilder garantiza que sea cuadrada (1:1) sin importar el tamaño de celda
                LayoutBuilder(
                  builder: (ctx, constraints) {
                    final side = constraints.maxWidth;
                    return ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                      child: SizedBox(
                        width: side,
                        height: side,
                        child: gift.imageUrl != null && gift.imageUrl!.isNotEmpty
                            ? Image.network(
                                gift.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildGiftPlaceholderSized(side),
                              )
                            : _buildGiftPlaceholderSized(side),
                      ),
                    );
                  },
                ),
                // Info
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (gift.sku != null && gift.sku!.isNotEmpty)
                        Text(
                          gift.sku!,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade400,
                            letterSpacing: 0.5,
                          ),
                        ),
                      Text(
                        gift.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_shopSettings?.currencySymbol ?? '\$'}${gift.price.toStringAsFixed(0)} ${_shopSettings?.currencyCode ?? 'MXN'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF00C853),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Check badge when selected
            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00E676),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 16, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGiftPlaceholder() {
    return Container(
      width: double.infinity,
      color: Colors.pink.withValues(alpha: 0.06),
      child: const Icon(Icons.card_giftcard, size: 36, color: Colors.pinkAccent),
    );
  }

  Widget _buildGiftPlaceholderSized(double side) {
    return Container(
      width: side,
      height: side,
      color: Colors.pink.withValues(alpha: 0.06),
      child: const Icon(Icons.card_giftcard, size: 36, color: Colors.pinkAccent),
    );
  }

  Widget _buildRelatedCard(ProductItem p) {
    final imageUrl = p.imageUrls.isNotEmpty ? p.imageUrls.first : '';
    final targetIndex = _all.indexWhere((a) => a.id == p.id);
    return GestureDetector(
      onTap: () {
        if (targetIndex >= 0) {
          _goToProduct(targetIndex);
        } else {
          context.push('/shop/product', extra: {
            'product': p,
            'shopId': widget.shopId,
            'allProducts': widget.allProducts,
          });
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 4 / 5,
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildSmallPlaceholder(),
                    )
                  : _buildSmallPlaceholder(),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            p.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          const SizedBox(height: 2),
          Text(
            '${_shopSettings?.currencySymbol ?? '\$'}${p.price.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00C853)),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallPlaceholder() {
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.local_florist, size: 36, color: Colors.grey),
      ),
    );
  }

  Widget _buildTagChip(String label) {
    return Container(
       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
       decoration: BoxDecoration(
         color: const Color(0xFF00E676).withValues(alpha: 0.1),
         borderRadius: BorderRadius.circular(20),
         border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.3)),
       ),
       child: Text(
         label,
         style: const TextStyle(
           color: Color(0xFF00C853),
           fontSize: 13,
           fontWeight: FontWeight.w500,
         ),
       ),
    );
  }
}

// ── Navigation arrow button ──────────────────────────────────────────────────

class _NavArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavArrowButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 26, color: Colors.black87),
      ),
    );
  }
}
