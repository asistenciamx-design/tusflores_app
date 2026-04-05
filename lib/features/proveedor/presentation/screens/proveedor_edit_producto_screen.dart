import 'package:flutter/material.dart';
import '../../../../core/utils/image_picker_helper.dart';
import '../../domain/models/proveedor_models.dart';
import '../../domain/repositories/proveedor_repository.dart';

class ProveedorEditProductoScreen extends StatefulWidget {
  final ProveedorProducto producto;

  const ProveedorEditProductoScreen({
    super.key,
    required this.producto,
  });

  @override
  State<ProveedorEditProductoScreen> createState() =>
      _ProveedorEditProductoScreenState();
}

class _ProveedorEditProductoScreenState
    extends State<ProveedorEditProductoScreen> {
  final _repo = ProveedorRepository();

  late double? _precio;
  late int _cantidad;
  late String? _calidad;
  late String? _presentacion;
  late String? _fotoUrl;

  bool _saving = false;
  bool _uploadingPhoto = false;

  static const _calidadOpts = [
    'estándar',
    'campo',
    'primera',
    'premium',
    'exportación',
  ];

  static const _presentacionOpts = [
    'Pieza',
    'Bonche',
    'Ramo',
    'Paquete',
    'Caja',
    'Gruesa',
    '1/2 Gruesa',
    '10 Tallos',
    '12 Tallos',
    '24 Tallos',
  ];

  @override
  void initState() {
    super.initState();
    _precio = widget.producto.precio;
    _cantidad = widget.producto.cantidad;
    _calidad = widget.producto.calidad;
    _presentacion = widget.producto.presentacion;
    _fotoUrl = widget.producto.fotoUrl;
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePickerHelper.pickImage(maxWidth: 800, maxHeight: 800);
    if (picked == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final url = await _repo.uploadFoto(
          rawBytes: picked.bytes, ext: picked.ext);
      setState(() => _fotoUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al subir foto: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  void _showNumpad(
      String label, num initialValue, bool isDecimal, void Function(num) onDone) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NumpadModal(
        label: label,
        initialValue: initialValue,
        isDecimal: isDecimal,
        onConfirm: onDone,
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _repo.updateProducto(
        id: widget.producto.id,
        precio: _precio,
        cantidad: _cantidad,
        calidad: _calidad,
        presentacion: _presentacion,
        fotoUrl: _fotoUrl,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Producto actualizado'),
          backgroundColor: Color(0xFF059669),
        ));
        Navigator.of(context).pop(true); // signal refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBF8FF),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          widget.producto.displayName,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF500088),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: Color(0xFF500088)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SKU badge
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF500088).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'SKU: ${widget.producto.sku}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF500088),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.producto.isActive
                        ? Colors.green.shade50
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.producto.isActive ? 'Activo en tienda' : 'Inactivo',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: widget.producto.isActive
                          ? Colors.green.shade700
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Photo
            _buildSection('Foto del producto (opcional)'),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _uploadingPhoto ? null : _pickPhoto,
              child: Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.grey.shade200,
                    width: 1.5,
                  ),
                ),
                child: _uploadingPhoto
                    ? const Center(child: CircularProgressIndicator())
                    : _fotoUrl != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(13),
                                child: Image.network(
                                  _fotoUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _photoPlaceholder(),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _fotoUrl = null),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close,
                                        size: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : _photoPlaceholder(),
              ),
            ),
            const SizedBox(height: 24),

            // Precio
            _buildSection('Precio'),
            const SizedBox(height: 10),
            _NumpadField(
              label: _precio != null
                  ? '\$${_precio!.toStringAsFixed(2)}'
                  : 'Toca para ingresar precio',
              onTap: () => _showNumpad(
                  'Precio (MXN)', _precio ?? 0, true,
                  (v) => setState(() => _precio = v.toDouble())),
            ),
            const SizedBox(height: 24),

            // Cantidad
            _buildSection('Cantidad disponible'),
            const SizedBox(height: 10),
            _NumpadField(
              label: '$_cantidad unidades',
              onTap: () => _showNumpad('Cantidad', _cantidad, false,
                  (v) => setState(() => _cantidad = v.toInt())),
            ),
            const SizedBox(height: 24),

            // Calidad
            _buildSection('Calidad'),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _calidadOpts.map((opt) {
                  final selected = _calidad == opt;
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _calidad = selected ? null : opt),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF500088)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF500088)
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        opt,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? Colors.white
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // Presentación
            _buildSection('Presentación'),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _presentacionOpts.map((opt) {
                  final selected = _presentacion == opt;
                  return GestureDetector(
                    onTap: () => setState(
                        () => _presentacion = selected ? null : opt),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF500088)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF500088)
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        opt,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? Colors.white
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 40),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF500088),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Guardar cambios',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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

  Widget _buildSection(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1F2937),
      ),
    );
  }

  Widget _photoPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_rounded,
            size: 40, color: Colors.grey.shade400),
        const SizedBox(height: 8),
        Text(
          'Agregar foto',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }
}

// ── Numpad field tap target ───────────────────────────────────────────────────

class _NumpadField extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _NumpadField({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.dialpad_rounded,
                color: Colors.grey.shade500, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Numpad Modal ──────────────────────────────────────────────────────────────

class _NumpadModal extends StatefulWidget {
  final String label;
  final num initialValue;
  final bool isDecimal;
  final void Function(num) onConfirm;

  const _NumpadModal({
    required this.label,
    required this.initialValue,
    required this.isDecimal,
    required this.onConfirm,
  });

  @override
  State<_NumpadModal> createState() => _NumpadModalState();
}

class _NumpadModalState extends State<_NumpadModal> {
  String _display = '';

  @override
  void initState() {
    super.initState();
    _display = widget.initialValue == 0
        ? ''
        : widget.isDecimal
            ? widget.initialValue.toStringAsFixed(2)
            : widget.initialValue.toInt().toString();
  }

  void _tap(String key) {
    setState(() {
      if (key == '⌫') {
        if (_display.isNotEmpty) {
          _display = _display.substring(0, _display.length - 1);
        }
      } else if (key == '.') {
        if (!_display.contains('.')) _display += '.';
      } else {
        if (_display.length < 10) _display += key;
      }
    });
  }

  void _confirm() {
    final val = num.tryParse(_display) ?? 0;
    widget.onConfirm(val);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final keys = [
      ['7', '8', '9'],
      ['4', '5', '6'],
      ['1', '2', '3'],
      [widget.isDecimal ? '.' : '', '0', '⌫'],
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            widget.label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF500088),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F0FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _display.isEmpty ? '0' : _display,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Color(0xFF500088),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ...keys.map((row) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: row.map((k) {
                    if (k.isEmpty) {
                      return const Expanded(child: SizedBox());
                    }
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ElevatedButton(
                          onPressed: () => _tap(k),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: k == '⌫'
                                ? Colors.red.shade50
                                : Colors.grey.shade100,
                            foregroundColor: k == '⌫'
                                ? Colors.red.shade700
                                : const Color(0xFF1F2937),
                            elevation: 0,
                            padding:
                                const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            k,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              )),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF500088),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Confirmar',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
