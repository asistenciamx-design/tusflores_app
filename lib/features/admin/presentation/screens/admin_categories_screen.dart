import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/repositories/admin_repository.dart';

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  final _repo = AdminRepository();
  bool _isLoading = true;
  List<Map<String, dynamic>> _categories = [];
  List<String> _groups = [];
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  // Paleta de colores ciclica para grupos dinámicos
  static const _palette = [
    (bg: Color(0xFFECFDF5), text: Color(0xFF065F46)),
    (bg: Color(0xFFF5F3FF), text: Color(0xFF5B21B6)),
    (bg: Color(0xFFFFF7ED), text: Color(0xFF9A3412)),
    (bg: Color(0xFFEFF6FF), text: Color(0xFF1D4ED8)),
    (bg: Color(0xFFFDF2F8), text: Color(0xFF9D174D)),
    (bg: Color(0xFFF0FDF4), text: Color(0xFF166534)),
    (bg: Color(0xFFFFFBEB), text: Color(0xFF92400E)),
    (bg: Color(0xFFF0F9FF), text: Color(0xFF0369A1)),
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _repo.getGroups(),
        _repo.getCategories(),
      ]);
      if (!mounted) return;
      setState(() {
        _groups = results[0] as List<String>;
        _categories = results[1] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Color helper ─────────────────────────────────────────────────────────────

  ({Color bg, Color text}) _groupColor(String group) {
    final idx = _groups.indexOf(group);
    final i = idx < 0 ? 0 : idx % _palette.length;
    return _palette[i];
  }

  // ── Pausa / activar categoría ────────────────────────────────────────────────

  Future<void> _toggleActive(Map<String, dynamic> cat) async {
    final isActive = cat['is_active'] as bool? ?? true;
    final name = cat['name'] as String? ?? '';
    final action = isActive ? 'pausar' : 'activar';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${isActive ? 'Pausar' : 'Activar'} categoría'),
        content: Text(
          isActive
              ? '¿Pausar "$name"? No aparecerá en el selector de productos hasta que la reactives.'
              : '¿Activar "$name"? Volverá a aparecer en el selector de productos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isActive ? Colors.orange : const Color(0xFF4F46E5),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isActive ? 'Pausar' : 'Activar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _repo.toggleCategoryActive(cat['id'] as String, isActive: !isActive);
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al $action la categoría')),
        );
      }
    }
  }

  // ── Crear nuevo grupo ────────────────────────────────────────────────────────

  Future<void> _createGroup() async {
    final nameCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo grupo'),
        content: TextField(
          controller: nameCtrl,
          textCapitalization: TextCapitalization.words,
          maxLength: 40,
          decoration: InputDecoration(
            labelText: 'Nombre del grupo',
            hintText: 'Ej: Color, Temporada...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            counterText: '',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Crear'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;
    if (_groups.contains(name)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('El grupo "$name" ya existe')),
        );
      }
      return;
    }
    try {
      await _repo.createGroup(name);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al crear el grupo')),
        );
      }
    }
  }

  // ── Add / Edit sheet ─────────────────────────────────────────────────────────

  Future<void> _openSheet({Map<String, dynamic>? existing}) async {
    final parents = _categories
        .where((c) => c['parent_id'] == null)
        .toList();

    final nameCtrl =
        TextEditingController(text: existing?['name'] as String? ?? '');
    String selectedGroup =
        existing?['group_name'] as String? ?? (_groups.isNotEmpty ? _groups.first : '');
    String? selectedParentId = existing?['parent_id'] as String?;
    String? existingImageUrl = existing?['image_url'] as String?;
    XFile? pickedFile;
    bool isSaving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          Future<void> pickImage() async {
            final picker = ImagePicker();
            final file =
                await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
            if (file != null) setModal(() => pickedFile = file);
          }

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(
                24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    existing == null ? 'Nueva categoría' : 'Editar categoría',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  // ── Imagen ───────────────────────────────────────────────
                  Text('Imagen de referencia',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.mutedLight,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: isSaving ? null : pickImage,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: pickedFile != null || existingImageUrl != null
                                  ? const Color(0xFF4F46E5).withValues(alpha: 0.4)
                                  : Colors.grey.shade300,
                              width: 1.5,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: pickedFile != null
                              ? FutureBuilder<dynamic>(
                                  future: pickedFile!.readAsBytes(),
                                  builder: (_, snap) {
                                    if (!snap.hasData) {
                                      return const Center(
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2));
                                    }
                                    return Image.memory(snap.data!,
                                        fit: BoxFit.cover);
                                  },
                                )
                              : existingImageUrl != null
                                  ? Image.network(existingImageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.broken_image_outlined,
                                              color: Colors.grey))
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_photo_alternate_outlined,
                                            size: 28, color: Colors.grey.shade400),
                                        const SizedBox(height: 4),
                                        Text('Agregar',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade400)),
                                      ],
                                    ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pickedFile != null
                                  ? 'Nueva imagen seleccionada'
                                  : existingImageUrl != null
                                      ? 'Imagen actual'
                                      : 'Sin imagen',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: pickedFile != null
                                      ? const Color(0xFF4F46E5)
                                      : AppTheme.textLight),
                            ),
                            const SizedBox(height: 4),
                            Text('JPG, PNG o WebP · máx. 5 MB',
                                style: TextStyle(
                                    fontSize: 11, color: AppTheme.mutedLight)),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: isSaving ? null : pickImage,
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF4F46E5),
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: const Icon(Icons.photo_library_outlined,
                                  size: 16),
                              label: Text(
                                pickedFile != null || existingImageUrl != null
                                    ? 'Cambiar imagen'
                                    : 'Seleccionar imagen',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            if (existingImageUrl != null && pickedFile == null)
                              TextButton.icon(
                                onPressed: isSaving
                                    ? null
                                    : () => setModal(() => existingImageUrl = null),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red.shade400,
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(Icons.delete_outline, size: 16),
                                label: const Text('Quitar imagen',
                                    style: TextStyle(fontSize: 12)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Nombre ───────────────────────────────────────────────
                  TextField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 60,
                    decoration: InputDecoration(
                      labelText: 'Nombre',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Grupo ────────────────────────────────────────────────
                  Text('Grupo',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.mutedLight,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _groups.map((g) {
                      final style = _groupColor(g);
                      final isSelected = selectedGroup == g;
                      return FilterChip(
                        label: Text(g),
                        selected: isSelected,
                        onSelected: (_) {
                          setModal(() {
                            selectedGroup = g;
                            selectedParentId = null;
                          });
                        },
                        backgroundColor: Colors.white,
                        selectedColor: style.bg,
                        labelStyle: TextStyle(
                          color: isSelected ? style.text : AppTheme.textLight,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                        side: BorderSide(
                            color: isSelected
                                ? style.text.withValues(alpha: 0.4)
                                : Colors.grey.shade300),
                        showCheckmark: false,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // ── Categoría padre (opcional) ────────────────────────────
                  Builder(builder: (_) {
                    final groupParents = parents
                        .where((p) => p['group_name'] == selectedGroup)
                        .toList();
                    if (groupParents.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Subcategoría de (opcional)',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.mutedLight,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String?>(
                          value: selectedParentId,
                          decoration: InputDecoration(
                            hintText: 'Sin categoría padre',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Sin categoría padre'),
                            ),
                            ...groupParents.map((p) => DropdownMenuItem<String?>(
                                  value: p['id'] as String,
                                  child: Text(p['name'] as String? ?? ''),
                                )),
                          ],
                          onChanged: (val) =>
                              setModal(() => selectedParentId = val),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  }),

                  // ── Guardar ──────────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              final name = nameCtrl.text.trim();
                              if (name.isEmpty) return;
                              if (selectedGroup.isEmpty) return;
                              setModal(() => isSaving = true);
                              try {
                                // Subir imagen si se seleccionó una nueva
                                String? imageUrl = existingImageUrl;
                                if (pickedFile != null) {
                                  imageUrl =
                                      await _repo.uploadCategoryImage(pickedFile!);
                                }

                                if (existing == null) {
                                  await _repo.createCategory(
                                    name: name,
                                    groupName: selectedGroup,
                                    parentId: selectedParentId,
                                    imageUrl: imageUrl,
                                  );
                                } else {
                                  await _repo.updateCategory(
                                    id: existing['id'] as String,
                                    name: name,
                                    groupName: selectedGroup,
                                    imageUrl: imageUrl,
                                    clearImage: existingImageUrl == null &&
                                        pickedFile == null,
                                  );
                                }
                                if (ctx.mounted) Navigator.pop(ctx);
                                _load();
                              } catch (e) {
                                setModal(() => isSaving = false);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              }
                            },
                      child: isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Guardar',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Confirmar eliminación ─────────────────────────────────────────────────────

  Future<void> _confirmDelete(Map<String, dynamic> cat) async {
    final name = cat['name'] as String? ?? '';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text('¿Eliminar "$name"? Esta acción es permanente.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _repo.deleteCategory(cat['id'] as String);
      _load();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Filtrar por búsqueda
    final filtered = _searchQuery.isEmpty
        ? _categories
        : _categories.where((c) {
            final name = (c['name'] as String? ?? '').toLowerCase();
            return name.contains(_searchQuery.toLowerCase());
          }).toList();

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final cat in filtered) {
      final g = cat['group_name'] as String? ?? 'Otro';
      grouped.putIfAbsent(g, () => []).add(cat);
    }

    // Incluir todos los grupos registrados, aunque estén vacíos (solo si no hay búsqueda activa)
    final allGroups = _searchQuery.isEmpty
        ? {
            ..._groups,
            ...grouped.keys,
          }.toList()
        : grouped.keys.toList();

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _groups.isEmpty ? null : () => _openSheet(),
        backgroundColor: const Color(0xFF4F46E5),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Nueva categoría',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // ── Header ─────────────────────────────────────────────
                    Row(
                      children: [
                        const Icon(Icons.category_rounded,
                            color: Color(0xFF4F46E5), size: 22),
                        const SizedBox(width: 8),
                        const Text('Categorías',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_categories.length} total',
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF4F46E5),
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Botón nuevo grupo
                        Tooltip(
                          message: 'Nuevo grupo',
                          child: InkWell(
                            onTap: _createGroup,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: const Color(0xFF065F46)
                                        .withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_rounded,
                                      size: 14, color: Color(0xFF065F46)),
                                  SizedBox(width: 3),
                                  Text('Grupo',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF065F46),
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Buscador ────────────────────────────────────────────
                    TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Buscar categoría...',
                        prefixIcon: const Icon(Icons.search_rounded,
                            size: 20, color: Color(0xFF4F46E5)),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppTheme.cardLight,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF4F46E5), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Sin grupos ─────────────────────────────────────────
                    if (allGroups.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Column(
                            children: [
                              Icon(Icons.folder_open_outlined,
                                  size: 48, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text('Crea un grupo primero',
                                  style: TextStyle(
                                      color: AppTheme.mutedLight,
                                      fontSize: 14)),
                            ],
                          ),
                        ),
                      ),

                    // ── Grupos con sus categorías ──────────────────────────
                    ...allGroups.map((g) {
                      final cats = grouped[g] ?? [];
                      final style = _groupColor(g);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Cabecera del grupo
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: style.bg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  g,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: style.text),
                                ),
                                if (cats.isEmpty) ...[
                                  const SizedBox(width: 6),
                                  Text('sin categorías',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: style.text.withValues(alpha: 0.6))),
                                ],
                              ],
                            ),
                          ),
                          ...cats.map((cat) => _CategoryRow(
                                cat: cat,
                                style: style,
                                onEdit: () => _openSheet(existing: cat),
                                onDelete: () => _confirmDelete(cat),
                                onToggleActive: () => _toggleActive(cat),
                              )),
                          const SizedBox(height: 16),
                        ],
                      );
                    }),
                    const SizedBox(height: 80), // espacio para FAB
                  ],
                ),
              ),
      ),
    );
  }
}

