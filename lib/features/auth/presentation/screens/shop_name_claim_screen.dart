import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/repositories/profile_repository.dart';

class ShopNameClaimScreen extends StatefulWidget {
  const ShopNameClaimScreen({super.key});

  @override
  State<ShopNameClaimScreen> createState() => _ShopNameClaimScreenState();
}

class _ShopNameClaimScreenState extends State<ShopNameClaimScreen> {
  final _nameCtrl = TextEditingController();
  bool _isLoading = false;

  String _selectedCountry = 'mx';

  final List<Map<String, String>> _countries = [
    {'code': 'mx', 'name': '🇲🇽 México'},
    {'code': 'co', 'name': '🇨🇴 Colombia'},
    {'code': 'ar', 'name': '🇦🇷 Argentina'},
    {'code': 'cl', 'name': '🇨🇱 Chile'},
    {'code': 'pe', 'name': '🇵🇪 Perú'},
    {'code': 'es', 'name': '🇪🇸 España'},
    {'code': 'us', 'name': '🇺🇸 Estados Unidos'},
    {'code': 'ot', 'name': '🌍 Otro'},
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      // In the future we can also save the country code to the profile
      await ProfileRepository().updateProfile(shopName: name);
      if (mounted) context.push('/connect-whatsapp');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al guardar el nombre de tu florería.')),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('¿Cómo se llama tu florería?',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.textLight, height: 1.2)),
              const SizedBox(height: 12),
              const Text('Crea tu catálogo digital profesional en menos de 30 segundos.',
                style: TextStyle(fontSize: 15, color: AppTheme.mutedLight, height: 1.4)),
              const SizedBox(height: 48),

              const Text('País', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textLight)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedCountry,
                isExpanded: true,
                items: _countries.map((c) => DropdownMenuItem(
                  value: c['code'],
                  child: Text(c['name']!),
                )).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedCountry = val);
                  }
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
                ),
              ),
              const SizedBox(height: 24),

              const Text('Nombre del negocio', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textLight)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Ej. Florería Las Rosas',
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
                ),
                onChanged: (val) => setState((){}),
              ),
              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.link, size: 20, color: AppTheme.primary),
                        SizedBox(width: 8),
                        Text('Tu enlace único', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'tusflores.app/$_selectedCountry/${_nameCtrl.text.isEmpty ? 'tu-florería' : _nameCtrl.text.toLowerCase().replaceAll(' ', '-')}',
                      style: const TextStyle(fontSize: 16, color: AppTheme.textLight),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              const Text('Al continuar, aceptas nuestros términos y condiciones.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.mutedLight)),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (_nameCtrl.text.trim().isEmpty || _isLoading) ? null : _continue,
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
                      : const Text('Continuar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
