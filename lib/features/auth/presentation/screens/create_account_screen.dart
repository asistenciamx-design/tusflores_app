import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _isLoading = false;
  String _accountType = 'shop_owner'; // 'shop_owner' o 'proveedor'

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos.')),
      );
      return;
    }

    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La contraseña debe tener al menos 8 caracteres.')),
      );
      return;
    }
    if (!RegExp(r'\d').hasMatch(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La contraseña debe incluir al menos un número.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // Insert initial profile record.
        // It's safe to do this client-side right after signup if RLS allows inserts for the new user UID
        try {
          await Supabase.instance.client.from('profiles').insert({
            'id': response.user!.id,
            'shop_name': name,
            'role': _accountType,
          });
        } catch (dbError) {
          // Proceed anyway as they are signed up. They can update profile later.
        }

        if (mounted) context.push('/verify-code', extra: email);
      }
    } on AuthException catch (e) {
      if (mounted) {
        final msg = _authErrorMessage(e.message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error inesperado al crear cuenta.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _authErrorMessage(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('already registered') || lower.contains('user already exists')) {
      return 'Ya existe una cuenta con este correo.';
    }
    if (lower.contains('invalid email')) {
      return 'El correo no tiene un formato válido.';
    }
    if (lower.contains('password') && lower.contains('characters')) {
      return 'La contraseña es demasiado corta.';
    }
    if (lower.contains('signup') && lower.contains('disabled')) {
      return 'El registro está deshabilitado temporalmente.';
    }
    return 'No se pudo crear la cuenta. Intenta de nuevo.';
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Crear Cuenta',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
              const SizedBox(height: 8),
              const Text('Selecciona tu tipo de cuenta para comenzar.',
                style: TextStyle(fontSize: 14, color: AppTheme.mutedLight)),
              const SizedBox(height: 24),

              // ── Selector de tipo ───────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _accountType = 'shop_owner'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _accountType == 'shop_owner'
                              ? AppTheme.primary.withValues(alpha: 0.1)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _accountType == 'shop_owner'
                                ? AppTheme.primary
                                : Colors.grey.shade200,
                            width: _accountType == 'shop_owner' ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.storefront_rounded,
                              size: 28,
                              color: _accountType == 'shop_owner'
                                  ? AppTheme.primary
                                  : Colors.grey.shade400,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Floreria',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _accountType == 'shop_owner'
                                    ? AppTheme.primary
                                    : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Vendo arreglos',
                              style: TextStyle(
                                fontSize: 11,
                                color: _accountType == 'shop_owner'
                                    ? AppTheme.primary.withValues(alpha: 0.7)
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _accountType = 'proveedor'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _accountType == 'proveedor'
                              ? const Color(0xFF500088).withValues(alpha: 0.1)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _accountType == 'proveedor'
                                ? const Color(0xFF500088)
                                : Colors.grey.shade200,
                            width: _accountType == 'proveedor' ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.local_shipping_rounded,
                              size: 28,
                              color: _accountType == 'proveedor'
                                  ? const Color(0xFF500088)
                                  : Colors.grey.shade400,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Proveedor',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _accountType == 'proveedor'
                                    ? const Color(0xFF500088)
                                    : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Vendo al mayoreo',
                              style: TextStyle(
                                fontSize: 11,
                                color: _accountType == 'proveedor'
                                    ? const Color(0xFF500088).withValues(alpha: 0.7)
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Text(
                _accountType == 'shop_owner' ? 'Nombre de la Floreria' : 'Nombre del Negocio',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textLight),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: _accountType == 'shop_owner'
                      ? 'Ej. Flores de Maria'
                      : 'Ej. Maxiflores',
                  prefixIcon: Icon(
                    _accountType == 'shop_owner'
                        ? Icons.storefront_outlined
                        : Icons.local_shipping_outlined,
                    color: AppTheme.mutedLight,
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),

              const Text('Correo Electrónico', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textLight)),
              const SizedBox(height: 8),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'ejemplo@correo.com',
                  prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.mutedLight),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),

              const Text('Contraseña', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textLight)),
              const SizedBox(height: 8),
              TextField(
                controller: _passCtrl,
                obscureText: _obscurePass,
                decoration: InputDecoration(
                  hintText: 'Tu contraseña',
                  prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.mutedLight),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility, color: AppTheme.mutedLight),
                    onPressed: () => setState(() => _obscurePass = !_obscurePass),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Crear Cuenta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('¿Ya tienes cuenta? ', style: TextStyle(color: AppTheme.mutedLight, fontSize: 14)),
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Text('Inicia Sesión', style: TextStyle(color: AppTheme.primary, fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
