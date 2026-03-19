import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/repositories/profile_repository.dart';

class ConnectWhatsAppScreen extends StatefulWidget {
  const ConnectWhatsAppScreen({super.key});

  @override
  State<ConnectWhatsAppScreen> createState() => _ConnectWhatsAppScreenState();
}

class _ConnectWhatsAppScreenState extends State<ConnectWhatsAppScreen> {
  final _phoneCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) return;
    if (phone.length < 10) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Guarda en Supabase
      await ProfileRepository().updateProfile(whatsappNumber: phone);
      if (mounted) context.push('/account-verified');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al guardar el número.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textLight),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Conecta tu WhatsApp',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
                const SizedBox(height: 12),
                const Text('Para recibir pedidos y notificaciones de tus clientes al instante.',
                  style: TextStyle(fontSize: 15, color: AppTheme.mutedLight, height: 1.4)),
                const SizedBox(height: 48),

                const Text('Número de WhatsApp', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textLight)),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Container(
                      width: 90,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('🇲🇽', style: TextStyle(fontSize: 20)),
                          SizedBox(width: 4),
                          Text('+52', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        maxLength: 15,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '55 1234 5678',
                          filled: true,
                          fillColor: Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
                        ),
                        onChanged: (val) => setState((){}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (_phoneCtrl.text.trim().isEmpty || _isLoading) ? null : _sendCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Guardar y Continuar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
