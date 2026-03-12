import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/shop_settings_model.dart';
import '../../domain/repositories/shop_settings_repository.dart';
import '../../../../features/auth/domain/repositories/profile_repository.dart';

// ─── Country / State / City data ─────────────────────────────────────────────

const List<String> _hispanicAmericanCountries = [
  'Argentina', 'Bolivia', 'Chile', 'Colombia', 'Costa Rica',
  'Cuba', 'Ecuador', 'El Salvador', 'Guatemala', 'Honduras',
  'México', 'Nicaragua', 'Panamá', 'Paraguay', 'Perú',
  'Puerto Rico', 'República Dominicana', 'Uruguay', 'Venezuela',
];

const Map<String, List<String>> _mexicanStates = {
  'CDMX': ['Álvaro Obregón','Azcapotzalco','Benito Juárez','Coyoacán','Cuajimalpa','Cuauhtémoc','Gustavo A. Madero','Iztacalco','Iztapalapa','La Magdalena Contreras','Miguel Hidalgo','Milpa Alta','Tláhuac','Tlalpan','Venustiano Carranza','Xochimilco'],
  'Jalisco': ['Guadalajara','Zapopan','Tlaquepaque','Tonalá','Tlajomulco','Puerto Vallarta','Lagos de Moreno'],
  'Nuevo León': ['Monterrey','San Nicolás','Guadalupe','San Pedro Garza García','Apodaca','Escobedo'],
  'Puebla': ['Puebla','Cholula','Tehuacán','Atlixco'],
  'Veracruz': ['Veracruz','Xalapa','Coatzacoalcos','Orizaba','Poza Rica'],
  'Estado de México': ['Ecatepec','Naucalpan','Tlalnepantla','Toluca','Chimalhuacán','Nezahualcóyotl','Texcoco'],
  'Guerrero': ['Acapulco','Chilpancingo','Zihuatanejo','Iguala'],
  'Guanajuato': ['León','Guanajuato','Irapuato','Celaya','Salamanca'],
  'Oaxaca': ['Oaxaca de Juárez','Salina Cruz','Tuxtepec','Juchitán'],
  'Chihuahua': ['Chihuahua','Ciudad Juárez','Delicias','Cuauhtémoc'],
  'Hidalgo': ['Pachuca','Tula de Allende','Tulancingo','Actopan'],
  'Tamaulipas': ['Tampico','Reynosa','Matamoros','Victoria','Nuevo Laredo'],
  'Baja California': ['Tijuana','Mexicali','Ensenada','Rosarito'],
  'Sonora': ['Hermosillo','Obregón','Nogales','Guaymas'],
  'Sinaloa': ['Culiacán','Mazatlán','Los Mochis','Guasave'],
  'San Luis Potosí': ['San Luis Potosí','Soledad','Matehuala','Cd. Valles'],
  'Michoacán': ['Morelia','Uruapan','Lázaro Cárdenas','Zamora'],
  'Querétaro': ['Querétaro','San Juan del Río','Corregidora','El Marqués'],
  'Tabasco': ['Villahermosa','Cárdenas','Comalcalco','Macuspana'],
  'Yucatán': ['Mérida','Valladolid','Progreso','Tizimín'],
  'Quintana Roo': ['Cancún','Playa del Carmen','Chetumal','Cozumel'],
  'Chiapas': ['Tuxtla Gutiérrez','San Cristóbal','Tapachula','Comitán'],
  'Morelos': ['Cuernavaca','Cuautla','Jiutepec','Temixco'],
  'Tlaxcala': ['Tlaxcala','Apizaco','Huamantla','Chiautempan'],
  'Aguascalientes': ['Aguascalientes','Jesús María','Calvillo'],
  'Nayarit': ['Tepic','Bahía de Banderas','Compostela'],
  'Colima': ['Colima','Manzanillo','Tecomán'],
  'Zacatecas': ['Zacatecas','Guadalupe','Fresnillo'],
  'Durango': ['Durango','Gómez Palacio','Lerdo'],
  'Baja California Sur': ['La Paz','Los Cabos','Comondú'],
  'Coahuila': ['Saltillo','Torreón','Monclova','Piedras Negras'],
  'Campeche': ['Campeche','Ciudad del Carmen','Escárcega'],
};

