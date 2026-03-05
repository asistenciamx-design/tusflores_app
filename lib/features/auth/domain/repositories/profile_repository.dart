import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/supabase_service.dart';

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
      debugPrint('Error getProfileBySlug: $e');
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

      final bytes = await file.readAsBytes();
      final ext = file.name.split('.').last;
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
}
