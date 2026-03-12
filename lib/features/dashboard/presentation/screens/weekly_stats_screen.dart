import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../orders/domain/models/order_model.dart';
import '../../../orders/domain/repositories/order_repository.dart';

class WeeklyStatsScreen extends StatefulWidget {
  const WeeklyStatsScreen({super.key});

  @override
  State<WeeklyStatsScreen> createState() => _WeeklyStatsScreenState();
}

class _WeeklyStatsScreenState extends State<WeeklyStatsScreen> {
  // 0=Ayer  1=Hoy  2=7 días  3=Mes
  int _selectedPeriod = 2;
  final List<String> _periods = ['Ayer', 'Hoy', '7 días', 'Mes'];

  bool _isLoading = true;
  String? _shopId;
  List<OrderModel> _allOrders = [];
  DateTimeRange? _customRange;

  @override
  void initState() {
    super.initState();
    _shopId = Supabase.instance.client.auth.currentUser?.id;
    _loadData();
  }

  Future<void> _loadData() async {
    if (_shopId == null) return;
    setState(() => _isLoading = true);
    try {
      _allOrders = await OrderRepository().getOrders(_shopId!);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  // ── Date ranges ────────────────────────────────────────────────────────────

  DateTimeRange get _dateRange {
    if (_customRange != null) return _customRange!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_selectedPeriod) {
      case 0: // Ayer
        return DateTimeRange(
          start: today.subtract(const Duration(days: 1)),
          end: today,
        );
      case 1: // Hoy
        return DateTimeRange(
          start: today,
          end: today.add(const Duration(days: 1)),
        );
      case 3: // Mes
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: today.add(const Duration(days: 1)),
        );
      case 2: // 7 días (default)
      default:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 6)),
          end: today.add(const Duration(days: 1)),
        );
    }
  }

  DateTimeRange get _previousDateRange {
    final r = _dateRange;
    final duration = r.end.difference(r.start);
    return DateTimeRange(
      start: r.start.subtract(duration),
      end: r.start,
    );
  }

  // ── Filtered orders ────────────────────────────────────────────────────────

  List<OrderModel> _filterOrders(DateTimeRange range) => _allOrders
      .where((o) =>
          !o.saleDate.isBefore(range.start) &&
          o.saleDate.isBefore(range.end) &&
          o.status != OrderStatus.cancelled)
      .toList();

  List<OrderModel> get _ordersInPeriod => _filterOrders(_dateRange);
  List<OrderModel> get _ordersInPreviousPeriod =>
      _filterOrders(_previousDateRange);

  // ── KPIs ──────────────────────────────────────────────────────────────────

  double get _totalSales =>
      _ordersInPeriod.fold(0.0, (s, o) => s + o.total);

  double get _previousTotal =>
      _ordersInPreviousPeriod.fold(0.0, (s, o) => s + o.total);

  double get _changePercent {
    if (_previousTotal == 0) return 0;
    return ((_totalSales - _previousTotal) / _previousTotal) * 100;
  }

  // ── Chart: last-7-days daily sales ────────────────────────────────────────

  List<double> get _last7DaysSales {
    final today = DateTime.now();
    return List.generate(7, (i) {
      final day = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: 6 - i));
      final nextDay = day.add(const Duration(days: 1));
      return _allOrders
          .where((o) =>
              !o.saleDate.isBefore(day) &&
              o.saleDate.isBefore(nextDay) &&
              o.status != OrderStatus.cancelled)
          .fold(0.0, (s, o) => s + o.total);
    });
  }

  List<String> get _last7DayLabels {
    const abbr = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    final today = DateTime.now();
    return List.generate(7, (i) {
      final day = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: 6 - i));
      return abbr[day.weekday - 1]; // weekday: 1=Mon … 7=Sun
    });
  }

  // ── Best sellers ──────────────────────────────────────────────────────────

  List<_BestSeller> get _bestSellers {
    final map = <String, int>{};
    for (final o in _ordersInPeriod) {
      map[o.productName] = (map[o.productName] ?? 0) + o.quantity;
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(3).map((e) => _BestSeller(e.key, e.value)).toList();
  }

  // ── Orders by status ──────────────────────────────────────────────────────

  Map<OrderStatus, int> get _ordersByStatus {
    final map = <OrderStatus, int>{};
    final r = _dateRange;
    for (final o in _allOrders.where((o) =>
        !o.saleDate.isBefore(r.start) && o.saleDate.isBefore(r.end))) {
      map[o.status] = (map[o.status] ?? 0) + 1;
    }
    return map;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: Colors.grey[100], shape: BoxShape.circle),
            child: const Icon(Icons.arrow_back_ios_new,
                size: 16, color: AppTheme.textLight),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Estadísticas',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: AppTheme.textLight)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.mutedLight),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPeriodTabs(),
                    const SizedBox(height: 16),
                    _buildDateRangePicker(context),
                    const SizedBox(height: 20),
                    _buildSalesCard(),
                    const SizedBox(height: 20),
                    _buildBestSellers(),
                    const SizedBox(height: 20),
                    _buildOrdersByStatus(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Period tabs ────────────────────────────────────────────────────────────

  Widget _buildPeriodTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_periods.length, (i) {
          final sel = i == _selectedPeriod && _customRange == null;
          return GestureDetector(
            onTap: () => setState(() {
              _selectedPeriod = i;
              _customRange = null;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: sel ? AppTheme.primary : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: sel
                        ? AppTheme.primary
                        : Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Text(
                _periods[i],
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : AppTheme.mutedLight),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Date range picker ──────────────────────────────────────────────────────

  Widget _buildDateRangePicker(BuildContext context) {
    final label = _customRange != null
        ? '${_fmt(_customRange!.start)} – ${_fmt(_customRange!.end)}'
        : 'Seleccionar rango de fechas';

    return GestureDetector(
      onTap: () async {
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2024),
          lastDate: DateTime.now().add(const Duration(days: 1)),
          locale: const Locale('es'),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
                colorScheme:
                    const ColorScheme.light(primary: AppTheme.primary)),
            child: child!,
          ),
        );
        if (picked != null) setState(() => _customRange = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: _customRange != null
                  ? AppTheme.primary
                  : Colors.grey.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                color: _customRange != null
                    ? AppTheme.primary
                    : AppTheme.mutedLight,
                size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      color: _customRange != null
                          ? AppTheme.textLight
                          : AppTheme.mutedLight)),
            ),
            if (_customRange != null)
              GestureDetector(
                onTap: () => setState(() => _customRange = null),
                child: const Icon(Icons.close,
                    size: 16, color: AppTheme.mutedLight),
              )
            else
              const Icon(Icons.keyboard_arrow_down,
                  color: AppTheme.mutedLight),
          ],
        ),
      ),
    );
  }

  // ── Sales card ─────────────────────────────────────────────────────────────

  Widget _buildSalesCard() {
    final change = _changePercent;
    final isUp = change >= 0;
    final chartData = _last7DaysSales;
    final chartDays = _last7DayLabels;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('VENTAS TOTALES',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                  letterSpacing: 1.2)),
          const SizedBox(height: 6),
          Text(
            '\$${_totalSales.toStringAsFixed(2)} MXN',
            style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: AppTheme.textLight),
          ),
          const SizedBox(height: 6),
          Row(children: [
            if (_previousTotal > 0) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isUp ? Colors.green : Colors.red)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(children: [
                  Icon(
                      isUp ? Icons.trending_up : Icons.trending_down,
                      color: isUp ? Colors.green : Colors.red,
                      size: 13),
                  const SizedBox(width: 4),
                  Text(
                      '${isUp ? '+' : ''}${change.toStringAsFixed(1)}%',
                      style: TextStyle(
                          color: isUp ? Colors.green : Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ]),
              ),
              const SizedBox(width: 8),
              const Text('vs período anterior',
                  style:
                      TextStyle(fontSize: 12, color: AppTheme.mutedLight)),
            ] else
              const Text('Sin datos del período anterior',
                  style:
                      TextStyle(fontSize: 12, color: AppTheme.mutedLight)),
          ]),
          const SizedBox(height: 6),
          Text(
            '${_ordersInPeriod.length} pedido${_ordersInPeriod.length != 1 ? 's' : ''}',
            style: const TextStyle(fontSize: 12, color: AppTheme.mutedLight),
          ),
          const SizedBox(height: 20),
          if (chartData.any((v) => v > 0))
            SizedBox(
                height: 120,
                child: _LineChart(data: chartData, days: chartDays))
          else
            Container(
              height: 60,
              alignment: Alignment.center,
              child: const Text('Sin ventas en los últimos 7 días',
                  style: TextStyle(color: AppTheme.mutedLight, fontSize: 13)),
            ),
        ],
      ),
    );
  }

  // ── Best sellers ───────────────────────────────────────────────────────────

  Widget _buildBestSellers() {
    final sellers = _bestSellers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Productos más vendidos',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textLight)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.08)),
          ),
          child: sellers.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('Sin pedidos en este período',
                        style: TextStyle(
                            color: AppTheme.mutedLight, fontSize: 14)),
                  ),
                )
              : Column(
                  children: List.generate(sellers.length, (i) {
                    final s = sellers[i];
                    final maxSold = sellers.first.sold;
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          child: Row(children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: i == 0
                                    ? const Color(0xFFFFF3CD)
                                    : Colors.grey[100],
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text('${i + 1}',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: i == 0
                                            ? const Color(0xFFB8860B)
                                            : AppTheme.mutedLight)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.local_florist,
                                  color: AppTheme.primary, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: AppTheme.textLight)),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: s.sold / maxSold,
                                      backgroundColor: Colors.grey[100],
                                      color: AppTheme.primary,
                                      minHeight: 4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${s.sold}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: AppTheme.textLight)),
                                const Text('vendidos',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.mutedLight)),
                              ],
                            ),
                          ]),
                        ),
                        if (i < sellers.length - 1)
                          Divider(
                              height: 1,
                              color: Colors.grey.withValues(alpha: 0.1),
                              indent: 72),
                      ],
                    );
                  }),
                ),
        ),
      ],
    );
  }

  // ── Orders by status ───────────────────────────────────────────────────────

  Widget _buildOrdersByStatus() {
    final statusMap = _ordersByStatus;
    final total = statusMap.values.fold(0, (s, v) => s + v);

    const statuses = [
      OrderStatus.waiting,
      OrderStatus.processing,
      OrderStatus.inTransit,
      OrderStatus.delivered,
      OrderStatus.cancelled,
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pedidos por estado',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textLight)),
          const SizedBox(height: 4),
          Text('$total pedido${total != 1 ? 's' : ''} en este período',
              style:
                  const TextStyle(fontSize: 12, color: AppTheme.mutedLight)),
          const SizedBox(height: 20),
          if (total == 0)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Sin pedidos en este período',
                    style: TextStyle(
                        color: AppTheme.mutedLight, fontSize: 14)),
              ),
            )
          else
            ...statuses.map((status) {
              final count = statusMap[status] ?? 0;
              if (count == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(children: [
                  Icon(status.chipIcon, color: status.chipColor, size: 18),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 90,
                    child: Text(status.label,
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textLight)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: count / total,
                        backgroundColor: Colors.grey[100],
                        valueColor:
                            AlwaysStoppedAnimation(status.chipColor),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 28,
                    child: Text('$count',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppTheme.textLight)),
                  ),
                ]),
              );
            }),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

