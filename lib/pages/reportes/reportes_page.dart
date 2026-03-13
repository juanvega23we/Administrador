import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'widgets/kpi_grid.dart';
import 'widgets/chart_card.dart';
import 'widgets/ingresos_card.dart';
import 'widgets/productos_mas_vendidos.dart';
import 'widgets/reportes_header.dart';
import 'widgets/stock_card.dart';
import '../../../widgets/notificacion_personalizada.dart';

const _kExcelFunctionUrl =
    'https://us-central1-el-gran-molino-6642d.cloudfunctions.net/generarReporteExcel';

const _kColor     = Color(0xFF00897B);
const _kColorDark = Color(0xFF004D40);

const _kStockMinDefault = 10;

class ReportesPage extends StatefulWidget {
  const ReportesPage({super.key});
  @override
  State<ReportesPage> createState() => _ReportesPageState();
}

class _ReportesPageState extends State<ReportesPage> {
  String    _periodo    = 'mes';
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  bool _exportandoExcel = false;
  bool _exportandoPdf   = false;

  List<Map<String, dynamic>> _pedidosCache  = [];
  List<Map<String, dynamic>> _topProductos  = [];
  bool   _loadingProds = false;
  String _ultimosIds   = '';

  // ─────────────────────────────────────────────────────────────────────────
  // FIX BUG-04: Límite de pedidos para el cálculo de top productos.
  // Antes: se cargaban TODOS los detalles en memoria del dispositivo.
  //        Con 1000+ pedidos podía consumir toda la RAM y colgar la app.
  // Ahora: se toman solo los últimos _kMaxPedidosTopProductos pedidos
  //        para el cálculo, lo que mantiene el tiempo de carga y la memoria
  //        bajo control sin afectar la utilidad del dato (los más recientes
  //        son los más relevantes para el ranking de productos).
  // ─────────────────────────────────────────────────────────────────────────
  static const int _kMaxPedidosTopProductos = 200;

