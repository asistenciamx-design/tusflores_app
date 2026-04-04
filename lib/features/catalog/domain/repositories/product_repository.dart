import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/image_compressor.dart';

class ProductRepository {
  final _supabase = Supabase.instance.client;

  /// Carga TODOS los productos del florista (activos e inactivos).
  /// Usado en la pantalla de catálogo del florista para gestión.
  Future<List<Map<String, dynamic>>> getProducts(String floristId) async {
    final response = await _supabase
        .from('products')
        .select()
        .eq('florist_id', floristId)
        .order('created_at', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  }

  /// Carga solo los productos ACTIVOS del florista.
  /// Usado en la vista pública del catálogo (vista del cliente).
  Future<List<Map<String, dynamic>>> getPublicProducts(String floristId) async {
    final response = await _supabase
        .from('products')
        .select()
        .eq('florist_id', floristId)
        .eq('is_active', true)
        .order('created_at', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  }

  /// Generates the next sequential SKU for a florist (e.g. F0001, F0002, ...).
  /// Looks at all existing SKUs (including inactive products) to never reuse a number.
  Future<String> getNextSku(String floristId) async {
    final response = await _supabase
        .from('products')
        .select('sku')
        .eq('florist_id', floristId);

    int maxNum = 0;
    for (final row in response as List) {
      final sku = row['sku'] as String?;
      if (sku != null && sku.length > 1 && sku[0] == 'F') {
        final num = int.tryParse(sku.substring(1));
        if (num != null && num > maxNum) maxNum = num;
      }
    }
    final next = maxNum + 1;
    return 'F${next.toString().padLeft(4, '0')}';
  }

  Future<Map<String, dynamic>> createProduct(String floristId, Map<String, dynamic> data) async {
    data['florist_id'] = floristId;
    final response = await _supabase.from('products').insert(data).select().single();
    return response;
  }

  Future<Map<String, dynamic>> updateProduct(String productId, String floristId, Map<String, dynamic> data) async {
    final response = await _supabase
        .from('products')
        .update(data)
        .eq('id', productId)
        .eq('florist_id', floristId)
        .select()
        .single();
    return response;
  }

  Future<void> deleteProduct(String productId, String floristId) async {
    // We do a soft delete to keep history.
    await _supabase
        .from('products')
        .update({'is_active': false})
        .eq('id', productId)
        .eq('florist_id', floristId);
  }

  Future<String?> uploadProductImage(String floristId, XFile file) async {
    try {
      const allowedExtensions = {'jpg', 'jpeg', 'png', 'webp', 'gif'};
      final origExt = file.name.split('.').last.toLowerCase();
      if (!allowedExtensions.contains(origExt)) {
        throw Exception('Tipo de archivo no permitido: .$origExt');
      }

      // Read bytes immediately to avoid blob URL expiration on web
      final rawBytes = Uint8List.fromList(await file.readAsBytes());

      // Comprimir y convertir a WebP (excepto .webp y .gif)
      final Uint8List bytes;
      final String ext;
      if (origExt == 'gif') {
        bytes = rawBytes;
        ext = origExt;
      } else {
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
      final path = '$floristId/$fileName';

      await _supabase.storage.from('products').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: 'image/$ext'),
      );
      return _supabase.storage.from('products').getPublicUrl(path);
    } catch (e) {
      rethrow;
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
