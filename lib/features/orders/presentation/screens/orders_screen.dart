import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_cache.dart';
import 'edit_order_screen.dart';
import 'confirm_payment_screen.dart';
import 'order_calendar_screen.dart';
import 'order_date_filter_screen.dart';
import 'print_card_screen.dart';
import 'albaran_screen.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/order_model.dart';
import '../../domain/repositories/order_repository.dart';
import '../../../profile/domain/repositories/shop_settings_repository.dart';
import '../../../reparto/presentation/widgets/assign_repartidor_sheet.dart';

// ─── Notification model ───────────────────────────────────────────────────────

enum _NotifType { newOrder, statusChange, comment }

/// Three display modes for the orders screen.
enum _FilterMode { byVenta, byEntrega, entregados }

class _NotificationItem {
  final String id;
  final _NotifType type;
  final String title;
  final String subtitle;
  final DateTime createdAt;
  bool read = false;

  _NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.createdAt,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class OrdersScreen extends StatefulWidget {
  final int initialTab;
  const OrdersScreen({super.key, this.initialTab = 0});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  // Active display mode
  _FilterMode _filterMode = _FilterMode.byVenta;

  // Chip index per mode (default: last chip = "Hoy" for venta/entregados, first = "Hoy" for entrega)
  int _selectedDateIndex = 3;

  List<String> get _currentChips {
    switch (_filterMode) {
      case _FilterMode.byVenta:    return ['15 días', '7 días', 'Ayer', 'Hoy'];
      case _FilterMode.byEntrega:  return ['Hoy', 'Mañana', '7 días', '15 días'];
      case _FilterMode.entregados: return ['Hoy', 'Esta semana', 'Este mes'];
    }
  }

  // Custom date range (only used in byVenta mode)
  DateTimeRange? _customDateRange;

  // Orders as mutable state
  List<OrderModel> _orders = [];
  final _orderRepo = OrderRepository();
  bool _isLoading = true;
  final Set<String> _expandedOrders = {};

  // ── Search
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  // ── Realtime
  RealtimeChannel? _ordersChannel;

  // ── Shop name (for share messages)
  String _shopName = 'Mi Florería';

  // ── Reparto settings
  bool _autoTransferShipping = false;

  // ── Notifications
  final List<_NotificationItem> _notifications = [];
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    // initialTab == 1 → open directly in Entregados mode
    if (widget.initialTab == 1) {
      _filterMode = _FilterMode.entregados;
      _selectedDateIndex = 2; // Este mes
    }
    _loadOrders();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    if (_ordersChannel != null) {
      Supabase.instance.client.removeChannel(_ordersChannel!);
    }
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final fetched = await _orderRepo.getOrders(user.id);
      _orders = fetched;
      _subscribeToOrders(user.id);
      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('shop_name')
            .eq('id', user.id)
            .maybeSingle();
        if (mounted && profile != null) {
          setState(() => _shopName = profile['shop_name'] ?? 'Mi Florería');
        }
      } catch (_) {}
      try {
        final settings = await ShopSettingsRepository().getSettings(user.id);
        if (mounted && settings != null) {
          setState(() => _autoTransferShipping = settings.autoTransferShipping);
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _isLoading = false);
  }

