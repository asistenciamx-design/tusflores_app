import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';

class PrintCardScreen extends StatefulWidget {
  final String initialMessage;
  const PrintCardScreen({super.key, required this.initialMessage});

  @override
  State<PrintCardScreen> createState() => _PrintCardScreenState();
}

class _PrintCardScreenState extends State<PrintCardScreen> {
  late TextEditingController _messageCtrl;
  late TextEditingController _fontSizeCtrl;
  late TextEditingController _marginTopCtrl;
  late TextEditingController _marginLeftCtrl;
  late TextEditingController _marginRightCtrl;

  String _selectedFont = 'Manrope';
  double _fontSize = 14.0;
  bool _isBold = false;
  bool _isItalic = false;
  bool _isStrikethrough = false;
  TextAlign _textAlign = TextAlign.center;
  double _marginTopCm = 1.0;
  double _marginLeftCm = 1.0;
  double _marginRightCm = 1.0;

  static const _prefFont = 'print_font';
  static const _prefFontSize = 'print_font_size';
  static const _prefMarginTop = 'print_margin_top';
  static const _prefMarginLeft = 'print_margin_left';
  static const _prefMarginRight = 'print_margin_right';

  final List<Map<String, String>> _fonts = const [
    {'name': 'Manrope', 'label': 'Manrope (Sans)'},
    {'name': 'Playfair Display', 'label': 'Playfair Display (Serif)'},
    {'name': 'Dancing Script', 'label': 'Dancing Script (Cursiva)'},
    {'name': 'Montserrat', 'label': 'Montserrat'},
  ];

  final List<String> _commonEmojis = const [
    '🌹', '🌸', '💐', '🌺', '✨', '💖', '🎉', '🥰',
    '💝', '🌷', '🌻', '🍀', '🌿', '🦋', '⭐', '🎊',
  ];

  @override
  void initState() {
    super.initState();
    _messageCtrl = TextEditingController(text: widget.initialMessage);
    _fontSizeCtrl = TextEditingController(text: '14');
    _marginTopCtrl = TextEditingController(text: '1.0');
    _marginLeftCtrl = TextEditingController(text: '1.0');
    _marginRightCtrl = TextEditingController(text: '1.0');
    _loadTemplate();
  }

  Future<void> _loadTemplate() async {
    final prefs = await SharedPreferences.getInstance();
    final font = prefs.getString(_prefFont);
    final fontSize = prefs.getDouble(_prefFontSize);
    final top = prefs.getDouble(_prefMarginTop);
    final left = prefs.getDouble(_prefMarginLeft);
    final right = prefs.getDouble(_prefMarginRight);
    if (!mounted) return;
    setState(() {
      if (font != null) _selectedFont = font;
      if (fontSize != null) {
        _fontSize = fontSize;
        _fontSizeCtrl.text = fontSize.toInt().toString();
      }
      if (top != null) {
        _marginTopCm = top;
        _marginTopCtrl.text = top.toStringAsFixed(1);
      }
      if (left != null) {
        _marginLeftCm = left;
        _marginLeftCtrl.text = left.toStringAsFixed(1);
      }
      if (right != null) {
        _marginRightCm = right;
        _marginRightCtrl.text = right.toStringAsFixed(1);
      }
    });
  }

