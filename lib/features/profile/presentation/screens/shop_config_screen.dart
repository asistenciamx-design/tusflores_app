import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_cache.dart';
import '../../domain/models/shop_settings_model.dart';
import '../../domain/repositories/shop_settings_repository.dart';

class ShopConfigScreen extends StatefulWidget {
  const ShopConfigScreen({super.key});

  @override
  State<ShopConfigScreen> createState() => _ShopConfigScreenState();
}

class _ShopConfigScreenState extends State<ShopConfigScreen> {
  final _repo = ShopSettingsRepository();
  final _unavailableMsgController = TextEditingController();
  ShopSettingsModel? _settings;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _unavailableMsgController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }
    final settings = await _repo.getSettings(userId);
    if (mounted) {
      CurrencyCache.update(settings);
      setState(() {
        _settings = settings;
        _unavailableMsgController.text = settings?.unavailableMessage ?? '';
        _isLoading = false;
      });
    }
  }

  ShopSettingsModel _buildUpdated({
    bool? showMapOnProfile,
    bool? trackingLinkEnabled,
    bool? showReviews,
    bool? isUnavailable,
    String? unavailableMessage,
    bool? sellGiftsStandalone,
    bool? autoTransferShipping,
    String? currencyCode,
    String? currencySymbol,
  }) {
    final c = _settings!;
    return ShopSettingsModel(
      storeHours: c.storeHours,
      deliveryRanges: c.deliveryRanges,
      shippingRates: c.shippingRates,
      bankMethods: c.bankMethods,
      linkMethods: c.linkMethods,
      faqs: c.faqs,
      simplePayments: c.simplePayments,
      branchImagePath: c.branchImagePath,
      country: c.country,
      state: c.state,
      city: c.city,
      address: c.address,
      mapsUrl: c.mapsUrl,
      references: c.references,
      phone: c.phone,
      whatsapp: c.whatsapp,
      showMapOnProfile: showMapOnProfile ?? c.showMapOnProfile,
      trackingLinkEnabled: trackingLinkEnabled ?? c.trackingLinkEnabled,
      showReviews: showReviews ?? c.showReviews,
      isUnavailable: isUnavailable ?? c.isUnavailable,
      unavailableMessage: unavailableMessage ?? c.unavailableMessage,
      sellGiftsStandalone: sellGiftsStandalone ?? c.sellGiftsStandalone,
      autoTransferShipping: autoTransferShipping ?? c.autoTransferShipping,
      catalogMessage: c.catalogMessage,
      catalogImageUrl: c.catalogImageUrl,
      currencyCode: currencyCode ?? c.currencyCode,
      currencySymbol: currencySymbol ?? c.currencySymbol,
      rawData: c.rawData,
    );
  }

  Future<void> _save(ShopSettingsModel updated) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    setState(() => _isSaving = true);
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

  Future<void> _toggle(String field, bool value) async {
    if (_settings == null) return;
    await _save(_buildUpdated(
      showMapOnProfile: field == 'showMapOnProfile' ? value : null,
      trackingLinkEnabled: field == 'trackingLinkEnabled' ? value : null,
      showReviews: field == 'showReviews' ? value : null,
      sellGiftsStandalone: field == 'sellGiftsStandalone' ? value : null,
      autoTransferShipping: field == 'autoTransferShipping' ? value : null,
    ));
  }

  Future<void> _toggleUnavailable(bool value) async {
    if (_settings == null) return;
    final msg = _unavailableMsgController.text.trim();
    await _save(_buildUpdated(
      isUnavailable: value,
      unavailableMessage: msg.isEmpty ? null : msg,
    ));
  }

  Future<void> _saveUnavailableMessage() async {
    if (_settings == null) return;
    final msg = _unavailableMsgController.text.trim();
    await _save(_buildUpdated(unavailableMessage: msg.isEmpty ? null : msg));
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
                    _SectionHeader(title: 'DISPONIBILIDAD'),
                    const SizedBox(height: 12),
                    _buildCard(children: [
                      _ConfigTile(
                        icon: Icons.pause_circle_outline,
                        iconColor: Colors.orange[700]!,
                        iconBg: Colors.orange.withValues(alpha: 0.1),
                        title: 'No disponible',
                        subtitle: 'Marca la tienda como cerrada temporalmente con un aviso.',
                        value: _settings!.isUnavailable,
                        onChanged: _toggleUnavailable,
                        enabled: !_isSaving,
                      ),
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 220),
                        crossFadeState: _settings!.isUnavailable
                            ? CrossFadeState.showFirst
                            : CrossFadeState.showSecond,
                        firstChild: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Motivo que verán tus clientes:',
                                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _unavailableMsgController,
                                enabled: !_isSaving,
                                maxLength: 80,
                                decoration: InputDecoration(
                                  hintText: 'Ej: Vacaciones del 15 al 20 de marzo',
                                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  counterStyle: TextStyle(fontSize: 11, color: Colors.grey[400]),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                onSubmitted: (_) => _saveUnavailableMessage(),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _isSaving ? null : _saveUnavailableMessage,
                                  child: const Text('Guardar mensaje'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        secondChild: const SizedBox.shrink(),
                      ),
                    ]),
                    const SizedBox(height: 24),
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
                    const SizedBox(height: 24),
                    _SectionHeader(title: 'REGALOS'),
                    const SizedBox(height: 12),
                    _buildCard(children: [
                      _ConfigTile(
                        icon: Icons.card_giftcard_outlined,
                        iconColor: Colors.pink.shade400,
                        iconBg: Colors.pink.withValues(alpha: 0.08),
                        title: 'Vender regalos individualmente',
                        subtitle: 'Permite que los clientes compren regalos sin incluir un arreglo floral.',
                        value: _settings!.sellGiftsStandalone,
                        onChanged: (v) => _toggle('sellGiftsStandalone', v),
                        enabled: !_isSaving,
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _SectionHeader(title: 'REPARTO'),
                    const SizedBox(height: 12),
                    _buildCard(children: [
                      _ConfigTile(
                        icon: Icons.delivery_dining_rounded,
                        iconColor: Colors.deepOrange,
                        iconBg: Colors.deepOrange.withValues(alpha: 0.1),
                        title: 'Transferir gasto de envío a repartidor',
                        subtitle: 'Al asignar un repartidor, el monto de envío de la zona se aplica automáticamente como su pago.',
                        value: _settings!.autoTransferShipping,
                        onChanged: (v) => _toggle('autoTransferShipping', v),
                        enabled: !_isSaving,
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _SectionHeader(title: 'MONEDA Y REGIÓN'),
                    const SizedBox(height: 12),
                    _buildCard(children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.currency_exchange, color: Colors.blue, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Moneda',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Divisa que verán tus clientes en precios.',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[500], height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            DropdownButton<String>(
                              value: _settings!.currencyCode,
                              underline: const SizedBox.shrink(),
                              borderRadius: BorderRadius.circular(12),
                              items: const [
                                DropdownMenuItem(value: 'MXN', child: Text('🇲🇽  MXN \$')),
                                DropdownMenuItem(value: 'USD', child: Text('🇺🇸  USD \$')),
                                DropdownMenuItem(value: 'COP', child: Text('🇨🇴  COP \$')),
                                DropdownMenuItem(value: 'ARS', child: Text('🇦🇷  ARS \$')),
                                DropdownMenuItem(value: 'PEN', child: Text('🇵🇪  PEN S/')),
                                DropdownMenuItem(value: 'VES', child: Text('🇻🇪  VES Bs.')),
                                DropdownMenuItem(value: 'CLP', child: Text('🇨🇱  CLP \$')),
                                DropdownMenuItem(value: 'GTQ', child: Text('🇬🇹  GTQ Q')),
                                DropdownMenuItem(value: 'BOB', child: Text('🇧🇴  BOB Bs.')),
                                DropdownMenuItem(value: 'HNL', child: Text('🇭🇳  HNL L')),
                                DropdownMenuItem(value: 'PYG', child: Text('🇵🇾  PYG ₲')),
                                DropdownMenuItem(value: 'NIO', child: Text('🇳🇮  NIO C\$')),
                                DropdownMenuItem(value: 'CRC', child: Text('🇨🇷  CRC ₡')),
                                DropdownMenuItem(value: 'BZD', child: Text('🇧🇿  BZD BZ\$')),
                              ],
                              onChanged: _isSaving ? null : (code) async {
                                if (code == null) return;
                                const symbolMap = {
                                  'MXN': r'$',  'USD': r'$',  'COP': r'$',
                                  'ARS': r'$',  'PEN': 'S/',  'VES': 'Bs.',
                                  'CLP': r'$',  'GTQ': 'Q',   'BOB': 'Bs.',
                                  'HNL': 'L',   'PYG': '₲',  'NIO': r'C$',
                                  'CRC': '₡',   'BZD': r'BZ$',
                                };
                                final updated = _buildUpdated(
                                  currencyCode: code,
                                  currencySymbol: symbolMap[code] ?? r'$',
                                );
                                await _save(updated);
                                CurrencyCache.update(_settings);
                              },
                            ),
                          ],
                        ),
                      ),
                    ]),
                    if (kIsWeb) ...[
                      const SizedBox(height: 8),
                      _SectionHeader(title: 'CÁMARA EN IPHONE'),
                      const SizedBox(height: 12),
                      _buildCameraTipCard(),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
    );
  }

  Widget _buildCameraTipCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFBBF24), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    color: Color(0xFFD97706), size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Activa la cámara en iPhone',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _cameraStep('1', 'Abre Ajustes de iPhone'),
          _cameraStep('2', 'Busca y toca Chrome (o Safari, según tu navegador)'),
          _cameraStep('3', 'Toca "Cámara"'),
          _cameraStep('4', 'Selecciona "Permitir"'),
          _cameraStep('5', 'Regresa a la app y vuelve a intentarlo'),
        ],
      ),
    );
  }

  Widget _cameraStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 1, right: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFFBBF24),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF78350F),
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF78350F),
                height: 1.4,
              ),
            ),
          ),
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
