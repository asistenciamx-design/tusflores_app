import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, FontLoader;
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';

// ── Template model ────────────────────────────────────────────────────────────
class _Template {
  String font;
  double fontSize;
  double marginTop;
  double marginLeft;
  double marginRight;
  bool bold;
  bool italic;
  bool strikethrough;
  String align;

  _Template({
    this.font = 'Manrope',
    this.fontSize = 14,
    this.marginTop = 1.0,
    this.marginLeft = 1.0,
    this.marginRight = 1.0,
    this.bold = false,
    this.italic = false,
    this.strikethrough = false,
    this.align = 'center',
  });

  String get label => font.split(' ').first;

  Map<String, dynamic> toJson() => {
        'font': font,
        'fontSize': fontSize,
        'marginTop': marginTop,
        'marginLeft': marginLeft,
        'marginRight': marginRight,
        'bold': bold,
        'italic': italic,
        'strikethrough': strikethrough,
        'align': align,
      };

  factory _Template.fromJson(Map<String, dynamic> j) => _Template(
        font: j['font'] ?? 'Manrope',
        fontSize: (j['fontSize'] as num?)?.toDouble() ?? 14,
        marginTop: (j['marginTop'] as num?)?.toDouble() ?? 1.0,
        marginLeft: (j['marginLeft'] as num?)?.toDouble() ?? 1.0,
        marginRight: (j['marginRight'] as num?)?.toDouble() ?? 1.0,
        bold: j['bold'] ?? false,
        italic: j['italic'] ?? false,
        strikethrough: j['strikethrough'] ?? false,
        align: j['align'] ?? 'center',
      );
}

// ── Screen ────────────────────────────────────────────────────────────────────
class PrintCardScreen extends StatefulWidget {
  final String initialMessage;
  const PrintCardScreen({super.key, required this.initialMessage});

  @override
  State<PrintCardScreen> createState() => _PrintCardScreenState();
}

class _PrintCardScreenState extends State<PrintCardScreen> {
  late final TextEditingController _messageCtrl;

  String _selectedFont = 'Manrope';
  double _fontSize = 14.0;
  bool _isBold = false;
  bool _isItalic = false;
  bool _isStrikethrough = false;
  TextAlign _textAlign = TextAlign.center;
  double _marginTopCm = 1.0;
  double _marginLeftCm = 1.0;
  double _marginRightCm = 1.0;

  // 3 saved template slots (null = empty)
  final List<_Template?> _templates = [null, null, null];

  bool _isPrinting = false;

  static const _prefTmplPrefix = 'print_template_';

  // ── Font catalogue ──────────────────────────────────────────────────────────
  static const _sansFonts = ['Manrope', 'Montserrat', 'Poppins', 'Lato', 'Roboto'];
  static const _scriptFonts = [
    'Dancing Script',
    'Great Vibes',
    'Caveat',
    'Pacifico',
    'Sacramento',
  ];

  // ── Emoji palette ───────────────────────────────────────────────────────────
  static const _emojis = [
    '🌹', '🌸', '💐', '🌺', '✨', '💖', '🎉', '🥰',
    '💝', '🌷', '🌻', '🍀', '🌿', '🦋', '⭐', '🎊',
  ];

