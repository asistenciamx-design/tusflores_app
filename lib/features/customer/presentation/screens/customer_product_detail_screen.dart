import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../catalog/presentation/screens/catalog_screen.dart' show ProductItem;

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
                  '\$${product.price.toStringAsFixed(2)} MXN',
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

                // Description
                Text(
                  product.description?.isNotEmpty == true ? product.description! : 'Sin descripción detallada.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // ── Productos similares ────────────────────────────────
                _buildRelatedProducts(),
                const SizedBox(height: 16),
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
                  context.push('/shop/checkout', extra: {'product': product, 'shopId': widget.shopId});
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
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    height: 100,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildSmallPlaceholder(),
                  )
                : _buildSmallPlaceholder(),
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
            '\$${p.price.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00C853)),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallPlaceholder() {
    return Container(
      height: 100,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.local_florist, size: 36, color: Colors.grey),
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
