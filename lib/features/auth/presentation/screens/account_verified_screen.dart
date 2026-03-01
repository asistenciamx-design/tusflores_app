import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

class AccountVerifiedScreen extends StatelessWidget {
  const AccountVerifiedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              
              // Ícono de éxito animado/destacado
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: Colors.green, size: 60),
              ),
              const SizedBox(height: 32),
              
              const Text('Cuenta Verificada',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
              const SizedBox(height: 16),
              
              const Text('Tu cuenta de WhatsApp se ha vinculado con éxito a tu florería.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppTheme.mutedLight, height: 1.4)),
              
              const SizedBox(height: 32),

              Container(
                 padding: const EdgeInsets.all(16),
                 decoration: BoxDecoration(
                   color: Colors.grey[50],
                   borderRadius: BorderRadius.circular(12),
                 ),
                 child: const Row(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Icon(Icons.privacy_tip_outlined, color: AppTheme.textLight, size: 24),
                     SizedBox(width: 12),
                     Expanded(
                       child: Text('Respetamos tu privacidad. Tu número solo se usará para notificaciones de pedidos y actualizaciones de clientes.',
                         style: TextStyle(fontSize: 13, color: AppTheme.textLight, height: 1.4)),
                     ),
                   ],
                 ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => context.go('/'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('Ir a mi Dashboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
