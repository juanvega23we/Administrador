// ═══════════════════════════════════════════════════════════════
//  reportes_page.dart  –  Salsamentaría Dashboard
//  Funciones: gráfico pastel↔barras, filtro fechas, export xlsx/pdf
//
//  Agregar en pubspec.yaml:
//    excel: ^4.0.6
//    pdf: ^3.10.8
//    printing: ^5.12.0
// ═══════════════════════════════════════════════════════════════
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as xls;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportesPage extends StatefulWidget {
  const ReportesPage({super.key});

  @override
  State<ReportesPage> createState() => _ReportesPageState();
}

class _ReportesPageState extends State<ReportesPage> {
  String _periodo = 'mes';
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  bool _exportando = false;
  List<Map<String, dynamic>> _pedidosCache = [];

  DateTime get _fechaInicioEfectiva {
    if (_periodo == 'custom' && _fechaInicio != null) return _fechaInicio!;
    final ahora = DateTime.now();
    switch (_periodo) {
      case 'hoy':
        return DateTime(ahora.year, ahora.month, ahora.day);
      case 'semana':
        return ahora.subtract(const Duration(days: 7));
      case 'mes':
      default:
        return DateTime(ahora.year, ahora.month, 1);
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  EXPORTAR EXCEL
  // ══════════════════════════════════════════════════════════════
  Future<void> _exportarExcel() async {
    if (_pedidosCache.isEmpty) {
      _snack('No hay datos para exportar', Colors.orange);
      return;
    }
    setState(() => _exportando = true);
    try {
      final excel = xls.Excel.createExcel();

      // Hoja Resumen
      final resumen = excel['Resumen'];
      excel.setDefaultSheet('Resumen');

      _excelCeldaTitulo(resumen, 0, 0, 'REPORTE DE SALSAMENTARÍA');
      _excelCeldaTitulo(resumen, 1, 0,
          'Período: ${_etiquetaPeriodo()} — Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}');

      final total = _pedidosCache.length;
      final pendientes =
          _pedidosCache.where((p) => p['estado'] == 'pendiente').length;
      final confirmados =
          _pedidosCache.where((p) => p['estado'] == 'confirmado').length;
      final entregados =
          _pedidosCache.where((p) => p['estado'] == 'entregado').length;
      final cancelados =
          _pedidosCache.where((p) => p['estado'] == 'cancelado').length;
      final ingresos = _pedidosCache
          .where((p) =>
              p['estado'] == 'entregado' || p['estado'] == 'confirmado')
          .fold(0.0, (s, p) => s + ((p['total'] as num?) ?? 0.0));
      final activos = total - cancelados;
      final ticket = activos > 0 ? ingresos / activos : 0.0;

      _excelFila(resumen, 3, ['MÉTRICA', 'VALOR'], '1F3864', header: true);
      _excelFila(resumen, 4, ['Total Pedidos', '$total'], 'E8F4F8');
      _excelFila(resumen, 5, ['Pendientes', '$pendientes'], 'FFFFFF');
      _excelFila(resumen, 6, ['Confirmados', '$confirmados'], 'E8F4F8');
      _excelFila(resumen, 7, ['Entregados', '$entregados'], 'FFFFFF');
      _excelFila(resumen, 8, ['Cancelados', '$cancelados'], 'E8F4F8');
      _excelFila(resumen, 9,
          ['Ingresos (S/)', ingresos.toStringAsFixed(2)], 'FFFFFF');
      _excelFila(resumen, 10,
          ['Ticket Promedio (S/)', ticket.toStringAsFixed(2)], 'E8F4F8');

      resumen.setColumnWidth(0, 25);
      resumen.setColumnWidth(1, 20);

      // Hoja Pedidos
      final detalle = excel['Pedidos'];
      _excelFila(detalle, 0,
          ['N° Pedido', 'Cliente', 'Estado', 'Total (S/)', 'Fecha'],
          '1F3864',
          header: true);

      for (int i = 0; i < _pedidosCache.length; i++) {
        final p = _pedidosCache[i];
        _excelFila(
          detalle,
          i + 1,
          [
            p['numeroPedido']?.toString() ??
                p['idPedido']?.toString() ??
                '—',
            _getNombreCliente(p),
            _nombreEstado(p['estado']?.toString()),
            ((p['total'] as num?) ?? 0.0).toStringAsFixed(2),
            _formatFechaStr(p['fechaPedido'] ?? p['creadoEn']),
          ],
          i.isEven ? 'F0F4FF' : 'FFFFFF',
        );
      }

      detalle.setColumnWidth(0, 18);
      detalle.setColumnWidth(1, 28);
      detalle.setColumnWidth(2, 14);
      detalle.setColumnWidth(3, 14);
      detalle.setColumnWidth(4, 22);

      excel.delete('Sheet1');

      final bytes = excel.encode();
      if (bytes == null) throw Exception('Error al codificar Excel');

      await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename:
            'reporte_salsamentaria_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx',
      );

      _snack('Excel exportado ✓', const Color(0xFF2E8B57));
    } catch (e) {
      _snack('Error al exportar Excel: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  EXPORTAR PDF
  // ══════════════════════════════════════════════════════════════
  Future<void> _exportarPdf() async {
    if (_pedidosCache.isEmpty) {
      _snack('No hay datos para exportar', Colors.orange);
      return;
    }
    setState(() => _exportando = true);
    try {
      final doc = pw.Document(
          title: 'Reporte Salsamentaría', author: 'Sistema Admin');

      final rojo = PdfColor.fromHex('008000');
      final rojoClaro = PdfColor.fromHex('008000');
      final gris = PdfColor.fromHex('F5F5F5');
      final grisTexto = PdfColor.fromHex('666666');
      final verde = PdfColor.fromHex('2E8B57');
      final naranja = PdfColor.fromHex('D35400');
      final azul = PdfColor.fromHex('1976D2');

      final total = _pedidosCache.length;
      final pendientes =
          _pedidosCache.where((p) => p['estado'] == 'pendiente').length;
      final confirmados =
          _pedidosCache.where((p) => p['estado'] == 'confirmado').length;
      final entregados =
          _pedidosCache.where((p) => p['estado'] == 'entregado').length;
      final cancelados =
          _pedidosCache.where((p) => p['estado'] == 'cancelado').length;
      final ingresos = _pedidosCache
          .where((p) =>
              p['estado'] == 'entregado' || p['estado'] == 'confirmado')
          .fold(0.0, (s, p) => s + ((p['total'] as num?) ?? 0.0));
      final activos = total - cancelados;
      final ticket = activos > 0 ? ingresos / activos : 0.0;

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('SALSAMENTARÍA',
                          style: pw.TextStyle(
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                              color: rojo)),
                      pw.Text('Reporte de Ventas y Pedidos',
                          style: pw.TextStyle(
                              fontSize: 11, color: grisTexto)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Período: ${_etiquetaPeriodo()}',
                          style: pw.TextStyle(
                              fontSize: 10, color: grisTexto)),
                      pw.Text(
                          'Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                          style: pw.TextStyle(
                              fontSize: 10, color: grisTexto)),
                    ],
                  ),
                ],
              ),
              pw.Divider(color: rojo, thickness: 2),
              pw.SizedBox(height: 4),
            ],
          ),
          footer: (ctx) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Salsamentaría — Reporte confidencial',
                  style: pw.TextStyle(fontSize: 8, color: grisTexto)),
              pw.Text(
                  'Página ${ctx.pageNumber} de ${ctx.pagesCount}',
                  style: pw.TextStyle(fontSize: 8, color: grisTexto)),
            ],
          ),
          build: (ctx) => [
            // KPIsgit 

            // Tabla estados
            pw.Text('DISTRIBUCIÓN POR ESTADO',
                style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: rojo)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(
                  color: PdfColor.fromHex('E0E0E0'), width: 0.5),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: rojoClaro),
                  children: [
                    _pdfTh('Estado'),
                    _pdfTh('Cantidad'),
                    _pdfTh('% del Total'),
                    _pdfTh('Ingresos'),
                  ],
                ),
                _pdfEstadoRow('Pendiente', pendientes, total, null, gris),
                _pdfEstadoRow('Confirmado', confirmados, total,
                    _ingresosEstado('confirmado'), PdfColors.white),
                _pdfEstadoRow('Entregado', entregados, total,
                    _ingresosEstado('entregado'), gris),
                _pdfEstadoRow(
                    'Cancelado', cancelados, total, null, PdfColors.white),
              ],
            ),
            pw.SizedBox(height: 20),

            // Tabla detalle
            pw.Text('DETALLE DE PEDIDOS ($total)',
                style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: rojo)),
            pw.SizedBox(height: 8),
            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(2),
                4: const pw.FlexColumnWidth(3),
              },
              border: pw.TableBorder.all(
                  color: PdfColor.fromHex('E0E0E0'), width: 0.5),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: rojoClaro),
                  children: [
                    _pdfTh('N° Pedido'),
                    _pdfTh('Cliente'),
                    _pdfTh('Estado'),
                    _pdfTh('Total'),
                    _pdfTh('Fecha'),
                  ],
                ),
                ..._pedidosCache.asMap().entries.map((e) {
                  final p = e.value;
                  final bg = e.key.isEven ? gris : PdfColors.white;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: bg),
                    children: [
                      _pdfTd(p['numeroPedido']?.toString() ??
                          p['idPedido']?.toString() ??
                          '—'),
                      _pdfTd(_getNombreCliente(p)),
                      _pdfTd(_nombreEstado(p['estado']?.toString())),
                      _pdfTd('S/ ${((p['total'] as num?) ?? 0.0).toStringAsFixed(2)}'),
                      _pdfTd(_formatFechaStr(
                          p['fechaPedido'] ?? p['creadoEn'])),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (_) async => doc.save(),
        name:
            'reporte_salsamentaria_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );

      _snack('PDF generado ✓', const Color(0xFF2E8B57));
    } catch (e) {
      _snack('Error al exportar PDF: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  // ── Helpers PDF ──────────────────────────────────────────────
  pw.Widget _pdfKpi(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColor(
              color.red, color.green, color.blue, 0.08),
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(
            color: PdfColor(color.red, color.green, color.blue, 0.3),
            width: 1,
          ),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 8,
                    color: PdfColor.fromHex('888888'))),
            pw.SizedBox(height: 2),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: color)),
          ],
        ),
      ),
    );
  }

  pw.Widget _pdfTh(String text) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(text,
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('8B0000'))),
      );

  pw.Widget _pdfTd(String text) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: pw.Text(text, style: const pw.TextStyle(fontSize: 8)),
      );

  pw.TableRow _pdfEstadoRow(
      String estado, int cant, int total, double? ing, PdfColor bg) {
    final pct =
        total > 0 ? (cant / total * 100).toStringAsFixed(1) : '0.0';
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: bg),
      children: [
        _pdfTd(estado),
        _pdfTd('$cant'),
        _pdfTd('$pct%'),
        _pdfTd(ing != null ? 'S/ ${ing.toStringAsFixed(2)}' : '—'),
      ],
    );
  }

  double _ingresosEstado(String estado) => _pedidosCache
      .where((p) => p['estado'] == estado)
      .fold(0.0, (s, p) => s + ((p['total'] as num?) ?? 0.0));

  // ── Helpers Excel ─────────────────────────────────────────────
  void _excelCeldaTitulo(xls.Sheet sheet, int row, int col, String text) {
    final cell = sheet.cell(
        xls.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = xls.TextCellValue(text);
    cell.cellStyle = xls.CellStyle(
      bold: true,
      fontSize: row == 0 ? 14 : 10,
      fontColorHex: xls.ExcelColor.fromHexString('8B0000'),
    );
  }

  void _excelFila(xls.Sheet sheet, int row, List<dynamic> values, String bgHex,
      {bool header = false}) {
    for (int col = 0; col < values.length; col++) {
      final cell = sheet.cell(
          xls.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      cell.value = xls.TextCellValue(values[col].toString());
      cell.cellStyle = xls.CellStyle(
        bold: header,
        backgroundColorHex: xls.ExcelColor.fromHexString(bgHex),
        fontColorHex:
            xls.ExcelColor.fromHexString(header ? 'FFFFFF' : '2C2C2C'),
      );
    }
  }

  // ── Helpers generales ─────────────────────────────────────────
  String _getNombreCliente(Map<String, dynamic> p) {
    if (p['nombreCliente'] != null) return p['nombreCliente'].toString();
    final c = p['cliente'] as Map<String, dynamic>?;
    return c?['nombre']?.toString() ?? 'Sin nombre';
  }

  String _nombreEstado(String? e) {
    switch (e) {
      case 'pendiente': return 'Pendiente';
      case 'confirmado': return 'Confirmado';
      case 'entregado': return 'Entregado';
      case 'cancelado': return 'Cancelado';
      default: return e ?? '—';
    }
  }

  String _formatFechaStr(dynamic ts) {
    if (ts == null || ts is! Timestamp) return 'Sin fecha';
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(ts.toDate());
    } catch (_) {
      return '—';
    }
  }

  String _etiquetaPeriodo() {
    switch (_periodo) {
      case 'hoy': return 'Hoy';
      case 'semana': return 'Últimos 7 días';
      case 'custom':
        if (_fechaInicio != null && _fechaFin != null) {
          return '${DateFormat('dd/MM/yy').format(_fechaInicio!)} – ${DateFormat('dd/MM/yy').format(_fechaFin!)}';
        }
        return 'Personalizado';
      default: return 'Este mes';
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ══════════════════════════════════════════════════════════════
  //  FILTRO FECHAS
  // ══════════════════════════════════════════════════════════════
  Future<void> _seleccionarFecha(bool esInicio) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: esInicio
          ? (_fechaInicio ?? DateTime.now())
          : (_fechaFin ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF8B0000),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (esInicio) _fechaInicio = picked;
        else _fechaFin = picked;
        _periodo = 'custom';
      });
    }
  }

  void _mostrarFiltroFechas() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4, height: 22,
                    decoration: BoxDecoration(
                        color: const Color(0xFF8B0000),
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 10),
                  const Text('Filtrar por rango de fechas',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _FechaTile(
                      label: 'Desde',
                      fecha: _fechaInicio,
                      onTap: () async {
                        await _seleccionarFecha(true);
                        setModal(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _FechaTile(
                      label: 'Hasta',
                      fecha: _fechaFin,
                      onTap: () async {
                        await _seleccionarFecha(false);
                        setModal(() {});
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _fechaInicio = null;
                          _fechaFin = null;
                          _periodo = 'mes';
                        });
                        Navigator.pop(ctx);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF8B0000),
                        side: const BorderSide(
                            color: Color(0xFF8B0000)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text('Limpiar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B0000),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text('Aplicar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _hayFiltroCustom => _periodo == 'custom';

  // ══════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F0EF),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              // ── HEADER ──
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                      bottom: BorderSide(color: Color(0xFFEDE0DE))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 5, height: 28,
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B0000),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Reportes de Salsamentaría',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C0A0A),
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _HeaderIconBtn(
                              icon: Icons.calendar_month_rounded,
                              isActive: _hayFiltroCustom,
                              tooltip: 'Filtrar por fecha',
                              onTap: _mostrarFiltroFechas,
                            ),
                            const SizedBox(width: 10),
                            _ExportBtn(
                              label: 'Excel',
                              icon: Icons.table_chart_rounded,
                              color: const Color(0xFF1E7145),
                              loading: _exportando,
                              onTap: _exportarExcel,
                            ),
                            const SizedBox(width: 8),
                            _ExportBtn(
                              label: 'PDF',
                              icon: Icons.picture_as_pdf_rounded,
                              color: const Color(0xFF8B0000),
                              loading: _exportando,
                              onTap: _exportarPdf,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _PeriodChip(
                          label: 'Hoy',
                          isSelected: _periodo == 'hoy',
                          onTap: () => setState(() {
                            _periodo = 'hoy';
                            _fechaInicio = null;
                            _fechaFin = null;
                          }),
                        ),
                        const SizedBox(width: 8),
                        _PeriodChip(
                          label: '7 días',
                          isSelected: _periodo == 'semana',
                          onTap: () => setState(() {
                            _periodo = 'semana';
                            _fechaInicio = null;
                            _fechaFin = null;
                          }),
                        ),
                        const SizedBox(width: 8),
                        _PeriodChip(
                          label: 'Este mes',
                          isSelected: _periodo == 'mes',
                          onTap: () => setState(() {
                            _periodo = 'mes';
                            _fechaInicio = null;
                            _fechaFin = null;
                          }),
                        ),
                        if (_hayFiltroCustom) ...[
                          const SizedBox(width: 8),
                          _PeriodChip(
                            label: _fechaInicio != null && _fechaFin != null
                                ? '${DateFormat('dd/MM').format(_fechaInicio!)} – ${DateFormat('dd/MM').format(_fechaFin!)}'
                                : 'Personalizado',
                            isSelected: true,
                            color: const Color(0xFFD35400),
                            onTap: _mostrarFiltroFechas,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // ── CUERPO ──
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('pedido')
                      .where('fechaPedido',
                          isGreaterThanOrEqualTo: Timestamp.fromDate(
                              _fechaInicioEfectiva))
                      .orderBy('fechaPedido', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF8B0000)));
                    }

                    final pedidos = snapshot.data!.docs
                        .map((d) => d.data() as Map<String, dynamic>)
                        .where((p) {
                      if (_periodo == 'custom' && _fechaFin != null) {
                        final ts = p['fechaPedido'] ?? p['creadoEn'];
                        if (ts is! Timestamp) return false;
                        final fin = DateTime(_fechaFin!.year,
                            _fechaFin!.month, _fechaFin!.day, 23, 59, 59);
                        return !ts.toDate().isAfter(fin);
                      }
                      return true;
                    }).toList();

                    // Cache para exportación
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _pedidosCache = List.from(pedidos);
                    });

                    final total = pedidos.length;
                    final pendientes = pedidos
                        .where((p) => p['estado'] == 'pendiente').length;
                    final confirmados = pedidos
                        .where((p) => p['estado'] == 'confirmado').length;
                    final entregados = pedidos
                        .where((p) => p['estado'] == 'entregado').length;
                    final cancelados = pedidos
                        .where((p) => p['estado'] == 'cancelado').length;
                    final ingresos = pedidos
                        .where((p) =>
                            p['estado'] == 'entregado' ||
                            p['estado'] == 'confirmado')
                        .fold(0.0,
                            (s, p) => s + ((p['total'] as num?) ?? 0.0));
                    final activos = total - cancelados;
                    final ticket =
                        activos > 0 ? ingresos / activos : 0.0;

                    return ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        _KpiGrid(
                          totalPedidos: total,
                          ingresos: ingresos,
                          ticketPromedio: ticket,
                          entregados: entregados,
                          pendientes: pendientes,
                          cancelados: cancelados,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: _ChartCard(
                                pendientes: pendientes,
                                confirmados: confirmados,
                                entregados: entregados,
                                cancelados: cancelados,
                                total: total,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 3,
                              child: _IngresosCard(
                                ingresos: ingresos,
                                ticketPromedio: ticket,
                                totalPedidos: total,
                                entregados: entregados,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _SectionHeader(
                          icon: Icons.receipt_long_rounded,
                          label: 'Pedidos del período',
                          badge: total > 0 ? '$total' : null,
                        ),
                        const SizedBox(height: 12),
                        if (pedidos.isEmpty)
                          _EmptyState()
                        else
                          ...pedidos.map((p) => Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 10),
                                child: _PedidoCard(pedido: p),
                              )),
                        const SizedBox(height: 20),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Botón exportación
// ═══════════════════════════════════════════════════════════════
class _ExportBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback onTap;

  const _ExportBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: loading ? 0.5 : 1.0,
      child: Material(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: loading ? null : onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                loading
                    ? SizedBox(
                        width: 15, height: 15,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: color))
                    : Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  KPI Grid
// ═══════════════════════════════════════════════════════════════
class _KpiGrid extends StatelessWidget {
  final int totalPedidos;
  final double ingresos;
  final double ticketPromedio;
  final int entregados;
  final int pendientes;
  final int cancelados;

  const _KpiGrid({
    required this.totalPedidos,
    required this.ingresos,
    required this.ticketPromedio,
    required this.entregados,
    required this.pendientes,
    required this.cancelados,
  });

  @override
  Widget build(BuildContext context) {
    String pct(int n) => totalPedidos > 0
        ? '${(n / totalPedidos * 100).toStringAsFixed(1)}% del total'
        : '0% del total';

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        _KpiCard(
            label: 'Total Pedidos',
            value: '$totalPedidos',
            icon: Icons.shopping_cart_rounded,
            accent: const Color(0xFFD35400),
            sub: 'en el período'),
        _KpiCard(
            label: 'Ingresos',
            value:
                'S/ ${NumberFormat('#,##0', 'es_PE').format(ingresos.round())}',
            icon: Icons.payments_rounded,
            accent: const Color(0xFF2E8B57),
            sub: 'confirmados + entregados'),
        _KpiCard(
            label: 'Ticket Promedio',
            value:
                'S/ ${NumberFormat('#,##0', 'es_PE').format(ticketPromedio.round())}',
            icon: Icons.trending_up_rounded,
            accent: const Color(0xFF8B0000),
            sub: 'por pedido activo'),
        _KpiCard(
            label: 'Entregados',
            value: '$entregados',
            icon: Icons.check_circle_rounded,
            accent: const Color(0xFF2E8B57),
            sub: pct(entregados)),
        _KpiCard(
            label: 'Pendientes',
            value: '$pendientes',
            icon: Icons.hourglass_empty_rounded,
            accent: Colors.orange,
            sub: pct(pendientes)),
        _KpiCard(
            label: 'Cancelados',
            value: '$cancelados',
            icon: Icons.cancel_rounded,
            accent: Colors.redAccent,
            sub: pct(cancelados)),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label, value, sub;
  final IconData icon;
  final Color accent;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: accent.withOpacity(0.15), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                  color: accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: accent,
                          height: 1.1)),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey[400]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  ChartCard  –  Pastel ↔ Barras
// ═══════════════════════════════════════════════════════════════
class _ChartCard extends StatefulWidget {
  final int pendientes, confirmados, entregados, cancelados, total;

  const _ChartCard({
    required this.pendientes,
    required this.confirmados,
    required this.entregados,
    required this.cancelados,
    required this.total,
  });

  @override
  State<_ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<_ChartCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = [
      _Segment('Pendientes', widget.pendientes, Colors.orange),
      _Segment('Confirmados', widget.confirmados, const Color(0xFF1976D2)),
      _Segment('Entregados', widget.entregados, const Color(0xFF2E8B57)),
      _Segment('Cancelados', widget.cancelados, Colors.redAccent),
    ];

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _SectionHeader(
                    icon: Icons.donut_large_rounded,
                    label: 'Distribución de Pedidos'),
                const Spacer(),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _isHovered
                        ? const Color(0xFF8B0000).withOpacity(0.08)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isHovered
                            ? Icons.bar_chart_rounded
                            : Icons.donut_large_rounded,
                        size: 14,
                        color: _isHovered
                            ? const Color(0xFF8B0000)
                            : Colors.grey[500],
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _isHovered ? 'Barras' : 'Pastel',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _isHovered
                                ? const Color(0xFF8B0000)
                                : Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Pasa el cursor sobre el gráfico para ver barras',
                style: TextStyle(fontSize: 11, color: Colors.grey[400])),
            const SizedBox(height: 20),
            MouseRegion(
              onEnter: (_) {
                setState(() => _isHovered = true);
                _ctrl.forward();
              },
              onExit: (_) {
                setState(() => _isHovered = false);
                _ctrl.reverse();
              },
              child: AnimatedBuilder(
                animation: _anim,
                builder: (ctx, _) => SizedBox(
                  height: 200,
                  child: Stack(
                    children: [
                      Opacity(
                          opacity: 1 - _anim.value,
                          child: _PieChart(
                              data: data, total: widget.total)),
                      Opacity(
                          opacity: _anim.value,
                          child: _BarChart(
                              data: data, total: widget.total)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: data.map((s) {
                final pct = widget.total > 0
                    ? (s.valor / widget.total * 100).toStringAsFixed(1)
                    : '0.0';
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                            color: s.color, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('${s.nombre}  $pct%',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500)),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segment {
  final String nombre;
  final int valor;
  final Color color;
  const _Segment(this.nombre, this.valor, this.color);
}

class _PieChart extends StatelessWidget {
  final List<_Segment> data;
  final int total;
  const _PieChart({required this.data, required this.total});

  @override
  Widget build(BuildContext context) => CustomPaint(
      painter: _PiePainter(data: data, total: total),
      child: const SizedBox.expand());
}

class _PiePainter extends CustomPainter {
  final List<_Segment> data;
  final int total;
  const _PiePainter({required this.data, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    double startAngle = -math.pi / 2;

    for (final seg in data) {
      if (seg.valor == 0) continue;
      final sweep = (seg.valor / total) * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle, sweep - 0.04, false,
        Paint()
          ..color = seg.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 28,
      );
      startAngle += sweep;
    }

    final tp = TextPainter(
      text: TextSpan(children: [
        TextSpan(
            text: '$total\n',
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C0A0A),
                height: 1.2)),
        TextSpan(
            text: 'pedidos',
            style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500)),
      ]),
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_PiePainter old) =>
      old.total != total || old.data != data;
}

class _BarChart extends StatelessWidget {
  final List<_Segment> data;
  final int total;
  const _BarChart({required this.data, required this.total});

  @override
  Widget build(BuildContext context) {
    final maxVal =
        data.map((s) => s.valor).fold(0, (a, b) => a > b ? a : b);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: data.map((seg) {
          final ratio = maxVal > 0 ? seg.valor / maxVal : 0.0;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('${seg.valor}',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: seg.color)),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    height: 140 * ratio,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [seg.color, seg.color.withOpacity(0.65)],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(seg.nombre,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Card lateral Ingresos
// ═══════════════════════════════════════════════════════════════
class _IngresosCard extends StatelessWidget {
  final double ingresos, ticketPromedio;
  final int totalPedidos, entregados;

  const _IngresosCard({
    required this.ingresos,
    required this.ticketPromedio,
    required this.totalPedidos,
    required this.entregados,
  });

  @override
  Widget build(BuildContext context) {
    final tasa = totalPedidos > 0 ? entregados / totalPedidos : 0.0;
    return Card(
      elevation: 0,
      color: const Color(0xFF8B0000),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.monetization_on_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Ingresos',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 14),
            Text(
              'S/ ${NumberFormat('#,##0', 'es_PE').format(ingresos.round())}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5),
            ),
            const SizedBox(height: 4),
            Text('confirmados + entregados',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.55), fontSize: 11)),
            const SizedBox(height: 20),
            _IngresoDato(
                label: 'Ticket promedio',
                value: 'S/ ${ticketPromedio.toStringAsFixed(0)}'),
            const SizedBox(height: 12),
            _IngresoDato(
                label: 'Tasa de entrega',
                value: '${(tasa * 100).toStringAsFixed(1)}%'),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Entregados vs Total',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: tasa,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF90EE90)),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IngresoDato extends StatelessWidget {
  final String label, value;
  const _IngresoDato({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.6), fontSize: 12)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ],
      );
}

// ═══════════════════════════════════════════════════════════════
//  Card pedido individual
// ═══════════════════════════════════════════════════════════════
class _PedidoCard extends StatelessWidget {
  final Map<String, dynamic> pedido;
  const _PedidoCard({required this.pedido});

  String get _cliente {
    if (pedido['nombreCliente'] != null)
      return pedido['nombreCliente'].toString();
    final c = pedido['cliente'] as Map<String, dynamic>?;
    return c?['nombre']?.toString() ?? 'Cliente no identificado';
  }

  @override
  Widget build(BuildContext context) {
    final estado = pedido['estado'] ?? 'pendiente';
    final total = (pedido['total'] as num?)?.toDouble() ?? 0.0;
    final fecha =
        _formatFecha(pedido['fechaPedido'] ?? pedido['creadoEn']);
    final color = _colorEstado(estado);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
                width: 4, height: 44,
                decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 14),
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withOpacity(0.1),
              child: Text(
                _cliente.isNotEmpty ? _cliente[0].toUpperCase() : '?',
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_cliente,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(fecha,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[450])),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('S/ ${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF8B0000))),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(_nombreEstado(estado),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: color)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatFecha(dynamic ts) {
    if (ts == null || ts is! Timestamp) return 'Sin fecha';
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(ts.toDate());
    } catch (_) {
      return '—';
    }
  }

  String _nombreEstado(String? e) {
    switch (e) {
      case 'pendiente': return 'Pendiente';
      case 'confirmado': return 'Confirmado';
      case 'entregado': return 'Entregado';
      case 'cancelado': return 'Cancelado';
      default: return e ?? '—';
    }
  }

  Color _colorEstado(String? e) {
    switch (e) {
      case 'pendiente': return Colors.orange;
      case 'confirmado': return const Color(0xFF1976D2);
      case 'entregado': return const Color(0xFF2E8B57);
      case 'cancelado': return Colors.redAccent;
      default: return Colors.grey;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
//  Widgets de soporte
// ═══════════════════════════════════════════════════════════════
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  const _SectionHeader(
      {required this.icon, required this.label, this.badge});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF8B0000)),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C0A0A))),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
                color: const Color(0xFF8B0000).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20)),
            child: Text(badge!,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8B0000))),
          ),
        ],
      ],
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  const _PeriodChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF8B0000);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? c : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? c : Colors.grey.shade300),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey[600])),
      ),
    );
  }
}

