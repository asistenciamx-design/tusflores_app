import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/review_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../screens/review_form_screen.dart';

/// Widget que muestra el resumen de calificación + listado de reseñas.
/// Se usa en CustomerAboutUsScreen y en la página pública de la tienda.
class ShopReviewsSection extends StatefulWidget {
  final String shopId;
  final String shopName;

  const ShopReviewsSection({
    super.key,
    required this.shopId,
    required this.shopName,
  });

  @override
  State<ShopReviewsSection> createState() => _ShopReviewsSectionState();
}

class _ShopReviewsSectionState extends State<ShopReviewsSection> {
  List<ReviewModel> _reviews = [];
  double _average = 0;
  int _count = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // Load reviews and rating from profiles in parallel
      final results = await Future.wait([
        Supabase.instance.client
            .from('shop_reviews')
            .select()
            .eq('shop_id', widget.shopId)
            .eq('is_visible', true)
            .order('created_at', ascending: false)
            .limit(20),
        Supabase.instance.client
            .from('profiles')
            .select('average_rating, review_count')
            .eq('id', widget.shopId)
            .maybeSingle(),
      ]);

      final reviewRows = results[0] as List;
      final profile = results[1] as Map<String, dynamic>?;

      if (mounted) {
        setState(() {
          _reviews =
              reviewRows.map((r) => ReviewModel.fromJson(r)).toList();
          _average =
              (profile?['average_rating'] as num?)?.toDouble() ?? 0;
          _count = profile?['review_count'] as int? ?? 0;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              const Icon(Icons.star_rounded,
                  color: Color(0xFFF59E0B), size: 22),
              const SizedBox(width: 8),
              const Text(
                'Reseñas',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReviewFormScreen(
                        shopId: widget.shopId,
                        shopName: widget.shopName,
                      ),
                    ),
                  );
                  _load(); // reload after review
                },
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Opinar'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFE91E8C),
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Rating summary card ────────────────────────────────────────────
        if (_count > 0) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _RatingSummaryCard(
                average: _average, count: _count, reviews: _reviews),
          ),
          const SizedBox(height: 20),
        ],

        // ── Review list ───────────────────────────────────────────────────
        if (_reviews.isEmpty)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.rate_review_outlined,
                      size: 48, color: Colors.black12),
                  const SizedBox(height: 12),
                  const Text(
                    'Aún no hay reseñas.',
                    style: TextStyle(
                        color: Colors.black45,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '¡Sé el primero en opinar!',
                    style: TextStyle(color: Colors.black38, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReviewFormScreen(
                            shopId: widget.shopId,
                            shopName: widget.shopName,
                          ),
                        ),
                      );
                      _load();
                    },
                    icon: const Icon(Icons.star_outline_rounded, size: 18),
                    label: const Text('Dejar reseña'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE91E8C),
                      side: const BorderSide(color: Color(0xFFE91E8C)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _reviews.length,
            itemBuilder: (_, i) => _ReviewCard(review: _reviews[i]),
          ),
      ],
    );
  }
}

// ── Rating summary card ─────────────────────────────────────────────────────

class _RatingSummaryCard extends StatelessWidget {
  final double average;
  final int count;
  final List<ReviewModel> reviews;

  const _RatingSummaryCard({
    required this.average,
    required this.count,
    required this.reviews,
  });

  @override
  Widget build(BuildContext context) {
    // Compute distribution
    final dist = List.filled(5, 0);
    for (final r in reviews) {
      if (r.rating >= 1 && r.rating <= 5) dist[r.rating - 1]++;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          // Left: big number
          Column(
            children: [
              Text(
                average.toStringAsFixed(1),
                style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E)),
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < average.round()
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 16,
                    color: const Color(0xFFF59E0B),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$count reseña${count == 1 ? '' : 's'}',
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF888899)),
              ),
            ],
          ),
          const SizedBox(width: 20),
          const VerticalDivider(width: 1),
          const SizedBox(width: 20),
          // Right: bars
          Expanded(
            child: Column(
              children: List.generate(5, (i) {
                final star = 5 - i;
                final val = count > 0 ? dist[star - 1] / count : 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Text('$star',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF888899))),
                      const SizedBox(width: 4),
                      const Icon(Icons.star_rounded,
                          size: 10, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: val,
                            minHeight: 6,
                            backgroundColor: const Color(0xFFF0F0F0),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFFF59E0B)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${dist[star - 1]}',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF888899))),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Individual review card ──────────────────────────────────────────────────

class _ReviewCard extends StatefulWidget {
  final ReviewModel review;
  const _ReviewCard({required this.review});

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.review;
    final hasComment = r.comment != null && r.comment!.isNotEmpty;
    final hasReply = r.shopReply != null && r.shopReply!.isNotEmpty;
    final long = hasComment && r.comment!.length > 120;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor:
                    const Color(0xFFE91E8C).withValues(alpha: 0.12),
                child: Text(
                  r.reviewerName.isNotEmpty
                      ? r.reviewerName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: Color(0xFFE91E8C),
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.reviewerName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFF1A1A2E)),
                          ),
                        ),
                        if (r.isVerified)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_rounded,
                                    size: 10, color: Color(0xFF10B981)),
                                SizedBox(width: 3),
                                Text('Verificado',
                                    style: TextStyle(
                                        fontSize: 9,
                                        color: Color(0xFF10B981),
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        ...List.generate(
                          5,
                          (i) => Icon(
                            i < r.rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 14,
                            color: const Color(0xFFF59E0B),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatDate(r.createdAt),
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF888899)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasComment) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: long ? () => setState(() => _expanded = !_expanded) : null,
              child: Text(
                (!_expanded && long)
                    ? '${r.comment!.substring(0, 120)}...'
                    : r.comment!,
                style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF444455),
                    height: 1.5),
              ),
            ),
            if (long)
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Text(
                  _expanded ? 'Ver menos' : 'Ver más',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFE91E8C),
                      fontWeight: FontWeight.w600),
                ),
              ),
          ],
          if (hasReply) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.storefront_outlined,
                      size: 16, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Respuesta de la florería',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryDark)),
                        const SizedBox(height: 4),
                        Text(r.shopReply!,
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF444455))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Hoy';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    if (diff.inDays < 30) return 'Hace ${(diff.inDays / 7).floor()} sem.';
    if (diff.inDays < 365) return 'Hace ${(diff.inDays / 30).floor()} meses';
    return 'Hace ${(diff.inDays / 365).floor()} año${(diff.inDays / 365).floor() > 1 ? 's' : ''}';
  }
}