  /// Opens a Supabase Realtime channel filtered by [shopId].
  /// INSERT → prepends the new order to the list.
  /// UPDATE → replaces the existing order in-place.
  void _subscribeToOrders(String shopId) {
    // Remove previous channel to avoid duplicates
    if (_ordersChannel != null) {
      Supabase.instance.client.removeChannel(_ordersChannel!);
    }
    _ordersChannel = Supabase.instance.client
        .channel('orders_realtime_$shopId')
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
              final newOrder = OrderModel.fromJson(payload.newRecord);
              if (!mounted) return;
              final alreadyExists =
                  _orders.any((o) => o.id == newOrder.id);
              if (!alreadyExists) {
                // Build notification
                final notif = _NotificationItem(
                  id: newOrder.id ?? DateTime.now().toString(),
                  type: _NotifType.newOrder,
                  title: '🛍️ Nuevo pedido ${newOrder.folio}',
                  subtitle:
                      '${newOrder.customerName} — ${CurrencyCache.symbol}${newOrder.price.toStringAsFixed(0)}',
                  createdAt: DateTime.now(),
                );
                setState(() {
                  _orders.insert(0, newOrder);
                  _notifications.insert(0, notif);
                  _unreadCount++;
                });
              }
            } catch (e) {
              _loadOrders();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'shop_id',
            value: shopId,
          ),
          callback: (payload) {
            try {
              final updated = OrderModel.fromJson(payload.newRecord);
              if (!mounted) return;
              final idx = _orders.indexWhere((o) => o.id == updated.id);
              if (idx >= 0) {
                setState(() => _orders[idx] = updated);
              }
            } catch (e) {
              _loadOrders();
            }
          },
        )
        .subscribe();
  }

  // ── Notifications panel ──────────────────────────────────────────────────

  void _showNotificationsPanel() {
    // Mark all as read when the panel opens
    setState(() {
      for (final n in _notifications) {
        n.read = true;
      }
      _unreadCount = 0;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.30,
          maxChildSize: 0.90,
          expand: false,
          builder: (_, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Handle
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Row(
                      children: [
                        const Text(
                          'Notificaciones',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textLight,
                          ),
                        ),
                        const Spacer(),
                        if (_notifications.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setState(() => _notifications.clear());
                              Navigator.pop(ctx);
                            },
                            child: const Text(
                              'Limpiar',
                              style: TextStyle(
                                  color: Color(0xFF7C3AED), fontSize: 13),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 20),
                  // List
                  Expanded(
                    child: _notifications.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.notifications_none_rounded,
                                    size: 64,
                                    color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                Text(
                                  'Sin notificaciones',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey.shade400,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Aquí verás nuevos pedidos\ny actualizaciones.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            controller: controller,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            itemCount: _notifications.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final n = _notifications[i];
                              final (iconData, iconColor, bgColor) =
                                  switch (n.type) {
                                _NotifType.newOrder => (
                                    Icons.shopping_bag_rounded,
                                    const Color(0xFF7C3AED),
                                    const Color(0xFFF3F0FF),
                                  ),
                                _NotifType.statusChange => (
                                    Icons.swap_horiz_rounded,
                                    const Color(0xFF059669),
                                    const Color(0xFFECFDF5),
                                  ),
                                _NotifType.comment => (
                                    Icons.chat_bubble_rounded,
                                    const Color(0xFFF59E0B),
                                    const Color(0xFFFFFBEB),
                                  ),
                              };
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 6),
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: bgColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(iconData,
                                      color: iconColor, size: 22),
                                ),
                                title: Text(
                                  n.title,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textLight,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 2),
                                    Text(n.subtitle,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        )),
                                    const SizedBox(height: 2),
                                    Text(
                                      _timeAgo(n.createdAt),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Hace un momento';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    return 'Hace ${diff.inDays} días';
  }

  /// Picks the date to use for filtering depending on the active mode.
  DateTime _filterDateOf(OrderModel o) {
    if (_filterMode == _FilterMode.byVenta) return o.createdAt.toLocal();
    return o.deliveryDate ?? o.saleDate.toLocal();
  }

  /// Applies the date-range or chip filter to any list of orders.
  List<OrderModel> _applyDateFilter(List<OrderModel> orders) {
    if (_customDateRange != null && _filterMode == _FilterMode.byVenta) {
      return orders.where((o) {
        final d = _filterDateOf(o);
        final start = _customDateRange!.start;
        final end =
            _customDateRange!.end.add(const Duration(hours: 23, minutes: 59));
        return d.isAfter(start.subtract(const Duration(minutes: 1))) &&
            d.isBefore(end.add(const Duration(minutes: 1)));
      }).toList();
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return orders.where((o) {
      final d = _filterDateOf(o);
      final oDate = DateTime(d.year, d.month, d.day);

      switch (_filterMode) {
        case _FilterMode.byVenta:
          // Chips: ['15 días', '7 días', 'Ayer', 'Hoy']
          if (_selectedDateIndex == 0)
            return oDate.isAfter(today.subtract(const Duration(days: 15)));
          if (_selectedDateIndex == 1)
            return oDate.isAfter(today.subtract(const Duration(days: 7)));
          if (_selectedDateIndex == 2)
            return oDate == today.subtract(const Duration(days: 1));
          if (_selectedDateIndex == 3) return oDate == today;

        case _FilterMode.byEntrega:
          // Chips: ['Hoy', 'Mañana', '7 días', '15 días'] — future orders only
          if (_selectedDateIndex == 0) return oDate == today;
          if (_selectedDateIndex == 1)
            return oDate == today.add(const Duration(days: 1));
          if (_selectedDateIndex == 2)
            return !oDate.isBefore(today) &&
                !oDate.isAfter(today.add(const Duration(days: 7)));
          if (_selectedDateIndex == 3)
            return !oDate.isBefore(today) &&
                !oDate.isAfter(today.add(const Duration(days: 15)));

        case _FilterMode.entregados:
          // Chips: ['Hoy', 'Esta semana', 'Este mes'] — past delivered orders
          if (_selectedDateIndex == 0) return oDate == today;
          if (_selectedDateIndex == 1) {
            final weekStart =
                today.subtract(Duration(days: today.weekday - 1));
            return !oDate.isBefore(weekStart) && !oDate.isAfter(today);
          }
          if (_selectedDateIndex == 2) {
            final monthStart = DateTime(today.year, today.month, 1);
            return !oDate.isBefore(monthStart) && !oDate.isAfter(today);
          }
      }
      return true;
    }).toList();
  }

  /// Orders filtered by mode, date period, and optionally search query.
  List<OrderModel> get _filteredOrders {
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      // In entregados mode, search only within delivered orders
      final pool = _filterMode == _FilterMode.entregados
          ? _orders.where((o) => o.status == OrderStatus.delivered).toList()
          : _orders;
      return pool.where((o) {
        return o.folio.toLowerCase().contains(q) ||
            o.customerName.toLowerCase().contains(q) ||
            o.productName.toLowerCase().contains(q);
      }).toList();
    }
    final List<OrderModel> byStatus;
    if (_filterMode == _FilterMode.entregados) {
      byStatus =
          _orders.where((o) => o.status == OrderStatus.delivered).toList();
    } else {
      byStatus = _orders
          .where((o) =>
              o.status == OrderStatus.waiting ||
              o.status == OrderStatus.processing ||
              o.status == OrderStatus.inTransit)
          .toList();
    }
    return _applyDateFilter(byStatus);
  }

  Future<void> _selectDateRange() async {
    final picked = await Navigator.push<DateTimeRange>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            OrderDateFilterScreen(initialRange: _customDateRange),
        fullscreenDialog: true,
      ),
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        // Unselect chips when custom range is chosen
        _selectedDateIndex = -1; 
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header scrolls WITH the list ──────────────────────────────
            SliverToBoxAdapter(child: _buildHeader()),

            // ── Order list ────────────────────────────────────────────────
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                    child: CircularProgressIndicator(color: AppTheme.primary)),
              )
            else if (_filteredOrders.isEmpty)
              SliverFillRemaining(child: _buildEmptyState())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(_buildOrderItems()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final canPop = Navigator.canPop(context);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with notification bell
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (canPop) ...[
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 38,
                    height: 38,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back,
                        color: Colors.black87, size: 20),
                  ),
                ),
              ],
              Text(
                _filterMode == _FilterMode.entregados
                    ? 'Pedidos Entregados'
                    : 'Mis Pedidos',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textLight,
                ),
              ),
              const Spacer(),
              // Calendar button
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const OrderCalendarScreen()),
                ),
                child: Container(
                  width: 42,
                  height: 42,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    color: AppTheme.primary,
                    size: 22,
                  ),
                ),
              ),
              // Bell button
              GestureDetector(
                onTap: _showNotificationsPanel,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _unreadCount > 0
                            ? const Color(0xFF7C3AED).withValues(alpha: 0.1)
                            : Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _unreadCount > 0
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_none_rounded,
                        color: _unreadCount > 0
                            ? const Color(0xFF7C3AED)
                            : Colors.grey.shade500,
                        size: 22,
                      ),
                    ),
                    if (_unreadCount > 0)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                              minWidth: 18, minHeight: 18),
                          child: Text(
                            _unreadCount > 99
                                ? '99+'
                                : '$_unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Barra de búsqueda ──
          _buildSearchBar(),
          const SizedBox(height: 12),

          // ── Filtro: Por Venta / Por Entrega ──
          _buildFilterModeToggle(),
          const SizedBox(height: 12),

          // Date filter chips (dinámicos según modo)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_currentChips.length, (i) {
                final selected = i == _selectedDateIndex;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedDateIndex = i;
                    _customDateRange = null;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      _currentChips[i],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : const Color(0xFF9E9E9E),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 14),

          // Selector de rango solo en modo "Por Venta"
          if (_filterMode == _FilterMode.byVenta) ...[
            GestureDetector(
              onTap: _selectDateRange,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.calendar_today, color: AppTheme.primary, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _customDateRange == null
                            ? 'Seleccionar rango de fechas'
                            : '${_formatDate(_customDateRange!.start)} - ${_formatDate(_customDateRange!.end)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: _customDateRange == null ? const Color(0xFF9E9E9E) : AppTheme.textLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (_customDateRange != null)
                      GestureDetector(
                        onTap: () => setState(() {
                          _customDateRange = null;
                          _selectedDateIndex = 3; // back to Hoy
                        }),
                        child: const Icon(Icons.close, color: Color(0xFF9E9E9E), size: 22),
                      )
                    else
                      const Icon(Icons.keyboard_arrow_down, color: Color(0xFF9E9E9E), size: 22),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ─── Order Card ─────────────────────────────────────────────────────────────

  Widget _buildOrderCard(OrderModel order) {
    final key = order.id ?? order.folio;
    final isExpanded = _expandedOrders.contains(key);

    return GestureDetector(
      onTap: () => setState(() {
        isExpanded ? _expandedOrders.remove(key) : _expandedOrders.add(key);
      }),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: time + urgency badge + folio
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _timeAgo(order.createdAt),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (order.source == 'shopify') ...[
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF96BF48).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF96BF48), width: 0.8),
                        ),
                        child: const Text(
                          'Shopify',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF5A8A00),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                    ..._buildUrgencyBadge(order),
                    Text(
                      'FOLIO ${order.folio}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFBDBDBD),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Product row
            Row(
              children: [
                // Product icon / image
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: order.productImageUrl != null
                      ? Image.network(
                          order.productImageUrl!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: order.iconBgColor ?? const Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(order.icon ?? Icons.local_florist, color: order.iconColor ?? const Color(0xFFFFA726), size: 28),
                          ),
                        )
                      : Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: order.iconBgColor ?? const Color(0xFFFFF8E1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(order.icon ?? Icons.local_florist, color: order.iconColor ?? const Color(0xFFFFA726), size: 28),
                        ),
                ),
                const SizedBox(width: 14),

                // Product info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...() {
                        try {
                          final List<dynamic> productsData = jsonDecode(order.productName);
                          // We build a single elegant string to display the products in the card e.g. "2x Rosas, 1x Peluche"
                          final parts = <String>[];
                          for (var p in productsData) {
                             final name = p['name'] as String? ?? 'Producto';
                             final qty = p['qty'] as int? ?? 1;
                             parts.add('${qty}x $name');
                          }
                          return [
                            Text(
                              parts.join(', '),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textLight,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ];
                        } catch (e) {
                          // Fallback for old orders where productName is just a plain string
                          return [
                            Text(
                              '${order.quantity}× ${order.productName}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textLight,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ];
                        }
                      }(),
                      const SizedBox(height: 4),
                      Text(
                        '${CurrencyCache.symbol}${order.price.toStringAsFixed(0)} ${CurrencyCache.code}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Venta: ${_formatDate(order.createdAt)}, ${_formatTime(order.createdAt)}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                      ),
                      Text(
                        'Entrega: ${order.deliveryInfo}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Collapsed indicator / expand toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Status badge (always visible)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: order.status.chipColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(order.status.chipIcon, color: order.status.chipColor, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        order.status.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: order.status.chipColor,
                        ),
                      ),
                    ],
                  ),
                ),
                // Chevron
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 20, color: Color(0xFFBDBDBD)),
                ),
              ],
            ),

            // ── Expandable section ──────────────────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: isExpanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),

            // Action icons row — 6 quick-access buttons (Foto is last)
            Row(
              children: [
                _cardAction(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Chat',
                  color: const Color(0xFF2E7D52),
                  bgColor: const Color(0xFFE6F4ED),
                  onTap: () => _openWhatsApp(order.customerPhone),
                ),
                const SizedBox(width: 7),
                _cardAction(
                  icon: Icons.ios_share_rounded,
                  label: 'Enviar',
                  color: const Color(0xFF6952A8),
                  bgColor: const Color(0xFFF0EAFA),
                  onTap: () => _shareOrder(order),
                ),
                const SizedBox(width: 7),
                _cardAction(
                  icon: Icons.edit_outlined,
                  label: 'Editar',
                  color: const Color(0xFF546E7A),
                  bgColor: const Color(0xFFECF1F4),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => EditOrderScreen(order: order))),
                ),
                const SizedBox(width: 7),
                _cardAction(
                  icon: Icons.note_alt_outlined,
                  label: 'Tarjeta',
                  color: const Color(0xFF2E7D52),
                  bgColor: AppTheme.primary.withValues(alpha: 0.08),
                  onTap: () {
                    final msg = order.dedicationMessage ?? '';
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => PrintCardScreen(initialMessage: msg)));
                  },
                ),
                const SizedBox(width: 7),
                _cardAction(
                  icon: Icons.receipt_long_outlined,
                  label: 'Albarán',
                  color: const Color(0xFF1565C0),
                  bgColor: const Color(0xFFE3F0FD),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AlbaranScreen(order: order, shopName: _shopName),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Fotos del arreglo — botón full-width (no puede colapsar)
            GestureDetector(
              onTap: () => _showPhotoSheet(context, order),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE4F3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      order.completionPhotos.isEmpty
                          ? Icons.camera_alt_outlined
                          : Icons.camera_alt_rounded,
                      color: const Color(0xFFE91E8C),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      order.completionPhotos.isEmpty
                          ? 'Fotos del arreglo'
                          : '${order.completionPhotos.length}/3 fotos',
                      style: const TextStyle(
                        color: Color(0xFFE91E8C),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Repartidor — botón full-width
            GestureDetector(
              onTap: () => _showRepartidorSheet(context, order),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: order.repartidorId != null
                      ? Border.all(
                          color: Colors.deepOrange.withValues(alpha: 0.35))
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      order.repartidorId != null
                          ? Icons.delivery_dining_rounded
                          : Icons.delivery_dining_outlined,
                      color: Colors.deepOrange,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      order.repartidorId != null
                          ? (order.repartidorName ?? 'Repartidor asignado')
                          : 'Repartidor',
                      style: const TextStyle(
                        color: Colors.deepOrange,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Payment + Status row
            Row(
              children: [
                // Pagado chip
                GestureDetector(
                  onTap: () async {
                    if (order.id == null) return;
                    final result = await Navigator.push<String>(context,
                        MaterialPageRoute(builder: (_) => ConfirmPaymentScreen(order: order)));
                    if (result != null && mounted) {
                      final success = await _orderRepo.updatePaymentStatus(order.id!, true, result);
                      if (success) {
                        setState(() {
                          order.isPaid = true;
                          order.paymentMethod = result;
                        });
                      }
                    }
                  },
                  child: _statusChip(
                    icon: order.isPaid ? null : Icons.account_balance_wallet_outlined,
                    label: order.isPaid
                        ? (order.paymentMethod != null
                            ? '\u2713 ${order.paymentMethod!.replaceFirst(RegExp(r'^Activa\s+', caseSensitive: false), '')}'
                            : 'Pagado')
                        : '¿Pagado?',
                    color: order.isPaid ? const Color(0xFF2E7D52) : const Color(0xFFD4790A),
                    outlined: true,
                  ),
                ),
                const SizedBox(width: 8),
                // Status popup button
                Expanded(
                  child: PopupMenuButton<OrderStatus>(
                    onSelected: (s) => _changeOrderStatus(order, s),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    itemBuilder: (ctx) => [
                      for (final s in [
                        OrderStatus.waiting,
                        OrderStatus.processing,
                        OrderStatus.inTransit,
                        OrderStatus.delivered,
                      ])
                        PopupMenuItem<OrderStatus>(
                          value: s,
                          child: Row(
                            children: [
                              Icon(s.chipIcon, color: s.chipColor, size: 16),
                              const SizedBox(width: 8),
                              Text(s.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: s == order.status
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: s == order.status ? s.chipColor : Colors.black87,
                                  )),
                              const Spacer(),
                              if (s == order.status)
                                Icon(Icons.check, color: s.chipColor, size: 14),
                            ],
                          ),
                        ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: order.status.chipColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(order.status.chipIcon, color: Colors.white, size: 15),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(order.status.label,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 3),
                          const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    )); // GestureDetector
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

  Widget _statusChip({IconData? icon, required String label, required Color color, bool outlined = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ─── Search Bar ─────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: _searchCtrl,
        textInputAction: TextInputAction.search,
        onChanged: (val) => setState(() => _searchQuery = val.trim()),
        decoration: InputDecoration(
          hintText: 'Buscar folio, cliente o producto…',
          hintStyle:
              TextStyle(color: Colors.grey[400], fontSize: 13),
          prefixIcon:
              Icon(Icons.search, color: Colors.grey[400], size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close,
                      size: 18, color: Colors.grey[500]),
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  // ─── Filter Mode Toggle ──────────────────────────────────────────────────────

  Widget _buildFilterModeToggle() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEEE),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          _buildToggleOption(
            label: '🛒 Venta',
            isSelected: _filterMode == _FilterMode.byVenta,
            onTap: () => setState(() {
              _filterMode = _FilterMode.byVenta;
              _selectedDateIndex = 3; // Hoy
              _customDateRange = null;
            }),
          ),
          _buildToggleOption(
            label: '🚚 Entregar',
            isSelected: _filterMode == _FilterMode.byEntrega,
            onTap: () => setState(() {
              _filterMode = _FilterMode.byEntrega;
              _selectedDateIndex = 0; // Hoy
              _customDateRange = null;
            }),
          ),
          _buildToggleOption(
            label: '✅ Entregados',
            isSelected: _filterMode == _FilterMode.entregados,
            onTap: () => setState(() {
              _filterMode = _FilterMode.entregados;
              _selectedDateIndex = 2; // Este mes
              _customDateRange = null;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(19),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? AppTheme.textLight
                    : const Color(0xFF9E9E9E),
              ),
            ),
          ),
        ),
      ),
    );
  }


  // ─── Urgency Badge ───────────────────────────────────────────────────────────

  /// Returns [badge, SizedBox] if the order has urgent/expired delivery, else [].
  List<Widget> _buildUrgencyBadge(OrderModel order) {
    if (order.status == OrderStatus.delivered) return [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final ref = order.deliveryDate ?? order.saleDate.toLocal();
    final deliveryDay = DateTime(ref.year, ref.month, ref.day);

    if (deliveryDay.isBefore(today)) {
      return [_urgencyPill('Vencido', Colors.red), const SizedBox(width: 6)];
    } else if (deliveryDay == today) {
      return [
        _urgencyPill('Hoy 🔴', Colors.orange),
        const SizedBox(width: 6)
      ];
    } else if (deliveryDay ==
        today.add(const Duration(days: 1))) {
      return [
        _urgencyPill('Mañana 🟡', const Color(0xFFF59E0B)),
        const SizedBox(width: 6)
      ];
    }
    return [];
  }

  Widget _urgencyPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }

  // ─── Empty State ─────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.inbox_outlined, size: 40, color: AppTheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            _filterMode == _FilterMode.entregados
                ? 'Sin pedidos entregados en este período'
                : 'Sin pedidos en operación',
            style: const TextStyle(
                color: Color(0xFFBDBDBD),
                fontSize: 15,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  /// Builds the flat or grouped list of widgets to render in the SliverList.
  List<Widget> _buildOrderItems() {
    // Entregados mode → summary banner + compact delivered cards
    if (_filterMode == _FilterMode.entregados) {
      return [
        _buildEntregadosSummary(_filteredOrders),
        ..._filteredOrders.map((o) => _buildEntregadoCard(o)),
      ];
    }
    // Search results → flat list
    if (_searchQuery.isNotEmpty) {
      return _filteredOrders.map((o) => _buildOrderCard(o)).toList();
    }
    // En operación → grouped by status with section headers
    final items = <Widget>[];
    for (final status in [
      OrderStatus.waiting,
      OrderStatus.processing,
      OrderStatus.inTransit,
    ]) {
      final group =
          _filteredOrders.where((o) => o.status == status).toList();
      if (group.isEmpty) continue;
      items.add(_buildStatusSectionHeader(status, group.length));
      items.addAll(group.map((o) => _buildOrderCard(o)));
    }
    return items;
  }

  // ─── Entregados Summary Banner ───────────────────────────────────────────────

  Widget _buildEntregadosSummary(List<OrderModel> orders) {
    final total = orders.fold<double>(0, (sum, o) => sum + o.price * o.quantity + o.shippingCost);
    final chipLabel = _currentChips[_selectedDateIndex < _currentChips.length ? _selectedDateIndex : 0];
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D3320), Color(0xFF1A5C38)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: Color(0xFF2BEE79), size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${orders.length} pedido${orders.length == 1 ? '' : 's'} entregado${orders.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  chipLabel,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${CurrencyCache.symbol}${total.toStringAsFixed(0)}',
                style: const TextStyle(
                    color: Color(0xFF2BEE79),
                    fontSize: 18,
                    fontWeight: FontWeight.w900),
              ),
              Text(
                CurrencyCache.code,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Entregado Card ──────────────────────────────────────────────────────────

  Widget _buildEntregadoCard(OrderModel order) {
    // Parse product name (may be JSON array)
    String productDisplay;
    try {
      final List<dynamic> items = jsonDecode(order.productName);
      productDisplay = items.map((p) {
        final name = p['name'] as String? ?? 'Producto';
        final qty = p['qty'] as int? ?? 1;
        return '${qty}× $name';
      }).join(', ');
    } catch (_) {
      productDisplay = '${order.quantity}× ${order.productName}';
    }

    final deliveryRef = order.deliveryDate ?? order.saleDate.toLocal();
    final deliveryLabel = _formatDate(deliveryRef);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: order.productImageUrl != null
                  ? Image.network(order.productImageUrl!,
                      width: 60, height: 60, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _entregadoIconBox(order))
                  : _entregadoIconBox(order),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product name + shopify pill
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          productDisplay,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textLight),
                        ),
                      ),
                      if (order.source == 'shopify')
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF96BF48).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: const Color(0xFF96BF48), width: 0.8),
                          ),
                          child: const Text('Shopify',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF5A8A00))),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(order.customerName,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF9E9E9E))),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 11, color: Color(0xFF10B981)),
                      const SizedBox(width: 4),
                      Text(deliveryLabel,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF10B981))),
                      const Spacer(),
                      Text('FOLIO ${order.folio}',
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFBDBDBD),
                              letterSpacing: 0.4)),
                    ],
                  ),
                  // Star rating (if available)
                  if (order.customerRating != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: List.generate(5, (i) {
                        return Icon(
                          i < order.customerRating!
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 14,
                          color: i < order.customerRating!
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFFDDDDDD),
                        );
                      }),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entregadoIconBox(OrderModel order) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: order.iconBgColor ?? const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(order.icon ?? Icons.local_florist,
          color: order.iconColor ?? Colors.black54, size: 28),
    );
  }

  Widget _buildStatusSectionHeader(OrderStatus status, int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: status.chipColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: status.chipColor.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(status.chipIcon, size: 13, color: status.chipColor),
                const SizedBox(width: 5),
                Text(status.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: status.chipColor,
                    )),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: status.chipColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$count',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Expanded(
            child: Divider(
              color: status.chipColor.withValues(alpha: 0.2),
              indent: 8,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRepartidorSheet(BuildContext context, OrderModel order) async {
    if (order.id == null) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final result = await showModalBottomSheet<AssignResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AssignRepartidorSheet(
        orderId: order.id!,
        shopId: user.id,
        currentRepartidorId: order.repartidorId,
        currentDeliveryAmount: order.deliveryAmount,
        shippingCost: order.shippingCost,
        autoTransferShipping: _autoTransferShipping,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        order.repartidorId = result.repartidorId;
        order.deliveryAmount = result.deliveryAmount;
        order.repartidorName = result.repartidorName;
      });
    }
  }

  void _showPhotoSheet(BuildContext context, OrderModel order) {
    if (order.id == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderPhotoSheet(
        order: order,
        orderRepo: _orderRepo,
        onPhotosUpdated: (urls) => setState(() => order.completionPhotos = urls),
      ),
    );
  }

  Future<void> _changeOrderStatus(
      OrderModel order, OrderStatus newStatus) async {
    if (order.id == null || newStatus == order.status) return;

    // 🔒 Payment gate for delivered
    if (newStatus == OrderStatus.delivered && !order.isPaid) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: const Row(
            children: [
              Icon(Icons.lock_outline, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Confirma el pago antes de marcar como Entregado.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          duration: const Duration(seconds: 3),
        ));
      return;
    }

    final success =
        await _orderRepo.updateOrderStatus(order.id!, newStatus);
    if (success && mounted) {
      setState(() => order.status = newStatus);
    }
  }

  String _formatDate(DateTime dt) {
    const meses = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(local.year, local.month, local.day);
    if (d == today) return 'Hoy';
    if (d == today.add(const Duration(days: 1))) return 'Mañana';
    if (d == today.subtract(const Duration(days: 1))) return 'Ayer';
    return '${local.day} de ${meses[local.month - 1]} de ${local.year}';
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour > 12 ? local.hour - 12 : local.hour == 0 ? 12 : local.hour;
    final m = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }

  Future<void> _openWhatsApp(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final url = Uri.parse('https://wa.me/52$clean');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir WhatsApp'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ─── Share Order ────────────────────────────────────────────────────────────

  void _shareOrder(OrderModel order) {
    Share.share(
      order.toShareMessage(isReceipt: false, shopName: _shopName),
      subject: 'Pedido ${order.folio} — $_shopName',
    );
  }
}

