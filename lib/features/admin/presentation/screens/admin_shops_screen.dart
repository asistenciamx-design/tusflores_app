import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/repositories/admin_repository.dart';

class AdminShopsScreen extends StatefulWidget {
  const AdminShopsScreen({super.key});

  @override
  State<AdminShopsScreen> createState() => _AdminShopsScreenState();
}

class _AdminShopsScreenState extends State<AdminShopsScreen> {
  final _repo = AdminRepository();
  final _searchCtrl = TextEditingController();
  bool _isLoading = true;
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final shops = await _repo.getAllShops();
      if (!mounted) return;
      setState(() {
        _all = shops;
        _filtered = shops;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all.where((s) {
              final name = (s['shop_name'] as String? ?? '').toLowerCase();
              return name.contains(q);
            }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.store_rounded,
                          color: Color(0xFF4F46E5), size: 22),
                      const SizedBox(width: 8),
                      const Text('Florerías',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      if (!_isLoading)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_all.length} registradas',
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF4F46E5),
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Search
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Buscar florería...',
                      hintStyle:
                          TextStyle(color: AppTheme.mutedLight, fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: AppTheme.mutedLight, size: 20),
                      filled: true,
                      fillColor: AppTheme.cardLight,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Colors.black.withValues(alpha: 0.08)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Colors.black.withValues(alpha: 0.08)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF4F46E5), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            // ── List ─────────────────────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: _filtered.isEmpty
                          ? Center(
                              child: Text(
                                'No hay florerías',
                                style:
                                    TextStyle(color: AppTheme.mutedLight),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                              itemCount: _filtered.length,
                              itemBuilder: (context, i) =>
                                  _ShopCard(shop: _filtered[i]),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shop card ──────────────────────────────────────────────────────────────────

class _ShopCard extends StatelessWidget {
  final Map<String, dynamic> shop;
  const _ShopCard({required this.shop});

  @override
  Widget build(BuildContext context) {
    final name = shop['shop_name'] as String? ?? '—';
    final phone = shop['whatsapp_number'] as String? ?? '—';
    final rating =
        (shop['average_rating'] as num?)?.toStringAsFixed(1) ?? '—';
    final reviewCount = shop['review_count'] as int? ?? 0;
    final rawDate = shop['created_at'] as String?;
    final date =
        rawDate != null ? DateTime.tryParse(rawDate) : null;
    final dateFmt = date != null
        ? DateFormat('d MMM yyyy', 'es_MX').format(date)
        : '—';

    // Initials avatar
    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join()
        : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardLight,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                    color: Color(0xFF4F46E5),
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(phone,
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.mutedLight)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _Pill(
                      icon: Icons.star_rounded,
                      iconColor: const Color(0xFFF59E0B),
                      label: '$rating ($reviewCount)',
                    ),
                    const SizedBox(width: 8),
                    _Pill(
                      icon: Icons.calendar_today_rounded,
                      iconColor: AppTheme.mutedLight,
                      label: dateFmt,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;

  const _Pill(
      {required this.icon, required this.iconColor, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: iconColor),
        const SizedBox(width: 3),
        Text(label,
            style:
                TextStyle(fontSize: 11, color: AppTheme.mutedLight)),
      ],
    );
  }
}
