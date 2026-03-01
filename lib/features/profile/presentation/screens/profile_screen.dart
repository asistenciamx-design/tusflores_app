import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Nosotros', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeroImage(context),
            // Floating section overlaps the hero image slightly
            Transform.translate(
              offset: const Offset(0, -24),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppTheme.backgroundLight,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDescription(context),
                      const SizedBox(height: 40),
                      _buildEventsGrid(context),
                      const SizedBox(height: 40),
                      _buildTimeline(context),
                      const SizedBox(height: 40),
                      _buildGallery(context),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroImage(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          height: 380,
          width: double.infinity,
          child: Image.network(
            'https://lh3.googleusercontent.com/aida-public/AB6AXuA2udWFUFjhd-rfk1bHrjG8ptdetn-XQHPNXYAAyhF0EDK9wgSuoBJaej_w7Ew4sIUrQkMor7CI9TmG1xw-fpnZRsbp6R2dw_pHqVg2Ca1Am-QHqK7tau_Mz7pEWFPN2fE2JnFh1Pm9ho0OXONJtQtxCdJ-dTcX66m01Pj8goPen07c5-wLJonSF-CrQvYKe43m98s9DzbpYlmuP-G6Q0IXS19Z4V56j8ZUP4VleXCQcarMe5Sssj-VubzcUPgIqVUjFBya7tDtSj3Y',
            fit: BoxFit.cover,
            color: Colors.black.withValues(alpha: 0.3),
            colorBlendMode: BlendMode.darken,
          ),
        ),
        Positioned(
          bottom: 48,
          left: 24,
          right: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, color: Colors.white, size: 14),
                    SizedBox(width: 8),
                    Text(
                      '5 AÑOS DE EXPERIENCIA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Florería las Rosas',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Playfair Display',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Creamos momentos inolvidables a través del lenguaje honesto de las flores.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDescription(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: AppTheme.primary, width: 4),
        ),
      ),
      padding: const EdgeInsets.only(left: 16),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: AppTheme.mutedLight,
            fontSize: 15,
            height: 1.6,
            fontFamily: 'Poppins',
          ),
          children: [
            const TextSpan(text: 'En '),
            const TextSpan(
              text: 'Florería Las Rosas',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textLight),
            ),
            const TextSpan(text: ', nos especializamos en diseños '),
            TextSpan(
              text: 'orgánicos y atemporales',
              style: TextStyle(fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.primary),
            ),
            const TextSpan(
              text: '. Nuestra misión es transformar espacios ordinarios en experiencias sensoriales extraordinarias, cuidando cada detalle desde la selección del tallo hasta la entrega final.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsGrid(BuildContext context) {
    return Column(
      children: [
        _buildSectionHeader(context, Icons.spa, 'Eventos que Atendemos'),
        const SizedBox(height: 24),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 0.85,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: const [
            _EventCard(icon: Icons.favorite, title: 'Bodas', description: 'Ramos de novia y decoración integral'),
            _EventCard(icon: Icons.domain, title: 'Corporativos', description: 'Eventos y regalos empresariales'),
            _EventCard(icon: Icons.celebration, title: 'Sociales', description: 'XV años y celebraciones'),
            _EventCard(icon: Icons.local_florist, title: 'Arreglos', description: 'Detalles para toda ocasión'),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeline(BuildContext context) {
    return Column(
      children: [
        _buildSectionHeader(context, Icons.history_edu, 'Nuestra Trayectoria'),
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.only(left: 8.0),
          child: Column(
            children: [
              _TimelineItem(
                year: '2023 - Actualidad',
                title: 'Consolidación de Mercado',
                description: 'Más de 500 eventos realizados con éxito y certificación como proveedor premium en 5 hoteles de lujo.',
                isLast: false,
              ),
              _TimelineItem(
                year: '2020',
                title: 'Expansión Local',
                description: 'Ampliamos nuestra cobertura a San Miguel de Allende y Valle de Bravo, especializándonos en bodas destino.',
                isLast: false,
              ),
              _TimelineItem(
                year: '2018',
                title: 'Fundación del Negocio',
                description: 'Comenzamos con un pequeño taller en CDMX con un enfoque en diseño floral sostenible.',
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGallery(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader(context, Icons.photo_library, 'Galería Reciente', paddingBottom: 0),
            TextButton(
              onPressed: () {},
              child: const Text('Ver todo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Column(
          children: [
            Row(
              children: [
                Expanded(child: _buildGalleryImage('https://lh3.googleusercontent.com/aida-public/AB6AXuCWU848bpNFAT6Q1O_eX2UFQ4-y4oGKuuVG9gaaOt2kNROPZTqsTYlGcKa_a5CS-LljiyM24vu4hqfElRy5pMTouhAolNhxIWfqyWjjLtEdkrwWe5HEnrW420jwxaJgbGwivE-QnQ-xRNOCtzb9Z9fl3xTnZhllq9c3F6s1zgi6MsI2Mkh_xEUjjaqQsif9MlribZKKpOniFMMiLy4cRPOT0qINQ-hTvd5pfAHWvcI6fGlgfHxB4VgGgSByNZoFY-wbubkSMjG50UxQ', height: 180)),
                const SizedBox(width: 12),
                Expanded(child: _buildGalleryImage('https://lh3.googleusercontent.com/aida-public/AB6AXuBfiKcWrJB9QwNA4WstbjpXIZaAKXYBSBUI_DZ3JctNkNFyQZZSge7xfEkDaikk_alwXn6JC_eNf6z48O7jqi9F2RRjRDU3qtLhAbBr4kDnOegByDSnlxIMGvmZ65BuODgnYcJl7Rf1ujymjbW7DPNHVSLz48ldHDN6h-rlgeTRUE_tW0zQQMAH67Hx4TUBOv56BehrWl8Xw67_pZhwI9HNjJFhOeNLqUVIDosM_ra6-w7Y25RmElcB2H_nBI5TBKJIW8a4pjCgSB5f', height: 180)),
              ],
            ),
            const SizedBox(height: 12),
            Stack(
              children: [
                _buildGalleryImage('https://lh3.googleusercontent.com/aida-public/AB6AXuBwY_gk845OXdF3Xz1kyAhNdLPBDlbF2fSiAXU4aupqK9C7W5x0BCQhRxXorLThxA8N6ChGic0CdsMIrLt8PwL2HK8cZN2ayHlihTSNsuVvu4o0KmMJyCFmWLU8nmDmTrZo4K2g9BFrTEsqOua6lkf61_dsUoPknqIeXrD-D-lP-ywZFRgcHFPPi5iec8_IQJaNJVMQyznKZXx7n37CgTsOsETRcvMnMz5Tpac357KdTUo0C48wlQHEjO5lH5Cg4OVX7CxAMoCxcK1J', height: 220, width: double.infinity),
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on, color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text('Jardín Santa Fe', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildGalleryImage('https://lh3.googleusercontent.com/aida-public/AB6AXuAhnU_Ahlp7apQxxRud-hqb2LFrtKjHVZiiFBB_ICFcMKgvjeSFOs49bGTEoQP6CzO25SZSs9jDQAvCdvbHkKxTsrvpa65kzVuDKExmOmIWCeK-iLnWuzq7vyfg7RUUw2Q6o1euk3YM_icMTXxAN1H_8P0CwID5M5_HJ3jfuGchPNM4_K-F71ZrjsIuy5OEnb-ADNjdjS1ECqoq8vqaC7QtHh8TGUlLbD6otzHTDNZOrrARV0MPDDatRSWyzLJqq4DWOhKO8L4IfFty', height: 180)),
                const SizedBox(width: 12),
                Expanded(child: _buildGalleryImage('https://lh3.googleusercontent.com/aida-public/AB6AXuCdAsj4mFP_Hf9LocVGmG48tuGqmH356FesDje6jKKQxYxTGUVj1VzbhMT8jHPZgvpc_Bps-NA5LUlv59XZJCBJcZurgKFB4nnP7UbF0EBAg4rU9NEZ5RNezbYPeCgKxvxzHgzeXk0brL-I8CtJLzjA-xTJl9nbqKYni8OyLGNdqFdFflvOJlTCkwiqmAV1GIlab3eFmdCHwlNw3utAzZDNybFXGimi_D0Co5fmrQqeHgmgMmoCqq4Djx4lZBQr-ROS3y0XrEuHnFdA', height: 180)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGalleryImage(String url, {required double height, double? width}) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
        image: DecorationImage(
          image: NetworkImage(url),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, IconData icon, String title, {double paddingBottom = 0}) {
    return Padding(
      padding: EdgeInsets.only(bottom: paddingBottom),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _EventCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.primary, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textLight),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(fontSize: 12, color: AppTheme.mutedLight),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final String year;
  final String title;
  final String description;
  final bool isLast;

  const _TimelineItem({
    required this.year,
    required this.title,
    required this.description,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (!isLast)
                  Positioned(
                    top: 16,
                    bottom: -24, // overlap to the next item
                    left: 11,
                    child: Container(width: 2, color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primary, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16.0, bottom: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    year.toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.textLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AppTheme.mutedLight,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
