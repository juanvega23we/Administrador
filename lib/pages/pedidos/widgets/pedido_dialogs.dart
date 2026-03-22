// lib/pages/pedidos/widgets/pedido_dialogs.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../../models/item_con_stock.dart';
import '../../../../widgets/notificacion_personalizada.dart';

class PedidoDialogs {
  static Future<bool> confirmarCancelar(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: _DialogContainer(
          gradientColors: const [Color(0xFFE53935), Color(0xFFEF5350)],
          icon: Icons.cancel_rounded,
          titulo: 'Cancelar Pedido',
          mensaje: '¿Estás seguro de que deseas cancelar este pedido?\n\nEsta acción no se puede deshacer.',
          labelConfirmar: 'Sí, cancelar',
          colorConfirmar: const Color(0xFFE53935),
          labelCancelar: 'No, volver',
          onConfirmar: () => Navigator.pop(ctx, true),
          onCancelar: () => Navigator.pop(ctx, false),
        ),
      ),
    );
    return result ?? false;
  }

  static Future<bool> confirmarEntrega(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: _DialogContainer(
          gradientColors: const [Color(0xFF2E7D32), Color(0xFF43A047)],
          icon: Icons.done_all_rounded,
          titulo: 'Confirmar Entrega',
          mensaje: '¿Confirmas que este pedido fue entregado al cliente?\n\nSe registrará automáticamente como venta.',
          labelConfirmar: 'Sí, entregar',
          colorConfirmar: const Color(0xFF2E7D32),
          labelCancelar: 'Cancelar',
          onConfirmar: () => Navigator.pop(ctx, true),
          onCancelar: () => Navigator.pop(ctx, false),
        ),
      ),
    );
    return result ?? false;
  }

  static Future<bool> confirmarDespacho(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: _DialogContainer(
          gradientColors: const [Color(0xFF6A1B9A), Color(0xFFAB47BC)],
          icon: Icons.local_shipping_rounded,
          titulo: 'Despachar Pedido',
          mensaje: '¿Confirmas que este pedido fue despachado y está en camino al cliente?',
          labelConfirmar: 'Sí, despachar',
          colorConfirmar: const Color(0xFF6A1B9A),
          labelCancelar: 'Cancelar',
          onConfirmar: () => Navigator.pop(ctx, true),
          onCancelar: () => Navigator.pop(ctx, false),
        ),
      ),
    );
    return result ?? false;
  }

  static Future<bool?> confirmarParcial(
    BuildContext context, {
    required List<String> productosProblema,
    required int productosOkCount,
  }) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.2), blurRadius: 30, offset: const Offset(0, 10))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFFE65100), Color(0xFFFFA726)]),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.white, size: 48),
                    SizedBox(height: 8),
                    Text('Stock Insuficiente', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Los siguientes productos no tienen stock suficiente:', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red[100]!)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: productosProblema.map((n) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(children: [
                            const Icon(Icons.remove_circle, color: Colors.red, size: 14),
                            const SizedBox(width: 6),
                            Expanded(child: Text(n, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                          ]),
                        )).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green[100]!)),
                      child: Row(children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          '$productosOkCount producto${productosOkCount > 1 ? 's' : ''} sí ${productosOkCount > 1 ? 'tienen' : 'tiene'} stock disponible.',
                          style: TextStyle(fontSize: 13, color: Colors.green[800]),
                        )),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    Text('¿Deseas confirmar el pedido con los productos disponibles y omitir los que no tienen stock?', style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4)),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.grey[700], side: BorderSide(color: Colors.grey[300]!), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: const Text('Cancelar'),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                        child: const Text('Confirmar igual', style: TextStyle(fontWeight: FontWeight.bold)),
                      )),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // REGISTRAR DEVOLUCIÓN
  // ════════════════════════════════════════════════════════════
  static Future<void> registrarDevolucion(
    BuildContext context, {
    required String docId,
    required Map<String, dynamic> pedido,
    required List<Map<String, dynamic>> itemsPedido,
    required String nombreCliente,
    required String telefono,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DialogDevolucion(
        docId:         docId,
        pedido:        pedido,
        itemsPedido:   itemsPedido,
        nombreCliente: nombreCliente,
        telefono:      telefono,
      ),
    );
  }

  static void mostrarCargando(BuildContext context, {String mensaje = 'Cargando...'}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(color: Color(0xFF00897B)),
              const SizedBox(height: 16),
              Text(mensaje),
            ]),
          ),
        ),
      ),
    );
  }

  static Future<void> editarPedido(
    BuildContext context, {
    required String docId,
    required String idPedidoParaBusqueda,
    required Map<String, dynamic> pedido,
    required List<ItemConStock> itemsConStock,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditarPedidoSheet(
        docId: docId,
        idPedidoParaBusqueda: idPedidoParaBusqueda,
        pedido: pedido,
        itemsConStock: itemsConStock,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// SHEET DE EDICIÓN
// ════════════════════════════════════════════════════════════
class _EditarPedidoSheet extends StatefulWidget {
  final String docId;
  final String idPedidoParaBusqueda;
  final Map<String, dynamic> pedido;
  final List<ItemConStock> itemsConStock;

  const _EditarPedidoSheet({
    required this.docId,
    required this.idPedidoParaBusqueda,
    required this.pedido,
    required this.itemsConStock,
  });

  @override
  State<_EditarPedidoSheet> createState() => _EditarPedidoSheetState();
}

class _EditarPedidoSheetState extends State<_EditarPedidoSheet> {
  static const _teal = Color(0xFF00897B);
  static final _fmt  = NumberFormat('#,###', 'es_CO');

  // Productos editables (no omitidos, no yaEntregados)
  late List<Map<String, dynamic>> _items;
  final List<TextEditingController> _cantControllers = [];

  // Productos bloqueados (yaEntregado = true)
  late List<Map<String, dynamic>> _itemsYaEntregados;

  List<_ProdCatalogo> _catalogo = [];
  bool _cargandoCatalogo = false;
  bool _guardando = false;

  final _busquedaCtrl = TextEditingController();
  String _busqueda = '';

  @override
  void initState() {
    super.initState();

    // ── Productos YA ENTREGADOS → solo lectura ────────────────
    _itemsYaEntregados = widget.itemsConStock
        .where((i) => i.yaEntregado)
        .map((i) => <String, dynamic>{
              'idProducto':     i.idProducto,
              'nombre':         i.nombre,
              'cantidad':       i.cantidad,
              'precioUnitario': i.precioUnitario,
            })
        .toList();

    // ── Productos EDITABLES ─────────────────────────────────────
    _items = widget.itemsConStock
        .where((i) => !i.omitido && !i.yaEntregado && !i.devuelto)
        .map((i) => <String, dynamic>{
              'idProducto':        i.idProducto,
              'nombre':            i.nombre,
              'cantidad':          i.cantidad,
              'precioUnitario':    i.precioUnitario,
              'stockActual':       i.stockActual,
              'cantidadDevuelta':  i.cantidadDevuelta,
              'motivoDevolucion':  i.motivoDevolucion,
            })
        .toList();

    for (final item in _items) {
      _cantControllers.add(TextEditingController(text: '${item['cantidad']}'));
    }
    _cargarCatalogo();
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    for (final c in _cantControllers) c.dispose();
    super.dispose();
  }

  Future<void> _cargarCatalogo() async {
    if (!mounted) return;
    setState(() => _cargandoCatalogo = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('productos')
          .where('stock', isGreaterThan: 0)
          .get();

      // Excluir los que ya están en el pedido (editables) Y los ya entregados
      final idsEnPedido = {
        ..._items.map((i) => i['idProducto'].toString()),
        ..._itemsYaEntregados.map((i) => i['idProducto'].toString()),
      };

      if (!mounted) return;
      setState(() {
        _catalogo = snap.docs
            .where((d) => !idsEnPedido.contains(d.id))
            .map((d) {
              final data = d.data();
              return _ProdCatalogo(
                id:     d.id,
                nombre: (data['nombre'] ?? data['name'] ?? d.id).toString(),
                precio: ((data['precio'] ?? data['precioUnitario'] ?? 0) as num).toDouble(),
                stock:  (data['stock'] as num?)?.toInt() ?? 0,
              );
            })
            .toList()
          ..sort((a, b) => a.nombre.compareTo(b.nombre));
        _cargandoCatalogo = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargandoCatalogo = false);
    }
  }

  double get _totalCalculado {
    double total = 0;
    // Sumar editables
    for (int i = 0; i < _items.length; i++) {
      final precio = (_items[i]['precioUnitario'] as num).toDouble();
      final cant   = int.tryParse(_cantControllers[i].text) ?? (_items[i]['cantidad'] as num).toInt();
      total += precio * cant;
    }
    // Sumar ya entregados (precio fijo, no editable)
    for (final item in _itemsYaEntregados) {
      final precio = (item['precioUnitario'] as num).toDouble();
      final cant   = (item['cantidad'] as num).toInt();
      total += precio * cant;
    }
    return total;
  }

  String _fmtVal(double v) => '\$${_fmt.format(v.toInt())}';

  void _incrementar(int idx) {
    final nueva = (int.tryParse(_cantControllers[idx].text) ?? 1) + 1;
    setState(() {
      _items[idx]['cantidad'] = nueva;
      _cantControllers[idx].text = '$nueva';
    });
  }

  void _decrementar(int idx) {
    final actual = int.tryParse(_cantControllers[idx].text) ?? 1;
    if (actual <= 1) return;
    final nueva = actual - 1;
    setState(() {
      _items[idx]['cantidad'] = nueva;
      _cantControllers[idx].text = '$nueva';
    });
  }

  void _quitarItem(int idx) {
    setState(() {
      final removido = _items.removeAt(idx);
      _cantControllers[idx].dispose();
      _cantControllers.removeAt(idx);
      final yaEsta = _catalogo.any((c) => c.id == removido['idProducto'].toString());
      if (!yaEsta) {
        _catalogo.add(_ProdCatalogo(
          id:     removido['idProducto'].toString(),
          nombre: removido['nombre'].toString(),
          precio: (removido['precioUnitario'] as num).toDouble(),
          stock:  (removido['stockActual'] as num?)?.toInt() ?? 0,
        ));
        _catalogo.sort((a, b) => a.nombre.compareTo(b.nombre));
      }
    });
  }

  void _agregar(String id, String nombre, double precio, int stock) {
    final idx = _items.indexWhere((i) => i['idProducto'].toString() == id);
    setState(() {
      if (idx != -1) {
        // Ya existe → incrementar cantidad
        final nueva = (int.tryParse(_cantControllers[idx].text) ?? 1) + 1;
        _items[idx]['cantidad'] = nueva;
        _cantControllers[idx].text = '$nueva';
      } else {
        // Nuevo producto → agregar
        _items.add(<String, dynamic>{
          'idProducto':     id,
          'nombre':         nombre,
          'cantidad':       1,
          'precioUnitario': precio,
          'stockActual':    stock,
        });
        _cantControllers.add(TextEditingController(text: '1'));
        _catalogo.removeWhere((c) => c.id == id);
      }
    });
  }

  Future<void> _guardar() async {
    if (_items.isEmpty && _itemsYaEntregados.isEmpty) {
      NotificacionPersonalizada.mostrarSnack(
        context,
        mensaje: 'El pedido debe tener al menos un producto',
        tipo: TipoNotificacion.advertencia,
      );
      return;
    }

    for (int i = 0; i < _items.length; i++) {
      final v = int.tryParse(_cantControllers[i].text);
      if (v != null && v > 0) _items[i]['cantidad'] = v;
    }

    setState(() => _guardando = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      final snap  = await FirebaseFirestore.instance
          .collection('detalle_pedido')
          .where('idPedido', isEqualTo: widget.idPedidoParaBusqueda)
          .get();

      final idsActuales = {
        for (final d in snap.docs) (d.data()['idProducto'] ?? '').toString(): d.id
      };

      // IDs que deben conservarse: editables nuevos + ya entregados (intocables)
      final idsNuevos = {
        ..._items.map((i) => i['idProducto'].toString()),
        ..._itemsYaEntregados.map((i) => i['idProducto'].toString()),
      };

      final esReenvio = widget.pedido['esReenvio'] == true;

      // En reenvío: marcar quitados como canceladoDelReenvio en lugar de eliminar
      // En pedido normal: eliminar los que ya no están
      for (final entry in idsActuales.entries) {
        if (!idsNuevos.contains(entry.key)) {
          if (esReenvio) {
            batch.update(
              FirebaseFirestore.instance.collection('detalle_pedido').doc(entry.value),
              {
                'canceladoDelReenvio': true,
                'omitido': true,
                'motivoOmision': 'Cancelado del reenvío por admin',
              },
            );
          } else {
            batch.delete(
              FirebaseFirestore.instance.collection('detalle_pedido').doc(entry.value),
            );
          }
        }
      }

      for (final item in _items) {
        final idProducto = item['idProducto'].toString();
        final cantidad   = (item['cantidad'] as num).toInt();
        final precio     = (item['precioUnitario'] as num).toDouble();
        final nombre     = item['nombre'].toString();

        if (idsActuales.containsKey(idProducto)) {
          batch.update(
            FirebaseFirestore.instance.collection('detalle_pedido').doc(idsActuales[idProducto]),
            {'cantidad': cantidad, 'subtotal': cantidad * precio, 'actualizadoEn': FieldValue.serverTimestamp()},
          );
        } else {
          final ref = FirebaseFirestore.instance.collection('detalle_pedido').doc();
          batch.set(ref, {
            'idPedido':          widget.idPedidoParaBusqueda,
            'idProducto':        idProducto,
            'nombreProducto':    nombre,
            'cantidad':          cantidad,
            'precioUnitario':    precio,
            'subtotal':          cantidad * precio,
            'omitido':           false,
            'esProductoReenvio': esReenvio,
            'creadoEn':          FieldValue.serverTimestamp(),
          });
        }
      }

      batch.update(
        FirebaseFirestore.instance.collection('pedido').doc(widget.docId),
        {'total': _totalCalculado, 'editadoEn': FieldValue.serverTimestamp(), 'editadoPorAdmin': true},
      );

      await batch.commit();
      if (!mounted) return;

      Navigator.pop(context);

      NotificacionPersonalizada.mostrarSnack(
        context,
        mensaje: 'Pedido actualizado correctamente',
        tipo: TipoNotificacion.exito,
      );

    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);

      NotificacionPersonalizada.mostrarSnack(
        context,
        mensaje: 'Error al guardar el pedido',
        tipo: TipoNotificacion.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;

    final catalogoFiltrado = _busqueda.isEmpty
        ? _catalogo
        : _catalogo.where((p) => p.nombre.toLowerCase().contains(_busqueda.toLowerCase())).toList();

    return Container(
      height: h * 0.90,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // ── Cabecera ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF00695C), Color(0xFF00897B)]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.edit_outlined, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Editar Pedido', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(widget.pedido['numeroPedido']?.toString() ?? '', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar sin guardar',
                  onPressed: _guardando ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),

          // ── Productos del pedido ──────────────────────────────
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Productos en el pedido',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF00695C))),
                  const SizedBox(height: 10),

                  // ── Editables ──────────────────────────────────
                  if (_items.isEmpty && _itemsYaEntregados.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey[200]!)),
                      child: Center(child: Text('No hay productos. Agrega desde el catálogo.', style: TextStyle(color: Colors.grey[500], fontSize: 13))),
                    )
                  else ...[
                    for (int i = 0; i < _items.length; i++)
                      _ItemEditable(
                        key: ValueKey(_items[i]['idProducto']),
                        item: _items[i],
                        controller: _cantControllers[i],
                        onIncrementar: () => _incrementar(i),
                        onDecrementar: () => _decrementar(i),
                        onQuitar: () => _quitarItem(i),
                        onCantidadCambiada: (v) => setState(() => _items[i]['cantidad'] = v),
                        fmtVal: _fmtVal,
                      ),

                    // ── Ya entregados (solo lectura) ───────────
                    if (_itemsYaEntregados.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.lock_outline, size: 13, color: Colors.green),
                          const SizedBox(width: 6),
                          Text('Ya entregados — no editables',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green[700])),
                        ],
                      ),
                      const SizedBox(height: 6),
                      for (final item in _itemsYaEntregados)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['nombre'].toString(),
                                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.green[800])),
                                    Text('${item['cantidad']}x  •  ${_fmtVal((item['precioUnitario'] as num).toDouble())} c/u',
                                        style: TextStyle(fontSize: 11, color: Colors.green[600])),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(6)),
                                child: Text('Ya entregado',
                                    style: TextStyle(fontSize: 11, color: Colors.green[800], fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ],
              ),
            ),
          ),

          const Divider(height: 1),

          // ── Buscador ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Agregar productos',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF00695C))),
                const SizedBox(height: 8),
                TextField(
                  controller: _busquedaCtrl,
                  onChanged: (v) => setState(() => _busqueda = v),
                  decoration: InputDecoration(
                    hintText: 'Buscar en catálogo...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _busqueda.isNotEmpty
                        ? IconButton(tooltip: 'Limpiar búsqueda', icon: const Icon(Icons.close, size: 18), onPressed: () { _busquedaCtrl.clear(); setState(() => _busqueda = ''); })
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _teal)),
                  ),
                ),
              ],
            ),
          ),

          // ── Lista catálogo ────────────────────────────────────
          Expanded(
            flex: 3,
            child: _cargandoCatalogo
                ? const Center(child: CircularProgressIndicator(color: _teal))
                : Column(
                    children: [
                      // Aviso cuando está en modo reemplazo
                      Expanded(
                        child: catalogoFiltrado.isEmpty
                            ? Center(child: Text(
                                _busqueda.isNotEmpty
                                    ? 'Sin resultados para "$_busqueda"'
                                    : 'No hay más productos',
                                style: TextStyle(color: Colors.grey[500], fontSize: 13),
                              ))
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                itemCount: catalogoFiltrado.length,
                                separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200]),
                                itemBuilder: (_, idx) {
                                  final prod = catalogoFiltrado[idx];
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(prod.nombre,
                                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                              Text('${_fmtVal(prod.precio)} • ${prod.stock} en stock',
                                                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                            ],
                                          ),
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => _agregar(prod.id, prod.nombre, prod.precio, prod.stock),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _teal,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          elevation: 0,
                                        ),
                                        child: const Text('+ Agregar', style: TextStyle(fontSize: 13)),
                                      ),
                                    ],
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
          ),

          const Divider(height: 1),

          // ── Footer ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            color: Colors.grey[50],
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total del pedido', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      Text(_fmtVal(_totalCalculado),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF00695C))),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: _guardando ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey[300]!),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _guardando ? null : _guardar,
                  icon: _guardando
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text(_guardando ? 'Guardando...' : 'Guardar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Modelo tipado para catálogo ───────────────────────────────
class _ProdCatalogo {
  final String id;
  final String nombre;
  final double precio;
  final int    stock;
  const _ProdCatalogo({required this.id, required this.nombre, required this.precio, required this.stock});
}

// ── Fila editable de producto ─────────────────────────────────
class _ItemEditable extends StatelessWidget {
  final Map<String, dynamic> item;
  final TextEditingController controller;
  final VoidCallback onIncrementar;
  final VoidCallback onDecrementar;
  final VoidCallback onQuitar;
  final ValueChanged<int> onCantidadCambiada;
  final String Function(double) fmtVal;

  const _ItemEditable({
    super.key,
    required this.item,
    required this.controller,
    required this.onIncrementar,
    required this.onDecrementar,
    required this.onQuitar,
    required this.onCantidadCambiada,
    required this.fmtVal,
  });

  static const _teal = Color(0xFF00897B);

  @override
  Widget build(BuildContext context) {
    final stock  = (item['stockActual'] as num?)?.toInt() ?? 0;
    final cant   = int.tryParse(controller.text) ?? (item['cantidad'] as num).toInt();
    final sufic  = stock >= cant;
    final precio = (item['precioUnitario'] as num).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: sufic ? Colors.green[200]! : Colors.red[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['nombre'].toString(),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                Text(fmtVal(precio),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 4),
                _StockBadgeSmall(stock: stock, cantidad: cant),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _CircleBtn(
              icon: Icons.remove,
              tooltip: 'Disminuir',
              color: cant <= 1 ? Colors.grey[200]! : Colors.red[100]!,
              iconColor: cant <= 1 ? Colors.grey[400]! : Colors.red,
              onTap: cant <= 1 ? null : onDecrementar),
          SizedBox(
            width: 48,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3)
              ],
              decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: _teal, width: 2))),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              onChanged: (v) {
                final n = int.tryParse(v);
                if (n != null && n > 0) onCantidadCambiada(n);
              },
            ),
          ),
          _CircleBtn(
              icon: Icons.add,
              tooltip: 'Aumentar',
              color: Colors.teal[50]!,
              iconColor: _teal,
              onTap: onIncrementar),
          const SizedBox(width: 4),
          IconButton(
              tooltip: 'Eliminar producto',
              onPressed: onQuitar,
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
              visualDensity: VisualDensity.compact),
        ],
      ),
    );
  }
}