class _HeaderIconBtn extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderIconBtn({
    required this.icon,
    required this.isActive,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const c = Color(0xFF8B0000);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: isActive
                ? c.withOpacity(0.12)
                : c.withOpacity(0.07),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: isActive ? c : Colors.transparent, width: 2),
          ),
          child: Icon(icon, color: c, size: 20),
        ),
      ),
    );
  }
}

class _FechaTile extends StatelessWidget {
  final String label;
  final DateTime? fecha;
  final VoidCallback onTap;
  const _FechaTile(
      {required this.label, required this.fecha, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const c = Color(0xFF8B0000);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: fecha != null ? c.withOpacity(0.06) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: fecha != null ? c : Colors.grey.shade300,
              width: fecha != null ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 5),
            Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 14,
                    color: fecha != null ? c : Colors.grey[500]),
                const SizedBox(width: 6),
                Text(
                  fecha != null
                      ? DateFormat('dd/MM/yyyy').format(fecha!)
                      : 'Seleccionar',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: fecha != null
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: fecha != null ? c : Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            children: [
              Icon(Icons.receipt_long_outlined,
                  size: 60, color: Colors.grey[300]),
              const SizedBox(height: 14),
              Text('No hay pedidos en este período',
                  style:
                      TextStyle(color: Colors.grey[500], fontSize: 15)),
            ],
          ),
        ),
      );
}