// ─── Screen ───────────────────────────────────────────────────────────────────

class ProfileBranchEditScreen extends StatefulWidget {
  const ProfileBranchEditScreen({super.key});

  @override
  State<ProfileBranchEditScreen> createState() => _ProfileBranchEditScreenState();
}

class _ProfileBranchEditScreenState extends State<ProfileBranchEditScreen> {
  // Image
  final ImagePicker _picker = ImagePicker();
  String? _branchImagePath;
  XFile? _selectedImageFile;

  // Location
  String _selectedCountry = 'México';
  String? _selectedState;
  String? _selectedCity;
  final _addressCtrl = TextEditingController();
  final _mapsCtrl = TextEditingController(); // Empty by default
  final _referencesCtrl = TextEditingController();

  // Branch data
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  bool _showMapOnProfile = false;

  // Schedules
  final List<String> _dayLabels = ['L', 'M', 'Mi', 'J', 'V', 'S', 'D'];
  TimeOfDay _attendanceStart = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _attendanceEnd = const TimeOfDay(hour: 18, minute: 0);
  final Set<int> _attendanceDays = {0, 1, 2, 3, 4};
  final List<ScheduleEntry> _specificSchedules = [];

  List<ShippingRate> _shippingRates = [];
  List<DeliveryRange> _deliveryRanges = [];
  final Set<int> _editingDeliveryRangeIndices = {};

  bool _isLoading = true;
  bool _isSaving = false;
  late final ShopSettingsRepository _settingsRepo;
  String? _shopId;

