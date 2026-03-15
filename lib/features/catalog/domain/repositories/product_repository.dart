import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<Map<String, dynamic>> createProduct(String floristId, Map<String, dynamic> data) async {
    data['florist_id'] = floristId;
    final response = await _supabase.from('products').insert(data).select().single();
    return response;
  }

  Future<Map<String, dynamic>> updateProduct(String productId, Map<String, dynamic> data) async {
    final response = await _supabase.from('products').update(data).eq('id', productId).select().single();
    return response;
  }

  Future<void> deleteProduct(String productId) async {
    // We do a soft delete to keep history.
    await _supabase.from('products').update({'is_active': false}).eq('id', productId);
  }

  Future<String?> uploadProductImage(String floristId, XFile file) async {
    try {
      const allowedExtensions = {'jpg', 'jpeg', 'png', 'webp', 'gif'};
      final ext = file.name.split('.').last.toLowerCase();
      if (!allowedExtensions.contains(ext)) {
        throw Exception('Tipo de archivo no permitido: .$ext');
      }

      final bytes = await file.readAsBytes();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = '$floristId/$fileName';
      
      // We assume there's a storage bucket named 'products' configured to be public.
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
}
