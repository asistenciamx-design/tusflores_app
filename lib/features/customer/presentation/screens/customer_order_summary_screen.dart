import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../orders/domain/models/order_model.dart';
import '../../../orders/domain/repositories/order_repository.dart';

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

  String _shopName = 'Cargando...';
  String _shopAddress = '';
  bool _isLoadingProfile = true;

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
            .select('shop_name, full_name, address')
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
      String pAddress = '';
      if (profile != null) {
        // full_name contains the actual commercial name from the form
        // shop_name contains the URL slug
        name = profile['full_name'] ?? profile['shop_name'] ?? 'Tu Florería';
        pAddress = profile['address'] ?? '';
      }

      String address = '';
      if (settingsRow != null && settingsRow['settings'] != null) {
        final settings = settingsRow['settings'] as Map<String, dynamic>;

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
      }
      if (address.isEmpty) address = pAddress;

      if (mounted) {
        setState(() {
          _shopName = name;
          _shopAddress = address;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading shop details: $e');
      if (mounted) {
        setState(() {
          _shopName = 'Tu Florería';
          _shopAddress = '';
          _isLoadingProfile = false;
        });
      }
    }
  }

  Future<void> _saveAndShare() async {
    setState(() => _isSaving = true);

    final newOrder = await _orderRepo.createOrder(widget.order);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (newOrder != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Pedido registrado. Abriendo WhatsApp...'),
            backgroundColor: Colors.green),
      );
      // Here usually launchUrl for WhatsApp
      context.go('/');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Error al enviar pedido'),
            backgroundColor: Colors.red),
      );
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
              ElevatedButton(
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTicket(BuildContext context) {
    return Container(
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
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                            ),
                            Text('\$${price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
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
                Text('DATOS DEL CLIENTE',
                    style: TextStyle(
                        color: Colors.blueGrey[400],
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
                const SizedBox(height: 12),
                _buildDataRow(Icons.person_pin, 'Quien compra:',
                    widget.order.customerName),
                const SizedBox(height: 8),
                _buildDataRow(Icons.phone_iphone, 'Teléfono del cliente:',
                    widget.order.customerPhone),
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
                if (widget.order.deliveryMethod != 'Recoger en tienda') ...[
                  _buildDataRow(Icons.person, 'Para:',
                      widget.order.recipientName ?? 'No especificado'),
                  const SizedBox(height: 8),
                  _buildDataRow(Icons.phone, 'Teléfono destinatario:',
                      widget.order.recipientPhone ?? 'No especificado'),
                  const SizedBox(height: 8),
                ],
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
                  isItalic: widget.order.dedicationMessage?.isNotEmpty == true,
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
