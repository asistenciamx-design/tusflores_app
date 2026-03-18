import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../orders/domain/models/order_model.dart';
import '../../../orders/domain/repositories/order_repository.dart';
import 'crm_client_profile_screen.dart';

enum _SortMode { az, mostOrders, mostSpent, recent }

class CrmScreen extends StatefulWidget {
  const CrmScreen({super.key});

  @override
  State<CrmScreen> createState() => _CrmScreenState();
}

class _CrmScreenState extends State<CrmScreen> {
  bool _isLoading = true;
  List<_ClientInteraction> _interactions = [];
  int _totalClients = 0;
  final _searchCtrl = TextEditingController();
  List<_ClientInteraction> _filtered = [];
  _SortMode _sortMode = _SortMode.recent;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() => _refresh();

  void _onSortChanged(_SortMode mode) {
    _sortMode = mode;
    _refresh();
  }

  void _refresh() {
    final q = _searchCtrl.text.toLowerCase();
    final base = q.isEmpty
        ? List<_ClientInteraction>.from(_interactions)
        : _interactions
            .where((c) =>
                c.name.toLowerCase().contains(q) ||
                c.phone.toLowerCase().contains(q) ||
                c.email.toLowerCase().contains(q))
            .toList();
    setState(() {
      _filtered = _sortedList(base);
    });
  }

  List<_ClientInteraction> _sortedList(List<_ClientInteraction> list) {
    final copy = List<_ClientInteraction>.from(list);
    switch (_sortMode) {
      case _SortMode.az:
        copy.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case _SortMode.mostOrders:
        copy.sort((a, b) => b.orderCount.compareTo(a.orderCount));
      case _SortMode.mostSpent:
        copy.sort((a, b) => b.totalSpent.compareTo(a.totalSpent));
      case _SortMode.recent:
        copy.sort((a, b) => (b.lastInteraction ?? DateTime(0))
            .compareTo(a.lastInteraction ?? DateTime(0)));
    }
    return copy;
  }

  double get _maxTotalSpent => _interactions.isEmpty
      ? 1.0
      : _interactions
          .map((c) => c.totalSpent)
          .reduce((a, b) => a > b ? a : b)
          .clamp(1.0, double.infinity);

  Future<void> _loadData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final orders = await OrderRepository().getOrders(user.id);

      // Group orders by buyer whatsapp to build client list (CRM buyers)
      final Map<String, List<OrderModel>> byClient = {};
      for (final order in orders) {
        final key = (order.buyerWhatsapp?.isNotEmpty == true)
            ? order.buyerWhatsapp!
            : (order.buyerName?.isNotEmpty == true ? order.buyerName! : 'sin-nombre');
        byClient.putIfAbsent(key, () => []).add(order);
      }

      final Map<String, _ClientInteraction> map = {};
      for (final entry in byClient.entries) {
        final clientOrders = entry.value;
        final first = clientOrders.first;
        final name = (first.buyerName?.isNotEmpty == true)
            ? first.buyerName!
            : 'Sin nombre';
        final phone = first.buyerWhatsapp ?? '';
        final email = first.buyerEmail ?? '';
        final lastInteraction = clientOrders
            .map((o) => o.createdAt)
            .reduce((a, b) => a.isAfter(b) ? a : b);
        map[entry.key] = _ClientInteraction(
          name: name,
          phone: phone,
          email: email,
          orderCount: clientOrders.length,
          totalSpent: clientOrders.fold(0.0, (s, o) => s + o.total),
          lastInteraction: lastInteraction,
          orders: clientOrders,
        );
      }

      final all = map.values.toList();

      if (mounted) {
        setState(() {
          _interactions = all;
          _filtered = _sortedList(all);
          _totalClients = all.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          _buildMetricsRow(),
                          const SizedBox(height: 24),
                          _buildGrowthChart(),
                          const SizedBox(height: 24),
                          _buildInteractionsList(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: const Color(0xFFF6F8F7),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_florist,
                    color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CRM',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  Text('Gestión de clientes',
                      style:
                          TextStyle(fontSize: 12, color: AppTheme.mutedLight)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Search bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Buscar clientes o pedidos...',
                hintStyle:
                    TextStyle(color: AppTheme.mutedLight, fontSize: 14),
                prefixIcon: Icon(Icons.search,
                    color: AppTheme.mutedLight, size: 20),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow() {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: 'Total Clientes',
            value: _totalClients.toString(),
            badge: '+5.2%',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            label: 'Pedidos totales',
            value: _interactions.fold<int>(0, (s, c) => s + c.orderCount).toString(),
            badge: '+8.4%',
          ),
        ),
      ],
    );
  }

