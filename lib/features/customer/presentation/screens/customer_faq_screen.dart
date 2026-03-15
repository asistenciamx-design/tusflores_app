import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../profile/domain/models/shop_settings_model.dart';
import '../../../profile/domain/repositories/shop_settings_repository.dart';

class CustomerFaqScreen extends StatefulWidget {
  final String? shopId;
  const CustomerFaqScreen({super.key, this.shopId});

  @override
  State<CustomerFaqScreen> createState() => _CustomerFaqScreenState();
}

class _CustomerFaqScreenState extends State<CustomerFaqScreen> {
  final _repo = ShopSettingsRepository();
  ShopSettingsModel? _settings;
  String _shopName = 'Mi Florería';
  bool _isLoading = true;

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
          if (profile != null) _shopName = profile['shop_name'] ?? 'Mi Florería';
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
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

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  List<FaqItem> get _visibleFaqs =>
      (_settings?.faqs ?? []).where((f) => f.isVisible).toList();

  String get _whatsapp => _settings?.whatsapp ?? '';
  String get _phone => _settings?.phone ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFDFA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SafeArea(child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildContactCard(context),
                  if (_visibleFaqs.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    _buildSectionTitle('PREGUNTAS FRECUENTES'),
                    const SizedBox(height: 16),
                    _buildFaqList(),
                  ],
                  if (_settings?.linkMethods.isNotEmpty ?? false) ...[
                    const SizedBox(height: 48),
                    _buildSectionTitle('SÍGUENOS EN REDES'),
                    const SizedBox(height: 24),
                    _buildSocialLinks(),
                  ],
                  const SizedBox(height: 32),
                  _buildFooterPill(),
                  const SizedBox(height: 40),
                ],
              ),
            )),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFFE5F7ED),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.local_florist, color: AppTheme.primary, size: 32),
        ),
        const SizedBox(height: 16),
        Text(
          _shopName,
          style: const TextStyle(
              fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 4),
        const Text(
          'Ayuda e Información',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildContactCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Contacto Directo',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
          const SizedBox(height: 12),
          Text(
            '¿Necesitas ayuda con tu pedido actual?\nNuestro equipo está listo para asistirte.',
            style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.4),
          ),
          const SizedBox(height: 24),
          if (_whatsapp.isNotEmpty)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => _launchWhatsApp(_whatsapp),
                icon: const Icon(Icons.chat, size: 20),
                label: const Text('Chat por WhatsApp',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1ECA65),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26)),
                  elevation: 0,
                ),
              ),
            ),
          if (_whatsapp.isNotEmpty) const SizedBox(height: 12),
          if (_phone.isNotEmpty)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => _launchPhone(_phone),
                icon: const Icon(Icons.phone, size: 20, color: AppTheme.primary),
                label: const Text('Llamar a sucursal',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey[200]!),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26)),
                ),
              ),
            ),
          if (_phone.isNotEmpty) const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                final shopId = widget.shopId ?? Supabase.instance.client.auth.currentUser?.id ?? '';
                context.push('/shop/payment-methods', extra: shopId);
              },
              icon: const Icon(Icons.payment, size: 20),
              label: const Text('Formas de Pago',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEEFBF4),
                foregroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF6B9A84),
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildFaqList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: _visibleFaqs
            .asMap()
            .entries
            .map((entry) => Padding(
                  padding: EdgeInsets.only(
                      bottom: entry.key < _visibleFaqs.length - 1 ? 12 : 0),
                  child: _buildFaqItem(
                    question: entry.value.question,
                    answer: entry.value.answer,
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildFaqItem({required String question, required String answer}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Theme(
        data: ThemeData().copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFFEEFBF4),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.help_outline,
                color: AppTheme.primary, size: 20),
          ),
          title: Text(
            question,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.black87),
          ),
          iconColor: Colors.grey[400],
          collapsedIconColor: Colors.grey[400],
          childrenPadding: const EdgeInsets.fromLTRB(64, 0, 24, 20),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(answer,
                style: TextStyle(
                    color: Colors.grey[600], height: 1.5, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialLinks() {
    final links = _settings?.linkMethods ?? [];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 32,
        runSpacing: 16,
        children: links
            .map((link) => _buildSocialIcon(link.serviceName, link.url))
            .toList(),
      ),
    );
  }

  Widget _buildSocialIcon(String name, String url) {
    final lower = name.toLowerCase();
    IconData icon;
    if (lower.contains('instagram')) {
      icon = Icons.camera_alt_outlined;
    } else if (lower.contains('facebook')) {
      icon = Icons.facebook;
    } else if (lower.contains('tiktok')) {
      icon = Icons.music_video;
    } else if (lower.contains('twitter') || lower.contains('x')) {
      icon = Icons.alternate_email;
    } else {
      icon = Icons.link;
    }
    return GestureDetector(
      onTap: url.isNotEmpty ? () => _launchUrl(url) : null,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                )
              ],
            ),
            child: Icon(icon, size: 28, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          Text(name, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildFooterPill() {
    final hours = _settings?.storeHours;
    String label = 'Estamos para servirte';
    if (hours != null && hours.isNotEmpty) {
      final first = hours.first;
      String fmt(TimeOfDay t) =>
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      label = 'Horario: ${fmt(first.start)} – ${fmt(first.end)}';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEEFBF4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.circle, size: 8, color: AppTheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
                color: Color(0xFF6B9A84),
                fontSize: 13,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
