import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/review_model.dart';
import '../../../../core/theme/app_theme.dart';

/// Widget de resumen de calificación para el dashboard de la florería.
class DashboardRatingWidget extends StatefulWidget {
  final String shopId;
  const DashboardRatingWidget({super.key, required this.shopId});

  @override
  State<DashboardRatingWidget> createState() => _DashboardRatingWidgetState();
}

class _DashboardRatingWidgetState extends State<DashboardRatingWidget> {
  double _average = 0;
  int _count = 0;
  List<ReviewModel> _recent = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.shopId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final results = await Future.wait([
        Supabase.instance.client
            .from('profiles')
            .select('average_rating, review_count')
            .eq('id', widget.shopId)
            .maybeSingle(),
        Supabase.instance.client
            .from('shop_reviews')
            .select()
            .eq('shop_id', widget.shopId)
            .eq('is_visible', true)
            .order('created_at', ascending: false)
            .limit(3),
      ]);
      final profile = results[0] as Map<String, dynamic>?;
      final rows = results[1] as List;

      if (mounted) {
        setState(() {
          _average = (profile?['average_rating'] as num?)?.toDouble() ?? 0;
          _count = profile?['review_count'] as int? ?? 0;
          _recent = rows.map((r) => ReviewModel.fromJson(r)).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.star_rounded,
                      color: Color(0xFFF59E0B), size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Reseñas de clientes',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                if (_count > 0)
                  TextButton(
                    onPressed: () => context.push('/reviews/manage'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text('Ver todas',
                        style: TextStyle(fontSize: 13)),
                  ),
              ],
            ),
          ),

          // Rating summary
          Padding(
            padding: const EdgeInsets.all(20),
            child: _count == 0
                ? _buildEmpty()
                : _buildSummary(context),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            const Icon(Icons.rate_review_outlined,
                size: 40, color: Colors.black12),
            const SizedBox(height: 8),
            const Text(
              'Aún no tienes reseñas.',
              style: TextStyle(color: Colors.black45, fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              'Las reseñas aparecerán aquí cuando los clientes califiquen sus pedidos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black38, fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(BuildContext context) {
    return Column(
      children: [
        // Big rating row
        Row(
          children: [
            Text(
              _average.toStringAsFixed(1),
              style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E)),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < _average.round()
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 18,
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_count reseña${_count == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF888899)),
                ),
              ],
            ),
          ],
        ),
        if (_recent.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          // Recent reviews preview
          ..._recent.map((r) => _RecentReviewTile(review: r)),
        ],
      ],
    );
  }
}

class _RecentReviewTile extends StatelessWidget {
  final ReviewModel review;
  const _RecentReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor:
                const Color(0xFFE91E8C).withValues(alpha: 0.1),
            child: Text(
              review.reviewerName.isNotEmpty
                  ? review.reviewerName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                  color: Color(0xFFE91E8C),
                  fontWeight: FontWeight.bold,
                  fontSize: 12),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      review.reviewerName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Color(0xFF1A1A2E)),
                    ),
                    const SizedBox(width: 6),
                    ...List.generate(
                      review.rating,
                      (_) => const Icon(Icons.star_rounded,
                          size: 11, color: Color(0xFFF59E0B)),
                    ),
                  ],
                ),
                if (review.comment != null && review.comment!.isNotEmpty)
                  Text(
                    review.comment!.length > 80
                        ? '${review.comment!.substring(0, 80)}...'
                        : review.comment!,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF666677),
                        height: 1.4),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
