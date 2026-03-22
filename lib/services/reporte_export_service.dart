// lib/services/reporte_export_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReporteExportService {
  static const String _kExcelFunctionUrl =
      'https://us-central1-el-gran-molino-6642d.cloudfunctions.net/generarReporteExcel';

  // ── Excel ────────────────────────────────────────────────────
  Future<void> exportarExcel(
    List<Map<String, dynamic>> pedidos,
    String etiquetaPeriodo, {
    List<Map<String, dynamic>> productos = const [],
  }) async {
    final pedidosJson = pedidos.map((p) {
      final ts = p['fechaPedido'] ?? p['creadoEn'];
      String fechaIso = '';
      if (ts is Timestamp) fechaIso = ts.toDate().toIso8601String();
      return {
        'numeroPedido'  : _getNumeroPedido(p),
        'nombreCliente' : _getNombreCliente(p),
        'estado'        : p['estado']?.toString() ?? 'pendiente',
        'total'         : ((p['total'] as num?) ?? 0).toInt(),
        'fechaPedido'   : fechaIso,
      };
    }).toList();

    final productosJson = productos.map((p) {
      final pVenta = ((p['precio']          as num?) ?? 0).toDouble();
      final pProv  = ((p['precioProveedor'] as num?) ?? 0).toDouble();
      final pctGan = pVenta > 0 ? ((pVenta - pProv) / pVenta * 100) : 0.0;
      return {
        'nombre'         : p['nombre']?.toString()    ?? '',
        'categoria'      : p['categoria']?.toString() ?? '',
        'precio'         : pVenta.toInt(),
        'precioProveedor': pProv.toInt(),
        'stock'          : ((p['stock'] as num?) ?? 0).toInt(),
        'codigo'         : p['codigo']?.toString()    ?? '',
        'pctGanancia'    : double.parse(pctGan.toStringAsFixed(1)),
      };
    }).toList();

    final response = await http
        .post(
          Uri.parse(_kExcelFunctionUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'pedidos'  : pedidosJson,
            'periodo'  : etiquetaPeriodo,
            'productos': productosJson,
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw Exception('Error del servidor: ${response.statusCode}\n${response.body}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data.containsKey('error')) throw Exception(data['error']);

    final bytes    = base64Decode(data['base64'] as String);
    final filename = data['filename'] as String? ??
        'reporte_granmolino_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';

    await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: filename);
  }

  // ── PDF ──────────────────────────────────────────────────────
  Future<void> exportarPdf(
    List<Map<String, dynamic>> pedidos,
    String etiquetaPeriodo, {
    List<Map<String, dynamic>> productos = const [],
  }) async {
    final doc    = pw.Document(title: 'Reporte Granero del Norte', author: 'Sistema Admin');
    final colores = _PdfColores();
    final kpis   = _calcularKpis(pedidos);
    final nowStr = DateFormat('dd/MM/yyyy  HH:mm').format(DateTime.now());

    String fmt(double n) => '\$${NumberFormat('#,##0', 'es_CO').format(n.round())}';
    String pct(double v) => '${v.toStringAsFixed(1)}%';

    // ── Helpers de celda ────────────────────────────────────────
    pw.Widget cell(String text, {
      PdfColor? bg, PdfColor? fg, bool bold = false, double size = 9,
      pw.Alignment align = pw.Alignment.centerLeft, double padH = 6, double padV = 5,
    }) {
      return pw.Container(
        color: bg,
        padding: pw.EdgeInsets.symmetric(horizontal: padH, vertical: padV),
        alignment: align,
        child: pw.Text(text,
            style: pw.TextStyle(
              fontSize: size,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: fg ?? colores.negro,
            )),
      );
    }

    pw.Widget thCell(String text) => cell(text,
        bg: colores.verde700, fg: colores.blanco, bold: true, size: 9,
        align: pw.Alignment.center, padV: 7);

    pw.TableRow headerRow(List<String> cols) =>
        pw.TableRow(children: cols.map(thCell).toList());

    pw.Widget kpiBox(String label, String value, String sub,
        PdfColor bg, PdfColor accent) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: bg,
          border: pw.Border.all(color: accent, width: 1.5),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8, color: accent, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(fontSize: 16, color: accent, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text(sub, style: pw.TextStyle(fontSize: 7, color: colores.gris3)),
        ]),
      );
    }

    pw.Widget barraVisual(double pctVal, PdfColor color) {
      final filled = (pctVal / 100 * 18).round().clamp(0, 18);
      final empty  = 18 - filled;
      return pw.Row(children: [
        pw.Text('█' * filled + '░' * empty,
            style: pw.TextStyle(fontSize: 7, color: color)),
        pw.SizedBox(width: 4),
        pw.Text(pct(pctVal), style: pw.TextStyle(fontSize: 8, color: colores.gris3)),
      ]);
    }

    // ── Tabla comparativa (reutilizable en cualquier página) ────
    pw.Widget tablaComparativa() {
      final diferencia   = kpis.totalPedidos - kpis.totalVentas;
      final pctCobrado   = kpis.totalPedidos > 0
          ? (kpis.totalVentas / kpis.totalPedidos * 100) : 0.0;
      final pctNoCobrado = 100.0 - pctCobrado;
      final noEntregados = kpis.total - kpis.entregados;

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: colores.verde50,
            child: pw.Text('  TOTAL PEDIDOS vs TOTAL VENTAS COBRADAS',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold,
                    color: colores.verde700)),
          ),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: colores.verde100, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3.0),
              1: const pw.FlexColumnWidth(2.0),
              2: const pw.FlexColumnWidth(1.2),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(3.5),
            },
            children: [
              headerRow(['Concepto', 'Valor', 'Pedidos', '% s/Total', 'Notas']),
              // Fila 1 — Total bruto de todos los pedidos
              pw.TableRow(children: [
                cell('Total pedidos del período', bg: colores.azul2, fg: colores.azul, bold: true),
                cell(fmt(kpis.totalPedidos), bg: colores.azul2, fg: colores.azul, bold: true, size: 11, align: pw.Alignment.center),
                cell('${kpis.total}',  bg: colores.azul2, align: pw.Alignment.center),
                cell('100%',           bg: colores.azul2, align: pw.Alignment.center),
                cell('Suma de TODOS los pedidos (cualquier estado)', bg: colores.azul2, fg: colores.gris3, size: 8),
              ]),
              // Fila 2 — Solo entregados = cobrado real
              pw.TableRow(children: [
                cell('Ventas cobradas (entregados)', bg: colores.verde100, fg: colores.verde700, bold: true),
                cell(fmt(kpis.totalVentas), bg: colores.verde100, fg: colores.verde700, bold: true, size: 11, align: pw.Alignment.center),
                cell('${kpis.entregados}', bg: colores.verde100, align: pw.Alignment.center),
                cell(pct(pctCobrado),      bg: colores.verde100, fg: colores.verde700, bold: true, align: pw.Alignment.center),
                cell('Solo pedidos con estado "entregado"', bg: colores.verde100, fg: colores.gris3, size: 8),
              ]),
              // Fila 3 — Diferencia (en curso / no cobrado)
              pw.TableRow(children: [
                cell('En curso / aún no cobrado',
                    bg: diferencia > 0 ? colores.amarillo : colores.verde50,
                    fg: diferencia > 0 ? colores.amarilloFc : colores.verde700, bold: true),
                cell(fmt(diferencia),
                    bg: diferencia > 0 ? colores.amarillo : colores.verde50,
                    fg: diferencia > 0 ? colores.amarilloFc : colores.verde700,
                    bold: true, size: 11, align: pw.Alignment.center),
                cell('$noEntregados',
                    bg: diferencia > 0 ? colores.amarillo : colores.verde50,
                    align: pw.Alignment.center),
                cell(pct(pctNoCobrado),
                    bg: diferencia > 0 ? colores.amarillo : colores.verde50,
                    fg: diferencia > 0 ? colores.amarilloFc : colores.verde700,
                    bold: true, align: pw.Alignment.center),
                cell('Pendiente + Confirmado + Despachado + Cancelado',
                    bg: diferencia > 0 ? colores.amarillo : colores.verde50,
                    fg: colores.gris3, size: 8),
              ]),
              // Fila total — cobertura
              pw.TableRow(children: [
                cell('COBERTURA DE COBRO', bg: colores.verde900, fg: colores.blanco, bold: true, size: 10),
                cell('${pctCobrado.toStringAsFixed(1)}% cobrado',
                    bg: colores.verde900, fg: colores.oro, bold: true, size: 11, align: pw.Alignment.center),
                cell('${kpis.entregados} de ${kpis.total}',
                    bg: colores.verde900, fg: colores.blanco, bold: true, align: pw.Alignment.center),
                pw.Container(color: colores.verde900),
                pw.Container(color: colores.verde900),
              ]),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'ℹ  "Total pedidos" incluye todos los estados. "Ventas cobradas" = solo entregados = dinero efectivamente cobrado.',
            style: pw.TextStyle(fontSize: 7, color: colores.gris3, fontStyle: pw.FontStyle.italic),
          ),
        ],
      );
    }

    // ══ PÁGINA 1: Resumen ══════════════════════════════════════
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(0),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Header
          pw.Container(
            color: colores.verde900,
            padding: const pw.EdgeInsets.fromLTRB(28, 20, 28, 20),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('GRANERO DEL NORTE',
                      style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: colores.blanco)),
                  pw.SizedBox(height: 2),
                  pw.Text('Reporte de Ventas & Pedidos',
                      style: pw.TextStyle(fontSize: 11, color: colores.verde300)),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text(nowStr, style: pw.TextStyle(fontSize: 9, color: colores.verde300)),
                  pw.SizedBox(height: 2),
                  pw.Text('Período: $etiquetaPeriodo',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: colores.blanco)),
                ]),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(24),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // KPIs — "VENTAS COBRADAS" en vez de "INGRESOS TOTALES"
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    color: colores.verde50,
                    child: pw.Text('  INDICADORES CLAVE DE RENDIMIENTO',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: colores.verde700)),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Row(children: [
                    pw.Expanded(child: kpiBox('TOTAL PEDIDOS', '${kpis.total}', 'en el período', colores.verde100, colores.verde700)),
                    pw.SizedBox(width: 8),
                    pw.Expanded(child: kpiBox('VENTAS COBRADAS', fmt(kpis.totalVentas), 'solo entregados', colores.kConf, PdfColor.fromHex('1B5E20'))),
                    pw.SizedBox(width: 8),
                    pw.Expanded(child: kpiBox('TICKET PROMEDIO', fmt(kpis.ticket), 'por pedido entregado', colores.kTick, colores.azul)),
                    pw.SizedBox(width: 8),
                    pw.Expanded(child: kpiBox('TASA DE ENTREGA', pct(kpis.tasaEntrega), '${kpis.entregados} de ${kpis.total}', colores.verde100, colores.verde500)),
                    pw.SizedBox(width: 8),
                    pw.Expanded(child: kpiBox('CANCELADOS', pct(kpis.pctCancelados), '${kpis.cancelados} pedido(s)', colores.rojo2, colores.rojo)),
                  ]),
                  pw.SizedBox(height: 20),

                  // Tabla distribución — ahora incluye Despachado
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    color: colores.verde50,
                    child: pw.Text('  DISTRIBUCIÓN POR ESTADO',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: colores.verde700)),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Table(
                    border: pw.TableBorder.all(color: colores.verde100, width: 0.5),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(2.5), 1: const pw.FlexColumnWidth(1.2),
                      2: const pw.FlexColumnWidth(1.2), 3: const pw.FlexColumnWidth(2),
                      4: const pw.FlexColumnWidth(3),
                    },
                    children: [
                      headerRow(['Estado', 'Pedidos', '% Total', 'Ventas (\$)', 'Participación Visual']),
                      pw.TableRow(children: [
                        cell('Pendiente',  bg: colores.gris1,    fg: colores.naranja),
                        cell('${kpis.pendientes}',  bg: colores.gris1,    align: pw.Alignment.center),
                        cell(pct(kpis.pctPendientes),  bg: colores.gris1,    align: pw.Alignment.center),
                        cell('—',          bg: colores.gris1,    align: pw.Alignment.center),
                        pw.Container(color: colores.gris1,    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                            child: barraVisual(kpis.pctPendientes, colores.naranja)),
                      ]),
                      pw.TableRow(children: [
                        cell('Confirmado', bg: colores.azul2,    fg: colores.azul),
                        cell('${kpis.confirmados}', bg: colores.azul2,    align: pw.Alignment.center),
                        cell(pct(kpis.pctConfirmados), bg: colores.azul2,    align: pw.Alignment.center),
                        cell('—',          bg: colores.azul2,    align: pw.Alignment.center),
                        pw.Container(color: colores.azul2,    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                            child: barraVisual(kpis.pctConfirmados, colores.azul)),
                      ]),
                      // NUEVO: Despachado
                      pw.TableRow(children: [
                        cell('Despachado', bg: colores.morado2,  fg: colores.morado),
                        cell('${kpis.despachados}', bg: colores.morado2,  align: pw.Alignment.center),
                        cell(pct(kpis.pctDespachados), bg: colores.morado2,  align: pw.Alignment.center),
                        cell('—',          bg: colores.morado2,  align: pw.Alignment.center),
                        pw.Container(color: colores.morado2,  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                            child: barraVisual(kpis.pctDespachados, colores.morado)),
                      ]),
                      pw.TableRow(children: [
                        cell('Entregado',  bg: colores.verde100, fg: colores.verde500),
                        cell('${kpis.entregados}',  bg: colores.verde100, align: pw.Alignment.center),
                        cell(pct(kpis.pctEntregados),  bg: colores.verde100, align: pw.Alignment.center),
                        cell(fmt(kpis.totalVentas), bg: colores.verde100, align: pw.Alignment.center),
                        pw.Container(color: colores.verde100, padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                            child: barraVisual(kpis.pctEntregados, colores.verde500)),
                      ]),
                      pw.TableRow(children: [
                        cell('Cancelado',  bg: colores.rojo2,    fg: colores.rojo),
                        cell('${kpis.cancelados}',  bg: colores.rojo2,    align: pw.Alignment.center),
                        cell(pct(kpis.pctCancelados),  bg: colores.rojo2,    align: pw.Alignment.center),
                        cell('—',          bg: colores.rojo2,    align: pw.Alignment.center),
                        pw.Container(color: colores.rojo2,    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                            child: barraVisual(kpis.pctCancelados, colores.rojo)),
                      ]),
                      // CORRECCIÓN: total muestra totalPedidos (todos), no solo entregados
                      pw.TableRow(children: [
                        cell('TOTAL GENERAL', bg: colores.verde900, fg: colores.blanco, bold: true, size: 10),
                        cell('${kpis.total}',            bg: colores.verde900, fg: colores.blanco, bold: true, size: 10, align: pw.Alignment.center),
                        cell('100%',                     bg: colores.verde900, fg: colores.blanco, bold: true, size: 10, align: pw.Alignment.center),
                        cell(fmt(kpis.totalPedidos),     bg: colores.verde900, fg: colores.oro, bold: true, size: 11, align: pw.Alignment.center),
                        pw.Container(color: colores.verde900),
                      ]),
                    ],
                  ),
                  pw.SizedBox(height: 20),

                  // TABLA COMPARATIVA en página 1
                  tablaComparativa(),

                  pw.Spacer(),
                  pw.Container(
                    color: colores.verde900,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: pw.Text(
                      'Generado automáticamente · Granero del Norte Admin · Datos en tiempo real desde Firestore',
                      style: pw.TextStyle(fontSize: 8, color: colores.verde300, fontStyle: pw.FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ));

    // ══ PÁGINA 2: Detalle ═════════════════════════════════════
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(0),
      header: (_) => pw.Column(children: [
        pw.Container(
          color: colores.verde900,
          padding: const pw.EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('DETALLE DE PEDIDOS (${kpis.total})',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: colores.blanco)),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('Actualizado: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 9, color: colores.verde300)),
              pw.Text('Período: $etiquetaPeriodo',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: colores.blanco)),
            ]),
          ]),
        ),
      ]),
      footer: (ctx) => pw.Container(
        color: colores.verde900,
        padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Los datos corresponden al período seleccionado.',
              style: pw.TextStyle(fontSize: 7, color: colores.verde300, fontStyle: pw.FontStyle.italic)),
          pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 7, color: colores.verde300)),
        ]),
      ),
      build: (_) => [
        pw.SizedBox(height: 16),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 24),
          child: pw.Table(
            border: pw.TableBorder.all(color: colores.verde100, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2.2), 1: const pw.FlexColumnWidth(2.8),
              2: const pw.FlexColumnWidth(1.8), 3: const pw.FlexColumnWidth(1.8),
              4: const pw.FlexColumnWidth(2.5),
            },
            children: [
              headerRow(['N° Pedido', 'Cliente', 'Estado', 'Total (\$)', 'Fecha']),
              ...pedidos.asMap().entries.map((e) {
                final idx    = e.key;
                final p      = e.value;
                final bg     = idx.isEven ? colores.blanco : colores.verde50;
                final estado = p['estado']?.toString() ?? 'pendiente';
                final tot    = ((p['total'] as num?) ?? 0.0).toDouble();
                PdfColor estColor;
                switch (estado) {
                  case 'confirmado': estColor = colores.azul;     break;
                  case 'despachado': estColor = colores.morado;   break;
                  case 'entregado':  estColor = colores.verde500; break;
                  case 'cancelado':  estColor = colores.rojo;     break;
                  default:           estColor = colores.naranja;
                }
                final ts = p['fechaPedido'] ?? p['creadoEn'];
                String fechaStr = '—';
                if (ts is Timestamp) {
                  try { fechaStr = DateFormat('dd/MM/yy HH:mm').format(ts.toDate()); } catch (_) {}
                }
                return pw.TableRow(children: [
                  cell(_getNumeroPedido(p), bg: bg, fg: colores.verde700, bold: true, size: 8, align: pw.Alignment.center),
                  cell(_getNombreCliente(p), bg: bg, size: 9),
                  cell(estado, bg: bg, fg: estColor, bold: true, size: 8, align: pw.Alignment.center),
                  // Cada pedido muestra su propio total (sin importar estado)
                  cell(fmt(tot), bg: bg, fg: colores.verde700, bold: true, size: 10, align: pw.Alignment.center),
                  cell(fechaStr, bg: bg, fg: colores.gris3, size: 8, align: pw.Alignment.center),
                ]);
              }),
              // CORRECCIÓN: total general = totalPedidos (todos los estados)
              pw.TableRow(children: [
                cell('TOTAL GENERAL (todos)', bg: colores.verde900, fg: colores.blanco, bold: true, size: 9, align: pw.Alignment.center),
                pw.Container(color: colores.verde900),
                pw.Container(color: colores.verde900),
                cell(fmt(kpis.totalPedidos), bg: colores.verde900, fg: colores.oro, bold: true, size: 12, align: pw.Alignment.center),
                pw.Container(color: colores.verde900),
              ]),
            ],
          ),
        ),
        pw.SizedBox(height: 24),

        // TABLA COMPARATIVA en página 2 (detalle)
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 24),
          child: tablaComparativa(),
        ),
        pw.SizedBox(height: 16),
      ],
    ));

    // ══ PÁGINA 3: Inventario (SOLO ADMIN) ════════════════════
    if (productos.isNotEmpty) {
      String fmtProv(double n) => '\$${NumberFormat('#,##0', 'es_CO').format(n.round())}';

      double totalInvProv  = 0;
      double totalInvVenta = 0;
      for (final p in productos) {
        final stock  = ((p['stock']           as num?) ?? 0).toDouble();
        final pProv  = ((p['precioProveedor'] as num?) ?? 0).toDouble();
        final pVenta = ((p['precio']          as num?) ?? 0).toDouble();
        totalInvProv  += stock * pProv;
        totalInvVenta += stock * pVenta;
      }
      final margenTotal = totalInvVenta - totalInvProv;

      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(0),
        header: (_) => pw.Column(children: [
          pw.Container(
            color: const PdfColor.fromInt(0xFF1B4332),
            padding: const pw.EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('INVENTARIO · PRECIOS PROVEEDOR',
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                pw.SizedBox(height: 3),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFFE65100),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text('CONFIDENCIAL · SOLO ADMINISTRADOR',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                ),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text(nowStr, style: pw.TextStyle(fontSize: 9, color: const PdfColor.fromInt(0xFF74C69D))),
                pw.Text('Período: $etiquetaPeriodo',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
              ]),
            ]),
          ),
        ]),
        footer: (ctx) => pw.Container(
          color: const PdfColor.fromInt(0xFF1B4332),
          padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 6),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('DOCUMENTO CONFIDENCIAL · USO EXCLUSIVO ADMINISTRACIÓN',
                style: pw.TextStyle(fontSize: 7, color: const PdfColor.fromInt(0xFF74C69D), fontStyle: pw.FontStyle.italic)),
            pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}',
                style: pw.TextStyle(fontSize: 7, color: const PdfColor.fromInt(0xFF74C69D))),
          ]),
        ),
        build: (_) => [
          pw.SizedBox(height: 14),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 24),
            child: pw.Row(children: [
              pw.Expanded(child: pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFFFF8E1),
                  border: pw.Border.all(color: const PdfColor.fromInt(0xFFE65100), width: 1.5),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('INVERSIÓN PROVEEDOR', style: pw.TextStyle(fontSize: 8, color: const PdfColor.fromInt(0xFFE65100), fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text(fmtProv(totalInvProv), style: pw.TextStyle(fontSize: 15, color: const PdfColor.fromInt(0xFFE65100), fontWeight: pw.FontWeight.bold)),
                  pw.Text('Precio inv. por proveedor', style: pw.TextStyle(fontSize: 7, color: colores.gris3)),
                ]),
              )),
              pw.SizedBox(width: 8),
              pw.Expanded(child: pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: colores.verde100,
                  border: pw.Border.all(color: colores.verde700, width: 1.5),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('VALOR DE VENTA', style: pw.TextStyle(fontSize: 8, color: colores.verde700, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text(fmtProv(totalInvVenta), style: pw.TextStyle(fontSize: 15, color: colores.verde700, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Precio de venta en stock', style: pw.TextStyle(fontSize: 7, color: colores.gris3)),
                ]),
              )),
              pw.SizedBox(width: 8),
              pw.Expanded(child: pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFE8F5E9),
                  border: pw.Border.all(color: const PdfColor.fromInt(0xFF1B5E20), width: 1.5),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('MARGEN BRUTO', style: pw.TextStyle(fontSize: 8, color: const PdfColor.fromInt(0xFF1B5E20), fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text(fmtProv(margenTotal), style: pw.TextStyle(fontSize: 15, color: const PdfColor.fromInt(0xFF1B5E20), fontWeight: pw.FontWeight.bold)),
                  pw.Text('Ganancia potencial en stock', style: pw.TextStyle(fontSize: 7, color: colores.gris3)),
                ]),
              )),
              pw.SizedBox(width: 8),
              pw.Expanded(child: pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFEDE7F6),
                  border: pw.Border.all(color: const PdfColor.fromInt(0xFF4527A0), width: 1.5),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('% GANANCIA PROM.', style: pw.TextStyle(fontSize: 8, color: const PdfColor.fromInt(0xFF4527A0), fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    totalInvProv > 0
                        ? '${(margenTotal / totalInvVenta * 100).toStringAsFixed(1)}%'
                        : '—',
                    style: pw.TextStyle(fontSize: 15, color: const PdfColor.fromInt(0xFF4527A0), fontWeight: pw.FontWeight.bold)),
                  pw.Text('Sobre precio de venta', style: pw.TextStyle(fontSize: 7, color: colores.gris3)),
                ]),
              )),
            ]),
          ),
          pw.SizedBox(height: 14),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 24),
            child: pw.Table(
              border: pw.TableBorder.all(color: colores.verde100, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.0),
                1: const pw.FlexColumnWidth(2.4),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(0.8),
                4: const pw.FlexColumnWidth(1.6),
                5: const pw.FlexColumnWidth(1.6),
                6: const pw.FlexColumnWidth(1.5),
                7: const pw.FlexColumnWidth(1.3),
              },
              children: [
                pw.TableRow(children: [
                  thCell('Código'), thCell('Producto'), thCell('Categoría'),
                  thCell('Stock'), thCell('P. x Unidad'), thCell('P. Prov. x Und.'),
                  thCell('Margen Unit.'), thCell('% Ganancia'),
                ]),
                ...productos.asMap().entries.map((e) {
                  final idx    = e.key;
                  final p      = e.value;
                  final bg     = idx.isEven ? colores.blanco : colores.verde50;
                  final pVenta = ((p['precio']          as num?) ?? 0).toDouble();
                  final pProv  = ((p['precioProveedor'] as num?) ?? 0).toDouble();
                  final margen = pVenta - pProv;
                  final margenColor = margen >= 0 ? colores.verde700 : colores.rojo;
                  final pctGan = pVenta > 0 ? (margen / pVenta * 100) : 0.0;
                  final pctColor = pctGan >= 0 ? const PdfColor.fromInt(0xFF4527A0) : colores.rojo;
                  return pw.TableRow(children: [
                    cell(p['codigo']?.toString()    ?? '—', bg: bg, fg: colores.gris3, size: 8, align: pw.Alignment.center),
                    cell(p['nombre']?.toString()    ?? '—', bg: bg, size: 8),
                    cell(p['categoria']?.toString() ?? '—', bg: bg, fg: colores.gris3, size: 8),
                    cell('${((p['stock'] as num?) ?? 0).toInt()}', bg: bg, align: pw.Alignment.center, size: 8),
                    cell(fmtProv(pVenta), bg: bg, fg: colores.verde700, bold: true, size: 9, align: pw.Alignment.center),
                    cell(fmtProv(pProv),  bg: bg, fg: const PdfColor.fromInt(0xFFE65100), bold: true, size: 9, align: pw.Alignment.center),
                    cell(fmtProv(margen), bg: bg, fg: margenColor, bold: true, size: 9, align: pw.Alignment.center),
                    cell('${pctGan.toStringAsFixed(1)}%', bg: bg, fg: pctColor, bold: true, size: 9, align: pw.Alignment.center),
                  ]);
                }),
                pw.TableRow(children: [
                  cell('TOTALES', bg: colores.verde900, fg: colores.blanco, bold: true, size: 9, align: pw.Alignment.center),
                  pw.Container(color: colores.verde900),
                  pw.Container(color: colores.verde900),
                  pw.Container(color: colores.verde900),
                  cell(fmtProv(totalInvVenta), bg: colores.verde900, fg: colores.oro, bold: true, size: 10, align: pw.Alignment.center),
                  cell(fmtProv(totalInvProv),  bg: colores.verde900, fg: const PdfColor.fromInt(0xFFFFCC80), bold: true, size: 10, align: pw.Alignment.center),
                  cell(fmtProv(margenTotal),   bg: colores.verde900, fg: colores.oro, bold: true, size: 10, align: pw.Alignment.center),
                  cell(
                    totalInvProv > 0 ? '${(margenTotal / totalInvVenta * 100).toStringAsFixed(1)}%' : '—',
                    bg: colores.verde900, fg: const PdfColor.fromInt(0xFFCE93D8), bold: true, size: 10, align: pw.Alignment.center),
                ]),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
        ],
      ));
    }

    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name: 'reporte_granmolino_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  // ── Helpers privados ─────────────────────────────────────────
  String _getNumeroPedido(Map<String, dynamic> p) =>
      p['numeroPedido']?.toString() ??
      p['idPedido']?.toString() ??
      p['_docId']?.toString() ?? '—';

  String _getNombreCliente(Map<String, dynamic> p) {
    if (p['nombreCliente'] != null) return p['nombreCliente'].toString();
    if (p['nombre']        != null) return p['nombre'].toString();
    final c = p['cliente'] as Map<String, dynamic>?;
    return c?['nombre']?.toString() ?? 'Sin nombre';
  }

  _KpisReporte _calcularKpis(List<Map<String, dynamic>> pedidos) {
    final total       = pedidos.length;
    final pendientes  = pedidos.where((p) => p['estado'] == 'pendiente').length;
    final confirmados = pedidos.where((p) => p['estado'] == 'confirmado').length;
    final despachados = pedidos.where((p) => p['estado'] == 'despachado').length;
    final entregados  = pedidos.where((p) => p['estado'] == 'entregado').length;
    final cancelados  = pedidos.where((p) => p['estado'] == 'cancelado').length;

    // totalVentas  = solo entregados → dinero real cobrado
    // totalPedidos = TODOS           → volumen bruto del período
    final totalVentas  = pedidos
        .where((p) => p['estado'] == 'entregado')
        .fold(0.0, (s, p) => s + ((p['total'] as num?) ?? 0.0));
    final totalPedidos = pedidos
        .fold(0.0, (s, p) => s + ((p['total'] as num?) ?? 0.0));

    final activos = entregados;
    return _KpisReporte(
      total: total,
      pendientes: pendientes,
      confirmados: confirmados,
      despachados: despachados,
      entregados: entregados,
      cancelados: cancelados,
      totalVentas: totalVentas,
      totalPedidos: totalPedidos,
      ticket: activos > 0 ? totalVentas / activos : 0.0,
      tasaEntrega: total > 0 ? entregados / total * 100 : 0.0,
      pctPendientes:  total > 0 ? pendientes  / total * 100 : 0.0,
      pctConfirmados: total > 0 ? confirmados / total * 100 : 0.0,
      pctDespachados: total > 0 ? despachados / total * 100 : 0.0,
      pctEntregados:  total > 0 ? entregados  / total * 100 : 0.0,
      pctCancelados:  total > 0 ? cancelados  / total * 100 : 0.0,
    );
  }
}

