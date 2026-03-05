import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../profile/domain/models/shop_settings_model.dart';
import '../../../profile/domain/repositories/shop_settings_repository.dart';

class CatalogMessageScreen extends StatefulWidget {
  const CatalogMessageScreen({super.key});

  @override
  State<CatalogMessageScreen> createState() => _CatalogMessageScreenState();
}

class _CatalogMessageScreenState extends State<CatalogMessageScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final _repo = ShopSettingsRepository();

  bool _isLoading = true;
  bool _isSaving = false;

  XFile? _pickedImage;          // imagen nueva elegida para esta sesión
  String? _savedImageUrl;       // URL de imagen ya guardada en Supabase Storage
  ShopSettingsModel? _currentSettings; // settings actuales para preservar otros campos

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  Future<void> _loadCurrentData() async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final settings = await _repo.getSettings(userId);
      if (settings != null && mounted) {
        _currentSettings = settings;
        _nameController.text = settings.rawData?['catalog_shop_name'] ?? '';
        _descriptionController.text = settings.catalogMessage ?? '';
        _savedImageUrl = settings.catalogImageUrl;
      }
    } catch (e) {
      debugPrint('Error loading catalog message: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null && mounted) {
      setState(() => _pickedImage = picked);
    }
  }

  Future<String?> _uploadImage(String userId) async {
    if (_pickedImage == null) return _savedImageUrl; // no hay nueva imagen
    try {
      final bytes = await _pickedImage!.readAsBytes();
      final ext = _pickedImage!.name.split('.').last;
      final path = '$userId/catalog_cover.$ext';
      await Supabase.instance.client.storage.from('catalog-images').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          contentType: 'image/$ext',
          upsert: true, // sobreescribe si ya existe
        ),
      );
      return Supabase.instance.client.storage.from('catalog-images').getPublicUrl(path);
    } catch (e) {
      debugPrint('Error uploading catalog image: $e');
      rethrow;
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Sesión no encontrada');

      // 1. Subir imagen si hay una nueva
      final imageUrl = await _uploadImage(userId);

      // 2. Guardar en shop_settings preservando los campos existentes
      final base = _currentSettings ?? ShopSettingsModel(
        storeHours: [], deliveryRanges: [], shippingRates: [],
      );

      // Construimos el JSON de settings mezclando el existente con los nuevos campos
      final existingJson = base.toJson();
      existingJson['catalog_shop_name'] = _nameController.text.trim();
      existingJson['catalog_message'] = _descriptionController.text.trim();
      if (imageUrl != null) existingJson['catalog_image_url'] = imageUrl;

      await Supabase.instance.client.from('shop_settings').upsert({
        'shop_id': userId,
        'settings': existingJson,
      });

      if (mounted) {
        setState(() => _savedImageUrl = imageUrl);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Cambios guardados correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // retorna true = hubo cambios
      }
    } catch (e) {
      debugPrint('Error saving catalog message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Mensaje Catálogo'),
        backgroundColor: AppTheme.backgroundLight,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Personaliza el mensaje que verán tus clientes al compartir tu catálogo.',
                    style: TextStyle(color: AppTheme.mutedLight, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  _buildTextField(
                    label: 'Nombre de la florería',
                    controller: _nameController,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    label: 'Descripción del mensaje',
                    controller: _descriptionController,
                    maxLines: 4,
                    hint: '✨ ¡Bienvenido a mi florería! Nuestras flores más frescas ya están listas para ti...',
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Imagen destacada (opcional)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Se adjuntará al compartir tu catálogo',
                    style: TextStyle(fontSize: 12, color: AppTheme.mutedLight),
                  ),
                  const SizedBox(height: 12),
                  _buildImagePicker(context),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'GUARDAR CAMBIOS',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(16),
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
              borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePicker(BuildContext context) {
    Widget imageContent;

    if (_pickedImage != null) {
      // Imagen nueva seleccionada en esta sesión
      imageContent = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: kIsWeb
            ? Image.network(_pickedImage!.path, fit: BoxFit.cover, width: double.infinity)
            : Image.network(_pickedImage!.path, fit: BoxFit.cover, width: double.infinity,
                errorBuilder: (_, __, ___) => _imagePlaceholder(context)),
      );
    } else if (_savedImageUrl != null && _savedImageUrl!.isNotEmpty) {
      // Imagen ya guardada en Supabase
      imageContent = Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              _savedImageUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (_, __, ___) => _imagePlaceholder(context),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => setState(() => _savedImageUrl = null),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      );
    } else {
      imageContent = _imagePlaceholder(context);
    }

    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        clipBehavior: Clip.antiAlias,
        child: imageContent,
      ),
    );
  }

  Widget _imagePlaceholder(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.secondaryBg.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.add_photo_alternate_rounded,
              size: 32,
              color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(height: 12),
        const Text(
          'Toca para seleccionar una imagen',
          style: TextStyle(
              color: AppTheme.mutedLight,
              fontSize: 14,
              fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
