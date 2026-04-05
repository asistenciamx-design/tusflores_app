import 'package:flutter/material.dart';
import '../../domain/models/proveedor_models.dart';
import '../../domain/repositories/proveedor_repository.dart';

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

  // Seleccionados en esta sesión
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

      // Agrupar y ordenar todo alfabéticamente
      final grouped = <String, List<MaestroCategory>>{};
      for (final c in cats) {
        grouped.putIfAbsent(c.groupName, () => []).add(c);
      }
      // Ordenar categorías dentro de cada grupo A→Z
      for (final g in grouped.keys) {
        grouped[g]!.sort((a, b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      }
      // Ordenar grupos A→Z
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

  Future<List<MaestroSubCategory>> _loadSubCats(String catId) async {
    if (_subCats[catId] == null) {
      final subs = await _repo.getMaestroSubCategories(catId);
      // Ordenar A→Z
      subs.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _subCats[catId] = subs;
      // Cargar sub-colores de cada sub-categoría
      for (final sub in subs) {
        if (_subColors[sub.id] == null) {
          final colors = await _repo.getMaestroSubColors(sub.id);
          colors.sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          _subColors[sub.id] = colors;
        }
      }
    }
    return _subCats[catId]!;
  }

  bool _isExisting(MaestroSelection sel) => _existing.contains(sel);
  bool _isNew(MaestroSelection sel) => _newSelections.contains(sel);
  bool _isSelected(MaestroSelection sel) =>
      _isExisting(sel) || _isNew(sel);

  void _toggleSelection(MaestroSelection sel) {
    if (_isExisting(sel)) return; // ya está — no se puede desmarcar aquí
    setState(() {
      if (_newSelections.contains(sel)) {
        _newSelections.remove(sel);
      } else {
        _newSelections.add(sel);
      }
    });
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

  // Cuántos items del catálogo tiene una categoría (existing + new)
  int _selectedCountForCat(MaestroCategory cat) {
    int count = 0;
    for (final sel in {..._existing, ..._newSelections}) {
      if (sel.categoryId == cat.id) count++;
    }
    return count;
  }

  Future<void> _openCategorySheet(MaestroCategory cat) async {
    // Cargar sub-cats y sub-colors si no están
    await _loadSubCats(cat.id);
    if (!mounted) return;

    final subs = _subCats[cat.id] ?? [];

    if (subs.isEmpty) {
      // Categoría sin variantes → selección directa
      await _openDirectSelectionSheet(cat);
    } else {
      // Categoría con sub-categorías → grid visual nivel 1
      await _openSubCatGridSheet(cat, subs);
    }
    // Al cerrar el sheet, refrescar el grid para mostrar checkmarks
    setState(() {});
  }

  /// Sheet Nivel 1: grid de sub-categorías con imagen
  Future<void> _openSubCatGridSheet(
      MaestroCategory cat, List<MaestroSubCategory> subs) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFFFBF8FF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    children: [
                      if (cat.imageUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            cat.imageUrl!,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _imgPlaceholder(44),
                          ),
                        )
                      else
                        _imgPlaceholder(44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF500088),
                              ),
                            ),
                            Text(
                              '${subs.length} variante${subs.length != 1 ? 's' : ''}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Grid de sub-categorías
                Flexible(
                  child: GridView.builder(
                    padding: EdgeInsets.fromLTRB(
                        16, 16, 16, _newSelections.isNotEmpty ? 88 : 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: subs.length,
                    itemBuilder: (_, i) {
                      final sub = subs[i];
                      final colors = _subColors[sub.id] ?? [];
                      final hasColors = colors.isNotEmpty;

                      // Contar seleccionados en esta sub-cat
                      int subSelCount = 0;
                      for (final sel
                          in {..._existing, ..._newSelections}) {
                        if (sel.subCategoryId == sub.id) subSelCount++;
                      }
                      // Si sub-cat no tiene sub-colors, es seleccionable directa
                      final directSel = MaestroSelection(
                          categoryId: cat.id, subCategoryId: sub.id);
                      final isDirectExisting =
                          !hasColors && _isExisting(directSel);
                      final isDirectNew =
                          !hasColors && _isNew(directSel);

                      return GestureDetector(
                        onTap: () async {
                          if (hasColors) {
                            // Nivel 2: abrir sheet encima (sin cerrar nivel 1)
                            await _openSubColorSheet(
                                cat, sub, setSheetState);
                            setSheetState(() {});
                          } else {
                            // Selección directa sin sub-colors
                            if (!isDirectExisting) {
                              _toggleSelection(directSel);
                              setSheetState(() {});
                              setState(() {});
                            }
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: (subSelCount > 0 ||
                                      isDirectNew ||
                                      isDirectExisting)
                                  ? const Color(0xFF500088)
                                      .withValues(alpha: 0.45)
                                  : Colors.grey.shade200,
                              width: (subSelCount > 0 ||
                                      isDirectNew ||
                                      isDirectExisting)
                                  ? 1.5
                                  : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    Colors.black.withValues(alpha: 0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Imagen
                              Expanded(
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ClipRRect(
                                      borderRadius:
                                          const BorderRadius.vertical(
                                              top: Radius.circular(15)),
                                      child: sub.imageUrl != null
                                          ? Image.network(
                                              sub.imageUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  _gridImgPlaceholder(),
                                            )
                                          : _gridImgPlaceholder(),
                                    ),
                                    // Badge selección
                                    if (subSelCount > 0)
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Container(
                                          width: 26,
                                          height: 26,
                                          decoration: BoxDecoration(
                                            color:
                                                const Color(0xFF059669),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: Colors.white,
                                                width: 2),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '$subSelCount',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight:
                                                    FontWeight.w800,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (!hasColors &&
                                        (isDirectNew || isDirectExisting))
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Container(
                                          width: 26,
                                          height: 26,
                                          decoration: BoxDecoration(
                                            color: isDirectExisting
                                                ? const Color(0xFF059669)
                                                : const Color(0xFF500088),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: Colors.white,
                                                width: 2),
                                          ),
                                          child: const Center(
                                            child: Icon(Icons.check,
                                                size: 13,
                                                color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    // Flecha si tiene sub-colors
                                    if (hasColors)
                                      Positioned(
                                        bottom: 8,
                                        right: 8,
                                        child: Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: Colors.black
                                                .withValues(alpha: 0.35),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.chevron_right_rounded,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // Nombre + dot color
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(10, 7, 10, 9),
                                child: Row(
                                  children: [
                                    if (sub.color != null &&
                                        sub.color!.isNotEmpty) ...[
                                      Container(
                                        width: 10,
                                        height: 10,
                                        margin:
                                            const EdgeInsets.only(right: 6),
                                        decoration: BoxDecoration(
                                          color: _hexColor(sub.color!),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Colors.grey.shade200),
                                        ),
                                      ),
                                    ],
                                    Expanded(
                                      child: Text(
                                        sub.name,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1F2937),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Botón guardar
                if (_newSelections.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving
                            ? null
                            : () async {
                                Navigator.of(ctx).pop();
                                await _save();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF500088),
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Agregar ${_newSelections.length} producto${_newSelections.length != 1 ? 's' : ''} a Mi Catálogo',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Sheet Nivel 2: lista de sub-colors para una sub-categoría específica
  Future<void> _openSubColorSheet(MaestroCategory cat,
      MaestroSubCategory sub, StateSetter parentSetState) async {
    final colors = _subColors[sub.id] ?? [];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setSheetState) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFFFBF8FF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.80,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header con imagen de sub-categoría
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    children: [
                      // Breadcrumb back button
                      GestureDetector(
                        onTap: () => Navigator.of(ctx2).pop(),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded,
                              size: 16, color: Color(0xFF500088)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (sub.imageUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            sub.imageUrl!,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _imgPlaceholder(44),
                          ),
                        )
                      else
                        _imgPlaceholder(44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sub.name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF500088),
                              ),
                            ),
                            Text(
                              '${colors.length} color${colors.length != 1 ? 'es' : ''}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Lista de sub-colors con checkbox
                Flexible(
                  child: colors.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'Sin colores registrados para esta variante.',
                            style: TextStyle(color: Colors.grey.shade500),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: colors.length,
                          itemBuilder: (_, i) {
                            final c = colors[i];
                            final sel = MaestroSelection(
                              categoryId: cat.id,
                              subCategoryId: sub.id,
                              subColorId: c.id,
                            );
                            return _buildSelectionRow(
                              label: c.name,
                              colorHex: c.color,
                              sel: sel,
                              indent: 20,
                              setSheetState: (fn) {
                                setSheetState(fn);
                                parentSetState(() {});
                                setState(() {});
                              },
                            );
                          },
                        ),
                ),
                // Botón guardar
                if (_newSelections.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving
                            ? null
                            : () async {
                                Navigator.of(ctx2).pop();
                                await _save();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF500088),
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Agregar ${_newSelections.length} producto${_newSelections.length != 1 ? 's' : ''} a Mi Catálogo',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openDirectSelectionSheet(MaestroCategory cat) async {
    final sel = MaestroSelection(categoryId: cat.id);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final selected = _isSelected(sel);
          final isExisting = _isExisting(sel);
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFFFBF8FF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: GestureDetector(
                    onTap: isExisting
                        ? null
                        : () {
                            _toggleSelection(sel);
                            setSheetState(() {});
                            setState(() {});
                          },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF500088).withValues(alpha: 0.06)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF500088)
                              : Colors.grey.shade200,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              cat.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          _sheetCheckbox(sel, setSheetState),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_newSelections.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving
                            ? null
                            : () async {
                                Navigator.of(ctx).pop();
                                await _save();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF500088),
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Agregar ${_newSelections.length} producto${_newSelections.length != 1 ? 's' : ''} a Mi Catálogo',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectionRow({
    required String label,
    required String? colorHex,
    required MaestroSelection sel,
    required double indent,
    required StateSetter setSheetState,
  }) {
    final selected = _isSelected(sel);
    final isExisting = _isExisting(sel);

    return InkWell(
      onTap: isExisting
          ? null
          : () {
              _toggleSelection(sel);
              setSheetState(() {});
            },
      child: Container(
        color: selected && !isExisting
            ? const Color(0xFF500088).withValues(alpha: 0.04)
            : null,
        padding: EdgeInsets.fromLTRB(indent, 12, 20, 12),
        child: Row(
          children: [
            if (colorHex != null && colorHex.isNotEmpty) ...[
              Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: _hexColor(colorHex),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300),
                ),
              ),
            ],
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? const Color(0xFF500088)
                      : const Color(0xFF1F2937),
                ),
              ),
            ),
            _sheetCheckbox(sel, setSheetState),
          ],
        ),
      ),
    );
  }

  Widget _sheetCheckbox(MaestroSelection sel, StateSetter setSheetState) {
    final isExisting = _isExisting(sel);
    final isNew = _isNew(sel);

    Color boxColor;
    Widget? icon;

    if (isExisting) {
      boxColor = const Color(0xFF059669);
      icon = const Icon(Icons.check, size: 14, color: Colors.white);
    } else if (isNew) {
      boxColor = const Color(0xFF500088);
      icon = const Icon(Icons.check, size: 14, color: Colors.white);
    } else {
      boxColor = Colors.grey.shade100;
      icon = null;
    }

    return GestureDetector(
      onTap: isExisting
          ? null
          : () {
              _toggleSelection(sel);
              setSheetState(() {});
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: boxColor,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: isNew || isExisting
                ? Colors.transparent
                : Colors.grey.shade300,
          ),
        ),
        child: icon != null ? Center(child: icon) : null,
      ),
    );
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
            // ── Pills de grupo A→Z ──────────────────────────────────────
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
                      padding:
                          const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xFF500088)
                            : Colors.white,
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
            // ── Grid 2 columnas A→Z ─────────────────────────────────────
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
                itemBuilder: (_, i) =>
                    _buildCategoryCard(currentCats[i]),
              ),
            ),
          ],
        ),
        // ── Barra flotante de guardado ──────────────────────────────────
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

    // Contar sub-categorías cargadas para mostrar "N variantes"
    final subs = _subCats[cat.id];
    final variantLabel = subs != null
        ? '${subs.length} variante${subs.length != 1 ? 's' : ''}'
        : null;

    // Puntos de colores de las sub-categorías
    final colorDots = subs
        ?.where((s) => s.color != null && s.color!.isNotEmpty)
        .take(5)
        .toList();

    return GestureDetector(
      onTap: () => _openCategorySheet(cat),
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
            // Imagen
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
                            errorBuilder: (_, __, ___) =>
                                _gridImgPlaceholder(),
                          )
                        : _gridImgPlaceholder(),
                  ),
                  // Badge de seleccionados
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
                          border: Border.all(
                              color: Colors.white, width: 2),
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
            // Info
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

  Widget _gridImgPlaceholder() {
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

  Widget _imgPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF3EEF8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        Icons.local_florist_rounded,
        size: size * 0.5,
        color: const Color(0xFF500088).withValues(alpha: 0.3),
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