  Future<void> _cargarTopProductos(List<Map<String, dynamic>> pedidos) async {
    // CORRECCIÓN BUG-04: limitar a los últimos N pedidos antes de consultar
    final pedidosLimitados = pedidos.length > _kMaxPedidosTopProductos
        ? pedidos.take(_kMaxPedidosTopProductos).toList()
        : pedidos;

    final ids = pedidosLimitados
        .where((p) => p['estado'] == 'confirmado' || p['estado'] == 'entregado')
        .map((p) => p['idPedido']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final clave = (List<String>.from(ids)..sort()).join(',');
    if (clave == _ultimosIds) return;
    _ultimosIds = clave;

    if (ids.isEmpty) {
      if (mounted) setState(() => _topProductos = []);
      return;
    }

    if (mounted) setState(() => _loadingProds = true);

    try {
      final Map<String, Map<String, dynamic>> prodMap = {};
      const batchSize = 30;

      for (int i = 0; i < ids.length; i += batchSize) {
        final batch = ids.sublist(i, (i + batchSize).clamp(0, ids.length));
        final snap  = await FirebaseFirestore.instance
            .collection('detalle_pedido')
            .where('idPedido', whereIn: batch)
            .get();

        for (final doc in snap.docs) {
          final d      = doc.data();
          final id     = (d['idProducto'] ?? doc.id).toString();
          final nombre = (d['nombreProducto'] ?? 'Sin nombre').toString();
          final cant   = (d['cantidad']  as num?)?.toInt()    ?? 0;
          final sub    = (d['subtotal']  as num?)?.toDouble() ?? 0.0;

          if (prodMap.containsKey(id)) {
            prodMap[id]!['cantidad'] = (prodMap[id]!['cantidad'] as int)    + cant;
            prodMap[id]!['ingresos'] = (prodMap[id]!['ingresos'] as double) + sub;
          } else {
            prodMap[id] = {'nombre': nombre, 'cantidad': cant, 'ingresos': sub};
          }
        }
      }

      final lista = prodMap.values.toList()
        ..sort((a, b) => (b['cantidad'] as int).compareTo(a['cantidad'] as int));

      if (mounted) setState(() {
        _topProductos = lista.take(5).toList();
        _loadingProds = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingProds = false);
    }
  }

  // ── FIX 1: fechaInicioEfectiva sin cambios + nuevo fechaFinEfectiva ──
  DateTime get _fechaInicioEfectiva {
    if (_periodo == 'custom' && _fechaInicio != null) return _fechaInicio!;
    final ahora = DateTime.now();
    switch (_periodo) {
      case 'hoy':    return DateTime(ahora.year, ahora.month, ahora.day);
      case 'semana': return ahora.subtract(const Duration(days: 7));
      default:       return DateTime(ahora.year, ahora.month, 1);
    }
  }

  // Cuando solo hay fechaInicio, el fin es ese mismo día (filtro de un solo día)
  DateTime? get _fechaFinEfectiva {
    if (_periodo != 'custom') return null;
    if (_fechaFin != null) return _fechaFin;
    if (_fechaInicio != null) return _fechaInicio; // mismo día como fin
    return null;
  }

  void _cambiarPeriodo(String nuevo) {
    setState(() {
      _periodo = nuevo; _fechaInicio = null;
      _fechaFin = null; _ultimosIds = '';
    });
  }

  Future<List<Map<String, dynamic>>> _fetchProductos() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('productos').get();
      return snap.docs.map((d) {
        final raw = d.data();
        return {
          'nombre':      (raw['nombre'] ?? raw['name'] ?? '—').toString(),
          'categoria':   (raw['categoria'] ?? '—').toString(),
          'stock':       (raw['stock']       as num?)?.toInt()    ?? 0,
          'stockMinimo': (raw['stockMinimo'] as num?)?.toInt()    ?? _kStockMinDefault,
          'precio':      (raw['precio'] ?? raw['precioVenta'] as num?)?.toDouble() ?? 0.0,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error cargando productos: $e');
      return [];
    }
  }

  Future<void> _exportarExcel() async {
    if (_pedidosCache.isEmpty) {
      _snack('No hay datos para exportar', TipoNotificacion.advertencia);
      return;
    }
    setState(() => _exportandoExcel = true);
    try {
      final pedidosJson = _pedidosCache.map((p) {
        final map = Map<String, dynamic>.from(p);
        for (final key in map.keys.toList()) {
          if (map[key] is Timestamp) {
            map[key] = (map[key] as Timestamp).toDate().toIso8601String();
          }
        }
        if (map['nombreCliente'] == null && map['cliente'] is Map) {
          map['nombreCliente'] = (map['cliente'] as Map)['nombre']?.toString() ?? '—';
        }
        return map;
      }).toList();

      final productosJson = await _fetchProductos();
      debugPrint('Productos a enviar al Excel: ${productosJson.length}');

      final response = await http.post(
        Uri.parse(_kExcelFunctionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'pedidos':   pedidosJson,
          'productos': productosJson,
          'periodo':   _etiquetaPeriodo(),
        }),
      );
      if (response.statusCode != 200) throw Exception('Error: ${response.statusCode}');
      final data     = jsonDecode(response.body) as Map<String, dynamic>;
      final bytes    = base64Decode(data['base64'] as String);
      final filename = data['filename'] as String? ??
          'reporte_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx';
      await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: filename);
      _snack('Excel exportado correctamente', TipoNotificacion.exito);
    } catch (e) {
      _snack('Error al exportar Excel: $e', TipoNotificacion.error);
    } finally {
      if (mounted) setState(() => _exportandoExcel = false);
    }
  }

  Future<void> _exportarPdf() async {
    if (_pedidosCache.isEmpty) {
      _snack('No hay datos para exportar', TipoNotificacion.advertencia);
      return;
    }
    setState(() => _exportandoPdf = true);
    try {
      final productos = await _fetchProductos();

      final doc       = pw.Document(title: 'Reporte Granero del Norte', author: 'Sistema Admin');
      final verde     = PdfColor.fromHex('00897B');
      final verdeOsc  = PdfColor.fromHex('00695C');
      final gris      = PdfColor.fromHex('F5F5F5');
      final grisTexto = PdfColor.fromHex('666666');
      final amarillo  = PdfColor.fromHex('FFF9C4');
      final rojo2     = PdfColor.fromHex('FFEBEE');
      final verde2    = PdfColor.fromHex('E8F5E9');

      final total      = _pedidosCache.length;
      final pendientes = _pedidosCache.where((p) => p['estado'] == 'pendiente').length;
      final confirmados= _pedidosCache.where((p) => p['estado'] == 'confirmado').length;
      final entregados = _pedidosCache.where((p) => p['estado'] == 'entregado').length;
      final cancelados = _pedidosCache.where((p) => p['estado'] == 'cancelado').length;
      final ingresos   = _pedidosCache
          .where((p) => p['estado'] == 'entregado' || p['estado'] == 'confirmado')
          .fold(0.0, (s, p) => s + ((p['total'] as num?) ?? 0.0));

      String estadoStock(Map p) {
        final s = (p['stock'] as num?)?.toInt() ?? 0;
        final m = (p['stockMinimo'] as num?)?.toInt() ?? _kStockMinDefault;
        if (s <= 0)  return 'sinStock';
        if (s <= m)  return 'bajo';
        return 'optimo';
      }

      final sinStockN = productos.where((p) => estadoStock(p) == 'sinStock').length;
      final bajosN    = productos.where((p) => estadoStock(p) == 'bajo').length;
      final okN       = productos.length - sinStockN - bajosN;
      final valorInv  = productos.fold<double>(0.0, (s, p) =>
          s + ((p['stock'] as num?)?.toDouble() ?? 0) *
              ((p['precio'] as num?)?.toDouble() ?? 0));

      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('GRANERO DEL NORTE',
                  style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: verde)),
              pw.Text('Reporte de Ventas y Pedidos',
                  style: pw.TextStyle(fontSize: 11, color: grisTexto)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('Periodo: ${_etiquetaPeriodo()}',
                  style: pw.TextStyle(fontSize: 10, color: grisTexto)),
              pw.Text('Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 10, color: grisTexto)),
            ]),
          ]),
          pw.Divider(color: verde, thickness: 2),
          pw.SizedBox(height: 4),
        ]),
        footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Granero del Norte — Reporte confidencial',
              style: pw.TextStyle(fontSize: 8, color: grisTexto)),
          pw.Text('Pagina ${ctx.pageNumber} de ${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: grisTexto)),
        ]),
        build: (ctx) => [
          pw.Text('DISTRIBUCION POR ESTADO',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: verde)),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColor.fromHex('E0E0E0'), width: 0.5),
            children: [
              pw.TableRow(decoration: pw.BoxDecoration(color: verdeOsc),
                  children: [_pdfTh('Estado'), _pdfTh('Cantidad'), _pdfTh('% del Total'), _pdfTh('Ingresos')]),
              _pdfEstadoRow('Pendiente',  pendientes,  total, null,  gris),
              _pdfEstadoRow('Confirmado', confirmados, total, _ingresosEstado('confirmado'), PdfColors.white),
              _pdfEstadoRow('Entregado',  entregados,  total, _ingresosEstado('entregado'),  gris),
              _pdfEstadoRow('Cancelado',  cancelados,  total, null,  PdfColors.white),
            ],
          ),
          pw.SizedBox(height: 20),

          pw.Text('DETALLE DE PEDIDOS ($total)',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: verde)),
          pw.SizedBox(height: 8),
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(2), 3: const pw.FlexColumnWidth(2),
              4: const pw.FlexColumnWidth(3),
            },
            border: pw.TableBorder.all(color: PdfColor.fromHex('E0E0E0'), width: 0.5),
            children: [
              pw.TableRow(decoration: pw.BoxDecoration(color: verdeOsc),
                  children: [_pdfTh('N Pedido'), _pdfTh('Cliente'), _pdfTh('Estado'), _pdfTh('Total'), _pdfTh('Fecha')]),
              ..._pedidosCache.asMap().entries.map((e) {
                final p  = e.value;
                final bg = e.key.isEven ? gris : PdfColors.white;
                return pw.TableRow(decoration: pw.BoxDecoration(color: bg), children: [
                  _pdfTd(p['numeroPedido']?.toString() ?? p['idPedido']?.toString() ?? '—'),
                  _pdfTd(_getNombreCliente(p)),
                  _pdfTd(_nombreEstado(p['estado']?.toString())),
                  _pdfTd('\$ ${_formatPrecioColombia(((p['total'] as num?) ?? 0.0).toDouble())}'),
                  _pdfTd(_formatFechaStr(p['fechaPedido'] ?? p['creadoEn'])),
                ]);
              }),
            ],
          ),
          pw.SizedBox(height: 24),

          if (productos.isNotEmpty) ...[
            pw.Divider(color: verde, thickness: 1),
            pw.SizedBox(height: 12),
            pw.Text('STOCK DE PRODUCTOS',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: verde)),
            pw.SizedBox(height: 8),
            pw.Row(children: [
              _pdfStockKpi('Total',      '${productos.length}',             PdfColors.grey100),
              pw.SizedBox(width: 6),
              _pdfStockKpi('Optimo',     '$okN',                            PdfColor.fromHex('E8F5E9')),
              pw.SizedBox(width: 6),
              _pdfStockKpi('Stock bajo', '$bajosN',                         PdfColor.fromHex('FFF9C4')),
              pw.SizedBox(width: 6),
              _pdfStockKpi('Sin stock',  '$sinStockN',                      PdfColor.fromHex('FFEBEE')),
              pw.SizedBox(width: 6),
              _pdfStockKpi('Valor inv.', '\$ ${_formatPrecioColombia(valorInv)}', PdfColors.grey100),
            ]),
            pw.SizedBox(height: 10),
            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(3.5),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(2),
                4: const pw.FlexColumnWidth(2),
              },
              border: pw.TableBorder.all(color: PdfColor.fromHex('E0E0E0'), width: 0.5),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: verdeOsc),
                  children: [
                    _pdfTh('Producto'), _pdfTh('Categoría'),
                    _pdfTh('Stock'),    _pdfTh('Estado'),
                    _pdfTh('Precio'),
                  ],
                ),
                ...(() {
                  final sorted = List<Map<String, dynamic>>.from(productos)
                    ..sort((a, b) {
                      int ord(Map p) {
                        final e = estadoStock(p);
                        if (e == 'sinStock') return 0;
                        if (e == 'bajo')     return 1;
                        return 2;
                      }
                      return ord(a).compareTo(ord(b));
                    });
                  return sorted.asMap().entries.map((e) {
                    final p     = e.value;
                    final stock = (p['stock'] as num?)?.toInt() ?? 0;
                    final precio= (p['precio'] as num?)?.toDouble() ?? 0.0;
                    final est   = estadoStock(p);
                    PdfColor bg;
                    String estadoTxt;
                    if (est == 'sinStock')  { bg = rojo2;    estadoTxt = 'Sin stock';  }
                    else if (est == 'bajo') { bg = amarillo; estadoTxt = 'Stock bajo'; }
                    else                   { bg = verde2;    estadoTxt = 'Optimo';     }
                    return pw.TableRow(decoration: pw.BoxDecoration(color: bg), children: [
                      _pdfTd(p['nombre'].toString()),
                      _pdfTd(p['categoria'].toString()),
                      _pdfTd('$stock'),
                      _pdfTd(estadoTxt),
                      _pdfTd(precio > 0 ? '\$ ${_formatPrecioColombia(precio)}' : '—'),
                    ]);
                  }).toList();
                })(),
              ],
            ),
          ],
        ],
      ));

      await Printing.layoutPdf(
        onLayout: (_) async => doc.save(),
        name: 'reporte_granmolino_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );
      _snack('PDF generado correctamente', TipoNotificacion.exito);
    } catch (e) {
      _snack('Error al exportar PDF: $e', TipoNotificacion.error);
    } finally {
      if (mounted) setState(() => _exportandoPdf = false);
    }
  }

  // ── Helpers PDF ───────────────────────────────────────────────
  pw.Widget _pdfTh(String text) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(text,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)));

  pw.Widget _pdfTd(String text) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: pw.Text(text, style: const pw.TextStyle(fontSize: 8)));

  pw.Widget _pdfStockKpi(String label, String value, PdfColor bg) =>
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(7),
          decoration: pw.BoxDecoration(
            color: bg,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
          ),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(label,  style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
            pw.SizedBox(height: 3),
            pw.Text(value,  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ]),
        ),
      );

  pw.TableRow _pdfEstadoRow(String estado, int cant, int total, double? ing, PdfColor bg) {
    final pct = total > 0 ? (cant / total * 100).toStringAsFixed(1) : '0.0';
    return pw.TableRow(decoration: pw.BoxDecoration(color: bg), children: [
      _pdfTd(estado), _pdfTd('$cant'), _pdfTd('$pct%'),
      _pdfTd(ing != null ? '\$ ${_formatPrecioColombia(ing)}' : '—'),
    ]);
  }

  double _ingresosEstado(String estado) => _pedidosCache
      .where((p) => p['estado'] == estado)
      .fold(0.0, (s, p) => s + ((p['total'] as num?) ?? 0.0));

  String _getNombreCliente(Map<String, dynamic> p) {
    if (p['nombreCliente'] != null) return p['nombreCliente'].toString();
    final c = p['cliente'] as Map<String, dynamic>?;
    return c?['nombre']?.toString() ?? 'Sin nombre';
  }

  String _nombreEstado(String? e) {
    switch (e) {
      case 'pendiente':  return 'Pendiente';
      case 'confirmado': return 'Confirmado';
      case 'entregado':  return 'Entregado';
      case 'cancelado':  return 'Cancelado';
      default:           return e ?? '—';
    }
  }

  String _formatFechaStr(dynamic ts) {
    if (ts == null || ts is! Timestamp) return 'Sin fecha';
    try { return DateFormat('dd/MM/yyyy HH:mm').format(ts.toDate()); }
    catch (_) { return '—'; }
  }

  String _formatPrecioColombia(double valor) {
    final formateador = NumberFormat('#,##0', 'es_CO');
    return formateador.format(valor.toInt());
  }

  // ── FIX 5: etiquetaPeriodo muestra fecha cuando solo hay un día ──
  String _etiquetaPeriodo() {
    switch (_periodo) {
      case 'hoy':    return 'Hoy';
      case 'semana': return 'Ultimos 7 dias';
      case 'custom':
        if (_fechaInicio != null && _fechaFin != null)
          return '${DateFormat('dd/MM/yy').format(_fechaInicio!)} – ${DateFormat('dd/MM/yy').format(_fechaFin!)}';
        if (_fechaInicio != null)
          return DateFormat('dd/MM/yy').format(_fechaInicio!); // un solo día
        return 'Personalizado';
      default: return 'Este mes';
    }
  }

  void _snack(String msg, TipoNotificacion tipo) {
    if (!mounted) return;
    NotificacionPersonalizada.mostrarSnack(context, mensaje: msg, tipo: tipo);
  }

  Future<void> _seleccionarFecha(bool esInicio) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: esInicio ? (_fechaInicio ?? DateTime.now()) : (_fechaFin ?? DateTime.now()),
      firstDate: DateTime(2020), lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _kColor, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (esInicio) _fechaInicio = picked; else _fechaFin = picked;
        _periodo = 'custom'; _ultimosIds = '';
      });
    }
  }

  void _mostrarFiltroFechas() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 4, height: 22,
                  decoration: BoxDecoration(color: _kColor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              const Text('Filtrar por rango de fechas',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 8),
            // ── FIX: aviso cuando solo se selecciona una fecha ──
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _fechaInicio != null && _fechaFin == null
                  ? Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Si no seleccionas fecha "Hasta", se filtrará solo el día ${DateFormat('dd/MM/yyyy').format(_fechaInicio!)}',
                            style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                          ),
                        ),
                      ]),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: FechaTile(label: 'Desde', fecha: _fechaInicio,
                  onTap: () async { await _seleccionarFecha(true); setModal(() {}); })),
              const SizedBox(width: 14),
              Expanded(child: FechaTile(label: 'Hasta', fecha: _fechaFin,
                  onTap: () async { await _seleccionarFecha(false); setModal(() {}); })),
            ]),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _fechaInicio = null; _fechaFin = null;
                    _periodo = 'mes'; _ultimosIds = '';
                  });
                  Navigator.pop(ctx);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kColor, side: const BorderSide(color: _kColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: const Text('Limpiar'),
              )),
              const SizedBox(width: 12),
              // ── FIX 3: Aplicar con aviso si solo hay fecha inicio ──
              Expanded(child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  if (_fechaInicio != null && _fechaFin == null) {
                    _snack(
                      'Mostrando datos del día ${DateFormat('dd/MM/yyyy').format(_fechaInicio!)}',
                      TipoNotificacion.advertencia,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kColor, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: const Text('Aplicar'),
              )),
            ]),
          ]),
        ),
      ),
    );
  }

  bool get _hayFiltroCustom => _periodo == 'custom';

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF0FAF8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE0F2F1))),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    Container(width: 5, height: 28,
                        decoration: BoxDecoration(color: _kColor, borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 12),
                    const Text('Reportes y Analisis',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                            color: _kColorDark, letterSpacing: -0.3)),
                  ]),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    HeaderIconBtn(icon: Icons.calendar_month_rounded, isActive: _hayFiltroCustom,
                        tooltip: 'Filtrar por fecha', onTap: _mostrarFiltroFechas),
                    const SizedBox(width: 10),
                    ExportBtn(label: 'Excel', icon: Icons.table_chart_rounded,
                        color: const Color(0xFF1E7145), loading: _exportandoExcel, onTap: _exportarExcel),
                    const SizedBox(width: 8),
                    ExportBtn(label: 'PDF', icon: Icons.picture_as_pdf_rounded,
                        color: const Color(0xFFE53935), loading: _exportandoPdf, onTap: _exportarPdf),
                  ]),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  PeriodChip(label: 'Hoy', isSelected: _periodo == 'hoy',
                      onTap: () => _cambiarPeriodo('hoy')),
                  const SizedBox(width: 8),
                  PeriodChip(label: '7 dias', isSelected: _periodo == 'semana',
                      onTap: () => _cambiarPeriodo('semana')),
                  const SizedBox(width: 8),
                  PeriodChip(label: 'Este mes', isSelected: _periodo == 'mes',
                      onTap: () => _cambiarPeriodo('mes')),
                  if (_hayFiltroCustom) ...[
                    const SizedBox(width: 8),
                    // ── FIX 4: chip muestra la fecha cuando es un solo día ──
                    PeriodChip(
                      label: _fechaInicio != null
                          ? (_fechaFin != null
                              ? '${DateFormat('dd/MM').format(_fechaInicio!)} – ${DateFormat('dd/MM').format(_fechaFin!)}'
                              : DateFormat('dd/MM').format(_fechaInicio!))
                          : 'Personalizado',
                      isSelected: true, color: const Color(0xFFD35400),
                      onTap: _mostrarFiltroFechas,
                    ),
                  ],
                ]),
                const SizedBox(height: 16),
              ]),
            ),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('pedido')
                    .where('fechaPedido',
                        isGreaterThanOrEqualTo: Timestamp.fromDate(_fechaInicioEfectiva))
                    .orderBy('fechaPedido', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: _kColor));
                  }

                  // ── FIX 2: filtro usa _fechaFinEfectiva (cubre también el caso de un solo día) ──
                  final pedidos = snapshot.data!.docs
                      .map((d) => d.data() as Map<String, dynamic>)
                      .where((p) {
                    if (_periodo == 'custom') {
                      final ts = p['fechaPedido'] ?? p['creadoEn'];
                      if (ts is! Timestamp) return false;
                      final fechaFin = _fechaFinEfectiva;
                      if (fechaFin == null) return true;
                      final fin = DateTime(
                          fechaFin.year, fechaFin.month, fechaFin.day, 23, 59, 59);
                      return !ts.toDate().isAfter(fin);
                    }
                    return true;
                  }).toList();

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _pedidosCache = List.from(pedidos);
                      _cargarTopProductos(pedidos);
                    }
                  });

                  final total      = pedidos.length;
                  final pendientes = pedidos.where((p) => p['estado'] == 'pendiente').length;
                  final confirmados= pedidos.where((p) => p['estado'] == 'confirmado').length;
                  final entregados = pedidos.where((p) => p['estado'] == 'entregado').length;
                  final cancelados = pedidos.where((p) => p['estado'] == 'cancelado').length;
                  final ingresos   = pedidos
                      .where((p) => p['estado'] == 'entregado' || p['estado'] == 'confirmado')
                      .fold(0.0, (s, p) => s + ((p['total'] as num?) ?? 0.0));
                  final activos = total - cancelados;
                  final ticket  = activos > 0 ? ingresos / activos : 0.0;

                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      KpiGrid(
                          totalPedidos: total, ingresos: ingresos,
                          ticketPromedio: ticket, entregados: entregados,
                          pendientes: pendientes, cancelados: cancelados),
                      const SizedBox(height: 24),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(flex: 5, child: ChartCard(
                            pendientes: pendientes, confirmados: confirmados,
                            entregados: entregados, cancelados: cancelados, total: total)),
                        const SizedBox(width: 16),
                        Expanded(flex: 3, child: IngresosCard(
                            ingresos: ingresos, ticketPromedio: ticket,
                            totalPedidos: total, entregados: entregados)),
                      ]),
                      const SizedBox(height: 24),
                      _loadingProds
                          ? Card(
                              elevation: 0, color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: Colors.grey.shade200),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.all(48),
                                child: Center(child: CircularProgressIndicator(color: _kColor)),
                              ),
                            )
                          : ProductosMasVendidos(productos: _topProductos),
                      const SizedBox(height: 24),
                      const StockCard(),
                      const SizedBox(height: 24),
                      SectionHeader(
                          icon: Icons.receipt_long_rounded,
                          label: 'Pedidos del periodo',
                          badge: total > 0 ? '$total' : null),
                      const SizedBox(height: 12),
                      if (pedidos.isEmpty)
                        const _EmptyState()
                      else
                        ...pedidos.map((p) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _PedidoCard(
                                pedido: p,
                                formatPrecioColombia: _formatPrecioColombia,
                              ),
                            )),
                      const SizedBox(height: 20),
                    ],
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PedidoCard extends StatefulWidget {
  final Map<String, dynamic> pedido;
  final Function(double) formatPrecioColombia;
  const _PedidoCard({required this.pedido, required this.formatPrecioColombia});
  @override
  State<_PedidoCard> createState() => _PedidoCardState();
}

