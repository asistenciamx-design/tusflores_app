// Copyright (c) 2024–2025 tusflores.app — Todos los derechos reservados.
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text(
          'Política de Privacidad',
          style: TextStyle(
            color: AppTheme.textLight,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          _Section(
            title: 'tusflores.app — Política de Privacidad',
            body:
                'Última actualización: marzo 2025\n\n'
                'En tusflores.app nos tomamos muy en serio la privacidad de los datos '
                'personales de nuestros usuarios. Esta Política describe qué datos '
                'recopilamos, cómo los usamos y los derechos que tienes sobre ellos, '
                'de conformidad con la Ley Federal de Protección de Datos Personales '
                'en Posesión de los Particulares (LFPDPPP) de México.',
          ),
          _Section(
            title: '1. Responsable del tratamiento',
            body:
                'tusflores.app es el responsable del tratamiento de tus datos '
                'personales. Para consultas sobre privacidad puedes contactarnos en:\n\n'
                'contacto@tusflores.app',
          ),
          _Section(
            title: '2. Datos que recopilamos',
            body:
                'Al usar tusflores.app podemos recopilar los siguientes datos:\n\n'
                '• Nombre completo\n'
                '• Número de teléfono y/o WhatsApp\n'
                '• Correo electrónico\n'
                '• Dirección de entrega\n'
                '• Información del pedido (productos, montos, fechas)\n'
                '• Datos del destinatario del arreglo floral\n\n'
                'No recopilamos datos de tarjetas de crédito ni información '
                'financiera sensible. Los pagos se gestionan directamente entre '
                'el cliente y la florería.',
          ),
          _Section(
            title: '3. Finalidad del tratamiento',
            body:
                'Tus datos se utilizan exclusivamente para:\n\n'
                '• Procesar y gestionar tu pedido de flores\n'
                '• Coordinar la entrega con la florería\n'
                '• Enviarte confirmación y seguimiento de tu pedido\n'
                '• Permitirte dejar una reseña sobre tu experiencia\n'
                '• Cumplir con obligaciones legales aplicables',
          ),
          _Section(
            title: '4. Compartición de datos',
            body:
                'Tus datos personales se comparten únicamente con la florería a '
                'quien realizaste el pedido, para que pueda procesarlo y entregarlo. '
                'No vendemos ni cedemos tus datos a terceros con fines comerciales.',
          ),
          _Section(
            title: '5. Conservación de datos',
            body:
                'Conservamos tus datos durante el tiempo necesario para cumplir con '
                'las finalidades descritas y con las obligaciones legales vigentes, '
                'o hasta que ejercites tu derecho de supresión.',
          ),
          _Section(
            title: '6. Tus derechos (ARCO)',
            body:
                'Tienes derecho a Acceder, Rectificar, Cancelar u Oponerte al '
                'tratamiento de tus datos personales (derechos ARCO). Para ejercerlos, '
                'envía un correo a contacto@tusflores.app indicando tu nombre, los '
                'datos que deseas gestionar y una copia de tu identificación oficial.',
          ),
          _Section(
            title: '7. Seguridad',
            body:
                'Implementamos medidas técnicas y organizativas para proteger tus '
                'datos frente a accesos no autorizados, pérdida o alteración, '
                'incluyendo cifrado en tránsito (HTTPS), control de acceso por roles '
                'y políticas de seguridad a nivel de base de datos.',
          ),
          _Section(
            title: '8. Cambios a esta política',
            body:
                'Podemos actualizar esta Política ocasionalmente. La versión vigente '
                'siempre estará disponible en tusflores.app/privacidad. Te notificaremos '
                'cambios relevantes a través de la plataforma.',
          ),
          SizedBox(height: 32),
          Center(
            child: Text(
              '© 2024–2025 tusflores.app',
              style: TextStyle(fontSize: 12, color: AppTheme.mutedLight),
            ),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;

  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.mutedLight,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