// ── Category row ──────────────────────────────────────────────────────────────

class _CategoryRow extends StatelessWidget {
  final Map<String, dynamic> cat;
  final ({Color bg, Color text}) style;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;

  const _CategoryRow({
    required this.cat,
    required this.style,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final name = cat['name'] as String? ?? '—';
    final isChild = cat['parent_id'] != null;
    final imageUrl = cat['image_url'] as String?;
    final isActive = cat['is_active'] as bool? ?? true;

    return Opacity(
      opacity: isActive ? 1.0 : 0.55,
      child: Container(
        margin: EdgeInsets.only(bottom: 8, left: isChild ? 16 : 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.cardLight : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isActive
                  ? (isChild
                      ? style.text.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.06))
                  : Colors.orange.shade200),
        ),
        child: Row(
          children: [
            // Thumbnail
            if (imageUrl != null)
              Container(
                width: 44,
                height: 44,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: style.bg,
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.image_not_supported_outlined,
                    size: 20,
                    color: style.text.withValues(alpha: 0.5),
                  ),
                ),
              )
            else
              Container(
                width: 44,
                height: 44,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: style.bg,
                ),
                child: Icon(
                  Icons.local_florist_outlined,
                  size: 20,
                  color: style.text.withValues(alpha: 0.5),
                ),
              ),

            if (isChild)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(Icons.subdirectory_arrow_right_rounded,
                    size: 14, color: style.text.withValues(alpha: 0.5)),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: isChild ? FontWeight.normal : FontWeight.w600,
                        decoration: isActive ? null : TextDecoration.none),
                  ),
                  if (!isActive)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('Pausada',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),
            // Botón pausa / reactivar
            IconButton(
              onPressed: onToggleActive,
              icon: Icon(
                isActive
                    ? Icons.pause_circle_outline_rounded
                    : Icons.play_circle_outline_rounded,
                size: 20,
              ),
              color: isActive ? Colors.orange.shade400 : Colors.green.shade500,
              visualDensity: VisualDensity.compact,
              tooltip: isActive ? 'Pausar' : 'Activar',
            ),
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              color: AppTheme.mutedLight,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              color: Colors.red.shade400,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
