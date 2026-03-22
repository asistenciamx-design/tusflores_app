import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_cache.dart';
import '../../domain/repositories/product_repository.dart';
import 'catalog_screen.dart' show ProductItem;

// ─── Category model ───────────────────────────────────────────────────────────

class _Category {
  final String id;
  final String name;
  final String? emoji;
  final String groupName;
  final String? parentId;

  _Category({
    required this.id,
    required this.name,
    this.emoji,
    required this.groupName,
    this.parentId,
  });

  factory _Category.fromMap(Map<String, dynamic> m) => _Category(
        id: m['id'] as String,
        name: m['name'] as String,
        emoji: m['emoji'] as String?,
        groupName: m['group_name'] as String,
        parentId: m['parent_id'] as String?,
      );

  String get displayName => emoji != null ? '$emoji $name' : name;
}

// ─── Group color palette ──────────────────────────────────────────────────────

const _kGroupPalette = [
  (bg: Color(0xFFECFDF5), text: Color(0xFF065F46), border: Color(0xFF6EE7B7)),
  (bg: Color(0xFFF5F3FF), text: Color(0xFF5B21B6), border: Color(0xFFDDD6FE)),
  (bg: Color(0xFFFFF7ED), text: Color(0xFF9A3412), border: Color(0xFFFDBA74)),
  (bg: Color(0xFFEFF6FF), text: Color(0xFF1D4ED8), border: Color(0xFF93C5FD)),
  (bg: Color(0xFFFDF2F8), text: Color(0xFF9D174D), border: Color(0xFFF9A8D4)),
  (bg: Color(0xFFFFFBEB), text: Color(0xFF92400E), border: Color(0xFFFCD34D)),
  (bg: Color(0xFFF0F9FF), text: Color(0xFF0369A1), border: Color(0xFF7DD3FC)),
  (bg: Color(0xFFF0FDF4), text: Color(0xFF166534), border: Color(0xFF86EFAC)),
];

// Cache de índice por nombre de grupo para colores consistentes por sesión
final _groupColorIndex = <String, int>{};
int _nextGroupIndex = 0;

