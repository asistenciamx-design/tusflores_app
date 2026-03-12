import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/shop_settings_model.dart';
import 'payment_method_success_screen.dart';

class AddPaymentMethodScreen extends StatefulWidget {
  const AddPaymentMethodScreen({super.key});

  @override
  State<AddPaymentMethodScreen> createState() => _AddPaymentMethodScreenState();
}

class _AddPaymentMethodScreenState extends State<AddPaymentMethodScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Transferencia fields
  final _bankNameCtrl = TextEditingController();
  final _holderCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _clabeCtrl = TextEditingController();

  // Link fields
  final _serviceNameCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bankNameCtrl.dispose();
    _holderCtrl.dispose();
    _accountCtrl.dispose();
    _clabeCtrl.dispose();
    _serviceNameCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final isTransfer = _tabController.index == 0;

    if (isTransfer) {
      if (_bankNameCtrl.text.isEmpty || _holderCtrl.text.isEmpty) {
        _showSnack('Por favor llena el nombre del banco y el titular.');
        return;
      }
      final clabe = _clabeCtrl.text.trim();
      if (clabe.isNotEmpty && clabe.length != 18) {
        _showSnack('La CLABE interbancaria debe tener exactamente 18 dígitos.');
        return;
      }
      final method = BankMethod(
        bankName: _bankNameCtrl.text.trim(),
        accountType: 'Cuenta Bancaria',
        holderName: _holderCtrl.text.trim(),
        accountNumber: _accountCtrl.text.trim(),
        clabe: clabe,
      );
      Navigator.pop(context, method);
    } else {
      if (_serviceNameCtrl.text.isEmpty || _urlCtrl.text.isEmpty) {
        _showSnack('Por favor llena el nombre del servicio y la URL.');
        return;
      }
      final url = _urlCtrl.text.trim();
      if (!url.startsWith('https://')) {
        _showSnack('La URL debe comenzar con https://');
        return;
      }
      final method = LinkMethod(serviceName: _serviceNameCtrl.text.trim(), url: url);
      Navigator.pop(context, method);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Añadir Método de Pago', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildTabBar(),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTransferenciaTab(),
                _buildLinkTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(14)),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: AppTheme.primary,
        unselectedLabelColor: AppTheme.mutedLight,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        tabs: const [Tab(text: 'Transferencia'), Tab(text: 'Link de Pago')],
      ),
    );
  }

  Widget _buildTransferenciaTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            CircleAvatar(
              backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
              child: const Icon(Icons.account_balance, color: AppTheme.primary),
            ),
            const SizedBox(width: 12),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Datos Bancarios', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text('Ingresa la información de tu cuenta', style: TextStyle(color: AppTheme.mutedLight, fontSize: 12)),
            ]),
          ]),
          const SizedBox(height: 28),

          _buildFormField('Nombre del Banco', _bankNameCtrl,
              hint: 'Ej. BBVA, Santander', icon: Icons.account_balance),
          const SizedBox(height: 16),

          _buildFormField('Nombre del Titular', _holderCtrl,
              hint: 'Como aparece en el estado de cuenta', icon: Icons.person_outline),
          const SizedBox(height: 16),

          _buildFormField('Número de Cuenta o Tarjeta', _accountCtrl,
              hint: '10 a 16 dígitos', icon: Icons.credit_card, keyboardType: TextInputType.number),
          const SizedBox(height: 16),

          _buildFormField('CLABE Interbancaria', _clabeCtrl,
              hint: 'Exactamente 18 dígitos', icon: Icons.tag, keyboardType: TextInputType.number, maxLength: 18),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text('Es necesaria para transferencias interbancarias.',
                style: TextStyle(color: AppTheme.primary, fontSize: 12)),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildLinkTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            CircleAvatar(
              backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
              child: const Icon(Icons.link, color: AppTheme.primary),
            ),
            const SizedBox(width: 12),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Enlace de Pago', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text('Configura tus links de cobro', style: TextStyle(color: AppTheme.mutedLight, fontSize: 12)),
            ]),
          ]),
          const SizedBox(height: 28),

          _buildFormField('Nombre del Servicio', _serviceNameCtrl,
              hint: 'Ej. PayPal, Mercado Pago', icon: Icons.credit_card_outlined),
          const SizedBox(height: 16),

          _buildFormField('URL del Enlace', _urlCtrl,
              hint: 'https://...', icon: Icons.link, keyboardType: TextInputType.url),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text('Copia y pega el link que generaste en tu aplicación de cobros.',
                style: TextStyle(color: AppTheme.primary, fontSize: 12)),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildFormField(String label, TextEditingController ctrl, {
    required String hint, required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textLight)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: TextFormField(
            controller: ctrl,
            keyboardType: keyboardType,
            maxLength: maxLength,
            inputFormatters: maxLength != null
                ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(maxLength)]
                : null,
            style: const TextStyle(fontSize: 14, color: AppTheme.textLight),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              counterText: '',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_circle, size: 20),
              label: const Text('Guardar Método', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {},
            child: const Text('+ Agregar otro método',
                style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
