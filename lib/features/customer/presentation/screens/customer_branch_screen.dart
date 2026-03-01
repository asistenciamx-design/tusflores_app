import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class CustomerBranchScreen extends StatelessWidget {
  const CustomerBranchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.35,
            child: _buildCoverHeader(context),
          ),
          
          // Main Content
          Positioned.fill(
            top: MediaQuery.of(context).size.height * 0.3,
            child: _buildMainContent(context),
          ),
          
          // Custom App Bar Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: Navigator.canPop(context) 
                ? CircleAvatar(
                    backgroundColor: Colors.white,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black87),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomActions(context),
    );
  }

  Widget _buildCoverHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF3F0E6), // Light background behind image
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
           Image.network(
             'https://images.unsplash.com/photo-1545241047-6083a36cb1ce?auto=format&fit=crop&q=80',
             fit: BoxFit.cover,
           ),
           // Optional gradient overlay for text readability at top
           Positioned.fill(
             child: DecoratedBox(
               decoration: BoxDecoration(
                 gradient: LinearGradient(
                   begin: Alignment.topCenter,
                   end: Alignment.bottomCenter,
                   colors: [
                     Colors.black.withValues(alpha: 0.3),
                     Colors.transparent,
                   ],
                   stops: const [0.0, 0.3],
                 ),
               ),
             ),
           ),
        ],
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sucursal Principal',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 8, color: Colors.green),
                      SizedBox(width: 6),
                      Text(
                        'Abierto ahora',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '• Cierra a las 18:00',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            _buildMapSection(),

            const SizedBox(height: 32),
            _buildDetailRow(
              icon: Icons.location_on,
              title: 'Dirección',
              subtitle: 'Av. Paseo de la Reforma 250, Juárez, Cuauhtémoc, 06600 Ciudad de México, CDMX',
            ),
            const SizedBox(height: 24),
            _buildDetailRow(
              icon: Icons.turn_right,
              title: 'Referencias',
              subtitle: 'Local 4B, frente a la fuente de los leones. Portón negro con enredaderas.',
            ),
            
            const SizedBox(height: 32),
            const Row(
              children: [
                Icon(Icons.access_time, color: AppTheme.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'HORARIOS',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            _buildSchedulesCard(
              title: 'Atención en Tienda',
              icon: Icons.storefront,
              schedules: [
                _ScheduleItem('Lunes - Viernes', '09:00 - 18:00'),
                _ScheduleItem('Sábado', '10:00 - 14:00'),
                _ScheduleItem('Domingo', 'Cerrado', isClosed: true),
              ]
            ),
            const SizedBox(height: 16),
            _buildSchedulesCard(
              title: 'Entregas a Domicilio',
              icon: Icons.local_shipping,
              schedules: [
                _ScheduleItem('Lunes - Sábado', '08:00 - 20:00'),
              ]
            ),
             const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMapSection() {
    return Column(
      children: [
        Container(
          height: 160,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(16),
            image: const DecorationImage(
              image: NetworkImage('https://maps.googleapis.com/maps/api/staticmap?center=19.42847,-99.16766&zoom=15&size=600x300&maptype=roadmap&markers=color:red%7Clabel:S%7C19.42847,-99.16766&key=YOUR_API_KEY'),
              fit: BoxFit.cover,
            ),
          ),
          child: Stack(
            children: [
               // Placeholder for map image if we don't have an API key right now
               const Center(
                 child: Icon(Icons.map, size: 50, color: Colors.black12),
               ),
               // Label like Android Maps
               Positioned(
                 top: 12, left: 12,
                 child: Container(
                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                   decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                   child: const Text('Ampliar el mapa', style: TextStyle(color: Colors.blue, fontSize: 12)),
                 ),
               ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.open_in_new, size: 16, color: Colors.green),
              label: const Text('Ver en Google Maps', style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w600)),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.near_me, size: 16, color: Colors.grey),
              label: Text('Cómo llegar', style: TextStyle(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w600)),
               style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildDetailRow({required IconData icon, required String title, required String subtitle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.green, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildSchedulesCard({required String title, required IconData icon, required List<_ScheduleItem> schedules}) {
     return Container(
       padding: const EdgeInsets.all(20),
       decoration: BoxDecoration(
         color: const Color(0xFFF8F9FA),
         borderRadius: BorderRadius.circular(16),
       ),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
               Icon(icon, color: Colors.grey[500], size: 20),
             ],
           ),
           const SizedBox(height: 16),
           ...schedules.map((schedule) => Padding(
             padding: const EdgeInsets.only(bottom: 8.0),
             child: Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Text(schedule.day, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                 Text(
                   schedule.time,
                   style: TextStyle(
                     fontWeight: FontWeight.w500,
                     fontSize: 14,
                     color: schedule.isClosed ? Colors.redAccent : Colors.black87
                   ),
                 ),
               ],
             ),
           ))
         ],
       ),
     );
  }

  Widget _buildBottomActions(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.chat, color: Colors.white),
              label: const Text('Contactar por WhatsApp', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1ECA65), // WhatsApp Green
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                   height: 48,
                   child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.phone, color: AppTheme.primary, size: 18),
                    label: const Text('Llamar', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                   height: 48,
                   child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.email, color: AppTheme.primary, size: 18),
                    label: const Text('Correo', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                       side: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}

class _ScheduleItem {
  final String day;
  final String time;
  final bool isClosed;
  _ScheduleItem(this.day, this.time, {this.isClosed = false});
}