String _formatDateGlobal(DateTime dt) {
  const meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];
  final local = dt.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(local.year, local.month, local.day);
  if (d == today) return 'Hoy';
  if (d == today.add(const Duration(days: 1))) return 'Mañana';
  if (d == today.subtract(const Duration(days: 1))) return 'Ayer';
  return '${local.day} de ${meses[local.month - 1]} de ${local.year}';
}

String _formatTimeGlobal(DateTime dt) {
  final local = dt.toLocal();
  final h = local.hour > 12 ? local.hour - 12 : local.hour == 0 ? 12 : local.hour;
  final m = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '$h:$m $period';
}

extension OrderShareExtension on OrderModel {
  String toShareMessage({bool isReceipt = false, String shopName = 'Mi Florería'}) {
    final statusLabel = switch (status) {
      OrderStatus.waiting    => '⏳ En espera',
      OrderStatus.processing => '🔨 Elaborando',
      OrderStatus.inTransit  => '🚚 En tránsito',
      OrderStatus.delivered  => '✅ Entregado',
      OrderStatus.cancelled  => '❌ Cancelado',
    };
    final payLabel = isPaid ? '✅ Pagado' : '⏳ Pendiente de pago';
    final subtotal = price * quantity;
    final total = subtotal + shippingCost;
    
    final buf = StringBuffer();
    if (isReceipt) {
      buf.writeln('🌸 *Recibo de Pago — $shopName*');
      buf.writeln('━━━━━━━━━━━━━━━━━━━━');
    } else {
      buf.writeln('🌸 *$shopName*');
      buf.writeln('📦 *Detalle de Pedido $folio*');
      buf.writeln('─────────────────');
    }

    buf.writeln('👤 *Cliente:* $customerName');
    buf.writeln('📱 *Tel:* $customerPhone');
    buf.writeln();

    if (isReceipt) {
      buf.writeln('📦 *Folio:* $folio');
    }
    
    
    try {
      final List<dynamic> productsData = jsonDecode(productName);
      for (var p in productsData) {
        final name = p['name'] as String? ?? 'Producto';
        final qty = p['qty'] as int? ?? 1;
        buf.writeln('🌷 *Producto:* ${qty}× $name');
      }
    } catch (e) {
      buf.writeln('🌷 *Producto:* ${quantity}× $productName');
    }
    
    buf.writeln('💰 *Precio u.:* ${CurrencyCache.symbol}${price.toStringAsFixed(2)} ${CurrencyCache.code}');
    buf.writeln('💵 *Subtotal:* ${CurrencyCache.symbol}${subtotal.toStringAsFixed(2)} ${CurrencyCache.code}');
    if (shippingCost > 0) {
      buf.writeln('🛵 *Costo envío:* ${CurrencyCache.symbol}${shippingCost.toStringAsFixed(2)} ${CurrencyCache.code}');
    }
    if (isReceipt) {
      buf.writeln('💵 *Total pagado:* ${CurrencyCache.symbol}${total.toStringAsFixed(2)} ${CurrencyCache.code}');
    } else {
      buf.writeln('💳 *Total:* ${CurrencyCache.symbol}${total.toStringAsFixed(2)} ${CurrencyCache.code}');
    }
    buf.writeln();
    
    final sDate = _formatDateGlobal(createdAt);
    final sTime = _formatTimeGlobal(createdAt);

    if (isReceipt) {
      if (isPaid && paymentMethod != null) {
        buf.writeln('💳 *Forma de pago:* $paymentMethod');
      }
      buf.writeln('📅 *Fecha:* $sDate  $sTime');
    } else {
      buf.writeln('📅 *Fecha de venta:* $sDate, $sTime');
    }

    buf.writeln('🚚 *Método de entrega:* $deliveryMethod');
    buf.writeln('🕒 *Fecha y rango de entrega:* $deliveryInfo');
    if (deliveryMethod.toLowerCase() != 'recoger en tienda') {
      if (deliveryLocationType != null) buf.writeln('📍 *Lugar de entrega:* $deliveryLocationType');
      if (deliveryAddress != null) buf.writeln('📍 *Dirección:* $deliveryAddress');
      if (deliveryReferences != null) buf.writeln('📍 *Referencias:* $deliveryReferences');
    }
    buf.writeln();
    
    if (recipientName != null) buf.writeln('🎁 *Destinataria:* $recipientName');
    if (recipientPhone != null) buf.writeln('📱 *Tel destinataria:* $recipientPhone');
    if (dedicationMessage != null) buf.writeln('🎀 *Dedicatoria:* $dedicationMessage');
    buf.writeln('🕵️ *Anónimo:* ${isAnonymous ? "Sí" : "No"}');
    buf.writeln();
    
    if (!isReceipt) {
      buf.writeln('📋 *Estado:* $statusLabel');
      buf.writeln('💳 *Pago:* $payLabel');
      if (isPaid && paymentMethod != null) {
        buf.writeln('💰 *Forma de pago:* $paymentMethod');
      }
      buf.writeln('─────────────────');
    } else {
      buf.writeln('━━━━━━━━━━━━━━━━━━━━');
    }
    
    buf.write('¡Gracias por tu compra! 🌹\nwww.tusflores.app/floreria-las-rosas');
    return buf.toString();
  }
}

