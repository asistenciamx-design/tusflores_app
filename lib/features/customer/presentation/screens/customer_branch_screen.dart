import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../profile/domain/models/shop_settings_model.dart';
import '../../../profile/domain/repositories/shop_settings_repository.dart';

class CustomerBranchScreen extends StatefulWidget {
  final String? shopId;
  const CustomerBranchScreen({super.key, this.shopId});

  @override
  State<CustomerBranchScreen> createState() => _CustomerBranchScreenState();
}

class _CustomerBranchScreenState extends State<CustomerBranchScreen> {
  final _repo = ShopSettingsRepository();
  ShopSettingsModel? _settings;
  String _shopName = 'Sucursal Principal';
  bool _isLoading = true;

  static const _dayNames = ['', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final shopId = widget.shopId ?? Supabase.instance.client.auth.currentUser?.id;
    if (shopId == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final settings = await _repo.getSettings(shopId);
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('shop_name')
          .eq('id', shopId)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _settings = settings;
          if (profile != null) _shopName = profile['shop_name'] ?? 'Sucursal Principal';
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isOpenNow() {
    if (_settings == null || _settings!.storeHours.isEmpty) return false;
    final now = TimeOfDay.now();
    final weekday = DateTime.now().weekday;
    for (final entry in _settings!.storeHours) {
      if (!entry.days.contains(weekday)) continue;
      final start = entry.start.hour * 60 + entry.start.minute;
      final end = entry.end.hour * 60 + entry.end.minute;
      final cur = now.hour * 60 + now.minute;
      if (cur >= start && cur < end) return true;
    }
    return false;
  }

  TimeOfDay? _closingTime() {
    if (_settings == null) return null;
    final now = TimeOfDay.now();
    final weekday = DateTime.now().weekday;
    for (final entry in _settings!.storeHours) {
      if (!entry.days.contains(weekday)) continue;
      final start = entry.start.hour * 60 + entry.start.minute;
      final end = entry.end.hour * 60 + entry.end.minute;
      final cur = now.hour * 60 + now.minute;
      if (cur >= start && cur < end) return entry.end;
    }
    return null;
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _formatDays(Set<int> days) {
    if (days.isEmpty) return '';
    final sorted = days.toList()..sort();
    bool consecutive = sorted.length > 1;
    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i] != sorted[i - 1] + 1) {
        consecutive = false;
        break;
      }
    }
    if (consecutive && sorted.length >= 3) {
      return '${_dayNames[sorted.first]} - ${_dayNames[sorted.last]}';
    }
    return sorted.map((d) => _dayNames[d]).join(', ');
  }

  Future<void> _launchWhatsApp(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('https://wa.me/$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchMaps(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _buildScrollContent(context),
    );
  }

