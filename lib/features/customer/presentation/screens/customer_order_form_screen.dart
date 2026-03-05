import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../profile/domain/models/shop_settings_model.dart';
import '../../../profile/domain/repositories/shop_settings_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../orders/domain/models/order_model.dart';
import '../../../catalog/presentation/screens/catalog_screen.dart' show ProductItem;

class CustomerOrderFormScreen extends StatefulWidget {
  final ProductItem? product;
  const CustomerOrderFormScreen({super.key, this.product});

  @override
  State<CustomerOrderFormScreen> createState() => _CustomerOrderFormScreenState();
}

class _CustomerOrderFormScreenState extends State<CustomerOrderFormScreen> {
  // Main product quantity
  int _mainProductQty = 1;

  // Store additional products selected by the user
  final List<Map<String, dynamic>> _additionalProducts = [];

  // Dummy catalog data to pick from
  final List<Map<String, dynamic>> _catalogProducts = [
    {
      'name': 'Arreglo Girasoles',
      'price': 380.0,
      'image': 'https://images.unsplash.com/photo-1559564478-e54619d83df2?q=80&w=200&h=200&fit=crop',
    },
    {
      'name': 'Orquídea Blanca',
      'price': 600.0,
      'image': 'https://images.unsplash.com/photo-1596434446-dc68f1841e24?q=80&w=200&h=200&fit=crop',
    },
    {
      'name': 'Ramo de Rosas Rojas',
      'price': 450.0,
      'image': 'https://images.unsplash.com/photo-1562690868-60bbe7293e94?q=80&w=200&h=200&fit=crop',
    },
  ];

  // Date/Time state
  String _selectedDate = 'Hoy';
  String _selectedTime = 'Mañana';

  // Delivery method state
  String _deliveryMethod = 'Envío a domicilio';

  // Form controllers
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _isAnonymous = false;

  final _streetCtrl = TextEditingController();
  final _suburbCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  String? _selectedState;
  String? _selectedCity;
  double _shippingCost = 0.0;
  final _refCtrl = TextEditingController();
  final _mapsUrlCtrl = TextEditingController();
  String _deliveryLocationType = 'Casa';

  bool _isLoadingSettings = true;
  ShopSettingsModel? _settings;
  String? _shopId;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = Supabase.instance.client.auth.currentUser;
    _shopId = user?.id ?? '';
    final repo = ShopSettingsRepository();
    final settings = await repo.getSettings(_shopId!);

