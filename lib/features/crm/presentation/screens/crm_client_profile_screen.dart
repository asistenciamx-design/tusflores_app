import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../orders/domain/models/order_model.dart';
import '../../../orders/presentation/screens/edit_order_screen.dart';

class CrmClientProfileScreen extends StatefulWidget {
  final String name;
  final String phone;
  final String email;
  final List<OrderModel> orders;

  const CrmClientProfileScreen({
    super.key,
    required this.name,
    required this.phone,
    required this.email,
    required this.orders,
  });

  @override
  State<CrmClientProfileScreen> createState() => _CrmClientProfileScreenState();
}

class _CrmClientProfileScreenState extends State<CrmClientProfileScreen> {
  final _noteCtrl = TextEditingController();
  final List<_InternalNote> _notes = [];
  bool _isLoadingNotes = true;
  bool _isSavingNote = false;
  DateTime? _lastNoteSavedAt;

  // Datos editables del cliente (null = usar los de la orden)
  String? _editedName;
  String? _editedEmail;
  List<String> _extraPhones = [];

  // Clave única del cliente para las tablas crm_*
  // Prioridad: teléfono > email > nombre (el nombre puede no ser único)
  String get _clientKey {
    if (widget.phone.isNotEmpty) return widget.phone;
    if (widget.email.isNotEmpty) return widget.email;
    return widget.name;
  }

  // Valores mostrados: editados > originales de la orden
  String get _displayName => (_editedName?.isNotEmpty == true) ? _editedName! : widget.name;
  String get _displayEmail => (_editedEmail?.isNotEmpty == true) ? _editedEmail! : widget.email;

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _loadClientData();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  // ── Supabase: cargar notas ────────────────────────────────────────────────

