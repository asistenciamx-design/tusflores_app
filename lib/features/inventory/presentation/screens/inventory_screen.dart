import 'dart:math';
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
        existingFolio: existing?.folio,
        repo: _repo,
      ),
    );
    if (result == true) _load();
  }

  void _shareList(InventoryList list) {
    final buf = StringBuffer();
    buf.writeln('📋 ${list.title}');
    if (list.folio != null) buf.writeln('Folio: ${list.folio}');
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

// ── Card de nota ──────────────────────────────────────────────────────────────
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
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fila superior: badge, fecha, folio
              Row(
                children: [
                  _StateBadge(isCompleted: isCompleted, isInactive: isInactive),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat("d MMM yyyy", 'es').format(list.createdAt),
                    style: const TextStyle(fontSize: 11, color: AppTheme.mutedLight),
                  ),
                  const Spacer(),
                  if (list.folio != null)
                    Text(
                      'Folio: ${list.folio}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _kColor,
                      ),
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
              // Cantidad de productos
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
              const SizedBox(height: 10),
              const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
              const SizedBox(height: 8),
              // Fila de acciones en la parte inferior
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _ActionBtn(
                    icon: Icons.share_outlined,
                    label: 'Compartir',
                    color: const Color(0xFF3B82F6),
                    onTap: onShare,
                  ),
                  _ActionBtn(
                    icon: isCompleted ? Icons.check_circle : Icons.check_circle_outline,
                    label: isCompleted ? 'Completada' : 'Completar',
                    color: const Color(0xFF16A34A),
                    onTap: onToggleComplete,
                  ),
                  _ActionBtn(
                    icon: list.isActive ? Icons.toggle_on : Icons.toggle_off,
                    label: list.isActive ? 'Activa' : 'Pausada',
                    color: list.isActive ? _kColor : const Color(0xFFF59E0B),
                    onTap: onToggleActive,
                  ),
                  _ActionBtn(
                    icon: Icons.delete_outline,
                    label: 'Eliminar',
                    color: Colors.red.shade400,
                    onTap: onDelete,
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
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
}

// ── Datos de un producto ya agregado ─────────────────────────────────────────
class _SubmittedItem {
  final String name;
  final String color;
  final String quality;
  final int qty;

  const _SubmittedItem({
    required this.name,
    this.color = '',
    this.quality = '',
    this.qty = 1,
  });
}

// ── Modal: Crear / Editar lista ───────────────────────────────────────────────
class _ListFormSheet extends StatefulWidget {
  final String initialTitle;
  final List<InventoryItem> initialItems;
  final String? listId;
  final int? existingFolio;
  final InventoryRepository repo;

  const _ListFormSheet({
    required this.initialTitle,
    required this.initialItems,
    this.listId,
    this.existingFolio,
    required this.repo,
  });

  @override
  State<_ListFormSheet> createState() => _ListFormSheetState();
}

class _ListFormSheetState extends State<_ListFormSheet> {
  late TextEditingController _titleCtrl;
  late int _folio;

  // Productos ya agregados
  final List<_SubmittedItem> _items = [];

  // Formulario de entrada actual
  final _nameCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  String? _selectedQuality;
  int _qty = 1;
  Key _colorKey = UniqueKey();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialTitle);
    _folio = widget.existingFolio ?? (Random().nextInt(90000) + 10000);
    _items.addAll(widget.initialItems.map((i) => _SubmittedItem(
          name: i.productName,
          color: i.color,
          quality: i.quality,
          qty: i.quantity,
        )));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _nameCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  Future<void> _openNumericKeypad(BuildContext context) async {
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => NumericKeypad(initialValue: _qty),
    );
    if (result != null) setState(() => _qty = result);
  }

  void _addProduct() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe el nombre del producto')),
      );
      return;
    }
    setState(() {
      _items.add(_SubmittedItem(
        name: name,
        color: _colorCtrl.text.trim(),
        quality: _selectedQuality ?? '',
        qty: _qty,
      ));
      _nameCtrl.clear();
      _colorCtrl.clear();
      _colorKey = UniqueKey();
      _selectedQuality = null;
      _qty = 1;
    });
  }

  Future<void> _save() async {
    // Auto-agregar si hay algo escrito en el formulario actual
    if (_nameCtrl.text.trim().isNotEmpty) _addProduct();

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un producto')),
      );
      return;
    }

    final title = _titleCtrl.text.trim().isEmpty ? widget.initialTitle : _titleCtrl.text.trim();
    final items = _items.asMap().entries.map((e) => InventoryItem(
          listId: widget.listId ?? '',
          sequenceNumber: e.key + 1,
          productName: e.value.name,
          color: e.value.color,
          quality: e.value.quality,
          quantity: e.value.qty,
        )).toList();

    setState(() => _saving = true);
    try {
      if (widget.listId == null) {
        await widget.repo.createList(title: title, items: items, folio: _folio);
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

  InputDecoration _fieldDec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFD1D5DB)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kColor, width: 1.5),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.listId != null;
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.97,
      minChildSize: 0.5,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF9FAFB),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            // Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: _kColorBg, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.inventory_2_outlined, color: _kColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          isEdit ? 'Editar lista' : 'Nueva lista',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Folio: $_folio',
                          style: const TextStyle(fontSize: 12, color: _kColor, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppTheme.mutedLight),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Body
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(16),
                children: [
                  // Título de la nota
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: TextField(
                      controller: _titleCtrl,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                      decoration: InputDecoration(
                        hintText: widget.initialTitle,
                        hintStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.mutedLight.withValues(alpha: 0.4)),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Formulario de entrada de producto ─────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _kColorBorder),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nombre del producto
                        const Text('Nombre del producto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.mutedLight)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _nameCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: _fieldDec('Ej. Rosas, Girasoles, Lilis...'),
                        ),
                        const SizedBox(height: 14),

                        // Color (fila completa)
                        const Text('Color', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.mutedLight)),
                        const SizedBox(height: 6),
                        Autocomplete<String>(
                          key: _colorKey,
                          optionsBuilder: (textEditingValue) {
                            if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
                            final q = textEditingValue.text.toLowerCase();
                            // Primero los que empiezan con la búsqueda, luego los que contienen
                            final starts = <String>[];
                            final contains = <String>[];
                            final seen = <String>{};
                            for (final c in kFlowerColors) {
                              final lower = c.toLowerCase();
                              if (seen.contains(lower)) continue;
                              seen.add(lower);
                              if (lower.startsWith(q)) {
                                starts.add(c);
                              } else if (lower.contains(q)) {
                                contains.add(c);
                              }
                            }
                            return [...starts, ...contains];
                          },
                          onSelected: (val) => setState(() => _colorCtrl.text = val),
                          fieldViewBuilder: (context, ctrl, focusNode, onFieldSubmitted) {
                            ctrl.addListener(() => _colorCtrl.text = ctrl.text);
                            return TextField(
                              controller: ctrl,
                              focusNode: focusNode,
                              decoration: _fieldDec('Ej. Rojo, Blanco...'),
                            );
                          },
                          optionsViewBuilder: (context, onSelected, options) => Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 8,
                              borderRadius: BorderRadius.circular(10),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 160, maxWidth: 260),
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  itemBuilder: (_, i) {
                                    final opt = options.elementAt(i);
                                    return ListTile(
                                      dense: true,
                                      visualDensity: VisualDensity.compact,
                                      title: Text(opt, style: const TextStyle(fontSize: 13)),
                                      onTap: () => onSelected(opt),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Calidad + Cantidad (misma fila)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Calidad
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Calidad', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.mutedLight)),
                                  const SizedBox(height: 6),
                                  Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE5E7EB)),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _selectedQuality,
                                        hint: const Text('Selecciona', style: TextStyle(fontSize: 13, color: Color(0xFFD1D5DB))),
                                        isExpanded: true,
                                        isDense: false,
                                        style: const TextStyle(fontSize: 13, color: AppTheme.textLight),
                                        icon: const Icon(Icons.expand_more, size: 18, color: AppTheme.mutedLight),
                                        items: _kQualities.map((q) => DropdownMenuItem(value: q, child: Text(q))).toList(),
                                        onChanged: (val) => setState(() => _selectedQuality = val),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Cantidad
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Cantidad', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.mutedLight)),
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: () => _openNumericKeypad(context),
                                  child: Container(
                                    height: 48,
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: _kColorBg,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: _kColorBorder),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.dialpad, size: 16, color: _kColor),
                                        const SizedBox(width: 8),
                                        Text(
                                          '$_qty',
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Botón agregar
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: OutlinedButton.icon(
                            onPressed: _addProduct,
                            icon: const Icon(Icons.add, color: _kColor, size: 18),
                            label: const Text('Agregar producto', style: TextStyle(color: _kColor, fontWeight: FontWeight.w700)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: _kColor, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Lista de productos agregados ───────────────────────────
                  if (_items.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Productos', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textLight)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: _kColorBg, borderRadius: BorderRadius.circular(10)),
                          child: Text('${_items.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _kColor)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._items.asMap().entries.map((e) => _SubmittedItemTile(
                          item: e.value,
                          index: e.key + 1,
                          onRemove: () => setState(() => _items.removeAt(e.key)),
                        )),
                  ],

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

// ── Producto agregado (tile de la lista) ──────────────────────────────────────
class _SubmittedItemTile extends StatelessWidget {
  final _SubmittedItem item;
  final int index;
  final VoidCallback onRemove;

  const _SubmittedItemTile({
    required this.item,
    required this.index,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (item.color.isNotEmpty) item.color,
      if (item.quality.isNotEmpty) item.quality,
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: _kColorBg, shape: BoxShape.circle),
            child: Text('$index', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _kColor)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textLight)),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.mutedLight)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: _kColorBg, borderRadius: BorderRadius.circular(8)),
            child: Text('×${item.qty}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _kColor)),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.remove_circle_outline, size: 20, color: Color(0xFFEF4444)),
          ),
        ],
      ),
    );
  }
}

