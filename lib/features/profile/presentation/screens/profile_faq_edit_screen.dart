import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/shop_settings_model.dart';
import '../../domain/repositories/shop_settings_repository.dart';

// Preguntas sugeridas que toda florería debería responder.
const _kDefaultFaqs = [
  ('flowers_offered',        '¿Qué flores ofrecen?'),
  ('custom_arrangements',    '¿Hacen arreglos personalizados?'),
  ('advance_order',          '¿Con cuánta anticipación debo realizar mi pedido?'),
  ('photo_before_delivery',  '¿Pueden enviarme una foto de mi arreglo antes de que salga a entrega?'),
  ('delivery_cost',          '¿Cuál es el costo de envío a mi zona o código postal?'),
  ('same_day_delivery',      '¿Tienen envíos el mismo día y hasta qué hora puedo pedir?'),
  ('delivery_schedule',      '¿Puedo elegir un horario de entrega específico?'),
  ('order_tracking',         '¿Cómo puedo rastrear el estatus de mi pedido en tiempo real?'),
  ('no_one_home',            '¿Qué sucede si no hay nadie en el domicilio para recibir las flores?'),
  ('delivery_notification',  '¿Me notifican en el momento en que las flores han sido entregadas?'),
  ('damaged_guarantee',      '¿Qué garantía tengo si las flores llegan maltratadas o el pedido está incompleto?'),
  ('payment_methods',        '¿Qué métodos de pago aceptan (tarjeta, transferencia, efectivo)?'),
  ('cash_on_delivery',       '¿Puedo pagar al momento de recibir las flores (pago contra entrega)?'),
  ('invoice',                '¿Cómo puedo solicitar una factura fiscal de mi compra?'),
  ('cancellation',           '¿Puedo cancelar / anular mi pedido una vez que ya lo pagué?'),
  ('claim_period',           '¿Cuánto tiempo tengo para hacer un reclamo si las flores no llegaron frescas?'),
];