    if (mounted) {
      setState(() {
         _settings = settings;
         _isLoadingSettings = false;
         if (settings != null && settings.deliveryRanges.isNotEmpty) {
           _selectedTime = settings.deliveryRanges.first.label;
         }
      });
    }
  }

  List<String> get _availableStates {
    if (_settings == null) return [];
    return _settings!.shippingRates.map((r) => r.estado).whereType<String>().toSet().toList()..sort();
  }

  List<String> get _availableCities {
    if (_settings == null || _selectedState == null) return [];
    return _settings!.shippingRates.where((r) => r.estado == _selectedState).map((r) => r.ciudad).whereType<String>().toSet().toList()..sort();
  }

  void _updateShippingCost() {
    if (_settings != null && _selectedState != null && _selectedCity != null) {
      final rate = _settings!.shippingRates.firstWhere(
        (r) => r.estado == _selectedState && r.ciudad == _selectedCity,
        orElse: () => ShippingRate(costo: 0),
      );
      setState(() {
        _shippingCost = rate.costo;
      });
    } else {
      setState(() {
        _shippingCost = 0.0;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _messageCtrl.dispose();
    _streetCtrl.dispose();
    _suburbCtrl.dispose();
    _zipCtrl.dispose();
    _refCtrl.dispose();
    _mapsUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), // Very light grey / off-white app background
      appBar: AppBar(
        title: const Text(
          'Datos de Compra',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 16),
        ),
        backgroundColor: const Color(0xFFF9FAFB),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoadingSettings 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_mainProductQty > 0) _buildProductSummary(),
            if (_mainProductQty > 0 && _additionalProducts.isNotEmpty) const SizedBox(height: 12),
            if (_additionalProducts.isNotEmpty) ...[
              ..._additionalProducts.map((p) => _buildAdditionalProductItem(p)),
            ],
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: _showProductSelector,
                icon: const Icon(Icons.add, color: AppTheme.primary, size: 20),
                label: const Text('Agregar otro producto', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),
            
            _buildSectionTitle('Fecha de entrega'),
            const SizedBox(height: 12),
            _buildDateOptions(),
            const SizedBox(height: 24),
            
            _buildSectionTitle('Horario'),
            const SizedBox(height: 12),
            _buildTimeOptions(),
            const SizedBox(height: 24),

            _buildSectionTitle('Método de entrega'),
            const SizedBox(height: 12),
            _buildDeliveryMethods(),
            const SizedBox(height: 24),

            _buildSectionTitle('Datos para la tarjeta'),
            const SizedBox(height: 12),
            _buildRecipientData(),
            const SizedBox(height: 24),

            _buildSectionTitle('Dirección de Entrega'),
            const SizedBox(height: 12),
            _buildDeliveryAddress(),
            const SizedBox(height: 100), // padding for bottom button
          ],
        ),
      ),
      bottomSheet: Container(
        color: const Color(0xFFF9FAFB),
        padding: const EdgeInsets.all(16.0),
        child: SafeArea(
          child: ElevatedButton.icon(
             onPressed: () {
               // Simulate save and continue
               double basePrice = widget.product?.price ?? 700.0;
               double subtotal = basePrice * _mainProductQty;
               for (var p in _additionalProducts) {
                 subtotal += (p['price'] as double) * (p['quantity'] as int);
               }
               
               final order = OrderModel(
                 folio: '#0000',
                 shopId: _shopId ?? '', // Using currently loaded shopId
                 productName: widget.product?.name ?? (_additionalProducts.isEmpty ? 'Pedido' : 'Pedido Personalizado'),
                 customerName: _nameCtrl.text.isEmpty ? 'Cliente' : _nameCtrl.text,
                 customerPhone: _phoneCtrl.text,
                 quantity: _mainProductQty > 0 ? _mainProductQty : 1,
                 price: subtotal,
                 status: OrderStatus.pending,
                 createdAt: DateTime.now(),
                 saleDate: DateTime.now(), // Real parsing if needed
                 deliveryInfo: '$_selectedDate, $_selectedTime',
                 isPaid: false,
                 shippingCost: _deliveryMethod == 'Recoger en tienda' ? 0.0 : _shippingCost,
                 deliveryMethod: _deliveryMethod,
                 isAnonymous: _isAnonymous,
                 recipientName: _nameCtrl.text,
                 recipientPhone: _phoneCtrl.text,
                 dedicationMessage: _messageCtrl.text,
                 deliveryAddress: '${_streetCtrl.text}, ${_suburbCtrl.text}, ${_zipCtrl.text}, ${_selectedCity ?? ''}, ${_selectedState ?? ''}',
                 deliveryReferences: _refCtrl.text,
                 deliveryLocationType: _deliveryLocationType,
               );

               context.push('/shop/summary', extra: order);
             },
             icon: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 20),
             label: const Text(
               'Guardar y continuar',
               style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
    );
  }

  Widget _buildProductSummary() {
    final double basePrice = widget.product?.price ?? 1200.0;
    final double total = basePrice * _mainProductQty;
    final image = (widget.product?.imageUrls.isNotEmpty == true) 
        ? widget.product!.imageUrls.first 
        : 'https://lh3.googleusercontent.com/aida-public/AB6AXuB3E2VbL-G75lTtz3Z1_Tf84D_wL10x4tF6C-K0K00fO2n8l2yqT6t7sJcRbbN2uEqOEq9NxtgP0X9K_3y-PjQ4d0f_y9G0K2jQfN8oR1qE5k6Mv7H1r9b2rI5k9wE7T3iX2yB0pY1eU3gV8cT0bN4yR6G3fL2wT9jN6oV4iR9wJ7G9oE7Q8f2R9cE6jR4';
    final name = widget.product?.name ?? 'Ramo Amor Eterno';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
             child: Image.network(
               image,
               height: 50,
               width: 50,
               fit: BoxFit.cover,
               errorBuilder: (ctx, err, stack) => Container(
                 height: 50, width: 50, color: Colors.grey[200], child: const Icon(Icons.local_florist, color: Colors.grey),
               ),
             ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  '\$${total.toStringAsFixed(0)}',
                  style: const TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    if (_mainProductQty > 0) {
                      setState(() {
                        _mainProductQty--;
                      });
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Icon(_mainProductQty > 1 ? Icons.remove : Icons.delete_outline, size: 16, color: _mainProductQty > 1 ? Colors.black87 : Colors.redAccent),
                  ),
                ),
                Text('$_mainProductQty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _mainProductQty++;
                    });
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Icon(Icons.add, size: 16, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalProductItem(Map<String, dynamic> product) {
    final int qty = product['quantity'] ?? 1;
    final double price = product['price'];
    final double total = price * qty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              product['image'],
              height: 50,
              width: 50,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) => Container(
                height: 50, width: 50, color: Colors.grey[200], child: const Icon(Icons.image, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  '\$${total.toStringAsFixed(0)}',
                  style: const TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (qty > 1) {
                        product['quantity'] = qty - 1;
                      } else {
                        _additionalProducts.remove(product);
                      }
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Icon(qty > 1 ? Icons.remove : Icons.delete_outline, size: 16, color: qty > 1 ? Colors.black87 : Colors.redAccent),
                  ),
                ),
                Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      product['quantity'] = qty + 1;
                    });
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Icon(Icons.add, size: 16, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showProductSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Catálogo de productos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 8),
                  Text('Selecciona el producto que deseas agregar a este pedido.', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: _catalogProducts.length,
                      separatorBuilder: (context, index) => const Divider(height: 24),
                      itemBuilder: (context, index) {
                        final product = _catalogProducts[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              product['image'],
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stack) => Container(
                                height: 50, width: 50, color: Colors.grey[200], child: const Icon(Icons.local_florist, color: AppTheme.primary),
                              ),
                            ),
                          ),
                          title: Text(product['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text('\$${product['price'].toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold)),
                          trailing: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                final existingIdx = _additionalProducts.indexWhere((p) => p['name'] == product['name']);
                                if (existingIdx >= 0) {
                                  _additionalProducts[existingIdx]['quantity'] = (_additionalProducts[existingIdx]['quantity'] ?? 1) + 1;
                                } else {
                                  _additionalProducts.add({...product, 'quantity': 1});
                                }
                              });
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                              foregroundColor: AppTheme.primary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            child: const Text('Agregar'),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDateOptions() {
    return Row(
      children: [
        _buildPillButton(
          title: 'Hoy',
          isSelected: _selectedDate == 'Hoy',
          onTap: () => setState(() => _selectedDate = 'Hoy'),
        ),
        const SizedBox(width: 12),
        _buildPillButton(
          title: 'Mañana',
          isSelected: _selectedDate == 'Mañana',
          onTap: () => setState(() => _selectedDate = 'Mañana'),
        ),
        const SizedBox(width: 12),
        _buildPillButton(
          title: 'Otro',
          icon: Icons.calendar_today,
          isSelected: _selectedDate == 'Otro',
          onTap: () => setState(() => _selectedDate = 'Otro'),
        ),
      ],
    );
  }

  Widget _buildPillButton({required String title, IconData? icon, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00E676) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF00E676) : Colors.grey.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.black87),
              const SizedBox(width: 6),
            ],
            Text(
               title,
               style: TextStyle(
                 color: isSelected ? Colors.white : Colors.black87,
                 fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                 fontSize: 12,
               ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeOptions() {
    if (_settings == null || _settings!.deliveryRanges.isEmpty) {
      return const Text('No hay horarios configurados.', style: TextStyle(color: Colors.grey, fontSize: 13));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _settings!.deliveryRanges.map((range) {
          IconData icon = Icons.access_time;
          if (range.start.hour < 12) {
            icon = Icons.wb_sunny_outlined;
          } else if (range.start.hour < 18) {
            icon = Icons.wb_twilight_outlined;
          } else {
            icon = Icons.nights_stay_outlined;
          }

          return Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: SizedBox(
              width: 140,
              child: _buildTimeCard(
                id: range.label, // use label as id
                icon: icon,
                title: range.label,
                subtitle: range.timeLabel, // e.g. "08:00 - 13:00"
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

   Widget _buildTimeCard({
    required String id,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedTime == id;
    final colorBorder = isSelected ? const Color(0xFF00E676) : Colors.grey.withValues(alpha: 0.2);
    final bgColor = isSelected ? const Color(0xFF00E676).withValues(alpha: 0.05) : Colors.white;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTime = id;
        });
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorBorder, width: isSelected ? 1.5 : 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: isSelected ? const Color(0xFF00C853) : Colors.grey, size: 24),
                    const SizedBox(height: 8),
                    Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          if (isSelected)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF00E676),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(2),
                child: const Icon(Icons.check, color: Colors.white, size: 10),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDeliveryMethods() {
     return Column(
       children: [
          _buildDeliveryOption(
            id: 'Envío a domicilio',
            icon: Icons.local_shipping,
            title: 'Envío a domicilio',
          ),
          const SizedBox(height: 12),
          _buildDeliveryOption(
            id: 'Recoger en tienda',
            icon: Icons.storefront,
            title: 'Recoger en tienda',
          ),
       ],
     );
  }

  Widget _buildDeliveryOption({required String id, required IconData icon, required String title}) {
     final isSelected = _deliveryMethod == id;
     final colorBorder = isSelected ? const Color(0xFF00E676) : Colors.grey.withValues(alpha: 0.2);
     final bgColor = isSelected ? const Color(0xFF00E676).withValues(alpha: 0.05) : Colors.white;

     return GestureDetector(
       onTap: () => setState(() => _deliveryMethod = id),
       child: Container(
         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
         decoration: BoxDecoration(
           color: bgColor,
           borderRadius: BorderRadius.circular(12),
           border: Border.all(color: colorBorder, width: 1),
         ),
         child: Row(
           children: [
             Container(
               padding: const EdgeInsets.all(6),
               decoration: BoxDecoration(
                 color: isSelected ? const Color(0xFF00E676) : Colors.grey[400],
                 shape: BoxShape.circle,
               ),
               child: Icon(icon, color: Colors.white, size: 16),
             ),
             const SizedBox(width: 16),
             Expanded(
               child: Text(
                 title,
                 style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.black87),
               ),
             ),
             Icon(
               isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
               color: isSelected ? const Color(0xFF00E676) : Colors.grey[300],
             ),
           ],
         ),
       ),
     );
  }

  Widget _buildRecipientData() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         _buildInputLabel('Nombre de quien recibe'),
         _buildTextField(controller: _nameCtrl, hint: 'Ej. María Pérez'),
         const SizedBox(height: 16),
         
         _buildInputLabel('Teléfono destinatario'),
         _buildTextField(controller: _phoneCtrl, hint: 'Ej. 55 1234 5678', keyboardType: TextInputType.phone),
         const SizedBox(height: 16),

         Row(
           mainAxisAlignment: MainAxisAlignment.spaceBetween,
           children: [
             _buildInputLabel('Dedicatoria (Opcional)'),
             Text('0/150', style: TextStyle(color: Colors.grey[400], fontSize: 10)),
           ],
         ),
         _buildTextField(
           controller: _messageCtrl,
           hint: 'Escribe un mensaje bonito aquí...',
           maxLines: 4,
         ),
         const SizedBox(height: 16),

         Container(
           padding: const EdgeInsets.all(12),
           decoration: BoxDecoration(
             color: Colors.white,
             borderRadius: BorderRadius.circular(12),
             border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
           ),
           child: Row(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               SizedBox(
                 width: 20,
                 height: 20,
                 child: Checkbox(
                   value: _isAnonymous,
                   onChanged: (val) => setState(() => _isAnonymous = val ?? false),
                   activeColor: Colors.black87,
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                 ),
               ),
               const SizedBox(width: 12),
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     const Text('¿Enviar como anónimo?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                     const SizedBox(height: 2),
                     Text('No incluiremos tu nombre en la tarjeta del destinatario.', style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                   ],
                 ),
               ),
             ],
           ),
         ),
      ],
    );
  }

  Widget _buildDeliveryAddress() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.blueGrey, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ingresa los detalles de la ubicación de entrega.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildInputLabel('CALLE Y NÚMERO'),
          _buildTextField(controller: _streetCtrl, hint: 'Av. Reforma 222'),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputLabel('COLONIA / BARRIO'),
                    _buildTextField(controller: _suburbCtrl, hint: 'Col. Juárez'),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputLabel('CÓDIGO POSTAL'),
                    _buildTextField(controller: _zipCtrl, hint: '06600', keyboardType: TextInputType.number),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildDropdown('ESTADO / PROVINCIA / DEPARTAMENTO', _availableStates, _selectedState, (val) {
            setState(() {
              _selectedState = val;
              _selectedCity = null;
              _updateShippingCost();
            });
          }, hint: 'Seleccionar estado...'),
          const SizedBox(height: 16),

          _buildDropdown('CIUDAD / MUNICIPIO', _availableCities, _selectedCity, (val) {
            setState(() {
              _selectedCity = val;
              _updateShippingCost();
            });
          }, hint: 'Seleccionar ciudad...'),
          const SizedBox(height: 16),

          _buildInputLabel('REFERENCIAS ADICIONALES'),
          _buildTextField(controller: _refCtrl, hint: 'Ej. Edificio blanco, dejar en recepción', maxLines: 2),
          const SizedBox(height: 16),

          _buildInputLabel('URL GOOGLE MAPS'),
          _buildTextField(
            controller: _mapsUrlCtrl,
            hint: 'Ej. https://maps.app.goo.gl/...',
            keyboardType: TextInputType.url,
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.copy, size: 20, color: Colors.grey),
                  onPressed: () {
                    if (_mapsUrlCtrl.text.isNotEmpty) {
                      Clipboard.setData(ClipboardData(text: _mapsUrlCtrl.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('URL copiada al portapapeles', style: TextStyle(color: Colors.white)),
                          backgroundColor: Colors.black87,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.clear, size: 20, color: Colors.grey),
                  onPressed: () => _mapsUrlCtrl.clear(),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _buildInputLabel('Lugar de entrega:', baseLabel: true),
          const SizedBox(height: 12),
          
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
               _buildLocationTypeBtn('Casa', Icons.home),
               _buildLocationTypeBtn('Edificio', Icons.business),
               _buildLocationTypeBtn('Fracc.', Icons.holiday_village),
               _buildLocationTypeBtn('Empresa', Icons.domain),
               _buildLocationTypeBtn('Funeraria', Icons.church), // Placeholders
               _buildLocationTypeBtn('Hospital', Icons.local_hospital),
             ],
          ),
          const SizedBox(height: 32),
          _buildOrderTotals(),
        ],
      ),
    );
  }

  Widget _buildLocationTypeBtn(String id, IconData icon) {
     final isSelected = _deliveryLocationType == id;
     const activeColor = Color(0xFF00E676);
     
     return GestureDetector(
       onTap: () => setState(() => _deliveryLocationType = id),
       child: Container(
         width: 65,
         padding: const EdgeInsets.symmetric(vertical: 8),
         decoration: BoxDecoration(
           color: isSelected ? activeColor.withValues(alpha: 0.05) : Colors.white,
           borderRadius: BorderRadius.circular(8),
           border: Border.all(color: isSelected ? activeColor : Colors.grey.withValues(alpha: 0.2)),
         ),
         child: Column(
           children: [
             Icon(icon, size: 20, color: isSelected ? activeColor : Colors.blueGrey),
             const SizedBox(height: 4),
             Text(id, style: TextStyle(fontSize: 9, color: isSelected ? activeColor : Colors.grey[600], fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
           ],
         ),
       ),
     );
  }

  Widget _buildInputLabel(String text, {bool baseLabel = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: baseLabel ? 12 : 9,
          fontWeight: FontWeight.bold,
          color: baseLabel ? Colors.black87 : Colors.grey[500],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? value, ValueChanged<String?> onChanged, {String hint = ''}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputLabel(label),
        DropdownButtonFormField<String>(
          initialValue: value != null && items.contains(value) ? value : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF00E676)),
            ),
          ),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          onChanged: onChanged,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
        ),
      ],
    );
  }

  Widget _buildOrderTotals() {
    double subtotal = 0;
    if (_mainProductQty > 0) {
      subtotal += 700.0 * _mainProductQty; 
    }
    for (var p in _additionalProducts) {
      subtotal += (p['price'] as double) * (p['quantity'] as int);
    }

    double effectiveShippingCost = _deliveryMethod == 'Recoger en tienda' ? 0.0 : _shippingCost;
    double total = subtotal + effectiveShippingCost;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal:', style: TextStyle(color: Colors.grey, fontSize: 14)),
              Text('\$${subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_selectedCity != null && _deliveryMethod != 'Recoger en tienda' ? 'Costo de envío $_selectedCity:' : 'Costo de envío:', style: const TextStyle(color: Colors.grey, fontSize: 14)),
              Text('\$${effectiveShippingCost.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF00E676)),
        ),
      ),
    );
  }
}
