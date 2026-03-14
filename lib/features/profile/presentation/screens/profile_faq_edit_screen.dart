import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/shop_settings_model.dart';
import '../../domain/repositories/shop_settings_repository.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class ProfileFaqEditScreen extends StatefulWidget {
  const ProfileFaqEditScreen({super.key});

  @override
  State<ProfileFaqEditScreen> createState() => _ProfileFaqEditScreenState();
}

class _ProfileFaqEditScreenState extends State<ProfileFaqEditScreen> {
  List<FaqItem> _faqs = [];
  bool _isLoading = true;
  final _repo = ShopSettingsRepository();
  ShopSettingsModel? _settings;
  String _shopId = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      _shopId = user.id;
      final settings = await _repo.getSettings(_shopId);
      if (mounted) {
        setState(() {
          _settings = settings;
          _faqs = List.from(settings?.faqs ?? []);
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (_settings != null) {
      final newSettings = ShopSettingsModel(
        storeHours: _settings!.storeHours,
        deliveryRanges: _settings!.deliveryRanges,
        shippingRates: _settings!.shippingRates,
        bankMethods: _settings!.bankMethods,
        linkMethods: _settings!.linkMethods,
        faqs: _faqs,
        branchImagePath: _settings!.branchImagePath,
        country: _settings!.country,
        state: _settings!.state,
        city: _settings!.city,
        address: _settings!.address,
        mapsUrl: _settings!.mapsUrl,
        references: _settings!.references,
        phone: _settings!.phone,
        whatsapp: _settings!.whatsapp,
        showMapOnProfile: _settings!.showMapOnProfile,
      );
      await _repo.updateSettings(_shopId, newSettings);
      _settings = newSettings;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Ayuda e Información', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 2,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Add button
          _buildAddButton(),
          const SizedBox(height: 24),

          // FAQ Cards
          ..._faqs.asMap().entries.map((entry) => _buildFaqCard(entry.key, entry.value)),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ─── Add Button ──────────────────────────────────────────────────────────────

  Widget _buildAddButton() {
    return InkWell(
      onTap: () => _openFaqDialog(),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28, height: 28,
              decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
              child: const Icon(Icons.add, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('Agregar Nueva Pregunta',
                style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  // ─── FAQ Card ────────────────────────────────────────────────────────────────

  Widget _buildFaqCard(int idx, FaqItem faq) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question + action buttons
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('PREGUNTA',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                            color: AppTheme.mutedLight, letterSpacing: 0.8)),
                    const SizedBox(height: 4),
                    Text(faq.question,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textLight)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Edit button
              _buildActionCircle(
                icon: Icons.edit_outlined,
                bgColor: AppTheme.primary.withValues(alpha: 0.08),
                iconColor: AppTheme.primary,
                onTap: () => _openFaqDialog(idx: idx, existing: faq),
              ),
              const SizedBox(width: 6),
              // Delete button
              _buildActionCircle(
                icon: Icons.delete_outline,
                bgColor: Colors.red.shade50,
                iconColor: Colors.red,
                onTap: () => _confirmDelete(idx),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Answer
          const Text('RESPUESTA',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                  color: AppTheme.mutedLight, letterSpacing: 0.8)),
          const SizedBox(height: 4),
          Text(faq.answer,
              style: const TextStyle(fontSize: 13, color: AppTheme.mutedLight, height: 1.5)),

          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 12),

          // Visibility toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Visible en perfil público',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.mutedLight)),
              Switch(
                value: faq.isVisible,
                onChanged: (val) {
                  setState(() => faq.isVisible = val);
                  _saveSettings();
                },
                activeThumbColor: Colors.white,
                activeTrackColor: AppTheme.primary,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: Colors.grey.shade300,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCircle({required IconData icon, required Color bgColor, required Color iconColor, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 18),
      ),
    );
  }

  // ─── Dialogs ─────────────────────────────────────────────────────────────────

  void _openFaqDialog({int? idx, FaqItem? existing}) {
    final questionCtrl = TextEditingController(text: existing?.question ?? '');
    final answerCtrl = TextEditingController(text: existing?.answer ?? '');
    final isEditing = existing != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
              ),
              const SizedBox(height: 20),

              Text(isEditing ? 'Editar Pregunta' : 'Nueva Pregunta',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // Question field
              _buildDialogField('Pregunta', questionCtrl, hint: '¿Cómo pueden contactarme?'),
              const SizedBox(height: 16),

              // Answer field
              _buildDialogField('Respuesta', answerCtrl,
                  hint: 'Escribe una respuesta clara y breve...', maxLines: 4),
              const SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (questionCtrl.text.trim().isEmpty) return;
                    setState(() {
                      if (isEditing && idx != null) {
                        _faqs[idx].question = questionCtrl.text.trim();
                        _faqs[idx].answer = answerCtrl.text.trim();
                      } else {
                        _faqs.add(FaqItem(
                          question: questionCtrl.text.trim(),
                          answer: answerCtrl.text.trim(),
                        ));
                      }
                    });
                    _saveSettings();
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEditing ? '✅ Pregunta actualizada.' : '✅ Pregunta agregada.'),
                        backgroundColor: AppTheme.primary,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(isEditing ? 'Guardar cambios' : 'Agregar pregunta',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDialogField(String label, TextEditingController ctrl, {String? hint, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textLight)),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 14, color: AppTheme.textLight),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
          ),
        ),
      ],
    );
  }

  void _confirmDelete(int idx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar pregunta', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('¿Estás seguro de que quieres eliminar esta pregunta? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.mutedLight)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _faqs.removeAt(idx));
              _saveSettings();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Pregunta eliminada.'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
