import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/repositories/profile_repository.dart';

// ── Country code data ────────────────────────────────────────────────────────
class _CC {
  final String flag;
  final String name;
  final String dial;
  const _CC(this.flag, this.name, this.dial);
}

const _kCountryCodes = [
  _CC('🇲🇽', 'México',       '+52'),
  _CC('🇺🇸', 'Estados Unidos', '+1'),
  _CC('🇨🇴', 'Colombia',     '+57'),
  _CC('🇪🇸', 'España',       '+34'),
  _CC('🇦🇷', 'Argentina',    '+54'),
  _CC('🇨🇱', 'Chile',        '+56'),
  _CC('🇵🇪', 'Perú',         '+51'),
  _CC('🇬🇹', 'Guatemala',    '+502'),
  _CC('🇭🇳', 'Honduras',     '+504'),
  _CC('🇸🇻', 'El Salvador',  '+503'),
  _CC('🇨🇷', 'Costa Rica',   '+506'),
  _CC('🇩🇴', 'Rep. Dominicana', '+1809'),
  _CC('🇵🇦', 'Panamá',       '+507'),
  _CC('🇧🇴', 'Bolivia',      '+591'),
  _CC('🇵🇾', 'Paraguay',     '+595'),
  _CC('🇺🇾', 'Uruguay',      '+598'),
  _CC('🇻🇪', 'Venezuela',    '+58'),
  _CC('🇧🇷', 'Brasil',       '+55'),
  _CC('🇨🇦', 'Canadá',       '+1'),
];

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
  String _countryDial = '+52'; // default México

  final ImagePicker _picker = ImagePicker();
  String? _logoUrl;
  String? _slug;
  String _slugPais = 'mx';

  @override
  void initState() {
    super.initState();
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
          final raw = (profile['whatsapp_number'] as String?) ?? '';
          _parseWhatsappNumber(raw);
          _logoUrl = profile['logo_url'];
        }
        // Cargar el slug real desde slugs_registry
        final slugRow = await Supabase.instance.client
            .from('slugs_registry')
            .select('slug, pais')
            .eq('entity_id', user.id)
            .maybeSingle();
        if (slugRow != null) {
          _slug = slugRow['slug'] as String?;
          _slugPais = (slugRow['pais'] as String?) ?? 'mx';
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
        whatsappNumber: '$_countryDial${_whatsappCtrl.text.trim()}',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 32),
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
                _buildWhatsappField(),
                const SizedBox(height: 32),
                ElevatedButton(
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
              ],
            ),
      ),
    );
  }

  void _parseWhatsappNumber(String raw) {
    if (raw.isEmpty) return;
    // Try to match a known dial code (longest first to avoid +1 eating +1809)
    final sorted = List<_CC>.from(_kCountryCodes)
      ..sort((a, b) => b.dial.length.compareTo(a.dial.length));
    for (final cc in sorted) {
      if (raw.startsWith(cc.dial)) {
        _countryDial = cc.dial;
        _whatsappCtrl.text = raw.substring(cc.dial.length);
        return;
      }
    }
    // No prefix found — keep default +52, use raw as number
    _whatsappCtrl.text = raw;
  }

  Future<void> _pickCountryCode() async {
    final picked = await showModalBottomSheet<_CC>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Código de país',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _kCountryCodes.length,
                itemBuilder: (ctx, i) {
                  final cc = _kCountryCodes[i];
                  final isSelected = cc.dial == _countryDial &&
                      cc.name == (_kCountryCodes.firstWhere(
                          (c) => c.dial == _countryDial,
                          orElse: () => _kCountryCodes[0]).name);
                  return ListTile(
                    leading: Text(cc.flag, style: const TextStyle(fontSize: 24)),
                    title: Text(cc.name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    trailing: Text(cc.dial,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? AppTheme.primary : Colors.grey[600],
                        )),
                    selected: isSelected,
                    selectedTileColor: AppTheme.primary.withValues(alpha: 0.06),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onTap: () => Navigator.pop(ctx, cc),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _countryDial = picked.dial);
  }

  Widget _buildWhatsappField() {
    final cc = _kCountryCodes.firstWhere(
      (c) => c.dial == _countryDial,
      orElse: () => _kCountryCodes[0],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'WhatsApp principal de pedidos',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textLight),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              // Country code picker
              GestureDetector(
                onTap: _pickCountryCode,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundLight,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                    border: Border(
                      right: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(cc.flag, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 6),
                      Text(
                        _countryDial,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textLight,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey[500]),
                    ],
                  ),
                ),
              ),
              // Phone number input
              Expanded(
                child: TextFormField(
                  controller: _whatsappCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontSize: 14, color: AppTheme.textLight),
                  decoration: InputDecoration(
                    hintText: 'Número sin código de país',
                    hintStyle: const TextStyle(color: AppTheme.mutedLight, fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 6),
          child: Text(
            'Ej. para México: +52 · 5548840937',
            style: TextStyle(fontSize: 11, color: Colors.grey[400]),
          ),
        ),
      ],
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
    final hasSlug = _slug != null && _slug!.isNotEmpty;
    final storeLink = hasSlug ? 'www.tusflores.app/$_slugPais/$_slug' : null;

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
                Icon(Icons.link, color: hasSlug ? AppTheme.primary : Colors.grey, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasSlug ? storeLink! : 'Sin URL configurada',
                    style: TextStyle(
                      fontSize: 13,
                      color: hasSlug ? Colors.grey[700] : Colors.grey[400],
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (hasSlug) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: storeLink!));
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
        ],
      ),
    );
  }
}
