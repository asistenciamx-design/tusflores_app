import 'package:flutter/material.dart';
import '../../domain/tiendas_repository.dart';

class ProveedorCatalogoScreen extends StatefulWidget {
  final ProveedorTienda proveedor;

  const ProveedorCatalogoScreen({super.key, required this.proveedor});

  @override
  State<ProveedorCatalogoScreen> createState() =>
      _ProveedorCatalogoScreenState();
}

class _ProveedorCatalogoScreenState extends State<ProveedorCatalogoScreen> {
  final _repo = TiendasRepository();
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  String? _error;
  List<ProveedorProductoPublic> _all = [];
  List<ProveedorProductoPublic> _filtered = [];
  List<String> _groups = [];
  String? _selectedGroup;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.getProductosProveedor(widget.proveedor.id);
      final groupSet = <String>{};
      for (final p in list) {
        if (p.categoryGroupName != null && p.categoryGroupName!.isNotEmpty) {
          groupSet.add(p.categoryGroupName!);
        }
      }
      setState(() {
        _all = list;
        _groups = groupSet.toList()..sort();
        _filtered = List.from(list);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _applyFilters() {
    final q = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _query = q;
      _filtered = _all.where((p) {
        if (_selectedGroup != null && p.categoryGroupName != _selectedGroup) {
          return false;
        }
        if (q.isNotEmpty) {
          final haystack =
              '${p.categoryName ?? ''} ${p.subCategoryName ?? ''} ${p.subColorName ?? ''}'
                  .toLowerCase();
          if (!haystack.contains(q)) return false;
        }
        return true;
      }).toList();
    });
  }

  void _selectGroup(String? group) {
    setState(() {
      _selectedGroup = _selectedGroup == group ? null : group;
    });
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8FF),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            if (_groups.length > 1) _buildGroupPills(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildError()
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: _filtered.isEmpty
                              ? _buildEmpty()
                              : _buildProductGrid(),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
            color: const Color(0xFF374151),
          ),
          // Proveedor logo
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF500088).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: widget.proveedor.logoUrl != null
                ? Image.network(
                    widget.proveedor.logoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.storefront_rounded,
                        color: Color(0xFF500088),
                        size: 18),
                  )
                : const Icon(Icons.storefront_rounded,
                    color: Color(0xFF500088), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.proveedor.shopName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B1B21),
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${widget.proveedor.activeCount} productos',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFEFEDF6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: TextField(
          controller: _searchCtrl,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Buscar en catálogo...',
            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            prefixIcon:
                Icon(Icons.search_rounded, color: Colors.grey.shade500),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupPills() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        scrollDirection: Axis.horizontal,
        itemCount: _groups.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final g = _groups[i];
          final selected = _selectedGroup == g;
          return GestureDetector(
            onTap: () => _selectGroup(g),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF500088)
                    : const Color(0xFFEFEDF6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                g,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : const Color(0xFF374151),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade300, size: 48),
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Icon(Icons.local_florist_outlined,
            size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text(
          _query.isNotEmpty || _selectedGroup != null
              ? 'Sin resultados'
              : 'Sin productos disponibles',
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildProductGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: _filtered.length,
      itemBuilder: (_, i) => _ProductCard(producto: _filtered[i]),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProveedorProductoPublic producto;

  const _ProductCard({required this.producto});

  @override
  Widget build(BuildContext context) {
    final img = producto.bestImageUrl;
    final colorHex = producto.subColorHex;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                img != null
                    ? Image.network(
                        img,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(colorHex),
                      )
                    : _placeholder(colorHex),
                // Price badge
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '\$${producto.precio.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B1B21),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Info
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category name
                  Text(
                    producto.categoryName ?? producto.sku,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B1B21),
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (producto.subCategoryName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      producto.subCategoryName!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const Spacer(),
                  // Color dot + variant name
                  if (producto.subColorName != null)
                    Row(
                      children: [
                        if (colorHex != null)
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(right: 5),
                            decoration: BoxDecoration(
                              color: _parseColor(colorHex),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.black12, width: 0.5),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            producto.subColorName!,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  // Cantidad badge
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${producto.cantidad} disponibles',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(String? hex) {
    final color = hex != null ? _parseColor(hex) : const Color(0xFF500088);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.6)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.local_florist_rounded,
          size: 36,
          color: Colors.white.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  static Color _parseColor(String hex) {
    final h = hex.replaceFirst('#', '');
    if (h.length == 6) {
      return Color(int.parse('FF$h', radix: 16));
    }
    return const Color(0xFF500088);
  }
}
