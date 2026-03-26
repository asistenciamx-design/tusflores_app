import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? code;
  const ResetPasswordScreen({super.key, this.code});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _sessionReady = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _exchangeCode();
  }

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _exchangeCode() async {
    final code = widget.code;
    if (code == null || code.isEmpty) {
      setState(() => _error = 'Enlace inválido o expirado.');
      return;
    }
    try {
      await Supabase.instance.client.auth.exchangeCodeForSession(code);
      if (mounted) setState(() => _sessionReady = true);
    } catch (e) {
      if (mounted) setState(() => _error = 'El enlace expiró o ya fue usado. Solicita uno nuevo.');
    }
  }

  Future<void> _updatePassword() async {
    final pass = _passCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    if (pass.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'Completa ambos campos.');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'La contraseña debe tener al menos 6 caracteres.');
      return;
    }
    if (pass != confirm) {
      setState(() => _error = 'Las contraseñas no coinciden.');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: pass),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contraseña actualizada correctamente.'),
            backgroundColor: AppTheme.primary,
          ),
        );
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'No se pudo actualizar. Intenta de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo
              Center(
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_reset, color: AppTheme.primary, size: 36),
                ),
              ),
              const SizedBox(height: 20),
              const Text('tusflores.app',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                    color: AppTheme.textLight, letterSpacing: -0.5)),
              const SizedBox(height: 32),
              const Text('Nueva contraseña',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold,
                    color: AppTheme.textLight)),
              const SizedBox(height: 8),
              const Text('Ingresa tu nueva contraseña para continuar.',
                style: TextStyle(fontSize: 14, color: AppTheme.mutedLight)),
              const SizedBox(height: 32),

              // Estado: cargando / error / formulario
              if (!_sessionReady && _error == null)
                const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              else if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(_error!,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 14)),
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () => context.go('/login'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Volver al inicio de sesión'),
                ),
              ] else ...[
                // Campo nueva contraseña
                const Text('Nueva contraseña',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: AppTheme.textLight)),
                const SizedBox(height: 8),
                TextField(
                  controller: _passCtrl,
                  obscureText: _obscurePass,
                  decoration: InputDecoration(
                    hintText: 'Mínimo 6 caracteres',
                    prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.mutedLight),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility,
                          color: AppTheme.mutedLight),
                      onPressed: () => setState(() => _obscurePass = !_obscurePass),
                    ),
                    filled: true, fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),

                // Confirmar contraseña
                const Text('Confirmar contraseña',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: AppTheme.textLight)),
                const SizedBox(height: 8),
                TextField(
                  controller: _confirmCtrl,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    hintText: 'Repite tu contraseña',
                    prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.mutedLight),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility,
                          color: AppTheme.mutedLight),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    filled: true, fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
                ],

                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _updatePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Guardar contraseña',
                            style: TextStyle(fontSize: 16,
                                fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
