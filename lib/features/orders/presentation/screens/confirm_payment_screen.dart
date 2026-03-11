import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../profile/domain/repositories/shop_settings_repository.dart';
import '../../domain/models/order_model.dart';
import 'orders_screen.dart';

// ─── Confirm Payment Screen ────────────────────────────────────────────────────

class ConfirmPaymentScreen extends StatefulWidget {
  final OrderModel order;
  final VoidCallback? onPaymentConfirmed;

  const ConfirmPaymentScreen({
    super.key,
    required this.order,
    this.onPaymentConfirmed,
  });

  @override
  State<ConfirmPaymentScreen> createState() => _ConfirmPaymentScreenState();
}

class _ConfirmPaymentScreenState extends State<ConfirmPaymentScreen> {
  int _selectedMethod = 0;
  bool _saved = false;
  bool _isLoading = true;
  List<_PaymentMethod> _methods = [];
  String _shopName = 'Mi Florería';

  @override
  void initState() {
    super.initState();
    _loadMethods();
  }

  Future<void> _loadMethods() async {
    final list = <_PaymentMethod>[];
    
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final settings = await ShopSettingsRepository().getSettings(user.id);

      // ── Direct / simple payment types (configured in Profile → Métodos de Pago)
      final simplePayments = settings?.simplePayments ?? ['Efectivo'];
      for (final label in simplePayments) {
        final (icon, color) = _simplePaymentIcon(label);
        list.add(_PaymentMethod(label: label, icon: icon, color: color));
      }

      // ── Bank transfer accounts
      final bankMethods = settings?.bankMethods ?? [];
      for (final b in bankMethods) {
        final isBBVA = b.bankName.toUpperCase().contains('BBVA');
        list.add(_PaymentMethod(
          label: b.bankName,
          iconText: isBBVA ? 'B' : b.bankName.substring(0, b.bankName.length.clamp(0, 4)),
          color: isBBVA ? const Color(0xFF004A98) : const Color(0xFFCC0000),
          detail: b.accountNumber,
        ));
      }

      // ── Payment links (PayPal, Mercado Pago, etc.)
      final linkMethods = settings?.linkMethods ?? [];
      for (final l in linkMethods) {
        final info = _getLinkInfo(l.serviceName);
        list.add(_PaymentMethod(
          label: l.serviceName,
          icon: info['icon'] as IconData?,
          iconText: info['iconText'] as String?,
          color: info['color'] as Color,
          detail: l.url,
        ));
      }
    }

    // Fallback: if nothing configured show Efectivo
    if (list.isEmpty) {
      list.add(const _PaymentMethod(
        label: 'Efectivo',
        icon: Icons.payments_outlined,
        color: AppTheme.primary,
      ));
    }

    // Pre-select the method that was previously saved on this order
    int preselected = 0;
    final saved = widget.order.paymentMethod;
    if (saved != null && saved.isNotEmpty) {
      final idx = list.indexWhere(
          (m) => saved.toLowerCase().contains(m.label.toLowerCase()));
      if (idx >= 0) preselected = idx;
    }

