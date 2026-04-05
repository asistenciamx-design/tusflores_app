import 'package:flutter/material.dart';
import '../../domain/models/proveedor_models.dart';
import '../../domain/repositories/proveedor_repository.dart';
import 'proveedor_maestro_detail_screen.dart';

class ProveedorMaestroScreen extends StatefulWidget {
  const ProveedorMaestroScreen({super.key});

  @override
  State<ProveedorMaestroScreen> createState() => _ProveedorMaestroScreenState();
}

class _ProveedorMaestroScreenState extends State<ProveedorMaestroScreen> {
  final _repo = ProveedorRepository();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  // grouped alfabéticamente: groupName → [categories ordenadas a-z]
  Map<String, List<MaestroCategory>> _grouped = {};
  List<String> _groups = [];
  String? _selectedGroup;

  // Sub-categorías y sub-colores cargados bajo demanda
  final Map<String, List<MaestroSubCategory>> _subCats = {};
  final Map<String, List<MaestroSubColor>> _subColors = {};

  // Ya en el catálogo del proveedor
  Set<MaestroSelection> _existing = {};

  // Seleccionados en esta sesión (pendientes de guardar)
  final Set<MaestroSelection> _newSelections = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repo.getMaestroCategories(),
        _repo.getMisSelecciones(),
      ]);
      final cats = results[0] as List<MaestroCategory>;
      final existing = results[1] as Set<MaestroSelection>;

      final grouped = <String, List<MaestroCategory>>{};
      for (final c in cats) {
        grouped.putIfAbsent(c.groupName, () => []).add(c);
      }
      for (final g in grouped.keys) {
        grouped[g]!.sort((a, b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      }
      final groups = grouped.keys.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      setState(() {
        _grouped = grouped;
        _groups = groups;
        _existing = existing;
        _selectedGroup = groups.isNotEmpty ? groups.first : null;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadSubCats(String catId) async {
    if (_subCats[catId] != null) return;
    final subs = await _repo.getMaestroSubCategories(catId);
    subs.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _subCats[catId] = subs;
    for (final sub in subs) {
      if (_subColors[sub.id] == null) {
        final colors = await _repo.getMaestroSubColors(sub.id);
        colors.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        _subColors[sub.id] = colors;
      }
    }
  }

  Future<void> _save() async {
    if (_newSelections.isEmpty) return;
    setState(() => _saving = true);
    try {
      await _repo.addProductosFromMaestro(_newSelections.toList());
      setState(() {
        _existing = {..._existing, ..._newSelections};
        _newSelections.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Productos agregados a tu catálogo'),
          backgroundColor: Color(0xFF059669),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int _selectedCountForCat(MaestroCategory cat) {
    int count = 0;
    for (final sel in {..._existing, ..._newSelections}) {
      if (sel.categoryId == cat.id) count++;
    }
    return count;
  }

  /// Navega a la pantalla de detalle visual completa para una categoría.
  Future<void> _openCategoryDetail(MaestroCategory cat) async {
    await _loadSubCats(cat.id);
    if (!mounted) return;

    final result = await Navigator.push<Set<MaestroSelection>>(
      context,
      MaterialPageRoute(
        builder: (_) => ProveedorMaestroDetailScreen(
          cat: cat,
          subs: _subCats[cat.id] ?? [],
          subColors: _subColors,
          existing: _existing,
          initialSelections: Set.from(_newSelections),
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _newSelections
          ..clear()
          ..addAll(result);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    final currentCats = _grouped[_selectedGroup] ?? [];

    return Stack(
      children: [
        Column(
          children: [
            // ── Pills de grupo A→Z ──────────────────────────────────────────
            SizedBox(
              height: 52,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                itemCount: _groups.length,
                itemBuilder: (_, i) {
                  final g = _groups[i];
                  final active = g == _selectedGroup;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedGroup = g),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: active ? const Color(0xFF500088) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active
                              ? const Color(0xFF500088)
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          g,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: active
                                ? Colors.white
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // ── Grid 2 columnas A→Z ─────────────────────────────────────────
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.fromLTRB(
                    16, 8, 16, _newSelections.isNotEmpty ? 96 : 16),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.78,
                ),
                itemCount: currentCats.length,
                itemBuilder: (_, i) => _buildCategoryCard(currentCats[i]),
              ),
            ),
          ],
        ),
        // ── Barra flotante de guardado ──────────────────────────────────────
        if (_newSelections.isNotEmpty)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF500088),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF500088).withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${_newSelections.length}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'productos seleccionados',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF500088),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF500088),
                              ),
                            )
                          : const Text(
                              'Guardar',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryCard(MaestroCategory cat) {
    final selectedCount = _selectedCountForCat(cat);
    final hasAnySelected = selectedCount > 0;

    final subs = _subCats[cat.id];
    final variantLabel = subs != null
        ? '${subs.length} variante${subs.length != 1 ? 's' : ''}'
        : null;

    final colorDots = subs
        ?.where((s) => s.color != null && s.color!.isNotEmpty)
        .take(5)
        .toList();

    return GestureDetector(
      onTap: () => _openCategoryDetail(cat),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasAnySelected
                ? const Color(0xFF500088).withValues(alpha: 0.4)
                : Colors.grey.shade200,
            width: hasAnySelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(15)),
                    child: cat.imageUrl != null
                        ? Image.network(
                            cat.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _imgPlaceholder(),
                          )
                        : _imgPlaceholder(),
                  ),
                  if (hasAnySelected)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFF500088),
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white, width: 2),
                        ),
                        child: Center(
                          child: selectedCount > 9
                              ? const Icon(Icons.check,
                                  size: 14, color: Colors.white)
                              : Text(
                                  '$selectedCount',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cat.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (variantLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      variantLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                  if (colorDots != null && colorDots.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: colorDots.map((s) {
                        return Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: _hexColor(s.color!),
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.grey.shade200),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imgPlaceholder() {
    return Container(
      color: const Color(0xFFF3EEF8),
      child: Center(
        child: Icon(
          Icons.local_florist_rounded,
          size: 40,
          color: const Color(0xFF500088).withValues(alpha: 0.25),
        ),
      ),
    );
  }

  Color _hexColor(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }
}
