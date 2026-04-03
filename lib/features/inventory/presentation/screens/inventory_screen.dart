import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/inventory_models.dart';
import '../../domain/repositories/inventory_repository.dart';

// ── Color del módulo ──────────────────────────────────────────────────────────
const _kColor = Color(0xFF7C3AED); // indigo/morado
const _kColorBg = Color(0xFFF5F3FF);
const _kColorBorder = Color(0xFFEDE9FE);

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _repo = InventoryRepository();
  List<InventoryList> _lists = [];
  bool _loading = true;
  String _filter = 'Todas'; // Todas, Activas, Completadas, Inactivas

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _repo.getLists();
      if (mounted) setState(() { _lists = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<InventoryList> get _filtered {
    switch (_filter) {
      case 'Activas':    return _lists.where((l) => l.isActive && !l.isCompleted).toList();
      case 'Completadas': return _lists.where((l) => l.isCompleted).toList();
      case 'Inactivas':  return _lists.where((l) => !l.isActive).toList();
      default:           return _lists;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Inventario', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textLight,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF3F4F6)),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, null),
        backgroundColor: _kColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva Lista', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kColor))
          : Column(
              children: [
                _buildFilterBar(),
                Expanded(child: _buildGrid()),
              ],
            ),
    );
  }

  Widget _buildFilterBar() {
    final opts = ['Todas', 'Activas', 'Completadas', 'Inactivas'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: opts.map((opt) {
            final active = _filter == opt;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _filter = opt),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: active ? _kColor : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: active ? _kColor : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Text(
                    opt,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: active ? Colors.white : AppTheme.mutedLight,
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

  Widget _buildGrid() {
    final items = _filtered;
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inventory_2_outlined, size: 64, color: _kColor.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              const Text('Sin listas aún',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
              const SizedBox(height: 8),
              const Text('Presiona "+ Nueva Lista" para comenzar',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.mutedLight, fontSize: 14)),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: _kColor,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.82,
        ),
        itemCount: items.length,
        itemBuilder: (ctx, i) => _NoteCard(
          list: items[i],
          onEdit: () => _openForm(context, items[i]),
          onToggleActive: () async {
            await _repo.toggleActive(items[i].id, !items[i].isActive);
            _load();
          },
          onToggleComplete: () async {
            await _repo.toggleCompleted(items[i].id, !items[i].isCompleted);
            _load();
          },
          onDelete: () => _confirmDelete(context, items[i]),
        ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, InventoryList? existing) async {
    String nextTitle = existing?.title ?? '';
    if (existing == null) nextTitle = await _repo.getNextTitle();

    if (!mounted) return;
    // ignore: use_build_context_synchronously
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ListFormSheet(
        initialTitle: nextTitle,
        initialItems: existing?.items ?? [],
        listId: existing?.id,
        repo: _repo,
      ),
    );
    if (result == true) _load();
  }

  Future<void> _confirmDelete(BuildContext context, InventoryList list) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar lista'),
        content: Text('¿Eliminar "${list.title}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _repo.deleteList(list.id);
      _load();
    }
  }
}

// ── Card de nota ──────────────────────────────────────────────────────────────
class _NoteCard extends StatelessWidget {
  final InventoryList list;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onToggleComplete;
  final VoidCallback onDelete;

  const _NoteCard({
    required this.list,
    required this.onEdit,
    required this.onToggleActive,
    required this.onToggleComplete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = list.isCompleted;
    final isInactive = !list.isActive;

    Color borderColor;
    Color bgColor;
    Color titleColor;

    if (isCompleted) {
      borderColor = const Color(0xFF86EFAC);
      bgColor = const Color(0xFFF0FDF4);
      titleColor = const Color(0xFF15803D);
    } else if (isInactive) {
      borderColor = const Color(0xFFE5E7EB);
      bgColor = const Color(0xFFF9FAFB);
      titleColor = AppTheme.mutedLight;
    } else {
      borderColor = _kColorBorder;
      bgColor = Colors.white;
      titleColor = AppTheme.textLight;
    }

    return Opacity(
      opacity: isInactive && !isCompleted ? 0.65 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Estado badge
              _StateBadge(isCompleted: isCompleted, isInactive: isInactive),
              const SizedBox(height: 10),
              // Título
              Text(
                list.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Fecha
              Text(
                DateFormat("d MMM yyyy", 'es').format(list.createdAt),
                style: const TextStyle(fontSize: 11, color: AppTheme.mutedLight),
              ),
              const SizedBox(height: 6),
              // Cantidad
              Row(
                children: [
                  Icon(Icons.format_list_bulleted, size: 13,
                      color: isCompleted ? const Color(0xFF16A34A) : _kColor),
                  const SizedBox(width: 4),
                  Text(
                    '${list.itemCount} ${list.itemCount == 1 ? 'producto' : 'productos'}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isCompleted ? const Color(0xFF16A34A) : _kColor,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Botones de acción
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ActionBtn(icon: Icons.edit_outlined, color: _kColor, onTap: onEdit),
                  _ActionBtn(
                    icon: isCompleted ? Icons.check_circle : Icons.check_circle_outline,
                    color: const Color(0xFF16A34A),
                    onTap: onToggleComplete,
                  ),
                  _ActionBtn(
                    icon: list.isActive ? Icons.toggle_on_outlined : Icons.toggle_off_outlined,
                    color: list.isActive ? AppTheme.mutedLight : const Color(0xFFF59E0B),
                    onTap: onToggleActive,
                  ),
                  _ActionBtn(icon: Icons.delete_outline, color: Colors.red.shade400, onTap: onDelete),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  final bool isCompleted;
  final bool isInactive;
  const _StateBadge({required this.isCompleted, required this.isInactive});

  @override
  Widget build(BuildContext context) {
    if (isCompleted) {
      return _pill('Completada', const Color(0xFF16A34A), const Color(0xFFDCFCE7));
    } else if (isInactive) {
      return _pill('Inactiva', AppTheme.mutedLight, const Color(0xFFF3F4F6));
    }
    return _pill('Activa', _kColor, _kColorBg);
  }

  Widget _pill(String label, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
      );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
      );
}

// ── Modal: Crear / Editar lista ───────────────────────────────────────────────
class _ListFormSheet extends StatefulWidget {
  final String initialTitle;
  final List<InventoryItem> initialItems;
  final String? listId;
  final InventoryRepository repo;

  const _ListFormSheet({
    required this.initialTitle,
    required this.initialItems,
    this.listId,
    required this.repo,
  });

  @override
  State<_ListFormSheet> createState() => _ListFormSheetState();
}

class _ListFormSheetState extends State<_ListFormSheet> {
  late TextEditingController _titleCtrl;
  late List<_ItemRow> _rows;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialTitle);
    _rows = widget.initialItems.isEmpty
        ? [_ItemRow()]
        : widget.initialItems.map((i) => _ItemRow.from(i)).toList();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    for (final r in _rows) { r.dispose(); }
    super.dispose();
  }

  void _addRow() => setState(() => _rows.add(_ItemRow()));
  void _removeRow(int i) { if (_rows.length > 1) setState(() { _rows[i].dispose(); _rows.removeAt(i); }); }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim().isEmpty ? widget.initialTitle : _titleCtrl.text.trim();
    final validRows = _rows.where((r) => r.name.text.trim().isNotEmpty).toList();
    if (validRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un producto')),
      );
      return;
    }

    // Ordenar alfabéticamente por nombre
    validRows.sort((a, b) => a.name.text.trim().toLowerCase().compareTo(b.name.text.trim().toLowerCase()));

    final items = validRows.asMap().entries.map((e) => InventoryItem(
          listId: widget.listId ?? '',
          sequenceNumber: e.key + 1,
          productName: e.value.name.text.trim(),
          color: e.value.color.text.trim(),
          quality: e.value.quality.text.trim(),
          quantity: int.tryParse(e.value.qty.text.trim()) ?? 1,
        )).toList();

    setState(() => _saving = true);
    try {
      if (widget.listId == null) {
        await widget.repo.createList(title: title, items: items);
      } else {
        await widget.repo.updateList(listId: widget.listId!, title: title, items: items);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.listId != null;
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.97,
      minChildSize: 0.5,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: _kColorBg, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.inventory_2_outlined, color: _kColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEdit ? 'Editar lista' : 'Nueva lista',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppTheme.mutedLight),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            // Body
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // Título
                  TextField(
                    controller: _titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Título',
                      hintText: widget.initialTitle,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _kColor, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Cabecera tabla
                  const _TableHeader(),
                  const Divider(height: 12),
                  // Filas
                  ..._rows.asMap().entries.map((e) => _ItemRowWidget(
                        row: e.value,
                        index: e.key + 1,
                        onRemove: () => _removeRow(e.key),
                        canRemove: _rows.length > 1,
                      )),
                  // Agregar fila
                  TextButton.icon(
                    onPressed: _addRow,
                    icon: const Icon(Icons.add, color: _kColor, size: 18),
                    label: const Text('Agregar producto', style: TextStyle(color: _kColor, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
            // Footer
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : Text(isEdit ? 'Guardar cambios' : 'Crear lista',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();
  @override
  Widget build(BuildContext context) => const Row(
        children: [
          SizedBox(width: 28, child: Text('#', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.mutedLight))),
          Expanded(flex: 4, child: Text('Producto', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.mutedLight))),
          Expanded(flex: 3, child: Text('Color', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.mutedLight))),
          Expanded(flex: 3, child: Text('Calidad', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.mutedLight))),
          Expanded(flex: 2, child: Text('Cant.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.mutedLight))),
          SizedBox(width: 28),
        ],
      );
}

// ── Fila editable ─────────────────────────────────────────────────────────────
class _ItemRow {
  final TextEditingController name = TextEditingController();
  final TextEditingController color = TextEditingController();
  final TextEditingController quality = TextEditingController();
  final TextEditingController qty = TextEditingController(text: '1');

  _ItemRow();

  factory _ItemRow.from(InventoryItem item) {
    final r = _ItemRow();
    r.name.text = item.productName;
    r.color.text = item.color;
    r.quality.text = item.quality;
    r.qty.text = item.quantity.toString();
    return r;
  }

  void dispose() {
    name.dispose(); color.dispose(); quality.dispose(); qty.dispose();
  }
}

class _ItemRowWidget extends StatelessWidget {
  final _ItemRow row;
  final int index;
  final VoidCallback onRemove;
  final bool canRemove;

  const _ItemRowWidget({
    required this.row,
    required this.index,
    required this.onRemove,
    required this.canRemove,
  });

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFD1D5DB)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _kColor, width: 1.5),
        ),
      );

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 28,
              child: Text('$index', style: const TextStyle(fontSize: 12, color: AppTheme.mutedLight, fontWeight: FontWeight.w600)),
            ),
            Expanded(flex: 4, child: Padding(padding: const EdgeInsets.only(right: 4), child: TextField(controller: row.name, style: const TextStyle(fontSize: 12), decoration: _dec('Nombre')))),
            Expanded(flex: 3, child: Padding(padding: const EdgeInsets.only(right: 4), child: TextField(controller: row.color, style: const TextStyle(fontSize: 12), decoration: _dec('Color')))),
            Expanded(flex: 3, child: Padding(padding: const EdgeInsets.only(right: 4), child: TextField(controller: row.quality, style: const TextStyle(fontSize: 12), decoration: _dec('Calidad')))),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: TextField(
                  controller: row.qty,
                  style: const TextStyle(fontSize: 12),
                  keyboardType: TextInputType.number,
                  decoration: _dec('1'),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            SizedBox(
              width: 28,
              child: canRemove
                  ? GestureDetector(
                      onTap: onRemove,
                      child: const Icon(Icons.remove_circle_outline, size: 18, color: Color(0xFFEF4444)),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
}
