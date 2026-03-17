import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GiftRepository {
  final _supabase = Supabase.instance.client;

  /// All gifts for florist management (active + inactive).
  Future<List<Map<String, dynamic>>> getGifts(String floristId) async {
    final response = await _supabase
        .from('gifts')
        .select()
        .eq('florist_id', floristId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Active gifts for customer display.
  Future<List<Map<String, dynamic>>> getPublicGifts(String floristId) async {
    final response = await _supabase
        .from('gifts')
        .select()
        .eq('florist_id', floristId)
        .eq('is_active', true)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Generates the next sequential gift SKU (G0001, G0002, ...).
  /// Never reuses numbers from deleted gifts.
  Future<String> getNextGiftSku(String floristId) async {
    final response = await _supabase
        .from('gifts')
        .select('sku')
        .eq('florist_id', floristId);

    int maxNum = 0;
    for (final row in response as List) {
      final sku = row['sku'] as String?;
      if (sku != null && sku.length > 1 && sku[0] == 'G') {
        final num = int.tryParse(sku.substring(1));
        if (num != null && num > maxNum) maxNum = num;
      }
    }
    return 'G${(maxNum + 1).toString().padLeft(4, '0')}';
  }

  Future<Map<String, dynamic>> createGift(
      String floristId, Map<String, dynamic> data) async {
    data['florist_id'] = floristId;
    final response =
        await _supabase.from('gifts').insert(data).select().single();
    return response;
  }

  Future<Map<String, dynamic>> updateGift(
      String giftId, String floristId, Map<String, dynamic> data) async {
    final response = await _supabase
        .from('gifts')
        .update(data)
        .eq('id', giftId)
        .eq('florist_id', floristId)
        .select()
        .single();
    return response;
  }

  Future<void> toggleActive(String giftId, String floristId, bool isActive) async {
    await _supabase
        .from('gifts')
        .update({'is_active': isActive})
        .eq('id', giftId)
        .eq('florist_id', floristId);
  }

  Future<String?> uploadGiftImage(String floristId, XFile file) async {
    const allowedExtensions = {'jpg', 'jpeg', 'png', 'webp', 'gif'};
    final ext = file.name.split('.').last.toLowerCase();
    if (!allowedExtensions.contains(ext)) {
      throw Exception('Tipo de archivo no permitido: .$ext');
    }
    final bytes = await file.readAsBytes();
    const maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB
    if (bytes.length > maxFileSizeBytes) {
      throw Exception('El archivo es demasiado grande. Máximo: 10 MB');
    }
    if (!_isValidImageBytes(bytes, ext)) {
      throw Exception('El archivo no es una imagen válida.');
    }
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final path = 'gifts/$floristId/$fileName';
    await _supabase.storage.from('products').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$ext'),
        );
    return _supabase.storage.from('products').getPublicUrl(path);
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
      case 'gif':
        return bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46;
      case 'webp':
        return bytes.length >= 12 &&
               bytes[0] == 0x52 && bytes[1] == 0x49 &&
               bytes[2] == 0x46 && bytes[3] == 0x46 &&
               bytes[8] == 0x57 && bytes[9] == 0x45 &&
               bytes[10] == 0x42 && bytes[11] == 0x50;
      default:
        return false;
    }
  }
}
