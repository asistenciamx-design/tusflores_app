import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../profile/domain/models/shop_settings_model.dart';
import '../../../profile/domain/repositories/shop_settings_repository.dart';
import '../../../catalog/domain/repositories/product_repository.dart';
import '../../../orders/domain/models/order_model.dart';
import '../../../catalog/presentation/screens/catalog_screen.dart'
    show ProductItem;

class CustomerOrderFormScreen extends StatefulWidget {
  final ProductItem? product;
  final String? shopId;
  final List<Map<String, dynamic>>? giftProducts;
  const CustomerOrderFormScreen(
      {super.key, this.product, this.shopId, this.giftProducts});

  @override
  State<CustomerOrderFormScreen> createState() =>
      _CustomerOrderFormScreenState();
}

class _CustomerOrderFormScreenState extends State<CustomerOrderFormScreen> {
  // Main product quantity
  int _mainProductQty = 1;

  // Store additional products selected by the user
  final List<Map<String, dynamic>> _additionalProducts = [];

  // Gift products selected before checkout (passed from product detail screen)
  late final List<Map<String, dynamic>> _giftProducts;

  // Actual catalog data to pick from
  List<ProductItem> _catalogProducts = [];

  // Date/Time state — empty means the user hasn't picked one yet
  String _selectedDate = '';
  String _selectedTime = '';

  // Delivery method state
  String _deliveryMethod = 'Envío a domicilio';

  // Form controllers
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _isAnonymous = false;

  // Buyer data (CRM)
  final _buyerNameCtrl = TextEditingController();
  final _buyerWhatsappCtrl = TextEditingController();
  final _buyerEmailCtrl = TextEditingController();

  final _streetCtrl = TextEditingController();
  final _suburbCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  String? _selectedState;
  String? _selectedCity;
  double _shippingCost = 0.0;
  final _refCtrl = TextEditingController();
  final _locationDetailsCtrl = TextEditingController();
  String _deliveryLocationType = 'Casa';

  static const _locationHints = {
    'Casa':      'Las entre calles facilitan la entrega',
    'Edificio':  'Número o letra de edificio, piso, departamento',
    'Fracc.':    'Nombre del fraccionamiento, número de casa o edificio, piso',
    'Empresa':   'Área, piso, oficina, extensión',
    'Funeraria': 'Número de sala de velación, piso, nombre del finado, '
                 'hora de inicio del servicio, nombre de familiar o amigo que puede recibir',
    'Hospital':  'Piso, habitación, nombre de familiar',
  };

  bool _isLoadingSettings = true;
  ShopSettingsModel? _settings;

  // ── Draft persistence ─────────────────────────────────────────────────────
  Timer? _draftTimer;
  SharedPreferences? _prefs;

