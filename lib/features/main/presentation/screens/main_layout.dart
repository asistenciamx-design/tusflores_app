import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/currency_cache.dart';
import '../../../../core/utils/responsive.dart';
import '../../../dashboard/presentation/screens/dashboard_screen.dart';
import '../../../catalog/presentation/screens/catalog_screen.dart';
import '../../../orders/presentation/screens/orders_screen.dart';
import '../../../orders/domain/models/order_model.dart';
import '../../../profile/presentation/screens/main_profile_settings_screen.dart';
import '../../../crm/presentation/screens/crm_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  // ── Realtime ──────────────────────────────────────────────────────────────
  RealtimeChannel? _ordersChannel;

  // ── Overlay banner ────────────────────────────────────────────────────────
  OverlayEntry? _bannerEntry;
  late AnimationController _bannerController;

  // ── OrdersScreen key — lets us call resetToToday() from the banner ────────
  final _ordersKey = GlobalKey<OrdersScreenState>();
  late final OrdersScreen _ordersScreen = OrdersScreen(key: _ordersKey);

  List<Widget> get _screens => [
        DashboardScreen(
          onNavigateToOrders: () => setState(() => _currentIndex = 2),
          onNavigateToCatalog: () => setState(() => _currentIndex = 1),
        ),
        const CatalogScreen(),
        _ordersScreen,
        const CrmScreen(),
        const MainProfileSettingsScreen(),
      ];

  static const _sidebarItems = [
    AppSidebarItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'Inicio',
    ),
    AppSidebarItem(
      icon: Icons.local_florist_outlined,
      activeIcon: Icons.local_florist,
      label: 'Catálogo',
    ),
    AppSidebarItem(
      icon: Icons.shopping_bag_outlined,
      activeIcon: Icons.shopping_bag,
      label: 'Pedidos',
    ),
    AppSidebarItem(
      icon: Icons.group_outlined,
      activeIcon: Icons.group,
      label: 'CRM',
    ),
    AppSidebarItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: 'Perfil',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _bannerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startRealtimeSubscription();
    });
  }

  @override
  void dispose() {
    _bannerEntry?.remove();
    _bannerEntry = null;
    _bannerController.dispose();
    if (_ordersChannel != null) {
      Supabase.instance.client.removeChannel(_ordersChannel!);
    }
    super.dispose();
  }

  // ── Realtime subscription ─────────────────────────────────────────────────

  void _startRealtimeSubscription() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final shopId = user.id;

    _ordersChannel = Supabase.instance.client
        .channel('main_layout_orders_$shopId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'shop_id',
            value: shopId,
          ),
          callback: (payload) {
            try {
              final newOrder = OrderModel.fromJson(
                  payload.newRecord as Map<String, dynamic>);
              if (!mounted) return;
              if (_currentIndex != 2) {
                _showNewOrderBanner(newOrder);
              }
            } catch (e) {}
          },
        )
        .subscribe();
  }

  // ── Banner ────────────────────────────────────────────────────────────────

  void _showNewOrderBanner(OrderModel order) {
    _dismissBannerImmediately();

    final slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _bannerController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _bannerEntry = OverlayEntry(
      builder: (ctx) {
        final topPadding = MediaQuery.of(ctx).padding.top;
        return Positioned(
          top: topPadding + 12,
          left: 16,
          right: 16,
          child: SlideTransition(
            position: slide,
            child: _NewOrderBanner(
              order: order,
              onTap: () {
                _dismissBanner();
                setState(() => _currentIndex = 2);
                // Forzar filtro "Hoy" para que el nuevo pedido sea visible
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _ordersKey.currentState?.resetToToday();
                });
              },
              onDismiss: _dismissBanner,
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_bannerEntry!);
    _bannerController.forward(from: 0);
  }

  void _dismissBanner() {
    if (_bannerEntry == null || !mounted) return;
    _bannerController.reverse().then((_) {
      _bannerEntry?.remove();
      _bannerEntry = null;
    });
  }

  void _dismissBannerImmediately() {
    _bannerEntry?.remove();
    _bannerEntry = null;
    _bannerController.reset();
  }

  void _onNavTap(int index) {
    setState(() => _currentIndex = index);
    if (index == 2) _dismissBanner();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: _MobileLayout(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
        screen: _screens[_currentIndex],
      ),
      desktop: _WideLayout(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
        screen: _screens[_currentIndex],
        items: _sidebarItems,
      ),
    );
  }
}

// ── Mobile layout: bottom navigation bar ─────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Widget screen;

  const _MobileLayout({
    required this.currentIndex,
    required this.onTap,
    required this.screen,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: screen,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: onTap,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Inicio',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.local_florist_outlined),
                activeIcon: Icon(Icons.local_florist),
                label: 'Catálogo',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.shopping_bag_outlined),
                activeIcon: Icon(Icons.shopping_bag),
                label: 'Pedidos',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.group_outlined),
                activeIcon: Icon(Icons.group),
                label: 'CRM',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Perfil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Wide layout: sidebar + content ───────────────────────────────────────────

class _WideLayout extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Widget screen;
  final List<AppSidebarItem> items;

  const _WideLayout({
    required this.currentIndex,
    required this.onTap,
    required this.screen,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          AppSidebar(
            currentIndex: currentIndex,
            onTap: onTap,
            items: items,
            accentColor: const Color(0xFF2BEE79),
            header: _SidebarHeader(),
          ),
          Expanded(child: screen),
        ],
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFF2BEE79),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.local_florist, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          'tusflores',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }
}

// ─── Banner widget ────────────────────────────────────────────────────────────

class _NewOrderBanner extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NewOrderBanner({
    required this.order,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final buyerLabel = order.buyerName?.isNotEmpty == true
        ? order.buyerName!
        : order.customerName;

    return Material(
      elevation: 10,
      borderRadius: BorderRadius.circular(18),
      shadowColor: const Color(0xFF7C3AED).withValues(alpha: 0.35),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6D28D9), Color(0xFF9F67FA)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.shopping_bag_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '🛍️ Nuevo pedido ${order.folio}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$buyerLabel · ${CurrencyCache.symbol}${order.price.toStringAsFixed(0)} ${CurrencyCache.code}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Ver pedidos',
                        style: TextStyle(
                          color: Color(0xFF6D28D9),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onDismiss,
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white60, size: 16),
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
}
