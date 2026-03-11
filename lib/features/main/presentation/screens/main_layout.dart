import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  Timer? _bannerTimer;

  List<Widget> get _screens => [
        DashboardScreen(
          onNavigateToOrders: () => setState(() => _currentIndex = 2),
          onNavigateToCatalog: () => setState(() => _currentIndex = 1),
        ),
        const CatalogScreen(),
        const OrdersScreen(),
        const CrmScreen(),
        const MainProfileSettingsScreen(),
      ];

  @override
  void initState() {
    super.initState();
    _bannerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    // Start subscription after first frame so Overlay is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startRealtimeSubscription();
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerEntry?.remove();
    _bannerEntry = null;
    _bannerController.dispose();
    if (_ordersChannel != null) {
      Supabase.instance.client.removeChannel(_ordersChannel!);
    }
    super.dispose();
  }

  // ── Realtime subscription (INSERT only — just for the banner) ─────────────

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
              // Only show banner when user is NOT on the Pedidos tab
              if (_currentIndex != 2) {
                _showNewOrderBanner(newOrder);
              }
            } catch (e) {
              debugPrint('[MainLayout Realtime] Error: $e');
            }
          },
        )
        .subscribe();
  }

  // ── Banner ────────────────────────────────────────────────────────────────

  void _showNewOrderBanner(OrderModel order) {
    _dismissBannerImmediately(); // remove any previous banner

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
              },
              onDismiss: _dismissBanner,
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_bannerEntry!);
    _bannerController.forward(from: 0);

    // Auto-dismiss after 5 s
    _bannerTimer?.cancel();
    _bannerTimer = Timer(const Duration(seconds: 5), _dismissBanner);
  }

  /// Animated dismiss (slide out upward).
  void _dismissBanner() {
    _bannerTimer?.cancel();
    _bannerTimer = null;
    if (_bannerEntry == null || !mounted) return;
    _bannerController.reverse().then((_) {
      _bannerEntry?.remove();
      _bannerEntry = null;
    });
  }

  /// Immediate dismiss (no animation) — used before showing a new banner.
  void _dismissBannerImmediately() {
    _bannerTimer?.cancel();
    _bannerTimer = null;
    _bannerEntry?.remove();
    _bannerEntry = null;
    _bannerController.reset();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
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
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
              // Dismiss banner when user manually navigates to Pedidos
              if (index == 2) _dismissBanner();
            },
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
    // Try to parse the buyer name (may be different from customerName)
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
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Icon
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

                // Text
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
                        '$buyerLabel · \$${order.price.toStringAsFixed(0)} MXN',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // CTA + close
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
