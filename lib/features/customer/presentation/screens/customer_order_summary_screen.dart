import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../orders/domain/models/order_model.dart';
import '../../../orders/domain/repositories/order_repository.dart';
import '../../../profile/domain/models/shop_settings_model.dart';

class CustomerOrderSummaryScreen extends StatefulWidget {
  final OrderModel order;
  const CustomerOrderSummaryScreen({super.key, required this.order});

  @override
  State<CustomerOrderSummaryScreen> createState() =>
      _CustomerOrderSummaryScreenState();
}

class _CustomerOrderSummaryScreenState
    extends State<CustomerOrderSummaryScreen> {
  bool _isSaving = false;
  final _orderRepo = OrderRepository();
  final ScreenshotController _screenshotController = ScreenshotController();

  String _shopName = 'Cargando...';
  String _shopAddress = '';
  String _shopPhone = '';
  bool _isLoadingProfile = true;
  ShopSettingsModel? _shopSettings;

  @override
  void initState() {
    super.initState();
    _loadShopDetails();
  }

  Future<void> _loadShopDetails() async {
    try {
      final client = Supabase.instance.client;
      final futures = await Future.wait([
        client
            .from('profiles')
            .select('shop_name, whatsapp_number')
            .eq('id', widget.order.shopId)
            .maybeSingle(),
        client
            .from('shop_settings')
            .select('settings')
            .eq('shop_id', widget.order.shopId)
            .maybeSingle(),
      ]);

      final profile = futures[0];
      final settingsRow = futures[1];

      String name = 'Tu Florería';
      String pPhone = '';
      if (profile != null) {
        name = profile['shop_name'] ?? 'Tu Florería';
        pPhone = profile['whatsapp_number'] ?? '';
      }

      String address = '';
      if (settingsRow != null && settingsRow['settings'] != null) {
        final settings = settingsRow['settings'] as Map<String, dynamic>;
        _shopSettings = ShopSettingsModel.fromJson(settings);

        // Use the specifically configured catalog name if it exists (e.g., "Mercado Jamaica" instead of "mercado-jamaica")
        final catalogName =
            (settings['catalog_shop_name'] as String?)?.trim() ?? '';
        if (catalogName.isNotEmpty) {
          name = catalogName;
        }

        address = settings['address'] ?? '';
        final city = settings['city'] ?? '';
        final state = settings['state'] ?? '';

        List<String> parts = [];
        if (address.isNotEmpty) parts.add(address);
        if (city.isNotEmpty) parts.add(city);
        if (state.isNotEmpty) parts.add(state);
        address = parts.join(', ');

        // Use whatsapp from shop_settings if profile doesn't have one
        if (pPhone.isEmpty) {
          pPhone = (settings['whatsapp'] as String?) ?? '';
        }
      }

      if (mounted) {
        setState(() {
          _shopName = name;
          _shopAddress = address;
          _shopPhone = pPhone;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading shop details: $e');
      if (mounted) {
        setState(() {
          _shopName = 'Tu Florería';
          _shopAddress = '';
          _shopPhone = '';
          _isLoadingProfile = false;
        });
      }
    }
  }

  String _buildWhatsAppMessage() {
    final buffer = StringBuffer();
    buffer.writeln('*¡Hola $_shopName!* 💐');
    buffer.writeln(
        'Acabo de generar un nuevo pedido desde tu catálogo web. Aquí tienes los detalles:');
    buffer.writeln('\n*Folio:* ${widget.order.folio}');

    buffer.writeln('\n🛒 *PRODUCTOS:*');
    try {
      final List<dynamic> productsData = jsonDecode(widget.order.productName);
      for (var p in productsData) {
        final name = p['name'] as String? ?? 'Producto';
        final qty = p['qty'] as int? ?? 1;
        buffer.writeln('• $qty x $name');
      }
    } catch (e) {
      buffer
          .writeln('• ${widget.order.quantity} x ${widget.order.productName}');
    }

    final total = widget.order.price + widget.order.shippingCost;
    buffer.writeln('\n💰 *Total:* \$${total.toStringAsFixed(2)} MXN');
    buffer.writeln(
        '🚚 *Envío:* ${widget.order.shippingCost == 0.0 ? 'GRATIS' : '\$${widget.order.shippingCost.toStringAsFixed(2)}'}');

    buffer.writeln('\n👤 *DATOS DEL COMPRADOR*');
    buffer.writeln('Nombre: ${widget.order.customerName}');
    buffer.writeln('Teléfono: ${widget.order.customerPhone}');

    buffer.writeln('\n📦 *DETALLES DE ENTREGA*');
    buffer.writeln('Método: ${widget.order.deliveryMethod}');
    buffer.writeln('Fecha/Hora: ${widget.order.deliveryInfo}');
    if (widget.order.deliveryMethod != 'Recoger en tienda') {
      buffer.writeln(
          'Dirección: ${widget.order.deliveryAddress ?? 'No especificado'}');
      if (widget.order.deliveryReferences?.isNotEmpty == true) {
        buffer.writeln('Referencias: ${widget.order.deliveryReferences}');
      }
    }

    if (widget.order.dedicationMessage?.isNotEmpty == true) {
      buffer.writeln('\n💌 *DEDICATORIA:*');
      buffer.writeln('"${widget.order.dedicationMessage}"');
      if (widget.order.isAnonymous) {
        buffer.writeln('_(Enviar de forma anónima)_');
      }
    }

    if (_shopSettings != null) {
      final banks = _shopSettings!.bankMethods;
      final links = _shopSettings!.linkMethods;
      if (banks.isNotEmpty || links.isNotEmpty) {
        buffer.writeln('\n💳 *MÉTODOS DE PAGO DISPONIBLES*');
        if (banks.isNotEmpty) {
          buffer.writeln('\n🏦 *Transferencia bancaria*');
          for (final b in banks) {
            buffer.writeln('• ${b.bankName} (${b.accountType})');
            buffer.writeln('  Titular: ${b.holderName}');
            buffer.writeln('  Cuenta: ${b.accountNumber}');
            buffer.writeln('  CLABE: ${b.clabe}');
          }
        }
        if (links.isNotEmpty) {
          buffer.writeln('\n🔗 *Links de pago*');
          for (final l in links) {
            buffer.writeln('• ${l.serviceName}: https://${l.url}');
          }
        }
      }
    }

    buffer.writeln(
        '\n💡 Adjunto a este mensaje la imagen con el Resumen de mi Pedido.');
    return buffer.toString();
  }

  Future<void> _downloadImage() async {
    setState(() => _isSaving = true);
    try {
      final imageBytes = await _screenshotController.capture(
          delay: const Duration(milliseconds: 100));
      if (imageBytes != null) {
        final fileName = "pedido_tusflores_${DateTime.now().millisecondsSinceEpoch}.png";
        
        if (kIsWeb) {
          // Web download implementation
          final blob = html.Blob([imageBytes]);
          final url = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.AnchorElement(href: url)
            ..setAttribute("download", fileName)
            ..click();
          html.Url.revokeObjectUrl(url);
        } else {
          // Mobile download implementation
          await ImageGallerySaver.saveImage(
            imageBytes,
            quality: 100,
            name: fileName.replaceAll('.png', ''), // It appends extension automatically
          );
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Imagen guardada en tu galería'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error capturing screenshot: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar la imagen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveAndShare() async {
    setState(() => _isSaving = true);

    try {

      // 2. Save order to Supabase
      final newOrder = await _orderRepo.createOrder(widget.order);

      if (!mounted) return;

      if (newOrder != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Pedido registrado. Abriendo WhatsApp...'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // 3. Launch WhatsApp
        if (_shopPhone.isNotEmpty) {
          final cleanPhone = _shopPhone.replaceAll(RegExp(r'\D'), '');
          final text = Uri.encodeComponent(_buildWhatsAppMessage());
          final webWhatsAppUrl = Uri.parse('https://wa.me/$cleanPhone?text=$text');

          try {
            await launchUrl(webWhatsAppUrl, mode: LaunchMode.externalApplication);
          } catch (e) {
            debugPrint('Error launching WhatsApp: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No se pudo abrir WhatsApp.')),
              );
            }
          }
        }

        if (mounted) {
          // Return to the public catalog of the shop
          // We don't have the slug directly, but the routing is `/mx/:slug`.
          // To safely redirect the customer to the shop they were browsing, we can pop until the first route or push a clean state.
          // In GoRouter, a simple approach to go back to the top-level catalog is to pop.
          // However, since we might be a few screens deep (product -> form -> summary), 
          // a better way is to pop back to the catalog branch route.
          // For the public variant `/mx/:slug`, calling pop might just work if they came from there.
          if (context.canPop()) {
              // Pop back to order form
              context.pop();
              if (context.canPop()) {
                // Pop back to product details
                context.pop();
                if (context.canPop()) {
                    // Pop back to catalog
                    context.pop();
                }
              }
          } else {
             context.go('/'); 
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error al procesar el pedido'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error inesperado: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7), // Light grey background
      appBar: AppBar(
        title: const Text(
          'Resumen del Pedido',
          style: TextStyle(
              color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFFF4F5F7),
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: CircleAvatar(
            backgroundColor: Colors.white,
            radius: 18,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.black87, size: 20),
              onPressed: () => context.pop(),
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
      body: _isLoadingProfile
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Column(
                children: [
                  _buildTicket(context),
                  const SizedBox(height: 120), // Space for bottom buttons
                ],
              ),
            ),
      bottomSheet: Container(
        color: const Color(0xFFF4F5F7),
        padding: const EdgeInsets.all(20.0),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          _isSaving || _isLoadingProfile ? null : _saveAndShare,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676), // WhatsApp Greenish
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(double.infinity, 54),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text(
                              'Guardar y confirmar pedido',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 54, // Match button height
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: IconButton(
                      onPressed:
                          _isSaving || _isLoadingProfile ? null : _downloadImage,
                      icon: const Icon(Icons.download_rounded, color: Colors.black87),
                      tooltip: 'Descargar imagen',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTicket(BuildContext context) {
    return Screenshot(
      controller: _screenshotController,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header section
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFFFDFDFD),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFF00E676),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_florist,
                        color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _shopName,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  if (_shopAddress.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _shopAddress,
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('FOLIO ${widget.order.folio}',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                            color: Colors.blueGrey)),
                  ),
                ],
              ),
            ),

            _buildDashedLine(),

            // Shopping breakdown Section
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  ...() {
                    try {
                      // Try parsing productName as JSON. If successful it's an array of products
                      final List<dynamic> productsData =
                          jsonDecode(widget.order.productName);
                      return productsData.map((p) {
                        final name = p['name'] as String? ?? 'Producto';
                        final qty = p['qty'] as int? ?? 1;
                        final price = p['price'] as double? ?? 0.0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${qty}x',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                              ),
                              Text('\$${price.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                            ],
                          ),
                        );
                      }).toList();
                    } catch (e) {
                      // Fallback to legacy single product string
                      return [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${widget.order.quantity}x',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(widget.order.productName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14)),
                                ],
                              ),
                            ),
                            Text('\$${widget.order.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ];
                    }
                  }(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Envío (${widget.order.deliveryMethod})',
                          style: const TextStyle(
                              fontSize: 13, color: Colors.blueGrey)),
                      Text(
                          widget.order.shippingCost == 0.0
                              ? 'GRATIS'
                              : '\$${widget.order.shippingCost.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.blueGrey)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('TOTAL DEL PEDIDO',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.blueGrey)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                              '\$${(widget.order.price + widget.order.shippingCost).toStringAsFixed(2)} MXN',
                              style: const TextStyle(
                                  color: Color(0xFF00E676),
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold)),
                          Text('Incluye IVA si aplica',
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: _buildDashedLine(),
            ),

            // Remitente (Cliente) Section
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DATOS DE DESTINATARIO',
                      style: TextStyle(
                          color: Colors.blueGrey[400],
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 12),
                  _buildDataRow(Icons.person_pin, 'Quien recibe:',
                      widget.order.customerName),
                  const SizedBox(height: 8),
                  _buildDataRow(Icons.phone_iphone,
                      'Teléfono del destinatario:', widget.order.customerPhone),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: _buildDashedLine(),
            ),

            // Entrega / Destinatario Section
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DETALLES DE ENTREGA',
                      style: TextStyle(
                          color: Colors.blueGrey[400],
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 12),
                  _buildDataRow(Icons.local_shipping, 'Método:',
                      widget.order.deliveryMethod),
                  const SizedBox(height: 8),
                  _buildDataRow(Icons.calendar_today, 'Fecha/Hora:',
                      widget.order.deliveryInfo),
                  const SizedBox(height: 8),
                  if (widget.order.deliveryAddress?.isNotEmpty == true &&
                      widget.order.deliveryMethod != 'Recoger en tienda') ...[
                    _buildDataRow(Icons.location_on, 'Dirección:',
                        widget.order.deliveryAddress!),
                    const SizedBox(height: 8),
                  ],
                  if (widget.order.deliveryReferences?.isNotEmpty == true) ...[
                    _buildDataRow(Icons.map, 'Referencias:',
                        widget.order.deliveryReferences!),
                    const SizedBox(height: 8),
                  ],
                  _buildDataRow(
                    Icons.sticky_note_2,
                    'Dedicatoria:',
                    widget.order.dedicationMessage?.isEmpty == true
                        ? 'Sin dedicatoria'
                        : '"${widget.order.dedicationMessage}"',
                    isItalic:
                        widget.order.dedicationMessage?.isNotEmpty == true,
                  ),
                  if (widget.order.isAnonymous) ...[
                    const SizedBox(height: 8),
                    _buildDataRow(Icons.visibility_off, 'Aviso:',
                        'El envío se realizará de forma anónima.'),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(IconData icon, String label, String value,
      {bool isItalic = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.blueGrey[300], size: 16),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(color: Colors.blueGrey[500], fontSize: 12)),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDashedLine() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 5.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.grey[300]),
              ),
            );
          }),
        );
      },
    );
  }
}
