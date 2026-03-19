import 'package:flutter/material.dart';
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

  static const _groups = ['Flor', 'Ocasión', 'Tipo'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final cats = await _repo.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Color helper ────────────────────────────────────────────────────────────

  ({Color bg, Color text}) _groupColor(String group) => switch (group) {
        'Flor' => (bg: const Color(0xFFECFDF5), text: const Color(0xFF065F46)),
        'Ocasión' => (
            bg: const Color(0xFFF5F3FF),
            text: const Color(0xFF5B21B6)
          ),
        _ => (bg: const Color(0xFFFFF7ED), text: const Color(0xFF9A3412)),
      };

  // ── Add / Edit sheet ────────────────────────────────────────────────────────

  Future<void> _openSheet({Map<String, dynamic>? existing}) async {
    // Collect parent ids for each group (categories without parent_id)
    final parents = _categories
        .where((c) => c['parent_id'] == null)
        .toList();

    final nameCtrl =
        TextEditingController(text: existing?['name'] as String? ?? '');
    String selectedGroup = existing?['group_name'] as String? ?? _groups.first;
    String? selectedParentId = existing?['parent_id'] as String?;
    bool isSaving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
              24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              // Name field
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
              // Group selector
              Text('Grupo',
                  style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.mutedLight,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
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
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
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
              // Parent selector (optional, only show parents of same group)
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
              // Save button
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
                          setModal(() => isSaving = true);
                          try {
                            if (existing == null) {
                              await _repo.createCategory(
                                name: name,
                                groupName: selectedGroup,
                                parentId: selectedParentId,
                              );
                            } else {
                              await _repo.updateCategory(
                                id: existing['id'] as String,
                                name: name,
                                groupName: selectedGroup,
                              );
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                            _load();
                          } catch (e) {
                            setModal(() => isSaving = false);
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
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    // Group categories
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final cat in _categories) {
      final g = cat['group_name'] as String? ?? 'Otro';
      grouped.putIfAbsent(g, () => []).add(cat);
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSheet(),
        backgroundColor: const Color(0xFF4F46E5),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Nueva',
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
                    // Header
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
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Groups
                    ..._groups.map((g) {
                      final cats = grouped[g] ?? [];
                      if (cats.isEmpty) return const SizedBox.shrink();
                      final style = _groupColor(g);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: style.bg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              g,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: style.text),
                            ),
                          ),
                          ...cats.map((cat) => _CategoryRow(
                                cat: cat,
                                style: style,
                                onEdit: () => _openSheet(existing: cat),
                                onDelete: () => _confirmDelete(cat),
                              )),
                          const SizedBox(height: 16),
                        ],
                      );
                    }),
                    const SizedBox(height: 60), // FAB padding
                  ],
                ),
              ),
      ),
    );
  }
}

// ── Category row ───────────────────────────────────────────────────────────────

class _CategoryRow extends StatelessWidget {
  final Map<String, dynamic> cat;
  final ({Color bg, Color text}) style;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryRow({
    required this.cat,
    required this.style,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = cat['name'] as String? ?? '—';
    final isChild = cat['parent_id'] != null;

    return Container(
      margin: EdgeInsets.only(bottom: 8, left: isChild ? 16 : 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppTheme.cardLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isChild
                ? style.text.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          if (isChild)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.subdirectory_arrow_right_rounded,
                  size: 14, color: style.text.withValues(alpha: 0.5)),
            ),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      isChild ? FontWeight.normal : FontWeight.w600),
            ),
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
    );
  }
}
