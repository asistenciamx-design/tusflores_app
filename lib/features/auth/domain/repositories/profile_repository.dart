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

  /// Update the current user's profile
  Future<void> updateProfile({
    String? shopName,
    String? whatsappNumber,
    String? logoUrl,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('No autenticado');

    final updates = <String, dynamic>{};
    if (shopName != null) updates['shop_name'] = shopName;
    if (whatsappNumber != null) updates['whatsapp_number'] = whatsappNumber;
    if (logoUrl != null) updates['logo_url'] = logoUrl;

    if (updates.isEmpty) return;

    updates['id'] = user.id;

    await _client.from('profiles').upsert(updates);
  }

  Future<String?> uploadLogo(XFile file) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final bytes = await file.readAsBytes();
      final ext = file.name.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = '${user.id}/$fileName';
      
      await _client.storage.from('shop_assets').uploadBinary(
        path, 
        bytes,
        fileOptions: FileOptions(contentType: 'image/$ext'),
      );
      return _client.storage.from('shop_assets').getPublicUrl(path);
    } catch (e) {
      return null;
    }
  }
}
