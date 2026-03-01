import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class CustomerAboutUsScreen extends StatelessWidget {
  const CustomerAboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Nosotros',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
         // Adding back button although usually covered by bottom navigation
         // depending on router configuration, if standalone, it helps.
        leading: Navigator.canPop(context) 
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => Navigator.maybePop(context),
              )
            : null,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCoverHeader(),
            _buildAboutCard(),
            const SizedBox(height: 32),
            _buildSectionTitle(Icons.local_florist, 'Eventos que Atendemos'),
            const SizedBox(height: 16),
            _buildEventsGrid(),
            const SizedBox(height: 32),
            _buildSectionTitle(Icons.history, 'Nuestra Trayectoria'),
            const SizedBox(height: 16),
            _buildTimeline(),
            const SizedBox(height: 32),
            _buildGalleryHeader(),
            const SizedBox(height: 16),
            _buildGalleryGrid(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverHeader() {
    return Container(
      height: 300,
      decoration: const BoxDecoration(
        color: Color(0xFFE5E5E5), // Base background for image
        // Placeholder for the actual image. In a real scenario, use DecorationImage(image: NetworkImage(...))
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Simulated floral background image
          Image.network(
            'https://images.unsplash.com/photo-1549643276-fbc2d8ca2e93?auto=format&fit=crop&q=80',
            fit: BoxFit.cover,
            color: Colors.black.withValues(alpha: 0.3),
            colorBlendMode: BlendMode.darken,
          ),
          Positioned(
            left: 20,
            bottom: 40,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        '5 AÑOS DE EXPERIENCIA',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                 const Text(
                  'Florería Las Rosas',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Creamos momentos inolvidables a través\ndel lenguaje honesto de las flores.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAboutCard() {
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
          ]
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
                    style: TextStyle(color: Colors.grey[800], fontSize: 14, height: 1.6),
                    children: const [
                      TextSpan(text: 'En '),
                      TextSpan(text: 'Florería Las Rosas', style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: ', nos especializamos en diseños '),
                      TextSpan(text: 'orgánicos y atemporales', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                      TextSpan(text: '. Nuestra misión es transformar espacios ordinarios en experiencias sensoriales extraordinarias, cuidando cada detalle desde la selección del tallo hasta la entrega final.'),
                    ]
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
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.1,
        children: [
          _buildEventCard(Icons.favorite, 'Bodas', 'Ramos de novia y\ndecoración...'),
          _buildEventCard(Icons.business, 'Corporativos', 'Eventos y regalos\nempresariales'),
          _buildEventCard(Icons.celebration, 'Sociales', 'XV años y\ncelebraciones'),
          _buildEventCard(Icons.local_florist, 'Arreglos', 'Detalles para toda\nocasión'),
        ],
      ),
    );
  }

  Widget _buildEventCard(IconData icon, String title, String subtitle) {
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
         ]
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
             child: Icon(icon, color: AppTheme.primary, size: 24),
           ),
           const SizedBox(height: 12),
           Text(
             title,
             style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
           ),
           const SizedBox(height: 4),
           Text(
             subtitle,
             textAlign: TextAlign.center,
             style: TextStyle(color: Colors.grey[500], fontSize: 11, height: 1.3),
           ),
         ],
       ),
    );
  }

  Widget _buildTimeline() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimelineNode(
            year: '2023 - ACTUALIDAD',
            title: 'Consolidación de Mercado',
            description: 'Más de 500 eventos realizados con éxito y certificación como proveedor premium en 5 hoteles de lujo.',
            isLast: false,
          ),
          _buildTimelineNode(
            year: '2020',
            title: 'Expansión Local',
            description: 'Ampliamos nuestra cobertura a San Miguel de Allende y Valle de Bravo, especializándonos en bodas destino.',
            isLast: false,
          ),
           _buildTimelineNode(
            year: '2015',
            title: 'Fundación del Negocio',
            description: 'Comenzamos con un pequeño taller en CDMX con un enfoque en diseño floral sostenible.',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineNode({required String year, required String title, required String description, required bool isLast}) {
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
                  else const SizedBox(height: 40) // Spacing for last node
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
                      style: const TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.5),
                    ),
                 ],
               ),
             ),
           )
        ],
      ),
    );
  }

  Widget _buildGalleryHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.photo_library, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Galería Reciente',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
           Text(
            'Ver todo',
            style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 13),
          )
        ],
      ),
    );
  }

  Widget _buildGalleryGrid() {
     return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      // To mimic the staggered layout from the design we can use a row with two columns 
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                _buildGalleryImage('https://images.unsplash.com/photo-1596431940381-42cb062fa53e?auto=format&fit=crop&q=80', 200),
                const SizedBox(height: 12),
                _buildGalleryImage('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&q=80', 160),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                _buildGalleryImage('https://images.unsplash.com/photo-1497215898147-5bf61b96d925?auto=format&fit=crop&q=80', 160),
                const SizedBox(height: 12),
                _buildGalleryImage('https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&q=80', 200),
              ],
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
        image: DecorationImage(
          image: NetworkImage(url),
          fit: BoxFit.cover,
        )
      ),
    );
  }
}
