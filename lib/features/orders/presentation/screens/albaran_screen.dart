import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_cache.dart';
import '../../domain/models/order_model.dart';

class AlbaranScreen extends StatefulWidget {
  final OrderModel order;
  final String shopName;
  final String? shopTagline;

  const AlbaranScreen({
    super.key,
    required this.order,
    required this.shopName,
    this.shopTagline,
  });

  @override
  State<AlbaranScreen> createState() => _AlbaranScreenState();
}

class _AlbaranScreenState extends State<AlbaranScreen> {
  // ── Visibility toggles ───────────────────────────────────────────────────
  bool _showFolio = true;
  bool _showDestinatario = true;
  bool _showDireccion = true;
  bool _showProducto = true;
  bool _showFoto = true;
  bool _showPrecio = false;

  // ── Format options ───────────────────────────────────────────────────────
  bool _isHorizontal = false;
  bool _isMediaSize = false;
  String _selectedFont = 'Manrope';
  double _fontSize = 10.0;

  bool _isPrinting = false;

  static const _sansFonts = [
    'Manrope',
    'Montserrat',
    'Lato',
    'Roboto',
    'Poppins',
  ];



  // ── Parsed product names ─────────────────────────────────────────────────
  List<Map<String, dynamic>> get _products {
    try {
      final list = jsonDecode(widget.order.productName) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [
        {'name': widget.order.productName, 'qty': widget.order.quantity}
      ];
    }
  }

  String get _recipientName =>
      widget.order.recipientName?.isNotEmpty == true
          ? widget.order.recipientName!
          : widget.order.customerName;

  String get _deliveryAddress =>
      widget.order.deliveryAddress ?? 'No especificada';

  double get _total =>
      widget.order.price + widget.order.shippingCost;