// ── Bottom sheet: fotos del arreglo terminado ─────────────────────────────────

class _OrderPhotoSheet extends StatefulWidget {
  final OrderModel order;
  final OrderRepository orderRepo;
  final ValueChanged<List<String>> onPhotosUpdated;

  const _OrderPhotoSheet({
    required this.order,
    required this.orderRepo,
    required this.onPhotosUpdated,
  });

  @override
  State<_OrderPhotoSheet> createState() => _OrderPhotoSheetState();
}

class _OrderPhotoSheetState extends State<_OrderPhotoSheet> {
  late final List<String?> _slots;
  final _picker = ImagePicker();
  final _uploading = [false, false, false];
  static const _pink = Color(0xFFE91E8C);

  @override
  void initState() {
    super.initState();
    final photos = widget.order.completionPhotos;
    _slots = List.generate(3, (i) => i < photos.length ? photos[i] : null);
  }

  Future<void> _pickPhoto(int index) async {
    if (kIsWeb) {
      // En web usamos un <input type="file"> nativo creado y clickeado de forma
      // SÍNCRONA dentro del gesto del usuario. Esto evita que iOS Safari bloquee
      // el file picker (popup blocker) y evita la pantalla negra de la cámara
      // que ocurría con image_picker_for_web (que pasa por el event loop de
      // Flutter antes de disparar el click, perdiendo el contexto del gesto).
      _pickPhotoWeb(index);
      return;
    }

    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar foto'),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.camera_alt_outlined, color: _pink),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library_outlined, color: _pink),
              title: const Text('Elegir de fototeca'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1200,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploading[index] = true);

    final Uint8List bytes = await picked.readAsBytes();
    final url = await widget.orderRepo.uploadOrderPhoto(
      widget.order.shopId,
      widget.order.id!,
      index + 1,
      bytes,
    );

    if (url != null) {
      _slots[index] = url;
      final urls = _slots.whereType<String>().toList();
      await widget.orderRepo.updateCompletionPhotos(widget.order.id!, urls);
      widget.onPhotosUpdated(urls);
    }

    if (mounted) setState(() => _uploading[index] = false);
  }

