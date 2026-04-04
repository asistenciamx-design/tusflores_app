import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/image_compressor.dart';
import '../../../../core/utils/responsive.dart';
import '../../domain/models/warehouse_models.dart';
import '../../domain/repositories/warehouse_repository.dart';

// ── Sanitizar mensajes de error para no exponer detalles internos ────────────
String _sanitizeError(Object e) {
  final msg = e.toString();
  // Mostrar errores de validación de negocio tal cual
  if (msg.startsWith('Exception: ')) return msg.replaceFirst('Exception: ', '');
  // Ocultar detalles técnicos
  return 'Ocurrió un error. Intenta de nuevo.';
}

// ═══════════════════════════════════════════════════════════════════════════════
// Pantalla principal — Bodega de Insumos
// ═══════════════════════════════════════════════════════════════════════════════

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  final _repo = WarehouseRepository();
  List<WarehouseProduct> _products = [];
  List<WarehouseCategory> _categories = [];
  String? _selectedCategoryId;
  bool _loading = true;
  String _search = '';

  // Stats
  int _totalProducts = 0;
  int _activeProducts = 0;
  int _criticalProducts = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _repo.getCategories(),
        _repo.getProducts(categoryId: _selectedCategoryId),
        _repo.getStats(),
      ]);
      _categories = results[0] as List<WarehouseCategory>;
      _products = results[1] as List<WarehouseProduct>;
      final stats = results[2] as Map<String, int>;
      _totalProducts = stats['total'] ?? 0;
      _activeProducts = stats['active'] ?? 0;
      _criticalProducts = stats['critical'] ?? 0;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_sanitizeError(e)), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadProducts() async {
    try {
      final products = await _repo.getProducts(categoryId: _selectedCategoryId);
      final stats = await _repo.getStats();
      if (mounted) {
        setState(() {
          _products = products;
          _totalProducts = stats['total'] ?? 0;
          _activeProducts = stats['active'] ?? 0;
          _criticalProducts = stats['critical'] ?? 0;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_sanitizeError(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<WarehouseProduct> get _filtered {
    if (_search.isEmpty) return _products;
    final q = _search.toLowerCase();
    return _products
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            (p.sku?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  void _openProductForm([WarehouseProduct? product]) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _ProductFormScreen(
          product: product,
          categories: _categories,
        ),
      ),
    );
    if (result == true) _loadProducts();
  }

  void _openCategoryManager() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategoryManagerSheet(
        categories: _categories,
        onChanged: () => _loadAll(),
      ),
    );
  }

  void _updateStock(WarehouseProduct product, int delta) async {
    final newStock = product.stock + delta;
    if (newStock < 0) return;
    try {
      await _repo.updateStock(product.id, newStock);
      setState(() => product.stock = newStock);
      // Refresh stats
      final stats = await _repo.getStats();
      if (mounted) {
        setState(() {
          _totalProducts = stats['total'] ?? 0;
          _activeProducts = stats['active'] ?? 0;
          _criticalProducts = stats['critical'] ?? 0;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_sanitizeError(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Bodegas de insumos',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textLight,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF3F4F6)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.category_rounded, size: 22),
            tooltip: 'Categorías',
            onPressed: _openCategoryManager,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openProductForm(),
        backgroundColor: const Color(0xFF7C3AED),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nuevo Producto',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: ResponsiveContent(
        maxWidth: 900,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadAll,
                child: CustomScrollView(
                slivers: [
                  // ── Stats header ──────────────────────────────────────
                  SliverToBoxAdapter(child: _buildStatsHeader()),
                  // ── Category chips ────────────────────────────────────
                  if (_categories.isNotEmpty)
                    SliverToBoxAdapter(child: _buildCategoryChips()),
                  // ── Search bar ────────────────────────────────────────
                  SliverToBoxAdapter(child: _buildSearchBar()),
                  // ── Product list ──────────────────────────────────────
                  if (filtered.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text('Sin productos',
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('Agrega tu primer producto a la bodega',
                                style: TextStyle(
                                    color: Colors.grey[400], fontSize: 13)),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _ProductCard(
                            product: filtered[index],
                            onTap: () => _openProductForm(filtered[index]),
                            onIncrement: () =>
                                _updateStock(filtered[index], 1),
                            onDecrement: () =>
                                _updateStock(filtered[index], -1),
                          ),
                          childCount: filtered.length,
                        ),
                      ),
                    ),
                ],
                ),
              ),
          ),
    );
  }

  Widget _buildStatsHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFF9B59B6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('RESUMEN DE EXISTENCIAS',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1)),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('$_totalProducts',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                const Text('Artículos Totales',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _StatBadge(
                  label: 'ACTIVOS',
                  value: '$_activeProducts',
                  dotColor: Colors.green,
                ),
                const SizedBox(width: 12),
                _StatBadge(
                  label: 'CRÍTICOS',
                  value: '$_criticalProducts',
                  dotColor: Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            final selected = _selectedCategoryId == null;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: const Text('Todos'),
                selected: selected,
                selectedColor: const Color(0xFF7C3AED),
                labelStyle: TextStyle(
                    color: selected ? Colors.white : AppTheme.textLight,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
                backgroundColor: Colors.white,
                side: BorderSide(
                    color: selected
                        ? Colors.transparent
                        : const Color(0xFFE5E7EB)),
                onSelected: (_) {
                  setState(() => _selectedCategoryId = null);
                  _loadProducts();
                },
              ),
            );
          }
          final cat = _categories[index - 1];
          final selected = _selectedCategoryId == cat.id;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(cat.name),
              selected: selected,
              selectedColor: const Color(0xFF7C3AED),
              labelStyle: TextStyle(
                  color: selected ? Colors.white : AppTheme.textLight,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
              backgroundColor: Colors.white,
              side: BorderSide(
                  color:
                      selected ? Colors.transparent : const Color(0xFFE5E7EB)),
              onSelected: (_) {
                setState(() => _selectedCategoryId = cat.id);
                _loadProducts();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        onChanged: (v) => setState(() => _search = v),
        decoration: InputDecoration(
          hintText: 'Buscar producto...',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 20),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Stat badge (dentro del header morado)
// ═══════════════════════════════════════════════════════════════════════════════

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color dotColor;

  const _StatBadge({
    required this.label,
    required this.value,
    required this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5)),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Product card
// ═══════════════════════════════════════════════════════════════════════════════

class _ProductCard extends StatelessWidget {
  final WarehouseProduct product;
  final VoidCallback onTap;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final isLow = product.isLowStock;
    final currFmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isLow
            ? Border.all(color: Colors.red.withValues(alpha: 0.3), width: 1.5)
            : Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Stack(
            children: [
              Row(
                children: [
                  // ── Thumbnail ──
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: product.imageUrl != null &&
                            product.imageUrl!.isNotEmpty
                        ? Image.network(
                            product.imageUrl!,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _placeholderThumb(),
                          )
                        : _placeholderThumb(),
                  ),
                  const SizedBox(width: 14),
                  // ── Info ──
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.name,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textLight),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(
                            '${currFmt.format(product.unitPrice)} / ${product.unit}',
                            style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF7C3AED),
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        // ── Stock controls ──
                        Row(
                          children: [
                            _StockButton(
                              icon: Icons.remove,
                              onTap: onDecrement,
                              color: isLow ? Colors.red : const Color(0xFF7C3AED),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                '${product.stock}'.padLeft(2, '0'),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isLow
                                      ? Colors.red
                                      : AppTheme.textLight,
                                ),
                              ),
                            ),
                            _StockButton(
                              icon: Icons.add,
                              onTap: onIncrement,
                              color: const Color(0xFF7C3AED),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // ── SKU badge ──
                  if (product.sku != null && product.sku!.isNotEmpty)
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text('SKU',
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.grey[500],
                                      fontWeight: FontWeight.w600)),
                              Text(product.sku!,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textLight)),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              // ── Low stock badge ──
              if (isLow)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_rounded,
                            color: Colors.white, size: 12),
                        SizedBox(width: 3),
                        Text('STOCK BAJO',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholderThumb() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.inventory_2_outlined, color: Colors.grey[400], size: 28),
    );
  }
}

class _StockButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _StockButton({
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Category manager bottom sheet
// ═══════════════════════════════════════════════════════════════════════════════

class _CategoryManagerSheet extends StatefulWidget {
  final List<WarehouseCategory> categories;
  final VoidCallback onChanged;

  const _CategoryManagerSheet({
    required this.categories,
    required this.onChanged,
  });

  @override
  State<_CategoryManagerSheet> createState() => _CategoryManagerSheetState();
}

class _CategoryManagerSheetState extends State<_CategoryManagerSheet> {
  final _repo = WarehouseRepository();
  final _nameCtrl = TextEditingController();
  late List<WarehouseCategory> _cats;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _cats = List.from(widget.categories);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _addCategory() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _adding = true);
    try {
      final cat = await _repo.createCategory(name);
      setState(() {
        _cats.add(cat);
        _nameCtrl.clear();
      });
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_sanitizeError(e)), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _adding = false);
  }

  void _deleteCategory(WarehouseCategory cat) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text(
            '¿Eliminar "${cat.name}"? Los productos en esta categoría quedarán sin categoría.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _repo.deleteCategory(cat.id);
      setState(() => _cats.removeWhere((c) => c.id == cat.id));
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_sanitizeError(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Categorías',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          // Add new
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'Nueva categoría...',
                      hintStyle:
                          TextStyle(color: Colors.grey[400], fontSize: 14),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFE5E7EB))),
                    ),
                    onSubmitted: (_) => _addCategory(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _adding ? null : _addCategory,
                  icon: _adding
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.add_circle,
                          color: Color(0xFF7C3AED), size: 32),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // List
          Flexible(
            child: _cats.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('Sin categorías aún',
                        style: TextStyle(color: Colors.grey[400])),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _cats.length,
                    itemBuilder: (_, i) {
                      final cat = _cats[i];
                      return ListTile(
                        leading: const Icon(Icons.folder_rounded,
                            color: Color(0xFF7C3AED)),
                        title: Text(cat.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w500)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red, size: 20),
                          onPressed: () => _deleteCategory(cat),
                        ),
                      );
                    },
                  ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Product form / detail screen
// ═══════════════════════════════════════════════════════════════════════════════

class _ProductFormScreen extends StatefulWidget {
  final WarehouseProduct? product;
  final List<WarehouseCategory> categories;

  const _ProductFormScreen({this.product, required this.categories});

  @override
  State<_ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<_ProductFormScreen> {
  final _repo = WarehouseRepository();
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _minStockCtrl = TextEditingController();
  final _supplierCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _selectedCategoryId;
  String? _imageUrl;
  Uint8List? _pendingImageBytes;
  String? _pendingImageExt;
  bool _saving = false;
  bool _deleting = false;
  bool _lowStockAlert = true;
  String _presentation = 'Pieza';
  List<WarehousePurchase> _purchases = [];

  // Para agregar compra
  final _purchaseQtyCtrl = TextEditingController();
  final _purchasePriceCtrl = TextEditingController();
  final _purchaseNotesCtrl = TextEditingController();

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final p = widget.product!;
      _nameCtrl.text = p.name;
      _skuCtrl.text = p.sku ?? '';
      _unitCtrl.text = p.unit;
      _priceCtrl.text = p.unitPrice > 0 ? p.unitPrice.toString() : '';
      _stockCtrl.text = p.stock.toString();
      _minStockCtrl.text = p.minStock > 0 ? p.minStock.toString() : '';
      _supplierCtrl.text = p.supplierName ?? '';
      _notesCtrl.text = p.notes ?? '';
      _selectedCategoryId = p.categoryId;
      _imageUrl = p.imageUrl;
      _purchases = List.from(p.purchases);
      _lowStockAlert = p.lowStockAlert;
      // Map saved unit to presentation pill
      _presentation = _unitToPresentation(p.unit);
    } else {
      _unitCtrl.text = 'Pieza';
      _stockCtrl.text = '0';
      _minStockCtrl.text = '10';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _unitCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    _minStockCtrl.dispose();
    _supplierCtrl.dispose();
    _notesCtrl.dispose();
    _purchaseQtyCtrl.dispose();
    _purchasePriceCtrl.dispose();
    _purchaseNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final compressed = await ImageCompressor.compress(
      XFile(file.path, name: file.name),
      maxWidth: 800,
      maxHeight: 800,
      quality: 75,
    );
    setState(() {
      _pendingImageBytes = compressed.bytes;
      _pendingImageExt = compressed.ext;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      String? imgUrl = _imageUrl;
      if (_pendingImageBytes != null) {
        imgUrl =
            await _repo.uploadImage(_pendingImageBytes!, _pendingImageExt!);
      }

      if (_isEditing) {
        final p = widget.product!;
        p.name = _nameCtrl.text.trim();
        p.sku = _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim();
        p.unit = _presentation;
        p.unitPrice = double.tryParse(_priceCtrl.text) ?? 0;
        p.stock = int.tryParse(_stockCtrl.text) ?? 0;
        p.minStock = int.tryParse(_minStockCtrl.text) ?? 0;
        p.imageUrl = imgUrl;
        p.supplierName = _supplierCtrl.text.trim().isEmpty
            ? null
            : _supplierCtrl.text.trim();
        p.notes =
            _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();
        p.lowStockAlert = _lowStockAlert;
        await _repo.updateProduct(p);
      } else {
        final product = WarehouseProduct(
          id: '',
          floreriaId: '',
          categoryId: _selectedCategoryId,
          name: _nameCtrl.text.trim(),
          sku: _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim(),
          unit: _presentation,
          unitPrice: double.tryParse(_priceCtrl.text) ?? 0,
          stock: int.tryParse(_stockCtrl.text) ?? 0,
          minStock: int.tryParse(_minStockCtrl.text) ?? 0,
          imageUrl: imgUrl,
          supplierName: _supplierCtrl.text.trim().isEmpty
              ? null
              : _supplierCtrl.text.trim(),
          notes:
              _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          lowStockAlert: _lowStockAlert,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _repo.createProduct(product);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_sanitizeError(e)), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar producto'),
        content:
            const Text('¿Estás seguro? Se eliminará el producto y su historial.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _deleting = true);
    try {
      await _repo.deleteProduct(widget.product!.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_sanitizeError(e)), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _deleting = false);
  }

  void _addPurchaseDialog() {
    _purchaseQtyCtrl.clear();
    _purchasePriceCtrl.clear();
    _purchaseNotesCtrl.clear();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Registrar compra'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _purchaseQtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Cantidad'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _purchasePriceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'Precio unitario (\$)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _purchaseNotesCtrl,
              decoration:
                  const InputDecoration(labelText: 'Notas (opcional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              final qty = int.tryParse(_purchaseQtyCtrl.text);
              if (qty == null || qty <= 0) return;
              Navigator.pop(context);
              try {
                await _repo.addPurchase(
                  productId: widget.product!.id,
                  quantity: qty,
                  unitPrice: double.tryParse(_purchasePriceCtrl.text),
                  supplierName: _supplierCtrl.text.trim().isEmpty
                      ? null
                      : _supplierCtrl.text.trim(),
                  notes: _purchaseNotesCtrl.text.trim().isEmpty
                      ? null
                      : _purchaseNotesCtrl.text.trim(),
                );
                // Reload
                final updated = await _repo.getProduct(widget.product!.id);
                setState(() {
                  _stockCtrl.text = updated.stock.toString();
                  _purchases = updated.purchases;
                });
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(_sanitizeError(e)),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  static const _presentations = ['Pieza', 'Paquete', 'Caja', 'Rollo', 'Bloque'];

  String _unitToPresentation(String unit) {
    final u = unit.trim();
    if (_presentations.contains(u)) return u;
    return 'Pieza';
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy', 'es');
    const purple = Color(0xFF500088);
    const bgSection = Color(0xFFF4F3F6);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9FC),
      // ── AppBar ──────────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF9FC),
        foregroundColor: AppTheme.textLight,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Editar Producto' : 'Nuevo Producto',
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: purple,
              fontSize: 20),
        ),
        actions: [
          if (_isEditing)
            IconButton(
              icon: _deleting
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _deleting ? null : _delete,
            ),
        ],
      ),
      // ── Bottom save bar ──────────────────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: purple,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_rounded, size: 20),
              label: Text(
                _isEditing ? 'GUARDAR CAMBIOS' : 'CREAR PRODUCTO',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.8),
              ),
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            // ── Image section ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 180,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8E8EB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0xFFCFC2D4).withValues(alpha: 0.4),
                        width: 1.5),
                    image: _pendingImageBytes != null
                        ? DecorationImage(
                            image: MemoryImage(_pendingImageBytes!),
                            fit: BoxFit.cover)
                        : (_imageUrl != null && _imageUrl!.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(_imageUrl!),
                                fit: BoxFit.cover,
                                opacity: 0.85)
                            : null),
                  ),
                  child: (_pendingImageBytes == null &&
                          (_imageUrl == null || _imageUrl!.isEmpty))
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined,
                                color: Colors.grey[500], size: 40),
                            const SizedBox(height: 8),
                            Text('Subir Imagen',
                                style: TextStyle(
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14)),
                            const SizedBox(height: 4),
                            Text('Formatos sugeridos: JPG, PNG (Max 5MB)',
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 11)),
                          ],
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Información General ────────────────────────────────────────
            _buildSection(
              color: bgSection,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(
                      Icons.local_florist_outlined, 'Información General', purple),
                  const SizedBox(height: 20),
                  // Nombre
                  _buildLabel('NOMBRE DEL PRODUCTO'),
                  const SizedBox(height: 6),
                  _buildField(
                    controller: _nameCtrl,
                    hint: 'florero de vidrio',
                    maxLength: 500,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Requerido';
                      if (v.trim().length > 500) return 'Máximo 500 caracteres';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // SKU
                  _buildLabel('SKU / CÓDIGO'),
                  const SizedBox(height: 6),
                  _buildField(
                    controller: _skuCtrl,
                    hint: 'TLP-2024-RED',
                    maxLength: 50,
                  ),
                  const SizedBox(height: 16),
                  // Categoría
                  _buildLabel('CATEGORÍA'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategoryId,
                    decoration: InputDecoration(
                      hintText: 'Seleccionar categoría',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFFCFC2D4), width: 0.4)),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Sin categoría')),
                      ...widget.categories.map((c) =>
                          DropdownMenuItem(value: c.id, child: Text(c.name))),
                    ],
                    onChanged: (v) => setState(() => _selectedCategoryId = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Aviso de stock bajo ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: bgSection,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4C2FF).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE4C2FF).withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.notifications_active_outlined,
                            color: purple, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Aviso de Stock Bajo',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: purple)),
                            Text('Notificar cuando el inventario sea crítico',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: purple.withValues(alpha: 0.7))),
                          ],
                        ),
                      ),
                      Switch(
                        value: _lowStockAlert,
                        onChanged: (v) => setState(() => _lowStockAlert = v),
                        activeTrackColor: purple,
                        thumbColor: WidgetStateProperty.all(Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Precios e Inventario ───────────────────────────────────────
            _buildSection(
              color: bgSection,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(
                      Icons.payments_outlined, 'Precios e Inventario', purple),
                  const SizedBox(height: 20),
                  // Precio unitario
                  _buildLabel('PRECIO UNITARIO'),
                  const SizedBox(height: 6),
                  _buildField(
                    controller: _priceCtrl,
                    hint: '0.00',
                    prefixText: '\$ ',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      final n = double.tryParse(v);
                      if (n == null || n < 0) return 'Precio inválido';
                      if (n > 999999.99) return 'Máx \$999,999.99';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  // Presentación pills
                  _buildLabel('PRESENTACIÓN'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _presentations.map((p) {
                      final selected = _presentation == p;
                      return GestureDetector(
                        onTap: () => setState(() => _presentation = p),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: selected ? purple : Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: selected
                                  ? purple
                                  : const Color(0xFFCFC2D4)
                                      .withValues(alpha: 0.4),
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            p,
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.grey[600],
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  // Stock actual + Stock mínimo
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('STOCK ACTUAL'),
                            const SizedBox(height: 6),
                            _buildField(
                              controller: _stockCtrl,
                              hint: '0',
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.isEmpty) return null;
                                final n = int.tryParse(v);
                                if (n == null || n < 0) return 'Inválido';
                                if (n > 999999) return 'Máx 999,999';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('STOCK MÍNIMO'),
                            const SizedBox(height: 6),
                            _buildField(
                              controller: _minStockCtrl,
                              hint: '10',
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.isEmpty) return null;
                                final n = int.tryParse(v);
                                if (n == null || n < 0) return 'Inválido';
                                if (n > 999999) return 'Máx 999,999';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Proveedor
                  _buildLabel('PROVEEDOR'),
                  const SizedBox(height: 6),
                  _buildField(
                    controller: _supplierCtrl,
                    hint: 'Nombre',
                    prefixIcon: Icons.local_shipping_outlined,
                    maxLength: 500,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Notas ─────────────────────────────────────────────────────
            _buildSection(
              color: bgSection,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildLabel('NOTAS Y DESCRIPCIÓN'),
                      Text('Se registrará automáticamente el historial.',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[400],
                              fontStyle: FontStyle.italic)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 4,
                    maxLength: 1000,
                    decoration: InputDecoration(
                      hintText:
                          'Detalles sobre el cuidado, origen o estacionalidad...',
                      hintStyle:
                          TextStyle(color: Colors.grey[400], fontSize: 13),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFFCFC2D4), width: 0.4)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: purple, width: 1.5)),
                    ),
                  ),
                ],
              ),
            ),

            // ── Historial de compras (solo edición) ───────────────────────
            if (_isEditing) ...[
              const SizedBox(height: 12),
              _buildSection(
                color: bgSection,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionHeader(
                            Icons.history_rounded,
                            'Historial de compras',
                            purple),
                        TextButton.icon(
                          onPressed: _addPurchaseDialog,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Registrar'),
                          style: TextButton.styleFrom(
                              foregroundColor: purple,
                              textStyle: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_purchases.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text('Sin compras registradas',
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 13)),
                        ),
                      )
                    else
                      ..._purchases.map((purchase) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: purple.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                      Icons.shopping_cart_outlined,
                                      color: purple,
                                      size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          '+${purchase.quantity} $_presentation',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14)),
                                      Text(
                                          dateFmt.format(purchase.purchasedAt),
                                          style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 12)),
                                    ],
                                  ),
                                ),
                                if (purchase.unitPrice != null)
                                  Text(
                                      '\$${purchase.unitPrice!.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: purple,
                                          fontSize: 14)),
                              ],
                            ),
                          )),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required Color color, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppTheme.textLight)),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: Color(0xFF4C4452),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
    IconData? prefixIcon,
    String? prefixText,
    String? Function(String?)? validator,
  }) {
    const purple = Color(0xFF500088);
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 20, color: Colors.grey[500])
            : null,
        prefixText: prefixText,
        prefixStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: Color(0xFFCFC2D4), width: 0.4),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: purple, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
      ),
    );
  }
}
