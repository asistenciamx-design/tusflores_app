import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class WeeklyStatsScreen extends StatefulWidget {
  const WeeklyStatsScreen({super.key});

  @override
  State<WeeklyStatsScreen> createState() => _WeeklyStatsScreenState();
}

class _WeeklyStatsScreenState extends State<WeeklyStatsScreen> {
  int _selectedPeriod = 1; // 0=Ayer 1=Hoy 2=Mañana 3=7días
  final List<String> _periods = ['Ayer', 'Hoy', 'Mañana', '7 días'];

  // Mock sales line chart data (Mon–Sun)
  final List<double> _salesData = [1200, 1800, 2300, 1700, 3000, 3500, 8450];
  final List<String> _days = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  // Mock catalog visits bar data [new, returning]
  final List<List<int>> _visits = [
    [50, 15], [42, 18], [57, 25], [42, 43], [67, 48], [85, 69], [100, 42],
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
            child: const Icon(Icons.arrow_back_ios_new, size: 16, color: AppTheme.textLight),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Estadísticas Semanales',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.textLight)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Period tabs ──────────────────────────────────────────────────
            _buildPeriodTabs(),
            const SizedBox(height: 16),

            // ── Date range picker ─────────────────────────────────────────────
            _buildDateRangePicker(context),
            const SizedBox(height: 20),

            // ── Total sales card with line chart ──────────────────────────────
            _buildSalesCard(),
            const SizedBox(height: 20),

            // ── Best-selling products ─────────────────────────────────────────
            _buildBestSellers(context),
            const SizedBox(height: 20),

            // ── Catalog visits bar chart ──────────────────────────────────────
            _buildVisitsChart(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ─── Period Tabs ──────────────────────────────────────────────────────────

  Widget _buildPeriodTabs() {
    return Row(
      children: List.generate(_periods.length, (i) {
        final sel = i == _selectedPeriod;
        return GestureDetector(
          onTap: () => setState(() => _selectedPeriod = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            decoration: BoxDecoration(
              color: sel ? AppTheme.primary : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: sel ? AppTheme.primary : Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Text(_periods[i],
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: sel ? Colors.white : AppTheme.mutedLight)),
          ),
        );
      }),
    );
  }

  // ─── Date Range Picker ────────────────────────────────────────────────────

  Widget _buildDateRangePicker(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await showDateRangePicker(
          context: context,
          firstDate: DateTime(2024),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          locale: const Locale('es'),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: AppTheme.primary)),
            child: child!,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        ),
        child: const Row(
          children: [
            Icon(Icons.calendar_today_outlined, color: AppTheme.primary, size: 18),
            SizedBox(width: 12),
            Expanded(
              child: Text('Seleccionar rango de fechas',
                style: TextStyle(fontSize: 14, color: AppTheme.mutedLight))),
            Icon(Icons.keyboard_arrow_down, color: AppTheme.mutedLight),
          ],
        ),
      ),
    );
  }

  // ─── Sales Card with Line Chart ───────────────────────────────────────────

  Widget _buildSalesCard() {
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
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
              color: AppTheme.primary, letterSpacing: 1.2)),
          const SizedBox(height: 6),
          const Text('\$8,450 MXN',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
          const SizedBox(height: 6),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
              child: const Row(children: [
                Icon(Icons.trending_up, color: Colors.green, size: 13),
                SizedBox(width: 4),
                Text('+20%', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
              ]),
            ),
            const SizedBox(width: 8),
            const Text('vs semana anterior', style: TextStyle(fontSize: 12, color: AppTheme.mutedLight)),
          ]),
          const SizedBox(height: 20),
          SizedBox(height: 120, child: _LineChart(data: _salesData, days: _days)),
        ],
      ),
    );
  }

  // ─── Best Sellers ─────────────────────────────────────────────────────────

  Widget _buildBestSellers(BuildContext context) {
    final products = [
      const _Product('Ramo "Amor Eterno"', 'Rosas rojas importadas', 42,
        'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=80&q=80'),
      const _Product('Cesta Primaveral', 'Mix de flores de temporada', 28,
        'https://images.unsplash.com/photo-1487530811015-780f93f1b6cc?w=80&q=80'),
      const _Product('Orquídea Phalaenopsis', 'Blanca en maceta cerámica', 15,
        'https://images.unsplash.com/photo-1590736969955-71cc94901144?w=80&q=80'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Productos más vendidos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
            GestureDetector(
              onTap: () {},
              child: const Text('Ver todo',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.08)),
          ),
          child: Column(
            children: List.generate(products.length, (i) {
              final p = products[i];
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(p.imageUrl,
                          width: 52, height: 52, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 52, height: 52,
                            decoration: BoxDecoration(
                              color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.local_florist, color: AppTheme.primary)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold,
                            fontSize: 14, color: AppTheme.textLight)),
                          const SizedBox(height: 2),
                          Text(p.subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.mutedLight)),
                        ],
                      )),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${p.sold}',
                            style: const TextStyle(fontWeight: FontWeight.bold,
                              fontSize: 16, color: AppTheme.textLight)),
                          const Text('vendidos', style: TextStyle(fontSize: 11, color: AppTheme.mutedLight)),
                        ],
                      ),
                    ]),
                  ),
                  if (i < products.length - 1)
                    Divider(height: 1, color: Colors.grey.withValues(alpha: 0.1), indent: 82),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  // ─── Catalog Visits Bar Chart ─────────────────────────────────────────────

  Widget _buildVisitsChart() {
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
          Row(
            children: [
              const Text('Visitas al catálogo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
              const Spacer(),
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              const Text('Nuevos', style: TextStyle(fontSize: 11, color: AppTheme.mutedLight)),
              const SizedBox(width: 12),
              Container(width: 8, height: 8, decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.35), shape: BoxShape.circle)),
              const SizedBox(width: 4),
              const Text('Recurrentes', style: TextStyle(fontSize: 11, color: AppTheme.mutedLight)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(height: 160, child: _BarChart(data: _visits, days: _days)),
        ],
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _Product {
  final String name, subtitle, imageUrl;
  final int sold;
  const _Product(this.name, this.subtitle, this.sold, this.imageUrl);
}

// ─── Custom Line Chart ────────────────────────────────────────────────────────

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
    final range = maxVal - minVal == 0 ? 1 : maxVal - minVal;
    final chartH = size.height - 20;

    final pts = List.generate(data.length, (i) {
      final x = (i / (data.length - 1)) * size.width;
      final y = chartH - ((data[i] - minVal) / range) * chartH;
      return Offset(x, y);
    });

    // Fill
    final fillPath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 0; i < pts.length - 1; i++) {
      final cp1 = Offset((pts[i].dx + pts[i + 1].dx) / 2, pts[i].dy);
      final cp2 = Offset((pts[i].dx + pts[i + 1].dx) / 2, pts[i + 1].dy);
      fillPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i + 1].dx, pts[i + 1].dy);
    }
    fillPath
      ..lineTo(size.width, chartH)
      ..lineTo(0, chartH)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()..shader = LinearGradient(
        colors: [AppTheme.primary.withValues(alpha: 0.25), AppTheme.primary.withValues(alpha: 0.0)],
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, chartH)),
    );

    // Line
    final linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 0; i < pts.length - 1; i++) {
      final cp1 = Offset((pts[i].dx + pts[i + 1].dx) / 2, pts[i].dy);
      final cp2 = Offset((pts[i].dx + pts[i + 1].dx) / 2, pts[i + 1].dy);
      linePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i + 1].dx, pts[i + 1].dy);
    }
    canvas.drawPath(linePath,
      Paint()..color = AppTheme.primary..strokeWidth = 2.5
        ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);

    // Dots
    for (int i = 0; i < pts.length; i++) {
      canvas.drawCircle(pts[i], 5, Paint()..color = Colors.white);
      canvas.drawCircle(pts[i], 5, Paint()
        ..color = AppTheme.primary..style = PaintingStyle.stroke..strokeWidth = 2);
    }

    // Day labels
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < days.length; i++) {
      tp.text = TextSpan(text: days[i],
        style: TextStyle(fontSize: 11, color: i == days.length - 1
          ? AppTheme.primary : AppTheme.mutedLight, fontWeight: FontWeight.w600));
      tp.layout();
      final x = (i / (days.length - 1)) * size.width - tp.width / 2;
      tp.paint(canvas, Offset(x, size.height - 14));
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter old) => old.data != data;
}