  Widget _buildGrowthChart() {
    // Visual bar chart — heights based on interaction data bucketed into 10 slots
    final bars = _buildChartBars();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Crecimiento de Clientes',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Últimos pedidos',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey[500])),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 160,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: Colors.grey.withValues(alpha: 0.1)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: bars
                .map((h) => Expanded(
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 2),
                        child: FractionallySizedBox(
                          heightFactor: h,
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.primary
                                  .withValues(alpha: 0.3 + h * 0.7),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4)),
                            ),
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  List<double> _buildChartBars() {
    if (_interactions.isEmpty) {
      return List.generate(10, (i) => 0.1 + i * 0.09);
    }
    // Count interactions per bucket (split all into 10 groups)
    final n = _interactions.length;
    final bucketSize = (n / 10).ceil().clamp(1, n);
    final counts = <int>[];
    for (int i = 0; i < 10; i++) {
      final start = i * bucketSize;
      final end = (start + bucketSize).clamp(0, n);
      counts.add(start < n ? end - start : 0);
    }
    final maxVal = counts.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) return List.generate(10, (i) => 0.1 + i * 0.09);
    return counts.map((c) => (c / maxVal).clamp(0.05, 1.0)).toList();
  }

  Widget _buildInteractionsList() {
    final maxSpent = _maxTotalSpent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _SortChip(
                label: 'A-Z',
                icon: Icons.sort_by_alpha,
                selected: _sortMode == _SortMode.az,
                onTap: () => _onSortChanged(_SortMode.az),
              ),
              const SizedBox(width: 8),
              _SortChip(
                label: 'Más pedidos',
                icon: Icons.trending_up,
                selected: _sortMode == _SortMode.mostOrders,
                onTap: () => _onSortChanged(_SortMode.mostOrders),
              ),
              const SizedBox(width: 8),
              _SortChip(
                label: 'Mayor gasto',
                icon: Icons.attach_money,
                selected: _sortMode == _SortMode.mostSpent,
                onTap: () => _onSortChanged(_SortMode.mostSpent),
              ),
              const SizedBox(width: 8),
              _SortChip(
                label: 'Recientes',
                icon: Icons.calendar_today_outlined,
                selected: _sortMode == _SortMode.recent,
                onTap: () => _onSortChanged(_SortMode.recent),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text('Sin clientes aún',
                  style: TextStyle(color: AppTheme.mutedLight)),
            ),
          )
        else
          ...(_filtered.take(20).map((c) => _InteractionTile(client: c, maxSpent: maxSpent))),
      ],
    );
  }
}

// ── Data model ──────────────────────────────────────────────────────────────

class _ClientInteraction {
  final String name;
  final String phone;
  final String email;
  final int orderCount;
  final double totalSpent;
  final DateTime? lastInteraction;
  final List<OrderModel> orders;

  const _ClientInteraction({
    required this.name,
    required this.phone,
    this.email = '',
    required this.orderCount,
    this.totalSpent = 0.0,
    this.lastInteraction,
    this.orders = const [],
  });
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String badge;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.mutedLight,
                  letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87)),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.trending_up,
                        color: AppTheme.primary, size: 12),
                    const SizedBox(width: 2),
                    Text(badge,
                        style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.15)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.5)
                : Colors.grey.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13,
                color: selected ? AppTheme.primary : AppTheme.mutedLight),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                    color:
                        selected ? AppTheme.primary : AppTheme.mutedLight)),
          ],
        ),
      ),
    );
  }
}

class _InteractionTile extends StatelessWidget {
  final _ClientInteraction client;
  final double maxSpent;

  const _InteractionTile({required this.client, required this.maxSpent});

  static const _palette = [
    Color(0xFFEC4899),
    Color(0xFF8B5CF6),
    Color(0xFF3B82F6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFF6366F1),
    Color(0xFF0EA5E9),
    Color(0xFFDB2777),
    Color(0xFF7C3AED),
    Color(0xFFF43F5E),
  ];

  Color get _avatarColor {
    final code = client.name.isNotEmpty ? client.name.codeUnitAt(0) : 0;
    return _palette[code % _palette.length];
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Hoy';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    if (diff.inDays < 14) return 'Hace 1 semana';
    if (diff.inDays < 30) return 'Hace ${(diff.inDays / 7).floor()} semanas';
    if (diff.inDays < 60) return 'Hace 1 mes';
    return 'Hace ${(diff.inDays / 30).floor()} meses';
  }

  String _formatMoney(double v) {
    if (v >= 1000) {
      final s = v.toStringAsFixed(0);
      final buf = StringBuffer();
      for (int i = 0; i < s.length; i++) {
        if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
        buf.write(s[i]);
      }
      return '\$${buf.toString()}';
    }
    return '\$${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final barFraction = maxSpent > 0 ? (client.totalSpent / maxSpent).clamp(0.04, 1.0) : 0.04;
    final initial = client.name.isNotEmpty ? client.name[0].toUpperCase() : '?';
    final color = _avatarColor;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CrmClientProfileScreen(
          name: client.name,
          phone: client.phone,
          email: client.email,
          orders: client.orders,
        ),
      )),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.08)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar con letra e color
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info central
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    client.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    client.phone.isNotEmpty
                        ? client.phone
                        : client.email.isNotEmpty
                            ? client.email
                            : 'Sin contacto',
                    style: const TextStyle(fontSize: 11, color: AppTheme.mutedLight),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (client.lastInteraction != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      'Último pedido: ${_formatDate(client.lastInteraction)}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.mutedLight),
                    ),
                  ],
                  const SizedBox(height: 6),
                  // Barra proporcional de gasto
                  LayoutBuilder(builder: (_, constraints) {
                    return Container(
                      height: 4,
                      width: constraints.maxWidth,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE9FE),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: barFraction,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [color, color.withValues(alpha: 0.6)],
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Derecha: monto + pedidos
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatMoney(client.totalSpent),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${client.orderCount} ${client.orderCount == 1 ? 'pedido' : 'pedidos'}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.mutedLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
