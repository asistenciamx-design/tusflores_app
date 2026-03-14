import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../reviews/presentation/screens/review_form_screen.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String folio;

  const OrderTrackingScreen({super.key, required this.folio});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final _phoneController = TextEditingController();
  bool _verified = false;
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _order;

  // Decode URI-encoded folio (%23 -> #) so Supabase queries work correctly
  String get _folio => Uri.decodeComponent(widget.folio);

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final rawPhone = _phoneController.text.trim();
    if (rawPhone.isEmpty) {
      setState(() => _error = 'Ingresa tu número de WhatsApp');
      return;
    }

    // Normalize: strip everything except digits
    final phone = rawPhone.replaceAll(RegExp(r'\D'), '');

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Query order by folio; we'll match phone client-side to handle
      // stored numbers with/without country code.
      final results = await Supabase.instance.client
          .from('orders')
          .select(
              'folio, status, product_name, quantity, delivery_method, delivery_info, delivery_address, delivery_city, price, shipping_cost, recipient_name, shop_id, created_at')
          .eq('folio', _folio)
          .limit(5);

      if (results.isEmpty) {
        setState(() {
          _error = 'No encontramos un pedido con ese folio.';
          _loading = false;
        });
        return;
      }

      // Match phone: stored value vs entered value — both normalized
      Map<String, dynamic>? matched;
      for (final row in results) {
        // Also fetch customer_phone
        final full = await Supabase.instance.client
            .from('orders')
            .select('customer_phone')
            .eq('folio', _folio)
            .limit(1)
            .single();

        final storedPhone =
            ((full['customer_phone'] ?? '') as String).replaceAll(RegExp(r'\D'), '');

        // Accept if entered digits are a suffix of stored (handles country code diff)
        if (storedPhone.endsWith(phone) || phone.endsWith(storedPhone)) {
          matched = row;
          break;
        }
      }

      if (matched == null) {
        setState(() {
          _error = 'El número no coincide con el registrado en el pedido.';
          _loading = false;
        });
        return;
      }

      // Fetch shop name for display
      final shopId = matched['shop_id'] as String?;
      String shopName = 'Tu florería';
      if (shopId != null) {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('shop_name')
            .eq('id', shopId)
            .maybeSingle();
        shopName = (profile?['shop_name'] ?? 'Tu florería') as String;
      }
      matched['_shop_name'] = shopName;

      setState(() {
        _order = matched;
        _verified = true;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Ocurrió un error. Intenta de nuevo.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF6F0),
      body: SafeArea(
        child: _verified && _order != null
            ? _TrackingView(order: _order!, folio: _folio)
            : _VerifyView(
                folio: _folio,
                phoneController: _phoneController,
                loading: _loading,
                error: _error,
                onVerify: _verify,
              ),
      ),
    );
  }
}

// ── Verification step ──────────────────────────────────────────────────────

class _VerifyView extends StatelessWidget {
  final String folio;
  final TextEditingController phoneController;
  final bool loading;
  final String? error;
  final VoidCallback onVerify;

