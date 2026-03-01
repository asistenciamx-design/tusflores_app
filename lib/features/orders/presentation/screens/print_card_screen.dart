import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../core/theme/app_theme.dart';

class PrintCardScreen extends StatefulWidget {
  final String initialMessage;

  const PrintCardScreen({super.key, required this.initialMessage});

  @override
  State<PrintCardScreen> createState() => _PrintCardScreenState();
}

class _PrintCardScreenState extends State<PrintCardScreen> {
  late TextEditingController _messageCtrl;

  // Print settings
  double _fontSize = 14.0;
  int _marginTopMm = 20;
  int _marginLeftMm = 15;
  int _marginRightMm = 15;
  String _selectedFont = 'Roboto';

  final List<String> _availableFonts = [
    'Roboto',
    'Lato',
    'Montserrat',
    'Dancing Script',
    'Pacifico',
    'Great Vibes',
  ];

  @override
  void initState() {
    super.initState();
    _messageCtrl = TextEditingController(text: widget.initialMessage);
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<pw.Font> _getFont(String fontName) async {
    switch (fontName) {
      case 'Lato':
        return await PdfGoogleFonts.latoRegular();
      case 'Montserrat':
        return await PdfGoogleFonts.montserratRegular();
      case 'Dancing Script':
        return await PdfGoogleFonts.dancingScriptRegular();
      case 'Pacifico':
        return await PdfGoogleFonts.pacificoRegular();
      case 'Great Vibes':
        return await PdfGoogleFonts.greatVibesRegular();
      case 'Roboto':
      default:
        return await PdfGoogleFonts.robotoRegular();
    }
  }

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final pdf = pw.Document(version: PdfVersion.pdf_1_5, compress: true);
    final font = await _getFont(_selectedFont);

    // 1 mm = 2.83465 points
    final double marginTop = _marginTopMm * 2.83465;
    final double marginLeft = _marginLeftMm * 2.83465;
    final double marginRight = _marginRightMm * 2.83465;

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.only(
          top: marginTop,
          left: marginLeft,
          right: marginRight,
          bottom: 20, // fixed bottom margin
        ),
        build: (context) {
          return pw.Text(
            _messageCtrl.text,
            style: pw.TextStyle(
              font: font,
              fontSize: _fontSize,
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Imprimir Dedicatoria', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left panel: Controls
          Container(
            width: 320,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(right: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mensaje a imprimir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.mutedLight)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _messageCtrl,
                    maxLines: 6,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primary)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text('Tipografía', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.mutedLight)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedFont,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primary)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: _availableFonts
                        .map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 14))))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedFont = val);
                    },
                  ),
                  const SizedBox(height: 24),

                  _buildSlider(
                    label: 'Tamaño de Fuente (${_fontSize.toInt()} px)',
                    value: _fontSize,
                    min: 8.0,
                    max: 24.0, // Allowing up to 24px just in case
                    onChanged: (val) => setState(() => _fontSize = val),
                  ),
                  const SizedBox(height: 16),
                  const Text('Márgenes (mm)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textDark)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMarginCounter(
                          'SUPERIOR',
                          _marginTopMm,
                          () => setState(() { if (_marginTopMm > 0) _marginTopMm--; }),
                          () => setState(() { _marginTopMm++; }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMarginCounter(
                          'IZQUIERDO',
                          _marginLeftMm,
                          () => setState(() { if (_marginLeftMm > 0) _marginLeftMm--; }),
                          () => setState(() { _marginLeftMm++; }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMarginCounter(
                          'DERECHO',
                          _marginRightMm,
                          () => setState(() { if (_marginRightMm > 0) _marginRightMm--; }),
                          () => setState(() { _marginRightMm++; }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final pdf = await _generatePdf(PdfPageFormat.letter);
                            await Printing.sharePdf(bytes: pdf, filename: 'dedicatoria.pdf');
                          },
                          icon: const Icon(Icons.picture_as_pdf, color: AppTheme.textDark, size: 20),
                          label: const Text('PDF', style: TextStyle(color: AppTheme.textDark)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final pdf = await _generatePdf(PdfPageFormat.letter);
                            await Printing.layoutPdf(onLayout: (format) => pdf);
                          },
                          icon: const Icon(Icons.print, color: Colors.white, size: 20),
                          label: const Text('Imprimir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF20D080), // Green from the mockup
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Right panel: Preview
          Expanded(
            child: Container(
              color: Colors.grey.shade200,
              child: PdfPreview(
                build: _generatePdf,
                initialPageFormat: PdfPageFormat.letter,
                canChangePageFormat: true,
                canChangeOrientation: true,
                useActions: false, // hide default toolbar
                allowPrinting: true,
                allowSharing: true,
                pdfFileName: 'dedicatoria.pdf',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarginCounter(String label, int value, VoidCallback onDecrement, VoidCallback onIncrement) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: onDecrement,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.grey.shade50, shape: BoxShape.circle),
                  child: const Icon(Icons.remove, size: 16, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 20,
                child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: onIncrement,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.grey.shade50, shape: BoxShape.circle),
                  child: const Icon(Icons.add, size: 16, color: Colors.grey),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlider({required String label, required double value, required double min, required double max, required ValueChanged<double> onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.mutedLight)),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: ((max - min) * 10).toInt(), // Snap to 0.1 intervals
          activeColor: AppTheme.primary,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