  Future<void> _loadNotes() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingNotes = false);
      return;
    }
    try {
      final rows = await Supabase.instance.client
          .from('crm_notes')
          .select()
          .eq('shop_id', user.id)
          .eq('client_key', _clientKey)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _notes.clear();
          for (final r in rows) {
            _notes.add(_InternalNote(
              id: r['id'] as String,
              text: r['note'] as String,
              createdAt: DateTime.parse(r['created_at'] as String),
            ));
          }
          _isLoadingNotes = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingNotes = false);
    }
  }

  // ── Supabase: agregar nota (guarda inmediatamente) ────────────────────────

  Future<void> _addNote() async {
    final text = _noteCtrl.text.trim();
    final now = DateTime.now();
    if (text.isEmpty || _isSavingNote) return;
    if (_lastNoteSavedAt != null &&
        now.difference(_lastNoteSavedAt!).inSeconds < 3) {
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // Actualización optimista en la UI
    final optimistic = _InternalNote(id: '', text: text, createdAt: DateTime.now());
    setState(() {
      _notes.insert(0, optimistic);
      _isSavingNote = true;
    });
    _noteCtrl.clear();

    try {
      final result = await Supabase.instance.client
          .from('crm_notes')
          .insert({
            'shop_id': user.id,
            'client_key': _clientKey,
            'note': text,
          })
          .select()
          .single();

      if (mounted) {
        setState(() {
          final idx = _notes.indexOf(optimistic);
          if (idx >= 0) {
            _notes[idx] = _InternalNote(
              id: result['id'] as String,
              text: text,
              createdAt: DateTime.parse(result['created_at'] as String),
            );
          }
          _isSavingNote = false;
          _lastNoteSavedAt = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _notes.remove(optimistic);
          _isSavingNote = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar la nota. Intenta de nuevo.')),
        );
        _noteCtrl.text = text;
      }
    }
  }

  // ── Supabase: cargar datos editables del cliente ─────────────────────────

  Future<void> _loadClientData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final row = await Supabase.instance.client
          .from('crm_clients')
          .select()
          .eq('shop_id', user.id)
          .eq('client_key', _clientKey)
          .maybeSingle();
      if (row != null && mounted) {
        setState(() {
          _editedName = row['display_name'] as String?;
          _editedEmail = row['email'] as String?;
          final phones = row['extra_phones'];
          if (phones is List) {
            _extraPhones = List<String>.from(phones);
          }
        });
      }
    } catch (e) {
    }
  }

  Future<void> _saveClientData({
    required String name,
    required String email,
    required List<String> extraPhones,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    await Supabase.instance.client.from('crm_clients').upsert(
      {
        'shop_id': user.id,
        'client_key': _clientKey,
        'display_name': name.trim().isNotEmpty ? name.trim() : null,
        'email': email.trim().isNotEmpty ? email.trim() : null,
        'extra_phones': extraPhones.where((p) => p.trim().isNotEmpty).toList(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'shop_id,client_key',
    );
    if (mounted) {
      setState(() {
        _editedName = name.trim().isNotEmpty ? name.trim() : null;
        _editedEmail = email.trim().isNotEmpty ? email.trim() : null;
        _extraPhones = extraPhones.where((p) => p.trim().isNotEmpty).toList();
      });
    }
  }

  // ── Abrir hoja de edición del cliente ─────────────────────────────────────

  void _openEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditClientSheet(
        initialName: _displayName,
        initialEmail: _displayEmail,
        primaryPhone: widget.phone,
        initialExtraPhones: List<String>.from(_extraPhones),
        onSave: (name, email, extras) => _saveClientData(
          name: name,
          email: email,
          extraPhones: extras,
        ),
      ),
    );
  }

  // ── Computed getters ─────────────────────────────────────────────────────

  double get _totalSpent =>
      widget.orders.fold(0.0, (sum, o) => sum + o.total);

  DateTime? get _clientSince {
    if (widget.orders.isEmpty) return null;
    return widget.orders
        .reduce((a, b) => a.createdAt.isBefore(b.createdAt) ? a : b)
        .createdAt;
  }

  List<OrderModel> get _sortedOrders => [...widget.orders]
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return '?';
  }

  String _monthFull(int m) {
    const months = [
      '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return months[m];
  }

  String _monthShort(int m) {
    const months = [
      '', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return months[m];
  }

  String _formatClientSince(DateTime? dt) {
    if (dt == null) return 'Nuevo cliente';
    return '${dt.day} de ${_monthFull(dt.month)}, ${dt.year}';
  }

  String _lastOrderLabel() {
    final last = _sortedOrders.isNotEmpty ? _sortedOrders.first : null;
    if (last == null) return '—';
    return '${last.createdAt.day} ${_monthShort(last.createdAt.month)}';
  }

  Future<void> _openWhatsApp() async {
    final digits = widget.phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('https://wa.me/52$digits');
    if (await canLaunchUrl(uri)) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    _buildProfileSection(),
                    const SizedBox(height: 4),
                    _buildStatsRow(),
                    const SizedBox(height: 24),
                    _buildContactSection(),
                    const SizedBox(height: 24),
                    _buildNotesSection(),
                    const SizedBox(height: 24),
                    _buildOrderHistorySection(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F8F7),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          _iconButton(Icons.arrow_back, () => Navigator.of(context).pop()),
          const Expanded(
            child: Text('Perfil del Cliente',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          ),
          _iconButton(Icons.edit_outlined, _openEditSheet),
        ],
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Icon(icon, color: Colors.black87, size: 20),
        ),
      );

  // ── Profile avatar + name ────────────────────────────────────────────────

  Widget _buildProfileSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.25), width: 3),
                ),
                child: CircleAvatar(
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                  child: Text(
                    _initials(_displayName),
                    style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary),
                  ),
                ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(_displayName,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87)),
          const SizedBox(height: 4),
          Text('Cliente desde: ${_formatClientSince(_clientSince)}',
              style: const TextStyle(fontSize: 12, color: AppTheme.mutedLight)),
        ],
      ),
    );
  }

  // ── Stats row ─────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _StatCard(label: 'PEDIDOS', value: widget.orders.length.toString()),
          const SizedBox(width: 10),
          _StatCard(
              label: '\$ TOTAL',
              value: '\$${_totalSpent.toStringAsFixed(0)}'),
          const SizedBox(width: 10),
          _StatCard(label: 'ÚLTIMO', value: _lastOrderLabel()),
        ],
      ),
    );
  }

  // ── Contact ───────────────────────────────────────────────────────────────

  Widget _buildContactSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('INFORMACIÓN DE CONTACTO'),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                // Teléfono principal
                _phoneRow(
                  phone: widget.phone.isNotEmpty ? widget.phone : '—',
                  label: 'Móvil Principal',
                  showWhatsApp: widget.phone.isNotEmpty,
                  onWhatsApp: _openWhatsApp,
                ),
                // Teléfonos extra
                ..._extraPhones.asMap().entries.map((e) {
                  final phone = e.value;
                  return Column(
                    children: [
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      _phoneRow(
                        phone: phone,
                        label: 'Teléfono adicional',
                        showWhatsApp: phone.isNotEmpty,
                        onWhatsApp: () async {
                          final digits = phone.replaceAll(RegExp(r'\D'), '');
                          final uri = Uri.parse('https://wa.me/52$digits');
                          if (await canLaunchUrl(uri)) {
                            launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                    ],
                  );
                }),
                const Divider(height: 1, indent: 16, endIndent: 16),
                // Email
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.mail_outline, color: AppTheme.primary, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_displayEmail.isNotEmpty ? _displayEmail : '—',
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                            const Text('Email Principal',
                                style: TextStyle(
                                    fontSize: 11, color: AppTheme.mutedLight)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _phoneRow({
    required String phone,
    required String label,
    required bool showWhatsApp,
    required VoidCallback onWhatsApp,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.call, color: AppTheme.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(phone,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.mutedLight)),
              ],
            ),
          ),
          if (showWhatsApp)
            GestureDetector(
              onTap: onWhatsApp,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.chat, color: Colors.white, size: 15),
                    SizedBox(width: 6),
                    Text('WhatsApp',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Notes ─────────────────────────────────────────────────────────────────

  Widget _buildNotesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('NOTAS INTERNAS'),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: AppTheme.primary.withValues(alpha: 0.1)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_isLoadingNotes)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))),
                  )
                else if (_notes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('Sin notas aún.',
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.mutedLight)),
                  )
                else
                  ..._notes.map((n) => _NoteItemWidget(note: n)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _noteCtrl,
                        style: const TextStyle(fontSize: 13),
                        maxLength: 500,
                        onSubmitted: (_) => _addNote(),
                        decoration: InputDecoration(
                          hintText: 'Agregar una nota...',
                          hintStyle: const TextStyle(
                              color: AppTheme.mutedLight, fontSize: 13),
                          filled: true,
                          fillColor: const Color(0xFFF6F8F7),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _addNote,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: _isSavingNote
                              ? AppTheme.primary.withValues(alpha: 0.5)
                              : AppTheme.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: _isSavingNote
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Row(
                                children: [
                                  Icon(Icons.add, color: Colors.white, size: 16),
                                  SizedBox(width: 4),
                                  Text('Agregar',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                      ),
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

  // ── Order history ─────────────────────────────────────────────────────────

  Widget _buildOrderHistorySection() {
    final displayed = _sortedOrders.take(5).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('HISTORIAL DE PEDIDOS',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.mutedLight,
                        letterSpacing: 0.8)),
                if (_sortedOrders.length > 5)
                  const Text('Ver todos',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          ...displayed.map((o) => _OrderTile(order: o)),
        ],
      ),
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8F7),
        border:
            Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.black87,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: const Text('Guardar Información',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.mutedLight,
                letterSpacing: 0.8)),
      );
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: AppTheme.primary.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.mutedLight,
                    letterSpacing: 0.5)),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primary)),
          ],
        ),
      ),
    );
  }
}

