import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, llena ambos campos.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null && mounted) {
        // Check role and redirect accordingly
        try {
          final profile = await Supabase.instance.client
              .from('profiles')
              .select('role')
              .eq('id', response.user!.id)
              .maybeSingle();
          final role = profile?['role'] as String? ?? 'shop_owner';
          if (mounted) {
            context.go(role == 'super_admin' ? '/admin' : '/');
          }
        } catch (_) {
          if (mounted) context.go('/');
        }
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
          const SnackBar(content: Text('Error inesperado al iniciar sesión.'), backgroundColor: Colors.red),
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
    if (lower.contains('invalid login') || lower.contains('invalid credentials')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Tu correo aún no ha sido confirmado. Revisa tu bandeja de entrada.';
    }
    if (lower.contains('too many requests') || lower.contains('rate limit')) {
      return 'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.';
    }
    return 'No se pudo iniciar sesión. Intenta de nuevo.';
  }

  Future<void> _showForgotPassword() async {
    final emailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Recuperar contraseña',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ingresa tu correo y te enviaremos un enlace para restablecer tu contraseña.',
              style: TextStyle(fontSize: 14, color: AppTheme.mutedLight),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'ejemplo@correo.com',
                prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.mutedLight),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.mutedLight)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Enviar enlace'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final email = emailCtrl.text.trim();
    if (email.isEmpty) return;

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'https://app.tusflores.app/reset-password',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Enlace enviado a $email — revisa tu bandeja de entrada.'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().toLowerCase().contains('rate limit') || e.toString().contains('429')
            ? 'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.'
            : 'No se pudo enviar el enlace. Verifica tu correo e intenta de nuevo.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // Logo/Título
              Center(
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.local_florist, color: AppTheme.primary, size: 36),
                ),
              ),
              const SizedBox(height: 20),
              const Text('tusflores.app',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textLight, letterSpacing: -0.5)),
              const SizedBox(height: 24),

              // Header Formulario
              const Text('Iniciar Sesión',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
              const SizedBox(height: 8),
              const Text('Ingresa tus credenciales para continuar.',
                style: TextStyle(fontSize: 14, color: AppTheme.mutedLight)),
              const SizedBox(height: 32),

              // Campo de Email
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

              // Campo de Contraseña
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
              const SizedBox(height: 12),

              // Olvidó contraseña
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _showForgotPassword(),
                  child: const Text('¿Olvidaste tu contraseña?',
                    style: TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 32),

              // Botón Iniciar Sesión
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
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
                      : const Text('Iniciar Sesión', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 32),

              // Crear cuenta
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('¿No tienes cuenta? ', style: TextStyle(color: AppTheme.mutedLight, fontSize: 14)),
                  GestureDetector(
                    onTap: () => context.push('/create-account'),
                    child: const Text('Crea una aquí', style: TextStyle(color: AppTheme.primary, fontSize: 14, fontWeight: FontWeight.bold)),
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
