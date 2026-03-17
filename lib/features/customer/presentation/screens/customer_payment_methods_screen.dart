// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../profile/domain/models/shop_settings_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../profile/domain/repositories/shop_settings_repository.dart';

class CustomerPaymentMethodsScreen extends StatefulWidget {
  final String shopId;
  const CustomerPaymentMethodsScreen({super.key, required this.shopId});

  @override
  State<CustomerPaymentMethodsScreen> createState() => _CustomerPaymentMethodsScreenState();
}

class _CustomerPaymentMethodsScreenState extends State<CustomerPaymentMethodsScreen> {
  final _repo = ShopSettingsRepository();
  bool _isLoading = true;
  ShopSettingsModel? _settings;
  String _shopName = 'Mi Florería';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _repo.getSettings(widget.shopId);
    String shopName = 'Mi Florería';
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('shop_name')
          .eq('id', widget.shopId)
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
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copiado: $text'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareText(String text) {
    Share.share(text);
  }

  void _shareAll() {
    if (_settings == null) return;
    
    final buffer = StringBuffer();
    buffer.writeln('Formas de Pago - $_shopName\n');

    if (_settings!.bankMethods.isNotEmpty) {
      buffer.writeln('TRANSFERENCIA BANCARIA');
      for (final b in _settings!.bankMethods) {
        buffer.writeln('${b.bankName} (${b.accountType})');
        buffer.writeln('Titular: ${b.holderName}');
        buffer.writeln('Cuenta: ${b.accountNumber}');
        buffer.writeln('CLABE: ${b.clabe}\n');
      }
    }

    if (_settings!.linkMethods.isNotEmpty) {
      buffer.writeln('LINKS DE PAGO');
      for (final l in _settings!.linkMethods) {
        final uri = Uri.tryParse(l.url);
        if (uri == null || !uri.isAbsolute || uri.scheme != 'https') continue;
        buffer.writeln('${l.serviceName}');
        buffer.writeln('${l.url}\n');
      }
    }

    Share.share(buffer.toString().trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFDFA),
      appBar: AppBar(
        title: const Text(
          'Formas de Pago',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => context.pop(),
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            SizedBox(
               width: double.infinity,
               height: 52,
               child: ElevatedButton.icon(
                onPressed: _shareAll,
                icon: const Icon(Icons.share, size: 20),
                label: const Text('Compartir todo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_settings != null) ...[
              if (_settings!.bankMethods.isNotEmpty) ..._settings!.bankMethods.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildBankAccountCard(
                  context: context,
                  bankName: b.bankName,
                  accountType: b.accountType,
                  ownerName: b.holderName,
                  accountNumber: b.accountNumber,
                  clabe: b.clabe,
                  iconBackgroundColor: b.bankName.toLowerCase().contains('banamex') ? Colors.red[50]! : Colors.blue[50]!,
                  iconColor: b.bankName.toLowerCase().contains('banamex') ? Colors.red[600]! : Colors.blue[600]!,
                  isBanamex: b.bankName.toLowerCase().contains('banamex'),
                ),
              )),
              if (_settings!.linkMethods.isNotEmpty) ..._settings!.linkMethods.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildDigitalPaymentCard(
                  context: context,
                  name: l.serviceName,
                  link: l.url,
                  icon: l.serviceName.toLowerCase().contains('paypal') ? Icons.paypal : (l.serviceName.toLowerCase().contains('mercado') ? Icons.handshake : Icons.link),
                  iconBgColor: l.serviceName.toLowerCase().contains('paypal') ? Colors.blue[50]! : (l.serviceName.toLowerCase().contains('mercado') ? Colors.cyan[50]! : Colors.purple[50]!),
                  iconColor: l.serviceName.toLowerCase().contains('paypal') ? Colors.blue[700]! : (l.serviceName.toLowerCase().contains('mercado') ? Colors.cyan[600]! : Colors.purple!),
                ),
              )),
              if (_settings!.bankMethods.isEmpty && _settings!.linkMethods.isEmpty)
                const Center(child: Text('No hay métodos de pago configurados.', style: TextStyle(color: Colors.grey))),
            ],
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildBankAccountCard({
    required BuildContext context,
    required String bankName,
    required String accountType,
    required String ownerName,
    required String accountNumber,
    required String clabe,
    required Color iconBackgroundColor,
    required Color iconColor,
    bool isBanamex = false,
  }) {
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isBanamex ? Icons.account_balance_wallet : Icons.account_balance, 
                  color: iconColor, 
                  size: 20
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(bankName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                  Text(accountType, style: const TextStyle(color: Color(0xFF6B9A84), fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
             decoration: BoxDecoration(
               color: const Color(0xFFF6FBF8),
               borderRadius: BorderRadius.circular(16),
             ),
             padding: const EdgeInsets.all(20),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 const Text('TITULAR', style: TextStyle(color: Color(0xFF6B9A84), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                 const SizedBox(height: 4),
                 Text(ownerName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87)),
                 const SizedBox(height: 20),
                 
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         const Text('CUENTA', style: TextStyle(color: Color(0xFF6B9A84), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                         const SizedBox(height: 4),
                         Text(accountNumber, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: Colors.black87, fontFamily: 'monospace')),
                       ],
                     ),
                     Row(
                       children: [
                         IconButton(
                           icon: const Icon(Icons.copy, color: AppTheme.primary, size: 20),
                           onPressed: () => _copyToClipboard(context, accountNumber),
                           padding: EdgeInsets.zero,
                           constraints: const BoxConstraints(),
                         ),
                         const SizedBox(width: 16),
                         IconButton(
                           icon: const Icon(Icons.ios_share, color: AppTheme.primary, size: 20),
                           onPressed: () => _shareText(accountNumber),
                           padding: EdgeInsets.zero,
                           constraints: const BoxConstraints(),
                         ),
                       ],
                     )
                   ],
                 ),
                 const SizedBox(height: 20),
                 
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         const Text('CLABE', style: TextStyle(color: Color(0xFF6B9A84), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                         const SizedBox(height: 4),
                         Text(clabe, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: Colors.black87, fontFamily: 'monospace')),
                       ],
                     ),
                     Row(
                       children: [
                         IconButton(
                           icon: const Icon(Icons.copy, color: AppTheme.primary, size: 20),
                           onPressed: () => _copyToClipboard(context, clabe),
                           padding: EdgeInsets.zero,
                           constraints: const BoxConstraints(),
                         ),
                         const SizedBox(width: 16),
                         IconButton(
                           icon: const Icon(Icons.ios_share, color: AppTheme.primary, size: 20),
                           onPressed: () => _shareText(clabe),
                           padding: EdgeInsets.zero,
                           constraints: const BoxConstraints(),
                         ),
                       ],
                     )
                   ],
                 )
               ],
             ),
          )
        ],
      ),
    );
  }

  Widget _buildDigitalPaymentCard({
    required BuildContext context,
    required String name,
    required String link,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
  }) {
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
           Container(
             padding: const EdgeInsets.all(12),
             decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
             child: Icon(icon, color: iconColor, size: 24),
           ),
           const SizedBox(width: 16),
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                 const SizedBox(height: 2),
                 Text(link, style: const TextStyle(color: Color(0xFF6B9A84), fontSize: 13, decoration: TextDecoration.underline)),
               ],
             ),
           ),
           Row(
             children: [
               IconButton(
                 icon: const Icon(Icons.copy, color: AppTheme.primary, size: 20),
                 onPressed: () => _copyToClipboard(context, link),
                 padding: EdgeInsets.zero,
                 constraints: const BoxConstraints(),
               ),
               const SizedBox(width: 16),
               IconButton(
                 icon: const Icon(Icons.ios_share, color: AppTheme.primary, size: 20),
                 onPressed: () => _shareText(link),
                 padding: EdgeInsets.zero,
                 constraints: const BoxConstraints(),
               ),
             ],
           )
        ],
      ),
    );
  }
}