  // ── PDF Generation ───────────────────────────────────────────────────────
  Future<Uint8List> _buildPdf() async {
    final pdf = pw.Document();

    final pageFormat = _isMediaSize
        ? (_isHorizontal
            ? PdfPageFormat.a5.landscape
            : PdfPageFormat.a5)
        : (_isHorizontal
            ? PdfPageFormat.letter.landscape
            : PdfPageFormat.letter);

    // Load selected font via PdfGoogleFonts
    pw.Font? regularFont;
    pw.Font? boldFont;
    try {
      switch (_selectedFont) {
        case 'Montserrat':
          regularFont = await PdfGoogleFonts.montserratRegular();
          boldFont    = await PdfGoogleFonts.montserratBold();
        case 'Lato':
          regularFont = await PdfGoogleFonts.latoRegular();
          boldFont    = await PdfGoogleFonts.latoBold();
        case 'Roboto':
          regularFont = await PdfGoogleFonts.robotoRegular();
          boldFont    = await PdfGoogleFonts.robotoBold();
        case 'Poppins':
          regularFont = await PdfGoogleFonts.poppinsRegular();
          boldFont    = await PdfGoogleFonts.poppinsBold();
        default: // Manrope
          regularFont = await PdfGoogleFonts.manropeRegular();
          boldFont    = await PdfGoogleFonts.manropeBold();
      }
    } catch (_) {
      // fall back to built-in font
    }

    final fs = _fontSize;
    final baseStyle = pw.TextStyle(
        font: regularFont, fontSize: fs, color: PdfColors.grey700);
    final labelStyle = pw.TextStyle(
        font: boldFont,
        fontSize: (fs * 0.7).clamp(6, 10).toDouble(),
        color: PdfColors.grey400,
        letterSpacing: 1.2);
    final titleStyle = pw.TextStyle(
        font: boldFont,
        fontSize: (fs * 1.3).clamp(10, 20).toDouble(),
        color: const PdfColor.fromInt(0xFF11d493));
    final boldStyle = pw.TextStyle(
        font: boldFont, fontSize: (fs * 1.1).clamp(8, 16).toDouble(), color: PdfColors.grey900);
    final smallStyle = pw.TextStyle(
        font: regularFont, fontSize: (fs * 0.85).clamp(6, 12).toDouble(), color: PdfColors.grey600);

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(widget.shopName, style: titleStyle),
                      if (widget.shopTagline != null)
                        pw.Text(widget.shopTagline!, style: smallStyle),
                    ],
                  ),
                  if (_showFolio)
                    pw.Text('Folio: ${widget.order.folio}',
                        style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 9,
                            color: PdfColors.black)),
                ],
              ),
              pw.SizedBox(height: 20),

              // ── Destinatario ─────────────────────────────────────────────
              if (_showDestinatario) ...[
                pw.Text('DESTINATARIO', style: labelStyle),
                pw.SizedBox(height: 3),
                pw.Text(_recipientName, style: boldStyle),
                if (widget.order.recipientPhone?.isNotEmpty == true)
                  pw.Text('Tel: ${widget.order.recipientPhone}',
                      style: smallStyle),
                pw.SizedBox(height: 14),
              ],

              // ── Dirección ────────────────────────────────────────────────
              if (_showDireccion) ...[
                pw.Text('DIRECCIÓN DE ENTREGA', style: labelStyle),
                pw.SizedBox(height: 3),
                pw.Text(_deliveryAddress, style: baseStyle),
                if (widget.order.deliveryReferences?.isNotEmpty == true)
                  pw.Text('Ref: ${widget.order.deliveryReferences}',
                      style: smallStyle),
                pw.SizedBox(height: 3),
                pw.Text('Fecha/Hora: ${widget.order.deliveryInfo}',
                    style: smallStyle),
                pw.SizedBox(height: 14),
              ],

              // ── Divider ──────────────────────────────────────────────────
              if (_showProducto) ...[
                pw.Divider(color: PdfColors.grey200),
                pw.SizedBox(height: 8),
                pw.Text('DETALLE DEL PEDIDO', style: labelStyle),
                pw.SizedBox(height: 8),
                ..._products.map((p) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 6),
                      child: pw.Row(
                        mainAxisAlignment:
                            pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('${p['qty'] ?? 1}x  ${p['name'] ?? ''}',
                              style: boldStyle),
                          if (_showPrecio)
                            pw.Text(
                                '${CurrencyCache.symbol}${_total.toStringAsFixed(2)} ${CurrencyCache.code}',
                                style: pw.TextStyle(
                                    font: boldFont,
                                    fontSize: 11,
                                    color: const PdfColor.fromInt(
                                        0xFF11d493))),
                        ],
                      ),
                    )),
                pw.SizedBox(height: 12),
              ],

              // ── Signature footer ─────────────────────────────────────────
              pw.Spacer(),
              pw.Divider(
                  color: PdfColors.grey300, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 12),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                          width: 100,
                          height: 0.5,
                          color: PdfColors.grey400),
                      pw.SizedBox(height: 4),
                      pw.Text('Firma de recibido', style: smallStyle),
                    ],
                  ),
                  pw.Text('tusflores.app',
                      style: pw.TextStyle(
                          font: regularFont,
                          fontSize: 8,
                          color: PdfColors.grey300)),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  Future<void> _print() async {
    setState(() => _isPrinting = true);
    try {
      final bytes = await _buildPdf();
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo completar la operación.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _share() async {
    setState(() => _isPrinting = true);
    try {
      final bytes = await _buildPdf();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'albaran_${widget.order.folio.replaceAll('#', '')}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo completar la operación.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  // ── UI ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: const BackButton(color: Color(0xFF1A1A2E)),
        title: const Text('Edición de Albarán',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF1A1A2E))),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade100, height: 1),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                // ── Preview ────────────────────────────────────────────────
                _buildPreviewSection(),
                // ── Format controls ────────────────────────────────────────
                _buildFormatSection(),
                // ── Toggles ────────────────────────────────────────────────
                _buildTogglesSection(),
                const SizedBox(height: 24),
              ],
            ),
          ),
          // ── Footer buttons ────────────────────────────────────────────────
          _buildFooter(),
        ],
      ),
    );
  }

  // ── Preview ──────────────────────────────────────────────────────────────
  Widget _buildPreviewSection() {
    return Container(
      color: const Color(0xFFF1F5F9),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('VISTA PREVIA INTERACTIVA',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: Color(0xFF94A3B8))),
          const SizedBox(height: 14),
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              width: _isHorizontal ? 280 : 200,
              constraints: const BoxConstraints(maxWidth: 320),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _buildDocPreview(),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _previewStyle(TextStyle base) {
    return GoogleFonts.getFont(_selectedFont, textStyle: base);
  }

  Widget _buildDocPreview() {
    final productList = _products;
    return DefaultTextStyle(
      style: _previewStyle(const TextStyle()),
      child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.shopName,
                      style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF11d493),
                          letterSpacing: 0.2)),
                  if (widget.shopTagline != null)
                    Text(widget.shopTagline!,
                        style: const TextStyle(
                            fontSize: 6, color: Color(0xFF94A3B8))),
                ],
              ),
              if (_showFolio)
                Text('Folio: ${widget.order.folio}',
                    style: const TextStyle(
                        fontSize: 6,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 12),

          // Destinatario
          if (_showDestinatario) ...[
            const Text('DESTINATARIO',
                style: TextStyle(
                    fontSize: 5.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.8)),
            const SizedBox(height: 2),
            Text(_recipientName,
                style: const TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
          ],

          // Dirección
          if (_showDireccion) ...[
            const Text('DIRECCIÓN DE ENTREGA',
                style: TextStyle(
                    fontSize: 5.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.8)),
            const SizedBox(height: 2),
            Text(_deliveryAddress,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 7, color: Color(0xFF475569))),
            Text('Entrega: ${widget.order.deliveryInfo}',
                style:
                    const TextStyle(fontSize: 6, color: Color(0xFF94A3B8))),
            const SizedBox(height: 8),
          ],

          // Producto
          if (_showProducto) ...[
            const Divider(height: 12, thickness: 0.5),
            const Text('DETALLE DEL PEDIDO',
                style: TextStyle(
                    fontSize: 5.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.8)),
            const SizedBox(height: 6),
            ...productList.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      if (_showFoto)
                        Container(
                          width: 28,
                          height: 28,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.local_florist_rounded,
                              size: 14, color: Color(0xFF94A3B8)),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p['name']?.toString() ?? '',
                                style: const TextStyle(
                                    fontSize: 7.5,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${p['qty'] ?? 1}x',
                              style: const TextStyle(
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.bold)),
                          if (_showPrecio)
                            Text(
                                '${CurrencyCache.symbol}${_total.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontSize: 7,
                                    color: Color(0xFF11d493),
                                    fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                )),
          ],

          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Firma placeholder
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 50, height: 0.5, color: const Color(0xFF94A3B8)),
                  const SizedBox(height: 2),
                  const Text('Firma', style: TextStyle(fontSize: 5.5, color: Color(0xFF94A3B8))),
                ],
              ),
              const Text('tusflores.app',
                  style: TextStyle(fontSize: 5, color: Color(0xFFCBD5E1))),
            ],
          ),
        ],
      ),
    ),    // Padding (child of DefaultTextStyle)
    );   // DefaultTextStyle
  }

  // ── Format Section ───────────────────────────────────────────────────────
  Widget _buildFormatSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('FORMATO DE IMPRESIÓN',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: Color(0xFF64748B))),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ORIENTACIÓN',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.8)),
                    const SizedBox(height: 6),
                    _SegmentedPicker(
                      options: const ['Vertical', 'Horizontal'],
                      selected: _isHorizontal ? 1 : 0,
                      onChanged: (i) =>
                          setState(() => _isHorizontal = i == 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TAMAÑO',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.8)),
                    const SizedBox(height: 6),
                    _SegmentedPicker(
                      options: const ['Carta', 'Media'],
                      selected: _isMediaSize ? 1 : 0,
                      onChanged: (i) =>
                          setState(() => _isMediaSize = i == 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ── Font selector ────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('FUENTE',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.8)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedFont,
                          isExpanded: true,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A2E)),
                          icon: const Icon(Icons.expand_more_rounded,
                              size: 18, color: Color(0xFF94A3B8)),
                          items: _sansFonts
                              .map((f) => DropdownMenuItem(
                                    value: f,
                                    child: Text(f,
                                        style: const TextStyle(fontSize: 12)),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _selectedFont = v);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TAMAÑO  ${_fontSize.toInt()}px',
                        style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.8)),
                    const SizedBox(height: 2),
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 8),
                        overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 16),
                        activeTrackColor: AppTheme.primary,
                        inactiveTrackColor: const Color(0xFFE2E8F0),
                        thumbColor: AppTheme.primary,
                        overlayColor:
                            AppTheme.primary.withValues(alpha: 0.15),
                      ),
                      child: Slider(
                        value: _fontSize,
                        min: 10,
                        max: 30,
                        divisions: 20,
                        onChanged: (v) => setState(() => _fontSize = v),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Toggles Section ──────────────────────────────────────────────────────
  Widget _buildTogglesSection() {
    final items = [
      _ToggleItem(
          icon: Icons.tag_rounded,
          label: 'Mostrar Número de Folio',
          value: _showFolio,
          onChanged: (v) => setState(() => _showFolio = v)),
      _ToggleItem(
          icon: Icons.person_outline_rounded,
          label: 'Datos de Destinatario',
          value: _showDestinatario,
          onChanged: (v) => setState(() => _showDestinatario = v)),
      _ToggleItem(
          icon: Icons.location_on_outlined,
          label: 'Dirección de Entrega',
          value: _showDireccion,
          onChanged: (v) => setState(() => _showDireccion = v)),
      _ToggleItem(
          icon: Icons.inventory_2_outlined,
          label: 'Detalle del Producto',
          value: _showProducto,
          onChanged: (v) => setState(() => _showProducto = v)),
      _ToggleItem(
          icon: Icons.image_outlined,
          label: 'Incluir Foto en Producto',
          value: _showFoto,
          onChanged: (v) => setState(() => _showFoto = v),
          disabled: !_showProducto),
      _ToggleItem(
          icon: Icons.attach_money_rounded,
          label: 'Mostrar Precio',
          value: _showPrecio,
          onChanged: (v) => setState(() => _showPrecio = v)),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CONFIGURACIÓN DE VISUALIZACIÓN',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: Color(0xFF64748B))),
          const SizedBox(height: 14),
          ...items.map((item) => _buildToggleRow(item)),
        ],
      ),
    );
  }

  Widget _buildToggleRow(_ToggleItem item) {
    final isDisabled = item.disabled;
    return AnimatedOpacity(
      opacity: isDisabled ? 0.4 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Icon(item.icon, size: 16, color: const Color(0xFF94A3B8)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(item.label,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600)),
            ),
            Switch(
              value: item.value,
              onChanged: isDisabled ? null : item.onChanged,
              activeColor: AppTheme.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }

  // ── Footer ───────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isPrinting ? null : _print,
              icon: _isPrinting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.print_rounded, size: 20),
              label: const Text('Imprimir Albarán',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isPrinting ? null : _share,
              icon: const Icon(Icons.share_rounded, size: 20),
              label: const Text('Compartir Digital',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: BorderSide(color: AppTheme.primary, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _ToggleItem {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool disabled;
  const _ToggleItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.disabled = false,
  });
}

class _SegmentedPicker extends StatelessWidget {
  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;

  const _SegmentedPicker({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: List.generate(options.length, (i) {
          final isSelected = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 4,
                              offset: const Offset(0, 1))
                        ]
                      : [],
                ),
                child: Text(
                  options[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? const Color(0xFF1A1A2E)
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
