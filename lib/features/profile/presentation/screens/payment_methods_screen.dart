import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/shop_settings_model.dart';
import '../../domain/repositories/shop_settings_repository.dart';
import 'add_payment_method_screen.dart';

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

  List<BankMethod> get bankMethods => _settings?.bankMethods ?? [];
  List<LinkMethod> get linkMethods => _settings?.linkMethods ?? [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      _shopId = user.id;
      final settings = await _repo.getSettings(_shopId);
      if (mounted) {
        setState(() {
          _settings = settings;
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
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        tabs: const [Tab(text: 'Transferencia'), Tab(text: 'Link de Pago')],
      ),
    );
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
            buffer.writeln('💳 *Formas de pago — Florería Las Rosas*\n');
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
            buffer.writeln('💳 *Formas de pago — Florería Las Rosas*\n');
            buffer.writeln('🔗 *Links de pago*');
            for (final l in linkMethods) {
              buffer.writeln('• ${l.serviceName}: https://${l.url}');
            }
            buffer.writeln('\n¡Gracias por tu compra! 🌸');
            message = buffer.toString().trim();
          }
          Share.share(message, subject: 'Formas de pago — Florería Las Rosas');
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
                _buildIconAction(Icons.ios_share, () => Share.share('${method.bankName} (${method.accountType})\nTitular: ${method.holderName}\nCuenta: ${method.accountNumber}\nCLABE: ${method.clabe}', subject: 'Datos bancarios — Florería Las Rosas')),
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
          _buildIconAction(Icons.ios_share, () => Share.share('${method.serviceName}: https://${method.url}', subject: 'Link de pago — Florería Las Rosas')),
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

  Widget _buildAddMethodButton() {
    return GestureDetector(
      onTap: () async {
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
          } else if (result is LinkMethod) {
            setState(() {
               _settings = ShopSettingsModel(
                 storeHours: _settings!.storeHours,
                 deliveryRanges: _settings!.deliveryRanges,
                 shippingRates: _settings!.shippingRates,
                 bankMethods: _settings!.bankMethods,
                 linkMethods: [..._settings!.linkMethods, result],
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
          }
        }
      },
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
