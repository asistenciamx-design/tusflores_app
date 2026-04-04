import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_cache.dart';
import '../../../../core/utils/image_picker_helper.dart';
import '../../domain/models/gift_model.dart';
import '../../domain/repositories/gift_repository.dart';

class _PendingImage {
  final Uint8List bytes;
  final String name;
  const _PendingImage({required this.bytes, required this.name});
}

class AddEditGiftScreen extends StatefulWidget {
  final GiftItem? gift;

  const AddEditGiftScreen({super.key, this.gift});

  @override
  State<AddEditGiftScreen> createState() => _AddEditGiftScreenState();
}

class _AddEditGiftScreenState extends State<AddEditGiftScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _descCtrl;

  dynamic _image; // String (network url) or XFile
  bool _isLoading = false;
  final _repo = GiftRepository();

  bool get isEditing => widget.gift != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.gift?.name ?? '');
    _priceCtrl = TextEditingController(
        text: widget.gift != null
            ? widget.gift!.price.toStringAsFixed(2)
            : '');
    _descCtrl = TextEditingController(text: widget.gift?.description ?? '');
    if (widget.gift?.imageUrl != null && widget.gift!.imageUrl!.isNotEmpty) {
      _image = widget.gift!.imageUrl;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await ImagePickerHelper.pickImage(source: ImageSource.gallery);
    if (result != null) {
      setState(() => _image = _PendingImage(bytes: result.bytes, name: 'image.${result.ext}'));
    }
  }

  void _removeImage() {
    setState(() => _image = null);
  }

  Future<void> _saveGift() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Sin sesión activa.');

      final name = _nameCtrl.text.trim();
      final price =
          double.parse(_priceCtrl.text.trim().replaceAll(',', ''));
      final desc = _descCtrl.text.trim();

      String? imageUrl;
      if (_image is String) {
        imageUrl = _image as String;
      } else if (_image is _PendingImage) {
        final p = _image as _PendingImage;
        imageUrl = await _repo.uploadGiftImage(user.id, p.bytes, p.name);
      }

      // Auto-assign SKU only for new gifts
      String? autoSku;
      if (!isEditing) {
        autoSku = await _repo.getNextGiftSku(user.id);
      }

      final giftData = {
        'name': name,
        if (autoSku != null) 'sku': autoSku,
        'price': price,
        'description': desc.isNotEmpty ? desc : null,
        'image_url': imageUrl,
        'is_active': widget.gift?.isActive ?? true,
      };

      if (isEditing && widget.gift!.id != null) {
        await _repo.updateGift(widget.gift!.id!, user.id, giftData);
      } else {
        await _repo.createGift(user.id, giftData);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No se pudo guardar el regalo. Intenta de nuevo.'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditing ? 'Editar Regalo' : 'Nuevo Regalo',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textLight,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image picker
                      _buildImagePicker(),
                      const SizedBox(height: 28),

                      // SKU (read-only when editing)
                      if (isEditing &&
                          widget.gift!.sku != null &&
                          widget.gift!.sku!.isNotEmpty) ...[
                        _buildLabel('SKU'),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.pink.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.pink.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.card_giftcard,
                                  size: 18, color: Colors.pink.shade400),
                              const SizedBox(width: 10),
                              Text(
                                widget.gift!.sku!,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.pink.shade400,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '· asignado automáticamente',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Nombre
                      _buildLabel('Nombre del regalo'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameCtrl,
                        maxLength: 100,
                        decoration: _inputDeco('Ej. Globo Metálico Rosa'),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 20),

                      // Precio
                      _buildLabel('Precio (${CurrencyCache.symbol} ${CurrencyCache.code})'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: _inputDeco('0.00').copyWith(
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(left: 16, right: 8),
                            child: Icon(Icons.attach_money,
                                size: 18, color: AppTheme.primary),
                          ),
                          prefixIconConstraints:
                              const BoxConstraints(minWidth: 0, minHeight: 0),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Requerido';
                          final parsed = double.tryParse(v.replaceAll(',', ''));
                          if (parsed == null) return 'Inválido';
                          if (parsed <= 0) return 'El precio debe ser mayor a 0';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Descripción
                      _buildLabel('Descripción (opcional)'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descCtrl,
                        maxLines: 3,
                        decoration:
                            _inputDeco('Ej. Globo de helio color rosa, 40cm'),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),

              // Bottom save button
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveGift,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isEditing
                                    ? 'Guardar Cambios'
                                    : 'Crear Regalo',
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.check_circle,
                                  color: Colors.white, size: 20),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Foto del regalo'),
        const SizedBox(height: 12),
        if (_image == null)
          GestureDetector(
            onTap: _pickImage,
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.pink.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.pink.withValues(alpha: 0.3), width: 1.5),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_a_photo,
                        size: 32, color: Colors.pinkAccent),
                    const SizedBox(height: 8),
                    Text(
                      'Agregar foto',
                      style: TextStyle(
                          color: Colors.pink.shade300,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _image is String
                      ? Image.network(
                          _image as String,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.broken_image),
                        )
                      : _image is _PendingImage
                          ? Image.memory(
                              (_image as _PendingImage).bytes,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : const SizedBox(),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: _removeImage,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit,
                        size: 16, color: Colors.black87),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(text,
        style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.black87));
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primary, width: 2),
      ),
    );
  }
}
