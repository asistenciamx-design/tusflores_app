import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../orders/domain/models/order_model.dart';
import '../../../orders/domain/repositories/order_repository.dart';

class CustomerOrderSummaryScreen extends StatefulWidget {
  final OrderModel order;
  const CustomerOrderSummaryScreen({super.key, required this.order});

  @override
  State<CustomerOrderSummaryScreen> createState() => _CustomerOrderSummaryScreenState();
}

class _CustomerOrderSummaryScreenState extends State<CustomerOrderSummaryScreen> {
  bool _isSaving = false;
  final _orderRepo = OrderRepository();

  Future<void> _saveAndShare() async {
    setState(() => _isSaving = true);
    
    final newOrder = await _orderRepo.createOrder(widget.order);
    
    if (!mounted) return;
    setState(() => _isSaving = false);
    
    if (newOrder != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pedido registrado. Abriendo WhatsApp...'), backgroundColor: Colors.green),
      );
      // Here usually launchUrl for WhatsApp
      context.go('/');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al enviar pedido'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7), // Light grey background
      appBar: AppBar(
        title: const Text(
          'Vista Previa',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
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
              ElevatedButton.icon(
                 onPressed: _isSaving ? null : _saveAndShare,
                 icon: _isSaving
                     ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                     : const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 20),
                 label: Text(
                   _isSaving ? 'Enviando...' : 'Compartir por WhatsApp',
                   style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                 ),
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
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                 onPressed: () => context.pop(),
                 icon: const Icon(Icons.close, color: Colors.black87, size: 20),
                 label: const Text(
                   'Cerrar',
                   style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                 ),
                 style: OutlinedButton.styleFrom(
                   backgroundColor: Colors.white,
                   foregroundColor: Colors.black87,
                   side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                   padding: const EdgeInsets.symmetric(vertical: 16),
                   minimumSize: const Size(double.infinity, 54),
                   shape: RoundedRectangleBorder(
                     borderRadius: BorderRadius.circular(12),
                   ),
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
                color: Color(0xFFFDFDFD), // Very slight variation if needed, or white
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
                     child: const Icon(Icons.local_florist, color: Colors.white, size: 32),
                   ),
                   const SizedBox(height: 16),
                   const Text(
                     'Florería Las Rosas',
                     style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                   ),
                   const SizedBox(height: 4),
                   Text(
                     'Av. Reforma 123, CDMX',
                     style: TextStyle(color: Colors.grey[500], fontSize: 13),
                   ),
                   const SizedBox(height: 16),
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                     decoration: BoxDecoration(
                       border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                       borderRadius: BorderRadius.circular(20),
                     ),
                     child: const Text('FOLIO #0045', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.blueGrey)),
                   ),
                ],
              ),
            ),
            
            _buildDashedLine(),

             // Items Section
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Text('Fecha de entrega', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                       Text(widget.order.deliveryInfo, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                     ],
                   ),
                   const SizedBox(height: 20),
                   Row(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text('${widget.order.quantity}x', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                       const SizedBox(width: 8),
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text(widget.order.productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                           ],
                         ),
                       ),
                       Text('\$${widget.order.price.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                     ],
                   ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: _buildDashedLine(), // Using custom dashed line separator
            ),

            // Total Section
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     crossAxisAlignment: CrossAxisAlignment.end,
                     children: [
                        const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                             Text('\$${(widget.order.price + widget.order.shippingCost).toStringAsFixed(2)} MXN', style: const TextStyle(color: Color(0xFF00E676), fontSize: 24, fontWeight: FontWeight.bold)),
                             Text('Incluye IVA', style: TextStyle(color: Colors.grey[400], fontSize: 10)),
                          ],
                        ),
                     ],
                   ),
                   const SizedBox(height: 24),
                   
                   // Info Cards
                   Container(
                     padding: const EdgeInsets.all(16),
                     decoration: BoxDecoration(
                       border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                       borderRadius: BorderRadius.circular(12),
                     ),
                     child: Row(
                       children: [
                         Container(
                           padding: const EdgeInsets.all(8),
                           decoration: BoxDecoration(
                             color: const Color(0xFF00E676).withValues(alpha: 0.1),
                             shape: BoxShape.circle,
                           ),
                           child: const Icon(Icons.payments_outlined, color: Color(0xFF00C853), size: 18),
                         ),
                         const SizedBox(width: 16),
                         Expanded(
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Text('MÉTODO DE PAGO', style: TextStyle(color: Colors.blueGrey[400], fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                               const SizedBox(height: 2),
                               const Text('Efectivo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                             ],
                           ),
                         ),
                         const Icon(Icons.check_circle, color: Color(0xFF00E676), size: 20),
                       ],
                     ),
                   ),
                   const SizedBox(height: 12),
                   Container(
                     padding: const EdgeInsets.all(16),
                     decoration: BoxDecoration(
                       border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                       borderRadius: BorderRadius.circular(12),
                     ),
                     child: Row(
                       children: [
                         Container(
                           padding: const EdgeInsets.all(8),
                           decoration: BoxDecoration(
                             color: const Color(0xFF00E676).withValues(alpha: 0.1),
                             shape: BoxShape.circle,
                           ),
                           child: const Icon(Icons.phone_android, color: Color(0xFF00C853), size: 18),
                         ),
                         const SizedBox(width: 16),
                         Expanded(
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Text('TELÉFONO PERSONA DESTINATARIA', style: TextStyle(color: Colors.blueGrey[400], fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                               const SizedBox(height: 2),
                               Text(widget.order.recipientPhone ?? 'Sin teléfono', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                             ],
                           ),
                         ),
                       ],
                     ),
                   ),
                ],
              ),
            ),

            Padding(
               padding: const EdgeInsets.symmetric(horizontal: 24.0),
               child: _buildDashedLine(),
            ),

            // Delivery Details Section
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DETALLES DE ENTREGA', style: TextStyle(color: Colors.blueGrey[400], fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.person, color: Colors.blueGrey[300], size: 16),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Para:', style: TextStyle(color: Colors.blueGrey[400], fontSize: 12)),
                            const SizedBox(height: 2),
                            Text(widget.order.recipientName ?? 'N/A', style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                   Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.sticky_note_2, color: Colors.blueGrey[300], size: 16),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Dedicatoria:', style: TextStyle(color: Colors.blueGrey[400], fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              widget.order.dedicationMessage?.isEmpty == true ? 'Sin dedicatoria' : '"${widget.order.dedicationMessage}"', 
                              style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            _buildDashedLine(),

            // Footer Text
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Este es un comprobante digital generado\npara tu comodidad.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[400], fontSize: 11),
              ),
            ),
         ],
       ),
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
