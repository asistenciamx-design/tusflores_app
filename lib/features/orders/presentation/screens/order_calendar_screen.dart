import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/order_model.dart';
import '../../domain/repositories/order_repository.dart';
import 'edit_order_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────

class OrderCalendarScreen extends StatefulWidget {
  const OrderCalendarScreen({super.key});

  @override
  State<OrderCalendarScreen> createState() => _OrderCalendarScreenState();
}

class _OrderCalendarScreenState extends State<OrderCalendarScreen> {
  final _orderRepo = OrderRepository();
  List<OrderModel> _allOrders = [];
  bool _isLoading = true;

  int _selectedTab = 0; // 0 = Pendientes, 1 = Entregados
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDate;
  DateTimeRange? _selectedRange;

  static const _meses = [
    'ENERO', 'FEBRERO', 'MARZO', 'ABRIL', 'MAYO', 'JUNIO',
    'JULIO', 'AGOSTO', 'SEPTIEMBRE', 'OCTUBRE', 'NOVIEMBRE', 'DICIEMBRE',
  ];

  static const _mesesLabel = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final orders = await _orderRepo.getOrders(user.id);
    if (mounted) setState(() { _allOrders = orders; _isLoading = false; });
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  OrderStatus get _activeStatus =>
      _selectedTab == 0 ? OrderStatus.pending : OrderStatus.delivered;

  List<OrderModel> get _tabOrders =>
      _allOrders.where((o) => o.status == _activeStatus).toList();

  /// Orders in the focused month (by saleDate).
  List<OrderModel> get _monthOrders => _tabOrders.where((o) {
        final d = o.saleDate;
        return d.year == _focusedMonth.year && d.month == _focusedMonth.month;
      }).toList();

  /// Count of orders for a specific day.
  int _countForDay(DateTime day) => _tabOrders.where((o) {
        final d = o.saleDate;
        return d.year == day.year && d.month == day.month && d.day == day.day;
      }).length;

  /// Orders to show in the list section.
  List<OrderModel> get _listOrders {
    if (_selectedRange != null) {
      final start = _selectedRange!.start;
      final end = _selectedRange!.end.add(const Duration(hours: 23, minutes: 59));
      return _tabOrders.where((o) {
        return o.saleDate.isAfter(start.subtract(const Duration(minutes: 1))) &&
            o.saleDate.isBefore(end.add(const Duration(minutes: 1)));
      }).toList()
        ..sort((a, b) => a.saleDate.compareTo(b.saleDate));
    }
    if (_selectedDate != null) {
      return _tabOrders.where((o) {
        final d = o.saleDate;
        return d.year == _selectedDate!.year &&
            d.month == _selectedDate!.month &&
            d.day == _selectedDate!.day;
      }).toList()
        ..sort((a, b) => a.saleDate.compareTo(b.saleDate));
    }
    return _monthOrders..sort((a, b) => a.saleDate.compareTo(b.saleDate));
  }

  double get _monthTotal =>
      _monthOrders.fold(0.0, (s, o) => s + o.price + o.shippingCost);

