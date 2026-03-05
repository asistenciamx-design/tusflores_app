import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/domain/repositories/profile_repository.dart';
import '../../../catalog/domain/repositories/product_repository.dart';
import '../../../catalog/presentation/screens/catalog_screen.dart' show ProductItem;
import '../../../../core/theme/app_theme.dart';

class CustomerCatalogScreen extends StatefulWidget {
  final String? shopId; // null = usar el florista autenticado
  const CustomerCatalogScreen({super.key, this.shopId});

  @override
  State<CustomerCatalogScreen> createState() => _CustomerCatalogScreenState();
}

class _CustomerCatalogScreenState extends State<CustomerCatalogScreen> {
  int _selectedCategoryIndex = 0;
  bool _isLoading = true;
  String _shopName = 'TusFlores';
  
  final _profileRepo = ProfileRepository();
  final _productRepo = ProductRepository();
  List<ProductItem> _products = [];
  
  List<String> get _categories {
    final tagSet = <String>{};
    for (final p in _products) {
      tagSet.addAll(p.tags);
    }
    return ['Todos', ...tagSet.toList()..sort()];
  }

  List<ProductItem> get _filteredProducts {
    if (_categories.isEmpty || _selectedCategoryIndex >= _categories.length) return _products;
    final category = _categories[_selectedCategoryIndex];
    if (category == 'Todos') return _products;
    return _products.where((p) => p.tags.contains(category)).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadStoreData();
  }

  Future<void> _loadStoreData() async {
    setState(() => _isLoading = true);
    try {
      // Si viene shopId del param de URL, utilízalo; si no, usa el usuario autenticado
      final targetShopId = widget.shopId ?? Supabase.instance.client.auth.currentUser?.id;
      if (targetShopId == null) return;

      // Cargar perfil de la florería
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('shop_name, full_name, logo_url, biography')
          .eq('id', targetShopId)
          .maybeSingle();
      if (profile != null && mounted) {
        _shopName = profile['shop_name'] ?? profile['full_name'] ?? 'Mi Florería';
      }

      // Cargar solo productos activos (public)
      final prodData = await _productRepo.getPublicProducts(targetShopId);
      if (mounted) {
        _products = prodData.map((json) => ProductItem.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Error loading customer catalog: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
              if (_products.isNotEmpty) _buildCategoryTabs(context),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              _buildProductsGrid(context),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
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

  Widget _buildStoreInfoSection(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
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
              child: const Icon(
                Icons.local_florist,
                size: 40,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _shopName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Icon(Icons.circle, size: 8, color: Colors.green),
                   SizedBox(width: 6),
                   Text(
                    'Abierto',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
             const SizedBox(height: 16),
             Text(
              'Hermosos arreglos florales para toda ocasión. Envío a domicilio disponible.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
             ),
          ],
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
          mainAxisSpacing: 16.0,
          crossAxisSpacing: 16.0,
          childAspectRatio: 0.73,
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
      return GestureDetector(
        onTap: () => context.push('/shop/product'),
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
                flex: 3,
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
                            '\$${product.price.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 16,
                            ),
                          )
                        ],
                      )
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      );
  }
}

