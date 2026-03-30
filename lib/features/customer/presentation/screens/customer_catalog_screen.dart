import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/domain/repositories/profile_repository.dart';
import '../../../catalog/domain/repositories/product_repository.dart';
import '../../../catalog/presentation/screens/catalog_screen.dart' show ProductItem;
import '../../../profile/domain/models/shop_settings_model.dart';
import '../../../profile/domain/repositories/shop_settings_repository.dart';
import '../../../../core/theme/app_theme.dart';

class CustomerCatalogScreen extends StatefulWidget {
  final String? shopId; // null = usar el florista autenticado
  final String? shopName; // nombre resuelto desde el slug
  /// Callback para navegar al tab "Nosotros" desde el layout padre.
  final VoidCallback? onNavigateToNosotros;
  const CustomerCatalogScreen({
    super.key,
    this.shopId,
    this.shopName,
    this.onNavigateToNosotros,
  });

  @override
  State<CustomerCatalogScreen> createState() => _CustomerCatalogScreenState();
}

class _CustomerCatalogScreenState extends State<CustomerCatalogScreen> {
  int _selectedCategoryIndex = 0;
  bool _isLoading = true;
  late String _shopName;
  double _averageRating = 0;
  int _reviewCount = 0;
  bool _showReviews = true;
  bool _isUnavailable = false;
  String? _unavailableMessage;

  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  final _productRepo = ProductRepository();
  final _settingsRepo = ShopSettingsRepository();
  ShopSettingsModel? _settings;
  List<ProductItem> _products = [];
  
  List<String> get _categories {
    final tagSet = <String>{};
    for (final p in _products) {
      tagSet.addAll(p.tags);
    }
    return ['Todos', ...tagSet.toList()..sort()];
  }

