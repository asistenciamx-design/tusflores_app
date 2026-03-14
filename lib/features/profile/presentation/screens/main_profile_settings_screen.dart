// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_theme.dart';
import 'profile_about_us_edit_screen.dart'; // To navigate to interactive "Nosotros" form
import 'profile_contact_screen.dart'; // To navigate to "Datos de contacto"
import 'profile_branch_edit_screen.dart'; // To navigate to "Sucursal"
import 'payment_methods_screen.dart'; // To navigate to "Métodos de Pago"
import 'profile_faq_edit_screen.dart'; // To navigate to "Preguntas Frecuentes"
import 'shop_config_screen.dart'; // To navigate to "Configuración"
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/domain/repositories/profile_repository.dart';
import '../../../../features/orders/domain/repositories/order_repository.dart';

class MainProfileSettingsScreen extends StatefulWidget {
  const MainProfileSettingsScreen({super.key});

  @override
  State<MainProfileSettingsScreen> createState() => _MainProfileSettingsScreenState();
}

class _MainProfileSettingsScreenState extends State<MainProfileSettingsScreen> {
  final _repo = ProfileRepository();
  final _orderRepo = OrderRepository();
  bool _isLoading = true;
  String _ownerName = '';
  String _shopName = '';
  int _orderCount = 0;
  double _rating = 0.0;
  String? _logoUrl;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        _ownerName = user.userMetadata?['name']?.toString() ?? 'Sin Nombre';
        final profile = await _repo.getProfile();
        if (profile != null) {
          _shopName = profile['shop_name'] ?? 'Mi Florería';
          _logoUrl = profile['logo_url'];
        }
        
        final shopId = user.id;
        final orders = await _orderRepo.getOrders(shopId);
        _orderCount = orders.length;
        _rating = 0.0; // To be implemented with real reviews system, default to 0.0
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image == null) return;
      
      setState(() => _isLoading = true);
      final url = await _repo.uploadLogo(image);
      if (url != null) {
        setState(() => _logoUrl = url);
        await _repo.updateProfile(logoUrl: url);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Foto de perfil actualizada')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error al subir: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(context),
              _buildStats(context),
              _buildMenu(context),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildHeader(BuildContext context) {
    if (_isLoading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(32.0),
        child: CircularProgressIndicator(),
      ));
    }

    final linkEnd = _shopName.isEmpty ? 'tu-floreria' : _shopName.toLowerCase().replaceAll(' ', '-');
    final storeLink = 'tusflores.app/mx/$linkEnd';

    return Container(
      padding: const EdgeInsets.only(top: 24, bottom: 24, left: 24, right: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: const Icon(Icons.edit, color: AppTheme.primary),
              onPressed: _isLoading ? null : _pickAndUploadImage,
            ),
          ),
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primary, width: 2),
                ),
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: _logoUrl != null ? NetworkImage(_logoUrl!) : null,
                  child: _logoUrl == null ? const Icon(Icons.store, size: 40, color: Colors.grey) : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified, color: AppTheme.primary, size: 24),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _ownerName.isEmpty ? 'Sin Nombre' : _ownerName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textLight,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.storefront, color: AppTheme.primary, size: 16),
                const SizedBox(width: 8),
                Text(
                  _shopName.isEmpty ? 'Mi Florería' : _shopName,
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_on, color: AppTheme.mutedLight, size: 16),
              SizedBox(width: 4),
              Text(
                'México',
                style: TextStyle(color: AppTheme.mutedLight, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.backgroundLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  storeLink,
                  style: const TextStyle(color: AppTheme.mutedLight, fontSize: 13),
                ),
                const SizedBox(width: 12),
                Container(width: 1, height: 20, color: Colors.grey.withValues(alpha: 0.3)),
                const SizedBox(width: 8),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(Icons.copy, color: Theme.of(context).colorScheme.primary, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: storeLink));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Enlace copiado al portapapeles'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(Icons.share, color: Theme.of(context).colorScheme.primary, size: 18),
                  onPressed: () {
                    Share.share('Visita nuestra florería en línea: $storeLink');
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(Icons.open_in_new, color: Theme.of(context).colorScheme.primary, size: 18),
                  onPressed: () {
                    context.push('/shop/catalog');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  Text(
                    '$_orderCount',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'PEDIDOS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: AppTheme.mutedLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        _rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'RATING',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: AppTheme.mutedLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenu(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8.0, bottom: 16.0),
            child: Text(
              'MENÚ PRINCIPAL',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: AppTheme.mutedLight,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                _MenuItem(
                  icon: Icons.contact_mail,
                  iconColor: Colors.purple,
                  iconBg: Colors.purple.withValues(alpha: 0.1),
                  title: 'Datos de contacto',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProfileContactScreen()),
                    ).then((value) {
                      if (value == true) {
                        _loadProfile();
                      }
                    });
                  },
                ),
                _buildDivider(),
                _MenuItem(
                  icon: Icons.groups,
                  iconColor: Colors.pink,
                  iconBg: Colors.pink.withValues(alpha: 0.1),
                  title: 'Nosotros',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProfileAboutUsEditScreen()),
                    );
                  },
                ),
                _buildDivider(),
                _MenuItem(
                  icon: Icons.store,
                  iconColor: Colors.indigo,
                  iconBg: Colors.indigo.withValues(alpha: 0.1),
                  title: 'Sucursal',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProfileBranchEditScreen()),
                    );
                  },
                ),
                _buildDivider(),
                _MenuItem(
                  icon: Icons.credit_card,
                  iconColor: Colors.teal,
                  iconBg: Colors.teal.withValues(alpha: 0.1),
                  title: 'Métodos de pago',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PaymentMethodsScreen()),
                    );
                  },
                ),
                _buildDivider(),
                _MenuItem(
                  icon: Icons.help,
                  iconColor: Colors.lightBlue,
                  iconBg: Colors.lightBlue.withValues(alpha: 0.1),
                  title: 'Preguntas',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProfileFaqEditScreen()),
                    );
                  },
                ),
                _buildDivider(),
                _MenuItem(
                  icon: Icons.tune,
                  iconColor: Colors.orange,
                  iconBg: Colors.orange.withValues(alpha: 0.1),
                  title: 'Configuración',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ShopConfigScreen()),
                    );
                  },
                ),
                _buildDivider(),
                _MenuItem(
                  icon: Icons.logout,
                  iconColor: Colors.red,
                  iconBg: Colors.red.withValues(alpha: 0.1),
                  title: 'Cerrar sesión',
                  titleColor: Colors.red,
                  onTap: () => _confirmLogout(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, indent: 64, color: Colors.grey.withValues(alpha: 0.1));
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
              child: const Icon(Icons.logout, color: Colors.red, size: 32),
            ),
            const SizedBox(height: 16),
            const Text('¿Cerrar sesión?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Se cerrará tu sesión actual. Tendrás que iniciar sesión de nuevo para acceder a tu cuenta.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 14, height: 1.5),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                // Cierra la sesión y redirige al login
                context.go('/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Cerrar sesión', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Cancelar', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}


class _MenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final Color? titleColor;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    this.titleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: titleColor ?? AppTheme.textLight,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.mutedLight),
          ],
        ),
      ),
    );
  }
}
