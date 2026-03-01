import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/repositories/product_repository.dart';
import 'catalog_screen.dart' show ProductItem;

class AddEditProductScreen extends StatefulWidget {
  final ProductItem? product;
  final int? productIndex;

  const AddEditProductScreen({super.key, this.product, this.productIndex});

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _tagCtrl;
  late TextEditingController _descCtrl;

  List<String> _tags = [];
  String? _imagePath;
  XFile? _selectedImageFile;
  bool _isLoading = false;
  final _repo = ProductRepository();

  bool get isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.product?.name ?? '');
    _priceCtrl = TextEditingController(
        text: widget.product != null ? widget.product!.price.toStringAsFixed(2) : '');
    _tagCtrl = TextEditingController();
    _descCtrl = TextEditingController(text: widget.product?.description ?? '');
    _tags = widget.product != null ? List.from(widget.product!.tags) : [];
    _imagePath = widget.product?.imagePath;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _tagCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    tag = tag.trim();
    if (tag.isNotEmpty && !_tags.contains(tag) && _tags.length < 3) {
      setState(() {
        _tags.add(tag);
        _tagCtrl.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    // Using gallery source, which on web opens the file picker
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      setState(() {
        _selectedImageFile = pickedFile;
        _imagePath = pickedFile.path;
      });
    }
  }

  Future<void> _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) throw Exception('No session found');

        final name = _nameCtrl.text.trim();
        final price = double.parse(_priceCtrl.text.trim().replaceAll(',', ''));
        final desc = _descCtrl.text.trim();
        
        String? finalImageUrl = widget.product?.imagePath;

        // Upload new image if selected
        if (_selectedImageFile != null) {
          final uploadedUrl = await _repo.uploadProductImage(user.id, _selectedImageFile!);
          if (uploadedUrl != null) {
            finalImageUrl = uploadedUrl;
          }
        }

        final productData = {
          'name': name,
          'price': price,
          'description': desc.isNotEmpty ? desc : null,
          'tags': _tags,
          'image_url': finalImageUrl,
          'is_active': widget.product?.isVisible ?? true,
        };

        if (isEditing && widget.product!.id != null) {
          await _repo.updateProduct(widget.product!.id!, productData);
        } else {
          await _repo.createProduct(user.id, productData);
        }

        if (mounted) Navigator.pop(context, true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al guardar el producto')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
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
          isEditing ? 'Editar Producto' : 'Añadir Producto',
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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildImagePicker(),
                      const SizedBox(height: 28),
                      
                      // Nombre
                      _buildLabel('Nombre del arreglo'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: _inputDeco('Ej. Ramo Primaveral'),
                        validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Precio
                      _buildLabel('Precio (\$ MXN)'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: _inputDeco('0.00').copyWith(
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(left: 16, right: 8),
                            child: Icon(Icons.attach_money, size: 18, color: AppTheme.primary),
                          ),
                          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Requerido';
                          if (double.tryParse(v.replaceAll(',', '')) == null) return 'Inválido';
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),
                      
                      // Categorías
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildLabel('Categorías (Max 3)'),
                          Text(
                            '${_tags.length}/3',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _tags.length < 3 ? AppTheme.primary : Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // Custom tags input
                      if (_tags.length < 3)
                        TextField(
                          controller: _tagCtrl,
                          decoration: _inputDeco('Escribe y enter...'),
                          onSubmitted: _addTag,
                        ),
                      if (_tags.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _tags.map((tag) => Chip(
                            label: Text(tag, style: const TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                            backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                            deleteIcon: const Icon(Icons.close, size: 16, color: AppTheme.primary),
                            onDeleted: () => _removeTag(tag),
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          )).toList(),
                        ),
                      ],

                      const SizedBox(height: 20),
                      
                      // Descripción
                      _buildLabel('Descripción'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descCtrl,
                        maxLines: 5,
                        decoration: _inputDeco('Describe las flores y el follaje...'),
                      ),

                      const SizedBox(height: 40), // Padding before button
                    ],
                  ),
                ),
              ),
              
              // Bottom Button
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
                    onPressed: _isLoading ? null : _saveProduct,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(color: Colors.white))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isEditing ? 'Guardar Cambios' : 'Crear Producto', 
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.check_circle, color: Colors.white, size: 20),
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
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: double.infinity,
        height: 220,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(24),
          // Using a light dashed-like visual effect via a thin border with some transparency
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3), width: 1.5),
        ),
        child: _imagePath != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: _imagePath!.startsWith('http') || kIsWeb || _imagePath!.startsWith('blob:')
                    ? Image.network(_imagePath!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholderIcon())
                    : Image.file(File(_imagePath!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholderIcon()),
              )
            : _placeholderIcon(),
      ),
    );
  }

  Widget _placeholderIcon() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.add_a_photo, size: 32, color: AppTheme.primary),
        ),
        const SizedBox(height: 12),
        const Text(
          'Subir Foto', 
          style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Toca para agregar imagen', 
          style: TextStyle(color: AppTheme.primary.withValues(alpha: 0.6), fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87));
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