class _StockBadgeSmall extends StatelessWidget {
  final int stock;
  final int cantidad;
  const _StockBadgeSmall({required this.stock, required this.cantidad});

  @override
  Widget build(BuildContext context) {
    final ok    = stock >= cantidad;
    final color = ok ? Colors.green : Colors.red;
    final bg    = ok ? Colors.green[50]! : Colors.red[50]!;
    final text  = ok ? '✓ Stock suficiente ($stock disp.)' : stock == 0 ? '✗ Sin stock' : '✗ Insuficiente (solo $stock, necesita $cantidad)';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(fontSize: 10, color: color[700], fontWeight: FontWeight.w600)),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback? onTap;
  final String? tooltip;

  const _CircleBtn({required this.icon, required this.color, required this.iconColor, required this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    Widget child = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(width: 30, height: 30, decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: Icon(icon, size: 16, color: iconColor)),
    );
    if (tooltip != null) {
      child = Tooltip(message: tooltip!, child: child);
    }
    return child;
  }
}

// ════════════════════════════════════════════════════════════
// DIALOG DEVOLUCIÓN
// ════════════════════════════════════════════════════════════
class _DialogDevolucion extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> pedido;
  final List<Map<String, dynamic>> itemsPedido;
  final String nombreCliente;
  final String telefono;

  const _DialogDevolucion({
    required this.docId,
    required this.pedido,
    required this.itemsPedido,
    required this.nombreCliente,
    required this.telefono,
  });

  @override
  State<_DialogDevolucion> createState() => _DialogDevolucionState();
}