class _PedidoCardState extends State<_PedidoCard> {
  bool _expandido = false;
  List<Map<String, dynamic>> _productos = [];
  bool _cargandoProductos = false;

  @override
  void initState() { super.initState(); _cargarProductos(); }

  Future<void> _cargarProductos() async {
    final idPedido = widget.pedido['idPedido']?.toString() ?? '';
    if (idPedido.isEmpty) return;
    setState(() => _cargandoProductos = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('detalle_pedido')
          .where('idPedido', isEqualTo: idPedido)
          .get();
      if (mounted) {
        setState(() {
          _productos = snap.docs.map((d) => d.data()).toList();
          _cargandoProductos = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cargandoProductos = false);
    }
  }

  String get _cliente {
    if (widget.pedido['nombreCliente'] != null) return widget.pedido['nombreCliente'].toString();
    final c = widget.pedido['cliente'] as Map<String, dynamic>?;
    return c?['nombre']?.toString() ?? 'Cliente no identificado';
  }

  String get _codigoPedido {
    final n = widget.pedido['numeroPedido']?.toString() ?? '';
    if (n.isNotEmpty) return n;
    return widget.pedido['idPedido']?.toString() ?? '—';
  }

  String _formatFecha(dynamic ts) {
    if (ts == null || ts is! Timestamp) return 'Sin fecha';
    try { return DateFormat('dd/MM/yyyy HH:mm').format(ts.toDate()); }
    catch (_) { return '—'; }
  }

  String _nombreEstado(String? e) {
    switch (e) {
      case 'pendiente':  return 'Pendiente';
      case 'confirmado': return 'Confirmado';
      case 'entregado':  return 'Entregado';
      case 'cancelado':  return 'Cancelado';
      default:           return e ?? '—';
    }
  }

  Color _colorEstado(String? e) {
    switch (e) {
      case 'pendiente':  return Colors.orange;
      case 'confirmado': return const Color(0xFF1976D2);
      case 'entregado':  return _kColor;
      case 'cancelado':  return Colors.redAccent;
      default:           return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = widget.pedido['estado'] ?? 'pendiente';
    final total  = (widget.pedido['total'] as num?)?.toDouble() ?? 0.0;
    final fecha  = _formatFecha(widget.pedido['fechaPedido'] ?? widget.pedido['creadoEn']);
    final color  = _colorEstado(estado);

    return Card(
      elevation: 0, color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _expandido = !_expandido),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(children: [
              Container(width: 4, height: 44,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 14),
              CircleAvatar(
                radius: 20, backgroundColor: color.withOpacity(0.1),
                child: Text(
                  _cliente.isNotEmpty ? _cliente[0].toUpperCase() : '?',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_cliente, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 4),
                Text(_codigoPedido,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(fecha, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('\$ ${widget.formatPrecioColombia(total)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _kColor)),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(_nombreEstado(estado),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                ),
              ]),
              const SizedBox(width: 8),
              Icon(_expandido ? Icons.expand_less : Icons.expand_more, color: Colors.grey[400]),
            ]),
          ),
        ),
        if (_expandido) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Productos',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey[700])),
              const SizedBox(height: 12),
              if (_cargandoProductos)
                const Center(child: CircularProgressIndicator(color: _kColor))
              else if (_productos.isEmpty)
                Text('Sin detalles de productos', style: TextStyle(color: Colors.grey[500]))
              else
                Column(children: _productos.map((prod) {
                  final nombre         = (prod['nombreProducto'] ?? prod['nombre'] ?? 'N/A').toString();
                  final cantidad        = prod['cantidad'] ?? 0;
                  final precioUnitario = (prod['precioUnitario'] as num?)?.toDouble() ?? 0.0;
                  final subtotal       = (prod['subtotal'] as num?)?.toDouble() ?? 0.0;
                  final omitido        = prod['omitido'] == true;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: omitido ? Colors.red[50] : Colors.teal[50],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('${cantidad}x',
                            style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12,
                              color: omitido ? Colors.red[300] : Colors.teal[700],
                            )),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(nombre,
                            style: TextStyle(
                              fontWeight: FontWeight.w500, fontSize: 13,
                              decoration: omitido ? TextDecoration.lineThrough : TextDecoration.none,
                              decorationColor: omitido ? Colors.grey[700] : null,
                              decorationThickness: omitido ? 2.0 : null,
                              color: omitido ? Colors.grey[700] : Colors.black87,
                            )),
                        const SizedBox(height: 2),
                        Text('\$ ${widget.formatPrecioColombia(precioUnitario)} c/u',
                            style: TextStyle(
                              fontSize: 11,
                              color: omitido ? Colors.grey[600] : Colors.grey[500],
                              decoration: omitido ? TextDecoration.lineThrough : TextDecoration.none,
                              decorationColor: omitido ? Colors.grey[600] : null,
                              decorationThickness: omitido ? 2.0 : null,
                            )),
                      ])),
                      if (omitido)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.red[100], borderRadius: BorderRadius.circular(4)),
                          child: Text('Sin stock',
                              style: TextStyle(fontSize: 10, color: Colors.red[700],
                                  fontWeight: FontWeight.w600)),
                        )
                      else
                        Text('\$ ${widget.formatPrecioColombia(subtotal)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13, color: _kColor)),
                    ]),
                  );
                }).toList()),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(children: [
            Icon(Icons.receipt_long_outlined, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 14),
            Text('No hay pedidos en este periodo',
                style: TextStyle(color: Colors.grey[500], fontSize: 15)),
          ]),
        ),
      );
}