// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../profile/domain/models/shop_settings_model.dart';
import '../../../profile/domain/repositories/shop_settings_repository.dart';
import '../../domain/models/order_model.dart';
import '../../domain/repositories/order_repository.dart';
import 'print_card_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class EditOrderScreen extends StatefulWidget {
  final OrderModel order;

  const EditOrderScreen({super.key, required this.order});

  @override
  State<EditOrderScreen> createState() => _EditOrderScreenState();
}

class _EditOrderScreenState extends State<EditOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _orderRepo = OrderRepository();
  bool _isSaving = false;

  // Product & Price
  late TextEditingController _qtyCtrl;
  late TextEditingController _productCtrl;
  late TextEditingController _priceCtrl;
  
  // Delivery
  DateTime? _selectedDate;
  String? _selectedRange;

  // Card
  late TextEditingController _cardToCtrl;
  late TextEditingController _cardPhoneCtrl;
  late TextEditingController _cardMessageCtrl;

  // Address
  late TextEditingController _streetCtrl;
  late TextEditingController _neighborhoodCtrl;
  late TextEditingController _zipCtrl;
  late TextEditingController _referenceCtrl;
  late TextEditingController _mapsUrlCtrl;
  String _locationType = 'Casa';
  String _deliveryMethod = 'Envío a domicilio';
  bool _isAnonymous = false;
  
  String? _selectedState;
  String? _selectedCity;
  double _shippingCost = 0.0;

  bool _isLoadingSettings = true;
  ShopSettingsModel? _settings;

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
      setState(() => _shippingCost = rate.costo);
    } else {
      setState(() => _shippingCost = 0.0);
    }
  }

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: widget.order.quantity.toString());
    _productCtrl = TextEditingController(text: widget.order.productName);
    // Remove formatting to keep just the number
    _priceCtrl = TextEditingController(text: widget.order.price.toStringAsFixed(0));
    
    _selectedDate = widget.order.saleDate;
    _selectedRange = widget.order.deliveryInfo.split(', ').last;
    _selectedState = widget.order.deliveryState;
    _selectedCity = widget.order.deliveryCity;
    _shippingCost = widget.order.shippingCost;
    _loadSettings();

    // Dummy data for remaining fields since OrderModel doesn't have them all yet
    _cardToCtrl = TextEditingController(text: 'Ana María');
    _cardPhoneCtrl = TextEditingController(text: '5543633544');
    _cardMessageCtrl = TextEditingController(text: '¡Feliz cumpleaños! Espero que te encanten estas flores.');
    
    _streetCtrl = TextEditingController(text: 'Av. Reforma 222');
    _neighborhoodCtrl = TextEditingController(text: 'Col. Juárez');
    _zipCtrl = TextEditingController(text: '06600');
    _referenceCtrl = TextEditingController(text: 'Ej. Edificio blanco, dejar en recepción');
    _mapsUrlCtrl = TextEditingController(text: '');
    
    // Listeners to recalculate totals if price/qty changes
    _qtyCtrl.addListener(() => setState(() {}));
    _priceCtrl.addListener(() => setState(() {}));
  }

  Future<void> _loadSettings() async {
    final repo = ShopSettingsRepository();
    final settings = await repo.getSettings(widget.order.shopId ?? '');
    if (mounted) {
      setState(() {
         _settings = settings;
         _isLoadingSettings = false;
         if (_selectedRange == null && _settings != null && _settings!.deliveryRanges.isNotEmpty) {
           _selectedRange = _settings!.deliveryRanges.first.fullLabel;
         }
      });
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _productCtrl.dispose();
    _priceCtrl.dispose();
    _cardToCtrl.dispose();
    _cardPhoneCtrl.dispose();
    _cardMessageCtrl.dispose();
    _streetCtrl.dispose();
    _neighborhoodCtrl.dispose();
    _zipCtrl.dispose();
    _referenceCtrl.dispose();
    _mapsUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _openWhatsApp(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final url = Uri.parse('https://wa.me/52$clean');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp')),
        );
      }
    }
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      
      final updatedOrder = widget.order.copyWith(
        quantity: int.tryParse(_qtyCtrl.text) ?? widget.order.quantity,
        productName: _productCtrl.text,
        price: double.tryParse(_priceCtrl.text) ?? widget.order.price,
        saleDate: _selectedDate,
        deliveryInfo: _selectedRange,
        deliveryMethod: _deliveryMethod,
        isAnonymous: _isAnonymous,
        recipientName: _cardToCtrl.text,
        recipientPhone: _cardPhoneCtrl.text,
        dedicationMessage: _cardMessageCtrl.text,
        deliveryAddress: '${_streetCtrl.text}, ${_neighborhoodCtrl.text}, ${_zipCtrl.text}',
        deliveryReferences: _referenceCtrl.text,
        deliveryLocationType: _locationType,
        shippingCost: _shippingCost,
        deliveryState: _selectedState,
        deliveryCity: _selectedCity,
      );

      final success = await _orderRepo.updateOrder(updatedOrder);

      if (mounted) {
        setState(() => _isSaving = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pedido actualizado exitosamente'), backgroundColor: Colors.green),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al actualizar pedido'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Editar Pedido', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textLight,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoadingSettings 
        ? const Center(child: CircularProgressIndicator())
        : SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOrderHeaderRow(),
                const SizedBox(height: 24),
                
                _buildSectionTitle('CLIENTE'),
                const SizedBox(height: 12),
                _buildCustomerCard(),
                
                const SizedBox(height: 24),
                _buildSectionTitle('PRODUCTO Y PRECIO'),
                const SizedBox(height: 12),
                _buildProductRow(),
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add, color: AppTheme.primary, size: 20),
                    label: const Text('Agregar otro producto', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
                _buildOrderTotals(),

                const SizedBox(height: 32),
                _buildSectionTitle('ENTREGA Y HORARIOS'),
                const SizedBox(height: 12),
                _buildInputLabel('Método de Entrega'),
                _buildDeliveryMethodField(),
                const SizedBox(height: 16),
                _buildInputLabel('Fecha de Entrega'),
                _buildDateField(),
                const SizedBox(height: 16),
                _buildInputLabel('Rango de entrega'),
                _buildDropdownField(),

                const SizedBox(height: 32),
                _buildSectionTitle('TARJETA Y DEDICATORIA'),
                const SizedBox(height: 16),
                _buildAnonymousCheckbox(),
                const SizedBox(height: 16),
                _buildInputLabel('Para:'),
                _buildTextField(_cardToCtrl, 'Nombre destinatario'),
                const SizedBox(height: 16),
                _buildInputLabel('Teléfono destinatario'),
                _buildTextField(_cardPhoneCtrl, '55...'),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInputLabel('Dedicatoria:'),
                    IconButton(
                      icon: const Icon(Icons.print, color: AppTheme.primary, size: 20),
                      tooltip: 'Imprimir Dedicatoria',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PrintCardScreen(
                              initialMessage: _cardMessageCtrl.text,
                            ),
                          ),
                        );
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildTextField(_cardMessageCtrl, 'Mensaje...', maxLines: 4),

                const SizedBox(height: 32),
                const Text('Dirección de Entrega', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textLight)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.indigo.shade300, size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text('Ingresa los detalles de la ubicación de entrega.', style: TextStyle(fontSize: 13, color: AppTheme.mutedLight)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildInputLabel('CALLE Y NÚMERO', uppercase: true),
                      _buildTextField(_streetCtrl, 'Av. Reforma 222'),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInputLabel('COLONIA / BARRIO', uppercase: true),
                                _buildTextField(_neighborhoodCtrl, 'Col. Juárez'),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInputLabel('CÓDIGO POSTAL', uppercase: true),
                                _buildTextField(_zipCtrl, '06600'),
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
                      _buildInputLabel('REFERENCIAS ADICIONALES', uppercase: true),
                      _buildTextField(_referenceCtrl, 'Ej. Edificio blanco...', maxLines: 2),
                      const SizedBox(height: 16),
                      _buildInputLabel('URL GOOGLE MAPS', uppercase: true),
                      _buildTextField(
                        _mapsUrlCtrl,
                        'Ej. https://maps.app.goo.gl/...',
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
                      const SizedBox(height: 20),
                      _buildInputLabel('Lugar de entrega:', uppercase: false),
                      const SizedBox(height: 12),
                      _buildLocationTypesGrid(),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveChanges,
                    icon: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save),
                    label: Text(_isSaving ? 'Actualizando...' : 'Actualizar Pedido', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2DD47A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Header & Sections ────────────────────────────────────────────────────────

  Widget _buildOrderHeaderRow() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ORDEN ACTIVA', style: TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('Folio ${widget.order.folio}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: AppTheme.textLight)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.receipt_long, color: AppTheme.primary, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.access_time_filled, color: Color(0xFF757575), size: 14),
              const SizedBox(width: 6),
              Text('Creado: ${_formatDate(widget.order.createdAt)}, ${_formatTime(widget.order.createdAt)}', style: const TextStyle(fontSize: 12, color: Color(0xFF757575))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.mutedLight, letterSpacing: 0.5));
  }

  Widget _buildCustomerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.order.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textLight)),
                    const SizedBox(height: 4),
                    Text('+52 ${widget.order.customerPhone}', style: const TextStyle(fontSize: 14, color: AppTheme.mutedLight)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                child: const Icon(Icons.person, color: AppTheme.mutedLight, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openWhatsApp(widget.order.customerPhone),
              icon: const Icon(Icons.chat),
              label: const Text('Ver contacto en WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE8F8F0),
                foregroundColor: const Color(0xFF229560),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          )
        ],
      ),
    );
  }

  // ─── Products & Gifts ────────────────────────────────────────────────────────

  Widget _buildProductRow() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInputLabel('Cantidad', uppercase: false),
              _buildTextField(_qtyCtrl, '1', centerAlign: true),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInputLabel('Nombre', uppercase: false),
              _buildTextField(_productCtrl, 'Ramo...'),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInputLabel('Precio', uppercase: false),
              _buildTextField(_priceCtrl, '0.00'),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Form Elements ────────────────────────────────────────────────────────────

  Widget _buildInputLabel(String text, {bool uppercase = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: TextStyle(fontSize: uppercase ? 10 : 12, fontWeight: FontWeight.bold, color: AppTheme.textLight, letterSpacing: uppercase ? 0.5 : 0)),
    );
  }

  InputDecoration _buildInputDecoration({String? label, IconData? icon}) {
    return InputDecoration(
      hintText: label,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.primary),
      ),
      prefixIcon: icon != null ? Icon(icon, color: AppTheme.mutedLight, size: 20) : null,
      prefixIconConstraints: icon != null ? const BoxConstraints(minWidth: 40) : null,
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    bool centerAlign = false,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textAlign: centerAlign ? TextAlign.center : TextAlign.start,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primary)),
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? value, ValueChanged<String?> onChanged, {String hint = ''}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputLabel(label, uppercase: true),
        DropdownButtonFormField<String>(
          initialValue: value != null && items.contains(value) ? value : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.primary),
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
    
    // Basic calculation using qty and price textfields
    int qty = int.tryParse(_qtyCtrl.text) ?? 1;
    double price = double.tryParse(_priceCtrl.text) ?? 0;
    subtotal += (qty * price); 

    double effectiveShippingCost = _deliveryMethod == 'Recoger en tienda' ? 0.0 : _shippingCost;
    double total = subtotal + effectiveShippingCost;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
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
              Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateField() {
    return GestureDetector(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: _selectedDate ?? DateTime.now(),
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (d != null) setState(() => _selectedDate = d);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_today, color: AppTheme.mutedLight, size: 20),
                const SizedBox(width: 12),
                Text(_selectedDate == null ? 'Seleccionar fecha' : '${_selectedDate!.month}/${_selectedDate!.day}/${_selectedDate!.year}', style: const TextStyle(fontSize: 14, color: AppTheme.textLight)),
              ],
            ),
            const Icon(Icons.calendar_month, color: AppTheme.textLight, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownField() {
    final ranges = _settings?.deliveryRanges.map((r) => r.fullLabel).toList() ?? [];
    if (_selectedRange != null && !ranges.contains(_selectedRange) && ranges.isNotEmpty) {
      _selectedRange = ranges.first;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_shipping, color: AppTheme.mutedLight, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: ranges.contains(_selectedRange) ? _selectedRange : null,
                isExpanded: true,
                hint: const Text('Seleccione un rango'),
                icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.mutedLight),
                style: const TextStyle(fontSize: 14, color: AppTheme.textLight),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedRange = v);
                },
                items: ranges.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryMethodField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioListTile<String>(
            title: const Text('Envío a domicilio', style: TextStyle(fontSize: 14)),
            value: 'Envío a domicilio',
            groupValue: _deliveryMethod,
            onChanged: (val) {
              if (val != null) setState(() => _deliveryMethod = val);
            },
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          RadioListTile<String>(
            title: const Text('Recoger en tienda', style: TextStyle(fontSize: 14)),
            value: 'Recoger en tienda',
            groupValue: _deliveryMethod,
            onChanged: (val) {
              if (val != null) setState(() => _deliveryMethod = val);
            },
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ],
      ),
    );
  }

  Widget _buildAnonymousCheckbox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                const Text('¿Enviar como anónimo?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textLight)),
                const SizedBox(height: 2),
                Text('No se incluirá el nombre del remitente en la tarjeta.', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationTypesGrid() {
    final types = [
      {'icon': Icons.home, 'label': 'Casa'},
      {'icon': Icons.business, 'label': 'Edificio'},
      {'icon': Icons.holiday_village, 'label': 'Fracc.'},
      {'icon': Icons.domain, 'label': 'Empresa'},
      {'icon': Icons.church, 'label': 'Funeraria'},
      {'icon': Icons.local_hospital, 'label': 'Hospital'},
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: types.map((t) {
        final label = t['label'] as String;
        final icon = t['icon'] as IconData;
        final isSelected = _locationType == label;
        
        return GestureDetector(
          onTap: () => setState(() => _locationType = label),
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primary.withValues(alpha: 0.1) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? AppTheme.primary : Colors.grey.shade200, width: isSelected ? 1.5 : 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: isSelected ? AppTheme.primary : AppTheme.mutedLight, size: 24),
                const SizedBox(height: 6),
                Text(label, style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? AppTheme.primary : AppTheme.mutedLight)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) return 'Hoy';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }
}