  // ───────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _messageCtrl = TextEditingController(text: widget.initialMessage);
    _loadTemplates();
    _loadBundledFonts();
  }

  /// Pre-loads bundled script TTF assets into Flutter's font system so the
  /// preview renders correctly on Flutter Web (where GoogleFonts CDN may be
  /// blocked by CSP/CORS).
  Future<void> _loadBundledFonts() async {
    final families = {
      'DancingScript': [
        'assets/fonts/DancingScript-Regular.ttf',
        'assets/fonts/DancingScript-Bold.ttf',
      ],
      'GreatVibes':  ['assets/fonts/GreatVibes-Regular.ttf'],
      'Caveat':      ['assets/fonts/Caveat-Regular.ttf', 'assets/fonts/Caveat-Bold.ttf'],
      'Pacifico':    ['assets/fonts/Pacifico-Regular.ttf'],
      'Sacramento':  ['assets/fonts/Sacramento-Regular.ttf'],
    };
    for (final entry in families.entries) {
      final loader = FontLoader(entry.key);
      for (final path in entry.value) {
        loader.addFont(rootBundle.load(path));
      }
      await loader.load();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  // ── Persistence ─────────────────────────────────────────────────────────────
  Future<void> _loadTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      for (int i = 0; i < 3; i++) {
        final raw = prefs.getString('$_prefTmplPrefix${i + 1}');
        if (raw != null) {
          try {
            _templates[i] = _Template.fromJson(jsonDecode(raw));
          } catch (_) {}
        }
      }
    });
  }

  Future<void> _saveToSlot(int slot) async {
    final t = _Template(
      font: _selectedFont,
      fontSize: _fontSize,
      marginTop: _marginTopCm,
      marginLeft: _marginLeftCm,
      marginRight: _marginRightCm,
      bold: _isBold,
      italic: _isItalic,
      strikethrough: _isStrikethrough,
      align: _textAlign == TextAlign.left
          ? 'left'
          : _textAlign == TextAlign.right
              ? 'right'
              : 'center',
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefTmplPrefix$slot', jsonEncode(t.toJson()));
    if (!mounted) return;
    setState(() => _templates[slot - 1] = t);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Guardado en Plantilla $slot'),
      backgroundColor: AppTheme.primary,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _applyTemplate(_Template t) => setState(() {
        _selectedFont = t.font;
        _fontSize = t.fontSize;
        _marginTopCm = t.marginTop;
        _marginLeftCm = t.marginLeft;
        _marginRightCm = t.marginRight;
        _isBold = t.bold;
        _isItalic = t.italic;
        _isStrikethrough = t.strikethrough;
        _textAlign = t.align == 'left'
            ? TextAlign.left
            : t.align == 'right'
                ? TextAlign.right
                : TextAlign.center;
      });

  // ── PDF ─────────────────────────────────────────────────────────────────────
  /// Loads a bundled TTF asset and returns a [pw.Font].
  Future<pw.Font> _assetFont(String path) async {
    final data = await rootBundle.load(path);
    return pw.Font.ttf(data);
  }

  Future<pw.Font> _pdfFont() async {
    switch (_selectedFont) {
      // ── Sans-serif: fetched via PdfGoogleFonts (no DataView issues) ──
      case 'Montserrat':
        if (_isBold && _isItalic) return PdfGoogleFonts.montserratBoldItalic();
        if (_isBold) return PdfGoogleFonts.montserratBold();
        if (_isItalic) return PdfGoogleFonts.montserratItalic();
        return PdfGoogleFonts.montserratRegular();
      case 'Poppins':
        if (_isBold) return PdfGoogleFonts.poppinsBold();
        return PdfGoogleFonts.poppinsRegular();
      case 'Lato':
        if (_isBold) return PdfGoogleFonts.latoBold();
        return PdfGoogleFonts.latoRegular();
      case 'Roboto':
        if (_isBold) return PdfGoogleFonts.robotoBold();
        return PdfGoogleFonts.robotoRegular();
      // ── Script / display: fetched via PdfGoogleFonts (proven static TTFs) ──
      case 'Dancing Script':
        return _isBold
            ? PdfGoogleFonts.dancingScriptBold()
            : PdfGoogleFonts.dancingScriptRegular();
      case 'Great Vibes':
        return PdfGoogleFonts.greatVibesRegular();
      case 'Caveat':
        return _isBold
            ? PdfGoogleFonts.caveatBold()
            : PdfGoogleFonts.caveatRegular();
      case 'Pacifico':
        return PdfGoogleFonts.pacificoRegular();
      case 'Sacramento':
        return PdfGoogleFonts.sacramentoRegular();
      case 'Manrope':
      default:
        if (_isBold) return PdfGoogleFonts.manropeBold();
        return PdfGoogleFonts.manropeRegular();
    }
  }

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    const cmPt = 28.3465;
    final pdfAlign = _textAlign == TextAlign.left
        ? pw.TextAlign.left
        : _textAlign == TextAlign.right
            ? pw.TextAlign.right
            : pw.TextAlign.center;

    Future<Uint8List> buildWith(pw.Font f) async {
      // compress: false avoids zlib issues on Flutter Web
      final doc = pw.Document(version: PdfVersion.pdf_1_5, compress: false);
      doc.addPage(pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.only(
          top: _marginTopCm * cmPt,
          left: _marginLeftCm * cmPt,
          right: _marginRightCm * cmPt,
          bottom: 20,
        ),
        build: (_) => pw.SizedBox(
          width: double.infinity,
          child: pw.Text(
            _messageCtrl.text,
            textAlign: pdfAlign,
            style: pw.TextStyle(
              font: f,
              fontSize: _fontSize,
              decoration:
                  _isStrikethrough ? pw.TextDecoration.lineThrough : null,
            ),
          ),
        ),
      ));
      return Uint8List.fromList(await doc.save());
    }

    // Try with the selected Google Font; if any stage fails (download, TTF
    // parse, or PDF serialisation), fall back to the built-in Helvetica so
    // the user always gets a usable PDF.
    pw.Font font;
    bool usingFallback = false;
    try {
      font = await _pdfFont();
    } catch (_) {
      font = _isBold ? pw.Font.helveticaBold() : pw.Font.helvetica();
      usingFallback = true;
    }

    try {
      return await buildWith(font);
    } catch (_) {
      if (usingFallback) rethrow; // already on fallback — propagate the error
      return await buildWith(
          _isBold ? pw.Font.helveticaBold() : pw.Font.helvetica());
    }
  }

  // ── Preview text style ──────────────────────────────────────────────────────
  TextStyle _previewStyle() {
    TextStyle base;
    switch (_selectedFont) {
      case 'Montserrat':
        base = GoogleFonts.montserrat();
        break;
      case 'Poppins':
        base = GoogleFonts.poppins();
        break;
      case 'Lato':
        base = GoogleFonts.lato();
        break;
      case 'Roboto':
        base = GoogleFonts.roboto();
        break;
      case 'Dancing Script':
        base = const TextStyle(fontFamily: 'DancingScript');
        break;
      case 'Great Vibes':
        base = const TextStyle(fontFamily: 'GreatVibes');
        break;
      case 'Caveat':
        base = const TextStyle(fontFamily: 'Caveat');
        break;
      case 'Pacifico':
        base = const TextStyle(fontFamily: 'Pacifico');
        break;
      case 'Sacramento':
        base = const TextStyle(fontFamily: 'Sacramento');
        break;
      case 'Manrope':
      default:
        base = GoogleFonts.manrope();
    }
    return base.copyWith(
      fontSize: _fontSize.clamp(9.0, 20.0),
      fontWeight: _isBold ? FontWeight.bold : FontWeight.normal,
      fontStyle: _isItalic ? FontStyle.italic : FontStyle.normal,
      decoration:
          _isStrikethrough ? TextDecoration.lineThrough : TextDecoration.none,
      color: Colors.black87,
    );
  }

  // ── Action runner (loading + error handling) ────────────────────────────────
  Future<void> _runAction(Future<void> Function() action) async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  // ── Dialogs ─────────────────────────────────────────────────────────────────
  void _showSaveDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('¿Guardar en qué plantilla?',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            for (int i = 1; i <= 3; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor:
                      AppTheme.primary.withValues(alpha: 0.1),
                  child: Text('$i',
                      style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold)),
                ),
                title: Text(
                  _templates[i - 1] != null
                      ? 'Plantilla $i  ·  ${_templates[i - 1]!.label}'
                      : 'Plantilla $i  ·  vacía',
                  style: const TextStyle(fontSize: 14),
                ),
                trailing: const Icon(Icons.save_alt,
                    color: AppTheme.primary, size: 20),
                onTap: () {
                  Navigator.pop(ctx);
                  _saveToSlot(i);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Insertar Emoji',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _emojis
                  .map((e) => GestureDetector(
                        onTap: () {
                          final sel = _messageCtrl.selection;
                          final text = _messageCtrl.text;
                          final newText = sel.isValid
                              ? text.replaceRange(sel.start, sel.end, e)
                              : text + e;
                          _messageCtrl.value = TextEditingValue(
                            text: newText,
                            selection: TextSelection.collapsed(
                              offset: sel.isValid
                                  ? sel.start + e.length
                                  : newText.length,
                            ),
                          );
                          setState(() {});
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primary
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(e,
                              style: const TextStyle(fontSize: 24)),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      appBar: AppBar(
        title: const Text('Dedicatoria Impresa',
            style:
                TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFFF6F8F7),
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTemplatesRow(),
            const SizedBox(height: 14),
            _buildPreview(),
            const SizedBox(height: 18),
            _buildTextarea(),
            const SizedBox(height: 16),
            _buildTypographyRow(),
            const SizedBox(height: 16),
            _buildStyleRow(),
            const SizedBox(height: 16),
            _buildMarginsRow(),
            const SizedBox(height: 18),
            _buildSaveBtn(),
            const SizedBox(height: 20),
            _buildActionButtons(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Template slots ──────────────────────────────────────────────────────────
  Widget _buildTemplatesRow() {
    return Row(
      children: List.generate(3, (i) {
        final t = _templates[i];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
            child: GestureDetector(
              onTap: t != null ? () => _applyTemplate(t) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    vertical: 10, horizontal: 6),
                decoration: BoxDecoration(
                  color: t != null
                      ? AppTheme.primary.withValues(alpha: 0.08)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: t != null
                        ? AppTheme.primary.withValues(alpha: 0.3)
                        : Colors.grey.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      t != null ? Icons.text_fields : Icons.add,
                      size: 16,
                      color: t != null
                          ? AppTheme.primary
                          : Colors.grey[400],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      t != null ? t.label : 'Vacía',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: t != null
                            ? AppTheme.primary
                            : Colors.grey[400],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Plantilla ${i + 1}',
                      style: TextStyle(
                        fontSize: 9,
                        color: t != null
                            ? Colors.black45
                            : Colors.grey[300],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  // ── Preview ─────────────────────────────────────────────────────────────────
  Widget _buildPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'VISTA PREVIA',
          style: TextStyle(
            color: AppTheme.primary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        AspectRatio(
          aspectRatio: 5 / 3, // ~20 % shorter than 4/3
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.12)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            padding: const EdgeInsets.all(10),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.18)),
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Márgenes de impresión',
                      style: TextStyle(
                          color: Colors.grey[400], fontSize: 9)),
                  Expanded(
                    child: Center(
                      child: _messageCtrl.text.isEmpty
                          ? Text(
                              'Escribe tu mensaje abajo... 🌹✨',
                              style: TextStyle(
                                  color: Colors.grey[400],
                                  fontStyle: FontStyle.italic,
                                  fontSize: 11),
                              textAlign: TextAlign.center,
                            )
                          : Text(
                              _messageCtrl.text,
                              textAlign: _textAlign,
                              style: _previewStyle(),
                              overflow: TextOverflow.fade,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Textarea ────────────────────────────────────────────────────────────────
  Widget _buildTextarea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Contenido de la dedicatoria',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.black87)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.2)),
          ),
          child: TextField(
            controller: _messageCtrl,
            maxLines: 4,
            minLines: 3,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 14, color: Colors.black87),
            decoration: const InputDecoration(
              hintText: 'Escribe tu dedicatoria aquí... 🌹✨',
              hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(14),
            ),
          ),
        ),
      ],
    );
  }

  // ── Typography row: font | size stepper | emoji ─────────────────────────────
  Widget _buildTypographyRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          flex: 6,
          child: _labeled(
            'FUENTE',
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: _fieldBox(),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedFont,
                  isExpanded: true,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.black87),
                  items: [
                    ..._sansFonts.map((f) => DropdownMenuItem(
                        value: f,
                        child: Text(f,
                            style: const TextStyle(fontSize: 12)))),
                    const DropdownMenuItem(
                      value: '__sep__',
                      enabled: false,
                      child: Divider(height: 1),
                    ),
                    ..._scriptFonts.map((f) => DropdownMenuItem(
                        value: f,
                        child: Text(f,
                            style: const TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic)))),
                  ],
                  onChanged: (val) {
                    if (val != null && val != '__sep__') {
                      setState(() => _selectedFont = val);
                    }
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 4,
          child: _labeled(
            'TAMAÑO',
            _stepper(
              value: _fontSize,
              min: 8,
              max: 36,
              step: 1,
              display: _fontSize.toInt().toString(),
              onChanged: (v) => setState(() => _fontSize = v),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: _labeled(
            'EMOJI',
            SizedBox(
              height: 44,
              child: OutlinedButton(
                onPressed: _showEmojiPicker,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  side: BorderSide(
                      color: AppTheme.primary.withValues(alpha: 0.2)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  backgroundColor: Colors.white,
                ),
                child: const Icon(Icons.mood,
                    color: AppTheme.primary, size: 22),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Style + Alignment ────────────────────────────────────────────────────────
  Widget _buildStyleRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _toggleGroup([
          _styleBtn('B', _isBold,
              () => setState(() => _isBold = !_isBold),
              const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15)),
          _styleBtn(
              'I',
              _isItalic,
              () => setState(() => _isItalic = !_isItalic),
              const TextStyle(
                  fontStyle: FontStyle.italic, fontSize: 15)),
          _styleBtn(
              'S',
              _isStrikethrough,
              () => setState(
                  () => _isStrikethrough = !_isStrikethrough),
              const TextStyle(
                  decoration: TextDecoration.lineThrough,
                  fontSize: 15)),
        ]),
        _toggleGroup([
          _alignBtn(Icons.format_align_left, TextAlign.left),
          _alignBtn(Icons.format_align_center, TextAlign.center),
          _alignBtn(Icons.format_align_right, TextAlign.right),
        ]),
      ],
    );
  }

  // ── Margins row ─────────────────────────────────────────────────────────────
  Widget _buildMarginsRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('MÁRGENES (CM)',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: Colors.black54)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
                child: _marginCell('Superior', _marginTopCm,
                    (v) => setState(() => _marginTopCm = v))),
            const SizedBox(width: 8),
            Expanded(
                child: _marginCell('Izquierdo', _marginLeftCm,
                    (v) => setState(() => _marginLeftCm = v))),
            const SizedBox(width: 8),
            Expanded(
                child: _marginCell('Derecho', _marginRightCm,
                    (v) => setState(() => _marginRightCm = v))),
          ],
        ),
      ],
    );
  }

  Widget _marginCell(
      String label, double value, void Function(double) onChanged) {
    return Column(
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 4),
        _stepper(
          value: value,
          min: 0,
          max: 5,
          step: 0.5,
          display: value.toStringAsFixed(1),
          onChanged: onChanged,
        ),
      ],
    );
  }

  // ── Save template button ─────────────────────────────────────────────────────
  Widget _buildSaveBtn() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showSaveDialog,
            icon: const Icon(Icons.save, size: 20),
            label: const Text('GUARDAR PLANTILLA',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    fontSize: 13)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: BorderSide(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                  width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              backgroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Guarda tus ajustes de fuente y márgenes para futuras dedicatorias.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 10,
              color: Colors.grey,
              fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  // ── Action buttons ───────────────────────────────────────────────────────────
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _actionBtn(
            icon: _isPrinting ? Icons.hourglass_top : Icons.print,
            label: 'IMPRIMIR',
            bg: AppTheme.primary,
            fg: Colors.black87,
            shadow: true,
            enabled: !_isPrinting,
            onTap: () => _runAction(() async {
              final pdf = await _generatePdf(PdfPageFormat.letter);
              await Printing.layoutPdf(onLayout: (_) async => pdf);
            }),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _actionBtn(
            icon: Icons.picture_as_pdf,
            label: 'DESCARGAR',
            bg: AppTheme.primary.withValues(alpha: 0.12),
            fg: AppTheme.primary,
            shadow: false,
            enabled: !_isPrinting,
            onTap: () => _runAction(() async {
              final pdf = await _generatePdf(PdfPageFormat.letter);
              await Printing.sharePdf(bytes: pdf, filename: 'dedicatoria.pdf');
            }),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _actionBtn(
            icon: Icons.share,
            label: 'COMPARTIR',
            bg: AppTheme.primary.withValues(alpha: 0.12),
            fg: AppTheme.primary,
            shadow: false,
            enabled: !_isPrinting,
            onTap: () => _runAction(() async {
              final pdf = await _generatePdf(PdfPageFormat.letter);
              await Printing.sharePdf(bytes: pdf, filename: 'dedicatoria.pdf');
            }),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SMALL HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  BoxDecoration _fieldBox() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      );

  Widget _labeled(String label, Widget child) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: Colors.black54)),
          const SizedBox(height: 6),
          child,
        ],
      );

  Widget _stepper({
    required double value,
    required double min,
    required double max,
    required double step,
    required String display,
    required void Function(double) onChanged,
  }) {
    return Container(
      height: 44,
      decoration: _fieldBox(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _stepBtn(
            Icons.remove,
            value > min
                ? () => onChanged((value - step).clamp(min, max))
                : null,
          ),
          Text(display,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          _stepBtn(
            Icons.add,
            value < max
                ? () => onChanged((value + step).clamp(min, max))
                : null,
          ),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback? onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Icon(icon,
              size: 16,
              color: onTap != null
                  ? AppTheme.primary
                  : Colors.grey[300]),
        ),
      );

  Widget _toggleGroup(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(children: children),
      );

  Widget _styleBtn(String label, bool active, VoidCallback onTap,
      TextStyle style) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: active
              ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
              : null,
        ),
        child: Center(
          child: Text(label,
              style: style.copyWith(
                  color:
                      active ? AppTheme.primary : Colors.black54)),
        ),
      ),
    );
  }

  Widget _alignBtn(IconData icon, TextAlign align) {
    final active = _textAlign == align;
    return GestureDetector(
      onTap: () => setState(() => _textAlign = align),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: active
              ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
              : null,
        ),
        child: Icon(icon,
            size: 20,
            color: active ? AppTheme.primary : Colors.black54),
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color bg,
    required Color fg,
    required bool shadow,
    required bool enabled,
    required Future<void> Function() onTap,
  }) =>
      GestureDetector(
        onTap: enabled ? () { onTap(); } : null,
        child: Opacity(
          opacity: enabled ? 1.0 : 0.5,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              boxShadow: shadow && enabled
                  ? [
                      BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ]
                  : null,
            ),
            child: Column(
              children: [
                Icon(icon, color: fg, size: 22),
                const SizedBox(height: 4),
                Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: fg,
                        letterSpacing: 0.5)),
              ],
            ),
          ),
        ),
      );
}
