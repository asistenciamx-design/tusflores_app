import 'package:flutter/material.dart';
import '../../domain/models/review_model.dart';
import '../../domain/repositories/review_repository.dart';

class ReviewFormScreen extends StatefulWidget {
  final String shopId;
  final String shopName;
  final String? orderId;
  final String? customerName;

  const ReviewFormScreen({
    super.key,
    required this.shopId,
    required this.shopName,
    this.orderId,
    this.customerName,
  });

  @override
  State<ReviewFormScreen> createState() => _ReviewFormScreenState();
}

class _ReviewFormScreenState extends State<ReviewFormScreen> {
  final _nameController = TextEditingController();
  final _commentController = TextEditingController();
  int _rating = 5;
  bool _loading = false;
  bool _done = false;

  static const _pink = Color(0xFFE91E8C);

  @override
  void initState() {
    super.initState();
    if (widget.customerName != null && widget.customerName!.isNotEmpty) {
      _nameController.text = widget.customerName!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa tu nombre')),
      );
      return;
    }

    setState(() => _loading = true);

    final review = ReviewModel(
      shopId: widget.shopId,
      orderId: widget.orderId,
      reviewerName: name,
      rating: _rating.clamp(1, 5),
      comment: _commentController.text.trim().isEmpty
          ? null
          : _commentController.text.trim(),
      isVerified: widget.orderId != null,
      createdAt: DateTime.now(),
    );

    final ok = await ReviewRepository().createReview(review);

    if (mounted) {
      setState(() {
        _loading = false;
        _done = ok;
      });
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ocurrió un error. Intenta de nuevo.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF6F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDF6F0),
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2E)),
                onPressed: () => Navigator.maybePop(context),
              )
            : null,
        title: Text(
          'Calificar ${widget.shopName}',
          style: const TextStyle(
              color: Color(0xFF1A1A2E),
              fontWeight: FontWeight.bold,
              fontSize: 17),
        ),
      ),
      body: _done ? _buildSuccess() : _buildForm(),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rating stars
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _pink.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.local_florist_rounded,
                      size: 38, color: _pink),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.shopName,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E)),
                ),
                const SizedBox(height: 6),
                const Text(
                  '¿Cómo fue tu experiencia?',
                  style: TextStyle(fontSize: 14, color: Color(0xFF888899)),
                ),
                const SizedBox(height: 20),
                _StarRating(
                  value: _rating,
                  onChanged: (v) => setState(() => _rating = v),
                ),
                const SizedBox(height: 8),
                Text(
                  _ratingLabel(_rating),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _ratingColor(_rating)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Name
          const Text('Tu nombre',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Color(0xFF444455))),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            maxLength: 80,
            decoration: InputDecoration(
              hintText: 'Ej. María G.',
              counterText: '',
              prefixIcon: const Icon(Icons.person_outline, color: _pink),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _pink, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 20),

          // Comment
          const Text('Tu comentario (opcional)',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Color(0xFF444455))),
          const SizedBox(height: 8),
          TextField(
            controller: _commentController,
            maxLines: 4,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText:
                  'Cuéntanos qué te pareció la calidad, el servicio, la puntualidad...',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _pink, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _pink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Enviar calificación',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  size: 48, color: Color(0xFF10B981)),
            ),
            const SizedBox(height: 24),
            const Text(
              '¡Gracias por tu reseña!',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Tu opinión ayuda a ${widget.shopName} a seguir mejorando y a otros clientes a tomar mejores decisiones.',
              style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF888899),
                  height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _StarRating(value: _rating, onChanged: null),
            const SizedBox(height: 40),
            TextButton(
              onPressed: () => Navigator.maybePop(context),
              child: const Text('Cerrar',
                  style: TextStyle(color: _pink, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }

  String _ratingLabel(int r) {
    switch (r) {
      case 1: return 'Muy mala experiencia';
      case 2: return 'Podría mejorar';
      case 3: return 'Regular';
      case 4: return 'Muy buena';
      case 5: return '¡Excelente!';
      default: return '';
    }
  }

  Color _ratingColor(int r) {
    if (r <= 2) return const Color(0xFFEF4444);
    if (r == 3) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }
}

// ── Star rating widget ──────────────────────────────────────────────────────

class _StarRating extends StatelessWidget {
  final int value;
  final ValueChanged<int>? onChanged;

  const _StarRating({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < value;
        return GestureDetector(
          onTap: onChanged != null ? () => onChanged!(i + 1) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 40,
              color: filled ? const Color(0xFFF59E0B) : const Color(0xFFDDDDDD),
            ),
          ),
        );
      }),
    );
  }
}
