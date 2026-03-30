import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_cache.dart';
import '../../domain/models/repartidor_model.dart';
import '../../domain/repositories/repartidor_repository.dart';
import '../../../orders/presentation/screens/order_date_filter_screen.dart';

class RepartoHistoricoScreen extends StatefulWidget {
  const RepartoHistoricoScreen({super.key});

  @override
  State<RepartoHistoricoScreen> createState() => _RepartoHistoricoScreenState();
}

class _RepartoHistoricoScreenState extends State<RepartoHistoricoScreen> {
  static const _chips = ['15 días', 'Semana', 'Ayer', 'Hoy', 'Este mes'];
  int _chipIndex = 3; // Hoy por default

  final _repo = RepartidorRepository();
  late String _shopId;

  List<RepartidorModel> _repartidores = [];
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;

  // Notes editing: orderId → controller
  final Map<String, TextEditingController> _notesCtrl = {};

  // Expanded notes: which order IDs have the note field open
  final Set<String> _expandedNotes = {};

  // Search
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Custom date range (overrides chip selection when set)
  DateTimeRange? _customDateRange;

  @override
  void initState() {
    super.initState();
    _shopId = Supabase.instance.client.auth.currentUser?.id ?? '';
    _load();
  }

  @override
  void dispose() {
    for (final c in _notesCtrl.values) {
      c.dispose();
    }
    _searchCtrl.dispose();
    super.dispose();
  }

