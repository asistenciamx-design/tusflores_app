import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/repartidor_model.dart';
import '../../domain/repositories/repartidor_repository.dart';

class AddEditRepartidorScreen extends StatefulWidget {
  final RepartidorModel? repartidor; // null = create mode

  const AddEditRepartidorScreen({super.key, this.repartidor});

  @override
  State<AddEditRepartidorScreen> createState() => _AddEditRepartidorScreenState();
}

class _AddEditRepartidorScreenState extends State<AddEditRepartidorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _platesCtrl = TextEditingController();
  final _vehicleCtrl = TextEditingController();
  bool _saving = false;

  bool get _isEditing => widget.repartidor != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameCtrl.text = widget.repartidor!.name;
      _platesCtrl.text = widget.repartidor!.vehiclePlates ?? '';
      _vehicleCtrl.text = widget.repartidor!.vehicleName ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _platesCtrl.dispose();
    _vehicleCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final shopId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final repo = RepartidorRepository();

    if (_isEditing) {
      final updated = widget.repartidor!.copyWith(
        name: _nameCtrl.text.trim(),
        vehiclePlates: _platesCtrl.text.trim().isEmpty ? null : _platesCtrl.text.trim(),
        vehicleName: _vehicleCtrl.text.trim().isEmpty ? null : _vehicleCtrl.text.trim(),
      );
      final ok = await repo.updateRepartidor(updated);
      if (mounted) {
        if (ok) {
          Navigator.pop(context, updated);
        } else {
          _showError('No se pudo actualizar el repartidor.');
        }
      }
    } else {
      final model = RepartidorModel(
        shopId: shopId,
        name: _nameCtrl.text.trim(),
        vehiclePlates: _platesCtrl.text.trim().isEmpty ? null : _platesCtrl.text.trim(),
        vehicleName: _vehicleCtrl.text.trim().isEmpty ? null : _vehicleCtrl.text.trim(),
        startDate: DateTime.now(),
      );
      final created = await repo.createRepartidor(model);
      if (mounted) {
        if (created != null) {
          Navigator.pop(context, created);
        } else {
          _showError('No se pudo crear el repartidor.');
        }
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Editar Repartidor' : 'Nuevo Repartidor',
          style: const TextStyle(
            color: AppTheme.textLight,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Illustration / icon
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delivery_dining_rounded,
                    color: AppTheme.primary, size: 36),
              ),
            ),
            const SizedBox(height: 24),

            _buildCard(children: [
              _buildField(
                controller: _nameCtrl,
                label: 'Nombre y Apellido',
                hint: 'Ej. Juan García López',
                icon: Icons.person_outline,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              _buildField(
                controller: _platesCtrl,
                label: 'Placas del vehículo',
                hint: 'Ej. ABC-123-D',
                icon: Icons.pin_outlined,
              ),
              const SizedBox(height: 16),
              _buildField(
                controller: _vehicleCtrl,
                label: 'Nombre / Tipo de unidad',
                hint: 'Ej. Moto Roja, Vehículo Blanco',
                icon: Icons.two_wheeler_rounded,
              ),
            ]),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _isEditing ? 'Guardar cambios' : 'Crear repartidor',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppTheme.primary, size: 20),
        filled: true,
        fillColor: const Color(0xFFF9F9F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primary),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