  /// Abre directamente el overlay de cámara sin bottom sheet intermedio.
  /// getUserMedia debe invocarse sincrónicamente dentro del gesto del usuario;
  /// cualquier Navigator.pop / await previo rompe ese contexto en iOS y provoca
  /// denegación de permiso silenciosa. La opción "Fototeca" está dentro del
  /// propio overlay HTML.
  void _pickPhotoWeb(int index) {
    _openCameraOverlay(index);
  }

  /// Abre el selector de archivos nativo del sistema para elegir una imagen.
  /// El .click() se dispara sincrónicamente dentro del onTap del ListTile.
  void _pickFromFileInput(int index) {
    final input = html.InputElement()
      ..type = 'file'
      ..accept = 'image/*';
    input.style.display = 'none';
    html.document.body?.append(input);

    StreamSubscription? sub;
    sub = input.onChange.listen((_) async {
      sub?.cancel();
      final file = input.files?.first;
      input.remove();

      if (file == null || !mounted) return;
      setState(() => _uploading[index] = true);

      try {
        final completer = Completer<Uint8List?>();
        final reader = html.FileReader();
        reader.onLoadEnd.listen((_) {
          final result = reader.result;
          if (result is Uint8List) {
            completer.complete(result);
          } else if (result is ByteBuffer) {
            completer.complete(result.asUint8List());
          } else {
            completer.complete(null);
          }
        });
        reader.readAsArrayBuffer(file);

        final bytes = await completer.future;
        if (bytes == null || !mounted) return;

        final url = await widget.orderRepo.uploadOrderPhoto(
          widget.order.shopId,
          widget.order.id!,
          index + 1,
          bytes,
        );

        if (url != null && mounted) {
          _slots[index] = url;
          final urls = _slots.whereType<String>().toList();
          await widget.orderRepo.updateCompletionPhotos(widget.order.id!, urls);
          widget.onPhotosUpdated(urls);
        }
      } catch (e) {
        debugPrint('[photo] Error al procesar imagen: $e');
      } finally {
        if (mounted) setState(() => _uploading[index] = false);
      }
    });

    input.click();
  }

