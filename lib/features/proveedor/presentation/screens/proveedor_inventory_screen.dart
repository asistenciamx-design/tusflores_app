import 'package:flutter/material.dart';
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
  final VoidCallback onGoToMaestro;

  const _MiCatalogoTab({
    required this.loading,
    required this.error,
    required this.productos,
    required this.onRefresh,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePause,
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
        ),
      ),
    );
  }
}

class _ProductoCard extends StatelessWidget {
  final ProveedorProducto producto;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTogglePause;

  const _ProductoCard({
    required this.producto,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePause,
  });

  @override
  Widget build(BuildContext context) {
    final p = producto;
    final hasLowStock = p.cantidad > 0 && p.cantidad <= 5;
    final imgUrl = p.bestImageUrl;

    return Opacity(
      opacity: p.isPaused ? 0.55 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: p.isPaused
                ? Colors.grey.shade300
                : hasLowStock
                    ? Colors.orange.shade200
                    : p.isActive
                        ? Colors.green.shade100
                        : Colors.grey.shade200,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail: mejor imagen disponible
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: imgUrl != null
                      ? Image.network(
                          imgUrl,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imgPlaceholder(),
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
                              label: '\$${p.precio!.toStringAsFixed(2)}',
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
                      if (hasLowStock && !p.isPaused) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                size: 12, color: Colors.orange.shade600),
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
                // Actions
                Column(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: p.isPaused
                            ? Colors.orange.shade400
                            : p.isActive
                                ? Colors.green.shade400
                                : Colors.grey.shade300,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Pause/resume
                    IconButton(
                      icon: Icon(
                        p.isPaused
                            ? Icons.play_circle_outline_rounded
                            : Icons.pause_circle_outline_rounded,
                        size: 20,
                      ),
                      color: p.isPaused
                          ? Colors.green.shade600
                          : Colors.orange.shade600,
                      onPressed: onTogglePause,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                          minWidth: 32, minHeight: 32),
                      tooltip: p.isPaused ? 'Reanudar' : 'Pausar',
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      color: const Color(0xFF500088),
                      onPressed: onEdit,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                          minWidth: 32, minHeight: 32),
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.delete_outline_rounded, size: 18),
                      color: Colors.red.shade400,
                      onPressed: onDelete,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                          minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _imgPlaceholder() {
    return Container(
      width: 64,
      height: 64,
      color: Colors.grey.shade100,
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