  List<ProductItem> get _filteredProducts {
    var list = _products;

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) =>
        p.name.toLowerCase().contains(q) ||
        (p.sku?.toLowerCase().contains(q) ?? false) ||
        p.tags.any((t) => t.toLowerCase().contains(q))
      ).toList();
    }

    if (_categories.isNotEmpty && _selectedCategoryIndex < _categories.length) {
      final category = _categories[_selectedCategoryIndex];
      if (category != 'Todos') {
        list = list.where((p) => p.tags.contains(category)).toList();
      }
    }

    return list;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _shopName = widget.shopName ?? 'TusFlores';
    _loadStoreData();
  }

  Future<void> _loadStoreData() async {
    setState(() => _isLoading = true);
    final targetShopId = widget.shopId ?? Supabase.instance.client.auth.currentUser?.id;
    if (targetShopId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    // Todas las consultas en paralelo — reduce el tiempo total a max(cada una)
    await Future.wait<void>([
      _fetchProfile(targetShopId),
      _fetchReviews(targetShopId),
      _fetchSettings(targetShopId),
      _fetchProducts(targetShopId),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchProfile(String shopId) async {
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('shop_name, full_name')
          .eq('id', shopId)
          .maybeSingle();
      if (profile != null && mounted &&
          (widget.shopName == null || widget.shopName!.isEmpty)) {
        _shopName = profile['shop_name'] ?? profile['full_name'] ?? 'Mi Florería';
      }
    } catch (e) {
    }
  }

  Future<void> _fetchReviews(String shopId) async {
    try {
      final reviews = await Supabase.instance.client
          .from('shop_reviews')
          .select('rating')
          .eq('shop_id', shopId)
          .eq('is_visible', true);
      if (mounted) {
        final list = reviews as List;
        _reviewCount = list.length;
        if (_reviewCount > 0) {
          _averageRating = list
              .map((r) => (r['rating'] as num).toDouble())
              .reduce((a, b) => a + b) /
              _reviewCount;
        }
      }
    } catch (e) {
    }
  }

  Future<void> _fetchSettings(String shopId) async {
    try {
      final settings = await _settingsRepo.getSettings(shopId);
      if (settings != null && mounted) {
        _settings = settings;
        _showReviews = settings.showReviews;
        _isUnavailable = settings.isUnavailable;
        _unavailableMessage = settings.unavailableMessage;
      }
    } catch (e) {
    }
  }

  Future<void> _fetchProducts(String shopId) async {
    try {
      final prodData = await _productRepo.getPublicProducts(shopId);
      if (mounted) {
        _products = prodData.map((json) => ProductItem.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('[CustomerCatalog] Error fetching products: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
        : CustomScrollView(
            slivers: [
              _buildAppBar(context),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              _buildStoreInfoSection(context),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverToBoxAdapter(child: _buildSearchBar()),
              if (_products.isNotEmpty) _buildCategoryTabs(context),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              _buildProductsGrid(context),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
              SliverToBoxAdapter(child: _buildLegalFooter(context)),
            ],
          ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      floating: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text(
        _shopName,
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.share, color: Colors.black87),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildStatusChip() {
    if (_isUnavailable) {
      final label = (_unavailableMessage != null && _unavailableMessage!.isNotEmpty)
          ? _unavailableMessage!
          : 'No disponible';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pause_circle_outline, size: 12, color: Colors.orange[700]),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.orange[800],
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.circle, size: 8, color: Colors.green),
          const SizedBox(width: 6),
          Text(
            'Abierto',
            style: TextStyle(
              color: Colors.green[700],
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreInfoSection(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            // Fila: logo + rating badge + chip de estado
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.local_florist, size: 28, color: Colors.green),
                ),
                if (_showReviews && _reviewCount > 0) ...[
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: widget.onNavigateToNosotros,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded, color: Colors.amber[700], size: 14),
                          const SizedBox(width: 3),
                          Text(
                            _averageRating.toStringAsFixed(1),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.amber[900],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text('·', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                          const SizedBox(width: 4),
                          Text(
                            '$_reviewCount ${_reviewCount == 1 ? "reseña" : "reseñas"}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                          const SizedBox(width: 2),
                          Icon(Icons.chevron_right, size: 13, color: Colors.grey[400]),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 10),
                _buildStatusChip(),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Hermosos arreglos florales para toda ocasión. Envío a domicilio disponible.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _searchQuery = v.trim()),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Buscar producto, flor o código...',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.grey.shade100,
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTabs(BuildContext context) {
     return SliverToBoxAdapter(
       child: SizedBox(
         height: 40,
         child: ListView.builder(
           scrollDirection: Axis.horizontal,
           padding: const EdgeInsets.symmetric(horizontal: 16),
           itemCount: _categories.length,
           itemBuilder: (context, index) {
             return _buildTabItem(
               title: _categories[index],
               isSelected: _selectedCategoryIndex == index,
               onTap: () {
                 setState(() {
                   _selectedCategoryIndex = index;
                 });
               },
             );
           },
         ),
       ),
     );
  }

  Widget _buildTabItem({required String title, required bool isSelected, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black87 : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: isSelected ? null : Border.all(color: Colors.grey[300]!),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductsGrid(BuildContext context) {
    if (_products.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40.0),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.local_florist_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('No hay productos disponibles', style: TextStyle(color: Colors.grey[500])),
              ],
            ),
          ),
        ),
      );
    }

    final displayProducts = _filteredProducts;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 28.0,
          crossAxisSpacing: 16.0,
          childAspectRatio: 0.45,
        ),
        delegate: SliverChildBuilderDelegate(
          (BuildContext context, int index) {
            return _buildProductCard(context, displayProducts[index]);
          },
          childCount: displayProducts.length,
        ),
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, ProductItem product) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 15.0),
        child: GestureDetector(
        onTap: () => context.push(
              '/shop/product',
              extra: {'product': product, 'shopId': widget.shopId, 'allProducts': _products},
            ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 4,
                child: Container(
                  color: Colors.grey[100],
                  width: double.infinity,
                  child: product.imageUrls.isNotEmpty
                      ? Image.network(
                          product.imageUrls.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(Icons.image_outlined, size: 48, color: Colors.grey[400]),
                        )
                      : Icon(Icons.local_florist, size: 48, color: Colors.grey[300]),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (product.sku != null && product.sku!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            product.sku!,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                              letterSpacing: 0.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_settings?.currencySymbol ?? '\$'}${product.price.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          const _AnimatedAddButton()
                        ],
                      )
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
        ),
      );
  }

  Widget _buildLegalFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Column(
        children: [
          Divider(height: 1, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.local_florist,
                  size: 13, color: AppTheme.mutedLight),
              const SizedBox(width: 5),
              Text(
                'Potenciado por tusflores.app',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => context.push('/privacidad'),
                child: const Text(
                  'Privacidad',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.mutedLight,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('·',
                    style: TextStyle(color: Colors.grey.shade300)),
              ),
              GestureDetector(
                onTap: () => context.push('/terminos'),
                child: const Text(
                  'Términos de uso',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.mutedLight,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '© 2024–2025 tusflores.app',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}

class _AnimatedAddButton extends StatefulWidget {
  const _AnimatedAddButton();

  @override
  State<_AnimatedAddButton> createState() => _AnimatedAddButtonState();
}

class _AnimatedAddButtonState extends State<_AnimatedAddButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedRotation(
        turns: _hovered ? 0.25 : 0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _hovered ? AppTheme.primary : Colors.black87,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.add,
            color: Colors.white,
            size: 16,
          ),
        ),
      ),
    );
  }
}
