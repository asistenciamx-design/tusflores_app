import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/utils/image_compressor.dart';
import '../../../../core/utils/image_picker_helper.dart';

class ProfileRepository {
  final SupabaseClient _client;

  ProfileRepository({SupabaseClient? client}) : _client = client ?? SupabaseService.client;

  /// Fetch the current user's profile
  Future<Map<String, dynamic>?> getProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final response = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
        
    return response;
  }

  /// Fetch a florist's profile by their shop slug (shop_name field)
  Future<Map<String, dynamic>?> getProfileBySlug(String slug) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('shop_name', slug)
          .maybeSingle();
      return response;
    } catch (e) {
      return null;
    }
  }

  /// Update the current user's profile
  Future<void> updateProfile({
    String? shopName,
    String? whatsappNumber,
    String? logoUrl,
    String? biography,
    int? yearsOfExperience,
    List<String>? specialties,
    List<dynamic>? milestones,
    List<String>? gallery,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('No autenticado');

    final updates = <String, dynamic>{};
    if (shopName != null) updates['shop_name'] = shopName;
    if (whatsappNumber != null) updates['whatsapp_number'] = whatsappNumber;
    if (logoUrl != null) updates['logo_url'] = logoUrl;
    if (biography != null) updates['biography'] = biography;
    if (yearsOfExperience != null) updates['years_of_experience'] = yearsOfExperience;
    if (specialties != null) updates['specialties'] = specialties;
    if (milestones != null) updates['milestones'] = milestones;
    if (gallery != null) updates['gallery'] = gallery;

    if (updates.isEmpty) return;

    await _client.from('profiles').update(updates).eq('id', user.id);
  }

  Future<String?> uploadLogo(XFile file) async {
    return uploadImage(file, folder: 'logos');
  }

  Future<String?> uploadImage(XFile file, {String folder = 'assets'}) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      const allowedExtensions = {'jpg', 'jpeg', 'png', 'webp', 'gif', 'heic', 'heif'};
      final origExt = file.name.split('.').last.toLowerCase();
      if (!allowedExtensions.contains(origExt)) {
        throw Exception('Tipo de archivo no permitido: .$origExt');
      }

      // Use platform-specific reader to avoid blob URL issues on web
      final rawBytes = await ImagePickerHelper.readBytes(file.path, file.name);

      // Comprimir y convertir a WebP (excepto .webp y .gif)
      final Uint8List bytes;
      final String ext;
      if (origExt == 'gif') {
        bytes = rawBytes;
        ext = origExt;
      } else {
        // heic/heif → comprimir como jpeg/webp (FlutterImageCompress lo maneja)
        final compressed = await ImageCompressor.compressBytes(rawBytes, file.name);
        bytes = compressed.bytes;
        ext = compressed.ext;
      }

      const maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB
      if (bytes.length > maxFileSizeBytes) {
        throw Exception('El archivo es demasiado grande. Máximo: 10 MB');
      }
      if (!_isValidImageBytes(bytes, ext)) {
        throw Exception('El archivo no es una imagen válida.');
      }
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = '${user.id}/$folder/$fileName';

      await _client.storage.from('shop_assets').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: 'image/$ext'),
      );
      return _client.storage.from('shop_assets').getPublicUrl(path);
    } catch (e) {
      throw Exception('Error al subir imagen: $e');
    }
  }

  bool _isValidImageBytes(List<int> bytes, String ext) {
    if (bytes.length < 4) return false;
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
      case 'png':
        return bytes[0] == 0x89 && bytes[1] == 0x50 &&
               bytes[2] == 0x4E && bytes[3] == 0x47;
      case 'webp':
        return bytes.length >= 12 &&
               bytes[0] == 0x52 && bytes[1] == 0x49 &&
               bytes[2] == 0x46 && bytes[3] == 0x46 &&
               bytes[8] == 0x57 && bytes[9] == 0x45 &&
               bytes[10] == 0x42 && bytes[11] == 0x50;
      case 'gif':
        return bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46;
      default:
        return false;
    }
  }
}
