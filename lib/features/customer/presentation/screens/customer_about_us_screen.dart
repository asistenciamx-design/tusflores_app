import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../reviews/presentation/widgets/shop_reviews_section.dart';

class CustomerAboutUsScreen extends StatefulWidget {
  final String? shopId;
  const CustomerAboutUsScreen({super.key, this.shopId});

  @override
  State<CustomerAboutUsScreen> createState() => _CustomerAboutUsScreenState();
}

class _CustomerAboutUsScreenState extends State<CustomerAboutUsScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final shopId = widget.shopId ?? Supabase.instance.client.auth.currentUser?.id;
    if (shopId == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('shop_name, biography, years_of_experience, specialties, milestones, gallery, logo_url')
          .eq('id', shopId)
          .maybeSingle();
      if (mounted) setState(() { _profile = profile; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _shopName => _profile?['shop_name'] ?? 'Nuestra Florería';
  String get _biography => _profile?['biography'] ?? '';
  int get _years => _profile?['years_of_experience'] ?? 0;
  List<String> get _specialties =>
      _profile?['specialties'] != null
          ? List<String>.from(_profile!['specialties'])
          : [];
  List<Map<String, dynamic>> get _milestones =>
      _profile?['milestones'] != null
          ? List<Map<String, dynamic>>.from(_profile!['milestones'])
          : [];
  List<String> get _gallery =>
      _profile?['gallery'] != null
          ? List<String>.from(_profile!['gallery'])
          : [];
  String? get _logoUrl => _profile?['logo_url'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildCoverHeader(),
                  _buildAboutCard(),
                  if (_specialties.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    _buildSectionTitle(Icons.local_florist, 'Especialidades'),
                    const SizedBox(height: 16),
                    _buildSpecialtiesGrid(),
                  ],
                  if (_milestones.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    _buildSectionTitle(Icons.history, 'Nuestra Trayectoria'),
                    const SizedBox(height: 16),
                    _buildTimeline(),
                  ],
                  if (_gallery.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    _buildGalleryHeader(),
                    const SizedBox(height: 16),
                    _buildGalleryGrid(),
                  ],
                  const SizedBox(height: 32),
                  _buildDivider(),
                  const SizedBox(height: 24),
                  ShopReviewsSection(
                    shopId: widget.shopId ?? Supabase.instance.client.auth.currentUser?.id ?? '',
                    shopName: _shopName,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildCoverHeader() {
    return Container(
      height: 300,
      color: const Color(0xFFE5E5E5),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_logoUrl != null && _logoUrl!.isNotEmpty)
            Image.network(_logoUrl!, fit: BoxFit.cover,
                color: Colors.black.withValues(alpha: 0.3),
                colorBlendMode: BlendMode.darken,
                errorBuilder: (_, __, ___) => _defaultCover())
          else
            _defaultCover(),
          Positioned(
            left: 20,
            bottom: 40,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_years > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '$_years AÑOS DE EXPERIENCIA',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  _shopName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_biography.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _biography.length > 80
                        ? '${_biography.substring(0, 80)}...'
                        : _biography,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultCover() {
    return Container(
      color: const Color(0xFF2D5A27),
      child: const Center(
        child: Icon(Icons.local_florist, size: 80, color: Colors.white24),
      ),
    );
  }

  Widget _buildAboutCard() {
    final bio = _biography;
    if (bio.isEmpty) return const SizedBox.shrink();
    return Transform.translate(
      offset: const Offset(0, -20),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                        color: Colors.grey[800], fontSize: 14, height: 1.6),
                    children: [
                      TextSpan(
                          text: '$_shopName ',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: bio),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialtiesGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.1,
        children: _specialties
            .take(4)
            .map((spec) => _buildSpecialtyCard(spec))
            .toList(),
      ),
    );
  }

  Widget _buildSpecialtyCard(String spec) {
    final info = _specialtyInfo(spec);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(info['icon'] as IconData,
                color: AppTheme.primary, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            spec,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _specialtyInfo(String spec) {
    final lower = spec.toLowerCase();
    if (lower.contains('boda') || lower.contains('novia')) {
      return {'icon': Icons.favorite};
    } else if (lower.contains('corporat') || lower.contains('empresa')) {
      return {'icon': Icons.business};
    } else if (lower.contains('social') ||
        lower.contains('xv') ||
        lower.contains('fiesta')) {
      return {'icon': Icons.celebration};
    } else if (lower.contains('arreglo') || lower.contains('floral')) {
      return {'icon': Icons.local_florist};
    } else if (lower.contains('mayor')) {
      return {'icon': Icons.warehouse};
    } else if (lower.contains('rosa')) {
      return {'icon': Icons.eco};
    } else {
      return {'icon': Icons.star};
    }
  }

  Widget _buildTimeline() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _milestones.asMap().entries.map((entry) {
          final isLast = entry.key == _milestones.length - 1;
          final m = entry.value;
          return _buildTimelineNode(
            year: m['year']?.toString() ?? '',
            title: m['title']?.toString() ?? '',
            description: m['description']?.toString() ?? '',
            isLast: isLast,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimelineNode({
    required String year,
    required String title,
    required String description,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppTheme.primary, width: 3),
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.grey[200],
                      margin: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  )
                else
                  const SizedBox(height: 40),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    year,
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 13, height: 1.5),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey[200])),
        ],
      ),
    );
  }

  Widget _buildGalleryHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: [
          Icon(Icons.photo_library, color: AppTheme.primary, size: 20),
          SizedBox(width: 8),
          Text(
            'Galería',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryGrid() {
    final photos = _gallery;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: photos
                  .asMap()
                  .entries
                  .where((e) => e.key.isEven)
                  .map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildGalleryImage(e.value, e.key == 0 ? 200 : 160),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: photos
                  .asMap()
                  .entries
                  .where((e) => e.key.isOdd)
                  .map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildGalleryImage(e.value, e.key == 1 ? 160 : 200),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryImage(String url, double height) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.image, color: Colors.black12)),
      ),
    );
  }
}