// Keys cuya respuesta se construye automáticamente desde los datos de la florería.
// El campo `answer` actúa como nota adicional opcional.
// Se activan (isVisible = true) al sembrar porque siempre tienen contenido.
const _kAutoAnsweredKeys = {'delivery_cost'};

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

  /// Pending = default question that needs a typed answer (excludes auto-answered).
  List<FaqItem> get _pendingFaqs => _faqs
      .where((f) =>
          f.defaultKey != null &&
          f.answer.trim().isEmpty &&
          !_kAutoAnsweredKeys.contains(f.defaultKey))
      .toList();

  List<FaqItem> get _answeredFaqs => _faqs
      .where((f) => !(f.defaultKey != null &&
          f.answer.trim().isEmpty &&
          !_kAutoAnsweredKeys.contains(f.defaultKey)))
      .toList();

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
        });
        _seedDefaultFaqs();
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _seedDefaultFaqs() {
    final existingKeys = _faqs
        .where((f) => f.defaultKey != null)
        .map((f) => f.defaultKey!)
        .toSet();

    bool added = false;
    for (final (key, question) in _kDefaultFaqs) {
      if (!existingKeys.contains(key)) {
        _faqs.add(FaqItem(
          question: question,
          answer: '',
          // Auto-answered keys are visible immediately; others start paused.
          isVisible: _kAutoAnsweredKeys.contains(key),
          defaultKey: key,
        ));
        added = true;
      }
    }

    setState(() => _isLoading = false);
    if (added) _saveSettings();
  }

  Future<void> _saveSettings() async {
    if (_settings == null) return;
    final newSettings = ShopSettingsModel(
      storeHours: _settings!.storeHours,
      deliveryRanges: _settings!.deliveryRanges,
      shippingRates: _settings!.shippingRates,
      bankMethods: _settings!.bankMethods,
      linkMethods: _settings!.linkMethods,
      faqs: _faqs,
      simplePayments: _settings!.simplePayments,
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
      trackingLinkEnabled: _settings!.trackingLinkEnabled,
      showReviews: _settings!.showReviews,
      isUnavailable: _settings!.isUnavailable,
      unavailableMessage: _settings!.unavailableMessage,
      sellGiftsStandalone: _settings!.sellGiftsStandalone,
      catalogMessage: _settings!.catalogMessage,
      catalogImageUrl: _settings!.catalogImageUrl,
    );
    await _repo.updateSettings(_shopId, newSettings);
    _settings = newSettings;
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final pending  = _pendingFaqs;
    final answered = _answeredFaqs;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Ayuda e Información',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 2,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _buildAddButton(),
                const SizedBox(height: 24),

                if (pending.isNotEmpty) ...[
                  _buildSectionHeader(
                    'POR RESPONDER',
                    '${pending.length} pregunta${pending.length == 1 ? '' : 's'} esperando tu respuesta',
                    Colors.amber.shade700,
                    Icons.schedule_rounded,
                  ),
                  const SizedBox(height: 12),
                  ...pending.map((faq) => _buildFaqCard(faq)),
                  const SizedBox(height: 24),
                ],

                if (answered.isNotEmpty) ...[
                  if (pending.isNotEmpty)
                    _buildSectionHeader(
                      'RESPONDIDAS',
                      '${answered.length} pregunta${answered.length == 1 ? '' : 's'}',
                      Colors.green.shade700,
                      Icons.check_circle_outline,
                    ),
                  if (pending.isNotEmpty) const SizedBox(height: 12),
                  ...answered.map((faq) => _buildFaqCard(faq)),
                ],

                const SizedBox(height: 40),
              ],
            ),
    );
  }

  // ─── Section header ───────────────────────────────────────────────────────

  Widget _buildSectionHeader(
      String title, String subtitle, Color color, IconData icon) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: 0.8)),
            Text(subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ],
    );
  }

  // ─── Add Button ───────────────────────────────────────────────────────────

  Widget _buildAddButton() {
    return InkWell(
      onTap: () => _openFaqDialog(),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                  color: AppTheme.primary, shape: BoxShape.circle),
              child: const Icon(Icons.add, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('Agregar Nueva Pregunta',
                style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ],
        ),
      ),
    );
  }

  // ─── FAQ Card ─────────────────────────────────────────────────────────────

  Widget _buildFaqCard(FaqItem faq) {
    final isAuto    = _kAutoAnsweredKeys.contains(faq.defaultKey);
    final isPending = faq.defaultKey != null &&
        faq.answer.trim().isEmpty &&
        !isAuto;
    final isDefault = faq.defaultKey != null;
    final idx       = _faqs.indexOf(faq);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPending
              ? Colors.amber.shade300
              : isAuto
                  ? AppTheme.primary.withValues(alpha: 0.25)
                  : Colors.grey.withValues(alpha: 0.1),
          width: (isPending || isAuto) ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Auto-answer banner
          if (isAuto)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.06),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome,
                      size: 13, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Respuesta automática · edita para agregar nota',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary),
                  ),
                ],
              ),
            ),

          // Pending banner
          if (isPending)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit_note_rounded,
                      size: 14, color: Colors.amber.shade700),
                  const SizedBox(width: 6),
                  Text(
                    'Pregunta sugerida · sin respuesta',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.shade700),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(20),
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
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.mutedLight,
                                  letterSpacing: 0.8)),
                          const SizedBox(height: 4),
                          Text(faq.question,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textLight)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildActionCircle(
                      icon: isPending
                          ? Icons.reply_rounded
                          : Icons.edit_outlined,
                      bgColor: isPending
                          ? Colors.amber.shade50
                          : AppTheme.primary.withValues(alpha: 0.08),
                      iconColor: isPending
                          ? Colors.amber.shade700
                          : AppTheme.primary,
                      onTap: () => _openFaqDialog(faq: faq),
                    ),
                    if (!isDefault) ...[
                      const SizedBox(width: 6),
                      _buildActionCircle(
                        icon: Icons.delete_outline,
                        bgColor: Colors.red.shade50,
                        iconColor: Colors.red,
                        onTap: () => _confirmDelete(idx),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 14),

                // Auto-answer preview
                if (isAuto) ...[
                  Text('RESPUESTA AUTOMÁTICA',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary.withValues(alpha: 0.7),
                          letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  _buildAutoPreview(faq.defaultKey!),
                  if (faq.answer.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('NOTA ADICIONAL',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.mutedLight,
                            letterSpacing: 0.8)),
                    const SizedBox(height: 4),
                    Text(faq.answer,
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.mutedLight,
                            height: 1.5)),
                  ],
                ] else ...[
                  // Regular answer
                  const Text('RESPUESTA',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.mutedLight,
                          letterSpacing: 0.8)),
                  const SizedBox(height: 4),
                  isPending
                      ? Text(
                          'Toca el botón para responder esta pregunta.',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade400,
                              fontStyle: FontStyle.italic,
                              height: 1.5),
                        )
                      : Text(faq.answer,
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.mutedLight,
                              height: 1.5)),
                ],

                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFF3F4F6)),
                const SizedBox(height: 12),

                // Visibility toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Visible en perfil público',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isPending
                              ? Colors.grey.shade400
                              : AppTheme.mutedLight),
                    ),
                    Switch(
                      value: faq.isVisible,
                      onChanged: isPending
                          ? null
                          : (val) {
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
          ),
        ],
      ),
    );
  }

  // ─── Auto-answer preview (florist management) ─────────────────────────────

  Widget _buildAutoPreview(String key) {
    if (key == 'delivery_cost') {
      final rates = _settings?.shippingRates ?? [];
      if (rates.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Aún no tienes tarifas configuradas. Ve a Perfil → Sucursal → Tarifas de envío.',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        );
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rates.map((r) {
            final label = (r.label != null && r.label!.isNotEmpty)
                ? r.label!
                : [r.ciudad, r.estado]
                    .where((s) => s != null && s!.isNotEmpty)
                    .join(', ');
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Text('• ',
                      style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  Expanded(
                    child: Text(label,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black87)),
                  ),
                  Text('\$${r.costo.toStringAsFixed(2)} MXN',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary)),
                ],
              ),
            );
          }).toList(),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildActionCircle(
      {required IconData icon,
      required Color bgColor,
      required Color iconColor,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 18),
      ),
    );
  }

  // ─── Dialog ───────────────────────────────────────────────────────────────

  void _openFaqDialog({FaqItem? faq}) {
    final isAuto      = _kAutoAnsweredKeys.contains(faq?.defaultKey);
    final questionCtrl = TextEditingController(text: faq?.question ?? '');
    final answerCtrl   = TextEditingController(text: faq?.answer ?? '');
    final isPending    = faq != null &&
        faq.defaultKey != null &&
        faq.answer.trim().isEmpty &&
        !isAuto;
    final isEditing = faq != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4))),
              ),
              const SizedBox(height: 20),

              Text(
                isAuto
                    ? 'Nota adicional'
                    : isPending
                        ? 'Responder pregunta'
                        : (isEditing ? 'Editar Pregunta' : 'Nueva Pregunta'),
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // For auto-answered: show live preview, skip question field
              if (isAuto) ...[
                Text('RESPUESTA AUTOMÁTICA',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                        letterSpacing: 0.8)),
                const SizedBox(height: 8),
                _buildAutoPreview(faq!.defaultKey!),
                const SizedBox(height: 20),
                _buildDialogField(
                  'Nota adicional (opcional)',
                  answerCtrl,
                  hint: 'Ej. Consulta zonas no listadas por WhatsApp.',
                  maxLines: 3,
                ),
              ] else ...[
                _buildDialogField('Pregunta', questionCtrl,
                    hint: '¿Cómo pueden contactarme?'),
                const SizedBox(height: 16),
                _buildDialogField('Respuesta', answerCtrl,
                    hint: 'Escribe una respuesta clara y breve...',
                    maxLines: 4),
              ],

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (!isAuto && questionCtrl.text.trim().isEmpty) return;
                    setState(() {
                      if (isEditing) {
                        if (!isAuto) faq.question = questionCtrl.text.trim();
                        faq.answer = answerCtrl.text.trim();
                        if (faq.defaultKey != null && !isAuto && faq.answer.isNotEmpty) {
                          faq.isVisible = true;
                        }
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
                        content: Text(isEditing
                            ? '✅ Pregunta actualizada.'
                            : '✅ Pregunta agregada.'),
                        backgroundColor: AppTheme.primary,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPending
                        ? Colors.amber.shade600
                        : AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(
                    isAuto
                        ? 'Guardar nota'
                        : isPending
                            ? 'Guardar respuesta'
                            : (isEditing
                                ? 'Guardar cambios'
                                : 'Agregar pregunta'),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDialogField(String label, TextEditingController ctrl,
      {String? hint, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textLight)),
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
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: Colors.grey.withValues(alpha: 0.2))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: Colors.grey.withValues(alpha: 0.2))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppTheme.primary, width: 1.5)),
          ),
        ),
      ],
    );
  }

  // ─── Delete ───────────────────────────────────────────────────────────────

  void _confirmDelete(int idx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar pregunta',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
            '¿Estás seguro de que quieres eliminar esta pregunta? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar',
                style: TextStyle(color: AppTheme.mutedLight)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _faqs.removeAt(idx));
              _saveSettings();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Pregunta eliminada.'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating),
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