class _DialogDevolucionState extends State<_DialogDevolucion> {
  static const _orange = Color(0xFFE65100);
  static const _teal   = Color(0xFF00897B);

  String _resolucion = 'reenvio';
  bool   _guardando  = false;
  final  _notasCtrl  = TextEditingController();

  final Map<String, int>    _cantidades   = {};
  final Map<String, bool>   _reponerStock = {};
  final Map<String, String> _motivos      = {};

  static final _fmt = NumberFormat('#,###', 'es_CO');
  String _fmtVal(double v) => '\$${_fmt.format(v.toInt())}';

  @override
  void initState() {
    super.initState();
    for (final item in widget.itemsPedido) {
      final id = (item['idProducto'] ?? item['id'])?.toString() ?? '';
      if (id.isNotEmpty) {
        _cantidades[id]   = 0;
        _reponerStock[id] = false;
        _motivos[id]      = 'defectuoso';
      }
    }
  }

  @override
  void dispose() {
    _notasCtrl.dispose();
    super.dispose();
  }

  bool get _hayProductosSeleccionados =>
      _cantidades.values.any((c) => c > 0);

  /// Verifica si se están devolviendo TODOS los productos disponibles con TODA su cantidad
  bool get _esCancelacionTotal {
    for (final item in widget.itemsPedido) {
      // Ignorar productos ya bloqueados (devueltos u omitidos)
      if (item['devuelto'] == true) continue;
      if (item['omitido']  == true) continue;
      final id      = (item['idProducto'] ?? item['id'])?.toString() ?? '';
      final cantMax = (item['cantidad'] as num?)?.toInt() ?? 0;
      final cantDev = _cantidades[id] ?? 0;
      if (cantDev < cantMax) return false;
    }
    return _hayProductosSeleccionados;
  }

