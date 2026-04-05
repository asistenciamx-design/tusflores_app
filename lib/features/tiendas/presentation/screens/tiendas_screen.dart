import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../domain/tiendas_repository.dart';
import 'proveedor_catalogo_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class TiendasScreen extends StatefulWidget {
  const TiendasScreen({super.key});

  @override
  State<TiendasScreen> createState() => _TiendasScreenState();
}

class _TiendasScreenState extends State<TiendasScreen> {
  final _repo = TiendasRepository();
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  String? _error;
  List<ProveedorTienda> _all = [];
  List<ProveedorTienda> _filtered = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.toLowerCase().trim();
      if (q == _query) return;
      setState(() {
        _query = q;
        _filtered = q.isEmpty
            ? List.from(_all)
            : _all
                .where((p) =>
                    p.shopName.toLowerCase().contains(q) ||
                    (p.groupName?.toLowerCase().contains(q) ?? false))
                .toList();
      });
    });
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
      final list = await _repo.getProveedoresActivos();
      setState(() {
        _all = list;
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

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFBF8FF),
      endDrawer: _buildDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            _buildNavBar(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildError()
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: CustomScrollView(
                            slivers: [
                              SliverToBoxAdapter(child: _buildHeader()),
                              _buildGrid(),
                              const SliverToBoxAdapter(
                                  child: SizedBox(height: 32)),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          // Logo
          GestureDetector(
            onTap: () => _openUrl('https://tusflores.app'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFF500088).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.local_florist_rounded,
                      color: Color(0xFF500088), size: 18),
                ),
                const SizedBox(width: 8),
                const Text(
                  'tusflores',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF500088),
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  '.app',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade500,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Hamburger
          GestureDetector(
            onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.menu_rounded,
                  color: Color(0xFF374151), size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF500088).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_florist_rounded,
                        color: Color(0xFF500088), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'tusflores.app',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF500088),
                        ),
                      ),
                      Text(
                        'Directorio floral',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 8),
            _drawerLink(Icons.home_outlined, 'Inicio', () {
              Navigator.pop(context);
              _openUrl('https://tusflores.app');
            }),
            _drawerLink(Icons.auto_awesome_outlined, 'Funciones', () {
              Navigator.pop(context);
              _openUrl('https://tusflores.app#funciones');
            }),
            _drawerLink(Icons.storefront_rounded, 'Tienda', () {
              Navigator.pop(context);
              // Ya estamos en /tiendas
            }, active: true),
            _drawerLink(Icons.photo_library_outlined, 'Galería', () {
              Navigator.pop(context);
              _openUrl('https://tusflores.app/galeria');
            }),
            _drawerLink(Icons.mail_outline_rounded, 'Contacto', () {
              Navigator.pop(context);
              _openUrl('https://tusflores.app#contacto');
            }),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('/login');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Entrar',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerLink(
      IconData icon, String label, VoidCallback onTap,
      {bool active = false}) {
    return ListTile(
      leading: Icon(icon,
          size: 22,
          color: active ? const Color(0xFF500088) : Colors.grey.shade600),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: active ? FontWeight.w700 : FontWeight.w600,
          color: active ? const Color(0xFF500088) : const Color(0xFF374151),
        ),
      ),
      onTap: onTap,
      tileColor: active
          ? const Color(0xFF500088).withValues(alpha: 0.05)
          : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
    );
  }

  void _openUrl(String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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
            ElevatedButton(
                onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF500088).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.storefront_rounded,
                    color: Color(0xFF500088), size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Tienda',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF500088),
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              Icon(Icons.location_on_outlined,
                  color: const Color(0xFF500088).withValues(alpha: 0.7),
                  size: 24),
            ],
          ),
          const SizedBox(height: 16),
          // Search bar
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFEFEDF6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Buscar proveedores o productos...',
                hintStyle:
                    TextStyle(color: Colors.grey.shade500, fontSize: 15),
                prefixIcon:
                    Icon(Icons.search_rounded, color: Colors.grey.shade500),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Section headline
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Proveedores\nSelectos',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B1B21),
                  height: 1.15,
                ),
              ),
              const Spacer(),
              if (_filtered.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF500088).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_filtered.length} ENCONTRADOS',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF500088),
                      letterSpacing: 1,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    if (_filtered.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 80),
          child: Column(
            children: [
              Icon(Icons.storefront_outlined,
                  size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                _query.isEmpty
                    ? 'Aún no hay proveedores activos'
                    : 'Sin resultados para "$_query"',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Construimos una lista de widgets: pares de tarjetas + banner cada 4
    final rows = <Widget>[];
    const gap = 12.0;
    const hPad = 16.0;

    int i = 0;
    bool bannerInserted = false;

    while (i < _filtered.length) {
      // Insertar banner después del 4to proveedor
      if (!bannerInserted && i >= 4) {
        rows.add(Padding(
          padding: const EdgeInsets.fromLTRB(hPad, 0, hPad, gap),
          child: _buildPromoBanner(),
        ));
        bannerInserted = true;
      }

      // Fila de 2 tarjetas
      final left = _filtered[i];
      final right = i + 1 < _filtered.length ? _filtered[i + 1] : null;

      rows.add(Padding(
        padding: const EdgeInsets.fromLTRB(hPad, 0, hPad, gap),
        child: Row(
          children: [
            Expanded(child: _buildCard(left)),
            const SizedBox(width: gap),
            Expanded(
              child: right != null
                  ? _buildCard(right)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ));

      i += 2;
    }

    return SliverList(
      delegate: SliverChildListDelegate(rows),
    );
  }

  Widget _buildCard(ProveedorTienda p) {
    final groupColor = _groupColor(p.groupName);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProveedorCatalogoScreen(proveedor: p),
        ),
      ),
      child: AspectRatio(
      aspectRatio: 4 / 5,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Fondo
            p.logoUrl != null
                ? Image.network(
                    p.logoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _gradientBg(),
                  )
                : _gradientBg(),
            // Overlay gradiente
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC000000)],
                  stops: [0.4, 1.0],
                ),
              ),
            ),
            // Badge grupo
            if (p.groupName != null)
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: groupColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    p.groupName!.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            // Info inferior
            Positioned(
              left: 12,
              right: 12,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    p.shopName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.bolt_rounded,
                          size: 12, color: Color(0xFF92F5A4)),
                      const SizedBox(width: 3),
                      Text(
                        '${p.activeCount} ACTIVOS',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildPromoBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: 180,
        color: const Color(0xFF500088),
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'DIRECTORIO FLORAL',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF92F5A4),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Encuentra el proveedor ideal',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Conecta tu florería con los mejores proveedores de México.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white60,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF92F5A4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'EXPLORAR',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF00210A),
                            letterSpacing: 1,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded,
                            size: 12, color: Color(0xFF00210A)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.local_florist_rounded,
              size: 72,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gradientBg() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6B21A8), Color(0xFF3B0764)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.local_florist_rounded,
          size: 48,
          color: Colors.white.withValues(alpha: 0.15),
        ),
      ),
    );
  }

  Color _groupColor(String? group) {
    if (group == null) return const Color(0xFF500088);
    final g = group.toLowerCase();
    if (g.contains('flor')) return const Color(0xFF006D30);
    if (g.contains('follaj')) return const Color(0xFF2D6A4F);
    if (g.contains('florero') || g.contains('recipiente')) {
      return const Color(0xFF5A2500);
    }
    if (g.contains('espuma') || g.contains('insumo')) {
      return const Color(0xFF374151);
    }
    if (g.contains('cerám') || g.contains('ceram')) {
      return const Color(0xFF92400E);
    }
    return const Color(0xFF500088);
  }
}
