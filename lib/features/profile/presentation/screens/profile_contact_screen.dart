import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/repositories/profile_repository.dart';

class ProfileContactScreen extends StatefulWidget {
  const ProfileContactScreen({super.key});

  @override
  State<ProfileContactScreen> createState() => _ProfileContactScreenState();
}

class _ProfileContactScreenState extends State<ProfileContactScreen> {
  final _repo = ProfileRepository();
  bool _isLoading = true;
  String _email = '';

  final _ownerNameCtrl = TextEditingController();
  final _shopNameCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  String? _logoUrl;

  @override
  void initState() {
    super.initState();
    _shopNameCtrl.addListener(() {
      setState(() {});
    });
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        _email = user.email ?? '';
        _ownerNameCtrl.text = user.userMetadata?['name']?.toString() ?? '';
        final profile = await _repo.getProfile();
        if (profile != null) {
          _shopNameCtrl.text = profile['shop_name'] ?? '';
          _whatsappCtrl.text = profile['whatsapp_number'] ?? '';
          _logoUrl = profile['logo_url'];
        }
      }
    } catch (e) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null && _ownerNameCtrl.text.trim().isNotEmpty) {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(data: {'name': _ownerNameCtrl.text.trim()}),
        );
      }
      
      await _repo.updateProfile(
        shopName: _shopNameCtrl.text.trim(),
        whatsappNumber: _whatsappCtrl.text.trim(),
        logoUrl: _logoUrl,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cambios guardados exitosamente')),
        );
        Navigator.pop(context, true); // Return true to refresh previous screen if needed
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al guardar los cambios'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _ownerNameCtrl.dispose();
    _shopNameCtrl.dispose();
    _whatsappCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadLogo() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image == null) return;
      
      setState(() => _isLoading = true);
      final url = await _repo.uploadLogo(image);
      if (url != null) {
        setState(() => _logoUrl = url);
        // Save automatically
        await _repo.updateProfile(logoUrl: url);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Logo actualizado en la nube')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Error al subir imagen', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Datos de contacto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: AppTheme.cardLight,
        elevation: 0,
        scrolledUnderElevation: 2,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 100),
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildProfileImage(),
                const SizedBox(height: 32),
                _buildSectionHeader('INFORMACIÓN PERSONAL'),
                _buildTextField(label: 'Nombre completo', icon: Icons.person, controller: _ownerNameCtrl, hintText: 'Ej. María Rosas'),
                const SizedBox(height: 32),
                _buildSectionHeader('NEGOCIO'),
                _buildTextField(label: 'Nombre comercial', icon: Icons.storefront, controller: _shopNameCtrl),
                const SizedBox(height: 16),
                _buildStoreLinkCard(),
                const SizedBox(height: 32),
                _buildSectionHeader('CONTACTO DIRECTO'),
                _buildTextField(label: 'Correo electrónico', icon: Icons.email, controller: TextEditingController(text: _email), enabled: false),
                const SizedBox(height: 16),
                _buildTextField(label: 'WhatsApp principal de pedidos', icon: Icons.chat, controller: _whatsappCtrl, hintText: 'Ej. 55 9876 5432', keyboardType: TextInputType.phone, maxLength: 15, inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    AppTheme.backgroundLight,
                    AppTheme.backgroundLight.withValues(alpha: 0.9),
                    AppTheme.backgroundLight.withValues(alpha: 0),
                  ],
                ),
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  shadowColor: AppTheme.primary.withValues(alpha: 0.4),
                ),
                child: const Text('Guardar cambios', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImage() {
    return Center(
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primary, width: 2),
            ),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey[200],
              backgroundImage: _logoUrl != null ? NetworkImage(_logoUrl!) : null,
              child: _logoUrl == null ? const Icon(Icons.store, size: 40, color: Colors.grey) : null,
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _isLoading ? null : _pickAndUploadLogo,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.backgroundLight, width: 3),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(6.0),
                  child: Icon(Icons.camera_alt, color: Colors.white, size: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppTheme.mutedLight,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildTextField({required String label, required IconData icon, TextEditingController? controller, String? hintText, TextInputType? keyboardType, bool enabled = true, int? maxLength, List<TextInputFormatter>? inputFormatters}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
          child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textLight)),
        ),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          style: const TextStyle(fontSize: 14, color: AppTheme.textLight),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: AppTheme.mutedLight),
            prefixIcon: Icon(icon, color: AppTheme.mutedLight, size: 20),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppTheme.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStoreLinkCard() {
    final linkEnd = _shopNameCtrl.text.isEmpty ? 'tu-floreria' : _shopNameCtrl.text.toLowerCase().replaceAll(' ', '-');
    final storeLink = 'tusflores.app/mx/$linkEnd';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Enlace de tu tienda', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textLight)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.backgroundLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.link, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    storeLink,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: storeLink));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enlace copiado al portapapeles')),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copiar'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextButton.icon(
                  onPressed: () {
                    Share.share('¡Visita mi florería en línea! $storeLink');
                  },
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Compartir'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
