import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/repositories/product_repository.dart';
import 'add_edit_product_screen.dart';

// ─── Data Model ───────────────────────────────────────────────────────────────

class ProductItem {
  String? id;
  String name;
  double price;
  List<String> tags;
  List<String> imageUrls;
  String? description;
  bool isVisible;

  ProductItem({
    this.id,
    required this.name,
    required this.price,
    this.tags = const [],
    this.imageUrls = const [],
    this.description,
    this.isVisible = true,
  });

  factory ProductItem.fromJson(Map<String, dynamic> json) {
    List<String> parseUrls = [];
    if (json['image_urls'] != null) {
      if (json['image_urls'] is List) {
        parseUrls = (json['image_urls'] as List).map((e) => e.toString()).toList();
      } else if (json['image_urls'] is String) {
        try {
          final decoded = jsonDecode(json['image_urls']);
          if (decoded is List) {
            parseUrls = decoded.map((e) => e.toString()).toList();
          } else {
            parseUrls = [json['image_urls'].toString()];
          }
        } catch (_) {
          parseUrls = [json['image_urls'].toString()];
        }
      }
    } else if (json['image_url'] != null) {
      parseUrls = [json['image_url'].toString()];
    }
    
    return ProductItem(
      id: json['id'],
      name: json['name'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      tags: List<String>.from(json['tags'] ?? []),
      imageUrls: parseUrls,
      description: json['description'],
      isVisible: json['is_active'] ?? true,
    );
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class CatalogScreen extends StatefulWidget {
  final bool showPausedOnly;
  const CatalogScreen({super.key, this.showPausedOnly = false});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _searchCtrl = TextEditingController();
  final _repo = ProductRepository();
  bool _isLoading = true;
  String _selectedCategory = 'Todos';
  String _searchQuery = '';
  List<ProductItem> _products = [];

  // Categories are derived dynamically from the tags of existing products
  List<String> get _categories {
    final tagSet = <String>{};
    for (final p in _products) {
      tagSet.addAll(p.tags);
    }
    return ['Todos', ...tagSet.toList()..sort()];
  }



  List<ProductItem> get _filteredProducts {
    return _products.where((p) {
      if (widget.showPausedOnly && p.isVisible) return false;
      // "Todos" shows everything; otherwise filter by whether the product has that tag
      final matchesCategory = _selectedCategory == 'Todos' || p.tags.contains(_selectedCategory);
      final matchesSearch = _searchQuery.isEmpty || p.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final data = await _repo.getProducts(user.id);
        setState(() {
          _products = data.map((json) => ProductItem.fromJson(json)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading products: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildCategoryChips(),
            Expanded(
              child: _isLoading 
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  : _filteredProducts.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                          itemCount: _filteredProducts.length,
                          itemBuilder: (_, i) => _buildProductCard(_filteredProducts[i]),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'addProductFAB',
        onPressed: _navigateToAddProduct,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 6,
        child: const Icon(Icons.add, size: 32),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showPausedOnly)
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 38,
                height: 38,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back,
                    color: Colors.black87, size: 20),
              ),
            ),
          Text(
            widget.showPausedOnly ? 'Productos en Pausa' : 'Mi Catálogo',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          // Search bar
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextFormField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Buscar arreglos florales...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 22),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                        onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Category Chips ───────────────────────────────────────────────────────────

  Widget _buildCategoryChips() {
    return Container(
      color: AppTheme.backgroundLight,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: _categories.map((cat) {
            final isSelected = cat == _selectedCategory;
            // Strip leading '#' for display only
            final displayLabel = cat.startsWith('#') ? cat.substring(1) : cat;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () => setState(() => _selectedCategory = cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: isSelected ? AppTheme.primary : Colors.grey.withValues(alpha: 0.2)),
                    boxShadow: isSelected ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))] : [],
                  ),
                  child: Text(displayLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.grey[600],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── Product Card ─────────────────────────────────────────────────────────────

  Widget _buildProductCard(ProductItem product) {
    final int originalIdx = _products.indexOf(product);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: product.isVisible ? 1.0 : 0.55,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Image
            GestureDetector(
              onTap: () => _navigateToEditProduct(originalIdx),
              child: Container(
                width: 80, height: 80,
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(14),
                ),
                child: product.imageUrls.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(product.imageUrls.first, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.local_florist, color: AppTheme.primary, size: 36)),
                      )
                    : Icon(Icons.local_florist, color: product.isVisible ? AppTheme.primary : Colors.grey, size: 36),
              ),
            ),

            // Info
            Expanded(
              child: GestureDetector(
                onTap: () => _navigateToEditProduct(originalIdx),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15,
                          color: product.isVisible ? AppTheme.textLight : Colors.grey,
                        ),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text('\$${product.price.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 17,
                          color: product.isVisible ? AppTheme.primary : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                children: [
                  // Edit + Delete
                  Row(children: [
                    _buildCircleIcon(Icons.edit_outlined, AppTheme.primary, AppTheme.primary.withValues(alpha: 0.08),
                        onTap: () => _navigateToEditProduct(originalIdx)),
                    const SizedBox(width: 6),
                    _buildCircleIcon(Icons.delete_outline, Colors.red, Colors.red.shade50,
                        onTap: () => _confirmDelete(originalIdx)),
                  ]),
                  const SizedBox(height: 8),
                  // Visibility toggle
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(product.isVisible ? 'Visible' : 'Oculto',
                        style: TextStyle(fontSize: 10, color: Colors.grey[400], fontWeight: FontWeight.w500)),
                      const SizedBox(width: 4),
                      Transform.scale(
                        scale: 0.75,
                        alignment: Alignment.centerRight,
                        child: Switch(
                          value: product.isVisible,
                          onChanged: (val) async {
                            final id = _products[originalIdx].id;
                            if (id == null) return;
                            // Optimistic UI update
                            setState(() => _products[originalIdx].isVisible = val);
                            await _repo.updateProduct(id, {'is_active': val});
                          },
                          activeThumbColor: Colors.white,
                          activeTrackColor: AppTheme.primary,
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: Colors.grey[300],
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

  Widget _buildCircleIcon(IconData icon, Color iconColor, Color bgColor, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 17),
      ),
    );
  }

  // ─── Empty State ──────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.local_florist_outlined, size: 72, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text(_searchQuery.isEmpty ? 'No hay productos en esta categoría' : 'Sin resultados para "$_searchQuery"',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[400], fontSize: 15, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _navigateToAddProduct,
          icon: const Icon(Icons.add_circle, color: AppTheme.primary),
          label: const Text('Agregar producto', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  // ─── Navigation ───────────────────────────────────────────────────────────────

  void _navigateToAddProduct() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddEditProductScreen()),
    );
    if (result == true && mounted) {
      _loadProducts();
    }
  }

  void _navigateToEditProduct(int idx) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddEditProductScreen(product: _products[idx], productIndex: idx)),
    );
    if (result == true && mounted) {
      _loadProducts();
    }
  }

  void _confirmDelete(int idx) {
    final name = _products[idx].name;
    final id = _products[idx].id;
    if (id == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar producto', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('¿Eliminar "$name" del catálogo? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: AppTheme.mutedLight))),
          ElevatedButton(
            onPressed: () async { 
              Navigator.pop(ctx); 
              setState(() => _isLoading = true);
              await _repo.deleteProduct(id);
              _loadProducts();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
