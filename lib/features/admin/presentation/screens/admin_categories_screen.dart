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
  Map<String, int> _subCounts = {};
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
        _repo.getSubCategoryCounts(),
      ]);
      if (!mounted) return;
      setState(() {
        _groups = results[0] as List<String>;
        _categories = results[1] as List<Map<String, dynamic>>;
        _subCounts = results[2] as Map<String, int>;
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

  // ── Variantes (sub-flores) modal ───────────────────────────────────────────

  Future<void> _openVariantsSheet(Map<String, dynamic> parentCat) async {
    final parentId = parentCat['id'] as String;
    final parentName = parentCat['name'] as String? ?? '';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _VariantsModal(
        repo: _repo,
        parentId: parentId,
        parentName: parentName,
        colorFor: _colorFor,
        parentGroup: parentCat['group_name'] as String? ?? '',
      ),
    );
    // Recargar conteos al cerrar
    _load();
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

    // En modo búsqueda se ignora el grupo seleccionado → busca en todos
    final isSearching = _searchQuery.isNotEmpty;
    final visibleCats = _categories.where((c) {
      final matchesGroup = isSearching || _selectedGroup == null || c['group_name'] == _selectedGroup;
      final matchesSearch = isSearching
          ? (c['name'] as String? ?? '').toLowerCase().contains(_searchQuery.toLowerCase())
          : true;
      return matchesGroup && matchesSearch;
    }).toList()
      ..sort((a, b) =>
          (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''));

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
                              final catId = cat['id'] as String? ?? '';
                              return _FlowerRow(
                                key: ValueKey(catId),
                                cat: cat,
                                colors: c,
                                showGroupBadge: isSearching || _selectedGroup == null,
                                onEdit: () => _openSheet(existing: cat),
                                onDelete: () => _confirmDelete(cat),
                                onToggleActive: () => _toggleActive(cat),
                                onVariants: () => _openVariantsSheet(cat),
                                repo: _repo,
                                subCount: _subCounts[catId] ?? 0,
                                parentGroup: group,
                                colorFor: _colorFor,
                                onGroupJump: isSearching
                                    ? () {
                                        final g = cat['group_name'] as String?;
                                        if (g != null) {
                                          _searchCtrl.clear();
                                          setState(() {
                                            _searchQuery = '';
                                            _selectedGroup = g;
                                          });
                                        }
                                      }
                                    : null,
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

// ── Fila de flor (expandible) ────────────────────────────────────────────────

class _FlowerRow extends StatefulWidget {
  final Map<String, dynamic> cat;
  final ({Color bg, Color text, Color pill}) colors;
  final bool showGroupBadge;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;
  final VoidCallback onVariants;
  final AdminRepository repo;
  final int subCount;
  final VoidCallback? onGroupJump;
  final String parentGroup;
  final ({Color bg, Color text, Color pill}) Function(String) colorFor;

  const _FlowerRow({
    super.key,
    required this.cat,
    required this.colors,
    required this.showGroupBadge,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
    required this.onVariants,
    required this.repo,
    this.subCount = 0,
    this.onGroupJump,
    required this.parentGroup,
    required this.colorFor,
  });

  @override
  State<_FlowerRow> createState() => _FlowerRowState();
}

class _FlowerRowState extends State<_FlowerRow> {
  bool _expanded = false;
  List<Map<String, dynamic>>? _subs;
  bool _loadingSubs = false;

  Future<void> _toggleExpand() async {
    if (widget.onGroupJump != null) {
      widget.onGroupJump!();
      return;
    }
    if (widget.subCount == 0) return;

    if (_expanded) {
      setState(() => _expanded = false);
      return;
    }

    if (_subs == null) {
      setState(() => _loadingSubs = true);
      try {
        final rows = await widget.repo.getSubCategories(
          widget.cat['id'] as String,
        );
        if (mounted) setState(() { _subs = rows; _loadingSubs = false; _expanded = true; });
      } catch (_) {
        if (mounted) setState(() => _loadingSubs = false);
      }
    } else {
      setState(() => _expanded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.cat['name'] as String? ?? '—';
    final sku = widget.cat['sku'] as String?;
    final imageUrl = widget.cat['image_url'] as String?;
    final isActive = widget.cat['is_active'] as bool? ?? true;
    final group = widget.cat['group_name'] as String? ?? '';
    final c = widget.colors;

    return Opacity(
      opacity: isActive ? 1.0 : 0.55,
      child: Column(
        children: [
          GestureDetector(
            onTap: _toggleExpand,
            child: Container(
              margin: EdgeInsets.only(bottom: _expanded ? 0 : 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isActive ? Colors.white : Colors.grey.shade50,
                borderRadius: _expanded
                    ? const BorderRadius.vertical(top: Radius.circular(12))
                    : BorderRadius.circular(12),
                border: Border.all(
                  color: _expanded
                      ? const Color(0xFF4F46E5).withValues(alpha: 0.2)
                      : isActive
                          ? Colors.black.withValues(alpha: 0.06)
                          : Colors.orange.shade200,
                ),
              ),
              child: Row(
                children: [
                  // Thumbnail
                  Container(
                    width: 44, height: 44,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: c.bg,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: imageUrl != null
                        ? Image.network(imageUrl, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(Icons.local_florist_outlined, size: 20, color: c.text.withValues(alpha: 0.5)))
                        : Icon(Icons.local_florist_outlined, size: 20, color: c.text.withValues(alpha: 0.5)),
                  ),

                  // Nombre + código
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            ),
                            if (widget.subCount > 0) ...[
                              const SizedBox(width: 6),
                              Icon(
                                _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                size: 18, color: const Color(0xFF4F46E5),
                              ),
                            ],
                            if (_loadingSubs) ...[
                              const SizedBox(width: 6),
                              const SizedBox(width: 14, height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5))),
                            ],
                          ],
                        ),
                        Row(
                          children: [
                            if (sku != null)
                              Text(sku, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.text.withValues(alpha: 0.6), letterSpacing: 0.8)),
                            if (widget.subCount > 0) ...[
                              if (sku != null) const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('${widget.subCount}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5))),
                              ),
                            ],
                            if (widget.showGroupBadge) ...[
                              if (sku != null || widget.subCount > 0) const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(4)),
                                child: Text(group, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c.text)),
                              ),
                            ],
                            if (!isActive) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(4)),
                                child: Text('Pausada', style: TextStyle(fontSize: 10, color: Colors.orange.shade800, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Acciones
                  IconButton(
                    onPressed: widget.onVariants,
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                    color: const Color(0xFF4F46E5),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Gestionar variantes',
                  ),
                  IconButton(
                    onPressed: widget.onToggleActive,
                    icon: Icon(isActive ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded, size: 20),
                    color: isActive ? Colors.orange.shade400 : Colors.green.shade500,
                    visualDensity: VisualDensity.compact,
                    tooltip: isActive ? 'Pausar' : 'Activar',
                  ),
                  IconButton(
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    color: AppTheme.mutedLight,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Editar',
                  ),
                  IconButton(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    color: Colors.red.shade400,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Eliminar',
                  ),
                ],
              ),
            ),
          ),

          // Sub-flores expandidas
          if (_expanded && _subs != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: c.bg.withValues(alpha: 0.3),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.2)),
              ),
              child: Column(
                children: _subs!.map((v) {
                  final vName = v['name'] as String? ?? '';
                  final vColor = v['color'] as String?;
                  final vSku = v['sku'] as String?;
                  final vImage = v['image_url'] as String?;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      children: [
                        const SizedBox(width: 8),
                        Container(
                          width: 4, height: 28,
                          decoration: BoxDecoration(
                            color: c.pill.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: c.bg,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: vImage != null
                              ? Image.network(vImage, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(Icons.local_florist_outlined, size: 14, color: c.text.withValues(alpha: 0.5)))
                              : Icon(Icons.local_florist_outlined, size: 14, color: c.text.withValues(alpha: 0.5)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(vName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                              Row(
                                children: [
                                  if (vSku != null)
                                    Text(vSku, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: c.text.withValues(alpha: 0.5), letterSpacing: 0.8)),
                                  if (vColor != null && vColor.isNotEmpty) ...[
                                    if (vSku != null) const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                                      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(3)),
                                      child: Text(vColor, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: c.text)),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Modal de variantes (sub-flores) ──────────────────────────────────────────

class _VariantsModal extends StatefulWidget {
  final AdminRepository repo;
  final String parentId;
  final String parentName;
  final String parentGroup;
  final ({Color bg, Color text, Color pill}) Function(String) colorFor;

  const _VariantsModal({
    required this.repo,
    required this.parentId,
    required this.parentName,
    required this.parentGroup,
    required this.colorFor,
  });

  @override
  State<_VariantsModal> createState() => _VariantsModalState();
}

class _VariantsModalState extends State<_VariantsModal> {
  List<Map<String, dynamic>> _variants = [];
  Map<String, int> _toneCounts = {};
  bool _isLoading = true;
  bool _showForm = false;
  bool _isSaving = false;
  Map<String, dynamic>? _editing;

  final _nameCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  XFile? _pickedFile;
  String? _existingImageUrl;

  @override
  void initState() {
    super.initState();
    _loadVariants();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadVariants() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        widget.repo.getSubCategories(widget.parentId),
        widget.repo.getSubColorCounts(),
      ]);
      if (mounted) {
        setState(() {
          _variants = results[0] as List<Map<String, dynamic>>;
          _toneCounts = results[1] as Map<String, int>;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startAdd() {
    setState(() {
      _editing = null;
      _nameCtrl.clear();
      _colorCtrl.clear();
      _pickedFile = null;
      _existingImageUrl = null;
      _showForm = true;
    });
  }

  void _startEdit(Map<String, dynamic> variant) {
    setState(() {
      _editing = variant;
      _nameCtrl.text = variant['name'] as String? ?? '';
      _colorCtrl.text = variant['color'] as String? ?? '';
      _existingImageUrl = variant['image_url'] as String?;
      _pickedFile = null;
      _showForm = true;
    });
  }

  void _cancelForm() {
    setState(() => _showForm = false);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file != null) setState(() => _pickedFile = file);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      String? imageUrl = _existingImageUrl;
      if (_pickedFile != null) {
        imageUrl = await widget.repo.uploadCategoryImage(_pickedFile!);
      }

      if (_editing != null) {
        await widget.repo.updateSubCategory(
          id: _editing!['id'] as String,
          name: name,
          color: _colorCtrl.text.trim(),
          clearColor: _colorCtrl.text.trim().isEmpty,
          imageUrl: imageUrl,
          clearImage: _existingImageUrl == null && _pickedFile == null,
        );
      } else {
        await widget.repo.createSubCategory(
          parentId: widget.parentId,
          name: name,
          color: _colorCtrl.text.trim().isEmpty ? null : _colorCtrl.text.trim(),
          imageUrl: imageUrl,
        );
      }

      setState(() { _showForm = false; _isSaving = false; });
      _loadVariants();
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _openTones(Map<String, dynamic> variant) async {
    final variantId = variant['id'] as String;
    final variantName = variant['name'] as String? ?? '';
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SubColorsModal(
        repo: widget.repo,
        parentId: variantId,
        parentName: variantName,
        parentGroup: widget.parentGroup,
        colorFor: widget.colorFor,
      ),
    );
    _loadVariants();
  }

  Future<void> _deleteVariant(Map<String, dynamic> variant) async {
    final name = variant['name'] as String? ?? '';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar variante'),
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
      await widget.repo.deleteSubCategory(variant['id'] as String);
      _loadVariants();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colorFor(widget.parentGroup);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: c.bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.account_tree_outlined, color: c.text, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Variantes de ${widget.parentName}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${_variants.length} variante${_variants.length == 1 ? '' : 's'}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                if (!_showForm)
                  FilledButton.icon(
                    onPressed: _startAdd,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Agregar', style: TextStyle(fontSize: 13)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),

          // Content
          Flexible(
            child: _isLoading
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ))
                : SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                        24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Formulario inline
                        if (_showForm) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _editing != null ? 'Editar variante' : 'Nueva variante',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 12),

                                // Imagen
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: _isSaving ? null : _pickImage,
                                      child: Container(
                                        width: 56, height: 56,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: _pickedFile != null || _existingImageUrl != null
                                                ? const Color(0xFF4F46E5).withValues(alpha: 0.4)
                                                : Colors.grey.shade300,
                                          ),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: _pickedFile != null
                                            ? FutureBuilder<dynamic>(
                                                future: _pickedFile!.readAsBytes(),
                                                builder: (_, snap) {
                                                  if (!snap.hasData) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                                                  return Image.memory(snap.data!, fit: BoxFit.cover);
                                                },
                                              )
                                            : _existingImageUrl != null
                                                ? Image.network(_existingImageUrl!, fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 20))
                                                : Icon(Icons.add_photo_alternate_outlined, size: 20, color: Colors.grey.shade400),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        children: [
                                          // Nombre
                                          TextField(
                                            controller: _nameCtrl,
                                            textCapitalization: TextCapitalization.words,
                                            maxLength: 60,
                                            decoration: InputDecoration(
                                              labelText: 'Nombre',
                                              hintText: 'Ej: ${widget.parentName} Rojo',
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                              counterText: '',
                                              isDense: true,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          // Color
                                          TextField(
                                            controller: _colorCtrl,
                                            textCapitalization: TextCapitalization.words,
                                            maxLength: 30,
                                            decoration: InputDecoration(
                                              labelText: 'Color (opcional)',
                                              hintText: 'Ej: Rojo, Amarillo...',
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                              counterText: '',
                                              isDense: true,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Botones
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: _isSaving ? null : _cancelForm,
                                      child: const Text('Cancelar'),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton(
                                      onPressed: _isSaving ? null : _save,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(0xFF4F46E5),
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                      ),
                                      child: _isSaving
                                          ? const SizedBox(
                                              height: 16, width: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                            )
                                          : Text(_editing != null ? 'Actualizar' : 'Guardar',
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Lista de variantes
                        if (_variants.isEmpty && !_showForm)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.account_tree_outlined, size: 40, color: Colors.grey.shade300),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Sin variantes todavía',
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Agrega colores o tipos específicos',
                                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        ..._variants.map((v) {
                          final vName = v['name'] as String? ?? '';
                          final vColor = v['color'] as String?;
                          final vSku = v['sku'] as String?;
                          final vImage = v['image_url'] as String?;
                          final vActive = v['is_active'] as bool? ?? true;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: vActive ? Colors.white : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: vActive
                                    ? Colors.black.withValues(alpha: 0.06)
                                    : Colors.orange.shade200,
                              ),
                            ),
                            child: Opacity(
                              opacity: vActive ? 1.0 : 0.55,
                              child: Row(
                                children: [
                                  // Thumbnail
                                  Container(
                                    width: 40, height: 40,
                                    margin: const EdgeInsets.only(right: 10),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: c.bg,
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: vImage != null
                                        ? Image.network(vImage, fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Icon(Icons.local_florist_outlined, size: 18, color: c.text.withValues(alpha: 0.5)))
                                        : Icon(Icons.local_florist_outlined, size: 18, color: c.text.withValues(alpha: 0.5)),
                                  ),
                                  // Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(vName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                        Row(
                                          children: [
                                            if (vSku != null)
                                              Text(vSku, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c.text.withValues(alpha: 0.6), letterSpacing: 0.8)),
                                            if (vColor != null && vColor.isNotEmpty) ...[
                                              if (vSku != null) const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: c.bg,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(vColor, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c.text)),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Actions
                                  Builder(builder: (_) {
                                    final vId = v['id'] as String? ?? '';
                                    final toneCount = _toneCounts[vId] ?? 0;
                                    return Stack(
                                      children: [
                                        IconButton(
                                          onPressed: () => _openTones(v),
                                          icon: const Icon(Icons.account_tree_outlined, size: 16),
                                          color: toneCount > 0
                                              ? const Color(0xFF4F46E5)
                                              : Colors.grey.shade400,
                                          visualDensity: VisualDensity.compact,
                                          tooltip: 'Tonos',
                                        ),
                                        if (toneCount > 0)
                                          Positioned(
                                            right: 4, top: 4,
                                            child: Container(
                                              padding: const EdgeInsets.all(3),
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF4F46E5),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Text('$toneCount',
                                                style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                            ),
                                          ),
                                      ],
                                    );
                                  }),
                                  IconButton(
                                    onPressed: () => _startEdit(v),
                                    icon: const Icon(Icons.edit_outlined, size: 16),
                                    color: AppTheme.mutedLight,
                                    visualDensity: VisualDensity.compact,
                                    tooltip: 'Editar',
                                  ),
                                  IconButton(
                                    onPressed: () => _deleteVariant(v),
                                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                                    color: Colors.red.shade400,
                                    visualDensity: VisualDensity.compact,
                                    tooltip: 'Eliminar',
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Modal de tonos (sub-colores) ─────────────────────────────────────────────

class _SubColorsModal extends StatefulWidget {
  final AdminRepository repo;
  final String parentId;
  final String parentName;
  final String parentGroup;
  final ({Color bg, Color text, Color pill}) Function(String) colorFor;

  const _SubColorsModal({
    required this.repo,
    required this.parentId,
    required this.parentName,
    required this.parentGroup,
    required this.colorFor,
  });

  @override
  State<_SubColorsModal> createState() => _SubColorsModalState();
}

class _SubColorsModalState extends State<_SubColorsModal> {
  List<Map<String, dynamic>> _tones = [];
  bool _isLoading = true;
  bool _showForm = false;
  bool _isSaving = false;
  Map<String, dynamic>? _editing;

  final _nameCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  XFile? _pickedFile;
  String? _existingImageUrl;

  @override
  void initState() {
    super.initState();
    _loadTones();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTones() async {
    setState(() => _isLoading = true);
    try {
      final rows = await widget.repo.getSubColors(widget.parentId);
      if (mounted) setState(() { _tones = rows; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startAdd() {
    setState(() {
      _editing = null;
      _nameCtrl.clear();
      _colorCtrl.clear();
      _pickedFile = null;
      _existingImageUrl = null;
      _showForm = true;
    });
  }

  void _startEdit(Map<String, dynamic> tone) {
    setState(() {
      _editing = tone;
      _nameCtrl.text = tone['name'] as String? ?? '';
      _colorCtrl.text = tone['color'] as String? ?? '';
      _existingImageUrl = tone['image_url'] as String?;
      _pickedFile = null;
      _showForm = true;
    });
  }

  void _cancelForm() => setState(() => _showForm = false);

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file != null) setState(() => _pickedFile = file);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      String? imageUrl = _existingImageUrl;
      if (_pickedFile != null) {
        imageUrl = await widget.repo.uploadCategoryImage(_pickedFile!);
      }

      if (_editing != null) {
        await widget.repo.updateSubColor(
          id: _editing!['id'] as String,
          name: name,
          color: _colorCtrl.text.trim(),
          clearColor: _colorCtrl.text.trim().isEmpty,
          imageUrl: imageUrl,
          clearImage: _existingImageUrl == null && _pickedFile == null,
        );
      } else {
        await widget.repo.createSubColor(
          parentId: widget.parentId,
          name: name,
          color: _colorCtrl.text.trim().isEmpty ? null : _colorCtrl.text.trim(),
          imageUrl: imageUrl,
        );
      }

      setState(() { _showForm = false; _isSaving = false; });
      _loadTones();
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteTone(Map<String, dynamic> tone) async {
    final name = tone['name'] as String? ?? '';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar tono'),
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
      await widget.repo.deleteSubColor(tone['id'] as String);
      _loadTones();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colorFor(widget.parentGroup);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: c.bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.palette_outlined, color: c.text, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tonos de ${widget.parentName}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${_tones.length} tono${_tones.length == 1 ? '' : 's'}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                if (!_showForm)
                  FilledButton.icon(
                    onPressed: _startAdd,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Agregar', style: TextStyle(fontSize: 13)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),

          // Content
          Flexible(
            child: _isLoading
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ))
                : SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                        24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Formulario inline
                        if (_showForm) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _editing != null ? 'Editar tono' : 'Nuevo tono',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: _isSaving ? null : _pickImage,
                                      child: Container(
                                        width: 56, height: 56,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: _pickedFile != null || _existingImageUrl != null
                                                ? const Color(0xFF4F46E5).withValues(alpha: 0.4)
                                                : Colors.grey.shade300,
                                          ),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: _pickedFile != null
                                            ? FutureBuilder<dynamic>(
                                                future: _pickedFile!.readAsBytes(),
                                                builder: (_, snap) {
                                                  if (!snap.hasData) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                                                  return Image.memory(snap.data!, fit: BoxFit.cover);
                                                },
                                              )
                                            : _existingImageUrl != null
                                                ? Image.network(_existingImageUrl!, fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 20))
                                                : Icon(Icons.add_photo_alternate_outlined, size: 20, color: Colors.grey.shade400),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        children: [
                                          TextField(
                                            controller: _nameCtrl,
                                            textCapitalization: TextCapitalization.words,
                                            maxLength: 60,
                                            decoration: InputDecoration(
                                              labelText: 'Nombre',
                                              hintText: 'Ej: Champagne, Crema, Marfil...',
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                              counterText: '',
                                              isDense: true,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          TextField(
                                            controller: _colorCtrl,
                                            textCapitalization: TextCapitalization.words,
                                            maxLength: 30,
                                            decoration: InputDecoration(
                                              labelText: 'Tono (opcional)',
                                              hintText: 'Ej: Champagne',
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                              counterText: '',
                                              isDense: true,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: _isSaving ? null : _cancelForm,
                                      child: const Text('Cancelar'),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton(
                                      onPressed: _isSaving ? null : _save,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(0xFF4F46E5),
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                      ),
                                      child: _isSaving
                                          ? const SizedBox(
                                              height: 16, width: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                            )
                                          : Text(_editing != null ? 'Actualizar' : 'Guardar',
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Lista de tonos
                        if (_tones.isEmpty && !_showForm)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.palette_outlined, size: 40, color: Colors.grey.shade300),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Sin tonos todavía',
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Agrega tonos como Champagne, Crema, Marfil...',
                                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        ..._tones.map((t) {
                          final tName = t['name'] as String? ?? '';
                          final tColor = t['color'] as String?;
                          final tSku = t['sku'] as String?;
                          final tImage = t['image_url'] as String?;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40, height: 40,
                                  margin: const EdgeInsets.only(right: 10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: c.bg,
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: tImage != null
                                      ? Image.network(tImage, fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Icon(Icons.palette_outlined, size: 18, color: c.text.withValues(alpha: 0.5)))
                                      : Icon(Icons.palette_outlined, size: 18, color: c.text.withValues(alpha: 0.5)),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(tName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                      Row(
                                        children: [
                                          if (tSku != null)
                                            Text(tSku, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c.text.withValues(alpha: 0.6), letterSpacing: 0.8)),
                                          if (tColor != null && tColor.isNotEmpty) ...[
                                            if (tSku != null) const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: c.bg,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(tColor, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c.text)),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _startEdit(t),
                                  icon: const Icon(Icons.edit_outlined, size: 16),
                                  color: AppTheme.mutedLight,
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Editar',
                                ),
                                IconButton(
                                  onPressed: () => _deleteTone(t),
                                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                                  color: Colors.red.shade400,
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Eliminar',
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