  @override
  void initState() {
    super.initState();
    _settingsRepo = ShopSettingsRepository();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    _shopId = user.id;

    final settings = await _settingsRepo.getSettings(_shopId!);
    if (!mounted) return;

    if (settings != null) {
      setState(() {
         _branchImagePath = settings.branchImagePath;
         _selectedCountry = settings.country ?? 'México';
         _selectedState = settings.state;
         _selectedCity = settings.city;
         _addressCtrl.text = settings.address ?? '';
         _mapsCtrl.text = settings.mapsUrl ?? '';
         _referencesCtrl.text = settings.references ?? '';
         _phoneCtrl.text = settings.phone ?? '';
         _whatsappCtrl.text = settings.whatsapp ?? '';
         _showMapOnProfile = settings.showMapOnProfile;

         _specificSchedules.clear();
         _specificSchedules.addAll(settings.storeHours);
         _deliveryRanges = List.from(settings.deliveryRanges);
         _shippingRates = List.from(settings.shippingRates);
      });
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _mapsCtrl.dispose();
    _referencesCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    super.dispose();
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';

  Future<TimeOfDay?> _pickTime(BuildContext context, TimeOfDay initial) async {
    return showTimePicker(context: context, initialTime: initial);
  }

  List<String> get _statesForCountry {
    if (_selectedCountry == 'México') return _mexicanStates.keys.toList()..sort();
    return [];
  }

  List<String> get _citiesForState {
    if (_selectedCountry == 'México' && _selectedState != null) {
      return _mexicanStates[_selectedState] ?? [];
    }
    return [];
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Sucursal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 2,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMapPlaceholder(),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSectionHeader('Imagen de sucursal', Icons.add_a_photo, AppTheme.primary),
                      _buildImageUpload(),
                      const SizedBox(height: 32),
                      _buildSectionHeader('Ubicación', Icons.pin_drop, AppTheme.primary),
                      _buildLocationForm(),
                      const SizedBox(height: 32),
                      _buildSectionHeader('Referencias', Icons.directions, AppTheme.primary),
                      _buildReferencesForm(),
                      const SizedBox(height: 32),
                      _buildSectionHeader('Datos de la Sucursal', Icons.storefront, AppTheme.primary),
                      _buildBranchDataForm(),
                      const SizedBox(height: 32),
                      _buildSectionHeader('Horarios', null, null),
                      _buildSchedulesForm(),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Save button
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.1))),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), offset: const Offset(0,-4), blurRadius: 6)],
              ),
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveLocation,
                icon: _isSaving 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Guardando...' : 'Guardar', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  shadowColor: AppTheme.primary.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveLocation() async {
    if (_shopId == null) return;
    setState(() => _isSaving = true);

    String? finalImagePath = _branchImagePath;
    if (_selectedImageFile != null) {
      final profileRepo = ProfileRepository();
      final uploadedUrl = await profileRepo.uploadImage(_selectedImageFile!, folder: 'sucursales');
      if (uploadedUrl != null) {
         finalImagePath = uploadedUrl;
      }
    }

    final updatedModel = ShopSettingsModel(
      branchImagePath: finalImagePath,
      country: _selectedCountry,
      state: _selectedState,
      city: _selectedCity,
      address: _addressCtrl.text.trim(),
      mapsUrl: _mapsCtrl.text.trim(),
      references: _referencesCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      whatsapp: _whatsappCtrl.text.trim(),
      showMapOnProfile: _showMapOnProfile,
      storeHours: _specificSchedules,
      deliveryRanges: _deliveryRanges,
      shippingRates: _shippingRates,
    );

    final success = await _settingsRepo.updateSettings(_shopId!, updatedModel);
    
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅  Información de sucursal guardada correctamente.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Error al guardar. Intenta de nuevo.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ─── Map Placeholder ─────────────────────────────────────────────────────────

  Widget _buildMapPlaceholder() {
    return Container(
      height: 220,
      width: double.infinity,
      color: Colors.grey[200],
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.map, size: 120, color: Colors.black12),
          Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.location_on, color: AppTheme.primary, size: 48),
            Container(width: 12, height: 6, decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10))),
          ]),
          Positioned(
            bottom: 16, right: 16,
            child: FloatingActionButton.small(
              heroTag: 'myLocationBtn',
              onPressed: () {},
              backgroundColor: Colors.white,
              foregroundColor: Colors.grey[600],
              elevation: 4,
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section Header ───────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, IconData? icon, Color? iconColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, color: iconColor, size: 20), const SizedBox(width: 8)],
          Text(title.toUpperCase(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.mutedLight, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  // ─── Image Upload ─────────────────────────────────────────────────────────────

  Widget _buildImageUpload() {
    return GestureDetector(
      onTap: () async {
        try {
          final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
          if (image != null) {
            setState(() {
              _branchImagePath = image.path;
              _selectedImageFile = image;
            });
          }
        } catch (_) {}
      },
      child: Container(
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
          image: _branchImagePath != null
              ? DecorationImage(image: NetworkImage(_branchImagePath!), fit: BoxFit.cover)
              : null,
        ),
        child: _branchImagePath != null
            ? Stack(children: [
                Positioned(top: 8, right: 8,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _branchImagePath = null;
                      _selectedImageFile = null;
                    }),
                    child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 16)),
                  ),
                ),
              ])
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate, color: AppTheme.mutedLight, size: 40),
                  SizedBox(height: 8),
                  Text('Subir foto de tu sucursal', style: TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('PNG, JPG hasta 5MB', style: TextStyle(color: AppTheme.mutedLight, fontSize: 12)),
                ],
              ),
      ),
    );
  }

  // ─── Location Form ────────────────────────────────────────────────────────────

  Widget _buildLocationForm() {
    final bool isMexico = _selectedCountry == 'México';

    return Column(
      children: [
        // Country
        _buildDropdown('País', _hispanicAmericanCountries, _selectedCountry, (val) {
          setState(() { _selectedCountry = val!; _selectedState = null; _selectedCity = null; });
        }),
        const SizedBox(height: 16),

        // State
        Row(
          children: [
            Expanded(
              child: isMexico
                  ? _buildDropdown('Estado', _statesForCountry, _selectedState, (val) {
                      setState(() { _selectedState = val; _selectedCity = null; });
                    })
                  : _buildTextInputField('Estado / Provincia', null, hint: 'Escribe el estado'),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: isMexico
                  ? _buildDropdown('Ciudad', _citiesForState, _selectedCity, (val) {
                      setState(() => _selectedCity = val);
                    })
                  : _buildTextInputField('Ciudad', null, hint: 'Escribe la ciudad'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        _buildTextInputField('Dirección Completa', _addressCtrl, hint: 'Av. Reforma 250, Col. Juárez, 06600'),
        const SizedBox(height: 16),

        _buildTextInputField('Enlace de Google Maps', _mapsCtrl,
            hint: 'Pega aquí la URL de Google Maps de tu sucursal',
            icon: Icons.link, iconColor: AppTheme.mutedLight, textColor: Colors.blue[700]),
      ],
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? value, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.mutedLight, fontWeight: FontWeight.w500)),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: items.contains(value) ? value : null,
              hint: Text('Seleccionar', style: TextStyle(fontSize: 14, color: Colors.grey[400])),
              icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.mutedLight),
              style: const TextStyle(fontSize: 14, color: AppTheme.textLight, fontWeight: FontWeight.w500),
              onChanged: items.isEmpty ? null : onChanged,
              items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextInputField(String label, TextEditingController? ctrl, {String? hint, IconData? icon, Color? iconColor, int maxLines = 1, Color? textColor}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: maxLines > 1 ? 12 : 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.mutedLight, fontWeight: FontWeight.w500)),
                TextFormField(
                  controller: ctrl,
                  maxLines: maxLines,
                  style: TextStyle(fontSize: 14, color: textColor ?? AppTheme.textLight, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.normal, fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.only(top: 4, bottom: 4),
                  ),
                ),
              ],
            ),
          ),
          if (icon != null) ...[const SizedBox(width: 8), Icon(icon, color: iconColor, size: 22)],
        ],
      ),
    );
  }

  // ─── References ───────────────────────────────────────────────────────────────

  Widget _buildReferencesForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextInputField('Indicaciones adicionales', _referencesCtrl,
            hint: 'Ej. Local 4B, frente a la fuente, portón negro...', maxLines: 3),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.only(left: 4.0),
          child: Text('Estas indicaciones ayudarán a tus clientes a encontrar tu local más fácilmente.',
              style: TextStyle(color: AppTheme.mutedLight, fontSize: 12)),
        ),
      ],
    );
  }

  // ─── Branch Data ──────────────────────────────────────────────────────────────

  Widget _buildBranchDataForm() {
    return Column(
      children: [
        _buildTextInputField('Teléfono', _phoneCtrl, hint: '55 1234 5678', icon: Icons.phone, iconColor: AppTheme.mutedLight),
        const SizedBox(height: 16),
        _buildTextInputField('WhatsApp', _whatsappCtrl, hint: '55 1234 5678', icon: Icons.chat, iconColor: Colors.green),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.withValues(alpha: 0.2))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Mostrar mapa en perfil', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textLight, fontSize: 14)),
                Text('Visible para todos los clientes', style: TextStyle(color: AppTheme.mutedLight, fontSize: 12)),
              ]),
              Switch(
                value: _showMapOnProfile,
                onChanged: (val) => setState(() => _showMapOnProfile = val),
                activeThumbColor: Colors.white,
                activeTrackColor: AppTheme.primary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Schedules Form ───────────────────────────────────────────────────────────

  Widget _buildSchedulesForm() {
    return Column(
      children: [
        // Horario de Atención
        _buildCard(children: [
          const Row(children: [
            Icon(Icons.schedule, color: AppTheme.primary, size: 24),
            SizedBox(width: 8),
            Text('Horario de Atención', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _buildTimeTile('Apertura', _attendanceStart, (t) => setState(() => _attendanceStart = t))),
            const SizedBox(width: 16),
            Expanded(child: _buildTimeTile('Cierre', _attendanceEnd, (t) => setState(() => _attendanceEnd = t))),
          ]),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          _buildDayToggles(_attendanceDays, (idx) {
            setState(() {
              if (_attendanceDays.contains(idx)) {
                _attendanceDays.remove(idx);
              } else {
                _attendanceDays.add(idx);
              }
            });
          }),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          // Specific day schedules
          ..._specificSchedules.asMap().entries.map((e) => _buildSpecificScheduleCard(e.key, e.value)),
          _buildAddScheduleButton(),
        ]),

        const SizedBox(height: 24),

        // Rangos de Entrega
        _buildCard(children: [
          const Row(children: [
            Icon(Icons.local_shipping, color: AppTheme.primary, size: 24),
            SizedBox(width: 8),
            Text('Rangos de Entrega', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 20),
          ..._deliveryRanges.asMap().entries.map((e) => _buildDeliveryRangeCard(e.key, e.value)),
          const SizedBox(height: 8),
          _buildAddDeliveryRangeButton(),
        ]),

        const SizedBox(height: 24),

        // Tarifas de Envío
        _buildCard(children: [
          const Row(children: [
            Icon(Icons.monetization_on, color: AppTheme.primary, size: 24),
            SizedBox(width: 8),
            Text('Tarifas de Envío', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 20),
          ..._shippingRates.asMap().entries.map((e) => _buildShippingRateCard(e.key, e.value)),
          const SizedBox(height: 8),
          _buildAddShippingRateButton(),
        ]),
      ],
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _buildTimeTile(String label, TimeOfDay time, ValueChanged<TimeOfDay> onPick) {
    return GestureDetector(
      onTap: () async {
        final picked = await _pickTime(context, time);
        if (picked != null) onPick(picked);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.mutedLight)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: AppTheme.backgroundLight, borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fmt(time), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
                const Icon(Icons.schedule, color: AppTheme.mutedLight, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayToggles(Set<int> active, ValueChanged<int> onToggle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(_dayLabels.length, (i) {
        final isActive = active.contains(i);
        return GestureDetector(
          onTap: () => onToggle(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: isActive ? AppTheme.primary : Colors.grey[200],
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(_dayLabels[i], style: TextStyle(
              color: isActive ? Colors.white : AppTheme.mutedLight,
              fontWeight: FontWeight.bold, fontSize: 12,
            )),
          ),
        );
      }),
    );
  }

  Widget _buildSpecificScheduleCard(int idx, ScheduleEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(children: [
        Row(
          children: [
            Expanded(child: _buildTimeTile('Apertura', entry.start, (t) => setState(() => entry.start = t))),
            const SizedBox(width: 12),
            Expanded(child: _buildTimeTile('Cierre', entry.end, (t) => setState(() => entry.end = t))),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _specificSchedules.removeAt(idx)),
              child: const Icon(Icons.close, color: Colors.grey, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildDayToggles(entry.days, (i) => setState(() {
          if (entry.days.contains(i)) {
            entry.days.remove(i);
          } else {
            entry.days.add(i);
          }
        })),
      ]),
    );
  }

  Widget _buildAddScheduleButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          setState(() {
            _specificSchedules.add(ScheduleEntry(
              start: const TimeOfDay(hour: 9, minute: 0),
              end: const TimeOfDay(hour: 18, minute: 0),
              days: {0, 1, 2, 3, 4},
            ));
          });
        },
        icon: const Icon(Icons.add_circle_outline, size: 20),
        label: const Text('Agregar horario específico por día', style: TextStyle(fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.primary,
          side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.4), width: 2),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildDeliveryRangeCard(int idx, DeliveryRange range) {
    final isEditing = _editingDeliveryRangeIndices.contains(idx);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              // ── Label (editable only when pencil pressed) ───────────
              Expanded(
                child: TextFormField(
                  key: ValueKey('dr_label_${idx}_$isEditing'),
                  initialValue: range.label,
                  readOnly: !isEditing,
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[800], fontSize: 14),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Ej. Matutino',
                    hintStyle: TextStyle(color: Colors.green[200], fontWeight: FontWeight.normal),
                    suffixIcon: GestureDetector(
                      onTap: () => setState(() {
                        if (isEditing) {
                          _editingDeliveryRangeIndices.remove(idx);
                        } else {
                          _editingDeliveryRangeIndices.add(idx);
                        }
                      }),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          isEditing ? Icons.check : Icons.edit,
                          size: 13,
                          color: isEditing ? AppTheme.primary : AppTheme.mutedLight,
                        ),
                      ),
                    ),
                    suffixIconConstraints: const BoxConstraints(maxWidth: 22, maxHeight: 22),
                  ),
                  onChanged: (val) => range.label = val.isEmpty ? 'Rango ${idx + 1}' : val,
                ),
              ),
              // ── Delete button ───────────────────────────────────────
              GestureDetector(
                onTap: () => setState(() {
                  _editingDeliveryRangeIndices.remove(idx);
                  _deliveryRanges.removeAt(idx);
                }),
                child: const Icon(Icons.close, color: Colors.grey, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _buildTimeTile('Inicio', range.start, (t) => setState(() => range.start = t))),
            const SizedBox(width: 12),
            Expanded(child: _buildTimeTile('Fin', range.end, (t) => setState(() => range.end = t))),
          ]),
          const SizedBox(height: 12),
          _buildDayToggles(range.days, (i) => setState(() {
            if (range.days.contains(i)) {
              range.days.remove(i);
            } else {
              range.days.add(i);
            }
          })),
        ],
      ),
    );
  }

  Widget _buildAddDeliveryRangeButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          setState(() {
            final n = _deliveryRanges.length + 1;
            _deliveryRanges.add(DeliveryRange(
              label: 'Rango $n',
              start: const TimeOfDay(hour: 8, minute: 0),
              end: const TimeOfDay(hour: 14, minute: 0),
              days: {0, 1, 2, 3, 4},
            ));
          });
        },
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Agregar rango', style: TextStyle(fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.primary,
          side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildShippingRateCard(int idx, ShippingRate rate) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: rate.label ?? 'Tarifa ${idx + 1}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[800], fontSize: 14),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Ej. Zona 1',
                    hintStyle: TextStyle(color: Colors.green[200], fontWeight: FontWeight.normal),
                    suffixIcon: const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.edit, size: 13, color: AppTheme.mutedLight),
                    ),
                    suffixIconConstraints: const BoxConstraints(maxWidth: 22, maxHeight: 22),
                  ),
                  onChanged: (val) => rate.label = val.isEmpty ? 'Tarifa ${idx + 1}' : val,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _shippingRates.removeAt(idx)),
                child: const Icon(Icons.close, color: Colors.grey, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: _buildSmallDropdown('Estado', _statesForCountry, rate.estado, (val) {
                  setState(() { rate.estado = val; rate.ciudad = null; });
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 5,
                child: _buildSmallDropdown('Ciudad', rate.estado != null ? _mexicanStates[rate.estado] ?? [] : [], rate.ciudad, (val) {
                  setState(() => rate.ciudad = val);
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: _buildSmallCostField(rate),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddShippingRateButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          setState(() {
            _shippingRates.add(ShippingRate());
          });
        },
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Agregar tarifa de envío', style: TextStyle(fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.primary,
          side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildSmallDropdown(String label, List<String> items, String? value, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.mutedLight, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              isDense: true,
              value: items.contains(value) ? value : null,
              hint: const Text('...', style: TextStyle(fontSize: 12, color: Colors.grey)),
              icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.mutedLight, size: 16),
              style: const TextStyle(fontSize: 12, color: AppTheme.textLight, fontWeight: FontWeight.w500),
              onChanged: items.isEmpty ? null : onChanged,
              items: items.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallCostField(ShippingRate rate) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Costo', style: TextStyle(fontSize: 10, color: AppTheme.mutedLight, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          TextFormField(
             initialValue: rate.costo > 0 ? rate.costo.toStringAsFixed(0) : '',
             keyboardType: TextInputType.number,
             style: const TextStyle(fontSize: 12, color: AppTheme.textLight, fontWeight: FontWeight.bold),
             decoration: const InputDecoration(
               prefixText: '\$ ',
               prefixStyle: TextStyle(fontSize: 12, color: AppTheme.textLight),
               isDense: true,
               contentPadding: EdgeInsets.zero,
               border: InputBorder.none,
             ),
             onChanged: (val) => rate.costo = double.tryParse(val) ?? 0,
          ),
        ],
      ),
    );
  }
}