  Future<void> _guardar() async {
    if (!_hayProductosSeleccionados) {
      NotificacionPersonalizada.mostrarSnack(
        context,
        mensaje: 'Selecciona al menos un producto a devolver',
        tipo: TipoNotificacion.advertencia,
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      final productosDevueltos = <Map<String, dynamic>>[];
      double montoDevolucion   = 0;

      for (final item in widget.itemsPedido) {
        final id       = (item['idProducto'] ?? item['id'])?.toString() ?? '';
        final cantidad = _cantidades[id] ?? 0;
        if (cantidad <= 0) continue;
        final precio  = (item['precioUnitario'] ?? item['precio'] as num? ?? 0).toDouble();
        final motivo  = _motivos[id] ?? 'defectuoso';
        final reponer = _reponerStock[id] ?? false;
        // La cantidad a reponer la decide el admin manualmente en el campo de cantidad
        final cantStock = reponer ? cantidad : 0;
        productosDevueltos.add({
          'idProducto':    id,
          'nombre':        (item['nombreProducto'] ?? item['nombre'] ?? '').toString(),
          'cantidad':      cantidad,
          'precio':        precio,
          'motivo':        motivo,
          'reponerStock':  reponer,
          'cantidadStock': cantStock,
        });
        montoDevolucion += cantidad * precio;
      }

      // ── Motivo predominante ──────────────────────────────────
      final motivoPredominante = productosDevueltos.isNotEmpty
          ? productosDevueltos.first['motivo']?.toString() ?? ''
          : '';

      // ── Para reembolso: cancelar solo si es devolución total ─
      final cancelarPedido =
          _resolucion == 'reembolso' && _esCancelacionTotal;

      final db        = FirebaseFirestore.instance;
      final devRef    = db.collection('devolucion').doc();
      final numeroPed = widget.pedido['numeroPedido']?.toString() ?? widget.docId;
      final ahora     = FieldValue.serverTimestamp();

      final batch = db.batch();

      batch.set(devRef, {
        'idDevolucion':       devRef.id,
        'idPedido':           widget.docId,
        'numeroPedido':       numeroPed,
        'nombreCliente':      widget.nombreCliente,
        'telefonoCliente':    widget.telefono,
        'resolucion':         _resolucion,
        'estado':             'registrada',
        'notasAdmin':         _notasCtrl.text.trim(),
        'productosDevueltos': productosDevueltos,
        'montoDevolucion':    montoDevolucion,
        'fechaSolicitud':     ahora,
        'registradoPor':      'admin',
        'cancelacionTotal':   cancelarPedido,
      });

      final Map<String, dynamic> updatesPedido = {
        'tieneDevolucion':        true,
        'esReenvio':              _resolucion == 'reenvio',
        'ultimaDevolucionRes':    _resolucion,
        'ultimaDevolucionMotivo': motivoPredominante,
        'fechaUltimaDevolucion':  ahora,
      };

      if (_resolucion == 'reenvio') {
        // Reenvío → vuelve a pendiente
        // Conservar el total de la primera entrega y acumular el reenvío
        final totalPrimeraEntrega =
            (widget.pedido['totalPrimeraEntrega'] as num?)?.toDouble() ??
            (widget.pedido['total']               as num?)?.toDouble() ??
            0.0;
        updatesPedido['estado']               = 'pendiente';
        updatesPedido['estadoAnterior']       = widget.pedido['estado'] ?? 'entregado';
        updatesPedido['totalPrimeraEntrega']  = totalPrimeraEntrega;
        updatesPedido['totalReenvio']         = montoDevolucion;
        // total acumulado = primera entrega + reenvío pendiente
        updatesPedido['total']                = totalPrimeraEntrega + montoDevolucion;
      } else if (cancelarPedido) {
        // Reembolso total → cancelar
        updatesPedido['estado']         = 'cancelado';
        updatesPedido['estadoAnterior'] = widget.pedido['estado'] ?? 'entregado';
      }
      // Reembolso parcial → no cambia el estado (se queda en entregado)

      batch.update(db.collection('pedido').doc(widget.docId), updatesPedido);
      await batch.commit();

      // ── Actualizar detalle_pedido por producto ───────────────
      for (final item in widget.itemsPedido) {
        final idProd = (item['idProducto'] ?? item['id'])?.toString() ?? '';
        if (idProd.isEmpty) continue;

        final prodDevuelto = productosDevueltos.firstWhere(
          (p) => p['idProducto'] == idProd,
          orElse: () => {},
        );

        final snap = await db.collection('detalle_pedido')
            .where('idPedido', isEqualTo: widget.docId)
            .where('idProducto', isEqualTo: idProd).get();

        if (prodDevuelto.isEmpty) {
          // Producto NO devuelto
          for (final doc in snap.docs) {
            if (_resolucion == 'reenvio') {
              // En reenvío: omitir los que no se devolvieron (ya fueron entregados)
              await doc.reference.update({
                'yaEntregado': true,
                'omitido':     true,
              });
            } else {
              // En reembolso: marcar yaEntregado
              await doc.reference.update({'yaEntregado': true});
            }
          }
          continue;
        }

        final cantDev   = (prodDevuelto['cantidad'] as num?)?.toInt() ?? 0;
        final motivo    = prodDevuelto['motivo']?.toString() ?? '';
        final reponer   = prodDevuelto['reponerStock'] == true;
        final cantStock = (prodDevuelto['cantidadStock'] as num?)?.toInt() ?? 0;

        for (final doc in snap.docs) {
          final cantActual = (doc.data()['cantidad'] as num?)?.toInt() ?? 0;
          // Cantidad original = lo que había antes de la devolución
          // Si ya tiene cantidadOriginal guardada, la respetamos
          final cantOriginalGuardada = (doc.data()['cantidadOriginal'] as num?)?.toInt();
          final cantOriginal = cantOriginalGuardada ?? cantActual;

          if (_resolucion == 'reenvio') {
            await doc.reference.update({
              'cantidad':          cantDev,
              'cantidadDevuelta':  cantDev,
              'cantidadOriginal':  cantOriginal,
              'subtotal':          cantDev * ((doc.data()['precioUnitario'] as num?)?.toDouble() ?? 0),
              'omitido':           false,
              'yaEntregado':       false,
              'devuelto':          false,
              'motivoDevolucion':  motivo,
              'stockRepuesto':     reponer,
            });
          } else {
            // Reembolso
            final nuevaCant = cantActual - cantDev;
            if (nuevaCant <= 0) {
              await doc.reference.update({
                'cantidad':         0,
                'devuelto':         true,
                'motivoDevolucion': motivo,
                'omitido':          false,
                'yaEntregado':      false,
                'stockRepuesto':    reponer,
              });
            } else {
              await doc.reference.update({
                'cantidad':         nuevaCant,
                'cantidadDevuelta': cantDev,
                'stockRepuesto':    reponer,
                'subtotal': nuevaCant * ((doc.data()['precioUnitario'] as num?)?.toDouble() ?? 0),
              });
            }
          }
        }

        if (reponer && cantStock > 0) {
          await db.collection('productos').doc(idProd).update({
            'stock': FieldValue.increment(cantStock),
          });
        }
      }

      // ── Recalcular total real del pedido ─────────────────────
      // Solo para reembolso parcial (el pedido sigue entregado)
      if (_resolucion == 'reembolso' && !cancelarPedido) {
        final detalleSnap = await db.collection('detalle_pedido')
            .where('idPedido', isEqualTo: widget.docId)
            .get();
        double nuevoTotal = 0;
        for (final doc in detalleSnap.docs) {
          final data = doc.data();
          if (data['devuelto'] == true) continue;
          if (data['omitido']  == true) continue;
          final cant   = (data['cantidad']       as num?)?.toDouble() ?? 0;
          final precio = (data['precioUnitario'] as num?)?.toDouble() ?? 0;
          nuevoTotal += cant * precio;
        }
        await db.collection('pedido').doc(widget.docId).update({
          'total': nuevoTotal,
        });
      }

      if (mounted) {
        Navigator.pop(context);
        if (_resolucion == 'reenvio') {
          NotificacionPersonalizada.mostrarSnack(
            context,
            mensaje: 'Devolución registrada — pedido vuelto a Pendiente para reenvío',
            tipo: TipoNotificacion.exito,
          );
        } else if (cancelarPedido) {
          NotificacionPersonalizada.mostrarSnack(
            context,
            mensaje: 'Reembolso total registrado — pedido cancelado',
            tipo: TipoNotificacion.error,
          );
        } else {
          NotificacionPersonalizada.mostrarSnack(
            context,
            mensaje: 'Reembolso parcial registrado — el pedido sigue entregado',
            tipo: TipoNotificacion.advertencia,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        NotificacionPersonalizada.mostrarSnack(
          context,
          mensaje: 'Error al registrar la devolución',
          tipo: TipoNotificacion.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [_orange, Color(0xFFFF8F00)]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(children: [
                const Icon(Icons.assignment_return, color: Colors.white, size: 26),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Registrar devolución',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                    Text(widget.pedido['numeroPedido']?.toString() ?? '',
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                )),
                IconButton(
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),

            // Contenido
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Info cliente
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Row(children: [
                        Icon(Icons.person, size: 16, color: Colors.orange[700]),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          '${widget.nombreCliente}  •  ${widget.telefono}',
                          style: TextStyle(fontSize: 13, color: Colors.orange[900], fontWeight: FontWeight.w500),
                        )),
                      ]),
                    ),
                    const SizedBox(height: 18),

                    const Text('Productos a devolver',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('Selecciona cantidad, motivo y si deseas devolver stock',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    const SizedBox(height: 10),

                    ...widget.itemsPedido.map((item) {
                      final id       = (item['idProducto'] ?? item['id'])?.toString() ?? '';
                      final nombre   = (item['nombreProducto'] ?? item['nombre'] ?? 'Producto').toString();
                      final cantMax  = (item['cantidad'] as num?)?.toInt() ?? 1;
                      final precio   = (item['precioUnitario'] ?? item['precio'] as num? ?? 0).toDouble();
                      final cant     = _cantidades[id] ?? 0;
                      final motivo   = _motivos[id] ?? 'defectuoso';
                      final activo   = cant > 0;
                      final reponer  = _reponerStock[id] ?? false;

                      // ── Productos bloqueados: devueltos u omitidos ──────
                      final estaDevuelto     = item['devuelto'] == true;
                      final estaOmitido      = item['omitido']  == true;
                      final motivoOmision    = item['motivoOmision']?.toString() ?? '';
                      final fueQuitadoManual = estaOmitido && motivoOmision != 'Sin stock al confirmar';
                      final bloqueado        = estaDevuelto || estaOmitido;

                      if (bloqueado) {
                        // Si fue quitado manualmente del reenvío, no bloquearlo
                        // sino mostrarlo como disponible para devolver
                        if (fueQuitadoManual) {
                          // No bloquearlo, dejarlo caer al flujo normal abajo
                        } else {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Row(children: [
                            Icon(
                              estaDevuelto ? Icons.assignment_return : Icons.block,
                              size: 16,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nombre,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[400],
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                Text(
                                  '${_fmtVal(precio)} c/u',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[400],
                                      decoration: TextDecoration.lineThrough),
                                ),
                              ],
                            )),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                estaDevuelto ? 'Ya devuelto' : 'Sin stock',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ]),
                        );
                        } // cierre else fueQuitadoManual
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: activo ? Colors.orange[50] : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: activo ? Colors.orange[300]! : Colors.grey[200]!,
                            width: activo ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                              child: Row(children: [
                                Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(nombre, style: TextStyle(
                                        fontWeight: FontWeight.w600, fontSize: 13,
                                        color: activo ? Colors.orange[900] : Colors.black87)),
                                    Text('${_fmtVal(precio)} c/u',
                                        style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                  ],
                                )),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    InkWell(
                                      onTap: cant > 0 ? () => setState(() {
                                        _cantidades[id] = cant - 1;
                                        if (cant - 1 == 0) _reponerStock[id] = false;
                                      }) : null,
                                      child: Padding(padding: const EdgeInsets.all(7),
                                          child: Icon(Icons.remove, size: 16,
                                              color: cant > 0 ? Colors.red : Colors.grey[300])),
                                    ),
                                    SizedBox(
                                      width: 48,
                                      child: TextField(
                                        controller: TextEditingController(text: '$cant')
                                          ..selection = TextSelection.collapsed(offset: '$cant'.length),
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: activo ? _orange : Colors.black87),
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(vertical: 4),
                                        ),
                                        onChanged: (v) {
                                          final n = int.tryParse(v) ?? 0;
                                          final clamped = n.clamp(0, cantMax);
                                          setState(() {
                                            _cantidades[id] = clamped;
                                            if (clamped == 0) _reponerStock[id] = false;
                                          });
                                        },
                                      ),
                                    ),
                                    InkWell(
                                      onTap: cant < cantMax ? () => setState(() {
                                        _cantidades[id] = cant + 1;
                                      }) : null,
                                      child: Padding(padding: const EdgeInsets.all(7),
                                          child: Icon(Icons.add, size: 16,
                                              color: cant < cantMax ? _teal : Colors.grey[300])),
                                    ),
                                  ]),
                                ),
                                const SizedBox(width: 6),
                                Text('/ $cantMax', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                              ]),
                            ),

                            const Divider(height: 1, indent: 12, endIndent: 12),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DropdownButtonFormField<String>(
                                    value: motivo,
                                    isDense: true,
                                    decoration: InputDecoration(
                                      labelText: 'Motivo',
                                      labelStyle: const TextStyle(fontSize: 12),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'defectuoso',
                                          child: Text('Producto defectuoso', style: TextStyle(fontSize: 13))),
                                      DropdownMenuItem(value: 'equivocado',
                                          child: Text('Producto equivocado', style: TextStyle(fontSize: 13))),
                                      DropdownMenuItem(value: 'cantidad_incorrecta',
                                          child: Text('Cantidad incorrecta', style: TextStyle(fontSize: 13))),
                                      DropdownMenuItem(value: 'insatisfecho',
                                          child: Text('Cliente insatisfecho', style: TextStyle(fontSize: 13))),
                                      DropdownMenuItem(value: 'otro',
                                          child: Text('Otro', style: TextStyle(fontSize: 13))),
                                    ],
                                    onChanged: (v) => setState(() => _motivos[id] = v ?? 'defectuoso'),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    SizedBox(width: 24, height: 24,
                                      child: Checkbox(
                                        value: reponer,
                                        activeColor: _teal,
                                        onChanged: (v) => setState(() {
                                          _reponerStock[id] = v ?? false;
                                          // Sin auto-completar cantidad
                                        }),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('Devolver al inventario',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                  ]),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 16),

                    const Text('Resolución', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _resolucion,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'reenvio',   child: Text('Reenvío del producto')),
                        DropdownMenuItem(value: 'reembolso', child: Text('Reembolso al cliente')),
                      ],
                      onChanged: (v) => setState(() => _resolucion = v ?? 'reenvio'),
                    ),
                    const SizedBox(height: 8),

                    if (_resolucion == 'reenvio')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(children: [
                          Icon(Icons.info_outline, size: 14, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Expanded(child: Text(
                            'El pedido volverá a Pendiente para iniciar el proceso de reenvío',
                            style: TextStyle(fontSize: 11, color: Colors.blue[800]),
                          )),
                        ]),
                      ),

                    if (_resolucion == 'reembolso') ...[
                      // ── Aviso dinámico: parcial o total ─────────
                      if (_hayProductosSeleccionados && _esCancelacionTotal)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Row(children: [
                            Icon(Icons.cancel_outlined, size: 14, color: Colors.red[700]),
                            const SizedBox(width: 8),
                            Expanded(child: Text(
                              'Devolución total — el pedido pasará a Cancelado. Recuerda hacer el reembolso al cliente manualmente.',
                              style: TextStyle(fontSize: 11, color: Colors.red[800]),
                            )),
                          ]),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange[200]!),
                          ),
                          child: Row(children: [
                            Icon(Icons.info_outline, size: 14, color: Colors.orange[700]),
                            const SizedBox(width: 8),
                            Expanded(child: Text(
                              'Reembolso parcial — el pedido seguirá en estado Entregado. Recuerda hacer el reembolso al cliente manualmente.',
                              style: TextStyle(fontSize: 11, color: Colors.orange[800]),
                            )),
                          ]),
                        ),
                    ],

                    const SizedBox(height: 14),

                    TextField(
                      controller: _notasCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Notas adicionales (opcional)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Botón guardar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _guardando ? null : _guardar,
                  icon: _guardando
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save),
                  label: Text(_guardando ? 'Guardando...' : 'Registrar devolución'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _orange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogContainer extends StatelessWidget {
  final List<Color> gradientColors;
  final IconData icon;
  final String titulo;
  final String mensaje;
  final String labelConfirmar;
  final String labelCancelar;
  final Color colorConfirmar;
  final VoidCallback onConfirmar;
  final VoidCallback onCancelar;

  const _DialogContainer({
    required this.gradientColors, required this.icon, required this.titulo, required this.mensaje,
    required this.labelConfirmar, required this.labelCancelar, required this.colorConfirmar,
    required this.onConfirmar, required this.onCancelar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: gradientColors[0].withOpacity(0.2), blurRadius: 30, offset: const Offset(0, 10))]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(gradient: LinearGradient(colors: gradientColors), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(children: [
              Icon(icon, color: Colors.white, size: 48),
              const SizedBox(height: 8),
              Text(titulo, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(mensaje, style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.5), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: onCancelar,
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.grey[700], side: BorderSide(color: Colors.grey[300]!), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text(labelCancelar),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(
                    onPressed: onConfirmar,
                    style: ElevatedButton.styleFrom(backgroundColor: colorConfirmar, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                    child: Text(labelConfirmar, style: const TextStyle(fontWeight: FontWeight.bold)),
                  )),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}