// ── Paleta de colores PDF ─────────────────────────────────────
class _PdfColores {
  final verde900    = PdfColor.fromHex('1B4332');
  final verde700    = PdfColor.fromHex('2D6A4F');
  final verde500    = PdfColor.fromHex('40916C');
  final verde300    = PdfColor.fromHex('74C69D');
  final verde100    = PdfColor.fromHex('D8F3DC');
  final verde50     = PdfColor.fromHex('F0FFF4');
  final blanco      = PdfColors.white;
  final gris1       = PdfColor.fromHex('F8F9FA');
  final gris3       = PdfColor.fromHex('6C757D');
  final negro       = PdfColor.fromHex('212529');
  final naranja     = PdfColor.fromHex('E67E22');
  final azul        = PdfColor.fromHex('1565C0');
  final azul2       = PdfColor.fromHex('EBF5FB');
  final rojo        = PdfColor.fromHex('C0392B');
  final rojo2       = PdfColor.fromHex('FFEBEE');
  final oro         = PdfColor.fromHex('F39C12');
  final kConf       = PdfColor.fromHex('C8E6C9');
  final kTick       = PdfColor.fromHex('BBDEFB');
  // Nuevo: morado para "despachado"
  final morado      = PdfColor.fromHex('6A1B9A');
  final morado2     = PdfColor.fromHex('EDE7F6');
  // Nuevo: amarillo para tabla comparativa
  final amarillo    = PdfColor.fromHex('FFF9C4');
  final amarilloFc  = PdfColor.fromHex('F57F17');
}

// ── DTO de KPIs ───────────────────────────────────────────────
class _KpisReporte {
  final int    total, pendientes, confirmados, despachados, entregados, cancelados;
  final double totalVentas, totalPedidos;   // ← reemplaza ingresos/ingresosConfirmados
  final double ticket, tasaEntrega;
  final double pctPendientes, pctConfirmados, pctDespachados, pctEntregados, pctCancelados;

  const _KpisReporte({
    required this.total,
    required this.pendientes,
    required this.confirmados,
    required this.despachados,
    required this.entregados,
    required this.cancelados,
    required this.totalVentas,
    required this.totalPedidos,
    required this.ticket,
    required this.tasaEntrega,
    required this.pctPendientes,
    required this.pctConfirmados,
    required this.pctDespachados,
    required this.pctEntregados,
    required this.pctCancelados,
  });
}