  /// Muestra un overlay HTML full-screen con el stream de cámara en vivo.
  /// Usa getUserMedia (llamado sincrónicamente dentro del gesto del usuario)
  /// para obtener permiso de cámara y mostrar el preview. El usuario ve el
  /// arreglo floral en tiempo real y toca el botón para capturar el frame.
  void _openCameraOverlay(int index) {
    final overlay = html.DivElement()
      ..id = 'tf-camera-overlay'
      ..setAttribute(
        'style',
        'position:fixed;top:0;left:0;width:100%;height:100%;'
        'background:#000;z-index:999999;display:flex;'
        'flex-direction:column;align-items:center;overflow:hidden;'
        '-webkit-user-select:none;user-select:none;',
      );

    final video = html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..setAttribute('playsinline', '')
      ..setAttribute(
        'style',
        'width:100%;flex:1;object-fit:cover;max-height:calc(100vh - 150px);',
      );

    final bar = html.DivElement()
      ..setAttribute(
        'style',
        'display:flex;flex-direction:column;align-items:center;'
        'padding:16px 0 40px;gap:14px;width:100%;',
      );

    // Botón circular de captura (estilo cámara nativa)
    final captureBtn = html.DivElement()
      ..setAttribute(
        'style',
        'width:72px;height:72px;border-radius:50%;background:white;'
        'border:5px solid rgba(255,255,255,0.45);cursor:pointer;'
        'box-shadow:0 3px 12px rgba(0,0,0,0.5);',
      );

    const btnStyle =
        'padding:10px 20px;font-size:15px;color:white;cursor:pointer;'
        'border:1px solid rgba(255,255,255,0.55);border-radius:50px;'
        'font-family:-apple-system,BlinkMacSystemFont,sans-serif;';

    final galleryBtn = html.DivElement()
      ..innerText = 'Fototeca'
      ..setAttribute('style', btnStyle);

    final cancelBtn = html.DivElement()
      ..innerText = 'Cancelar'
      ..setAttribute('style', btnStyle);

    final btnRow = html.DivElement()
      ..setAttribute(
        'style',
        'display:flex;gap:16px;align-items:center;justify-content:center;',
      );
    btnRow..append(galleryBtn)..append(cancelBtn);

    bar..append(captureBtn)..append(btnRow);
    overlay
      ..append(video)
      ..append(bar);
    html.document.body?.append(overlay);

    html.MediaStream? activeStream;

    void stopAndRemove() {
      activeStream?.getTracks().forEach((t) => t.stop());
      overlay.remove();
    }

    cancelBtn.onClick.listen((_) => stopAndRemove());

    galleryBtn.onClick.listen((_) {
      stopAndRemove();
      _pickFromFileInput(index);
    });

    captureBtn.onClick.listen((_) {
      final w = (video.videoWidth > 0 ? video.videoWidth : 1280).toInt();
      final h = (video.videoHeight > 0 ? video.videoHeight : 720).toInt();

      final canvas = html.CanvasElement(width: w, height: h);
      canvas.context2D.drawImage(video, 0, 0);
      stopAndRemove();

      _processCanvasCapture(canvas, index);
    });

    // getUserMedia es invocado sincrónicamente aquí (dentro del contexto
    // del gesto del usuario) — la Promise se crea de inmediato aunque el
    // resultado llegue de forma asíncrona vía .then()/.catchError().
    final mediaDevices = html.window.navigator.mediaDevices;
    if (mediaDevices == null) {
      stopAndRemove();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Cámara no disponible en este navegador.')),
        );
      }
      return;
    }

    // Intenta primero con cámara trasera; si falla, reintenta con cualquier
    // cámara disponible; si sigue fallando, muestra el diálogo de ayuda.
    void tryCamera(bool preferRear) {
      final constraints = preferRear
          ? {'video': {'facingMode': 'environment'}, 'audio': false}
          : {'video': true, 'audio': false};

      mediaDevices.getUserMedia(constraints).then((stream) {
        activeStream = stream;
        video.srcObject = stream;
      }).catchError((_) {
        if (preferRear) {
          tryCamera(false);
        } else {
          stopAndRemove();
          _showCameraPermissionHelp(index);
        }
      });
    }

    tryCamera(true);
  }

  void _showCameraPermissionHelp(int index) {
    if (!mounted) return;
    final ua = html.window.navigator.userAgent.toLowerCase();
    final browser = ua.contains('crios') ? 'Chrome' : 'Safari';
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cámara sin permiso'),
        content: Text(
          'iOS bloqueó el acceso a la cámara de $browser.\n\n'
          'Para activarla:\n'
          '1. Cierra el navegador\n'
          '2. Abre Ajustes de iPhone\n'
          '3. Busca "$browser"\n'
          '4. Toca "Cámara" → "Permitir"\n'
          '5. Regresa y vuelve a intentarlo\n\n'
          'O usa la Fototeca para subir una foto ya tomada.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _pickFromFileInput(index);
            },
            child: const Text('Usar Fototeca'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  /// Extrae los bytes JPEG del canvas capturado y los sube a Supabase.
  Future<void> _processCanvasCapture(
      html.CanvasElement canvas, int index) async {
    if (!mounted) return;
    setState(() => _uploading[index] = true);

    try {
      // toDataUrl devuelve "data:image/jpeg;base64,<datos>"
      final dataUrl = canvas.toDataUrl('image/jpeg', 0.85);
      final base64Data = dataUrl.split(',').last;
      final bytes = Uint8List.fromList(base64Decode(base64Data));

      final url = await widget.orderRepo.uploadOrderPhoto(
        widget.order.shopId,
        widget.order.id!,
        index + 1,
        bytes,
      );

      if (url != null && mounted) {
        _slots[index] = url;
        final urls = _slots.whereType<String>().toList();
        await widget.orderRepo.updateCompletionPhotos(widget.order.id!, urls);
        widget.onPhotosUpdated(urls);
      }
    } catch (e) {
      debugPrint('[photo] Error al procesar captura: $e');
    } finally {
      if (mounted) setState(() => _uploading[index] = false);
    }
  }

  Future<void> _deletePhoto(int index) async {
    setState(() => _slots[index] = null);
    final urls = _slots.whereType<String>().toList();
    await widget.orderRepo.updateCompletionPhotos(widget.order.id!, urls);
    widget.onPhotosUpdated(urls);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFDF6F0),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Fotos del arreglo terminado',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E))),
          const SizedBox(height: 6),
          const Text(
            'Tus clientes verán estas fotos al consultar el estado de su pedido.',
            style: TextStyle(fontSize: 13, color: Color(0xFF888899)),
          ),
          const SizedBox(height: 20),
          Row(
            children: List.generate(
              3,
              (i) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 2 ? 12 : 0),
                  child: _buildSlot(i),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _pink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Listo',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 8),
        ],
      ),
    );
  }

  Widget _buildSlot(int index) {
    final url = _slots[index];
    final uploading = _uploading[index];

    return GestureDetector(
      onTap: () => _pickPhoto(index),
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: url != null
                  ? _pink.withValues(alpha: 0.4)
                  : Colors.grey.withValues(alpha: 0.25),
              width: url != null ? 2 : 1,
            ),
          ),
          child: uploading
              ? const Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _pink))
              : url != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(url, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: GestureDetector(
                            onTap: () => _deletePhoto(index),
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  size: 13, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined,
                            size: 28, color: Colors.grey[400]),
                        const SizedBox(height: 6),
                        Text('Foto ${index + 1}',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[400],
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
        ),
      ),
    );
  }
}