// ── Data class ────────────────────────────────────────────────────────────────

class _BestSeller {
  final String name;
  final int sold;
  const _BestSeller(this.name, this.sold);
}

// ── Custom Line Chart ─────────────────────────────────────────────────────────

class _LineChart extends StatelessWidget {
  final List<double> data;
  final List<String> days;
  const _LineChart({required this.data, required this.days});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LineChartPainter(data: data, days: days),
      size: Size.infinite,
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> data;
  final List<String> days;
  _LineChartPainter({required this.data, required this.days});

  @override
  void paint(Canvas canvas, Size size) {
    final maxVal = data.reduce(max);
    final minVal = data.reduce(min);
    final range = maxVal - minVal == 0 ? 1.0 : maxVal - minVal;
    final chartH = size.height - 20;

    final pts = List.generate(data.length, (i) {
      final x = data.length < 2
          ? size.width / 2
          : (i / (data.length - 1)) * size.width;
      final y = chartH - ((data[i] - minVal) / range) * chartH;
      return Offset(x, y);
    });

    // Gradient fill
    final fillPath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 0; i < pts.length - 1; i++) {
      final cp1 = Offset((pts[i].dx + pts[i + 1].dx) / 2, pts[i].dy);
      final cp2 = Offset((pts[i].dx + pts[i + 1].dx) / 2, pts[i + 1].dy);
      fillPath.cubicTo(
          cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i + 1].dx, pts[i + 1].dy);
    }
    fillPath
      ..lineTo(size.width, chartH)
      ..lineTo(0, chartH)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.25),
            AppTheme.primary.withValues(alpha: 0.0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, size.width, chartH)),
    );

    // Line
    final linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 0; i < pts.length - 1; i++) {
      final cp1 = Offset((pts[i].dx + pts[i + 1].dx) / 2, pts[i].dy);
      final cp2 = Offset((pts[i].dx + pts[i + 1].dx) / 2, pts[i + 1].dy);
      linePath.cubicTo(
          cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i + 1].dx, pts[i + 1].dy);
    }
    canvas.drawPath(
        linePath,
        Paint()
          ..color = AppTheme.primary
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);

    // Dots
    for (final p in pts) {
      canvas.drawCircle(p, 5, Paint()..color = Colors.white);
      canvas.drawCircle(
          p,
          5,
          Paint()
            ..color = AppTheme.primary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }

    // Day labels
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < days.length; i++) {
      tp.text = TextSpan(
        text: days[i],
        style: TextStyle(
            fontSize: 11,
            color: i == days.length - 1
                ? AppTheme.primary
                : AppTheme.mutedLight,
            fontWeight: FontWeight.w600),
      );
      tp.layout();
      final x = data.length < 2
          ? size.width / 2 - tp.width / 2
          : (i / (days.length - 1)) * size.width - tp.width / 2;
      tp.paint(canvas, Offset(x, size.height - 14));
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter old) =>
      old.data != data || old.days != days;
}
