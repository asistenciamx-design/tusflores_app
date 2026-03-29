import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Pantalla: Filtro de Ventas (selector de rango de fechas pasadas)
//
// Muestra 3 meses en orden descendente (mes actual → meses anteriores).
// Solo fechas pasadas son seleccionables. El usuario toca inicio y fin del
// rango; el botón "Confirmar Fecha" devuelve el DateTimeRange al caller.
// ─────────────────────────────────────────────────────────────────────────────

class OrderDateFilterScreen extends StatefulWidget {
  final DateTimeRange? initialRange;
  const OrderDateFilterScreen({super.key, this.initialRange});

  @override
  State<OrderDateFilterScreen> createState() => _OrderDateFilterScreenState();
}

class _OrderDateFilterScreenState extends State<OrderDateFilterScreen> {
  DateTime? _start;
  DateTime? _end;

  static const _meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  @override
  void initState() {
    super.initState();
    _start = widget.initialRange?.start;
    _end   = widget.initialRange?.end;
  }

  void _onDayTap(DateTime day) {
    final today = _today();
    if (day.isAfter(today)) return; // futuros bloqueados

    setState(() {
      if (_start == null || (_start != null && _end != null)) {
        // Empezar nueva selección
        _start = day;
        _end   = null;
      } else {
        // Elegir fin
        if (day.isBefore(_start!)) {
          _end   = _start;
          _start = day;
        } else {
          _end = day;
        }
      }
    });
  }

  DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  bool _inRange(DateTime day) {
    if (_start == null || _end == null) return false;
    return !day.isBefore(_start!) && !day.isAfter(_end!);
  }

  bool _isStart(DateTime day) => _start != null && _isSameDay(day, _start!);
  bool _isEnd(DateTime day)   => _end   != null && _isSameDay(day, _end!);
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _rangeLabel() {
    if (_start == null) return 'Selecciona la fecha de inicio';
    if (_end == null)   return 'Selecciona la fecha de fin';
    return '${_start!.day} ${_meses[_start!.month - 1]} → ${_end!.day} ${_meses[_end!.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final today = _today();

    // Meses: actual + 2 anteriores, orden descendente (más reciente arriba)
    final months = List.generate(3, (i) {
      final d = DateTime(today.year, today.month - i);
      return DateTime(d.year, d.month);
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── Fondo degradado (tema floral) ──────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0D3320),
                  Color(0xFF1A5C38),
                  Color(0xFF0A2818),
                  Color(0xFF144D2E),
                ],
                stops: [0.0, 0.35, 0.65, 1.0],
              ),
            ),
          ),
          // Textura sutil de puntos
          Opacity(
            opacity: 0.06,
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(
                      'https://www.transparenttextures.com/patterns/dark-mosaic.png'),
                  repeat: ImageRepeat.repeat,
                ),
              ),
            ),
          ),

          // ── Contenido ─────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // App bar
                _buildAppBar(),

                // Calendarios
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    itemCount: months.length,
                    itemBuilder: (_, i) =>
                        _buildMonthPanel(months[i], today),
                  ),
                ),
              ],
            ),
          ),

          // ── Botón inferior fijo ───────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                  24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
              child: SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton.icon(
                  onPressed: (_start != null && _end != null)
                      ? () => Navigator.pop(
                          context,
                          DateTimeRange(start: _start!, end: _end!))
                      : null,
                  icon: const Icon(Icons.calendar_today_rounded, size: 18),
                  label: const Text(
                    'CONFIRMAR FECHA',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1EBB5D),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        Colors.white.withValues(alpha: 0.15),
                    disabledForegroundColor:
                        Colors.white.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            border: Border(
                bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1))),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 4),
              const Text(
                'Filtro de Ventas',
                style: TextStyle(
                  color: Color(0xFF2BEE79),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthPanel(DateTime month, DateTime today) {
    final label =
        '${_meses[month.month - 1].toUpperCase()} ${month.year}';

    // Días del mes
    final daysInMonth =
        DateUtils.getDaysInMonth(month.year, month.month);
    // Día de la semana del día 1 (lunes=0 … domingo=6)
    final firstWeekday =
        DateTime(month.year, month.month, 1).weekday - 1; // 0=lunes

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              children: [
                // Cabecera mes
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'VISTA MENSUAL',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 9,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),

                // Cabecera días de semana
                Row(
                  children: ['LU', 'MA', 'MI', 'JU', 'VI', 'SA', 'DO']
                      .map((d) => Expanded(
                            child: Text(
                              d,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),

                // Grid de días
                _buildDaysGrid(month, today, daysInMonth, firstWeekday),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDaysGrid(
      DateTime month, DateTime today, int daysInMonth, int firstWeekday) {
    // Total celdas: celdas previas + días del mes
    final totalCells =
        (firstWeekday + daysInMonth + 6) ~/ 7 * 7; // múltiplo de 7

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisExtent: 38,
        mainAxisSpacing: 4,
      ),
      itemCount: totalCells,
      itemBuilder: (_, index) {
        final dayNum = index - firstWeekday + 1;
        if (dayNum < 1 || dayNum > daysInMonth) {
          return const SizedBox.shrink();
        }
        final day = DateTime(month.year, month.month, dayNum);
        final isFuture = day.isAfter(today);
        final isToday  = _isSameDay(day, today);
        final isStart  = _isStart(day);
        final isEnd    = _isEnd(day);
        final inRange  = _inRange(day);

        Color? bg;
        Color textColor;
        bool hasGlow = false;

        if (isStart || isEnd) {
          bg = const Color(0xFF2BEE79);
          textColor = const Color(0xFF00210A);
          hasGlow = true;
        } else if (inRange) {
          bg = const Color(0xFF2BEE79).withValues(alpha: 0.25);
          textColor = Colors.white;
        } else if (isToday) {
          bg = Colors.white.withValues(alpha: 0.2);
          textColor = const Color(0xFF2BEE79);
        } else if (isFuture) {
          textColor = Colors.white.withValues(alpha: 0.15);
        } else {
          textColor = Colors.white.withValues(alpha: 0.85);
        }

        return GestureDetector(
          onTap: isFuture ? null : () => _onDayTap(day),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              boxShadow: hasGlow
                  ? [
                      BoxShadow(
                        color: const Color(0xFF2BEE79).withValues(alpha: 0.5),
                        blurRadius: 10,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                '$dayNum',
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: (isStart || isEnd || isToday)
                      ? FontWeight.bold
                      : FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
