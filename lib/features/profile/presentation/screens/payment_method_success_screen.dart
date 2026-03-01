import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/shop_settings_model.dart';

class PaymentMethodSuccessScreen extends StatefulWidget {
  final BankMethod? bankMethod;
  final LinkMethod? linkMethod;

  const PaymentMethodSuccessScreen({super.key, this.bankMethod, this.linkMethod});

  @override
  State<PaymentMethodSuccessScreen> createState() => _PaymentMethodSuccessScreenState();
}

class _PaymentMethodSuccessScreenState extends State<PaymentMethodSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  bool get _isLink => widget.linkMethod != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // Close button
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst || route.settings.name == '/payment-methods');
                    Navigator.pop(context);
                  },
                ),
              ),
            ),

            const Spacer(),

            // Animated checkmark circle
            ScaleTransition(
              scale: _scaleAnim,
              child: Container(
                width: 100, height: 100,
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 52),
              ),
            ),
            const SizedBox(height: 28),

            // Title
            FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  Text(
                    _isLink ? '¡Enlace Guardado!' : '¡Método Guardado!',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Text(
                      _isLink
                          ? 'Tu nuevo link de pago ha sido activado y ya puedes compartirlo con tus clientes.'
                          : 'Tu cuenta bancaria ha sido guardada y ya está disponible en tu perfil.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.mutedLight, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Preview Card
            FadeTransition(
              opacity: _fadeAnim,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildPreviewCard(),
              ),
            ),

            const Spacer(),

            // Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                      child: const Text('Ver mis métodos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textLight,
                        side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text('Añadir otro', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    if (_isLink) {
      final link = widget.linkMethod!;
      final Map<String, dynamic> info = _getServiceInfo(link.serviceName);
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: (info['color'] as Color).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(info['icon'] as IconData, color: info['color'] as Color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(link.serviceName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text(link.url, style: const TextStyle(color: AppTheme.mutedLight, fontSize: 12)),
            ])),
            const Icon(Icons.link, color: AppTheme.primary, size: 22),
          ],
        ),
      );
    } else {
      final bank = widget.bankMethod!;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.account_balance, color: Colors.blue, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(bank.bankName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text(bank.holderName, style: const TextStyle(color: AppTheme.mutedLight, fontSize: 12)),
            ])),
            const Icon(Icons.check_circle, color: AppTheme.primary, size: 22),
          ],
        ),
      );
    }
  }

  Map<String, dynamic> _getServiceInfo(String name) {
    switch (name.toLowerCase()) {
      case 'paypal': return {'icon': Icons.payment, 'color': const Color(0xFF003087)};
      case 'mercado pago': return {'icon': Icons.handshake, 'color': const Color(0xFF009EE3)};
      default: return {'icon': Icons.link, 'color': Colors.purple};
    }
  }
}