  const _VerifyView({
    required this.folio,
    required this.phoneController,
    required this.loading,
    required this.error,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo / icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFE91E8C).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_florist_rounded,
                  size: 40, color: Color(0xFFE91E8C)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Seguimiento de pedido',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E)),
            ),
            const SizedBox(height: 6),
            Text(
              'Folio: $folio',
              style: const TextStyle(fontSize: 15, color: Color(0xFF666680)),
            ),
            const SizedBox(height: 32),
            const Text(
              'Ingresa el número de WhatsApp con el que hiciste tu pedido para continuar.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF888899)),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Número de WhatsApp',
                hintText: 'Ej. 5512345678',
                prefixIcon:
                    const Icon(Icons.phone_rounded, color: Color(0xFFE91E8C)),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFFE91E8C), width: 2),
                ),
                errorText: error,
              ),
              onSubmitted: (_) => onVerify(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : onVerify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE91E8C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Ver mi pedido',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tracking timeline ──────────────────────────────────────────────────────

class _TrackingView extends StatelessWidget {
  final Map<String, dynamic> order;
  final String folio;

  const _TrackingView({required this.order, required this.folio});

  static const _stages = [
    _Stage('En espera', Icons.schedule_rounded, Color(0xFFF59E0B)),
    _Stage('Elaborando', Icons.spa_outlined, Color(0xFF3B82F6)),
    _Stage('En tránsito', Icons.local_shipping_outlined, Color(0xFF8B5CF6)),
    _Stage('Entregado', Icons.check_circle_rounded, Color(0xFF10B981)),
  ];

  static const _statusOrder = {
    'waiting': 0,
    'processing': 1,
    'in_transit': 2,
    'delivered': 3,
  };

  String _parseProductNames(dynamic productName) {
    if (productName == null) return 'Producto';
    try {
      final List<dynamic> list = jsonDecode(productName as String);
      return list.map((p) {
        final name = p['name'] as String? ?? 'Producto';
        final qty = p['qty'] as int? ?? 1;
        return qty > 1 ? '$qty x $name' : name;
      }).join(', ');
    } catch (_) {
      return productName.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawStatus = order['status'] as String? ?? 'waiting';
    final currentStep = _statusOrder[rawStatus] ?? 0;
    final shopName = order['_shop_name'] as String? ?? 'Tu florería';
    final isCancelled = rawStatus == 'cancelled';
    final isDelivered = rawStatus == 'delivered';

    final products = _parseProductNames(order['product_name']);
    final deliveryInfo = order['delivery_info'] as String? ?? '';
    final deliveryMethod = order['delivery_method'] as String? ?? '';
    final deliveryCity = order['delivery_city'] as String? ?? '';
    final price = (order['price'] as num?)?.toDouble() ?? 0;
    final shipping = (order['shipping_cost'] as num?)?.toDouble() ?? 0;
    final total = price + shipping;
    final recipientName = order['recipient_name'] as String? ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE91E8C).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_florist_rounded,
                    size: 24, color: Color(0xFFE91E8C)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shopName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF1A1A2E))),
                    Text('Folio $folio',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF888899))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Status banner
          if (isCancelled)
            _StatusBanner(
              label: 'Pedido cancelado',
              color: const Color(0xFFEF4444),
              icon: Icons.cancel_outlined,
            )
          else if (isDelivered)
            _StatusBanner(
              label: '¡Pedido entregado!',
              color: const Color(0xFF10B981),
              icon: Icons.check_circle_rounded,
            )
          else
            _StatusBanner(
              label: _stages[currentStep].label,
              color: _stages[currentStep].color,
              icon: _stages[currentStep].icon,
            ),

          const SizedBox(height: 28),

          // Timeline
          if (!isCancelled) ...[
            const Text('Estado del pedido',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF1A1A2E))),
            const SizedBox(height: 16),
            ...List.generate(_stages.length, (i) {
              final done = i <= currentStep;
              final active = i == currentStep;
              final isLast = i == _stages.length - 1;
              return _TimelineItem(
                stage: _stages[i],
                done: done,
                active: active,
                isLast: isLast,
              );
            }),
            const SizedBox(height: 28),
          ],

          // Order details card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Detalles del pedido',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF1A1A2E))),
                const SizedBox(height: 12),
                _DetailRow(icon: Icons.inventory_2_outlined,
                    label: 'Producto', value: products),
                if (recipientName.isNotEmpty)
                  _DetailRow(icon: Icons.person_outline_rounded,
                      label: 'Para', value: recipientName),
                _DetailRow(
                    icon: deliveryMethod == 'Recoger en tienda'
                        ? Icons.storefront_outlined
                        : Icons.local_shipping_outlined,
                    label: 'Entrega',
                    value: deliveryMethod),
                if (deliveryInfo.isNotEmpty)
                  _DetailRow(icon: Icons.calendar_today_outlined,
                      label: 'Fecha / Hora', value: deliveryInfo),
                if (deliveryCity.isNotEmpty)
                  _DetailRow(icon: Icons.location_on_outlined,
                      label: 'Ciudad', value: deliveryCity),
                _DetailRow(
                    icon: Icons.attach_money_rounded,
                    label: 'Total',
                    value: '\$${total.toStringAsFixed(2)} MXN'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // CTA: calificar cuando entregado
          if (isDelivered) ...[
            const SizedBox(height: 8),
            _RateOrderBanner(
              shopId: order['shop_id'] as String? ?? '',
              shopName: shopName,
              orderId: order['id'] as String?,
              customerName: order['recipient_name'] as String?,
            ),
            const SizedBox(height: 16),
          ],

          // Footer note
          const Center(
            child: Text(
              'Powered by TusFlores.app',
              style: TextStyle(fontSize: 12, color: Color(0xFFBBBBCC)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────

class _Stage {
  final String label;
  final IconData icon;
  final Color color;
  const _Stage(this.label, this.icon, this.color);
}

class _StatusBanner extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusBanner(
      {required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 17)),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final _Stage stage;
  final bool done;
  final bool active;
  final bool isLast;

  const _TimelineItem({
    required this.stage,
    required this.done,
    required this.active,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final Color nodeColor =
        done ? stage.color : const Color(0xFFDDDDEE);
    const lineColor = Color(0xFFE5E5F0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: circle + line
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: done ? nodeColor : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                    color: nodeColor,
                    width: active ? 2.5 : 1.5),
              ),
              child: Icon(stage.icon,
                  size: 16,
                  color: done ? Colors.white : nodeColor),
            ),
            if (!isLast)
              Container(
                  width: 2,
                  height: 36,
                  color: done ? nodeColor : lineColor),
          ],
        ),
        const SizedBox(width: 14),
        // Right: label
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            stage.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              color: done
                  ? const Color(0xFF1A1A2E)
                  : const Color(0xFFAAAAAA),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Rate order banner ──────────────────────────────────────────────────────

class _RateOrderBanner extends StatefulWidget {
  final String shopId;
  final String shopName;
  final String? orderId;
  final String? customerName;

  const _RateOrderBanner({
    required this.shopId,
    required this.shopName,
    this.orderId,
    this.customerName,
  });

  @override
  State<_RateOrderBanner> createState() => _RateOrderBannerState();
}

class _RateOrderBannerState extends State<_RateOrderBanner> {
  bool _alreadyRated = false;

  @override
  void initState() {
    super.initState();
    _checkAlreadyRated();
  }

  Future<void> _checkAlreadyRated() async {
    if (widget.orderId == null) return;
    try {
      final rows = await Supabase.instance.client
          .from('shop_reviews')
          .select('id')
          .eq('order_id', widget.orderId!)
          .limit(1);
      if (mounted && (rows as List).isNotEmpty) {
        setState(() => _alreadyRated = true);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_alreadyRated) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: 0.25)),
        ),
        child: const Row(
          children: [
            Icon(Icons.star_rounded, color: Color(0xFF10B981), size: 22),
            SizedBox(width: 10),
            Text('¡Gracias por tu reseña!',
                style: TextStyle(
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReviewFormScreen(
              shopId: widget.shopId,
              shopName: widget.shopName,
              orderId: widget.orderId,
              customerName: widget.customerName,
            ),
          ),
        );
        _checkAlreadyRated();
      },
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE91E8C), Color(0xFFFF6B9D)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE91E8C).withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.star_rounded, color: Colors.white, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('¿Cómo fue tu experiencia?',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                  SizedBox(height: 2),
                  Text('Déjanos una reseña, ¡nos ayuda mucho!',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }
}

// ── Detail row ──────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFFE91E8C)),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF888899))),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A2E))),
          ),
        ],
      ),
    );
  }
}