class _InternalNote {
  final String id;
  final String text;
  final DateTime createdAt;
  _InternalNote({required this.id, required this.text, required this.createdAt});
}

class _NoteItemWidget extends StatelessWidget {
  final _InternalNote note;
  const _NoteItemWidget({required this.note});

  @override
  Widget build(BuildContext context) {
    final dt = note.createdAt;
    final label =
        '${dt.day} ${_m(dt.month)}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8F7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(note.text,
              style: const TextStyle(fontSize: 13, color: Colors.black87)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppTheme.mutedLight)),
        ],
      ),
    );
  }

  String _m(int m) {
    const months = [
      '', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return months[m];
  }
}

// ── Edit client bottom sheet ──────────────────────────────────────────────────

class _EditClientSheet extends StatefulWidget {
  final String initialName;
  final String initialEmail;
  final String primaryPhone;
  final List<String> initialExtraPhones;
  final Future<void> Function(String name, String email, List<String> extras) onSave;

  const _EditClientSheet({
    required this.initialName,
    required this.initialEmail,
    required this.primaryPhone,
    required this.initialExtraPhones,
    required this.onSave,
  });

  @override
  State<_EditClientSheet> createState() => _EditClientSheetState();
}

class _EditClientSheetState extends State<_EditClientSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late List<TextEditingController> _phoneCtrllers;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _emailCtrl = TextEditingController(text: widget.initialEmail);
    _phoneCtrllers = widget.initialExtraPhones
        .map((p) => TextEditingController(text: p))
        .toList();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    for (final c in _phoneCtrllers) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final extras = _phoneCtrllers
          .map((c) => c.text.trim())
          .where((p) => p.isNotEmpty)
          .toList();
      await widget.onSave(_nameCtrl.text, _emailCtrl.text, extras);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar. Intenta de nuevo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Editar perfil del cliente',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _fieldLabel('Nombre'),
            _inputField(_nameCtrl, 'Nombre completo', Icons.person_outline),
            const SizedBox(height: 14),
            _fieldLabel('Email'),
            _inputField(_emailCtrl, 'correo@ejemplo.com', Icons.mail_outline),
            const SizedBox(height: 14),
            _fieldLabel('Teléfono principal'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, size: 16, color: AppTheme.mutedLight),
                  const SizedBox(width: 8),
                  Text(widget.primaryPhone.isNotEmpty ? widget.primaryPhone : '—',
                      style: const TextStyle(
                          fontSize: 14, color: AppTheme.mutedLight)),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Text('El teléfono principal no se puede editar aquí.',
                style: TextStyle(fontSize: 11, color: AppTheme.mutedLight)),
            const SizedBox(height: 16),
            _fieldLabel('Teléfonos adicionales'),
            ..._phoneCtrllers.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: _inputField(
                            e.value, 'Teléfono ${e.key + 2}', Icons.call_outlined,
                            isPhone: true),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() {
                          e.value.dispose();
                          _phoneCtrllers.removeAt(e.key);
                        }),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.remove, color: Colors.redAccent, size: 18),
                        ),
                      ),
                    ],
                  ),
                )),
            if (_phoneCtrllers.length < 5)
              TextButton.icon(
                onPressed: () => setState(() =>
                    _phoneCtrllers.add(TextEditingController())),
                icon: const Icon(Icons.add, size: 16, color: AppTheme.primary),
                label: const Text('Agregar teléfono',
                    style: TextStyle(color: AppTheme.primary, fontSize: 13)),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Guardar cambios',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.mutedLight,
                letterSpacing: 0.3)),
      );

  Widget _inputField(
      TextEditingController ctrl, String hint, IconData icon,
      {bool isPhone = false}) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(fontSize: 14),
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      maxLength: isPhone ? 20 : null,
      inputFormatters: isPhone
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.mutedLight, fontSize: 14),
        prefixIcon: Icon(icon, color: AppTheme.mutedLight, size: 18),
        filled: true,
        fillColor: const Color(0xFFF6F8F7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        counterText: '',
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final OrderModel order;
  const _OrderTile({required this.order});

  /// Convierte product_name aunque esté guardado como JSON array.
  /// Ej: '[{"name":"florero","qty":1,"price":1000}]' → 'florero'
  ///     'Orquídea Phalaenopsis'                      → 'Orquídea Phalaenopsis'
  String _readableProductName(String raw) {
    final trimmed = raw.trim();
    if (!trimmed.startsWith('[') && !trimmed.startsWith('{')) return raw;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is List && decoded.isNotEmpty) {
        return decoded.map((item) {
          final name =
              (item['name'] ?? item['product'] ?? 'Producto').toString();
          final qty = item['qty'] ?? item['quantity'] ?? 1;
          final qtyInt = qty is int ? qty : int.tryParse(qty.toString()) ?? 1;
          return qtyInt == 1 ? name : '$name x$qtyInt';
        }).join(', ');
      }
      if (decoded is Map) {
        return (decoded['name'] ?? decoded['product'] ?? raw).toString();
      }
    } catch (_) {}
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final dt = order.createdAt;
    final dateLabel = '${dt.day} de ${_monthFull(dt.month)}, ${dt.year}';
    final statusLabel = order.status == OrderStatus.delivered
        ? 'Entregado'
        : order.status == OrderStatus.cancelled
            ? 'Cancelado'
            : 'Pendiente';
    final statusColor = order.status == OrderStatus.delivered
        ? AppTheme.primary
        : order.status == OrderStatus.cancelled
            ? Colors.redAccent
            : Colors.orange;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EditOrderScreen(order: order)),
      ),
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppTheme.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_florist,
                color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Folio: ${order.folio}',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                        letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(_readableProductName(order.productName),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                Text(dateLabel,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.mutedLight)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('\$${order.total.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
              Text(statusLabel,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor)),
            ],
          ),
        ],
      ),
    ),
    );
  }

  String _monthFull(int m) {
    const months = [
      '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return months[m];
  }
}
