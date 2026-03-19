import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/repositories/admin_repository.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _repo = AdminRepository();
  bool _isLoading = true;
  String _adminName = '';

  int _totalShops = 0;
  int _totalOrders = 0;
  double _totalRevenue = 0;
  int _recentOrders = 0;

  List<Map<String, dynamic>> _recentShops = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('shop_name')
          .eq('id', user!.id)
          .maybeSingle();
      _adminName = profile?['shop_name'] as String? ?? 'Admin';

      final metrics = await _repo.getGlobalMetrics();
      final shops = await _repo.getAllShops();

      if (!mounted) return;
      setState(() {
        _totalShops = metrics['total_shops'] as int;
        _totalOrders = metrics['total_orders'] as int;
        _totalRevenue = metrics['total_revenue'] as double;
        _recentOrders = metrics['recent_orders'] as int;
        _recentShops = shops.take(5).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final moneyFmt = NumberFormat('#,##0.00', 'es_MX');

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // ── Header ──────────────────────────────────────────────
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.admin_panel_settings_rounded,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Super Admin',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.mutedLight,
                                  fontWeight: FontWeight.w500),
                            ),
                            Text(
                              _adminName,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Metric cards ─────────────────────────────────────────
                    Text('Resumen global',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.mutedLight)),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.55,
                      children: [
                        _MetricCard(
                          label: 'Florerías',
                          value: '$_totalShops',
                          icon: Icons.store_rounded,
                          color: const Color(0xFF4F46E5),
                        ),
                        _MetricCard(
                          label: 'Pedidos totales',
                          value: '$_totalOrders',
                          icon: Icons.shopping_bag_rounded,
                          color: const Color(0xFF0891B2),
                        ),
                        _MetricCard(
                          label: 'Pedidos (7 días)',
                          value: '$_recentOrders',
                          icon: Icons.trending_up_rounded,
                          color: const Color(0xFF059669),
                        ),
                        _MetricCard(
                          label: 'Ingresos totales',
                          value: '\$${moneyFmt.format(_totalRevenue)}',
                          icon: Icons.payments_rounded,
                          color: const Color(0xFFD97706),
                          valueSize: 16,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // ── Recent shops ─────────────────────────────────────────
                    Text('Últimas florerías registradas',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.mutedLight)),
                    const SizedBox(height: 12),
                    ..._recentShops.map((shop) => _ShopRow(shop: shop)),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Metric card ────────────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final double valueSize;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.valueSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: valueSize,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textLight)),
              Text(label,
                  style: TextStyle(
                      fontSize: 11, color: AppTheme.mutedLight)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Shop row ───────────────────────────────────────────────────────────────────

class _ShopRow extends StatelessWidget {
  final Map<String, dynamic> shop;
  const _ShopRow({required this.shop});

  @override
  Widget build(BuildContext context) {
    final name = shop['shop_name'] as String? ?? '—';
    final rawDate = shop['created_at'] as String?;
    final date = rawDate != null ? DateTime.tryParse(rawDate) : null;
    final dateFmt = date != null
        ? DateFormat('d MMM yyyy', 'es_MX').format(date)
        : '—';
    final rating = (shop['average_rating'] as num?)?.toStringAsFixed(1) ?? '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_florist_rounded,
                color: Color(0xFF4F46E5), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                Text('Registrada: $dateFmt',
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.mutedLight)),
              ],
            ),
          ),
          Row(
            children: [
              const Icon(Icons.star_rounded,
                  size: 14, color: Color(0xFFF59E0B)),
              const SizedBox(width: 3),
              Text(rating,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}
