import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/models/proveedor_models.dart';
import '../../domain/repositories/proveedor_repository.dart';
import 'proveedor_maestro_screen.dart';
import 'proveedor_edit_producto_screen.dart';

class ProveedorInventoryScreen extends StatefulWidget {
  const ProveedorInventoryScreen({super.key});

  @override
  State<ProveedorInventoryScreen> createState() =>
      _ProveedorInventoryScreenState();
}

class _ProveedorInventoryScreenState extends State<ProveedorInventoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _repo = ProveedorRepository();

  bool _loadingMios = true;
  String? _errorMios;
  List<ProveedorProducto> _mios = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMios();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMios() async {
    setState(() {
      _loadingMios = true;
      _errorMios = null;
    });
    try {
      final list = await _repo.getMisProductos();
      setState(() {
        _mios = list;
        _loadingMios = false;
      });
    } catch (e) {
      setState(() {
        _errorMios = e.toString();
        _loadingMios = false;
      });
    }
  }

  Future<void> _deleteProducto(ProveedorProducto p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitar producto'),
        content: Text(
            '¿Quitar "${p.displayName}" de tu catálogo? No se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _repo.removeProducto(p.id);
      _loadMios();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _togglePause(ProveedorProducto p) async {
    try {
      await _repo.togglePause(id: p.id, isPaused: !p.isPaused);
      _loadMios();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  void _shareProducto(ProveedorProducto p) {
    final lines = <String>[
      p.displayName,
      'SKU: ${p.sku}',
      if (p.precio != null) 'Precio: \$${p.precio!.toStringAsFixed(2)}',
      if (p.cantidad > 0) 'Disponible: ${p.cantidad} uds',
      if (p.calidad != null) 'Calidad: ${p.calidad}',
      if (p.presentacion != null) 'Presentación: ${p.presentacion}',
    ];
    Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Producto copiado al portapapeles'),
        backgroundColor: Color(0xFF059669),
        duration: Duration(seconds: 2),
      ));
    }
  }

  Future<void> _openEdit(ProveedorProducto p) async {
    final refreshed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProveedorEditProductoScreen(producto: p),
      ),
    );
    if (refreshed == true) _loadMios();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab bar
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF500088),
            unselectedLabelColor: Colors.grey.shade500,
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            indicatorColor: const Color(0xFF500088),
            indicatorWeight: 2.5,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Mi Catálogo'),
                    if (_mios.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF500088).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_mios.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF500088),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Tab(text: 'Maestro'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _MiCatalogoTab(
                loading: _loadingMios,
                error: _errorMios,
                productos: _mios,
                onRefresh: _loadMios,
                onEdit: _openEdit,
                onDelete: _deleteProducto,
                onTogglePause: _togglePause,
                onShare: _shareProducto,
                onGoToMaestro: () => _tabController.animateTo(1),
              ),
              const ProveedorMaestroScreen(),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Mi Catálogo tab ───────────────────────────────────────────────────────────

class _MiCatalogoTab extends StatelessWidget {
  final bool loading;
  final String? error;
  final List<ProveedorProducto> productos;
  final VoidCallback onRefresh;
  final Future<void> Function(ProveedorProducto) onEdit;
  final Future<void> Function(ProveedorProducto) onDelete;
  final Future<void> Function(ProveedorProducto) onTogglePause;
  final void Function(ProveedorProducto) onShare;
  final VoidCallback onGoToMaestro;

  const _MiCatalogoTab({
    required this.loading,
    required this.error,
    required this.productos,
    required this.onRefresh,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePause,
    required this.onShare,
    required this.onGoToMaestro,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRefresh, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (productos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Tu catálogo está vacío',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Agrega productos desde el Maestro',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onGoToMaestro,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ir al Maestro'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF500088),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: productos.length,
        itemBuilder: (_, i) => _ProductoCard(
          producto: productos[i],
          onEdit: () => onEdit(productos[i]),
          onDelete: () => onDelete(productos[i]),
          onTogglePause: () => onTogglePause(productos[i]),
          onShare: () => onShare(productos[i]),
        ),
      ),
    );
  }
}

class _ProductoCard extends StatefulWidget {
  final ProveedorProducto producto;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTogglePause;
  final VoidCallback? onShare;

  const _ProductoCard({
    required this.producto,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePause,
    this.onShare,
  });

  @override
  State<_ProductoCard> createState() => _ProductoCardState();
}

class _ProductoCardState extends State<_ProductoCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.producto;
    final hasLowStock = p.cantidad > 0 && p.cantidad <= 5;
    final imgUrl = p.bestImageUrl;
    // Listo para público: tiene precio y cantidad > 0
    final isReady = p.precio != null && p.cantidad > 0;
    final needsData = !isReady && !p.isPaused;

    return Opacity(
      opacity: p.isPaused ? 0.55 : 1.0,
      child: GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: p.isPaused
                ? Colors.grey.shade50
                : isReady
                    ? const Color(0xFFF0FFF4) // verde suave
                    : const Color(0xFFFFF8F0), // naranja suave
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: p.isPaused
                  ? Colors.grey.shade300
                  : isReady
                      ? const Color(0xFF22C55E).withValues(alpha: 0.4)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.4),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: p.isPaused
                    ? Colors.black.withValues(alpha: 0.03)
                    : isReady
                        ? const Color(0xFF22C55E).withValues(alpha: 0.10)
                        : const Color(0xFFF59E0B).withValues(alpha: 0.10),
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
                // ── Row principal: thumbnail + info ─────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: imgUrl != null
                          ? Image.network(
                              imgUrl,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _imgPlaceholder(),
                            )
                          : _imgPlaceholder(),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.displayName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F2937),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            p.sku,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (p.isPaused)
                                _Chip(
                                  label: 'Pausado',
                                  color: Colors.orange.shade800,
                                  bg: Colors.orange.shade50,
                                )
                              else if (p.precio != null)
                                _Chip(
                                  label:
                                      '\$${p.precio!.toStringAsFixed(2)}',
                                  color: Colors.green.shade700,
                                  bg: Colors.green.shade50,
                                )
                              else
                                _Chip(
                                  label: 'Sin precio',
                                  color: Colors.orange.shade700,
                                  bg: Colors.orange.shade50,
                                ),
                              _Chip(
                                label: '${p.cantidad} uds',
                                color: hasLowStock
                                    ? Colors.orange.shade700
                                    : Colors.grey.shade700,
                                bg: hasLowStock
                                    ? Colors.orange.shade50
                                    : Colors.grey.shade100,
                              ),
                              if (p.presentacion != null)
                                _Chip(
                                  label: p.presentacion!,
                                  color: const Color(0xFF500088),
                                  bg: const Color(0xFF500088)
                                      .withValues(alpha: 0.08),
                                ),
                              if (p.calidad != null)
                                _Chip(
                                  label: p.calidad!,
                                  color: Colors.teal.shade700,
                                  bg: Colors.teal.shade50,
                                ),
                            ],
                          ),
                          if (needsData) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.info_outline_rounded,
                                    size: 12,
                                    color: Colors.orange.shade700),
                                const SizedBox(width: 4),
                                Text(
                                  p.precio == null && p.cantidad == 0
                                      ? 'Falta precio y cantidad'
                                      : p.precio == null
                                          ? 'Falta precio'
                                          : 'Falta cantidad',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ] else if (hasLowStock && !p.isPaused) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    size: 12,
                                    color: Colors.orange.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  'Stock bajo',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange.shade600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Status dot + chevron
                    Column(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: p.isPaused
                                ? Colors.grey.shade400
                                : isReady
                                    ? const Color(0xFF22C55E)
                                    : const Color(0xFFF59E0B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: Color(0xFFBDBDBD),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // ── Expandable action buttons ──────────────────────────
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: _expanded
                      ? Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            children: [
                              _cardAction(
                                icon: p.isPaused
                                    ? Icons.play_circle_outline_rounded
                                    : Icons.pause_circle_outline_rounded,
                                label: p.isPaused ? 'Reanudar' : 'Pausar',
                                color: p.isPaused
                                    ? const Color(0xFF2E7D52)
                                    : Colors.orange.shade800,
                                bgColor: p.isPaused
                                    ? const Color(0xFFE6F4ED)
                                    : Colors.orange.shade50,
                                onTap: widget.onTogglePause,
                              ),
                              const SizedBox(width: 7),
                              _cardAction(
                                icon: Icons.edit_outlined,
                                label: 'Editar',
                                color: const Color(0xFF500088),
                                bgColor: const Color(0xFFF0EAFA),
                                onTap: widget.onEdit,
                              ),
                              const SizedBox(width: 7),
                              _cardAction(
                                icon: Icons.ios_share_rounded,
                                label: 'Compartir',
                                color: const Color(0xFF1565C0),
                                bgColor: const Color(0xFFE3F0FD),
                                onTap: widget.onShare ?? () {},
                              ),
                              const SizedBox(width: 7),
                              _cardAction(
                                icon: Icons.delete_outline_rounded,
                                label: 'Eliminar',
                                color: Colors.red.shade700,
                                bgColor: Colors.red.shade50,
                                onTap: widget.onDelete,
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cardAction({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 19),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imgPlaceholder() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.local_florist_rounded,
          color: Colors.grey.shade400, size: 28),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;

  const _Chip({
    required this.label,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
