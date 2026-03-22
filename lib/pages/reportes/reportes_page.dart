import 'dart:async';
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
import 'widgets/section_banners.dart';
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

  bool _topProductosPendiente      = false;
  bool _recalculandoTotales        = false;

  static const int _kMaxPedidosTopProductos = 200;

  /// Corrige en Firestore el `total` de pedidos con reenvío entregado
  /// que aún no tienen los campos `totalPrimeraEntrega` / `totalReenvio`.
  /// Esto resuelve pedidos creados antes de la corrección del bug.
  Future<void> _recalcularTotalesReenvio(List<Map<String, dynamic>> pedidos) async {
    if (_recalculandoTotales) return;
    _recalculandoTotales = true;

    try {
      final db = FirebaseFirestore.instance;

      final pendientes = pedidos.where((p) =>
          p['esReenvio']           == true &&
          p['estado']              == 'entregado' &&
          p['totalPrimeraEntrega'] == null,
      ).toList();

      for (final p in pendientes) {
        // El docId del pedido viene en __docId (inyectado en el StreamBuilder)
        final docId = p['__docId']?.toString() ?? '';
        if (docId.isEmpty) continue;

        try {
          final detalleSnap = await db
              .collection('detalle_pedido')
              .where('idPedido', isEqualTo: docId)
              .get();

          double subtotalEntrega = 0;
          double subtotalReenvio = 0;

          for (final doc in detalleSnap.docs) {
            final d      = doc.data();
            final precio = (d['precioUnitario'] as num?)?.toDouble() ?? 0.0;

            if (d['yaEntregado'] == true) {
              final cant = (d['cantidad'] as num?)?.toInt() ?? 0;
              subtotalEntrega += precio * cant;
            } else if (d['esProductoReenvio'] == true) {
              final cantReenv = (d['cantidadReenviada'] as num?)?.toInt() ?? 0;
              final cant      = cantReenv > 0 ? cantReenv : ((d['cantidad'] as num?)?.toInt() ?? 0);
              subtotalReenvio += precio * cant;
            } else {
              final cantDev   = (d['cantidadDevuelta']  as num?)?.toInt() ?? 0;
              final cantReenv = (d['cantidadReenviada'] as num?)?.toInt() ?? 0;
              if (cantDev > 0) {
                final cantOriginal  = (d['cantidadOriginal'] as num?)?.toInt() ?? 0;
                final cantEntregada = cantOriginal - cantDev;
                if (cantEntregada > 0) subtotalEntrega += precio * cantEntregada;
                if (cantReenv     > 0) subtotalReenvio += precio * cantReenv;
              }
            }
          }

          if (subtotalEntrega > 0 || subtotalReenvio > 0) {
            final totalFinal = subtotalEntrega + subtotalReenvio;
            await db.collection('pedido').doc(docId).update({
              'total'               : totalFinal,
              'totalPrimeraEntrega' : subtotalEntrega,
              'totalReenvio'        : subtotalReenvio,
            });
          }
        } catch (_) {
          // Si falla un pedido individual, continuar con los demás
        }
      }
    } finally {
      _recalculandoTotales = false;
    }
  }

  dynamic _sanitizarParaJson(dynamic valor) {
    if (valor is Timestamp) return valor.toDate().toIso8601String();
    if (valor is Map) return valor.map((k, v) => MapEntry(k.toString(), _sanitizarParaJson(v)));
    if (valor is List) return valor.map((e) => _sanitizarParaJson(e)).toList();
    return valor;
  }

  Future<void> _cargarTopProductos(List<Map<String, dynamic>> pedidos) async {
    final pedidosLimitados = pedidos.length > _kMaxPedidosTopProductos
        ? pedidos.take(_kMaxPedidosTopProductos).toList()
        : pedidos;

    final ids = pedidosLimitados
        .where((p) => p['estado'] == 'entregado')
        .map((p) => (p['__docId'] ?? p['idPedido'])?.toString() ?? '')
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
          final precio = (d['precioUnitario'] as num?)?.toDouble() ?? 0.0;

          // Ignorar productos omitidos por falta de stock
          if (d['omitido'] == true && d['yaEntregado'] != true) continue;
          // Ignorar productos totalmente devueltos sin reenvío
          if (d['devuelto'] == true && (d['cantidadDevuelta'] as num?)?.toInt() == 0) continue;

          int cantReal = 0;

          if (d['yaEntregado'] == true) {
            // Primera entrega normal
            cantReal = (d['cantidad'] as num?)?.toInt() ?? 0;
          } else if (d['esProductoReenvio'] == true) {
            // Producto nuevo del reenvío
            final cantReenv = (d['cantidadReenviada'] as num?)?.toInt() ?? 0;
            cantReal = cantReenv > 0 ? cantReenv : ((d['cantidad'] as num?)?.toInt() ?? 0);
          } else {
            final cantDev   = (d['cantidadDevuelta']  as num?)?.toInt() ?? 0;
            final cantReenv = (d['cantidadReenviada'] as num?)?.toInt() ?? 0;
            if (cantDev > 0) {
              // Devolución parcial: contar entregado + reenviado
              final cantOriginal  = (d['cantidadOriginal'] as num?)?.toInt() ??
                                    ((d['cantidad'] as num?)?.toInt() ?? 0);
              final cantEntregada = cantOriginal - cantDev;
              cantReal = cantEntregada + cantReenv;
            } else {
              // Producto normal entregado
              cantReal = (d['cantidad'] as num?)?.toInt() ?? 0;
            }
          }

          if (cantReal <= 0) continue;

          final sub = precio * cantReal;

          if (prodMap.containsKey(id)) {
            prodMap[id]!['cantidad'] = (prodMap[id]!['cantidad'] as int)    + cantReal;
            prodMap[id]!['ingresos'] = (prodMap[id]!['ingresos'] as double) + sub;
          } else {
            prodMap[id] = {'nombre': nombre, 'cantidad': cantReal, 'ingresos': sub};
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

  DateTime get _fechaInicioEfectiva {
    if (_periodo == 'custom' && _fechaInicio != null) return _fechaInicio!;
    final ahora = DateTime.now();
    switch (_periodo) {
      case 'hoy':    return DateTime(ahora.year, ahora.month, ahora.day);
      case 'semana': return ahora.subtract(const Duration(days: 7));
      default:       return DateTime(ahora.year, ahora.month, 1);
    }
  }

  DateTime? get _fechaFinEfectiva {
    if (_periodo != 'custom') return null;
    if (_fechaFin != null)    return _fechaFin;
    if (_fechaInicio != null) return _fechaInicio;
    return null;
  }

  void _cambiarPeriodo(String nuevo) {
    setState(() {
      _periodo = nuevo;
      _fechaInicio = null;
      _fechaFin    = null;
      _ultimosIds  = '';
    });
  }

  Future<List<Map<String, dynamic>>> _fetchProductos() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('productos').get();
      return snap.docs.map((d) {
        final raw = d.data();
        return {
          'nombre':          (raw['nombre'] ?? raw['name'] ?? '—').toString(),
          'categoria':       (raw['categoria'] ?? '—').toString(),
          'stock':           (raw['stock']           as num?)?.toInt()    ?? 0,
          'stockMinimo':     (raw['stockMinimo']     as num?)?.toInt()    ?? _kStockMinDefault,
          'precio':          (raw['precio'] ?? raw['precioVenta'] as num?)?.toDouble() ?? 0.0,
          'precioProveedor': (raw['precioProveedor'] as num?)?.toDouble() ?? 0.0,
          'codigo':          (raw['codigo'] ?? '—').toString(),
        };
      }).toList();
    } catch (e) {
      debugPrint('Error cargando productos: $e');
      return [];
    }
  }

  /// Carga devoluciones del período activo desde Firestore
  Future<List<Map<String, dynamic>>> _fetchDevoluciones() async {
    try {
      final inicio = Timestamp.fromDate(_fechaInicioEfectiva);

      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('devolucion')
          .where('fechaSolicitud', isGreaterThanOrEqualTo: inicio)
          .orderBy('fechaSolicitud', descending: true);

      if (_periodo == 'custom' && _fechaFinEfectiva != null) {
        final fin = DateTime(_fechaFinEfectiva!.year, _fechaFinEfectiva!.month,
            _fechaFinEfectiva!.day, 23, 59, 59);
        query = query.where('fechaSolicitud',
            isLessThanOrEqualTo: Timestamp.fromDate(fin));
      }

      final snap = await query.get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (e) {
      debugPrint('Error cargando devoluciones: $e');
      return [];
    }
  }

  String _labelMotivoDevPdf(dynamic productosDevueltos) {
    if (productosDevueltos is! List || productosDevueltos.isEmpty) return '—';
    final motivos = (productosDevueltos as List)
        .map((p) => _traducirMotivo(p['motivo']?.toString() ?? ''))
        .toSet()
        .join(', ');
    return motivos.isEmpty ? '—' : motivos;
  }

  String _resumenProductosDevPdf(dynamic productosDevueltos) {
    if (productosDevueltos is! List || productosDevueltos.isEmpty) return '—';
    return (productosDevueltos as List).map((p) {
      final nombre = p['nombre']?.toString() ?? '?';
      final cant   = p['cantidad']?.toString() ?? '0';
      return '$cant× $nombre';
    }).join('\n');
  }

  String _traducirMotivo(String motivo) {
    switch (motivo) {
      case 'defectuoso':          return 'Defectuoso';
      case 'equivocado':          return 'Equivocado';
      case 'cantidad_incorrecta': return 'Cant. incorrecta';
      case 'insatisfecho':        return 'Insatisfecho';
      case 'otro':                return 'Otro';
      default: return motivo.isNotEmpty ? motivo : '—';
    }
  }

  pw.Widget _pdfDevKpi(String label, String value, PdfColor color, PdfColor bg) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: pw.BoxDecoration(
          color: bg,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: color, width: 0.5),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8, color: color)),
          pw.SizedBox(height: 3),
          pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: color)),
        ]),
      ),
    );
  }
  Future<void> _exportarExcel() async {
    if (_pedidosCache.isEmpty) {
      _snack('No hay datos para exportar', TipoNotificacion.advertencia);
      return;
    }
    setState(() => _exportandoExcel = true);
    try {
      final pedidosJson = _pedidosCache.map((p) {
        final sanitized = _sanitizarParaJson(p) as Map<String, dynamic>;
        if (sanitized['nombreCliente'] == null && sanitized['cliente'] is Map) {
          sanitized['nombreCliente'] =
              (sanitized['cliente'] as Map)['nombre']?.toString() ?? '—';
        }
        return sanitized;
      }).toList();

      final productosJson    = await _fetchProductos();
      final devolucionesJson = await _fetchDevoluciones();

      // Preparar devoluciones con campos legibles para el Excel
      final devolucionesParaExcel = devolucionesJson.map((d) {
        final sanitized = _sanitizarParaJson(d) as Map<String, dynamic>;
        sanitized['resolucionLabel'] =
            d['resolucion'] == 'reenvio'   ? 'Reenvío'   :
            d['resolucion'] == 'reembolso' ? 'Reembolso' :
            d['resolucion']?.toString() ?? '—';
        sanitized['motivoLabel']      = _labelMotivoDevPdf(d['productosDevueltos']);
        sanitized['productosResumen'] = _resumenProductosDevPdf(d['productosDevueltos']);
        return sanitized;
      }).toList();

      final response = await http.post(
        Uri.parse(_kExcelFunctionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'pedidos':      pedidosJson,
          'productos':    productosJson,
          'devoluciones': devolucionesParaExcel,
          'periodo':      _etiquetaPeriodo(),
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

  // ── Modal selector PDF ────────────────────────────────────────
  Future<void> _mostrarOpcionesPdf() async {
    bool incluyePedidos   = true;
    bool incluyeProductos = true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          const color = Color(0xFFE53935);
          final puedeExportar = incluyePedidos || incluyeProductos;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            titlePadding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
            title: Row(children: [
              const Icon(Icons.picture_as_pdf_rounded, color: color, size: 22),
              const SizedBox(width: 10),
              const Text('Exportar PDF',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
            ]),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Selecciona qué secciones incluir:',
                  style: TextStyle(fontSize: 13, color: Colors.black54)),
              const SizedBox(height: 12),
              _checkTile(
                label: 'Pedidos', subtitle: 'Detalle y distribución de pedidos',
                icon: Icons.receipt_long_rounded, value: incluyePedidos, color: color,
                onChanged: (v) => setDlg(() => incluyePedidos = v!),
              ),
              const SizedBox(height: 8),
              _checkTile(
                label: 'Productos / Stock', subtitle: 'Inventario y estado de stock',
                icon: Icons.inventory_2_rounded, value: incluyeProductos, color: color,
                onChanged: (v) => setDlg(() => incluyeProductos = v!),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.select_all_rounded, size: 18),
                  label: const Text('Seleccionar todo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color, side: const BorderSide(color: color),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  onPressed: () => setDlg(() {
                    incluyePedidos = true; incluyeProductos = true;
                  }),
                ),
              ),
            ]),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar', style: TextStyle(color: Colors.black45)),
              ),
              ElevatedButton(
                onPressed: !puedeExportar ? null : () {
                  Navigator.pop(ctx);
                  _exportarPdf(conPedidos: incluyePedidos, conProductos: incluyeProductos);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: color, foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: const Text('Exportar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _checkTile({
    required String label, required String subtitle, required IconData icon,
    required bool value, required Color color, required ValueChanged<bool?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: value ? color.withOpacity(0.06) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: value ? color.withOpacity(0.4) : Colors.grey.shade200),
      ),
      child: CheckboxListTile(
        value: value, onChanged: onChanged, activeColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Row(children: [
          Icon(icon, size: 16, color: value ? color : Colors.grey),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600,
              color: value ? color : Colors.black87)),
        ]),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.black45)),
      ),
    );
  }

  // ── PDF ───────────────────────────────────────────────────────
  Future<void> _exportarPdf({
    bool conPedidos   = true,
    bool conProductos = true,
  }) async {
    if (_pedidosCache.isEmpty && conPedidos) {
      _snack('No hay datos para exportar', TipoNotificacion.advertencia);
      return;
    }
    setState(() => _exportandoPdf = true);
    try {
      final productos   = conProductos ? await _fetchProductos() : <Map<String, dynamic>>[];
      final devoluciones = await _fetchDevoluciones();

      final doc       = pw.Document(title: 'Reporte Granero del Norte', author: 'Sistema Admin');
      final verde     = PdfColor.fromHex('00897B');
      final verdeOsc  = PdfColor.fromHex('00695C');
      final gris      = PdfColor.fromHex('F5F5F5');
      final grisTexto = PdfColor.fromHex('666666');
      final amarillo  = PdfColor.fromHex('FFF9C4');
      final rojo2     = PdfColor.fromHex('FFEBEE');
      final verde2    = PdfColor.fromHex('E8F5E9');
      // Colores tabla comparativa — ya no se usan, se usa gris/white uniforme

      final total       = _pedidosCache.length;
      final pendientes  = _pedidosCache.where((p) => p['estado'] == 'pendiente').length;
      final confirmados = _pedidosCache.where((p) => p['estado'] == 'confirmado').length;
      final despachados = _pedidosCache.where((p) => p['estado'] == 'despachado').length;
      final entregados  = _pedidosCache.where((p) => p['estado'] == 'entregado').length;
      final cancelados  = _pedidosCache.where((p) => p['estado'] == 'cancelado').length;

      // ── CORRECCIÓN: dos totales distintos ──────────────────
      // totalVentas  = solo entregados  → dinero real cobrado
      // totalPedidos = TODOS los estados → volumen bruto
      final totalVentas  = _ingresosEstado('entregado');
      final totalPedidos = _pedidosCache.fold(0.0, (s, p) => s + _totalRealPedido(p));

      String estadoStock(Map p) {
        final s = (p['stock'] as num?)?.toInt() ?? 0;
        final m = (p['stockMinimo'] as num?)?.toInt() ?? _kStockMinDefault;
        if (s <= 0) return 'sinStock';
        if (s <= m) return 'bajo';
        return 'optimo';
      }

      final sinStockN = productos.where((p) => estadoStock(p) == 'sinStock').length;
      final bajosN    = productos.where((p) => estadoStock(p) == 'bajo').length;
      final okN       = productos.length - sinStockN - bajosN;

      final valorInv = productos.fold<double>(0.0, (s, p) =>
          s + ((p['stock'] as num?)?.toDouble() ?? 0) *
              ((p['precio'] as num?)?.toDouble() ?? 0));
      final valorInvProv = productos.fold<double>(0.0, (s, p) =>
          s + ((p['stock'] as num?)?.toDouble() ?? 0) *
              ((p['precioProveedor'] as num?)?.toDouble() ?? 0));
      final gananciaPotencial = valorInv - valorInvProv;
      final pctGanTotal = valorInv > 0 ? (gananciaPotencial / valorInv * 100) : 0.0;

      String fmtInv(double n) => '\$ ${NumberFormat('#,##0', 'es_CO').format(n.round())}';

      // ── Widget tabla comparativa reutilizable ───────────────
      List<pw.Widget> tablaComparativa() {
        final diferencia   = totalPedidos - totalVentas;
        final pctCobrado   = totalPedidos > 0 ? (totalVentas / totalPedidos * 100) : 0.0;
        final pctNoCobrado = 100.0 - pctCobrado;
        final noEntregados = total - entregados;

        pw.Widget compCell(String text, {
          PdfColor? bg, PdfColor? fg, bool bold = false, double size = 8,
        }) => pw.Container(
          color: bg,
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: pw.Text(text, style: pw.TextStyle(
            fontSize: size, color: fg, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          )),
        );

        return [
          pw.Text('TOTAL PEDIDOS vs TOTAL VENTAS COBRADAS',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: verde)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColor.fromHex('E0E0E0'), width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3.0),
              1: const pw.FlexColumnWidth(2.2),
              2: const pw.FlexColumnWidth(1.2),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(3.5),
            },
            children: [
              // Encabezado
              pw.TableRow(
                decoration: pw.BoxDecoration(color: verdeOsc),
                children: [
                  _pdfTh('Concepto'), _pdfTh('Valor'),
                  _pdfTh('Pedidos'), _pdfTh('% del Total'), _pdfTh('Notas'),
                ],
              ),
              // Fila 1 — todos los pedidos (gris)
              pw.TableRow(decoration: pw.BoxDecoration(color: gris), children: [
                compCell('Total pedidos del período'),
                compCell(fmtInv(totalPedidos)),
                compCell('$total'),
                compCell('100%'),
                compCell('Suma de TODOS los pedidos (cualquier estado)', fg: grisTexto, size: 7),
              ]),
              // Fila 2 — solo entregados (blanco)
              pw.TableRow(children: [
                compCell('Ventas cobradas (entregados)'),
                compCell(fmtInv(totalVentas)),
                compCell('$entregados'),
                compCell('${pctCobrado.toStringAsFixed(1)}%'),
                compCell('Solo pedidos con estado "entregado"', fg: grisTexto, size: 7),
              ]),
              // Fila 3 — diferencia (gris)
              pw.TableRow(decoration: pw.BoxDecoration(color: gris), children: [
                compCell('En curso / aún no cobrado'),
                compCell(fmtInv(diferencia)),
                compCell('$noEntregados'),
                compCell('${pctNoCobrado.toStringAsFixed(1)}%'),
                compCell('Pendiente + Confirmado + Despachado + Cancelado', fg: grisTexto, size: 7),
              ]),
              // Fila total — cobertura
              pw.TableRow(
                decoration: pw.BoxDecoration(color: verdeOsc),
                children: [
                  _pdfTh('COBERTURA DE COBRO'),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                    child: pw.Text('${pctCobrado.toStringAsFixed(1)}% cobrado',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('F39C12'))),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                    child: pw.Text('$entregados de $total',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white)),
                  ),
                  pw.Container(color: verdeOsc),
                  pw.Container(color: verdeOsc),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'ℹ  "Total pedidos" incluye todos los estados. "Ventas cobradas" = solo entregados = dinero efectivamente cobrado.',
            style: pw.TextStyle(fontSize: 7, color: grisTexto, fontStyle: pw.FontStyle.italic),
          ),
          pw.SizedBox(height: 20),
        ];
      }

      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        maxPages: 200,
        margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 48),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
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
                pw.Text('Generado: ${DateFormat("dd/MM/yyyy HH:mm").format(DateTime.now())}',
                    style: pw.TextStyle(fontSize: 10, color: grisTexto)),
              ]),
            ]),
            pw.Divider(color: verde, thickness: 2),
            pw.SizedBox(height: 4),
          ],
        ),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Pagina ${ctx.pageNumber} de ${ctx.pagesCount}',
                style: pw.TextStyle(fontSize: 8, color: grisTexto)),
          ],
        ),
        build: (ctx) => [

          // ── SECCIÓN PEDIDOS ──────────────────────────────────
          if (conPedidos) ...[
            pw.Text('DISTRIBUCION POR ESTADO',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: verde)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColor.fromHex('E0E0E0'), width: 0.5),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: verdeOsc),
                  children: [
                    _pdfTh('Estado'), _pdfTh('Cantidad'),
                    _pdfTh('% del Total'), _pdfTh('Ventas'),
                  ],
                ),
                _pdfEstadoRow('Pendiente',  pendientes,  total, null,          gris),
                _pdfEstadoRow('Confirmado', confirmados, total, null,          PdfColors.white),
                _pdfEstadoRow('Despachado', despachados, total, null,          gris),
                _pdfEstadoRow('Entregado',  entregados,  total, totalVentas,   PdfColors.white),
                _pdfEstadoRow('Cancelado',  cancelados,  total, null,          gris),
                // CORRECCIÓN: total muestra totalPedidos (todos), no solo entregados
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: verdeOsc),
                  children: [
                    _pdfTh('TOTAL GENERAL'),
                    _pdfTh('$total'),
                    _pdfTh('100%'),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                      child: pw.Text(
                        '\$ ${_formatPrecioColombia(totalPedidos)}',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('F39C12')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // ── TABLA COMPARATIVA (nueva) ──────────────────────
            ...tablaComparativa(),

            pw.Text('DETALLE DE PEDIDOS ($total)',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: verde)),
            pw.SizedBox(height: 8),
            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(2), 3: const pw.FlexColumnWidth(2),
                4: const pw.FlexColumnWidth(3),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: verdeOsc),
                  children: [
                    _pdfTh('N Pedido'), _pdfTh('Cliente'), _pdfTh('Estado'),
                    _pdfTh('Total'), _pdfTh('Fecha'),
                  ],
                ),
              ],
            ),
            ..._pedidosCache.asMap().entries.map((e) {
              final p   = e.value;
              final bg  = e.key.isEven ? gris : PdfColors.white;
              final est = p['estado']?.toString() ?? '';
              return pw.Table(
                columnWidths: {
                  0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(2), 3: const pw.FlexColumnWidth(2),
                  4: const pw.FlexColumnWidth(3),
                },
                border: pw.TableBorder(
                  left:   pw.BorderSide(color: PdfColor.fromHex('E0E0E0'), width: 0.5),
                  right:  pw.BorderSide(color: PdfColor.fromHex('E0E0E0'), width: 0.5),
                  bottom: pw.BorderSide(color: PdfColor.fromHex('E0E0E0'), width: 0.5),
                  verticalInside: pw.BorderSide(color: PdfColor.fromHex('E0E0E0'), width: 0.5),
                ),
                children: [
                  pw.TableRow(decoration: pw.BoxDecoration(color: bg), children: [
                    _pdfTd(p['numeroPedido']?.toString() ?? p['idPedido']?.toString() ?? '—'),
                    _pdfTd(_getNombreCliente(p)),
                    _pdfTd(_nombreEstado(est)),
                    // Cada pedido muestra su propio total (sin filtrar por estado)
                    _pdfTd('\$ ${_formatPrecioColombia(((p['total'] as num?) ?? 0.0).toDouble())}'),
                    _pdfTd(_formatFechaStr(p['fechaPedido'] ?? p['creadoEn'])),
                  ]),
                ],
              );
            }),
            // CORRECCIÓN: total general = totalPedidos (todos los estados)
            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(2), 3: const pw.FlexColumnWidth(2),
                4: const pw.FlexColumnWidth(3),
              },
              children: [
                pw.TableRow(decoration: pw.BoxDecoration(color: verdeOsc), children: [
                  _pdfTh('TOTAL GENERAL'), _pdfTh(''), _pdfTh(''),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                    child: pw.Text('\$ ${_formatPrecioColombia(totalPedidos)}',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('F39C12'))),
                  ),
                  _pdfTh(''),
                ]),
              ],
            ),
            pw.SizedBox(height: 24),

            // ── SECCIÓN DEVOLUCIONES ─────────────────────────
            if (devoluciones.isNotEmpty) ...[ 
              pw.Divider(color: verde, thickness: 1),
              pw.SizedBox(height: 12),
              pw.Text('DEVOLUCIONES DEL PERÍODO',
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: verde)),
              pw.SizedBox(height: 10),
              // KPIs rápidos
              pw.Row(children: [
                _pdfDevKpi('Total devoluciones', '${devoluciones.length}',
                    verdeOsc, gris),
                pw.SizedBox(width: 6),
                _pdfDevKpi('Reenvíos',
                    '${devoluciones.where((d) => d["resolucion"] == "reenvio").length}',
                    verdeOsc, gris),
                pw.SizedBox(width: 6),
                _pdfDevKpi('Reembolsos',
                    '${devoluciones.where((d) => d["resolucion"] == "reembolso").length}',
                    verdeOsc, gris),
                pw.SizedBox(width: 6),
                _pdfDevKpi('Monto total devuelto',
                    '\$ ${_formatPrecioColombia(devoluciones.fold(0.0, (s, d) => s + ((d["montoDevolucion"] as num?)?.toDouble() ?? 0.0)))}',
                    verdeOsc, gris),
              ]),
              pw.SizedBox(height: 10),
              // Tabla devoluciones
              pw.Table(
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.8),
                  1: const pw.FlexColumnWidth(2.0),
                  2: const pw.FlexColumnWidth(2.5),
                  3: const pw.FlexColumnWidth(3.5),
                  4: const pw.FlexColumnWidth(2.0),
                  5: const pw.FlexColumnWidth(1.8),
                  6: const pw.FlexColumnWidth(1.8),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: verdeOsc),
                    children: [
                      _pdfTh('Fecha'),
                      _pdfTh('N° Pedido'),
                      _pdfTh('Cliente'),
                      _pdfTh('Productos devueltos'),
                      _pdfTh('Motivo'),
                      _pdfTh('Resolución'),
                      _pdfTh('Monto'),
                    ],
                  ),
                ],
              ),
              ...devoluciones.asMap().entries.map((e) {
                final d   = e.value;
                final bg  = e.key.isEven ? gris : PdfColors.white;
                final res = d['resolucion']?.toString() ?? '';
                final resLabel = res == 'reenvio' ? 'Reenvío' : res == 'reembolso' ? 'Reembolso' : res;
                final motivo = _labelMotivoDevPdf(d['productosDevueltos']);
                final productos_dev = _resumenProductosDevPdf(d['productosDevueltos']);
                return pw.Table(
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1.8),
                    1: const pw.FlexColumnWidth(2.0),
                    2: const pw.FlexColumnWidth(2.5),
                    3: const pw.FlexColumnWidth(3.5),
                    4: const pw.FlexColumnWidth(2.0),
                    5: const pw.FlexColumnWidth(1.8),
                    6: const pw.FlexColumnWidth(1.8),
                  },
                  border: pw.TableBorder.all(color: PdfColor.fromHex('E0E0E0'), width: 0.5),
                  children: [
                    pw.TableRow(decoration: pw.BoxDecoration(color: bg), children: [
                      _pdfTd(_formatFechaStr(d['fechaSolicitud'])),
                      _pdfTd(d['numeroPedido']?.toString() ?? '—'),
                      _pdfTd(d['nombreCliente']?.toString() ?? '—'),
                      _pdfTd(productos_dev),
                      _pdfTd(motivo),
                      _pdfTd(resLabel),
                      _pdfTd('\$ ${_formatPrecioColombia((d["montoDevolucion"] as num?)?.toDouble() ?? 0.0)}'),
                    ]),
                  ],
                );
              }),
              pw.SizedBox(height: 24),
            ],
          ],

          // ── SECCIÓN PRODUCTOS / STOCK ────────────────────────
          if (conProductos && productos.isNotEmpty) ...[
            pw.Divider(color: verde, thickness: 1),
            pw.SizedBox(height: 12),
            pw.Text('STOCK DE PRODUCTOS',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: verde)),
            pw.SizedBox(height: 10),
            pw.Row(children: [
              _pdfStockKpi('Total productos', '${productos.length}', PdfColors.grey600, PdfColors.grey100),
              pw.SizedBox(width: 6),
              _pdfStockKpi('Óptimo',     '$okN',      PdfColor.fromHex('2D6A4F'), PdfColor.fromHex('D8F3DC')),
              pw.SizedBox(width: 6),
              _pdfStockKpi('Stock bajo', '$bajosN',   PdfColor.fromHex('E67E22'), PdfColor.fromHex('FFF9C4')),
              pw.SizedBox(width: 6),
              _pdfStockKpi('Sin stock',  '$sinStockN', PdfColor.fromHex('C0392B'), PdfColor.fromHex('FFEBEE')),
            ]),
            pw.SizedBox(height: 10),
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Expanded(child: _pdfInvKpi('VALOR INV. VENTA',      fmtInv(valorInv),          'Precio de venta × stock actual')),
              pw.SizedBox(width: 8),
              pw.Expanded(child: _pdfInvKpi('VALOR INV. COSTO',      fmtInv(valorInvProv),       'Precio proveedor × stock actual')),
              pw.SizedBox(width: 8),
              pw.Expanded(child: _pdfInvKpi('GANANCIA POTENCIAL',    fmtInv(gananciaPotencial),  'Venta − costo del inventario')),
              pw.SizedBox(width: 8),
              pw.Expanded(child: _pdfInvKpi('MARGEN TOTAL',
                  valorInv > 0 ? '${pctGanTotal.toStringAsFixed(1)}%' : '—',
                  'Ganancia sobre precio de venta')),
            ]),
            pw.SizedBox(height: 12),
            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(3.0), 1: const pw.FlexColumnWidth(1.8),
                2: const pw.FlexColumnWidth(1.2), 3: const pw.FlexColumnWidth(1.8),
                4: const pw.FlexColumnWidth(1.8), 5: const pw.FlexColumnWidth(2.0),
                6: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: verdeOsc),
                  children: [
                    _pdfTh('Producto'), _pdfTh('Categoría'), _pdfTh('Stock'),
                    _pdfTh('Estado'),   _pdfTh('Precio venta x Und.'),
                    _pdfTh('Precio costo x Und.'), _pdfTh('% Ganancia'),
                  ],
                ),
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
                final p      = e.value;
                final stock  = (p['stock']  as num?)?.toInt()    ?? 0;
                final precio = (p['precio'] as num?)?.toDouble() ?? 0.0;
                final pProv  = (p['precioProveedor'] as num?)?.toDouble() ?? 0.0;
                final margen = precio - pProv;
                final pctGan = precio > 0 ? (margen / precio * 100) : 0.0;
                final est    = estadoStock(p);
                PdfColor bg; String estadoTxt;
                if (est == 'sinStock')  { bg = rojo2;    estadoTxt = 'Sin stock';  }
                else if (est == 'bajo') { bg = amarillo; estadoTxt = 'Stock bajo'; }
                else                   { bg = verde2;    estadoTxt = 'Optimo';     }
                final pctColor = pctGan >= 0
                    ? PdfColor.fromHex('2E7D32') : PdfColor.fromHex('C62828');
                return pw.Table(
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3.0), 1: const pw.FlexColumnWidth(1.8),
                    2: const pw.FlexColumnWidth(1.2), 3: const pw.FlexColumnWidth(1.8),
                    4: const pw.FlexColumnWidth(1.8), 5: const pw.FlexColumnWidth(2.0),
                    6: const pw.FlexColumnWidth(1.5),
                  },
                  border: pw.TableBorder(
                    left:   pw.BorderSide(color: PdfColor.fromHex('E0E0E0'), width: 0.5),
                    right:  pw.BorderSide(color: PdfColor.fromHex('E0E0E0'), width: 0.5),
                    bottom: pw.BorderSide(color: PdfColor.fromHex('E0E0E0'), width: 0.5),
                    verticalInside: pw.BorderSide(color: PdfColor.fromHex('E0E0E0'), width: 0.5),
                  ),
                  children: [
                    pw.TableRow(decoration: pw.BoxDecoration(color: bg), children: [
                      _pdfTd(p['nombre'].toString()),
                      _pdfTd(p['categoria'].toString()),
                      _pdfTd('$stock'),
                      _pdfTd(estadoTxt),
                      _pdfTd(precio > 0 ? '\$ ${_formatPrecioColombia(precio)}' : '—'),
                      _pdfTd(pProv  > 0 ? '\$ ${_formatPrecioColombia(pProv)}'  : '—',
                          color: PdfColor.fromHex('E65100')),
                      _pdfTd(pProv  > 0 ? '${pctGan.toStringAsFixed(1)}%' : '—',
                          color: pctColor, bold: true),
                    ]),
                  ],
                );
              }).toList();
            })(),
          ],
        ],
      ));

      await Printing.layoutPdf(
        onLayout: (_) async => doc.save(),
        name: 'reporte_granmolino_${DateFormat("yyyyMMdd").format(DateTime.now())}.pdf',
      );
      _snack('PDF generado correctamente', TipoNotificacion.exito);
    } catch (e) {
      _snack('Error al exportar PDF: $e', TipoNotificacion.error);
    } finally {
      if (mounted) setState(() => _exportandoPdf = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────
  String _getNombreCliente(Map<String, dynamic> p) {
    if (p['nombreCliente'] != null) return p['nombreCliente'].toString();
    final c = p['cliente'] as Map<String, dynamic>?;
    return c?['nombre']?.toString() ?? 'Sin nombre';
  }

  String _formatPrecioColombia(double valor) =>
      NumberFormat('#,##0', 'es_CO').format(valor.toInt());

  String _etiquetaPeriodo() {
    switch (_periodo) {
      case 'hoy':    return 'Hoy';
      case 'semana': return 'Ultimos 7 dias';
      case 'custom':
        if (_fechaInicio != null && _fechaFin != null)
          return '${DateFormat('dd/MM/yy').format(_fechaInicio!)} – ${DateFormat('dd/MM/yy').format(_fechaFin!)}';
        if (_fechaInicio != null) return DateFormat('dd/MM/yy').format(_fechaInicio!);
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
        _periodo    = 'custom';
        _ultimosIds = '';
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
                        Expanded(child: Text(
                          'Si no seleccionas fecha "Hasta", se filtrará solo el día ${DateFormat('dd/MM/yyyy').format(_fechaInicio!)}',
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                        )),
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
                  setState(() { _fechaInicio = null; _fechaFin = null; _periodo = 'mes'; _ultimosIds = ''; });
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
              Expanded(child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  if (_fechaInicio != null && _fechaFin == null) {
                    _snack('Mostrando datos del día ${DateFormat('dd/MM/yyyy').format(_fechaInicio!)}',
                        TipoNotificacion.advertencia);
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
                    const Text('Reportes y Análisis',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                            color: _kColorDark, letterSpacing: -0.3)),
                  ]),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    HeaderIconBtn(
                      icon: Icons.calendar_month_rounded,
                      isActive: _hayFiltroCustom,
                      tooltip: 'Filtrar por fecha',
                      onTap: _mostrarFiltroFechas,
                    ),
                    const SizedBox(width: 10),
                    ExportBtn(
                      label: 'Excel', icon: Icons.table_chart_rounded,
                      color: const Color(0xFF1E7145),
                      loading: _exportandoExcel, onTap: _exportarExcel,
                    ),
                    const SizedBox(width: 8),
                    ExportBtn(
                      label: 'PDF', icon: Icons.picture_as_pdf_rounded,
                      color: const Color(0xFFE53935),
                      loading: _exportandoPdf, onTap: _mostrarOpcionesPdf,
                    ),
                  ]),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  PeriodChip(label: 'Hoy',      isSelected: _periodo == 'hoy',    onTap: () => _cambiarPeriodo('hoy')),
                  const SizedBox(width: 8),
                  PeriodChip(label: '7 días',   isSelected: _periodo == 'semana', onTap: () => _cambiarPeriodo('semana')),
                  const SizedBox(width: 8),
                  PeriodChip(label: 'Este mes', isSelected: _periodo == 'mes',    onTap: () => _cambiarPeriodo('mes')),
                  if (_hayFiltroCustom) ...[
                    const SizedBox(width: 8),
                    PeriodChip(
                      label: _fechaInicio != null
                          ? (_fechaFin != null
                              ? '${DateFormat('dd/MM').format(_fechaInicio!)} – ${DateFormat('dd/MM').format(_fechaFin!)}'
                              : DateFormat('dd/MM').format(_fechaInicio!))
                          : 'Personalizado',
                      isSelected: true,
                      color: const Color(0xFFD35400),
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

                  final pedidos = snapshot.data!.docs
                      .map((d) {
                        final data = d.data() as Map<String, dynamic>;
                        // Incluir el docId para poder buscar en detalle_pedido
                        data['__docId'] = d.id;
                        return data;
                      })
                      .where((p) {
                    if (_periodo == 'custom') {
                      final ts = p['fechaPedido'] ?? p['creadoEn'];
                      if (ts is! Timestamp) return false;
                      final fechaFin = _fechaFinEfectiva;
                      if (fechaFin == null) return true;
                      final fin = DateTime(fechaFin.year, fechaFin.month, fechaFin.day, 23, 59, 59);
                      return !ts.toDate().isAfter(fin);
                    }
                    return true;
                  }).toList();

                  if (!_topProductosPendiente) {
                    _topProductosPendiente = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _topProductosPendiente = false;
                      if (mounted) {
                        _pedidosCache = List.from(pedidos);
                        _cargarTopProductos(pedidos);
                        // Corregir totales de pedidos con reenvío entregado
                        // que aún no tienen los campos nuevos en Firestore
                        _recalcularTotalesReenvio(pedidos);
                      }
                    });
                  }

                  final total       = pedidos.length;
                  final pendientes  = pedidos.where((p) => p['estado'] == 'pendiente').length;
                  final confirmados = pedidos.where((p) => p['estado'] == 'confirmado').length;
                  final entregados  = pedidos.where((p) => p['estado'] == 'entregado').length;
                  final cancelados  = pedidos.where((p) => p['estado'] == 'cancelado').length;
                  final ingresos    = pedidos
                      .where((p) => p['estado'] == 'entregado')
                      .fold(0.0, (s, p) => s + _totalRealPedido(p));
                  final activos = entregados;
                  final ticket  = activos > 0 ? ingresos / activos : 0.0;

                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      KpiGrid(
                          totalPedidos: total, ingresos: ingresos,
                          ticketPromedio: ticket, entregados: entregados,
                          pendientes: pendientes, cancelados: cancelados,
                          confirmados: confirmados),
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
                      SectionBanners(
                        topProductos    : _topProductos,
                        loadingProds    : _loadingProds,
                        pedidos         : pedidos,
                        formatPrecio    : _formatPrecioColombia,
                        kStockMinDefault: _kStockMinDefault,
                      ),
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

  // ── Helpers PDF ───────────────────────────────────────────────
  pw.Widget _pdfTh(String text) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(text, style: pw.TextStyle(
            fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)));

  pw.Widget _pdfTd(String text, {PdfColor? color, bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: pw.Text(text, style: pw.TextStyle(
            fontSize: 8, color: color,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)));

  pw.Widget _pdfStockKpi(String label, String value, PdfColor color, PdfColor bg) =>
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(7),
          decoration: pw.BoxDecoration(
            color: bg,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            border: pw.Border.all(color: color, width: 0.5),
          ),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(label, style: pw.TextStyle(fontSize: 7, color: color)),
            pw.SizedBox(height: 3),
            pw.Text(value, style: pw.TextStyle(
                fontSize: 9, fontWeight: pw.FontWeight.bold, color: color)),
          ]),
        ),
      );

  // Helper para KPIs de inventario (extraído para no repetir código)
  pw.Widget _pdfInvKpi(String label, String value, String sub) => pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      borderRadius: pw.BorderRadius.circular(8),
      border: pw.Border.all(color: PdfColor.fromHex('2D6A4F'), width: 1.5),
    ),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(label, style: pw.TextStyle(
          fontSize: 7, color: PdfColor.fromHex('2D6A4F'), fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 7),
      pw.Text(value, style: pw.TextStyle(
          fontSize: 13, color: PdfColor.fromHex('1B4332'), fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      pw.Text(sub, style: pw.TextStyle(fontSize: 6.5, color: PdfColors.grey500)),
    ]),
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
      .fold(0.0, (s, p) => s + _totalRealPedido(p));

  /// Devuelve el total real de un pedido, considerando reenvíos.
  /// Para pedidos con reenvío ya entregado, usa totalPrimeraEntrega + totalReenvio
  /// si están disponibles, de lo contrario usa el campo total directamente.
  double _totalRealPedido(Map<String, dynamic> p) {
    if (p['esReenvio'] == true && p['estado'] == 'entregado') {
      final primeraEntrega = (p['totalPrimeraEntrega'] as num?)?.toDouble();
      final reenvio        = (p['totalReenvio']        as num?)?.toDouble();
      if (primeraEntrega != null && reenvio != null) {
        return primeraEntrega + reenvio;
      }
    }
    return (p['total'] as num?)?.toDouble() ?? 0.0;
  }

  String _nombreEstado(String? e) {
    switch (e) {
      case 'pendiente':  return 'Pendiente';
      case 'confirmado': return 'Confirmado';
      case 'despachado': return 'Despachado';
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
}