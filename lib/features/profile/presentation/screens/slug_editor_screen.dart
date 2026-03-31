import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/reserved_slugs.dart';
import '../../../../core/theme/app_theme.dart';

class SlugEditorScreen extends StatefulWidget {
  const SlugEditorScreen({super.key});

  @override
  State<SlugEditorScreen> createState() => _SlugEditorScreenState();
}

class _SlugEditorScreenState extends State<SlugEditorScreen> {
  final _ctrl = TextEditingController();
  final _supabase = Supabase.instance.client;

  String? _currentSlug;    // slug actual guardado en BD
  String? _currentPais;
  String _selectedPais = 'mx';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isChecking = false;

  // Resultado de la validación en tiempo real
  String? _errorMsg;
  bool? _isAvailable;

  Timer? _debounce;

  static const _countries = [
    {'code': 'mx', 'name': 'Mexico', 'flag': '🇲🇽'},
    {'code': 'co', 'name': 'Colombia', 'flag': '🇨🇴'},
    {'code': 'ar', 'name': 'Argentina', 'flag': '🇦🇷'},
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentSlug();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentSlug() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final row = await _supabase
          .from('slugs_registry')
          .select()
          .eq('entity_id', uid)
          .maybeSingle();
      if (row != null && mounted) {
        setState(() {
          _currentSlug = row['slug'] as String?;
          _currentPais = row['pais'] as String?;
          _selectedPais = _currentPais ?? 'mx';
          _ctrl.text = _currentSlug ?? '';
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  void _onSlugChanged(String value) {
    _debounce?.cancel();
    final slug = value.toLowerCase().trim();

    // Validación local inmediata
    final formatError = validateSlugFormat(slug);
    if (formatError != null) {
      setState(() {
        _errorMsg = formatError;
        _isAvailable = null;
        _isChecking = false;
      });
      return;
    }

    final reservedError = validateSlugReserved(slug);
    if (reservedError != null) {
      setState(() {
        _errorMsg = reservedError;
        _isAvailable = null;
        _isChecking = false;
      });
      return;
    }

    // Si es el slug actual del usuario, no hace falta verificar
    if (slug == _currentSlug && _selectedPais == _currentPais) {
      setState(() {
        _errorMsg = null;
        _isAvailable = true;
        _isChecking = false;
      });
      return;
    }

    setState(() {
      _isChecking = true;
      _errorMsg = null;
      _isAvailable = null;
    });

    // Debounce 500ms antes de consultar BD
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final response = await _supabase.rpc('check_slug_available', params: {
          'p_pais': _selectedPais,
          'p_slug': slug,
        });
        if (!mounted) return;
        final available = response as bool;
        setState(() {
          _isAvailable = available;
          _isChecking = false;
          _errorMsg = available ? null : 'Este slug ya está en uso';
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isChecking = false;
          _errorMsg = 'Error al verificar disponibilidad';
        });
      }
    });
  }

  Future<void> _save() async {
    final slug = _ctrl.text.toLowerCase().trim();
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    // Validar de nuevo
    final fmtErr = validateSlugFormat(slug);
    if (fmtErr != null) {
      _showSnack(fmtErr, isError: true);
      return;
    }
    final resErr = validateSlugReserved(slug);
    if (resErr != null) {
      _showSnack(resErr, isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (_currentSlug != null) {
        // Actualizar slug existente
        await _supabase
            .from('slugs_registry')
            .update({
              'pais': _selectedPais,
              'slug': slug,
            })
            .eq('entity_id', uid);
      } else {
        // Crear nuevo slug
        await _supabase.from('slugs_registry').insert({
          'pais': _selectedPais,
          'slug': slug,
          'entity_type': 'floreria',
          'entity_id': uid,
        });
      }

      if (mounted) {
        setState(() {
          _currentSlug = slug;
          _currentPais = _selectedPais;
        });
        _showSnack('URL guardada correctamente');
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('uq_slug_per_country')) {
        _showSnack('Este slug ya está en uso', isError: true);
        setState(() {
          _isAvailable = false;
          _errorMsg = 'Este slug ya está en uso';
        });
      } else {
        _showSnack('Error al guardar: $msg', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final slug = _ctrl.text.toLowerCase().trim();
    final previewUrl = slug.isNotEmpty
        ? 'tusflores.app/$_selectedPais/$slug'
        : 'tusflores.app/$_selectedPais/tu-slug';

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Tu URL personalizada'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textLight,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Preview ───────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.link, color: AppTheme.primary, size: 32),
                        const SizedBox(height: 12),
                        Text(
                          previewUrl,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: slug.isNotEmpty
                                ? AppTheme.textLight
                                : Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── País ──────────────────────────────────────────────
                  const Text(
                    'Pais',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedPais,
                        isExpanded: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        borderRadius: BorderRadius.circular(12),
                        items: _countries.map((c) {
                          return DropdownMenuItem(
                            value: c['code'] as String,
                            child: Text(
                              '${c['flag']} ${c['name']}',
                              style: const TextStyle(fontSize: 15),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedPais = val);
                            _onSlugChanged(_ctrl.text);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Slug input ────────────────────────────────────────
                  const Text(
                    'Tu slug',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _ctrl,
                    onChanged: _onSlugChanged,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9-]')),
                      LengthLimitingTextInputFormatter(60),
                    ],
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'mi-floreria',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _errorMsg != null
                              ? Colors.red.shade300
                              : _isAvailable == true
                                  ? Colors.green.shade300
                                  : Colors.grey.shade300,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _errorMsg != null
                              ? Colors.red
                              : _isAvailable == true
                                  ? Colors.green
                                  : AppTheme.primary,
                          width: 2,
                        ),
                      ),
                      prefixText: 'tusflores.app/$_selectedPais/',
                      prefixStyle: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                      suffixIcon: _buildSuffixIcon(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_errorMsg != null)
                    Text(
                      _errorMsg!,
                      style: TextStyle(color: Colors.red.shade600, fontSize: 13),
                    ),
                  if (_isAvailable == true && _errorMsg == null)
                    const Text(
                      'Disponible',
                      style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'Solo letras minusculas (a-z), numeros y guiones. Sin acentos ni simbolos.',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                  const SizedBox(height: 32),

                  // ── Guardar ───────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_isAvailable == true && !_isSaving && !_isChecking)
                          ? _save
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _currentSlug != null
                                  ? 'Actualizar URL'
                                  : 'Guardar URL',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  if (_currentSlug != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Colors.amber.shade700, size: 20),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Si cambias tu URL, la anterior dejara de funcionar inmediatamente.',
                              style: TextStyle(fontSize: 13, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget? _buildSuffixIcon() {
    if (_isChecking) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_errorMsg != null) {
      return const Icon(Icons.close, color: Colors.red);
    }
    if (_isAvailable == true) {
      return const Icon(Icons.check_circle, color: Colors.green);
    }
    return null;
  }
}
