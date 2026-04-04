import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../catalog/presentation/screens/add_edit_product_screen.dart';
import '../../../profile/domain/repositories/shop_settings_repository.dart';
import '../../../auth/domain/repositories/profile_repository.dart';
import '../../../catalog/domain/repositories/product_repository.dart';
import '../../../../features/orders/domain/repositories/order_repository.dart';
import '../../../../features/orders/domain/models/order_model.dart';
import 'weekly_stats_screen.dart';
import 'package:intl/intl.dart';
import '../../../orders/presentation/screens/edit_order_screen.dart';
import '../../../catalog/presentation/screens/catalog_screen.dart';
import '../../../orders/presentation/screens/orders_screen.dart';
import '../../../reviews/presentation/widgets/dashboard_rating_widget.dart';
import '../../../reparto/presentation/screens/reparto_historico_screen.dart';
import '../../../inventory/presentation/screens/inventory_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onNavigateToOrders;
  final VoidCallback? onNavigateToCatalog;
  const DashboardScreen({super.key, this.onNavigateToOrders, this.onNavigateToCatalog});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _shopName = 'Cargando...';
  String _userName = '...';

  bool _isLoadingData = true;
  int _pendingCount = 0;
  int _deliveredCount = 0;
  int _catalogCount = 0;
  int _pausedCount = 0;
  double _todaySales = 0.0;
  OrderModel? _latestOrder;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final products = await ProductRepository().getProducts(user.id);
      final activeCount = products.where((p) => p['is_active'] == true).length;
      final pausedCount = products.where((p) => p['is_active'] == false).length;

      final orders = await OrderRepository().getOrders(user.id);

      int pending = 0;
      int delivered = 0;
      double sales = 0;
      OrderModel? latest;

      final today = DateTime.now();

      for (var order in orders) {
        if (order.status == OrderStatus.waiting) pending++;
        if (order.status == OrderStatus.delivered) delivered++;

        if (order.createdAt.year == today.year &&
            order.createdAt.month == today.month &&
            order.createdAt.day == today.day) {
          sales += order.total;
        }
      }

      if (orders.isNotEmpty) {
        latest = orders.first;
      }

      if (mounted) {
        setState(() {
          _catalogCount = activeCount;
          _pausedCount = pausedCount;
          _pendingCount = pending;
          _deliveredCount = delivered;
          _todaySales = sales;
          _latestOrder = latest;
          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      if (mounted) setState(() => _userName = user.userMetadata?['name']?.toString() ?? 'Emprendedor');
      try {
        final profile = await ProfileRepository().getProfile();
        if (profile != null) {
          if (mounted) setState(() => _shopName = profile['shop_name'] ?? 'Mi Florería');
        }
      } catch (e) {
        if (mounted) setState(() => _shopName = 'Mi Florería');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    _buildSalesCard(context),
                    const SizedBox(height: 16),
                    _buildStatsGrid(context),
                    const SizedBox(height: 16),
                    _buildActionButtons(context),
                    const SizedBox(height: 28),
                    _buildLatestOrder(context),
                    const SizedBox(height: 16),
                    _buildRepartoCard(context),
                    const SizedBox(height: 16),
                    _buildInventarioCard(context),
                    const SizedBox(height: 16),
                    DashboardRatingWidget(shopId: Supabase.instance.client.auth.currentUser?.id ?? ''),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _shopName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Hola $_userName 👋',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.mutedLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
            ),
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(Icons.notifications_outlined, color: AppTheme.primary, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primary, Color(0xFF0D9488)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.40),
            blurRadius: 28,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -8,
            right: -8,
            child: Icon(
              Icons.local_florist,
              size: 80,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'VENTAS DE HOY',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _isLoadingData
                      ? const SizedBox(
                          height: 40,
                          width: 100,
                          child: Center(child: CircularProgressIndicator(color: Colors.white)),
                        )
                      : Text(
                          NumberFormat.currency(locale: 'es_MX', symbol: '\$').format(_todaySales),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.trending_up, color: Colors.white, size: 13),
                        SizedBox(width: 4),
                        Text(
                          '+15% vs ayer',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              InkWell(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const WeeklyStatsScreen())),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: const Text(
                    'Ver detalles del día',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context) {
    if (_isLoadingData) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(24.0),
        child: CircularProgressIndicator(),
      ));
    }
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const OrdersScreen(initialTab: 0))),
                child: _StatCard(
                  icon: Icons.pending_actions,
                  iconColor: const Color(0xFFF59E0B),
                  iconBg: const Color(0xFFFFF8E6),
                  glowColor: const Color(0xFFF59E0B),
                  value: _pendingCount.toString(),
                  label: 'Pendientes',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const OrdersScreen(initialTab: 1))),
                child: _StatCard(
                  icon: Icons.check_circle_outline,
                  iconColor: AppTheme.primary,
                  iconBg: const Color(0xFFECFDF5),
                  glowColor: AppTheme.primary,
                  value: _deliveredCount.toString(),
                  label: 'Entregados',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => widget.onNavigateToCatalog?.call(),
                child: _StatCard(
                  icon: Icons.menu_book_outlined,
                  iconColor: const Color(0xFF3B82F6),
                  iconBg: const Color(0xFFEFF6FF),
                  glowColor: const Color(0xFF3B82F6),
                  value: _catalogCount.toString(),
                  label: 'Catálogo',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CatalogScreen(showPausedOnly: true))),
                child: _StatCard(
                  icon: Icons.pause_circle_outline,
                  iconColor: const Color(0xFF94A3B8),
                  iconBg: const Color(0xFFF1F5F9),
                  glowColor: const Color(0xFF94A3B8),
                  value: _pausedCount.toString(),
                  label: 'En Pausa',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
             Expanded(
               child: _OutlineActionButton(
                 icon: Icons.share_outlined,
                 label: 'Compartir catálogo',
                 onTap: () async {
                   final userId = Supabase.instance.client.auth.currentUser?.id;
                   if (userId == null) return;

                   final settings = await ShopSettingsRepository().getSettings(userId);
                   final profile = await ProfileRepository().getProfile();

                   final catalogName = (settings?.rawData?['catalog_shop_name'] as String?)?.trim() ?? '';
                   final displayName = catalogName.isNotEmpty ? catalogName : _shopName;

                   // Buscar slug registrado en slugs_registry
                   String storeUrl = 'https://www.tusflores.app';
                   try {
                     final slugRow = await Supabase.instance.client
                         .from('slugs_registry')
                         .select('slug, pais')
                         .eq('entity_id', userId)
                         .maybeSingle();
                     if (slugRow != null) {
                       final s = slugRow['slug'] as String;
                       final p = slugRow['pais'] as String;
                       storeUrl = 'https://www.tusflores.app/$p/$s';
                     }
                   } catch (_) {}

                   final customMsg = (settings?.catalogMessage as String?)?.trim() ?? '';

                   final buffer = StringBuffer();
                   buffer.writeln('🌸 *$displayName*');
                   buffer.writeln();
                   if (customMsg.isNotEmpty) {
                     buffer.writeln(customMsg);
                     buffer.writeln();
                   }
                   buffer.writeln('👉 Visita nuestro catálogo:');
                   buffer.writeln(storeUrl);

                   Share.share(buffer.toString().trim());
                 },
                 onEdit: () async {
                   final result = await context.push('/shop/catalog-message');
                   if (result == true && mounted) _loadProfile();
                 },
               ),
             ),
             const SizedBox(width: 12),
             Expanded(
               child: _OutlineActionButton(
                 icon: Icons.payments_outlined,
                 label: 'Compartir formas de pago',
                 onTap: () async {
                   final String shopId = Supabase.instance.client.auth.currentUser!.id;
                   final settings = await ShopSettingsRepository().getSettings(shopId);
                   if (settings == null) {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay formas de pago configuradas')));
                     return;
                   }
                   final buffer = StringBuffer();
                   buffer.writeln('💳 *Formas de pago — $_shopName*\n');
                   if (settings.bankMethods.isNotEmpty) {
                     buffer.writeln('🏦 *Transferencia bancaria*');
                     for (final b in settings.bankMethods) {
                       buffer.writeln('• ${b.bankName} (${b.accountType})');
                       buffer.writeln('  Titular: ${b.holderName}');
                       buffer.writeln('  Cuenta: ${b.accountNumber}');
                       buffer.writeln('  CLABE: ${b.clabe}');
                     }
                     buffer.writeln();
                   }
                   if (settings.linkMethods.isNotEmpty) {
                     buffer.writeln('🔗 *Links de pago*');
                     for (final l in settings.linkMethods) {
                       buffer.writeln('• ${l.serviceName}: https://${l.url}');
                     }
                   }
                   buffer.writeln('\n¡Gracias por tu compra! 🌸');
                   Share.share(buffer.toString().trim(), subject: 'Formas de pago — $_shopName');
                 },
               ),
             ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.45),
                blurRadius: 22,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddEditProductScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 0,
              minimumSize: const Size(double.infinity, 0),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle_outline, size: 22),
                SizedBox(width: 10),
                Text(
                  'AGREGAR NUEVO PRODUCTO',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLatestOrder(BuildContext context) {
    if (_isLoadingData) {
      return const SizedBox.shrink();
    }

    if (_latestOrder == null) {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ÚLTIMO PEDIDO',
                style: TextStyle(
                  color: AppTheme.mutedLight,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.0,
                ),
              ),
              InkWell(
                onTap: widget.onNavigateToOrders,
                child: Text(
                  'Ver todos',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'Aún no hay pedidos registrados',
                style: TextStyle(color: AppTheme.mutedLight),
              ),
            ),
          ),
        ],
      );
    }

    final order = _latestOrder!;
    final timeDiff = DateTime.now().difference(order.createdAt);
    String timeAgo = '';
    if (timeDiff.inMinutes < 60) {
      timeAgo = 'Hace ${timeDiff.inMinutes} min';
    } else if (timeDiff.inHours < 24) {
      timeAgo = 'Hace ${timeDiff.inHours} hrs';
    } else {
      timeAgo = 'Hace ${timeDiff.inDays} días';
    }

    String statusText = 'PENDIENTE';
    Color statusColor = AppTheme.accentYellowText;
    Color statusBg = AppTheme.accentYellow;

    if (order.status == OrderStatus.delivered) {
      statusText = 'ENTREGADO';
      statusColor = Colors.green.shade700;
      statusBg = Colors.green.shade100;
    } else if (order.status == OrderStatus.cancelled) {
      statusText = 'CANCELADO';
      statusColor = Colors.red.shade700;
      statusBg = Colors.red.shade100;
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'ÚLTIMO PEDIDO',
              style: TextStyle(
                color: AppTheme.mutedLight,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.0,
              ),
            ),
            InkWell(
              onTap: widget.onNavigateToOrders,
              child: Text(
                'Ver todos',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => EditOrderScreen(order: order))),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: AppTheme.primary.withValues(alpha: 0.10),
                  ),
                  child: const Icon(Icons.local_florist, color: AppTheme.primary, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text(
                                   'Folio ${order.folio}',
                                   style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                         fontWeight: FontWeight.bold,
                                       ),
                                 ),
                                 Text(
                                   order.customerName,
                                   style: const TextStyle(
                                     color: AppTheme.mutedLight,
                                     fontSize: 14,
                                   ),
                                   maxLines: 1,
                                   overflow: TextOverflow.ellipsis,
                                 ),
                               ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildRepartoCard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'REPARTO',
          style: TextStyle(
            color: AppTheme.mutedLight,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RepartoHistoricoScreen()),
          ),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.deepOrange.withValues(alpha: 0.18)),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepOrange.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delivery_dining_rounded,
                      color: Colors.deepOrange, size: 26),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Histórico de Reparto',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textLight,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Consulta entregas, montos y notas por repartidor',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.mutedLight,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: Colors.deepOrange, size: 22),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

  Widget _buildInventarioCard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'LISTA DE COMPRA',
          style: TextStyle(
            color: AppTheme.mutedLight,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const InventoryScreen()),
          ),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.18)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.inventory_2_outlined,
                      color: Color(0xFF7C3AED), size: 26),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Listas de Compra',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textLight,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Crea y gestiona tus listas de flores e insumos',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.mutedLight,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFF7C3AED), size: 22),
              ],
            ),
          ),
        ),
      ],
    );
  }

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Color glowColor;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.glowColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: glowColor.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.14),
            blurRadius: 18,
            spreadRadius: 0,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: iconColor.withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlineActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  const _OutlineActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      height: 96,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.06),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.20),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
            Icon(
              icon,
              color: AppTheme.primary,
              size: 26,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 11,
                height: 1.2,
              ),
            ),
          ],
        ),
      );

    if (onEdit != null) {
      return Stack(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: content,
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Material(
              color: Colors.transparent,
              child: IconButton(
                icon: const Icon(Icons.edit, size: 18),
                color: AppTheme.primary,
                onPressed: onEdit,
                splashRadius: 20,
              ),
            ),
          ),
        ],
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: content,
    );
  }
}
