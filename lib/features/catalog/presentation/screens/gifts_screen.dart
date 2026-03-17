import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_cache.dart';
import '../../domain/models/gift_model.dart';
import '../../domain/repositories/gift_repository.dart';
import 'add_edit_gift_screen.dart';

class GiftsScreen extends StatefulWidget {
  const GiftsScreen({super.key});

  @override
  State<GiftsScreen> createState() => _GiftsScreenState();
}

class _GiftsScreenState extends State<GiftsScreen> {
  final _repo = GiftRepository();
  bool _isLoading = true;
  List<GiftItem> _gifts = [];

  @override
  void initState() {
    super.initState();
    _loadGifts();
  }

  Future<void> _loadGifts() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final data = await _repo.getGifts(user.id);
        setState(() {
          _gifts = data.map((j) => GiftItem.fromJson(j)).toList();
        });
      }
    } catch (e) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleActive(GiftItem gift) async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      await _repo.toggleActive(gift.id!, uid, !gift.isActive);
      await _loadGifts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo actualizar el regalo.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _navigateToAddEdit({GiftItem? gift}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddEditGiftScreen(gift: gift)),
    );
    if (result == true) await _loadGifts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Regalos',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _gifts.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  itemCount: _gifts.length,
                  itemBuilder: (_, i) => _buildGiftCard(_gifts[i]),
                ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'addGiftFAB',
        onPressed: () => _navigateToAddEdit(),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 6,
        child: const Icon(Icons.add, size: 32),
      ),
    );
  }

  Widget _buildGiftCard(GiftItem gift) {
    return GestureDetector(
      onTap: () => _navigateToAddEdit(gift: gift),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: gift.isActive
                ? Colors.transparent
                : Colors.grey.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: gift.imageUrl != null && gift.imageUrl!.isNotEmpty
                  ? Image.network(
                      gift.imageUrl!,
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
                    )
                  : _buildImagePlaceholder(),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (gift.sku != null && gift.sku!.isNotEmpty)
                      Text(
                        gift.sku!,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.pink.shade300,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    Text(
                      gift.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: gift.isActive ? Colors.black87 : Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (gift.description != null && gift.description!.isNotEmpty)
                      Text(
                        gift.description!,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Text(
                      '${CurrencyCache.symbol}${gift.price.toStringAsFixed(2)} ${CurrencyCache.code}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF00C853)),
                    ),
                  ],
                ),
              ),
            ),
            // Toggle
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Switch.adaptive(
                value: gift.isActive,
                onChanged: (_) => _toggleActive(gift),
                activeColor: AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: 90,
      height: 90,
      color: Colors.pink.withValues(alpha: 0.08),
      child: const Icon(Icons.card_giftcard, size: 36, color: Colors.pinkAccent),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🎁', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          const Text(
            'Sin regalos aún',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega globos, peluches, chocolates\ny más para complementar tus arreglos.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500, height: 1.5),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _navigateToAddEdit(),
            icon: const Icon(Icons.add),
            label: const Text('Agregar primer regalo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}