    String shopName = 'Mi Florería';
    try {
      if (user != null) {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('shop_name')
            .eq('id', user.id)
            .maybeSingle();
        shopName = profile?['shop_name'] ?? 'Mi Florería';
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _methods = list;
        _selectedMethod = preselected;
        _shopName = shopName;
        _isLoading = false;
      });
    }
  }

  /// Returns icon + color for common simple payment labels.
  (IconData, Color) _simplePaymentIcon(String label) {
    final l = label.toLowerCase();
    if (l.contains('tarjeta') || l.contains('terminal')) {
      return (Icons.credit_card, const Color(0xFF0369A1));
    }
    if (l.contains('dep') || l.contains('banco')) {
      return (Icons.account_balance, const Color(0xFF065F46));
    }
    if (l.contains('clabe') || l.contains('spei')) {
      return (Icons.swap_horiz, const Color(0xFF7C3AED));
    }
    if (l.contains('cheque')) {
      return (Icons.receipt_long, const Color(0xFF92400E));
    }
    // Default = Efectivo / cash
    return (Icons.payments_outlined, AppTheme.primary);
  }


  Map<String, dynamic> _getLinkInfo(String name) {
    switch (name.toLowerCase()) {
      case 'paypal':
        return {'icon': null, 'iconText': 'P', 'color': const Color(0xFF003087)};
      case 'mercado pago':
        return {'icon': Icons.handshake_outlined, 'iconText': null, 'color': const Color(0xFF009EE3)};
      default:
        return {'icon': Icons.link, 'iconText': null, 'color': Colors.purple};
    }
  }

  String get _selectedMethodLabel => _methods[_selectedMethod].label;
  String? get _selectedMethodDetail => _methods[_selectedMethod].detail;

  // ─── Receipt text ─────────────────────────────────────────────────────────

  String _buildReceipt() {
    final method = _selectedMethodLabel;
    final detail = _selectedMethodDetail != null ? ' - $_selectedMethodDetail' : '';
    
    final oldMethod = widget.order.paymentMethod;
    final oldPaid = widget.order.isPaid;
    
    // Temporarily mutate order to reflect selected UI state for the receipt
    widget.order.paymentMethod = '$method$detail';
    widget.order.isPaid = true;
    
    final receipt = widget.order.toShareMessage(isReceipt: true, shopName: _shopName);
    
    // Revert state
    widget.order.paymentMethod = oldMethod;
    widget.order.isPaid = oldPaid;
    
    return receipt;
  }

  Future<void> _shareViaWhatsApp() async {
    final msg = Uri.encodeComponent(_buildReceipt());
    final phone = widget.order.customerPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final url = phone.isNotEmpty
        ? Uri.parse('https://wa.me/52$phone?text=$msg')
        : Uri.parse('https://api.whatsapp.com/send?text=$msg');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir WhatsApp'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
            child: const Icon(Icons.arrow_back_ios_new, size: 16, color: AppTheme.textLight),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Confirmar Pago',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.textLight)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Total card ────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              const Text('TOTAL A PAGAR',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.mutedLight, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Text('\$${((widget.order.price * widget.order.quantity) + widget.order.shippingCost).toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: AppTheme.primary)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(30)),
                child: Text('FOLIO ${widget.order.folio}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.mutedLight, fontSize: 13, letterSpacing: 0.5)),
              ),
              const SizedBox(height: 8),
              Text(widget.order.customerName,
                  style: const TextStyle(color: AppTheme.mutedLight, fontSize: 13)),
            ]),
          ),
          const SizedBox(height: 24),

          // ── Method selector ───────────────────────────────────────────────
          const Text('Selecciona método de pago',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
          const SizedBox(height: 14),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            _buildPaymentGrid(),
          const SizedBox(height: 28),

          // ── Save button ───────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saved ? null : () {
                setState(() => _saved = true);
                widget.onPaymentConfirmed?.call();
                Navigator.pop(context, _selectedMethodLabel); // return method name
              },
              icon: const Icon(Icons.save_alt, size: 20),
              label: Text(_saved ? '¡Guardado!' : 'Guardar Pago',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _saved ? Colors.grey : AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Ver recibo ────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Share.share(_buildReceipt(), subject: 'Recibo ${widget.order.folio} — $_shopName'),
              icon: const Padding(
                padding: EdgeInsets.only(bottom: 2.0),
                child: Icon(Icons.receipt_long, size: 18, color: AppTheme.primary),
              ),
              label: const Text('Ver Recibo',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primary)),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                side: const BorderSide(color: AppTheme.primary, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Compartir por WhatsApp ────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _shareViaWhatsApp,
              icon: const Padding(
                padding: EdgeInsets.only(bottom: 2.0),
                child: Icon(Icons.chat_bubble_outline, size: 18),
              ),
              label: const Text('Compartir Recibo por WhatsApp',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE8F5E9), // Light green background
                foregroundColor: AppTheme.primary, // Green text/icon
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ─── Payment Grid ─────────────────────────────────────────────────────────

  Widget _buildPaymentGrid() {
    final firstFour = _methods.length >= 4 ? _methods.sublist(0, 4) : _methods;
    final rest = _methods.length > 4 ? _methods.sublist(4) : <_PaymentMethod>[];

    return Column(children: [
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.3,
        children: List.generate(firstFour.length, (i) => _buildMethodCard(i, firstFour[i])),
      ),
      if (rest.isNotEmpty) ...[
        const SizedBox(height: 12),
        ...rest.asMap().entries.map((e) {
          final i = e.key + firstFour.length;
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            child: _buildMethodCard(i, e.value, wide: true),
          );
        }),
      ],
    ]);
  }

  Widget _buildMethodCard(int index, _PaymentMethod method, {bool wide = false}) {
    final selected = _selectedMethod == index;
    final textColor = selected ? AppTheme.primary : AppTheme.textLight;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppTheme.primary : Colors.transparent, width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(16),
        child: Stack(children: [
          if (wide)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _methodIcon(method),
              const SizedBox(width: 14),
              Text(method.label,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor)),
            ])
          else
            Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [
              _methodIcon(method),
              const SizedBox(height: 12),
              Text(method.label,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: textColor),
                  textAlign: TextAlign.center),
            ]),
          if (selected)
            Positioned(
              top: 0, right: 0,
              child: Container(
                width: 20, height: 20,
                decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                child: const Icon(Icons.check, size: 13, color: Colors.white),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _methodIcon(_PaymentMethod m) {
    if (m.icon != null) {
      return Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: m.color.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(m.icon, color: m.color, size: 24),
      );
    }
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(color: m.color.withValues(alpha: 0.1), shape: BoxShape.circle),
      child: Center(
        child: Text(m.iconText ?? '?',
            style: TextStyle(
                color: m.color,
                fontWeight: FontWeight.bold,
                fontSize: (m.iconText?.length ?? 1) > 2 ? 10 : 16)),
      ),
    );
  }
}

// ─── Model ────────────────────────────────────────────────────────────────────

class _PaymentMethod {
  final String label;
  final IconData? icon;
  final String? iconText;
  final Color color;
  final String? detail; // account number or URL

  const _PaymentMethod({
    required this.label,
    required this.color,
    this.icon,
    this.iconText,
    this.detail,
  });
}
