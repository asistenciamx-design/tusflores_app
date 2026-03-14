import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/shop_settings_model.dart';
import '../../domain/repositories/shop_settings_repository.dart';

class ShopConfigScreen extends StatefulWidget {
  const ShopConfigScreen({super.key});

  @override
  State<ShopConfigScreen> createState() => _ShopConfigScreenState();
}

class _ShopConfigScreenState extends State<ShopConfigScreen> {
  final _repo = ShopSettingsRepository();
  ShopSettingsModel? _settings;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }
    final settings = await _repo.getSettings(userId);
    if (mounted) {
      setState(() {
        _settings = settings;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggle(String field, bool value) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || _settings == null) return;

    setState(() => _isSaving = true);

    // Construir nuevo modelo con el campo modificado
    final current = _settings!;
    final updated = ShopSettingsModel(
      storeHours: current.storeHours,
      deliveryRanges: current.deliveryRanges,
      shippingRates: current.shippingRates,
      bankMethods: current.bankMethods,
      linkMethods: current.linkMethods,
      faqs: current.faqs,
      simplePayments: current.simplePayments,
      branchImagePath: current.branchImagePath,
      country: current.country,
      state: current.state,
      city: current.city,
      address: current.address,
      mapsUrl: current.mapsUrl,
      references: current.references,
      phone: current.phone,
      whatsapp: current.whatsapp,
      showMapOnProfile: field == 'showMapOnProfile' ? value : current.showMapOnProfile,
      trackingLinkEnabled: field == 'trackingLinkEnabled' ? value : current.trackingLinkEnabled,
      showReviews: field == 'showReviews' ? value : current.showReviews,
      catalogMessage: current.catalogMessage,
      catalogImageUrl: current.catalogImageUrl,
      rawData: current.rawData,
    );

    final ok = await _repo.updateSettings(userId, updated);
    if (mounted) {
      setState(() {
        if (ok) _settings = updated;
        _isSaving = false;
      });
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al guardar. Intenta de nuevo.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _settings == null
              ? const Center(child: Text('No se pudo cargar la configuración.'))
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _SectionHeader(title: 'TIENDA PÚBLICA'),
                    const SizedBox(height: 12),
                    _buildCard(children: [
                      _ConfigTile(
                        icon: Icons.star_rounded,
                        iconColor: Colors.amber[700]!,
                        iconBg: Colors.amber.withValues(alpha: 0.1),
                        title: 'Mostrar reseñas',
                        subtitle: 'Muestra el rating y las opiniones de clientes en tu tienda pública.',
                        value: _settings!.showReviews,
                        onChanged: (v) => _toggle('showReviews', v),
                        enabled: !_isSaving,
                      ),
                      _buildDivider(),
                      _ConfigTile(
                        icon: Icons.map_outlined,
                        iconColor: Colors.teal,
                        iconBg: Colors.teal.withValues(alpha: 0.1),
                        title: 'Mostrar mapa en sucursal',
                        subtitle: 'Muestra el mapa de Google Maps en la sección Sucursal.',
                        value: _settings!.showMapOnProfile,
                        onChanged: (v) => _toggle('showMapOnProfile', v),
                        enabled: !_isSaving,
                      ),
                      _buildDivider(),
                      _ConfigTile(
                        icon: Icons.link,
                        iconColor: Colors.indigo,
                        iconBg: Colors.indigo.withValues(alpha: 0.1),
                        title: 'Link de rastreo en pedidos',
                        subtitle: 'Incluye el enlace de seguimiento del pedido en el mensaje de WhatsApp.',
                        value: _settings!.trackingLinkEnabled,
                        onChanged: (v) => _toggle('trackingLinkEnabled', v),
                        enabled: !_isSaving,
                      ),
                    ]),
                    const SizedBox(height: 32),
                  ],
                ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() => Padding(
        padding: const EdgeInsets.only(left: 68),
        child: Divider(height: 1, color: Colors.grey.withValues(alpha: 0.15)),
      );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: AppTheme.mutedLight,
        ),
      ),
    );
  }
}

class _ConfigTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  const _ConfigTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500], height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }
}