({Color bg, Color text, Color border}) _groupChipStyle(String group) {
  if (!_groupColorIndex.containsKey(group)) {
    _groupColorIndex[group] = _nextGroupIndex % _kGroupPalette.length;
    _nextGroupIndex++;
  }
  return _kGroupPalette[_groupColorIndex[group]!];
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class AddEditProductScreen extends StatefulWidget {
  final ProductItem? product;
  final int? productIndex;

  const AddEditProductScreen({super.key, this.product, this.productIndex});

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _descCtrl;

  List<dynamic> _images = []; // mixed: String (network url) or XFile
  final List<_RecipeRow> _recipeRows = [];
  bool _isLoading = false;
  final _repo = ProductRepository();

  // Categories
  List<_Category> _allCategories = [];
  final Set<String> _selectedIds = {};
  bool _isLoadingCategories = true;

  bool get isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.product?.name ?? '');
    _priceCtrl = TextEditingController(
        text: widget.product != null ? widget.product!.price.toStringAsFixed(2) : '');
    _descCtrl = TextEditingController(text: widget.product?.description ?? '');
    if (widget.product != null) {
      _images = List.from(widget.product!.imageUrls);
      for (final item in widget.product!.recipe) {
        _recipeRows.add(_RecipeRow(
          initialQty: (item['qty'] as num?)?.toInt(),
          initialName: item['name'] as String?,
          initialColor: item['color'] as String?,
          initialQuality: item['quality'] as String?,
          initialType: item['type'] as String?,
        ));
      }
    }
    _loadCategories();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    for (final row in _recipeRows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final data = await Supabase.instance.client
          .from('categories')
          .select()
          .eq('is_active', true)
          .order('group_name')
          .order('name');
      if (!mounted) return;
      final cats = (data as List).map((m) => _Category.fromMap(m)).toList();
      final existingTags = widget.product?.tags ?? [];
      setState(() {
        _allCategories = cats;
        // Match existing tag names → IDs for edit mode
        for (final cat in cats) {
          if (existingTags.contains(cat.name)) _selectedIds.add(cat.id);
        }
        _isLoadingCategories = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  List<String> get _selectedNames => _allCategories
      .where((c) => _selectedIds.contains(c.id))
      .map((c) => c.name)
      .toList();

  void _openCategorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _CategorySheet(
        allCategories: _allCategories,
        selectedIds: Set.from(_selectedIds),
        onDone: (ids) => setState(() {
          _selectedIds
            ..clear()
            ..addAll(ids);
        }),
      ),
    );
  }

  Future<void> _pickImages() async {
    if (_images.length >= 5) return;
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        for (var file in pickedFiles) {
          if (_images.length < 5) _images.add(file);
        }
      });
    }
  }

  void _removeImage(int index) => setState(() => _images.removeAt(index));

  void _addRecipeRow() => setState(() => _recipeRows.add(_RecipeRow()));

  void _removeRecipeRow(int index) {
    setState(() {
      _recipeRows[index].dispose();
      _recipeRows.removeAt(index);
    });
  }

  Future<void> _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) throw Exception('No session found — cierra sesión e intenta de nuevo.');

        final name = _nameCtrl.text.trim();
        final price = double.parse(_priceCtrl.text.trim().replaceAll(',', ''));
        final desc = _descCtrl.text.trim();
        final recipe = _recipeRows
            .where((r) => r.name.text.trim().isNotEmpty)
            .map((r) => r.toJson())
            .toList();

        List<String> finalImageUrls = [];
        for (int i = 0; i < _images.length; i++) {
          final item = _images[i];
          if (item is String) {
            finalImageUrls.add(item);
          } else {
            final uploadedUrl = await _repo.uploadProductImage(user.id, item as XFile);
            if (uploadedUrl != null) finalImageUrls.add(uploadedUrl);
          }
        }

        String? autoSku;
        if (!isEditing) autoSku = await _repo.getNextSku(user.id);

        final productData = {
          'name': name,
          if (autoSku != null) 'sku': autoSku,
          'price': price,
          'description': desc.isNotEmpty ? desc : null,
          'recipe': recipe.isNotEmpty ? recipe : null,
          'tags': _selectedNames,
          'image_urls': finalImageUrls,
          'is_active': widget.product?.isVisible ?? true,
        };

        if (isEditing && widget.product!.id != null) {
          await _repo.updateProduct(widget.product!.id!, user.id, productData);
        } else {
          await _repo.createProduct(user.id, productData);
        }

        if (mounted) Navigator.pop(context, true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No se pudo guardar el producto. Intenta de nuevo.'),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 6),
              action: SnackBarAction(label: 'OK', textColor: Colors.white, onPressed: () {}),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditing ? 'Editar Producto' : 'Añadir Producto',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textLight,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildImageGallery(),
                      const SizedBox(height: 28),

                      // Nombre
                      _buildLabel('Nombre del arreglo'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: _inputDeco('Ej. Ramo Primaveral'),
                        maxLength: 100,
                        validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                      ),

                      // SKU
                      if (isEditing && widget.product!.sku != null && widget.product!.sku!.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildLabel('SKU'),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.qr_code, size: 18, color: AppTheme.primary),
                              const SizedBox(width: 10),
                              Text(widget.product!.sku!,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: AppTheme.primary,
                                      letterSpacing: 1.0)),
                              const SizedBox(width: 8),
                              Text('· asignado automáticamente',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Precio
                      _buildLabel('Precio (${CurrencyCache.symbol} ${CurrencyCache.code})'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: _inputDeco('0.00').copyWith(
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(left: 16, right: 8),
                            child: Icon(Icons.attach_money, size: 18, color: AppTheme.primary),
                          ),
                          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Requerido';
                          final parsed = double.tryParse(v.replaceAll(',', ''));
                          if (parsed == null) return 'Inválido';
                          if (parsed <= 0) return 'El precio debe ser mayor a 0';
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      // ── Categorías ──────────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildLabel('Categorías'),
                          Text(
                            '${_selectedIds.length}/3',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _selectedIds.length < 3 ? AppTheme.primary : Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (_isLoadingCategories)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      else ...[
                        // Selected chips
                        if (_selectedIds.isNotEmpty) ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _allCategories
                                .where((c) => _selectedIds.contains(c.id))
                                .map((cat) {
                                  final style = _groupChipStyle(cat.groupName);
                                  return Chip(
                                    label: Text(cat.name,
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: style.text,
                                            fontWeight: FontWeight.w600)),
                                    backgroundColor: style.bg,
                                    deleteIcon: Icon(Icons.close, size: 15, color: style.text),
                                    onDeleted: () => setState(() => _selectedIds.remove(cat.id)),
                                    side: BorderSide(color: style.border),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16)),
                                  );
                                })
                                .toList(),
                          ),
                          const SizedBox(height: 10),
                        ],
                        // Selector button
                        GestureDetector(
                          onTap: _openCategorySheet,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.label_outline,
                                    size: 18, color: AppTheme.primary.withValues(alpha: 0.8)),
                                const SizedBox(width: 10),
                                Text(
                                  _selectedIds.isEmpty
                                      ? 'Seleccionar categorías...'
                                      : 'Cambiar categorías',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: _selectedIds.isEmpty
                                          ? Colors.grey.shade400
                                          : AppTheme.primary),
                                ),
                                const Spacer(),
                                Icon(Icons.chevron_right,
                                    color: Colors.grey.shade400, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Descripción Corta
                      _buildLabel('Descripción Corta'),
                      const SizedBox(height: 4),
                      Text('Resumen breve visible en el catálogo.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descCtrl,
                        maxLines: 3,
                        maxLength: 300,
                        decoration:
                            _inputDeco('Ej. Ramo de 24 rosas rojas con follaje tropical...'),
                      ),

                      const SizedBox(height: 8),
                      _buildRecipeSection(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),

              // Bottom Button
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveProduct,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(color: Colors.white))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isEditing ? 'Guardar Cambios' : 'Crear Producto',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.check_circle, color: Colors.white, size: 20),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecipeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildLabel('Descripción Detallada'),
            if (_recipeRows.isNotEmpty)
              Text(
                '${_recipeRows.length} ${_recipeRows.length == 1 ? 'ingrediente' : 'ingredientes'}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Receta del arreglo: flores, follaje y materiales con cantidad, color y calidad.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 12),
        if (_recipeRows.isNotEmpty) ...[
          ...List.generate(_recipeRows.length, (i) {
            final row = _recipeRows[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final t in [
                              ('flor', '🌸', 'Flor'),
                              ('follaje', '🌿', 'Follaje'),
                              ('florero', '🏺', 'Florero'),
                              ('extra', '✨', 'Extra'),
                            ])
                              GestureDetector(
                                onTap: () => setState(() => row.type = t.$1),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: row.type == t.$1
                                        ? AppTheme.primary.withValues(alpha: 0.12)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: row.type == t.$1
                                          ? AppTheme.primary.withValues(alpha: 0.4)
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Text(
                                    '${t.$2} ${t.$3}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: row.type == t.$1
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: row.type == t.$1
                                          ? AppTheme.primary
                                          : Colors.grey.shade500,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, size: 18, color: Colors.grey.shade400),
                        onPressed: () => _removeRecipeRow(i),
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox(
                        width: 52,
                        child: TextField(
                          controller: row.qty,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 3,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: _inputDeco('Cant.').copyWith(
                            counterText: '',
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: row.name,
                          maxLength: 60,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: _inputDeco('Rosa, Eucalipto...').copyWith(
                            counterText: '',
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: row.color,
                          maxLength: 40,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: _inputDeco('Rojo...').copyWith(
                            counterText: '',
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: row.quality,
                          maxLength: 40,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: _inputDeco('Premium...').copyWith(
                            counterText: '',
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
        ],
        GestureDetector(
          onTap: _addRecipeRow,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 18, color: AppTheme.primary.withValues(alpha: 0.8)),
                const SizedBox(width: 8),
                Text(
                  'Agregar Flor / Material',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageGallery() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildLabel('Fotos del Producto (Máx 5)'),
            Text(
              '${_images.length}/5',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _images.length < 5 ? AppTheme.primary : Colors.grey.shade400,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (_images.length < 5)
                GestureDetector(
                  onTap: _pickImages,
                  child: Container(
                    width: 100,
                    height: 100,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.3), width: 1.5),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_a_photo, size: 28, color: AppTheme.primary),
                        const SizedBox(height: 8),
                        Text('Agregar',
                            style: TextStyle(
                                color: AppTheme.primary.withValues(alpha: 0.8),
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ...List.generate(_images.length, (index) {
                final item = _images[index];
                return Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.grey[200],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: item is String
                            ? Image.network(item,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))
                            : item is XFile
                                ? (kIsWeb
                                    ? Image.network(item.path,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.broken_image))
                                    : Image.file(File(item.path),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.broken_image)))
                                : const SizedBox(),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 16,
                      child: GestureDetector(
                        onTap: () => _removeImage(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                              color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) =>
      Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87));

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
      );
}

// ─── Category Bottom Sheet ─────────────────────────────────────────────────────

class _CategorySheet extends StatefulWidget {
  final List<_Category> allCategories;
  final Set<String> selectedIds;
  final void Function(Set<String>) onDone;

  const _CategorySheet({
    required this.allCategories,
    required this.selectedIds,
    required this.onDone,
  });

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.selectedIds);
  }

  void _toggle(String id) => setState(() {
        if (_selected.contains(id)) {
          _selected.remove(id);
        } else if (_selected.length < 3) {
          _selected.add(id);
        }
      });

  @override
  Widget build(BuildContext context) {
    final groups = widget.allCategories
        .map((c) => c.groupName)
        .toSet()
        .toList()
      ..sort();
    // Top-level categories per group (no parent)
    Map<String, List<_Category>> topLevel = {
      for (final g in groups)
        g: widget.allCategories.where((c) => c.groupName == g && c.parentId == null).toList()
    };
    // Children map: parentId → list
    Map<String, List<_Category>> children = {};
    for (final c in widget.allCategories.where((c) => c.parentId != null)) {
      children.putIfAbsent(c.parentId!, () => []).add(c);
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text('Seleccionar categorías',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _selected.length >= 3
                        ? Colors.grey.shade100
                        : AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_selected.length}/3',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _selected.length >= 3 ? Colors.grey.shade400 : AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                for (final group in groups) ...[
                  // Group header
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 3,
                          height: 14,
                          decoration: BoxDecoration(
                            color: _groupChipStyle(group).border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          group == 'Flor' ? 'Por Flor' : group == 'Ocasión' ? 'Por Ocasión' : 'Por Tipo',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: _groupChipStyle(group).text),
                        ),
                      ],
                    ),
                  ),
                  // Top-level chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (topLevel[group] ?? []).map((cat) {
                      final isSelected = _selected.contains(cat.id);
                      final hasChildren = children.containsKey(cat.id);
                      final atLimit = _selected.length >= 3 && !isSelected;
                      final style = _groupChipStyle(cat.groupName);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: atLimit ? null : () => _toggle(cat.id),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? style.text
                                    : atLimit
                                        ? Colors.grey.shade100
                                        : style.bg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? style.text
                                      : atLimit
                                          ? Colors.grey.shade200
                                          : style.border,
                                ),
                              ),
                              child: Text(
                                cat.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : atLimit
                                          ? Colors.grey.shade300
                                          : style.text,
                                ),
                              ),
                            ),
                          ),
                          // Subcategories indented
                          if (hasChildren) ...[
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: (children[cat.id] ?? []).map((sub) {
                                  final subSelected = _selected.contains(sub.id);
                                  final subAtLimit = _selected.length >= 3 && !subSelected;
                                  return GestureDetector(
                                    onTap: subAtLimit ? null : () => _toggle(sub.id),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: subSelected
                                            ? style.text.withValues(alpha: 0.85)
                                            : subAtLimit
                                                ? Colors.grey.shade50
                                                : style.bg,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: subSelected
                                              ? style.text
                                              : subAtLimit
                                                  ? Colors.grey.shade200
                                                  : style.border,
                                        ),
                                      ),
                                      child: Text(
                                        sub.name,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: subSelected
                                              ? Colors.white
                                              : subAtLimit
                                                  ? Colors.grey.shade300
                                                  : style.text,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                        ],
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
          // Done button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onDone(_selected);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    _selected.isEmpty
                        ? 'Confirmar sin categoría'
                        : _selected.length >= 3
                            ? 'Confirmar — límite alcanzado (3/3)'
                            : 'Confirmar (${_selected.length}/3)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Recipe Row Helper ─────────────────────────────────────────────────────────

class _RecipeRow {
  final TextEditingController qty;
  final TextEditingController name;
  final TextEditingController color;
  final TextEditingController quality;
  String type;

  _RecipeRow({
    int? initialQty,
    String? initialName,
    String? initialColor,
    String? initialQuality,
    String? initialType,
  })  : qty = TextEditingController(text: initialQty != null ? initialQty.toString() : ''),
        name = TextEditingController(text: initialName ?? ''),
        color = TextEditingController(text: initialColor ?? ''),
        quality = TextEditingController(text: initialQuality ?? ''),
        type = initialType ?? 'flor';

  void dispose() {
    qty.dispose();
    name.dispose();
    color.dispose();
    quality.dispose();
  }

  Map<String, dynamic> toJson() => {
        'qty': int.tryParse(qty.text.trim()) ?? 0,
        'name': name.text.trim(),
        'color': color.text.trim(),
        'quality': quality.text.trim(),
        'type': type,
      };
}