  String _listTitle() {
    if (_selectedRange != null) {
      final s = _selectedRange!.start;
      final e = _selectedRange!.end;
      return '${s.day} ${_mesesLabel[s.month - 1]} – ${e.day} ${_mesesLabel[e.month - 1]}';
    }
    if (_selectedDate != null) {
      return '${_selectedDate!.day} de ${_mesesLabel[_selectedDate!.month - 1]}';
    }
    return _selectedTab == 0 ? 'Pendientes' : 'Entregados';
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      initialDateRange: _selectedRange,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppTheme.primary,
            onPrimary: Colors.white,
            onSurface: AppTheme.textLight,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedRange = picked;
        _selectedDate = null;
        // Navigate to the range's start month
        _focusedMonth = DateTime(picked.start.year, picked.start.month);
      });
    }
  }

  String _formatDateLabel(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return 'Hoy';
    }
    return '${dt.day} de ${_mesesLabel[dt.month - 1]}, ${dt.year}';
  }

  String _productLabel(OrderModel o) {
    try {
      final list = jsonDecode(o.productName) as List<dynamic>;
      if (list.length == 1) {
        return '${list[0]['qty']}× ${list[0]['name']}';
      }
      return '${list.length} productos';
    } catch (_) {
      return '${o.quantity}× ${o.productName}';
    }
  }

  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader()),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _buildOrderTile(_listOrders[i]),
                        childCount: _listOrders.length,
                      ),
                    ),
                  ),
                  if (_listOrders.isEmpty)
                    SliverFillRemaining(child: _buildEmpty()),
                ],
              ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Title bar
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 20, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  color: AppTheme.textLight,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Text(
                  'Calendario de Pedidos',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textLight,
                  ),
                ),
              ],
            ),
          ),

          // Tabs
          const SizedBox(height: 10),
          Row(
            children: [
              _buildTab(0, 'Pendientes'),
              _buildTab(1, 'Entregados'),
            ],
          ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 16),

          // Month navigation
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _navArrow(Icons.chevron_left, () => setState(() {
                  _focusedMonth = DateTime(
                      _focusedMonth.year, _focusedMonth.month - 1);
                  _selectedDate = null;
                  _selectedRange = null;
                })),
                Text(
                  '${_meses[_focusedMonth.month - 1]} ${_focusedMonth.year}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 1.2,
                    color: AppTheme.mutedLight,
                  ),
                ),
                _navArrow(Icons.chevron_right, () => setState(() {
                  _focusedMonth = DateTime(
                      _focusedMonth.year, _focusedMonth.month + 1);
                  _selectedDate = null;
                  _selectedRange = null;
                })),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Summary cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildSummaryCard(),
          ),
          const SizedBox(height: 16),

          // Calendar grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildCalendar(),
          ),
          const SizedBox(height: 16),

          // Date range button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildRangeButton(),
          ),
          const SizedBox(height: 16),

          // List header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _listTitle(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textLight,
                  ),
                ),
                if (_selectedDate != null || _selectedRange != null)
                  GestureDetector(
                    onTap: () => setState(() {
                      _selectedDate = null;
                      _selectedRange = null;
                    }),
                    child: Text(
                      'Ver todos',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String label) {
    final selected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedTab = index;
          _selectedDate = null;
          _selectedRange = null;
        }),
        child: Container(
          padding: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? AppTheme.primary : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? AppTheme.primary : const Color(0xFFB0B0B0),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navArrow(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppTheme.primary, size: 20),
        ),
      );

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0F0F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL PEDIDOS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_monthOrders.length}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textLight,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 40, color: const Color(0xFFF0F0F0)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'TOTAL VENTAS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${_monthTotal.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Calendar grid ────────────────────────────────────────────────────────

  Widget _buildCalendar() {
    const weekDays = ['LU', 'MA', 'MI', 'JU', 'VI', 'SA', 'DO'];
    // First day of the focused month (adjust to Monday-start week)
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDay = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    // weekday: 1=Mon … 7=Sun
    final startOffset = firstDay.weekday - 1; // blanks before day 1
    final totalCells = startOffset + lastDay.day;
    final rows = (totalCells / 7).ceil();
    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0F0F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Weekday header
          Row(
            children: weekDays.map((d) {
              final isWeekend = d == 'SA' || d == 'DO';
              return Expanded(
                child: Text(
                  d,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isWeekend
                        ? AppTheme.primary.withValues(alpha: 0.6)
                        : Colors.grey.shade400,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          // Day cells
          ...List.generate(rows, (row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: List.generate(7, (col) {
                  final cellIndex = row * 7 + col;
                  final dayNum = cellIndex - startOffset + 1;
                  if (dayNum < 1 || dayNum > lastDay.day) {
                    return const Expanded(child: SizedBox(height: 44));
                  }
                  final day = DateTime(_focusedMonth.year, _focusedMonth.month, dayNum);
                  final count = _countForDay(day);
                  final isSelected = _selectedDate != null &&
                      _selectedDate!.year == day.year &&
                      _selectedDate!.month == day.month &&
                      _selectedDate!.day == day.day;
                  final isToday = day.year == today.year &&
                      day.month == today.month &&
                      day.day == today.day;
                  final isWeekend = day.weekday == 6 || day.weekday == 7;
                  // In range?
                  final inRange = _selectedRange != null &&
                      !day.isBefore(_selectedRange!.start) &&
                      !day.isAfter(_selectedRange!.end);

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _selectedRange = null;
                        _selectedDate = isSelected ? null : day;
                      }),
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          // Day cell background
                          Container(
                            height: 44,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primary
                                  : inRange
                                      ? AppTheme.primary.withValues(alpha: 0.12)
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                '$dayNum',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected || isToday
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : isToday
                                          ? AppTheme.primaryDark
                                          : isWeekend
                                              ? Colors.grey.shade400
                                              : AppTheme.textLight,
                                ),
                              ),
                            ),
                          ),
                          // Order count badge
                          if (count > 0)
                            Positioned(
                              top: 2,
                              right: 4,
                              child: Container(
                                width: 17,
                                height: 17,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF34D399),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppTheme.primary
                                        : Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '$count',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? AppTheme.primaryDark
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Date range button ────────────────────────────────────────────────────

  Widget _buildRangeButton() {
    final hasRange = _selectedRange != null;
    return GestureDetector(
      onTap: _pickDateRange,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: hasRange
              ? AppTheme.primary.withValues(alpha: 0.15)
              : AppTheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.primary.withValues(alpha: hasRange ? 0.5 : 0.2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.date_range_rounded,
                color: AppTheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              hasRange
                  ? '${_selectedRange!.start.day}/${_selectedRange!.start.month} – ${_selectedRange!.end.day}/${_selectedRange!.end.month}'
                  : 'Seleccionar rango de fechas',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
            if (hasRange) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _selectedRange = null),
                child: Icon(Icons.close_rounded,
                    color: AppTheme.primary, size: 18),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Order tile ───────────────────────────────────────────────────────────

  Widget _buildOrderTile(OrderModel order) {
    final isPending = order.status == OrderStatus.pending;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EditOrderScreen(order: order)),
      ).then((_) => _loadOrders()),
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF0F0F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.shopping_bag_rounded,
                  color: AppTheme.primary, size: 22),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pedido: ${order.folio}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textLight,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _productLabel(order),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatDateLabel(order.saleDate),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
            // Amount + badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${(order.price + order.shippingCost).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textLight,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isPending
                        ? AppTheme.primary.withValues(alpha: 0.12)
                        : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isPending ? 'PENDIENTE' : 'ENTREGADO',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isPending
                          ? AppTheme.primaryDark
                          : const Color(0xFF166534),
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

  Widget _buildEmpty() {
    return Container(
      color: const Color(0xFFF5F5F5),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 52, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              _selectedDate != null
                  ? 'Sin pedidos este día'
                  : _selectedRange != null
                      ? 'Sin pedidos en este rango'
                      : 'Sin pedidos este mes',
              style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