// ── Teclado numérico grande reutilizable ─────────────────────────────────────
class NumericKeypad extends StatefulWidget {
  final int initialValue;
  final Color accentColor;

  const NumericKeypad({
    super.key,
    this.initialValue = 1,
    this.accentColor = _kColor,
  });

  @override
  State<NumericKeypad> createState() => _NumericKeypadState();
}

class _NumericKeypadState extends State<NumericKeypad> {
  late String _display;

  @override
  void initState() {
    super.initState();
    _display = widget.initialValue > 0 ? '${widget.initialValue}' : '';
  }

  void _onDigit(String digit) {
    setState(() {
      if (_display == '0') {
        _display = digit;
      } else if (_display.length < 5) {
        _display += digit;
      }
    });
  }

  void _onDoubleZero() {
    if (_display.isNotEmpty && _display != '0' && _display.length < 4) {
      setState(() => _display += '00');
    }
  }

  void _onBackspace() {
    if (_display.isNotEmpty) {
      setState(() => _display = _display.substring(0, _display.length - 1));
    }
  }

  void _onSave() {
    final value = int.tryParse(_display) ?? 0;
    Navigator.pop(context, value < 1 ? 1 : value);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFEDE9FE),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: Cancelar, display, Guardar
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textLight)),
                  ),
                  Expanded(
                    child: Text(
                      _display.isEmpty ? '0' : _display,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: widget.accentColor,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _onSave,
                    child: const Text('Guardar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textLight)),
                  ),
                ],
              ),
            ),
            // Keypad grid
            ..._buildRows(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRows() {
    final rows = [
      ['7', '8', '9'],
      ['4', '5', '6'],
      ['1', '2', '3'],
      ['00', '0', '⌫'],
    ];
    return rows.map((row) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: row.map((key) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: _KeypadButton(
              label: key,
              onTap: () {
                if (key == '⌫') {
                  _onBackspace();
                } else if (key == '00') {
                  _onDoubleZero();
                } else {
                  _onDigit(key);
                }
              },
              isBackspace: key == '⌫',
            ),
          ),
        )).toList(),
      ),
    )).toList();
  }
}

class _KeypadButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isBackspace;

  const _KeypadButton({
    required this.label,
    required this.onTap,
    this.isBackspace = false,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            height: 64,
            alignment: Alignment.center,
            child: isBackspace
                ? const Icon(Icons.backspace_outlined, size: 26, color: AppTheme.textLight)
                : Text(
                    label,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textLight,
                    ),
                  ),
          ),
        ),
      );
}
