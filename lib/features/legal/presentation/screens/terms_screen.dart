// Copyright (c) 2024–2025 tusflores.app — Todos los derechos reservados.
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

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
          'Términos de Uso',
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
            title: 'tusflores.app — Términos de Uso',
            body:
                'Última actualización: marzo 2025\n\n'
                'Al acceder o usar tusflores.app, aceptas estos Términos de Uso. '
                'Si no estás de acuerdo, por favor no utilices la plataforma.',
          ),
          _Section(
            title: '1. Descripción del servicio',
            body:
                'tusflores.app es una plataforma tecnológica que permite a florerías '
                'gestionar sus pedidos, catálogo, clientes y operaciones de reparto, '
                'y a sus clientes finales realizar pedidos de arreglos florales en línea. '
                'tusflores.app actúa como intermediario tecnológico; la relación '
                'comercial principal se establece entre la florería y el cliente final.',
          ),
          _Section(
            title: '2. Uso de la plataforma',
            body:
                'Al usar tusflores.app te comprometes a:\n\n'
                '• Proporcionar información veraz y actualizada\n'
                '• No usar la plataforma para fines ilegales o fraudulentos\n'
                '• No intentar acceder a datos de otras florerías o usuarios\n'
                '• No reproducir, copiar ni distribuir el software o contenido '
                'de la plataforma sin autorización escrita',
          ),
          _Section(
            title: '3. Responsabilidad de las florerías',
            body:
                'Las florerías registradas son responsables de:\n\n'
                '• La veracidad de la información publicada en su tienda\n'
                '• El cumplimiento de los pedidos recibidos\n'
                '• El trato adecuado a sus clientes finales\n'
                '• El manejo responsable de los datos de sus clientes\n'
                '• El pago puntual del servicio contratado con tusflores.app',
          ),
          _Section(
            title: '4. Pedidos y pagos',
            body:
                'tusflores.app no procesa pagos entre clientes y florerías. '
                'Los métodos de pago son gestionados directamente por cada florería. '
                'tusflores.app no es responsable por disputas de pago, reembolsos '
                'o cancelaciones entre florerías y sus clientes.',
          ),
          _Section(
            title: '5. Propiedad intelectual',
            body:
                'Todo el software, diseño, código fuente, marca, logotipo y contenido '
                'de tusflores.app son propiedad exclusiva de tusflores.app y están '
                'protegidos por la Ley Federal del Derecho de Autor de México y '
                'tratados internacionales. Queda prohibida su reproducción o uso '
                'sin autorización escrita.',
          ),
          _Section(
            title: '6. Limitación de responsabilidad',
            body:
                'tusflores.app no garantiza la disponibilidad ininterrumpida del '
                'servicio y no será responsable por daños indirectos, pérdida de '
                'datos, lucro cesante o cualquier daño derivado del uso o '
                'imposibilidad de uso de la plataforma más allá de lo que '
                'establezca la ley aplicable.',
          ),
          _Section(
            title: '7. Suspensión y cancelación',
            body:
                'Nos reservamos el derecho de suspender o cancelar el acceso a '
                'cuentas que violen estos Términos, sin previo aviso en casos de '
                'fraude o actividad ilegal.',
          ),
          _Section(
            title: '8. Modificaciones',
            body:
                'Podemos modificar estos Términos en cualquier momento. La versión '
                'vigente estará siempre disponible en tusflores.app/terminos. '
                'El uso continuado de la plataforma tras la publicación de cambios '
                'constituye aceptación de los nuevos Términos.',
          ),
          _Section(
            title: '9. Ley aplicable',
            body:
                'Estos Términos se rigen por las leyes de los Estados Unidos '
                'Mexicanos. Cualquier controversia se someterá a los tribunales '
                'competentes de la Ciudad de México.',
          ),
          _Section(
            title: '10. Contacto',
            body: 'contacto@tusflores.app',
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
