import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/inventory_models.dart';

class InventoryRepository {
  final _client = Supabase.instance.client;

  String get _userId => _client.auth.currentUser!.id;

  // ── Obtener todas las listas con sus items ───────────────────────────────
  Future<List<InventoryList>> getLists() async {
    final data = await _client
        .from('inventory_lists')
        .select('*, inventory_items(id, list_id, sequence_number, product_name, color, quality, quantity)')
        .eq('floreria_id', _userId)
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => InventoryList.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ── Obtener siguiente número de nota ─────────────────────────────────────
  Future<String> getNextTitle() async {
    final data = await _client
        .from('inventory_lists')
        .select('title')
        .eq('floreria_id', _userId)
        .ilike('title', 'Nota %');
    int max = 0;
    for (final row in (data as List)) {
      final title = row['title'] as String? ?? '';
      final num = int.tryParse(title.replaceFirst(RegExp(r'^Nota\s+'), '')) ?? 0;
      if (num > max) max = num;
    }
    return 'Nota ${max + 1}';
  }

  // ── Crear lista con items ─────────────────────────────────────────────────
  Future<InventoryList> createList({
    required String title,
    required List<InventoryItem> items,
    int? folio,
  }) async {
    final listData = await _client
        .from('inventory_lists')
        .insert({
          'floreria_id': _userId,
          'created_by_user_id': _userId,
          'title': title,
          if (folio != null) 'folio': folio,
        })
        .select()
        .single();

    final listId = listData['id'] as String;
    if (items.isNotEmpty) {
      await _client.from('inventory_items').insert(
            items.map((it) => it.toInsertMap(listId)).toList(),
          );
    }

    final full = await _client
        .from('inventory_lists')
        .select('*, inventory_items(id, list_id, sequence_number, product_name, color, quality, quantity)')
        .eq('id', listId)
        .single();
    return InventoryList.fromMap(Map<String, dynamic>.from(full));
  }

  // ── Editar lista ──────────────────────────────────────────────────────────
  Future<InventoryList> updateList({
    required String listId,
    required String title,
    required List<InventoryItem> items,
  }) async {
    await _client.from('inventory_lists').update({
      'title': title,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', listId);

    // Reemplazar todos los items
    await _client.from('inventory_items').delete().eq('list_id', listId);
    if (items.isNotEmpty) {
      await _client.from('inventory_items').insert(
            items.map((it) => it.toInsertMap(listId)).toList(),
          );
    }

    final full = await _client
        .from('inventory_lists')
        .select('*, inventory_items(id, list_id, sequence_number, product_name, color, quality, quantity)')
        .eq('id', listId)
        .single();
    return InventoryList.fromMap(Map<String, dynamic>.from(full));
  }

  // ── Toggle activa / inactiva ──────────────────────────────────────────────
  Future<void> toggleActive(String listId, bool newValue) async {
    await _client.from('inventory_lists').update({
      'is_active': newValue,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', listId).eq('floreria_id', _userId);
  }

  // ── Toggle completada ─────────────────────────────────────────────────────
  Future<void> toggleCompleted(String listId, bool newValue) async {
    await _client.from('inventory_lists').update({
      'is_completed': newValue,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', listId).eq('floreria_id', _userId);
  }

  // ── Eliminar lista ────────────────────────────────────────────────────────
  Future<void> deleteList(String listId) async {
    await _client.from('inventory_lists').delete().eq('id', listId).eq('floreria_id', _userId);
  }
}