  Future<void> _saveTemplate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefFont, _selectedFont);
    await prefs.setDouble(_prefFontSize, _fontSize);
    await prefs.setDouble(_prefMarginTop, _marginTopCm);
    await prefs.setDouble(_prefMarginLeft, _marginLeftCm);
    await prefs.setDouble(_prefMarginRight, _marginRightCm);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Plantilla guardada'),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _fontSizeCtrl.dispose();
    _marginTopCtrl.dispose();
    _marginLeftCtrl.dispose();
    _marginRightCtrl.dispose();
    super.dispose();
  }

  Future<pw.Font> _getPdfFont({bool bold = false, bool italic = false}) async {
    switch (_selectedFont) {
      case 'Playfair Display':
        if (bold) return await PdfGoogleFonts.playfairDisplayBold();
        return await PdfGoogleFonts.playfairDisplayRegular();
      case 'Dancing Script':
        if (bold) return await PdfGoogleFonts.dancingScriptBold();
        return await PdfGoogleFonts.dancingScriptRegular();
      case 'Montserrat':
        if (bold && italic) return await PdfGoogleFonts.montserratBoldItalic();
        if (bold) return await PdfGoogleFonts.montserratBold();
        if (italic) return await PdfGoogleFonts.montserratItalic();
        return await PdfGoogleFonts.montserratRegular();
      case 'Manrope':
      default:
        if (bold) return await PdfGoogleFonts.manropeBold();
        return await PdfGoogleFonts.manropeRegular();
    }
  }

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final pdf = pw.Document(version: PdfVersion.pdf_1_5, compress: true);
    final font = await _getPdfFont(bold: _isBold, italic: _isItalic);

    const double cmToPoints = 28.3465;
    final double marginTop = _marginTopCm * cmToPoints;
    final double marginLeft = _marginLeftCm * cmToPoints;
    final double marginRight = _marginRightCm * cmToPoints;

    pw.TextAlign pdfAlign;
    switch (_textAlign) {
      case TextAlign.left:
        pdfAlign = pw.TextAlign.left;
        break;
      case TextAlign.right:
        pdfAlign = pw.TextAlign.right;
        break;
      default:
        pdfAlign = pw.TextAlign.center;
    }

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.only(
          top: marginTop,
          left: marginLeft,
          right: marginRight,
          bottom: 20,
        ),
        build: (context) {
          return pw.Text(
            _messageCtrl.text,
            textAlign: pdfAlign,
            style: pw.TextStyle(
              font: font,
              fontSize: _fontSize,
              decoration: _isStrikethrough ? pw.TextDecoration.lineThrough : null,
            ),
          );
        },
      ),
    );
    return pdf.save();
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
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _commonEmojis
                  .map((emoji) => GestureDetector(
                        onTap: () {
                          final sel = _messageCtrl.selection;
                          final text = _messageCtrl.text;
                          final newText = sel.isValid
                              ? text.replaceRange(sel.start, sel.end, emoji)
                              : text + emoji;
                          _messageCtrl.value = TextEditingValue(
                            text: newText,
                            selection: TextSelection.collapsed(
                              offset: sel.isValid
                                  ? sel.start + emoji.length
                                  : newText.length,
                            ),
                          );
                          setState(() {});
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(emoji,
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

  TextStyle _previewTextStyle() {
    TextStyle base;
    switch (_selectedFont) {
      case 'Playfair Display':
        base = GoogleFonts.playfairDisplay();
        break;
      case 'Dancing Script':
        base = GoogleFonts.dancingScript();
        break;
      case 'Montserrat':
        base = GoogleFonts.montserrat();
        break;
      case 'Manrope':
      default:
        base = GoogleFonts.manrope();
    }
    return base.copyWith(
      fontSize: _fontSize.clamp(10.0, 18.0),
      fontWeight: _isBold ? FontWeight.bold : FontWeight.normal,
      fontStyle: _isItalic ? FontStyle.italic : FontStyle.normal,
      decoration:
          _isStrikethrough ? TextDecoration.lineThrough : TextDecoration.none,
      color: Colors.black87,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      appBar: AppBar(
        title: const Text('Dedicatoria Impresa',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
            _buildPreviewSection(),
            const SizedBox(height: 24),
            _buildTextSection(),
            const SizedBox(height: 20),
            _buildTypographyRow(),
            const SizedBox(height: 20),
            _buildStyleAndAlignment(),
            const SizedBox(height: 20),
            _buildMargins(),
            const SizedBox(height: 20),
            _buildSaveTemplateButton(),
            const SizedBox(height: 24),
            _buildActionButtons(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewSection() {
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
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 4 / 3,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.12)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.18),
                    style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Márgenes de impresión',
                    style: TextStyle(color: Colors.grey[400], fontSize: 10),
                  ),
                  Expanded(
                    child: Center(
                      child: _messageCtrl.text.isEmpty
                          ? Text(
                              'Escribe tu mensaje abajo... 🌹✨',
                              style: TextStyle(
                                  color: Colors.grey[400],
                                  fontStyle: FontStyle.italic,
                                  fontSize: 13),
                              textAlign: TextAlign.center,
                            )
                          : Text(
                              _messageCtrl.text,
                              textAlign: _textAlign,
                              style: _previewTextStyle(),
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

  Widget _buildTextSection() {
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
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
          ),
          child: TextField(
            controller: _messageCtrl,
            maxLines: 5,
            minLines: 4,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 14, color: Colors.black87),
            decoration: const InputDecoration(
              hintText: 'Escribe tu dedicatoria aquí... 🌹✨',
              hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypographyRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Fuente
        Expanded(
          flex: 6,
          child: _labeledField(
            label: 'FUENTE',
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.2)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedFont,
                  isExpanded: true,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.black87),
                  items: _fonts
                      .map((f) => DropdownMenuItem(
                          value: f['name'],
                          child: Text(f['label']!,
                              style: const TextStyle(fontSize: 12))))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedFont = val);
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Tamaño
        Expanded(
          flex: 3,
          child: _labeledField(
            label: 'TAMAÑO',
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.2)),
              ),
              child: TextField(
                controller: _fontSizeCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                    fontSize: 14, color: Colors.black87),
                onChanged: (val) {
                  final n = double.tryParse(val);
                  if (n != null && n >= 8 && n <= 24) {
                    setState(() => _fontSize = n);
                  }
                },
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Emoji
        Expanded(
          flex: 3,
          child: _labeledField(
            label: 'EMOJI',
            child: SizedBox(
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

  Widget _labeledField({required String label, required Widget child}) {
    return Column(
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
  }

  Widget _buildStyleAndAlignment() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // B I S
        _toggleGroup(children: [
          _styleToggle(
              label: 'B',
              active: _isBold,
              onTap: () => setState(() => _isBold = !_isBold),
              textStyle: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15)),
          _styleToggle(
              label: 'I',
              active: _isItalic,
              onTap: () => setState(() => _isItalic = !_isItalic),
              textStyle: const TextStyle(
                  fontStyle: FontStyle.italic, fontSize: 15)),
          _styleToggle(
              label: 'S',
              active: _isStrikethrough,
              onTap: () =>
                  setState(() => _isStrikethrough = !_isStrikethrough),
              textStyle: const TextStyle(
                  decoration: TextDecoration.lineThrough, fontSize: 15)),
        ]),
        // Alignment
        _toggleGroup(children: [
          _alignToggle(Icons.format_align_left, TextAlign.left),
          _alignToggle(Icons.format_align_center, TextAlign.center),
          _alignToggle(Icons.format_align_right, TextAlign.right),
        ]),
      ],
    );
  }

  Widget _toggleGroup({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(children: children),
    );
  }

  Widget _styleToggle({
    required String label,
    required bool active,
    required VoidCallback onTap,
    required TextStyle textStyle,
  }) {
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
          child: Text(
            label,
            style: textStyle.copyWith(
                color: active ? AppTheme.primary : Colors.black54),
          ),
        ),
      ),
    );
  }

  Widget _alignToggle(IconData icon, TextAlign align) {
    final isActive = _textAlign == align;
    return GestureDetector(
      onTap: () => setState(() => _textAlign = align),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive
              ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
              : null,
        ),
        child: Icon(icon,
            size: 20,
            color: isActive ? AppTheme.primary : Colors.black54),
      ),
    );
  }

  Widget _buildMargins() {
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
              child: _marginField('Superior', _marginTopCtrl,
                  (v) => setState(() => _marginTopCm = v)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _marginField('Izquierdo', _marginLeftCtrl,
                  (v) => setState(() => _marginLeftCm = v)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _marginField('Derecho', _marginRightCtrl,
                  (v) => setState(() => _marginRightCm = v)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _marginField(String label, TextEditingController ctrl,
      void Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
          ),
          child: TextField(
            controller: ctrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
            onChanged: (val) {
              final n = double.tryParse(val);
              if (n != null && n >= 0) onChanged(n);
            },
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveTemplateButton() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _saveTemplate,
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

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _actionButton(
            icon: Icons.print,
            label: 'IMPRIMIR',
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.black87,
            hasShadow: true,
            onTap: () async {
              final pdf = await _generatePdf(PdfPageFormat.letter);
              await Printing.layoutPdf(onLayout: (format) => pdf);
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _actionButton(
            icon: Icons.picture_as_pdf,
            label: 'DESCARGAR',
            backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
            foregroundColor: AppTheme.primary,
            hasShadow: false,
            onTap: () async {
              final pdf = await _generatePdf(PdfPageFormat.letter);
              await Printing.sharePdf(
                  bytes: pdf, filename: 'dedicatoria.pdf');
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _actionButton(
            icon: Icons.share,
            label: 'COMPARTIR',
            backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
            foregroundColor: AppTheme.primary,
            hasShadow: false,
            onTap: () async {
              final pdf = await _generatePdf(PdfPageFormat.letter);
              await Printing.sharePdf(
                  bytes: pdf, filename: 'dedicatoria.pdf');
            },
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
    required bool hasShadow,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: hasShadow
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
            Icon(icon, color: foregroundColor, size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: foregroundColor,
                    letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }
}
