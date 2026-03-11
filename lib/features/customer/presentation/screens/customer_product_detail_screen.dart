import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../catalog/presentation/screens/catalog_screen.dart' show ProductItem;

class CustomerProductDetailScreen extends StatefulWidget {
  final ProductItem? product;
  final String? shopId;
  const CustomerProductDetailScreen({super.key, this.product, this.shopId});

  @override
  State<CustomerProductDetailScreen> createState() => _CustomerProductDetailScreenState();
}

class _CustomerProductDetailScreenState extends State<CustomerProductDetailScreen> {
  int _selectedImageIndex = 0;

  List<String> get _images {
    if (widget.product == null || widget.product!.imageUrls.isEmpty) {
      return [];
    }
    return widget.product!.imageUrls;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.product == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Producto no encontrado')),
        body: const Center(child: Text('La información del producto no está disponible.')),
      );
    }

    final product = widget.product!;
    final currentImage = _images.isNotEmpty ? _images[_selectedImageIndex] : '';

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
      // bottomNavigationBar + SafeArea miscalculates insets on Safari iOS on first
      // render, causing the button to be hidden behind browser chrome.
      body: Stack(
        children: [
          // Scrollable product content — with generous bottom padding for the button
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                 // Main Image
                 ClipRRect(
                   borderRadius: BorderRadius.circular(16),
                   child: currentImage.isNotEmpty
                    ? Image.network(
                       currentImage,
                       height: 350,
                       width: double.infinity,
                       fit: BoxFit.cover,
                       errorBuilder: (ctx, err, stack) => _buildPlaceholderImage(),
                     )
                    : _buildPlaceholderImage(),
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
      height: 350,
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
           borderRadius: BorderRadius.circular(10), // slightly smaller to fit inside border
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
           color: Color(0xFF00C853), // slightly darker green for text
           fontSize: 13,
           fontWeight: FontWeight.w500,
         ),
       ),
    );
  }
}
