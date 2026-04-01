import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'proveedor_dashboard_screen.dart';

class ProveedorLayout extends StatefulWidget {
  const ProveedorLayout({super.key});

  @override
  State<ProveedorLayout> createState() => _ProveedorLayoutState();
}

class _ProveedorLayoutState extends State<ProveedorLayout> {
  int _currentIndex = 0;
  String _shopName = '';
  bool _isShopOwner = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('shop_name, role')
          .eq('id', user.id)
          .maybeSingle();
      if (mounted && row != null) {
        setState(() {
          _shopName = row['shop_name'] as String? ?? '';
          _isShopOwner = (row['role'] as String?) == 'shop_owner';
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBF8FF),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            const Icon(Icons.local_florist_rounded,
                color: Color(0xFF500088), size: 24),
            const SizedBox(width: 8),
            Text(
              _shopName.isNotEmpty ? _shopName : 'Proveedor',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF500088),
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          if (_isShopOwner)
            GestureDetector(
              onTap: () => context.go('/'),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2BEE79).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF2BEE79).withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.storefront_rounded, size: 13, color: Color(0xFF059669)),
                    SizedBox(width: 4),
                    Text(
                      'Florería',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF6B21A8).withValues(alpha: 0.1),
              child: const Icon(Icons.person_rounded,
                  color: Color(0xFF6B21A8), size: 20),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          ProveedorDashboardScreen(),
          _PlaceholderTab(icon: Icons.shopping_bag_rounded, label: 'Pedidos'),
          _PlaceholderTab(icon: Icons.inventory_2_rounded, label: 'Inventario'),
          _PlaceholderTab(icon: Icons.groups_rounded, label: 'CRM'),
          _PlaceholderTab(icon: Icons.account_circle_rounded, label: 'Perfil'),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: const Color(0xFF500088),
            unselectedItemColor: Colors.grey.shade500,
            selectedLabelStyle: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3),
            unselectedLabelStyle: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.3),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_rounded),
                label: 'INICIO',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.shopping_bag_outlined),
                label: 'PEDIDOS',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.inventory_2_outlined),
                label: 'INVENTARIO',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.groups_outlined),
                label: 'CRM',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.account_circle_outlined),
                label: 'PERFIL',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Tab placeholder para secciones aún no implementadas
class _PlaceholderTab extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PlaceholderTab({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(label,
            style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade400)),
          const SizedBox(height: 4),
          Text('Proximamente',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        ],
      ),
    );
  }
}
