import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../catalog/presentation/screens/add_edit_product_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../profile/domain/repositories/shop_settings_repository.dart';
import '../../../auth/domain/repositories/profile_repository.dart';
import '../../../catalog/domain/repositories/product_repository.dart';
import '../../../../features/orders/domain/repositories/order_repository.dart';
import '../../../../features/orders/domain/models/order_model.dart';
import 'weekly_stats_screen.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onNavigateToOrders;
  const DashboardScreen({super.key, this.onNavigateToOrders});

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
      // Load products count (all, including paused)
      final products = await ProductRepository().getProducts(user.id);
      final activeCount = products.where((p) => p['is_active'] == true).length;
      final pausedCount = products.where((p) => p['is_active'] == false).length;

      // Load orders
      final orders = await OrderRepository().getOrders(user.id);
      
      int pending = 0;
      int delivered = 0;
      double sales = 0;
      OrderModel? latest;
      
      final today = DateTime.now();
      
      for (var order in orders) {
        if (order.status == OrderStatus.pending) pending++;
        if (order.status == OrderStatus.delivered) delivered++;
        
        // Sales today
        if (order.createdAt != null &&
            order.createdAt!.year == today.year &&
            order.createdAt!.month == today.month &&
            order.createdAt!.day == today.day) {
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
      debugPrint('Error loading dashboard data: $e');
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
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    _buildSalesCard(context),
                    const SizedBox(height: 12),
                    _buildStatsGrid(context),
                    const SizedBox(height: 12),
                    _buildActionButtons(context),
                    const SizedBox(height: 24),
                    _buildLatestOrder(context),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24.0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _shopName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.secondaryBg,
                backgroundImage: NetworkImage(
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuAeIkOPO00Vkudeg_UpRc9dQunoSmMdv2yNQm47qwypGvvdnBgR5YfMKynfn1HT7z9crfg7OPvzkKzun3DFwR0TFos1l2VDD6hl8-mnbM2OzHiGCExkw-e_ZQfnsmsIrH46CsCBzL6m9h3aR1ZL33CJPuJ6srcoXwHzAMTcXa6KJArq3NCxPIJFm0CKg3QTy8l3gYLe0ocBUxSXeLOHLKnZq0Unl43_Mgglw1IkBLbQwymxQymKslAaVbI0WO7PlcsCLCLd-12vrrE-',
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Hola $_userName 👋',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.mutedLight,
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
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ventas de hoy',
                style: TextStyle(
                  color: AppTheme.mutedLight,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              Icon(Icons.more_horiz, color: AppTheme.mutedLight, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _isLoadingData
                  ? const SizedBox(
                      height: 36,
                      width: 100,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Text(
                      NumberFormat.currency(locale: 'es_MX', symbol: '\$').format(_todaySales),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.trending_up, color: Colors.green, size: 12),
                        SizedBox(width: 4),
                        Text(
                          '+15%',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'vs ayer',
                    style: TextStyle(color: AppTheme.mutedLight, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Center(
            child: InkWell(
              onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const WeeklyStatsScreen())),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ver Estadísticas',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward,
                    color: Theme.of(context).colorScheme.primary,
                    size: 16,
                  ),
                ],
              ),
            ),
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
        // Fila 1: Pendientes | Entregados | Catálogo
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.pending_actions,
                iconColor: Colors.orange,
                iconBg: Colors.orange.withValues(alpha: 0.1),
                value: _pendingCount.toString(),
                label: 'Pendientes',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.local_shipping,
                iconColor: Colors.blue,
                iconBg: Colors.blue.withValues(alpha: 0.1),
                value: _deliveredCount.toString(),
                label: 'Entregados',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.inventory_2,
                iconColor: Colors.purple,
                iconBg: Colors.purple.withValues(alpha: 0.1),
                value: _catalogCount.toString(),
                label: 'Catálogo',
              ),
            ),
          ],
        ),
        // Fila 2: En Pausa (ancho completo)
        if (_pausedCount > 0) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => context.go('/catalog'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.pause_circle_outline, color: Colors.grey, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'En Pausa',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          '$_pausedCount producto${_pausedCount == 1 ? '' : 's'} oculto${_pausedCount == 1 ? '' : 's'} del catálogo público',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _pausedCount.toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
                ],
              ),
            ),
          ),
        ],
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
                 icon: Icons.share,
                 label: 'Compartir catálogo',
                 onTap: () {
                   const String catalogUrl = 'tusflores.app/floreria';
                   final String message = '✨ ¡Bienvenido a $_shopName! ✨ Nuestras flores más frescas ya están listas para ti. Mira nuestro catálogo actualizado y elige el detalle perfecto para hoy: $catalogUrl';
                   Share.share(message);
                 },
                 onEdit: () {
                   context.push('/shop/catalog-message');
                 },
               ),
             ),
             const SizedBox(width: 12),
             Expanded(
               child: _OutlineActionButton(
                 icon: Icons.payments,
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
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddEditProductScreen()),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
            minimumSize: const Size(double.infinity, 0),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle, size: 20),
              SizedBox(width: 8),
              Text(
                'AGREGAR NUEVO PRODUCTO',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ],
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
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
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
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.secondaryBg,
                  border: Border.all(color: AppTheme.secondaryBg, width: 2),
                ),
                child: const Icon(Icons.shopping_bag, color: AppTheme.mutedLight),
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(16),
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
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.mutedLight,
              fontSize: 12,
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
      height: 100,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
            Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
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
                icon: const Icon(Icons.edit, size: 20),
                color: Theme.of(context).colorScheme.primary,
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
