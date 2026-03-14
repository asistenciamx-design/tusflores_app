import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/shop_settings_model.dart';
import '../../domain/repositories/shop_settings_repository.dart';
import 'add_payment_method_screen.dart';
import 'payment_method_success_screen.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _repo = ShopSettingsRepository();
  bool _isLoading = true;
  ShopSettingsModel? _settings;
  String _shopId = '';
  String _shopName = 'Mi Florería';

  // Pre-defined simple payment options
  static const _kDirectOptions = [
    ('Efectivo', Icons.payments_outlined),
    ('Tarjeta / Terminal', Icons.credit_card),
    ('Depósito bancario', Icons.account_balance),
    ('Clábes / SPEI', Icons.swap_horiz),
    ('Cheque', Icons.receipt_long),
  ];

  List<BankMethod> get bankMethods => _settings?.bankMethods ?? [];
  List<LinkMethod> get linkMethods => _settings?.linkMethods ?? [];
  List<String> get simplePayments => _settings?.simplePayments ?? ['Efectivo'];
  bool get trackingLinkEnabled => _settings?.trackingLinkEnabled ?? true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      _shopId = user.id;
      final settings = await _repo.getSettings(_shopId);
      String shopName = 'Mi Florería';
      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('shop_name')
            .eq('id', _shopId)
            .maybeSingle();
        shopName = profile?['shop_name'] ?? 'Mi Florería';
      } catch (_) {}
      if (mounted) {
        setState(() {
          _settings = settings;
          _shopName = shopName;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (_settings != null) {
      await _repo.updateSettings(_shopId, _settings!);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Métodos de Pago', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 2,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildTabBar(),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTransferenciaTab(),
                _buildLinkTab(),
                _buildDirectPaymentTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: AppTheme.primary,
        unselectedLabelColor: AppTheme.mutedLight,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        tabs: const [
          Tab(text: 'Transferencia'),
          Tab(text: 'Link de Pago'),
          Tab(text: 'Efectivo/Otros'),
        ],
      ),
    );
  }

  Widget _buildDirectPaymentTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F0FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF7C3AED), size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Activa los métodos de pago directo que aceptas. Estos aparecerán en "Pend. Pago" al confirmar un pedido.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF5B21B6)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ..._kDirectOptions.map((opt) {
          final (label, icon) = opt;
          final isOn = simplePayments.contains(label);
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isOn
                    ? AppTheme.primary.withValues(alpha: 0.6)
                    : Colors.grey.shade200,
                width: isOn ? 1.5 : 1,
              ),
            ),
            child: SwitchListTile(
              value: isOn,
              onChanged: (val) => _toggleSimplePayment(label, val),
              secondary: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isOn
                      ? AppTheme.primary.withValues(alpha: 0.1)
                      : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon,
                    color: isOn ? AppTheme.primary : Colors.grey.shade400,
                    size: 20),
              ),
              title: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isOn ? AppTheme.textLight : Colors.grey.shade500,
                ),
              ),
              activeColor: AppTheme.primary,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          );
        }),
        const SizedBox(height: 24),
        // ── Seguimiento de pedido ──────────────────────────────────────────
        const Divider(),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.pin_drop_outlined, size: 16, color: Color(0xFF888899)),
            const SizedBox(width: 6),
            const Text(
              'Seguimiento de pedido',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF888899)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: trackingLinkEnabled
                  ? AppTheme.primary.withValues(alpha: 0.6)
                  : Colors.grey.shade200,
              width: trackingLinkEnabled ? 1.5 : 1,
            ),
          ),
          child: SwitchListTile(
            value: trackingLinkEnabled,
            onChanged: _toggleTrackingLink,
            secondary: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: trackingLinkEnabled
                    ? AppTheme.primary.withValues(alpha: 0.1)
                    : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.track_changes_rounded,
                  color: trackingLinkEnabled ? AppTheme.primary : Colors.grey.shade400,
                  size: 20),
            ),
            title: Text(
              'Incluir link de seguimiento',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: trackingLinkEnabled ? AppTheme.textLight : Colors.grey.shade500,
              ),
            ),
            subtitle: Text(
              trackingLinkEnabled
                  ? 'El comprador puede rastrear su pedido'
                  : 'No se incluye en el mensaje de WhatsApp',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
            activeColor: AppTheme.primary,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _toggleTrackingLink(bool value) async {
    if (_settings == null) return;
    setState(() {
      _settings = ShopSettingsModel(
        storeHours: _settings!.storeHours,
        deliveryRanges: _settings!.deliveryRanges,
        shippingRates: _settings!.shippingRates,
        bankMethods: _settings!.bankMethods,
        linkMethods: _settings!.linkMethods,
        faqs: _settings!.faqs,
        simplePayments: _settings!.simplePayments,
        branchImagePath: _settings!.branchImagePath,
        country: _settings!.country,
        state: _settings!.state,
        city: _settings!.city,
        address: _settings!.address,
        mapsUrl: _settings!.mapsUrl,
        references: _settings!.references,
        phone: _settings!.phone,
        whatsapp: _settings!.whatsapp,
        showMapOnProfile: _settings!.showMapOnProfile,
        trackingLinkEnabled: value,
        catalogMessage: _settings!.catalogMessage,
        catalogImageUrl: _settings!.catalogImageUrl,
      );
    });
    await _saveSettings();
  }

  Future<void> _toggleSimplePayment(String label, bool add) async {
    if (_settings == null) return;
    final current = List<String>.from(simplePayments);
    if (add) {
      if (!current.contains(label)) current.add(label);
    } else {
      current.remove(label);
    }
    setState(() {
      _settings = ShopSettingsModel(
        storeHours: _settings!.storeHours,
        deliveryRanges: _settings!.deliveryRanges,
        shippingRates: _settings!.shippingRates,
        bankMethods: _settings!.bankMethods,
        linkMethods: _settings!.linkMethods,
        faqs: _settings!.faqs,
        simplePayments: current,
        branchImagePath: _settings!.branchImagePath,
        country: _settings!.country,
        state: _settings!.state,
        city: _settings!.city,
        address: _settings!.address,
        mapsUrl: _settings!.mapsUrl,
        references: _settings!.references,
        phone: _settings!.phone,
        whatsapp: _settings!.whatsapp,
        showMapOnProfile: _settings!.showMapOnProfile,
        trackingLinkEnabled: _settings!.trackingLinkEnabled,
        catalogMessage: _settings!.catalogMessage,
        catalogImageUrl: _settings!.catalogImageUrl,
      );
    });
    await _saveSettings();
  }

  Widget _buildTransferenciaTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        _buildShareAllButton(isTransfer: true),
        const SizedBox(height: 16),
        ...bankMethods.asMap().entries.map((e) => _buildBankCard(e.key, e.value)),
        _buildAddMethodButton(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildLinkTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        _buildShareAllButton(isTransfer: false),
        const SizedBox(height: 16),
        ...linkMethods.asMap().entries.map((e) => _buildLinkCard(e.key, e.value)),
        _buildAddMethodButton(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildShareAllButton({required bool isTransfer}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          final String message;
          if (isTransfer) {
            final buffer = StringBuffer();
            buffer.writeln('💳 *Formas de pago — $_shopName*\n');
            buffer.writeln('🏦 *Transferencia bancaria*');
            for (final b in bankMethods) {
              buffer.writeln('• ${b.bankName} (${b.accountType})');
              buffer.writeln('  Titular: ${b.holderName}');
              buffer.writeln('  Cuenta: ${b.accountNumber}');
              buffer.writeln('  CLABE: ${b.clabe}');
            }
            buffer.writeln('\n¡Gracias por tu compra! 🌸');
            message = buffer.toString().trim();
          } else {
            final buffer = StringBuffer();
            buffer.writeln('💳 *Formas de pago — $_shopName*\n');
            buffer.writeln('🔗 *Links de pago*');
            for (final l in linkMethods) {
              buffer.writeln('• ${l.serviceName}: https://${l.url}');
            }
            buffer.writeln('\n¡Gracias por tu compra! 🌸');
            message = buffer.toString().trim();
          }
          Share.share(message, subject: 'Formas de pago — $_shopName');
        },
        icon: const Icon(Icons.share, size: 20),
        label: Text(isTransfer ? 'Compartir como texto' : 'Compartir todo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildBankCard(int idx, BankMethod method) {
    final IconData bankIcon = method.bankName == 'BBVA' ? Icons.account_balance : Icons.account_balance_wallet;
    final Color bankColor = method.bankName == 'BBVA' ? const Color(0xFF004481) : const Color(0xFFCC0000);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(backgroundColor: bankColor.withValues(alpha: 0.1), child: Icon(bankIcon, color: bankColor, size: 20)),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(method.bankName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(method.accountType, style: const TextStyle(color: AppTheme.mutedLight, fontSize: 12)),
                  ],
                )),
                _buildIconAction(Icons.copy, () => Clipboard.setData(ClipboardData(text: '${method.bankName}\n${method.holderName}\nCuenta: ${method.accountNumber}\nCLABE: ${method.clabe}'))),
                const SizedBox(width: 4),
                _buildIconAction(Icons.ios_share, () => Share.share('${method.bankName} (${method.accountType})\nTitular: ${method.holderName}\nCuenta: ${method.accountNumber}\nCLABE: ${method.clabe}', subject: 'Datos bancarios — $_shopName')),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _buildDetailRow('TITULAR', method.holderName),
              const SizedBox(height: 8),
              _buildDetailRow('CUENTA', method.accountNumber),
              const SizedBox(height: 8),
              _buildDetailRow('CLABE', method.clabe),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkCard(int idx, LinkMethod method) {
    final Map<String, dynamic> serviceInfo = _getServiceInfo(method.serviceName);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: (serviceInfo['color'] as Color).withValues(alpha: 0.1),
            child: Icon(serviceInfo['icon'] as IconData, color: serviceInfo['color'] as Color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(method.serviceName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text(method.url, style: const TextStyle(color: AppTheme.mutedLight, fontSize: 12)),
            ],
          )),
          _buildIconAction(Icons.copy, () => Clipboard.setData(ClipboardData(text: 'https://${method.url}'))),
          const SizedBox(width: 4),
          _buildIconAction(Icons.ios_share, () => Share.share('${method.serviceName}: https://${method.url}', subject: 'Link de pago — $_shopName')),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(children: [
      SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.mutedLight, letterSpacing: 0.5))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 14, color: AppTheme.textLight, fontWeight: FontWeight.w500))),
    ]);
  }

  Widget _buildIconAction(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppTheme.primary, size: 18),
      ),
    );
  }

  void _openAddMethod() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddPaymentMethodScreen()),
    );
    if (result != null && mounted && _settings != null) {
      if (result is BankMethod) {
        setState(() {
           _settings = ShopSettingsModel(
             storeHours: _settings!.storeHours,
             deliveryRanges: _settings!.deliveryRanges,
             shippingRates: _settings!.shippingRates,
             bankMethods: [..._settings!.bankMethods, result],
             linkMethods: _settings!.linkMethods,
             faqs: _settings!.faqs,
             branchImagePath: _settings!.branchImagePath,
             country: _settings!.country,
             state: _settings!.state,
             city: _settings!.city,
             address: _settings!.address,
             mapsUrl: _settings!.mapsUrl,
             references: _settings!.references,
             phone: _settings!.phone,
             whatsapp: _settings!.whatsapp,
             showMapOnProfile: _settings!.showMapOnProfile,
           );
        });
        await _saveSettings();
        if (mounted) {
          final addAnother = await Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentMethodSuccessScreen(bankMethod: result))) ?? false;
          if (addAnother) _openAddMethod();
        }
      } else if (result is LinkMethod) {
        setState(() {
           _settings = ShopSettingsModel(
             storeHours: _settings!.storeHours,
             deliveryRanges: _settings!.deliveryRanges,
             shippingRates: _settings!.shippingRates,
             bankMethods: _settings!.bankMethods,
             linkMethods: [..._settings!.linkMethods, result],
             faqs: _settings!.faqs,
             branchImagePath: _settings!.branchImagePath,
             country: _settings!.country,
             state: _settings!.state,
             city: _settings!.city,
             address: _settings!.address,
             mapsUrl: _settings!.mapsUrl,
             references: _settings!.references,
             phone: _settings!.phone,
             whatsapp: _settings!.whatsapp,
             showMapOnProfile: _settings!.showMapOnProfile,
           );
        });
        await _saveSettings();
        if (mounted) {
          final addAnother = await Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentMethodSuccessScreen(linkMethod: result))) ?? false;
          if (addAnother) _openAddMethod();
        }
      }
    }
  }

  Widget _buildAddMethodButton() {
    return GestureDetector(
      onTap: _openAddMethod,
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4), width: 1.5),
          color: AppTheme.primary.withValues(alpha: 0.03),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 24, height: 24, decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle), child: const Icon(Icons.add, color: Colors.white, size: 16)),
            const SizedBox(width: 8),
            const Text('Agregar método de pago', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getServiceInfo(String name) {
    switch (name.toLowerCase()) {
      case 'paypal': return {'icon': Icons.payment, 'color': const Color(0xFF003087)};
      case 'mercado pago': return {'icon': Icons.handshake, 'color': const Color(0xFF009EE3)};
      default: return {'icon': Icons.link, 'color': Colors.purple};
    }
  }
}