// ─── Custom Bar Chart ─────────────────────────────────────────────────────────

class _BarChart extends StatelessWidget {
  final List<List<int>> data;
  final List<String> days;
  const _BarChart({required this.data, required this.days});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BarChartPainter(data: data, days: days),
      size: Size.infinite,
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<List<int>> data; // [[new, returning], ...]
  final List<String> days;
  _BarChartPainter({required this.data, required this.days});

  @override
  void paint(Canvas canvas, Size size) {
    final allTotals = data.map((d) => d[0] + d[1]).toList();
    final maxTotal = allTotals.reduce(max).toDouble();
    const labelH = 18.0;
    const dayH = 18.0;
    final chartH = size.height - labelH - dayH;
    final colW = size.width / data.length;
    const barW = 22.0;
    const barSpacing = 4.0;

    for (int i = 0; i < data.length; i++) {
      final newV = data[i][0];
      final retV = data[i][1];
      final total = newV + retV;
      final cx = colW * i + colW / 2;

      final newH = (newV / maxTotal) * chartH;
      final retH = (retV / maxTotal) * chartH;

      // Returning bar (lighter, left)
      final retLeft = cx - barW - barSpacing / 2;
      final retTop = chartH - retH;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(retLeft, retTop, barW, retH), const Radius.circular(5)),
        Paint()..color = AppTheme.primary.withValues(alpha: 0.35),
      );

      // New bar (solid, right)
      final newLeft = cx + barSpacing / 2;
      final newTop = chartH - newH;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(newLeft, newTop, barW, newH), const Radius.circular(5)),
        Paint()..color = AppTheme.primary,
      );

      // Total label
      if (i == data.length - 1 || total >= allTotals.reduce(max) * 0.8) {
        final tp = TextPainter(
          text: TextSpan(text: '$total visitas',
            style: const TextStyle(fontSize: 9, color: AppTheme.mutedLight, fontWeight: FontWeight.w600)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(cx - tp.width / 2, min(retTop, newTop) - 14));
      }

      // Day label
      final tp = TextPainter(
        text: TextSpan(text: days[i],
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: i == data.length - 1 ? AppTheme.primary : AppTheme.mutedLight)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, size.height - dayH));
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) => false;
}
