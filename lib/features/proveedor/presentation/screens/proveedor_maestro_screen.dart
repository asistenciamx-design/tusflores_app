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

  // grouped: groupName → [categories]
  Map<String, List<MaestroCategory>> _grouped = {};
  String? _selectedGroup;

  // Expansion state per category
  final Map<String, bool> _expanded = {};
  // Sub-categories and sub-colors loaded on demand
  final Map<String, List<MaestroSubCategory>> _subCats = {};
  final Map<String, List<MaestroSubColor>> _subColors = {};

  // Already in proveedor catalog
  Set<MaestroSelection> _existing = {};

  // Newly selected in this session
  final Set<MaestroSelection> _newSelections = {};
  final Set<MaestroSelection> _toRemove = {};

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

      setState(() {
        _grouped = grouped;
        _existing = existing;
        _selectedGroup = grouped.keys.isNotEmpty ? grouped.keys.first : null;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggleCategory(MaestroCategory cat) async {
    final expanded = _expanded[cat.id] ?? false;
    if (!expanded) {
      // Load sub-categories if not loaded
      if (_subCats[cat.id] == null) {
        final subs = await _repo.getMaestroSubCategories(cat.id);
        setState(() => _subCats[cat.id] = subs);
        // Load sub-colors for each sub-category
        for (final sub in subs) {
          if (_subColors[sub.id] == null) {
            final colors = await _repo.getMaestroSubColors(sub.id);
            setState(() => _subColors[sub.id] = colors);
          }
        }
      }
    }
    setState(() => _expanded[cat.id] = !expanded);
  }

  bool _isExisting(MaestroSelection sel) => _existing.contains(sel);

  void _toggleSelection(MaestroSelection sel) {
    if (_isExisting(sel)) {
      // Toggle removal of existing
      setState(() {
        if (_toRemove.contains(sel)) {
          _toRemove.remove(sel);
        } else {
          _toRemove.add(sel);
        }
      });
    } else {
      setState(() {
        if (_newSelections.contains(sel)) {
          _newSelections.remove(sel);
        } else {
          _newSelections.add(sel);
        }
      });
    }
  }

  bool _isMarkedForRemoval(MaestroSelection sel) => _toRemove.contains(sel);

  Future<void> _save() async {
    if (_newSelections.isEmpty && _toRemove.isEmpty) return;
    setState(() => _saving = true);
    try {
      if (_newSelections.isNotEmpty) {
        await _repo.addProductosFromMaestro(_newSelections.toList());
      }
      // Remove is done from Mi Catálogo — we only add here
      setState(() {
        _existing = {..._existing, ..._newSelections};
        _newSelections.clear();
        _toRemove.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Catálogo actualizado'),
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

  int get _pendingCount => _newSelections.length + _toRemove.length;

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

    final groups = _grouped.keys.toList();
    final currentCats = _grouped[_selectedGroup] ?? [];

    return Stack(
      children: [
        Column(
          children: [
            // Group pill selector
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: groups.length,
                itemBuilder: (_, i) {
                  final g = groups[i];
                  final active = g == _selectedGroup;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedGroup = g),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                            color: active ? Colors.white : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Category list
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: _pendingCount > 0 ? 88 : 16,
                ),
                itemCount: currentCats.length,
                itemBuilder: (_, i) => _buildCategoryTile(currentCats[i]),
              ),
            ),
          ],
        ),
        // Floating save bar
        if (_pendingCount > 0)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF500088),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 4,
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Agregar $_pendingCount producto${_pendingCount != 1 ? 's' : ''} a Mi Catálogo',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryTile(MaestroCategory cat) {
    final isExpanded = _expanded[cat.id] ?? false;
    final subs = _subCats[cat.id] ?? [];

    // Direct category selection (no sub-categories)
    final directSel = MaestroSelection(categoryId: cat.id);
    final hasSubs = isExpanded && subs.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _toggleCategory(cat),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (cat.imageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        cat.imageUrl!,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholderIcon(),
                      ),
                    )
                  else
                    _placeholderIcon(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cat.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // If no sub-cats are loaded yet or subs is empty after expand,
                  // show checkbox for direct selection
                  if (!isExpanded)
                    const Icon(Icons.chevron_right_rounded,
                        color: Colors.grey),
                  if (isExpanded && subs.isEmpty)
                    _buildCheckbox(directSel),
                  if (isExpanded && subs.isNotEmpty)
                    const Icon(Icons.expand_less_rounded,
                        color: Colors.grey),
                ],
              ),
            ),
          ),
          if (hasSubs)
            ...subs.map((sub) => _buildSubCategoryTile(cat.id, sub)),
        ],
      ),
    );
  }

  Widget _buildSubCategoryTile(String catId, MaestroSubCategory sub) {
    final colors = _subColors[sub.id] ?? [];
    final subSel = MaestroSelection(
        categoryId: catId, subCategoryId: sub.id);

    return Column(
      children: [
        const Divider(height: 1, indent: 16, endIndent: 16),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 10, 16, 10),
          child: Row(
            children: [
              if (sub.color != null && sub.color!.isNotEmpty)
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: _hexColor(sub.color!),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                ),
              Expanded(
                child: Text(
                  sub.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (colors.isEmpty) _buildCheckbox(subSel),
            ],
          ),
        ),
        if (colors.isNotEmpty)
          ...colors.map((c) => _buildSubColorTile(catId, sub.id, c)),
      ],
    );
  }

  Widget _buildSubColorTile(
      String catId, String subCatId, MaestroSubColor color) {
    final sel = MaestroSelection(
        categoryId: catId, subCategoryId: subCatId, subColorId: color.id);
    return Column(
      children: [
        const Divider(height: 1, indent: 40, endIndent: 16),
        Padding(
          padding: const EdgeInsets.fromLTRB(44, 8, 16, 8),
          child: Row(
            children: [
              if (color.color != null && color.color!.isNotEmpty)
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: _hexColor(color.color!),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                ),
              Expanded(
                child: Text(
                  color.name,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              _buildCheckbox(sel),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCheckbox(MaestroSelection sel) {
    final isExisting = _isExisting(sel);
    final isNew = _newSelections.contains(sel);
    final forRemoval = _isMarkedForRemoval(sel);

    Color boxColor;
    Widget? icon;

    if (isExisting && !forRemoval) {
      boxColor = const Color(0xFF059669);
      icon = const Icon(Icons.check, size: 14, color: Colors.white);
    } else if (forRemoval) {
      boxColor = Colors.red.shade400;
      icon = const Icon(Icons.remove, size: 14, color: Colors.white);
    } else if (isNew) {
      boxColor = const Color(0xFF500088);
      icon = const Icon(Icons.check, size: 14, color: Colors.white);
    } else {
      boxColor = Colors.grey.shade200;
      icon = null;
    }

    return GestureDetector(
      onTap: () => _toggleSelection(sel),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: boxColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isNew || isExisting ? Colors.transparent : Colors.grey.shade400,
          ),
        ),
        child: icon != null ? Center(child: icon) : null,
      ),
    );
  }

  Widget _placeholderIcon() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.local_florist_rounded,
          color: Colors.grey.shade400, size: 22),
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
