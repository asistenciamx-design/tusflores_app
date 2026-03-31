import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/repositories/admin_repository.dart';

// Los 10 grupos oficiales (orden fijo)
const _kOfficialGroups = [
  'Comerciales', 'Relleno', 'Bulbo', 'Silvestres', 'Tropicales',
  'Orquídeas', 'Jardín', 'Verano', 'Aromáticas', 'Temporada',
];

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
  String? _selectedGroup;
  final _searchCtrl = TextEditingController();
  final _pillScrollCtrl = ScrollController();

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
    _pillScrollCtrl.dispose();
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
        // Auto-seleccionar primer grupo oficial si ninguno elegido
        _selectedGroup ??= _kOfficialGroups.firstWhere(
          (g) => (_groups).contains(g),
          orElse: () => _groups.isNotEmpty ? _groups.first : '',
        );
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Colores por grupo ─────────────────────────────────────────────────────

  static const _groupColors = <String, ({Color bg, Color text, Color pill})>{
    'Comerciales': (bg: Color(0xFFFDF2F8), text: Color(0xFF9D174D), pill: Color(0xFFEC4899)),
    'Relleno':     (bg: Color(0xFFF0FDF4), text: Color(0xFF166534), pill: Color(0xFF22C55E)),
    'Bulbo':       (bg: Color(0xFFFFF7ED), text: Color(0xFF9A3412), pill: Color(0xFFF97316)),
    'Silvestres':  (bg: Color(0xFFF0F9FF), text: Color(0xFF0369A1), pill: Color(0xFF38BDF8)),
    'Tropicales':  (bg: Color(0xFFFFFBEB), text: Color(0xFF92400E), pill: Color(0xFFFBBF24)),
    'Orquídeas':   (bg: Color(0xFFF5F3FF), text: Color(0xFF5B21B6), pill: Color(0xFF8B5CF6)),
    'Jardín':      (bg: Color(0xFFECFDF5), text: Color(0xFF065F46), pill: Color(0xFF10B981)),
    'Verano':      (bg: Color(0xFFFEF9C3), text: Color(0xFF713F12), pill: Color(0xFFEAB308)),
    'Aromáticas':  (bg: Color(0xFFFDF4FF), text: Color(0xFF86198F), pill: Color(0xFFD946EF)),
    'Temporada':   (bg: Color(0xFFEFF6FF), text: Color(0xFF1D4ED8), pill: Color(0xFF3B82F6)),
  };

  ({Color bg, Color text, Color pill}) _colorFor(String group) {
    return _groupColors[group] ??
        (bg: const Color(0xFFF3F4F6), text: const Color(0xFF374151), pill: const Color(0xFF6B7280));
  }

  // ── Toggle pausa ──────────────────────────────────────────────────────────

  Future<void> _toggleActive(Map<String, dynamic> cat) async {
    final isActive = cat['is_active'] as bool? ?? true;
    final name = cat['name'] as String? ?? '';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isActive ? 'Pausar flor' : 'Activar flor'),
        content: Text(
          isActive
              ? '¿Pausar "$name"? No aparecerá en el selector hasta que la reactives.'
              : '¿Activar "$name"? Volverá a aparecer en el selector.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
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
          const SnackBar(content: Text('Error al cambiar estado')),
        );
      }
    }
  }

  // ── Crear grupo ──────────────────────────────────────────────────────────

  Future<void> _createGroup() async {
    final nameCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nuevo grupo'),
        content: TextField(
          controller: nameCtrl,
          textCapitalization: TextCapitalization.words,
          maxLength: 40,
          decoration: InputDecoration(
            labelText: 'Nombre del grupo',
            hintText: 'Ej: Exóticas, Acuáticas...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            counterText: '',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
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

  // ── Eliminar ──────────────────────────────────────────────────────────────

  Future<void> _confirmDelete(Map<String, dynamic> cat) async {
    final name = cat['name'] as String? ?? '';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar flor'),
        content: Text('¿Eliminar "$name"? Esta acción es permanente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _repo.deleteCategory(cat['id'] as String);
      _load();
    }
  }

  // ── Add / Edit sheet ──────────────────────────────────────────────────────

  Future<void> _openSheet({Map<String, dynamic>? existing}) async {
    final nameCtrl = TextEditingController(text: existing?['name'] as String? ?? '');
    String selectedGroup = existing?['group_name'] as String? ??
        (_selectedGroup ?? (_groups.isNotEmpty ? _groups.first : ''));
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
            final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
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
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    existing == null ? 'Agregar flor' : 'Editar flor',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (existing?['sku'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      existing!['sku'] as String,
                      style: const TextStyle(
                        fontSize: 12, color: Color(0xFF4F46E5),
                        fontWeight: FontWeight.w700, letterSpacing: 1.2,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Imagen
                  Row(
                    children: [
                      GestureDetector(
                        onTap: isSaving ? null : pickImage,
                        child: Container(
                          width: 72, height: 72,
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
                                    if (!snap.hasData) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                                    return Image.memory(snap.data!, fit: BoxFit.cover);
                                  },
                                )
                              : existingImageUrl != null
                                  ? Image.network(existingImageUrl!, fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.grey))
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_photo_alternate_outlined, size: 24, color: Colors.grey.shade400),
                                        const SizedBox(height: 2),
                                        Text('Foto', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                                      ],
                                    ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextButton.icon(
                              onPressed: isSaving ? null : pickImage,
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF4F46E5),
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: const Icon(Icons.photo_library_outlined, size: 16),
                              label: Text(
                                pickedFile != null || existingImageUrl != null ? 'Cambiar imagen' : 'Agregar imagen',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            Text('JPG, PNG · máx. 5 MB',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                            if (existingImageUrl != null && pickedFile == null)
                              TextButton.icon(
                                onPressed: isSaving ? null : () => setModal(() => existingImageUrl = null),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red.shade400,
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(Icons.delete_outline, size: 14),
                                label: const Text('Quitar', style: TextStyle(fontSize: 12)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Nombre
                  TextField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 60,
                    decoration: InputDecoration(
                      labelText: 'Nombre de la flor',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Categoría
                  Text('Categoría',
                      style: TextStyle(fontSize: 13, color: AppTheme.mutedLight, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _groups.map((g) {
                      final c = _colorFor(g);
                      final isSelected = selectedGroup == g;
                      return FilterChip(
                        label: Text(g),
                        selected: isSelected,
                        onSelected: (_) => setModal(() => selectedGroup = g),
                        backgroundColor: Colors.white,
                        selectedColor: c.bg,
                        labelStyle: TextStyle(
                          color: isSelected ? c.text : AppTheme.textLight,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 13,
                        ),
                        side: BorderSide(
                          color: isSelected ? c.text.withValues(alpha: 0.4) : Colors.grey.shade300,
                        ),
                        showCheckmark: false,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Guardar
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              final name = nameCtrl.text.trim();
                              if (name.isEmpty || selectedGroup.isEmpty) return;
                              setModal(() => isSaving = true);
                              try {
                                String? imageUrl = existingImageUrl;
                                if (pickedFile != null) {
                                  imageUrl = await _repo.uploadCategoryImage(pickedFile!);
                                }
                                if (existing == null) {
                                  await _repo.createCategory(
                                    name: name,
                                    groupName: selectedGroup,
                                    imageUrl: imageUrl,
                                  );
                                } else {
                                  await _repo.updateCategory(
                                    id: existing['id'] as String,
                                    name: name,
                                    groupName: selectedGroup,
                                    imageUrl: imageUrl,
                                    clearImage: existingImageUrl == null && pickedFile == null,
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
                              height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Guardar',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Ordenar grupos: primero los 10 oficiales, luego el resto
    final sortedGroups = [
      ..._kOfficialGroups.where((g) => _groups.contains(g)),
      ..._groups.where((g) => !_kOfficialGroups.contains(g)),
    ];

    // Flores del grupo seleccionado, filtradas por búsqueda
    final visibleCats = _categories.where((c) {
      final matchesGroup = _selectedGroup == null || c['group_name'] == _selectedGroup;
      final matchesSearch = _searchQuery.isEmpty ||
          (c['name'] as String? ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesGroup && matchesSearch;
    }).toList()
      ..sort((a, b) {
        final sa = (a['sort_order'] as int?) ?? 999;
        final sb = (b['sort_order'] as int?) ?? 999;
        if (sa != sb) return sa.compareTo(sb);
        return (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? '');
      });

    final activeColor = _selectedGroup != null ? _colorFor(_selectedGroup!) : null;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: sortedGroups.isEmpty ? null : () => _openSheet(),
        backgroundColor: const Color(0xFF4F46E5),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Agregar flor',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: CustomScrollView(
                  slivers: [
                    // ── Header ─────────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Row(
                          children: [
                            const Icon(Icons.local_florist_rounded,
                                color: Color(0xFF4F46E5), size: 22),
                            const SizedBox(width: 8),
                            const Text('Categorías',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            const Spacer(),
                            // Contador total
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_categories.length} total',
                                style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF4F46E5), fontWeight: FontWeight.w600),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: const Color(0xFF065F46).withValues(alpha: 0.3)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add_rounded, size: 14, color: Color(0xFF065F46)),
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
                      ),
                    ),

                    // ── Buscador ───────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText: 'Buscar por nombre de flor...',
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
                            fillColor: Colors.white,
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
                      ),
                    ),

                    // ── Pills de categorías ────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: SizedBox(
                          height: 40,
                          child: ListView.separated(
                            controller: _pillScrollCtrl,
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: sortedGroups.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (_, i) {
                              final g = sortedGroups[i];
                              final isSelected = _selectedGroup == g;
                              final c = _colorFor(g);
                              return GestureDetector(
                                onTap: () => setState(() {
                                  _selectedGroup = isSelected ? null : g;
                                  _searchCtrl.clear();
                                  _searchQuery = '';
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? c.pill : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected
                                          ? c.pill
                                          : Colors.grey.shade300,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: c.pill.withValues(alpha: 0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            )
                                          ]
                                        : null,
                                  ),
                                  child: Text(
                                    g,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    // ── Indicador de categoría seleccionada ────────────────
                    if (_selectedGroup != null && activeColor != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: activeColor.bg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _selectedGroup!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: activeColor.text,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${visibleCats.length} flores',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // ── Lista de flores ────────────────────────────────────
                    if (visibleCats.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 60),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.local_florist_outlined,
                                    size: 48, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'Sin resultados para "$_searchQuery"'
                                      : 'Esta categoría no tiene flores',
                                  style: TextStyle(
                                      color: AppTheme.mutedLight, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (_, i) {
                              final cat = visibleCats[i];
                              final group = cat['group_name'] as String? ?? '';
                              final c = _colorFor(group);
                              return _FlowerRow(
                                cat: cat,
                                colors: c,
                                showGroupBadge: _selectedGroup == null,
                                onEdit: () => _openSheet(existing: cat),
                                onDelete: () => _confirmDelete(cat),
                                onToggleActive: () => _toggleActive(cat),
                              );
                            },
                            childCount: visibleCats.length,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ── Fila de flor ──────────────────────────────────────────────────────────────

class _FlowerRow extends StatelessWidget {
  final Map<String, dynamic> cat;
  final ({Color bg, Color text, Color pill}) colors;
  final bool showGroupBadge;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;

  const _FlowerRow({
    required this.cat,
    required this.colors,
    required this.showGroupBadge,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final name = cat['name'] as String? ?? '—';
    final sku = cat['sku'] as String?;
    final imageUrl = cat['image_url'] as String?;
    final isActive = cat['is_active'] as bool? ?? true;
    final group = cat['group_name'] as String? ?? '';

    return Opacity(
      opacity: isActive ? 1.0 : 0.55,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? Colors.black.withValues(alpha: 0.06)
                : Colors.orange.shade200,
          ),
        ),
        child: Row(
          children: [
            // Thumbnail / icono
            Container(
              width: 44, height: 44,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: colors.bg,
              ),
              clipBehavior: Clip.antiAlias,
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.local_florist_outlined,
                        size: 20, color: colors.text.withValues(alpha: 0.5),
                      ),
                    )
                  : Icon(
                      Icons.local_florist_outlined,
                      size: 20, color: colors.text.withValues(alpha: 0.5),
                    ),
            ),

            // Nombre + código
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Row(
                    children: [
                      if (sku != null)
                        Text(
                          sku,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colors.text.withValues(alpha: 0.6),
                            letterSpacing: 0.8,
                          ),
                        ),
                      if (showGroupBadge && sku != null) const SizedBox(width: 6),
                      if (showGroupBadge)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: colors.bg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            group,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: colors.text,
                            ),
                          ),
                        ),
                      if (!isActive) ...[
                        const SizedBox(width: 6),
                        Container(
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
                    ],
                  ),
                ],
              ),
            ),

            // Acciones
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
              tooltip: 'Editar',
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              color: Colors.red.shade400,
              visualDensity: VisualDensity.compact,
              tooltip: 'Eliminar',
            ),
          ],
        ),
      ),
    );
  }
}
