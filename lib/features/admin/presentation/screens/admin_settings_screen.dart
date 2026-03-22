import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                  color: Colors.red.shade50, shape: BoxShape.circle),
              child: const Icon(Icons.logout, color: Colors.red, size: 32),
            ),
            const SizedBox(height: 16),
            const Text('¿Cerrar sesión?',
                style:
                    TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Se cerrará la sesión de Super Admin. Tendrás que iniciar sesión de nuevo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Color(0xFF6B7280), fontSize: 14, height: 1.5),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await Supabase.instance.client.auth.signOut();
                    if (context.mounted) context.go('/login');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Cerrar sesión',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? '—';

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Header ──────────────────────────────────────────────────
            const Row(
              children: [
                Icon(Icons.settings_rounded,
                    color: Color(0xFF4F46E5), size: 22),
                SizedBox(width: 8),
                Text('Ajustes',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 24),

            // ── Perfil ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cardLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: Colors.black.withValues(alpha: 0.06)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEEF2FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.admin_panel_settings_rounded,
                        color: Color(0xFF4F46E5), size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Super Admin',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(email,
                            style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.mutedLight)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Admin',
                        style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF4F46E5),
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Sección App ─────────────────────────────────────────────
            _SectionTitle(label: 'Aplicación'),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.info_outline_rounded,
              label: 'Versión',
              trailing: Text('1.0.0',
                  style: TextStyle(
                      fontSize: 13, color: AppTheme.mutedLight)),
            ),
            _SettingsTile(
              icon: Icons.palette_outlined,
              label: 'Plataforma',
              trailing: Text('tusflores.app',
                  style: TextStyle(
                      fontSize: 13, color: AppTheme.mutedLight)),
            ),
            const SizedBox(height: 20),

            // ── Sección Cuenta ──────────────────────────────────────────
            _SectionTitle(label: 'Cuenta'),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.logout_rounded,
              iconColor: Colors.red.shade400,
              label: 'Cerrar sesión',
              labelColor: Colors.red.shade600,
              onTap: () => _confirmLogout(context),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(label.toUpperCase(),
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppTheme.mutedLight)),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final Color? labelColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.iconColor,
    this.labelColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardLight,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon,
            size: 20,
            color: iconColor ?? const Color(0xFF4F46E5)),
        title: Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: labelColor ?? AppTheme.textLight)),
        trailing: trailing ??
            (onTap != null
                ? Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppTheme.mutedLight)
                : null),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
