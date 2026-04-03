import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/inventory_models.dart';
import '../../domain/models/flower_colors.dart';
import '../../domain/repositories/inventory_repository.dart';

// ── Color del módulo ──────────────────────────────────────────────────────────
const _kColor = Color(0xFF7C3AED);
const _kColorBg = Color(0xFFF5F3FF);
const _kColorBorder = Color(0xFFEDE9FE);

const _kQualities = ['Estándar', 'Campo', 'Primera', 'Premium'];

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _repo = InventoryRepository();
  List<InventoryList> _lists = [];
  bool _loading = true;
  String _filter = 'Todas';

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
      case 'Activas':     return _lists.where((l) => l.isActive && !l.isCompleted).toList();
      case 'Completadas': return _lists.where((l) => l.isCompleted).toList();
      case 'Inactivas':   return _lists.where((l) => !l.isActive).toList();
      default:            return _lists;
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
                Expanded(child: _buildList()),
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
                    border: Border.all(color: active ? _kColor : const Color(0xFFE5E7EB)),
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

  Widget _buildList() {
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
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) => _NoteCard(
          list: items[i],
          onTap: () => _openForm(context, items[i]),
          onShare: () => _shareList(items[i]),
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

  void _shareList(InventoryList list) {
    final buf = StringBuffer();
    buf.writeln('📋 ${list.title}');
    buf.writeln('Fecha: ${DateFormat("d MMMM yyyy", "es").format(list.createdAt)}');
    buf.writeln('─────────────────');
    for (final item in list.items) {
      final parts = <String>[item.productName];
      if (item.color.isNotEmpty) parts.add(item.color);
      if (item.quality.isNotEmpty) parts.add(item.quality);
      buf.writeln('${item.sequenceNumber}. ${parts.join(' · ')} × ${item.quantity}');
    }
    buf.writeln('─────────────────');
    buf.writeln('Total: ${list.itemCount} productos');
    buf.writeln('\nEnviado desde tusflores.app');

    SharePlus.instance.share(ShareParams(text: buf.toString().trim()));
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

// ── Card horizontal de nota ───────────────────────────────────────────────────
class _NoteCard extends StatelessWidget {
  final InventoryList list;
  final VoidCallback onTap;
  final VoidCallback onShare;
  final VoidCallback onToggleActive;
  final VoidCallback onToggleComplete;
  final VoidCallback onDelete;

  const _NoteCard({
    required this.list,
    required this.onTap,
    required this.onShare,
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
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          child: Row(
            children: [
              // Contenido izquierdo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge + fecha
                    Row(
                      children: [
                        _StateBadge(isCompleted: isCompleted, isInactive: isInactive),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat("d MMM yyyy", 'es').format(list.createdAt),
                          style: const TextStyle(fontSize: 11, color: AppTheme.mutedLight),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Título
                    Text(
                      list.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
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
                  ],
                ),
              ),
              // Acciones derecha
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionBtn(
                    icon: Icons.share_outlined,
                    color: const Color(0xFF3B82F6),
                    onTap: onShare,
                    size: 22,
                  ),
                  const SizedBox(height: 6),
                  _ActionBtn(
                    icon: isCompleted ? Icons.check_circle : Icons.check_circle_outline,
                    color: const Color(0xFF16A34A),
                    onTap: onToggleComplete,
                    size: 22,
                  ),
                  const SizedBox(height: 6),
                  _ActionBtn(
                    icon: list.isActive ? Icons.toggle_on : Icons.toggle_off,
                    color: list.isActive ? _kColor : const Color(0xFFF59E0B),
                    onTap: onToggleActive,
                    size: 22,
                  ),
                  const SizedBox(height: 6),
                  _ActionBtn(
                    icon: Icons.delete_outline,
                    color: Colors.red.shade400,
                    onTap: onDelete,
                    size: 22,
                  ),
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
  final double size;
  const _ActionBtn({required this.icon, required this.color, required this.onTap, this.size = 17});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: size, color: color),
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
  void _removeRow(int i) {
    if (_rows.length > 1) {
      setState(() {
        _rows[i].dispose();
        _rows.removeAt(i);
      });
    }
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim().isEmpty ? widget.initialTitle : _titleCtrl.text.trim();
    final validRows = _rows.where((r) => r.name.text.trim().isNotEmpty).toList();
    if (validRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un producto')),
      );
      return;
    }

    // Ordenar alfabéticamente
    validRows.sort((a, b) => a.name.text.trim().toLowerCase().compareTo(b.name.text.trim().toLowerCase()));

    final items = validRows.asMap().entries.map((e) => InventoryItem(
          listId: widget.listId ?? '',
          sequenceNumber: e.key + 1,
          productName: e.value.name.text.trim(),
          color: e.value.color.text.trim(),
          quality: e.value.selectedQuality ?? '',
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
                  // Título — línea simple
                  TextField(
                    controller: _titleCtrl,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                    decoration: InputDecoration(
                      hintText: widget.initialTitle,
                      hintStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.mutedLight.withValues(alpha: 0.4)),
                      border: InputBorder.none,
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: _kColor, width: 2),
                      ),
                      contentPadding: const EdgeInsets.only(bottom: 8),
                    ),
                  ),
                  const SizedBox(height: 24),
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
          SizedBox(width: 24, child: Text('#', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.mutedLight))),
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
  String? selectedQuality;
  final TextEditingController qty = TextEditingController(text: '1');

  _ItemRow();

  factory _ItemRow.from(InventoryItem item) {
    final r = _ItemRow();
    r.name.text = item.productName;
    r.color.text = item.color;
    r.selectedQuality = _kQualities.contains(item.quality) ? item.quality : (item.quality.isNotEmpty ? item.quality : null);
    r.qty.text = item.quantity.toString();
    return r;
  }

  void dispose() {
    name.dispose();
    color.dispose();
    qty.dispose();
  }
}

class _ItemRowWidget extends StatefulWidget {
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

  @override
  State<_ItemRowWidget> createState() => _ItemRowWidgetState();
}

class _ItemRowWidgetState extends State<_ItemRowWidget> {
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
              width: 24,
              child: Text('${widget.index}', style: const TextStyle(fontSize: 12, color: AppTheme.mutedLight, fontWeight: FontWeight.w600)),
            ),
            // Producto
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: TextField(
                  controller: widget.row.name,
                  style: const TextStyle(fontSize: 12),
                  decoration: _dec('Nombre'),
                ),
              ),
            ),
            // Color — con autocompletado
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Autocomplete<String>(
                  initialValue: TextEditingValue(text: widget.row.color.text),
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
                    final q = textEditingValue.text.toLowerCase();
                    return kFlowerColors.where((c) => c.toLowerCase().contains(q));
                  },
                  onSelected: (val) => widget.row.color.text = val,
                  fieldViewBuilder: (context, ctrl, focusNode, onFieldSubmitted) {
                    // Sincronizar controlador externo
                    ctrl.addListener(() => widget.row.color.text = ctrl.text);
                    return TextField(
                      controller: ctrl,
                      focusNode: focusNode,
                      style: const TextStyle(fontSize: 12),
                      decoration: _dec('Color'),
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(10),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 180, maxWidth: 180),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (_, i) {
                              final opt = options.elementAt(i);
                              return ListTile(
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                title: Text(opt, style: const TextStyle(fontSize: 12)),
                                onTap: () => onSelected(opt),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // Calidad — dropdown
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Container(
                  height: 34,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: widget.row.selectedQuality,
                      hint: const Text('Calidad', style: TextStyle(fontSize: 12, color: Color(0xFFD1D5DB))),
                      isExpanded: true,
                      isDense: true,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textLight),
                      icon: const Icon(Icons.expand_more, size: 16, color: AppTheme.mutedLight),
                      items: _kQualities.map((q) => DropdownMenuItem(value: q, child: Text(q))).toList(),
                      onChanged: (val) => setState(() => widget.row.selectedQuality = val),
                    ),
                  ),
                ),
              ),
            ),
            // Cantidad
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: TextField(
                  controller: widget.row.qty,
                  style: const TextStyle(fontSize: 12),
                  keyboardType: TextInputType.number,
                  decoration: _dec('1'),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            // Eliminar fila
            SizedBox(
              width: 28,
              child: widget.canRemove
                  ? GestureDetector(
                      onTap: widget.onRemove,
                      child: const Icon(Icons.remove_circle_outline, size: 18, color: Color(0xFFEF4444)),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
}