  Widget _buildScrollContent(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: MediaQuery.of(context).size.height * 0.35,
          pinned: false,
          floating: false,
          backgroundColor: const Color(0xFFF3F0E6),
          leading: Navigator.canPop(context)
              ? Padding(
                  padding: const EdgeInsets.all(8),
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black87),
                      onPressed: () => Navigator.maybePop(context),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                )
              : null,
          flexibleSpace: FlexibleSpaceBar(
            background: _buildCoverHeader(),
          ),
        ),
        SliverToBoxAdapter(
          child: _buildMainContent(context),
        ),
      ],
    );
  }

  Widget _buildCoverHeader() {
    final imageUrl = _settings?.branchImagePath;
    return Container(
      color: const Color(0xFFF3F0E6),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl != null && imageUrl.isNotEmpty)
            Image.network(imageUrl, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _defaultCover())
          else
            _defaultCover(),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.3],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultCover() {
    return Container(
      color: const Color(0xFFE8F5E9),
      child: const Center(
        child: Icon(Icons.local_florist, size: 80, color: AppTheme.primary),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    final isOpen = _isOpenNow();
    final closing = _closingTime();
    final address = _buildAddressString();
    final refs = _settings?.references;
    final showMap = (_settings?.showMapOnProfile ?? false) &&
        (_settings?.mapsUrl?.isNotEmpty ?? false);
    final whatsapp = _settings?.whatsapp ?? '';
    final phone = _settings?.phone ?? '';
    final hasActions = whatsapp.isNotEmpty || phone.isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        24, 32, 24, MediaQuery.of(context).padding.bottom + 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _shopName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isOpen
                      ? Colors.greenAccent.withValues(alpha: 0.3)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle,
                        size: 8, color: isOpen ? Colors.green : Colors.red),
                    const SizedBox(width: 6),
                    Text(
                      isOpen ? 'Abierto ahora' : 'Cerrado',
                      style: TextStyle(
                        color: isOpen ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isOpen && closing != null) ...[
                const SizedBox(width: 8),
                Text(
                  '• Cierra a las ${_fmt(closing)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ],
          ),

          if (showMap) ...[
            const SizedBox(height: 24),
            _buildMapSection(),
          ],

          if (address.isNotEmpty) ...[
            const SizedBox(height: 32),
            _buildDetailRow(
              icon: Icons.location_on,
              title: 'Dirección',
              subtitle: address,
            ),
          ],

          if (refs != null && refs.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildDetailRow(
              icon: Icons.turn_right,
              title: 'Referencias',
              subtitle: refs,
            ),
          ],

          if (_settings != null && _settings!.storeHours.isNotEmpty) ...[
            const SizedBox(height: 32),
            const Row(
              children: [
                Icon(Icons.access_time, color: AppTheme.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'HORARIOS',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.5),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSchedulesCard(
              title: 'Atención en Tienda',
              icon: Icons.storefront,
              rows: _settings!.storeHours
                  .map((e) => _ScheduleRow(
                        days: _formatDays(e.days),
                        time: '${_fmt(e.start)} – ${_fmt(e.end)}',
                      ))
                  .toList(),
            ),
          ],

          if (_settings != null && _settings!.deliveryRanges.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSchedulesCard(
              title: 'Entregas a Domicilio',
              icon: Icons.local_shipping,
              rows: _settings!.deliveryRanges
                  .map((e) => _ScheduleRow(
                        days: e.label.isNotEmpty
                            ? e.label
                            : _formatDays(e.days),
                        time: '${_fmt(e.start)} – ${_fmt(e.end)}',
                      ))
                  .toList(),
            ),
          ],

          if (hasActions) ...[
            const SizedBox(height: 40),
            if (whatsapp.isNotEmpty)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => _launchWhatsApp(whatsapp),
                  icon: const Icon(Icons.chat, color: Colors.white),
                  label: const Text('Contactar por WhatsApp',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1ECA65),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26)),
                    elevation: 0,
                  ),
                ),
              ),
            if (whatsapp.isNotEmpty && phone.isNotEmpty) const SizedBox(height: 12),
            if (phone.isNotEmpty)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => _launchPhone(phone),
                  icon: const Icon(Icons.phone, color: AppTheme.primary, size: 18),
                  label: const Text('Llamar',
                      style: TextStyle(
                          color: Colors.black87, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _buildAddressString() {
    final parts = <String>[];
    if (_settings?.address?.isNotEmpty ?? false) parts.add(_settings!.address!);
    if (_settings?.city?.isNotEmpty ?? false) parts.add(_settings!.city!);
    if (_settings?.state?.isNotEmpty ?? false) parts.add(_settings!.state!);
    if (_settings?.country?.isNotEmpty ?? false) parts.add(_settings!.country!);
    return parts.join(', ');
  }

  Widget _buildMapSection() {
    return GestureDetector(
      onTap: () {
        final url = _settings?.mapsUrl;
        if (url != null && url.isNotEmpty) _launchMaps(url);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.map_outlined, color: Colors.green, size: 22),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ver ubicación',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Abrir en Google Maps',
                    style: TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new, size: 18, color: Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
      {required IconData icon,
      required String title,
      required String subtitle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.green, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 14, color: Colors.grey[600], height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSchedulesCard({
    required String title,
    required IconData icon,
    required List<_ScheduleRow> rows,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              Icon(icon, color: Colors.grey[500], size: 20),
            ],
          ),
          const SizedBox(height: 16),
          ...rows.map((row) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(row.days,
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 14)),
                    Text(row.time,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: Colors.black87)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

}

class _ScheduleRow {
  final String days;
  final String time;
  _ScheduleRow({required this.days, required this.time});
}
