import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import 'edit_order_screen.dart';
import 'confirm_payment_screen.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/order_model.dart';
import '../../domain/repositories/order_repository.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  // Date filter
  final List<String> _dateFilters = ['Ayer', 'Hoy', 'Mañana', '7 días', '15 días'];
  int _selectedDateIndex = 1; // "Hoy" selected by default

  int _selectedTab = 0; // 0 = Pendientes, 1 = Entregados

  // Custom date range
  DateTimeRange? _customDateRange;

  // Orders as mutable state
  List<OrderModel> _orders = [];
  final _orderRepo = OrderRepository();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final fetched = await _orderRepo.getOrders(user.id);
      _orders = fetched;
    }
    if (mounted) setState(() => _isLoading = false);
  }

  List<OrderModel> get _filteredOrders {
    var filtered = _orders.where((o) => o.status == (_selectedTab == 0 ? OrderStatus.pending : OrderStatus.delivered)).toList();
    
    // Apply date filtering
    if (_customDateRange != null) {
      filtered = filtered.where((o) {
        final d = o.saleDate;
        final start = _customDateRange!.start;
        // end time should be the end of the day
        final end = _customDateRange!.end.add(const Duration(hours: 23, minutes: 59));
        return d.isAfter(start.subtract(const Duration(minutes: 1))) && d.isBefore(end.add(const Duration(minutes: 1)));
      }).toList();
    } else {
      // Logic for the predefined chips (Ayer, Hoy, Mañana, 7 días, 15 días)
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      filtered = filtered.where((o) {
        final d = o.saleDate;
        final oDate = DateTime(d.year, d.month, d.day);
        
        if (_selectedDateIndex == 0) return oDate == today.subtract(const Duration(days: 1)); // Ayer
        if (_selectedDateIndex == 1) return oDate == today; // Hoy
        if (_selectedDateIndex == 2) return oDate == today.add(const Duration(days: 1)); // Mañana
        if (_selectedDateIndex == 3) return oDate.isAfter(today.subtract(const Duration(days: 7))); // 7 días
        if (_selectedDateIndex == 4) return oDate.isAfter(today.subtract(const Duration(days: 15))); // 15 días
        return true;
      }).toList();
    }
    
    return filtered;
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      initialDateRange: _customDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              onSurface: AppTheme.textLight,
            ),
          ),
          child: child!,
        );
      },
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  : _filteredOrders.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          itemCount: _filteredOrders.length,
                          itemBuilder: (_, i) => _buildOrderCard(_filteredOrders[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          const Text(
            'Mis Pedidos',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppTheme.textLight,
            ),
          ),
          const SizedBox(height: 14),

          // Date filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_dateFilters.length, (i) {
                final selected = i == _selectedDateIndex;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedDateIndex = i;
                    _customDateRange = null; // Clear custom range
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
                      _dateFilters[i],
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

          // Date range selector
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
                        _selectedDateIndex = 1; // back to Hoy
                      }),
                      child: const Icon(Icons.close, color: Color(0xFF9E9E9E), size: 22),
                    )
                  else
                    const Icon(Icons.keyboard_arrow_down, color: Color(0xFF9E9E9E), size: 22),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Status tabs
          Row(
            children: [
              _buildStatusTab(0, 'Pendientes'),
              const SizedBox(width: 4),
              _buildStatusTab(1, 'Entregados'),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStatusTab(int index, String label) {
    final selected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: selected ? AppTheme.primary : const Color(0xFF9E9E9E),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Order Card ─────────────────────────────────────────────────────────────

  Widget _buildOrderCard(OrderModel order) {
    return Container(
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
            // Top row: time + folio
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _timeAgo(order.createdAt),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                ),
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
            const SizedBox(height: 12),

            // Product row
            Row(
              children: [
                // Product icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: order.iconBgColor ?? const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(order.icon ?? Icons.local_florist, color: order.iconColor ?? const Color(0xFFFFA726), size: 28),
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
                        '\$${order.price.toStringAsFixed(0)} MXN',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Venta: ${_formatDate(order.saleDate)}, ${_formatTime(order.saleDate)}',
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

            const SizedBox(height: 14),

            // Action row
            Row(
              children: [
                // WhatsApp
                GestureDetector(
                  onTap: () => _openWhatsApp(order.customerPhone),
                  child: _iconBtn(Icons.chat, const Color(0xFF25D366)),
                ),
                const SizedBox(width: 8),
                // Share order
                GestureDetector(
                  onTap: () => _shareOrder(order),
                  child: _iconBtn(Icons.ios_share, AppTheme.primary),
                ),
                const SizedBox(width: 8),
                // Edit
                GestureDetector(
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => EditOrderScreen(order: order))),
                  child: _iconBtn(Icons.edit, const Color(0xFF9E9E9E)),
                ),
                const SizedBox(width: 10),
                // Pagado chip
                GestureDetector(
                  onTap: () async {
                    if (order.id == null) return;
                    final result = await Navigator.push<String>(context,
                      MaterialPageRoute(builder: (_) =>
                        ConfirmPaymentScreen(
                          order: order,
                        )));
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
                    icon: Icons.account_balance_wallet,
                    label: order.isPaid
                        ? (order.paymentMethod != null ? '\u2713 ${order.paymentMethod}' : 'Pagado')
                        : 'Pend. pago',
                    color: order.isPaid ? AppTheme.primary : Colors.orange,
                    outlined: true,
                  ),
                ),
                const SizedBox(width: 8),
                // Entregado button
                Expanded(
                  child: GestureDetector(
                    onTap: order.status == OrderStatus.pending
                        ? () async {
                            if (order.id == null) return;
                            final success = await _orderRepo.updateOrderStatus(order.id!, OrderStatus.delivered);
                            if (success && mounted) {
                              setState(() => order.status = OrderStatus.delivered);
                            }
                          }
                        : null,
                    child: _actionButton(
                      order.status == OrderStatus.delivered ? Icons.check_circle : Icons.local_shipping_outlined,
                      'Entregado',
                      AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _statusChip({required IconData icon, required String label, required Color color, bool outlined = false}) {
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
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
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
            _selectedTab == 0 ? 'Sin pedidos pendientes' : 'Sin pedidos entregados',
            style: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    return 'Hace ${diff.inDays} día(s)';
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day) return 'Hoy';
    if (dt.day == now.day + 1) return 'Mañana';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
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
      order.toShareMessage(isReceipt: false),
      subject: 'Pedido ${order.folio} — Florería Las Rosas',
    );
  }
}

String _formatDateGlobal(DateTime dt) {
  final now = DateTime.now();
  if (dt.day == now.day && dt.month == now.month && dt.year == now.year) return 'Hoy';
  if (dt.day == now.day + 1 && dt.month == now.month && dt.year == now.year) return 'Mañana';
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}

String _formatTimeGlobal(DateTime dt) {
  final h = dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
  final m = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  return '$h:$m $period';
}

extension OrderShareExtension on OrderModel {
  String toShareMessage({bool isReceipt = false}) {
    final statusLabel = status == OrderStatus.delivered ? '✅ Entregado' : '⏳ Pendiente';
    final payLabel = isPaid ? '✅ Pagado' : '⏳ Pendiente de pago';
    final subtotal = price * quantity;
    final total = subtotal + shippingCost;
    
    final buf = StringBuffer();
    if (isReceipt) {
      buf.writeln('🌸 *Recibo de Pago — Florería Las Rosas*');
      buf.writeln('━━━━━━━━━━━━━━━━━━━━');
    } else {
      buf.writeln('🌸 *Florería Las Rosas*');
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
    
    buf.writeln('💰 *Precio u.:* \$${price.toStringAsFixed(2)} MXN');
    buf.writeln('💵 *Subtotal:* \$${subtotal.toStringAsFixed(2)} MXN');
    if (shippingCost > 0) {
      buf.writeln('🛵 *Costo envío:* \$${shippingCost.toStringAsFixed(2)} MXN');
    }
    if (isReceipt) {
      buf.writeln('💵 *Total pagado:* \$${total.toStringAsFixed(2)} MXN');
    } else {
      buf.writeln('💳 *Total:* \$${total.toStringAsFixed(2)} MXN');
    }
    buf.writeln();
    
    final sDate = _formatDateGlobal(saleDate);
    final sTime = _formatTimeGlobal(saleDate);

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
    
    buf.write('¡Gracias por tu compra! 🌹\ntusflores.app/floreria-las-rosas');
    return buf.toString();
  }
}