  DateTimeRange _rangeFor(int chipIndex) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (chipIndex) {
      case 0: // 15 días
        return DateTimeRange(
            start: today.subtract(const Duration(days: 14)), end: today);
      case 1: // Semana
        return DateTimeRange(
            start: today.subtract(const Duration(days: 6)), end: today);
      case 2: // Ayer
        final ayer = today.subtract(const Duration(days: 1));
        return DateTimeRange(start: ayer, end: ayer);
      case 3: // Hoy
        return DateTimeRange(start: today, end: today);
      case 4: // Este mes
        return DateTimeRange(
            start: DateTime(today.year, today.month, 1), end: today);
      default:
        return DateTimeRange(start: today, end: today);
    }
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
        _chipIndex = -1; // deselect chips
      });
      _load();
    }
  }

  String _formatDateLabel(DateTime dt) {
    const meses = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
    ];
    return '${dt.day} ${meses[dt.month - 1]} ${dt.year}';
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final range = _customDateRange ?? _rangeFor(_chipIndex);
    final results = await Future.wait([
      _repo.getRepartidores(_shopId),
      _repo.getHistoricoOrders(
          shopId: _shopId, from: range.start, to: range.end),
    ]);
    _repartidores = results[0] as List<RepartidorModel>;
    _orders = results[1] as List<Map<String, dynamic>>;

    // Init notes controllers
    for (final o in _orders) {
      final id = o['id'] as String? ?? '';
      if (!_notesCtrl.containsKey(id)) {
        _notesCtrl[id] = TextEditingController(
            text: o['driver_notes'] as String? ?? '');
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveNote(String orderId, String note) async {
    await _repo.assignToOrder(orderId: orderId, driverNotes: note);
  }

  List<Map<String, dynamic>> _ordersFor(String repartidorId) {
    return _orders
        .where((o) => o['repartidor_id'] == repartidorId)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (Navigator.canPop(context))
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 38,
                              height: 38,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.arrow_back,
                                  color: Colors.black87, size: 20),
                            ),
                          ),
                        const Text(
                          'Histórico de Reparto',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(_chips.length, (i) {
                          final sel = i == _chipIndex;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _chipIndex = i;
                                _customDateRange = null;
                              });
                              _load();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 8),
                              decoration: BoxDecoration(
                                color: sel
                                    ? AppTheme.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Text(
                                _chips[i],
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: sel
                                      ? Colors.white
                                      : const Color(0xFF9E9E9E),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Search bar
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (v) =>
                          setState(() => _searchQuery = v.toLowerCase().trim()),
                      decoration: InputDecoration(
                        hintText: 'Buscar folio u operador…',
                        hintStyle: const TextStyle(
                            fontSize: 13, color: Color(0xFFBDBDBD)),
                        prefixIcon: const Icon(Icons.search_rounded,
                            size: 18, color: Color(0xFFBDBDBD)),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? GestureDetector(
                                onTap: () => setState(() {
                                  _searchCtrl.clear();
                                  _searchQuery = '';
                                }),
                                child: const Icon(Icons.close_rounded,
                                    size: 16, color: Color(0xFFBDBDBD)),
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFFF5F5F5),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    // Date range picker button
                    GestureDetector(
                      onTap: _selectDateRange,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: _customDateRange != null
                              ? AppTheme.primary.withValues(alpha: 0.08)
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _customDateRange != null
                                ? AppTheme.primary.withValues(alpha: 0.5)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_month_rounded,
                              size: 17,
                              color: _customDateRange != null
                                  ? AppTheme.primary
                                  : const Color(0xFFBDBDBD),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _customDateRange == null
                                    ? 'Seleccionar rango de fechas'
                                    : '${_formatDateLabel(_customDateRange!.start)}  →  ${_formatDateLabel(_customDateRange!.end)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: _customDateRange == null
                                      ? const Color(0xFFBDBDBD)
                                      : AppTheme.primary,
                                ),
                              ),
                            ),
                            if (_customDateRange != null)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  setState(() {
                                    _customDateRange = null;
                                    _chipIndex = 3; // Hoy
                                  });
                                  _load();
                                },
                                child: const Icon(Icons.close_rounded,
                                    size: 16, color: Color(0xFF9E9E9E)),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),

            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                    child:
                        CircularProgressIndicator(color: AppTheme.primary)),
              )
            else if (_repartidores.isEmpty || _orders.isEmpty)
              SliverFillRemaining(child: _buildEmpty())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    _filteredRepartidores
                        .map((r) => _buildRepartidorSection(r))
                        .toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<RepartidorModel> get _filteredRepartidores {
    if (_searchQuery.isEmpty) return _repartidores;
    return _repartidores.where((r) {
      final nameMatch =
          r.name.toLowerCase().contains(_searchQuery);
      final orderMatch = r.id != null &&
          _ordersFor(r.id!).any((o) =>
              (o['folio'] as String? ?? '').toLowerCase().contains(_searchQuery));
      return nameMatch || orderMatch;
    }).toList();
  }

  Widget _buildRepartidorSection(RepartidorModel r) {
    if (r.id == null) return const SizedBox.shrink();
    // In search mode, filter orders by folio too
    final orders = _searchQuery.isEmpty
        ? _ordersFor(r.id!)
        : _ordersFor(r.id!)
            .where((o) =>
                (o['folio'] as String? ?? '')
                    .toLowerCase()
                    .contains(_searchQuery) ||
                r.name.toLowerCase().contains(_searchQuery))
            .toList();
    if (orders.isEmpty) return const SizedBox.shrink();

    final totalPedidos = orders.length;
    final totalMonto = orders.fold<double>(
      0,
      (sum, o) =>
          sum +
          ((o['delivery_amount'] as num?)?.toDouble() ??
              (o['shipping_cost'] as num?)?.toDouble() ??
              0),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Repartidor header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D3320), Color(0xFF1A5C38)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delivery_dining_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (r.vehicleName != null || r.vehiclePlates != null)
                        Text(
                          [
                            if (r.vehicleName != null) r.vehicleName!,
                            if (r.vehiclePlates != null) r.vehiclePlates!,
                          ].join(' · '),
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$totalPedidos pedido${totalPedidos == 1 ? '' : 's'}',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${CurrencyCache.symbol}${totalMonto.toStringAsFixed(0)} ${CurrencyCache.code}',
                      style: const TextStyle(
                        color: Color(0xFF2BEE79),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Orders list
          ...orders.asMap().entries.map((entry) {
            final idx = entry.key;
            final o = entry.value;
            return _buildOrderRow(o, idx, orders.length);
          }),
        ],
      ),
    );
  }

  Widget _buildOrderRow(
      Map<String, dynamic> o, int idx, int total) {
    final orderId = o['id'] as String? ?? '';
    final folio = o['folio'] as String? ?? '-';
    final deliveryDate = o['delivery_date'] != null
        ? DateTime.parse(o['delivery_date'] as String)
        : (o['sale_date'] != null
            ? DateTime.parse(o['sale_date'] as String)
            : DateTime.now());
    final monto = (o['delivery_amount'] as num?)?.toDouble() ??
        (o['shipping_cost'] as num?)?.toDouble() ??
        0.0;
    final zona = o['delivery_city'] as String? ??
        o['delivery_location_type'] as String? ??
        o['delivery_state'] as String? ??
        '—';

    _notesCtrl.putIfAbsent(
        orderId,
        () => TextEditingController(
            text: o['driver_notes'] as String? ?? ''));

    final ctrl = _notesCtrl[orderId]!;
    final isExpanded = _expandedNotes.contains(orderId);
    final hasNote = ctrl.text.trim().isNotEmpty;

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() {
            isExpanded
                ? _expandedNotes.remove(orderId)
                : _expandedNotes.add(orderId);
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Folio
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'FOLIO $folio',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Fecha
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            size: 11, color: Color(0xFF9E9E9E)),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(deliveryDate),
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF9E9E9E)),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Monto
                    Text(
                      '${CurrencyCache.symbol}${monto.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textLight,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Note icon button
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          isExpanded
                              ? Icons.sticky_note_2_rounded
                              : Icons.sticky_note_2_outlined,
                          size: 18,
                          color: hasNote
                              ? AppTheme.primary
                              : const Color(0xFFBDBDBD),
                        ),
                        if (hasNote && !isExpanded)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppTheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 12, color: Color(0xFF9E9E9E)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        zona,
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF9E9E9E)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                // Note preview when collapsed and has content
                if (!isExpanded && hasNote) ...[
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          ctrl.text.trim(),
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9E9E9E),
                              fontStyle: FontStyle.italic),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                // Expandable notes field
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: isExpanded
                      ? Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: TextField(
                            controller: ctrl,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: 'Nota de entrega…',
                              hintStyle: const TextStyle(
                                  fontSize: 12, color: Color(0xFFBDBDBD)),
                              filled: true,
                              fillColor: const Color(0xFFF9F9F9),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade200),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade200),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: AppTheme.primary),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              isDense: true,
                            ),
                            style: const TextStyle(fontSize: 12),
                            maxLines: 3,
                            minLines: 1,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (v) {
                              _saveNote(orderId, v);
                              setState(() => _expandedNotes.remove(orderId));
                            },
                            onEditingComplete: () {
                              _saveNote(orderId, ctrl.text);
                              setState(() => _expandedNotes.remove(orderId));
                            },
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
        if (idx < total - 1)
          Divider(height: 1, indent: 16, color: Colors.grey.shade100),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    const meses = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
    ];
    return '${dt.day} ${meses[dt.month - 1]} ${dt.year}';
  }

  Widget _buildEmpty() {
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
            child: const Icon(Icons.history_rounded,
                size: 40, color: AppTheme.primary),
          ),
          const SizedBox(height: 16),
          const Text(
            'Sin entregas en este período',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFFBDBDBD)),
          ),
        ],
      ),
    );
  }
}
