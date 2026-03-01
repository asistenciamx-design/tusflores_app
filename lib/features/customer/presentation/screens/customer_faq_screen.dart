import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

class CustomerFaqScreen extends StatelessWidget {
  const CustomerFaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFDFA), // Very light greenish-grey background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => context.pop(),
              )
            : null,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildContactCard(context),
            const SizedBox(height: 32),
            _buildSectionTitle('PREGUNTAS FRECUENTES'),
            const SizedBox(height: 16),
            _buildFaqList(),
            const SizedBox(height: 48),
            _buildSectionTitle('SÍGUENOS EN REDES'),
            const SizedBox(height: 24),
            _buildSocialLinks(),
            const SizedBox(height: 32),
            _buildFooterPill(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFFE5F7ED), // Light green circle
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.local_florist, color: AppTheme.primary, size: 32),
        ),
        const SizedBox(height: 16),
        const Text(
          'Florería Las Rosas',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 4),
        const Text(
          'CENTRO DE AYUDA',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildContactCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Contacto Directo',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          Text(
            '¿Necesitas ayuda con tu pedido actual?\nNuestro equipo está listo para asistirte.',
            style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.4),
          ),
          const SizedBox(height: 24),
          
          // Action Buttons
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.chat, size: 20),
              label: const Text('Chat por WhatsApp', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1ECA65), // Vibrant WhatsApp green
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          SizedBox(
             width: double.infinity,
             height: 52,
             child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.phone, size: 20, color: AppTheme.primary),
              label: const Text('Llamar a sucursal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey[200]!),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/shop/payment-methods'),
              icon: const Icon(Icons.payment, size: 20),
              label: const Text('Formas de Pago', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEEFBF4), // Very light green
                foregroundColor: AppTheme.primary, // Dark green text
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
           style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF6B9A84), // Muted green text
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
  
  Widget _buildFaqList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          _buildFaqItem(
            icon: Icons.local_shipping,
            question: '¿Hacen entregas el mismo día?',
            answer: 'Sí, contamos con entregas el mismo día si realizas tu pedido antes de las 2:00 PM. Válido solo en zonas con cobertura.',
          ),
          const SizedBox(height: 12),
           _buildFaqItem(
            icon: Icons.payments,
            question: '¿Cuáles son los métodos de pago?',
            answer: 'Aceptamos transferencias SPEI, tarjetas de crédito/débito y pagos en efectivo en tiendas de conveniencia.',
          ),
          const SizedBox(height: 12),
          _buildFaqItem(
            icon: Icons.palette,
            question: '¿Puedo personalizar mi ramo?',
            answer: 'Por supuesto. Puedes contactarnos por WhatsApp para indicarnos flores o colores específicos y armaremos algo especial.',
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem({required IconData icon, required String question, required String answer}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
           BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Theme(
        data: ThemeData().copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFFEEFBF4),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.primary, size: 20),
          ),
          title: Text(
            question,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87),
          ),
          iconColor: Colors.grey[400],
          collapsedIconColor: Colors.grey[400],
          childrenPadding: const EdgeInsets.fromLTRB(64, 0, 24, 20),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(answer, style: TextStyle(color: Colors.grey[600], height: 1.5, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialLinks() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSocialIcon(Icons.camera_alt_outlined, 'Instagram'), // Fallback icon for IG
        const SizedBox(width: 32),
        _buildSocialIcon(Icons.facebook, 'Facebook'),
      ],
    );
  }

  Widget _buildSocialIcon(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
               BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, 4),
              )
            ],
          ),
          child: Icon(icon, size: 28, color: Colors.black87),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        )
      ],
    );
  }

  Widget _buildFooterPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEEFBF4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: AppTheme.primary),
          SizedBox(width: 8),
          Text(
            'Estamos para servirte de 9am a 7pm',
            style: TextStyle(color: Color(0xFF6B9A84), fontSize: 13, fontWeight: FontWeight.w500),
          )
        ],
      ),
    );
  }
}
