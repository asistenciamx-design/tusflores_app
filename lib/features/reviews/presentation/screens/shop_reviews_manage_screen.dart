import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/review_model.dart';
import '../../domain/repositories/review_repository.dart';

class ShopReviewsManageScreen extends StatefulWidget {
  const ShopReviewsManageScreen({super.key});

  @override
  State<ShopReviewsManageScreen> createState() => _ShopReviewsManageScreenState();
}

enum _Filter { all, visible, hidden }

class _ShopReviewsManageScreenState extends State<ShopReviewsManageScreen> {
  static const _primary = Color(0xFFC2185B);

  final _repo = ReviewRepository();
  List<ReviewModel> _reviews = [];
  bool _loading = true;
  _Filter _filter = _Filter.all;

  String get _shopId => Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _repo.getAllShopReviews(_shopId);
    if (mounted) setState(() { _reviews = data; _loading = false; });
  }

  List<ReviewModel> get _filtered {
    switch (_filter) {
      case _Filter.visible: return _reviews.where((r) => r.isVisible).toList();
      case _Filter.hidden:  return _reviews.where((r) => !r.isVisible).toList();
      case _Filter.all:     return _reviews;
    }
  }

  double get _average {
    if (_reviews.isEmpty) return 0;
    return _reviews.map((r) => r.rating).reduce((a, b) => a + b) / _reviews.length;
  }

  Future<void> _toggleVisibility(ReviewModel review) async {
    final newVal = !review.isVisible;
    final ok = await _repo.setReviewVisibility(review.id!, newVal);
    if (ok && mounted) {
      setState(() {
        final idx = _reviews.indexWhere((r) => r.id == review.id);
        if (idx >= 0) {
          _reviews[idx] = ReviewModel(
            id: review.id,
            shopId: review.shopId,
            orderId: review.orderId,
            reviewerName: review.reviewerName,
            rating: review.rating,
            comment: review.comment,
            shopReply: review.shopReply,
            isVerified: review.isVerified,
            isVisible: newVal,
            createdAt: review.createdAt,
          );
        }
      });
    }
  }

  void _openReplySheet(ReviewModel review) {
    final ctrl = TextEditingController(text: review.shopReply ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        bool saving = false;
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.reply_rounded, color: _primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        review.shopReply != null ? 'Editar respuesta' : 'Responder reseña',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '"${review.comment ?? review.reviewerName}"',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF888899)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: ctrl,
                    maxLines: 4,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Escribe tu respuesta como florería...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _primary, width: 2),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFFAFAFA),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: saving ? null : () async {
                        final text = ctrl.text.trim();
                        if (text.isEmpty) return;
                        setModal(() => saving = true);
                        final ok = await _repo.replyToReview(review.id!, text);
                        if (ok && mounted) {
                          Navigator.pop(ctx);
                          setState(() {
                            final idx = _reviews.indexWhere((r) => r.id == review.id);
                            if (idx >= 0) {
                              _reviews[idx] = ReviewModel(
                                id: review.id,
                                shopId: review.shopId,
                                orderId: review.orderId,
                                reviewerName: review.reviewerName,
                                rating: review.rating,
                                comment: review.comment,
                                shopReply: text,
                                isVerified: review.isVerified,
                                isVisible: review.isVisible,
                                createdAt: review.createdAt,
                              );
                            }
                          });
                        } else {
                          setModal(() => saving = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: saving
                          ? const SizedBox(
                              height: 18, width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Guardar respuesta',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Reseñas de clientes',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _primary),
            onPressed: _load,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : RefreshIndicator(
              color: _primary,
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  // ── Stats bar ──
                  SliverToBoxAdapter(child: _buildStatsBar()),
                  // ── Filter chips ──
                  SliverToBoxAdapter(child: _buildFilterChips()),
                  // ── List ──
                  _filtered.isEmpty
                      ? SliverFillRemaining(child: _buildEmpty())
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _buildReviewCard(_filtered[i]),
                            childCount: _filtered.length,
                          ),
                        ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsBar() {
    final visible = _reviews.where((r) => r.isVisible).length;
    final hidden  = _reviews.where((r) => !r.isVisible).length;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          _StatItem(
            icon: Icons.star_rounded,
            iconColor: const Color(0xFFF59E0B),
            value: _reviews.isEmpty ? '—' : _average.toStringAsFixed(1),
            label: 'Promedio',
          ),
          _divider(),
          _StatItem(
            icon: Icons.rate_review_outlined,
            iconColor: _primary,
            value: '${_reviews.length}',
            label: 'Total',
          ),
          _divider(),
          _StatItem(
            icon: Icons.visibility_outlined,
            iconColor: const Color(0xFF10B981),
            value: '$visible',
            label: 'Visibles',
          ),
          _divider(),
          _StatItem(
            icon: Icons.visibility_off_outlined,
            iconColor: const Color(0xFF9CA3AF),
            value: '$hidden',
            label: 'Pausadas',
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
    width: 1, height: 36,
    color: const Color(0xFFEEEEEE),
  );

  Widget _buildFilterChips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          _FilterChip(
            label: 'Todas (${_reviews.length})',
            selected: _filter == _Filter.all,
            onTap: () => setState(() => _filter = _Filter.all),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Visibles (${_reviews.where((r) => r.isVisible).length})',
            selected: _filter == _Filter.visible,
            onTap: () => setState(() => _filter = _Filter.visible),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Pausadas (${_reviews.where((r) => !r.isVisible).length})',
            selected: _filter == _Filter.hidden,
            onTap: () => setState(() => _filter = _Filter.hidden),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              _filter == _Filter.all
                  ? 'Aún no tienes reseñas'
                  : _filter == _Filter.visible
                      ? 'No hay reseñas visibles'
                      : 'No hay reseñas pausadas',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF888899),
              ),
            ),
            if (_filter == _Filter.all) ...[
              const SizedBox(height: 8),
              const Text(
                'Cuando tus clientes dejen reseñas, aparecerán aquí.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFFAAAAAA)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(ReviewModel review) {
    final isHidden = !review.isVisible;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      decoration: BoxDecoration(
        color: isHidden ? const Color(0xFFF9F9F9) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isHidden
            ? Border.all(color: const Color(0xFFE5E7EB))
            : Border.all(color: Colors.transparent),
        boxShadow: isHidden
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 20,
                  backgroundColor: isHidden
                      ? const Color(0xFFE5E7EB)
                      : _primary.withValues(alpha: 0.12),
                  child: Text(
                    review.reviewerName.isNotEmpty
                        ? review.reviewerName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isHidden ? const Color(0xFF9CA3AF) : _primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              review.reviewerName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isHidden
                                    ? const Color(0xFF9CA3AF)
                                    : const Color(0xFF1A1A2E),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (review.isVerified) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Verificado',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(review.createdAt),
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFFAAAAAA)),
                      ),
                    ],
                  ),
                ),
                // Visibility toggle
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Transform.scale(
                      scale: 0.85,
                      child: Switch(
                        value: review.isVisible,
                        onChanged: review.id != null
                            ? (_) => _toggleVisibility(review)
                            : null,
                        activeColor: _primary,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    Text(
                      review.isVisible ? 'Visible' : 'Pausada',
                      style: TextStyle(
                        fontSize: 10,
                        color: review.isVisible
                            ? const Color(0xFF10B981)
                            : const Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Stars ──
            Row(
              children: List.generate(5, (i) => Icon(
                i < review.rating
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                size: 18,
                color: i < review.rating
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFFDDDDDD),
              )),
            ),

            // ── Comment ──
            if (review.comment != null && review.comment!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                review.comment!,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: isHidden
                      ? const Color(0xFFAAAAAA)
                      : const Color(0xFF444455),
                ),
              ),
            ],

            // ── Shop reply ──
            if (review.shopReply != null && review.shopReply!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _primary.withValues(alpha: 0.15)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.storefront_rounded,
                        size: 15, color: _primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        review.shopReply!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF444455),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Actions ──
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: review.id != null
                      ? () => _openReplySheet(review)
                      : null,
                  icon: Icon(
                    review.shopReply != null
                        ? Icons.edit_outlined
                        : Icons.reply_rounded,
                    size: 15,
                  ),
                  label: Text(
                    review.shopReply != null
                        ? 'Editar respuesta'
                        : 'Responder',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primary,
                    side: BorderSide(
                        color: _primary.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Hoy';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E))),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: Color(0xFF888899))),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const _primary = Color(0xFFC2185B);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _primary : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}