  String get _draftKey =>
      'order_draft_${widget.shopId ?? 'unknown'}_${widget.product?.id ?? 'generic'}';

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    // Auto-save on every state change once prefs are ready
    if (_prefs != null) _scheduleSave();
  }

  @override
  void initState() {
    super.initState();
    _giftProducts = List<Map<String, dynamic>>.from(widget.giftProducts ?? []);
    // Init prefs first, then load data (which will restore the draft at the end)
    SharedPreferences.getInstance().then((prefs) {
      _prefs = prefs;
      _loadData();
    });
    // Save whenever the user types in any text field
    for (final ctrl in [
      _nameCtrl, _phoneCtrl, _messageCtrl,
      _buyerNameCtrl, _buyerWhatsappCtrl, _buyerEmailCtrl,
      _streetCtrl, _suburbCtrl, _zipCtrl, _refCtrl, _locationDetailsCtrl,
    ]) {
      ctrl.addListener(_scheduleSave);
    }
  }

  Future<void> _loadData() async {
    if (widget.shopId == null || widget.shopId!.isEmpty) {
      if (mounted) {
        setState(() => _isLoadingSettings = false);
      }
      return;
    }

    try {
      final settingsRepo = ShopSettingsRepository();
      final productRepo = ProductRepository();

      final results = await Future.wait([
        settingsRepo.getSettings(widget.shopId!),
        productRepo.getPublicProducts(widget.shopId!),
      ]);

      final settings = results[0] as ShopSettingsModel?;
      final productsRaw = results[1] as List<Map<String, dynamic>>;

      if (mounted) {
        setState(() {
          _settings = settings;
          _catalogProducts = productsRaw
              .map((p) => ProductItem.fromJson(p))
              .where((p) =>
                  p.id !=
                  widget.product?.id) // Don't show the main product as an extra
              .toList();

          _isLoadingSettings = false;
          // Do NOT pre-select a time — user must choose actively
        });
        // Restore saved draft AFTER settings are loaded so state/city dropdowns
        // have their available values and shipping cost can be re-calculated.
        _restoreDraft();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSettings = false);
      }
    }
  }

  List<String> get _availableStates {
    if (_settings == null) return [];
    return _settings!.shippingRates
        .map((r) => r.estado)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
  }

  List<String> get _availableCities {
    if (_settings == null || _selectedState == null) return [];
    return _settings!.shippingRates
        .where((r) => r.estado == _selectedState)
        .map((r) => r.ciudad)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
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
    _draftTimer?.cancel();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _messageCtrl.dispose();
    _buyerNameCtrl.dispose();
    _buyerWhatsappCtrl.dispose();
    _buyerEmailCtrl.dispose();
    _streetCtrl.dispose();
    _suburbCtrl.dispose();
    _zipCtrl.dispose();
    _refCtrl.dispose();
    _locationDetailsCtrl.dispose();
    super.dispose();
  }

  // ── Draft helpers ─────────────────────────────────────────────────────────

  void _scheduleSave() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 500), _saveDraft);
  }

  void _saveDraft() {
    if (_prefs == null || !mounted) return;
    _prefs!.setString(
      _draftKey,
      jsonEncode({
        '_savedAt': DateTime.now().millisecondsSinceEpoch,
        'name': _nameCtrl.text,
        'phone': _phoneCtrl.text,
        'message': _messageCtrl.text,
        'buyerName': _buyerNameCtrl.text,
        'buyerWhatsapp': _buyerWhatsappCtrl.text,
        'buyerEmail': _buyerEmailCtrl.text,
        'street': _streetCtrl.text,
        'suburb': _suburbCtrl.text,
        'zip': _zipCtrl.text,
        'ref': _refCtrl.text,
        'locationDetails': _locationDetailsCtrl.text,
        'isAnonymous': _isAnonymous,
        'selectedDate': _selectedDate,
        'selectedTime': _selectedTime,
        'deliveryMethod': _deliveryMethod,
        'selectedState': _selectedState,
        'selectedCity': _selectedCity,
        'deliveryLocationType': _deliveryLocationType,
        'mainProductQty': _mainProductQty,
        'additionalProducts': _additionalProducts,
      }),
    );
  }

  void _restoreDraft() {
    if (_prefs == null) return;
    final raw = _prefs!.getString(_draftKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final Map<String, dynamic> d = jsonDecode(raw);
      // Discard drafts older than 24 hours (VULN-10: limit PII retention)
      final savedAt = d['_savedAt'] as int?;
      if (savedAt == null ||
          DateTime.now().millisecondsSinceEpoch - savedAt >
              const Duration(hours: 24).inMilliseconds) {
        _clearDraft();
        return;
      }
      // Temporarily null prefs so the setState override doesn't schedule a
      // redundant save while we are restoring.
      final savedPrefs = _prefs;
      _prefs = null;
      setState(() {
        if ((d['name'] as String?)?.isNotEmpty == true) {
          _nameCtrl.text = d['name'];
        }
        if ((d['phone'] as String?)?.isNotEmpty == true) {
          _phoneCtrl.text = d['phone'];
        }
        if ((d['message'] as String?)?.isNotEmpty == true) {
          _messageCtrl.text = d['message'];
        }
        if ((d['buyerName'] as String?)?.isNotEmpty == true) {
          _buyerNameCtrl.text = d['buyerName'];
        }
        if ((d['buyerWhatsapp'] as String?)?.isNotEmpty == true) {
          _buyerWhatsappCtrl.text = d['buyerWhatsapp'];
        }
        if ((d['buyerEmail'] as String?)?.isNotEmpty == true) {
          _buyerEmailCtrl.text = d['buyerEmail'];
        }
        if ((d['street'] as String?)?.isNotEmpty == true) {
          _streetCtrl.text = d['street'];
        }
        if ((d['suburb'] as String?)?.isNotEmpty == true) {
          _suburbCtrl.text = d['suburb'];
        }
        if ((d['zip'] as String?)?.isNotEmpty == true) {
          _zipCtrl.text = d['zip'];
        }
        if ((d['ref'] as String?)?.isNotEmpty == true) {
          _refCtrl.text = d['ref'];
        }
        if ((d['locationDetails'] as String?)?.isNotEmpty == true) {
          _locationDetailsCtrl.text = d['locationDetails'];
        }
        _isAnonymous = d['isAnonymous'] ?? false;
        _selectedDate = d['selectedDate'] ?? _selectedDate;
        if (d['selectedTime'] != null) _selectedTime = d['selectedTime'];
        _deliveryMethod = d['deliveryMethod'] ?? _deliveryMethod;
        _selectedState = d['selectedState'];
        _selectedCity = d['selectedCity'];
        _deliveryLocationType =
            d['deliveryLocationType'] ?? _deliveryLocationType;
        _mainProductQty = d['mainProductQty'] ?? _mainProductQty;
        if (d['additionalProducts'] is List) {
          _additionalProducts
            ..clear()
            ..addAll((d['additionalProducts'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList());
        }
      });
      _prefs = savedPrefs;
      _updateShippingCost();
    } catch (e) {
    }
  }

  void _clearDraft() {
    _draftTimer?.cancel();
    _prefs?.remove(_draftKey);
  }

  /// Returns true if all required fields are filled, otherwise shows a snackbar.
  bool _validateForm() {
    String? error;
    if (_selectedDate.isEmpty) {
      error = 'Selecciona una fecha de entrega';
    } else if (_selectedTime.isEmpty) {
      error = 'Selecciona un horario de entrega';
    } else if (_deliveryMethod != 'Recoger en tienda' &&
        _nameCtrl.text.trim().isEmpty) {
      error = 'Ingresa el nombre de quien recibe';
    } else if (_deliveryMethod != 'Recoger en tienda' &&
        _phoneCtrl.text.trim().isEmpty) {
      error = 'Ingresa el teléfono del destinatario';
    } else if (_deliveryMethod != 'Recoger en tienda' &&
        _messageCtrl.text.trim().isEmpty) {
      error = 'Escribe una dedicatoria';
    } else if (_buyerNameCtrl.text.trim().isEmpty) {
      error = 'Ingresa tu nombre en "Tus Datos"';
    } else if (_buyerWhatsappCtrl.text.trim().isEmpty) {
      error = 'Ingresa tu WhatsApp en "Tus Datos"';
    }
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.redAccent),
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF9FAFB), // Very light grey / off-white app background
      appBar: AppBar(
        title: const Text(
          'Datos de Compra',
          style: TextStyle(
              color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 16),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_mainProductQty > 0) _buildProductSummary(),
                  if (_mainProductQty > 0 && _additionalProducts.isNotEmpty)
                    const SizedBox(height: 12),
                  if (_additionalProducts.isNotEmpty) ...[
                    ..._additionalProducts
                        .map((p) => _buildAdditionalProductItem(p)),
                  ],
                  if (_giftProducts.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ..._giftProducts.map((g) => _buildGiftProductItem(g)),
                  ],
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton.icon(
                      onPressed: _showProductSelector,
                      icon: const Icon(Icons.add,
                          color: AppTheme.primary, size: 20),
                      label: const Text('Agregar otro producto',
                          style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold)),
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
                  if (_deliveryMethod != 'Recoger en tienda') ...[
                    _buildSectionTitle('Datos de Envío'),
                    const SizedBox(height: 12),
                    _buildRecipientData(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Dirección de Entrega'),
                    const SizedBox(height: 12),
                    _buildDeliveryAddress(),
                    const SizedBox(height: 24),
                  ],
                  _buildSectionTitle('Tus Datos'),
                  const SizedBox(height: 12),
                  _buildBuyerData(),
                  const SizedBox(height: 24),
                  _buildOrderTotals(),
                  const SizedBox(height: 32),
                  SafeArea(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (!_validateForm()) return;
                        double basePrice = widget.product?.price ?? 700.0;
                        double subtotal = basePrice * _mainProductQty;

                        List<Map<String, dynamic>> allProducts = [];
                        allProducts.add({
                          'name': widget.product?.name ?? 'Pedido',
                          'sku': widget.product?.sku ?? '',
                          'qty': _mainProductQty > 0 ? _mainProductQty : 1,
                          'price': basePrice,
                        });

                        for (var p in _additionalProducts) {
                          double pPrice = p['price'] as double;
                          int pQty = p['quantity'] as int;
                          subtotal += pPrice * pQty;
                          allProducts.add({
                            'name': p['name'] ?? 'Extra',
                            'sku': p['sku'] ?? '',
                            'qty': pQty,
                            'price': pPrice,
                          });
                        }

                        for (var g in _giftProducts) {
                          double gPrice = (g['price'] as num).toDouble();
                          int gQty = (g['quantity'] as num?)?.toInt() ?? 1;
                          subtotal += gPrice * gQty;
                          allProducts.add({
                            'name': g['name'] ?? 'Regalo',
                            'sku': g['sku'] ?? '',
                            'qty': gQty,
                            'price': gPrice,
                          });
                        }

                        // Encode all products into the productName field
                        String encodedProducts = jsonEncode(allProducts);

                        String finalReferences = _refCtrl.text;
                        if (_locationDetailsCtrl.text.isNotEmpty) {
                          finalReferences = finalReferences.isNotEmpty
                              ? '${_locationDetailsCtrl.text}\n$finalReferences'
                              : _locationDetailsCtrl.text;
                        }

                        final order = OrderModel(
                          folio: '#0000',
                          shopId: widget.shopId ??
                              '', // Using currently loaded shopId
                          productName: encodedProducts,
                          customerName: _buyerNameCtrl.text.isEmpty
                              ? 'Cliente'
                              : _buyerNameCtrl.text,
                          customerPhone: _buyerWhatsappCtrl.text,
                          quantity: 1, // Store as 1 bundle
                          price: subtotal,
                          status: OrderStatus.waiting,
                          createdAt: DateTime.now(),
                          saleDate: _parseDeliveryDate(_selectedDate),
                          deliveryInfo: '$_selectedDate, $_selectedTime',
                          isPaid: false,
                          shippingCost: _deliveryMethod == 'Recoger en tienda'
                              ? 0.0
                              : _shippingCost,
                          deliveryMethod: _deliveryMethod,
                          isAnonymous: _isAnonymous,
                          recipientName: _nameCtrl.text,
                          recipientPhone: _phoneCtrl.text,
                          dedicationMessage: _messageCtrl.text,
                          deliveryAddress:
                              '${_streetCtrl.text}, ${_suburbCtrl.text}, ${_zipCtrl.text}',
                          deliveryReferences: finalReferences,
                          deliveryLocationType: _deliveryLocationType,
                          // Save state & city as dedicated fields so the florist
                          // editor can display and protect them correctly.
                          deliveryState: _selectedState,
                          deliveryCity: _selectedCity,
                          buyerName: _buyerNameCtrl.text,
                          buyerWhatsapp: _buyerWhatsappCtrl.text,
                          buyerEmail: _buyerEmailCtrl.text,
                        );

                        _clearDraft();
                        context.push('/shop/summary', extra: order);
                      },
                      icon: const Icon(Icons.chat_bubble_outline,
                          color: Colors.white, size: 20),
                      label: const Text(
                        'Guardar y continuar',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF00E676), // WhatsApp Greenish
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
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
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
                height: 50,
                width: 50,
                color: Colors.grey[200],
                child: const Icon(Icons.local_florist, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.product?.sku != null && widget.product!.sku!.isNotEmpty)
                  Text(
                    widget.product!.sku!,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500, letterSpacing: 0.5),
                  ),
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  '${_settings?.currencySymbol ?? '\$'}${total.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: Color(0xFF00C853),
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Icon(
                        _mainProductQty > 1
                            ? Icons.remove
                            : Icons.delete_outline,
                        size: 16,
                        color: _mainProductQty > 1
                            ? Colors.black87
                            : Colors.redAccent),
                  ),
                ),
                Text('$_mainProductQty',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                GestureDetector(
                  onTap: () {
                    if (_mainProductQty < 999) setState(() => _mainProductQty++);
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
                height: 50,
                width: 50,
                color: Colors.grey[200],
                child: const Icon(Icons.image, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (product['sku'] != null && (product['sku'] as String).isNotEmpty)
                  Text(
                    product['sku'] as String,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500, letterSpacing: 0.5),
                  ),
                Text(product['name'],
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  '${_settings?.currencySymbol ?? '\$'}${total.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: Color(0xFF00C853),
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Icon(qty > 1 ? Icons.remove : Icons.delete_outline,
                        size: 16,
                        color: qty > 1 ? Colors.black87 : Colors.redAccent),
                  ),
                ),
                Text('$qty',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                GestureDetector(
                  onTap: () {
                    if (qty < 99) setState(() => product['quantity'] = qty + 1);
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

  Widget _buildGiftProductItem(Map<String, dynamic> gift) {
    final double price = (gift['price'] as num).toDouble();
    final int qty = (gift['quantity'] as num?)?.toInt() ?? 1;
    final String imageUrl = gift['image'] as String? ?? '';
    final String sku = gift['sku'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.pink.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    height: 50,
                    width: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildGiftThumb(),
                  )
                : _buildGiftThumb(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (sku.isNotEmpty)
                  Text(sku,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          letterSpacing: 0.5)),
                Text(gift['name'] as String? ?? 'Regalo',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                Text(
                  '${_settings?.currencySymbol ?? '\$'}${(price * qty).toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: Color(0xFF00C853),
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ],
            ),
          ),
          // Remove button
          GestureDetector(
            onTap: () => setState(() => _giftProducts.remove(gift)),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 16, color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftThumb() {
    return Container(
      height: 50,
      width: 50,
      decoration: BoxDecoration(
        color: Colors.pink.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.card_giftcard, size: 22, color: Colors.pinkAccent),
    );
  }

  void _showProductSelector() {
    final searchCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            final q = searchCtrl.text.trim().toLowerCase();
            final filtered = q.isEmpty
                ? _catalogProducts
                : _catalogProducts.where((p) =>
                    p.name.toLowerCase().contains(q) ||
                    (p.sku?.toLowerCase().contains(q) ?? false) ||
                    p.tags.any((t) => t.toLowerCase().contains(q))
                  ).toList();
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
                  const Text('Catálogo de productos',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  const SizedBox(height: 8),
                  Text(
                      'Selecciona el producto que deseas agregar a este pedido.',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchCtrl,
                    onChanged: (_) => setSheetState(() {}),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Buscar producto, flor o código...',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey, size: 20),
                      suffixIcon: searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                              onPressed: () => setSheetState(() => searchCtrl.clear()),
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 24),
                      itemBuilder: (context, index) {
                        final productItem = filtered[index];
                        final productImage = productItem.imageUrls.isNotEmpty
                            ? productItem.imageUrls.first
                            : null;

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: productImage != null
                                ? Image.network(
                                    productImage,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx, err, stack) =>
                                        Container(
                                      height: 50,
                                      width: 50,
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.local_florist,
                                          color: AppTheme.primary),
                                    ),
                                  )
                                : Container(
                                    height: 50,
                                    width: 50,
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.local_florist,
                                        color: AppTheme.primary),
                                  ),
                          ),
                          title: Text(productItem.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          subtitle: Text(
                              '${_settings?.currencySymbol ?? '\$'}${productItem.price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  color: Color(0xFF00C853),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                          trailing: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                final existingIdx =
                                    _additionalProducts.indexWhere(
                                        (p) => p['name'] == productItem.name);
                                if (existingIdx >= 0) {
                                  _additionalProducts[existingIdx]['quantity'] =
                                      (_additionalProducts[existingIdx]
                                                  ['quantity'] ??
                                              1) +
                                          1;
                                } else {
                                  _additionalProducts.add({
                                    'id': productItem.id,
                                    'name': productItem.name,
                                    'sku': productItem.sku ?? '',
                                    'price': productItem.price,
                                    'image': productImage,
                                    'quantity': 1,
                                  });
                                }
                              });
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  AppTheme.primary.withValues(alpha: 0.1),
                              foregroundColor: AppTheme.primary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
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
      },
    ).whenComplete(() => searchCtrl.dispose());
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 2)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF00E676),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate =
            "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      });
    }
  }

  Widget _buildDateOptions() {
    bool isCustomDate =
        _selectedDate.isNotEmpty && _selectedDate != 'Hoy' && _selectedDate != 'Mañana';

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
          title: isCustomDate ? _selectedDate : 'Otro',
          icon: Icons.calendar_today,
          isSelected: isCustomDate,
          onTap: () => _selectDate(context),
        ),
      ],
    );
  }

  Widget _buildPillButton(
      {required String title,
      IconData? icon,
      required bool isSelected,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00E676) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected
                  ? const Color(0xFF00E676)
                  : Colors.grey.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 14, color: isSelected ? Colors.white : Colors.black87),
              const SizedBox(width: 6),
            ],
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeOptions() {
    if (_settings == null) {
      return const Text('Cargando horarios...',
          style: TextStyle(color: Colors.grey, fontSize: 13));
    }

    if (_deliveryMethod == 'Recoger en tienda') {
      if (_settings!.storeHours.isEmpty) {
        return const Text('No hay horarios de sucursal configurados.',
            style: TextStyle(color: Colors.grey, fontSize: 13));
      }

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _settings!.storeHours.map((hour) {
            String fmt(TimeOfDay t) =>
                '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
            final label = '${fmt(hour.start)} - ${fmt(hour.end)}';

            IconData icon = Icons.storefront;
            if (hour.start.hour < 12) {
              icon = Icons.wb_sunny_outlined;
            } else if (hour.start.hour < 18) {
              icon = Icons.wb_twilight_outlined;
            } else {
              icon = Icons.nights_stay_outlined;
            }

            return Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: SizedBox(
                width: 140,
                child: _buildTimeCard(
                  id: label,
                  icon: icon,
                  title: 'Horario Tienda',
                  subtitle: label,
                ),
              ),
            );
          }).toList(),
        ),
      );
    }

    if (_settings!.deliveryRanges.isEmpty) {
      return const Text('No hay horarios de entrega configurados.',
          style: TextStyle(color: Colors.grey, fontSize: 13));
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
                id: range
                    .timeLabel, // Use timeLabel as id to pass the real hours (e.g., "08:00 - 14:00") instead of "Rango X"
                icon: icon,
                title: range.label,
                subtitle: range.timeLabel,
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
    final colorBorder = isSelected
        ? const Color(0xFF00E676)
        : Colors.grey.withValues(alpha: 0.2);
    final bgColor = isSelected
        ? const Color(0xFF00E676).withValues(alpha: 0.05)
        : Colors.white;

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
              border:
                  Border.all(color: colorBorder, width: isSelected ? 1.5 : 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon,
                        color:
                            isSelected ? const Color(0xFF00C853) : Colors.grey,
                        size: 24),
                    const SizedBox(height: 8),
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
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

  Widget _buildDeliveryOption(
      {required String id, required IconData icon, required String title}) {
    final isSelected = _deliveryMethod == id;
    final colorBorder = isSelected
        ? const Color(0xFF00E676)
        : Colors.grey.withValues(alpha: 0.2);
    final bgColor = isSelected
        ? const Color(0xFF00E676).withValues(alpha: 0.05)
        : Colors.white;

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
                style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                    color: Colors.black87),
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
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
        _buildTextField(
            controller: _nameCtrl,
            hint: 'Ej. María Pérez',
            maxLength: 100,
            autofillHints: const [AutofillHints.name]),
        const SizedBox(height: 16),
        _buildInputLabel('Teléfono destinatario'),
        _buildTextField(
            controller: _phoneCtrl,
            hint: 'Ej. 55 1234 5678',
            maxLength: 15,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofillHints: const [AutofillHints.telephoneNumber]),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildInputLabel('Dedicatoria'),
            Text('0/150',
                style: TextStyle(color: Colors.grey[400], fontSize: 10)),
          ],
        ),
        _buildTextField(
          controller: _messageCtrl,
          hint: 'Escribe un mensaje bonito aquí...',
          maxLines: 4,
          maxLength: 150,
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
                  onChanged: (val) =>
                      setState(() => _isAnonymous = val ?? false),
                  activeColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('¿Enviar como anónimo?',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                        'No incluiremos tu nombre en la tarjeta del destinatario.',
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBuyerData() {
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
              const Icon(Icons.person_outline, color: Colors.blueGrey, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Necesitamos tus datos para mantenerte informado sobre tu pedido.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInputLabel('TU NOMBRE'),
          _buildTextField(
            controller: _buyerNameCtrl,
            hint: 'Ej. Ana García',
            maxLength: 100,
            autofillHints: const [AutofillHints.name],
          ),
          const SizedBox(height: 16),
          _buildInputLabel('WHATSAPP'),
          _buildTextField(
            controller: _buyerWhatsappCtrl,
            hint: 'Ej. 5512345678',
            maxLength: 15,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofillHints: const [AutofillHints.telephoneNumber],
          ),
          const SizedBox(height: 16),
          _buildInputLabel('CORREO ELECTRÓNICO'),
          _buildTextField(
            controller: _buyerEmailCtrl,
            hint: 'Ej. ana@correo.com',
            maxLength: 254,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
          ),
        ],
      ),
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
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInputLabel('CALLE Y NÚMERO'),
          _buildTextField(
              controller: _streetCtrl,
              hint: 'Av. Reforma 222',
              maxLength: 200,
              autofillHints: const [AutofillHints.streetAddressLine1]),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputLabel('COLONIA / BARRIO'),
                    _buildTextField(
                        controller: _suburbCtrl,
                        hint: 'Col. Juárez',
                        maxLength: 150,
                        autofillHints: const [AutofillHints.addressCity]),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputLabel('CÓDIGO POSTAL'),
                    _buildTextField(
                        controller: _zipCtrl,
                        hint: '06600',
                        maxLength: 10,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        autofillHints: const [AutofillHints.postalCode]),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDropdown('ESTADO / PROVINCIA / DEPARTAMENTO', _availableStates,
              _selectedState, (val) {
            setState(() {
              _selectedState = val;
              _selectedCity = null;
              _updateShippingCost();
            });
          }, hint: 'Seleccionar estado...'),
          const SizedBox(height: 16),
          _buildDropdown('CIUDAD / MUNICIPIO', _availableCities, _selectedCity,
              (val) {
            setState(() {
              _selectedCity = val;
              _updateShippingCost();
            });
          }, hint: 'Seleccionar ciudad...'),
          const SizedBox(height: 16),
          _buildInputLabel('REFERENCIAS ADICIONALES'),
          _buildTextField(
              controller: _refCtrl,
              hint: 'Ej. Edificio blanco, dejar en recepción',
              maxLines: 2,
              maxLength: 500),
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
              _buildLocationTypeBtn('Funeraria', Icons.church),
              _buildLocationTypeBtn('Hospital', Icons.local_hospital),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _locationDetailsCtrl,
            hint: _locationHints[_deliveryLocationType] ?? '',
            maxLines: 3,
            maxLength: 300,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationTypeBtn(String id, IconData icon) {
    final isSelected = _deliveryLocationType == id;
    const activeColor = Color(0xFF00E676);

    return GestureDetector(
      onTap: () => setState(() {
        _deliveryLocationType = id;
        _locationDetailsCtrl.clear();
      }),
      child: Container(
        width: 65,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected ? activeColor.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isSelected
                  ? activeColor
                  : Colors.grey.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 20, color: isSelected ? activeColor : Colors.blueGrey),
            const SizedBox(height: 4),
            Text(id,
                style: TextStyle(
                    fontSize: 11,
                    color: isSelected ? activeColor : Colors.grey[600],
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal)),
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
          fontSize: baseLabel ? 14 : 11,
          fontWeight: FontWeight.bold,
          color: baseLabel ? Colors.black87 : Colors.grey[500],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? value,
      ValueChanged<String?> onChanged,
      {String hint = ''}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputLabel(label),
        DropdownButtonFormField<String>(
          initialValue: value != null && items.contains(value) ? value : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          items: items
              .map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(e, style: const TextStyle(fontSize: 15))))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildOrderTotals() {
    double subtotal = 0;
    if (_mainProductQty > 0) {
      subtotal += (widget.product?.price ?? 700.0) * _mainProductQty;
    }
    for (var p in _additionalProducts) {
      subtotal += (p['price'] as double) * (p['quantity'] as int);
    }
    for (var g in _giftProducts) {
      subtotal += (g['price'] as num).toDouble() *
          ((g['quantity'] as num?)?.toInt() ?? 1);
    }

    double effectiveShippingCost =
        _deliveryMethod == 'Recoger en tienda' ? 0.0 : _shippingCost;
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
              const Text('Subtotal:',
                  style: TextStyle(color: Colors.grey, fontSize: 16)),
              Text('${_settings?.currencySymbol ?? '\$'}${subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                  _selectedCity != null &&
                          _deliveryMethod != 'Recoger en tienda'
                      ? 'Costo de envío $_selectedCity:'
                      : 'Costo de envío:',
                  style: const TextStyle(color: Colors.grey, fontSize: 16)),
              Text('${_settings?.currencySymbol ?? '\$'}${effectiveShippingCost.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text('${_settings?.currencySymbol ?? '\$'}${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: Color(0xFF00E676),
                      fontWeight: FontWeight.bold,
                      fontSize: 20)),
            ],
          ),
        ],
      ),
    );
  }

  DateTime _parseDeliveryDate(String dateString) {
    final now = DateTime.now();
    if (dateString == 'Hoy') {
      return now;
    } else if (dateString == 'Mañana') {
      return now.add(const Duration(days: 1));
    } else {
      try {
        final parts = dateString.split('/');
        if (parts.length == 3) {
          int day = int.parse(parts[0]);
          int month = int.parse(parts[1]);
          int year = int.parse(parts[2]);
          return DateTime(year, month, day);
        }
      } catch (_) {}
    }
    return now;
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    Iterable<String>? autofillHints,
    TextInputAction? textInputAction,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textInputAction: textInputAction ?? TextInputAction.next,
      autofillHints: autofillHints,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
