// lib/pages/pedidos/widgets/pedido_card.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../../widgets/notificacion_personalizada.dart';
import '../../../../models/item_con_stock.dart';
import 'pedido_dialogs.dart';

class PedidoCard extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> pedido;
  final Future<void> Function(String nuevoEstado) onEstadoChanged;

  const PedidoCard({
    super.key,
    required this.docId,
    required this.pedido,
    required this.onEstadoChanged,
  });

  @override
  State<PedidoCard> createState() => _PedidoCardState();
}

class _PedidoCardState extends State<PedidoCard> {
  static final _formatoCOP = NumberFormat('#,###', 'es_CO');

  // Cache del future para no recargar en cada rebuild
  Future<List<ItemConStock>>? _itemsFuture;
  String? _lastDocId; // detectar si cambió el pedido

  String _formatearTotal(double valor) =>
      '\$${_formatoCOP.format(valor.toInt())}';

  // Recarga el future cuando el pedido cambia de estado
  void _recargarItems() {
    setState(() {
      _itemsFuture = _cargarItemsConStock();
    });
  }

  @override
  void initState() {
    super.initState();
    _lastDocId   = widget.docId;
    _itemsFuture = _cargarItemsConStock();
  }

  @override
  void didUpdateWidget(PedidoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recargar si cambió el estado del pedido
    if (oldWidget.pedido['estado'] != widget.pedido['estado'] ||
        oldWidget.docId != widget.docId) {
      _itemsFuture = _cargarItemsConStock();
    }
  }

  String get _numeroPedidoLegible {
    final num = widget.pedido['numeroPedido']?.toString() ?? '';
    if (num.isNotEmpty && num.startsWith('PED-')) return num;
    final id = widget.pedido['idPedido']?.toString() ?? '';
    if (id.isNotEmpty && id.startsWith('PED-')) return id;
    if (num.isNotEmpty) return num;
    if (id.isNotEmpty) return id;
    final ts = widget.pedido['fechaPedido'] ?? widget.pedido['creadoEn'];
    if (ts is Timestamp) {
      final f = ts.toDate();
      return 'PED-${f.year}${f.month.toString().padLeft(2, '0')}'
          '${f.day.toString().padLeft(2, '0')}-'
          '${f.hour.toString().padLeft(2, '0')}'
          '${f.minute.toString().padLeft(2, '0')}';
    }
    return 'PED-${widget.docId.substring(0, widget.docId.length.clamp(0, 8))}';
  }

  String get _idPedidoParaBusqueda {
    if (widget.docId.isNotEmpty) return widget.docId;
    final idPedido = widget.pedido['idPedido']?.toString() ?? '';
    if (idPedido.isNotEmpty) return idPedido;
    return widget.pedido['numeroPedido']?.toString() ?? '';
  }

  // Acceso conveniente a widget properties
  String get docId => widget.docId;
  Map<String, dynamic> get pedido => widget.pedido;

  Future<void> _cambiarEstado(String nuevoEstado) async {
    await widget.onEstadoChanged(nuevoEstado);
    _recargarItems();
  }

  String get _nombreCliente {
    if (pedido['nombreCliente'] != null)
      return pedido['nombreCliente'].toString();
    final c = pedido['cliente'];
    if (c is Map) return c['nombre']?.toString() ?? 'N/A';
    return 'N/A';
  }

  String get _telefono {
    if (pedido['telefonoContacto'] != null)
      return pedido['telefonoContacto'].toString();
    final c = pedido['cliente'];
    if (c is Map) return c['telefono']?.toString() ?? 'N/A';
    return 'N/A';
  }

  String get _direccion {
    if (pedido['direccionEntrega'] != null)
      return pedido['direccionEntrega'].toString();
    final d = pedido['direccion'];
    if (d is Map) return '${d['calle'] ?? ''}, ${d['ciudad'] ?? ''}';
    return 'N/A';
  }

  Future<List<ItemConStock>> _cargarItemsConStock() async {
    final items = await _cargarProductos();
    if (items.isEmpty) return [];

    // ── Cargar todos los stocks en paralelo en lugar de secuencial ──
    final futures = items.map((item) async {
      final idProd = (item['idProducto'] ?? item['id'])?.toString() ?? '';
      int stockActual = 0;
      if (idProd.isNotEmpty) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('productos')
              .doc(idProd)
              .get();
          if (doc.exists) {
            stockActual = (doc.data()?['stock'] as num?)?.toInt() ?? 0;
          }
        } catch (_) {}
      }
      return ItemConStock(item: item, stockActual: stockActual);
    });

    return Future.wait(futures);
  }

  Future<List<Map<String, dynamic>>> _cargarProductos() async {
    // idPedido en detalle_pedido siempre es el docId del pedido
    final detallesSnap = await FirebaseFirestore.instance
        .collection('detalle_pedido')
        .where('idPedido', isEqualTo: docId)
        .get();

    if (detallesSnap.docs.isNotEmpty) {
      return detallesSnap.docs.map((d) => d.data()).toList();
    }

    // Fallback: buscar por numeroPedido por si datos viejos lo usan así
    final numeroPedido = pedido['numeroPedido']?.toString() ?? '';
    if (numeroPedido.isNotEmpty) {
      final byNum = await FirebaseFirestore.instance
          .collection('detalle_pedido')
          .where('idPedido', isEqualTo: numeroPedido)
          .get();
      if (byNum.docs.isNotEmpty) {
        return byNum.docs.map((d) => d.data()).toList();
      }
    }

    // Último fallback: array items en el documento del pedido
    final itemsArray = pedido['items'] as List<dynamic>? ?? [];
    return itemsArray.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> _confirmarConValidacion(BuildContext context) async {
    PedidoDialogs.mostrarCargando(context,
        mensaje: 'Verificando stock disponible...');

    final productos = await _cargarProductos();

    if (context.mounted) Navigator.pop(context);

    if (productos.isEmpty) {
      _cambiarEstado('confirmado');
      return;
    }

    final Map<String, int>    cantidadPorProducto = {};
    final Map<String, String> nombrePorProducto   = {};
    final Map<String, double> precioPorProducto   = {};

    for (final item in productos) {
      final idProducto = (item['idProducto'] ?? item['id'])?.toString();
      if (idProducto == null || idProducto.isEmpty) continue;
      if (item['yaEntregado'] == true) continue;
      if (item['devuelto'] == true) continue;
      final cantidad = (item['cantidad'] as num?)?.toInt() ?? 0;
      if (cantidad <= 0) continue;
      final precio =
          (item['precioUnitario'] ?? item['precio'] as num? ?? 0).toDouble();
      final nombre =
          (item['nombreProducto'] ?? item['nombre'] ?? idProducto).toString();
      cantidadPorProducto[idProducto] =
          (cantidadPorProducto[idProducto] ?? 0) + cantidad;
      nombrePorProducto[idProducto] = nombre;
      precioPorProducto[idProducto] = precio;
    }

    final List<String> sinStock          = [];
    final List<String> stockInsuficiente = [];
    final List<String> idsOk             = [];
    final List<String> idsSinStock       = [];

    for (final entry in cantidadPorProducto.entries) {
      final idProducto = entry.key;
      final cantidad   = entry.value;
      final nombre     = nombrePorProducto[idProducto] ?? idProducto;

      final productoDoc = await FirebaseFirestore.instance
          .collection('productos')
          .doc(idProducto)
          .get();

      if (!productoDoc.exists) continue;

      final stockActual =
          (productoDoc.data()?['stock'] as num?)?.toInt() ?? 0;

      if (stockActual == 0) {
        sinStock.add(nombre);
        idsSinStock.add(idProducto);
      } else if (stockActual < cantidad) {
        stockInsuficiente.add(nombre);
        idsSinStock.add(idProducto);
      } else {
        idsOk.add(idProducto);
      }
    }

    if (!context.mounted) return;

    if (sinStock.isEmpty && stockInsuficiente.isEmpty) {
      _cambiarEstado('confirmado');
      return;
    }

    if (idsOk.isNotEmpty) {
      final productosProblema = [...sinStock, ...stockInsuficiente];
      final continuar = await PedidoDialogs.confirmarParcial(
        context,
        productosProblema: productosProblema,
        productosOkCount: idsOk.length,
      );

      if (continuar == true && context.mounted) {
        await _aplicarConfirmacionParcial(
          idsSinStock: idsSinStock,
          precioPorProducto: precioPorProducto,
          cantidadPorProducto: cantidadPorProducto,
        );
        _cambiarEstado('confirmado');
      }
      return;
    }

    final detalle = [
      ...sinStock.map((n) => '• $n'),
      ...stockInsuficiente.map((n) => '• $n'),
    ].join('\n');

    NotificacionPersonalizada.mostrar(
      context,
      titulo: sinStock.isNotEmpty ? '¡Stock Agotado!' : '¡Stock Insuficiente!',
      mensaje: sinStock.isNotEmpty
          ? 'No se puede confirmar este pedido.\nLos siguientes productos no tienen stock:\n\n$detalle\n\nRecarga el inventario para continuar.'
          : 'No hay suficiente stock para confirmar este pedido:\n\n$detalle\n\nRecarga el inventario para continuar.',
      tipo: TipoNotificacion.stockAgotado,
    );
  }

  Future<void> _aplicarConfirmacionParcial({
    required List<String> idsSinStock,
    required Map<String, double> precioPorProducto,
    required Map<String, int> cantidadPorProducto,
  }) async {
    double descuento = 0;
    for (final id in idsSinStock) {
      final precio   = precioPorProducto[id] ?? 0;
      final cantidad = cantidadPorProducto[id] ?? 0;
      descuento += precio * cantidad;
    }

    final detallesSnap = await FirebaseFirestore.instance
        .collection('detalle_pedido')
        .where('idPedido', isEqualTo: _idPedidoParaBusqueda)
        .get();

    final batch = FirebaseFirestore.instance.batch();

    for (final doc in detallesSnap.docs) {
      final data       = doc.data();
      final idProducto = (data['idProducto'] ?? '').toString();
      if (idsSinStock.contains(idProducto)) {
        batch.update(doc.reference, {
          'omitido': true,
          'motivoOmision': 'Sin stock al confirmar',
        });
      }
    }

    final totalActual = (pedido['total'] as num?)?.toDouble() ?? 0;
    final nuevoTotal  = (totalActual - descuento).clamp(0, double.infinity);

    batch.update(
      FirebaseFirestore.instance.collection('pedido').doc(docId),
      {
        'total':              nuevoTotal,
        'totalConOmisiones':  true,
        'descuentoOmisiones': descuento,
      },
    );

    await batch.commit();
  }

  Future<void> _editarPedido(BuildContext context) async {
    PedidoDialogs.mostrarCargando(context, mensaje: 'Cargando productos...');
    final items = await _cargarItemsConStock();
    if (context.mounted) Navigator.pop(context);
    if (!context.mounted) return;

    await PedidoDialogs.editarPedido(
      context,
      docId: docId,
      idPedidoParaBusqueda: _idPedidoParaBusqueda,
      pedido: pedido,
      itemsConStock: items,
    );
    // Recargar después de editar
    _recargarItems();
  }

  Future<void> _registrarDevolucion(BuildContext context) async {
    PedidoDialogs.mostrarCargando(context, mensaje: 'Cargando productos...');
    final items = await _cargarProductos();
    if (context.mounted) Navigator.pop(context);
    if (!context.mounted) return;

    await PedidoDialogs.registrarDevolucion(
      context,
      docId:         docId,
      pedido:        pedido,
      itemsPedido:   items,
      nombreCliente: _nombreCliente,
      telefono:      _telefono,
    );
    // Recargar después de registrar devolución
    _recargarItems();
  }

  String _formatearFecha(dynamic timestamp) {
    if (timestamp == null || timestamp is! Timestamp) return 'Sin fecha';
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate());
    } catch (_) {
      return 'Fecha inválida';
    }
  }

  String _getNombreEstado(String estado) {
    switch (estado) {
      case 'pendiente':  return 'Pendiente';
      case 'confirmado': return 'Confirmado';
      case 'despachado': return 'Despachado';
      case 'entregado':  return 'Entregado';
      case 'cancelado':  return 'Cancelado';
      default:           return estado;
    }
  }

  // ── Helpers para el banner de devolución ─────────────────────
  String _labelMotivo(String motivo) {
    switch (motivo) {
      case 'defectuoso':          return 'Motivo: Producto defectuoso';
      case 'equivocado':          return 'Motivo: Producto equivocado';
      case 'cantidad_incorrecta': return 'Motivo: Cantidad incorrecta';
      case 'insatisfecho':        return 'Motivo: Cliente insatisfecho';
      case 'otro':                return 'Motivo: Otro';
      default:
        return motivo.isNotEmpty ? 'Motivo: $motivo' : '';
    }
  }

  String _labelResolucion(String res) {
    switch (res) {
      case 'reenvio':   return 'Resolución: Reenvío del producto';
      case 'reembolso': return 'Resolución: Reembolso al cliente';
      default:          return res.isNotEmpty ? 'Resolución: $res' : '';
    }
  }

  Color _getColorEstado(String estado) {
    switch (estado) {
      case 'pendiente':  return Colors.orange;
      case 'confirmado': return Colors.blue;
      case 'despachado': return Colors.purple;
      case 'entregado':  return Colors.green;
      case 'cancelado':  return Colors.red;
      default:           return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fechaPedido =
        _formatearFecha(pedido['fechaPedido'] ?? pedido['creadoEn']);
    final estado          = (pedido['estado'] ?? 'pendiente').toString();
    final total           = (pedido['total'] as num?)?.toDouble() ?? 0.0;
    final tieneOmisiones  = pedido['totalConOmisiones'] == true;
    final tieneDevolucion = pedido['tieneDevolucion'] == true;
    // ── Leer motivo y resolución guardados en el pedido ──────
    final devMotivo    = pedido['ultimaDevolucionMotivo']?.toString() ?? '';
    final devResolucion = pedido['ultimaDevolucionRes']?.toString() ?? '';
    final esPendiente  = estado == 'pendiente';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getColorEstado(estado),
          child: const Icon(Icons.receipt_long, color: Colors.white),
        ),
        title: Text(_numeroPedidoLegible,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$_nombreCliente • $fechaPedido'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tieneDevolucion) ...[
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: devResolucion == 'reembolso'
                      ? Colors.blue[100]
                      : Colors.deepOrange[100],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: devResolucion == 'reembolso'
                        ? Colors.blue[300]!
                        : Colors.deepOrange[300]!,
                  ),
                ),
                child: Text(
                  devResolucion == 'reembolso' ? 'Reembolso' : 'Reenvío',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: devResolucion == 'reembolso'
                        ? Colors.blue[800]
                        : Colors.deepOrange[800],
                  ),
                ),
              ),
            ],
            Chip(
              label: Text(
                _getNombreEstado(estado),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
              backgroundColor: _getColorEstado(estado),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(icon: Icons.person,     label: 'Cliente',   value: _nombreCliente),
                const SizedBox(height: 8),
                _InfoRow(icon: Icons.phone,       label: 'Teléfono',  value: _telefono),
                const SizedBox(height: 8),
                _InfoRow(icon: Icons.location_on, label: 'Dirección', value: _direccion),
                if (pedido['observaciones'] != null &&
                    pedido['observaciones'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _InfoRow(icon: Icons.note, label: 'Observaciones',
                      value: pedido['observaciones'].toString()),
                ],

                // Banner omisiones
                if (tieneOmisiones) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        'Pedido confirmado parcialmente. Los productos tachados fueron omitidos por falta de stock.',
                        style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                      )),
                    ]),
                  ),
                ],

                // ── Banner devolución: ahora muestra motivo Y resolución ──
                if (tieneDevolucion) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.deepOrange[200]!),
                    ),
                    child: Row(children: [
                      Icon(Icons.assignment_return, size: 16, color: Colors.deepOrange[700]),
                      const SizedBox(width: 8),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Devolución registrada',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepOrange[800],
                              )),
                          // Motivo — solo se muestra si existe
                          if (devMotivo.isNotEmpty)
                            Text(
                              _labelMotivo(devMotivo),
                              style: TextStyle(fontSize: 11, color: Colors.deepOrange[700]),
                            ),
                          // Resolución — siempre se muestra si existe
                          if (devResolucion.isNotEmpty)
                            Text(
                              _labelResolucion(devResolucion),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.deepOrange[700],
                              ),
                            ),
                        ],
                      )),
                    ]),
                  ),
                ],

                const Divider(height: 32),

                // Cabecera productos
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Productos',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    if (esPendiente)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 13, color: Colors.orange[700]),
                            const SizedBox(width: 4),
                            Text('Stock en tiempo real',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Lista productos con stock
                FutureBuilder<List<ItemConStock>>(
                  future: _itemsFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final items = snapshot.data!;
                    if (items.isEmpty) {
                      return Text('Sin detalle de productos',
                          style: TextStyle(color: Colors.grey[500]));
                    }

                    final esReenvio     = pedido['esReenvio'] == true;
                    final esEntregado   = estado == 'entregado';

                    // ── En pendiente/confirmado/despachado con reenvío ──
                    // Solo mostrar productos del reenvío (no yaEntregados)
                    if (esReenvio && !esEntregado) {
                      final itemsReenvio = items
                          .where((i) => !i.yaEntregado && !i.omitido)
                          .toList();

                      // Total solo de productos del reenvío
                      double totalReenvio = 0;
                      for (final i in itemsReenvio) {
                        totalReenvio += i.precioUnitario * i.cantidad;
                      }

                      return Column(
                        children: [
                          ...itemsReenvio.map((item) => _ProductoRow(
                                item: item,
                                esPendiente: esPendiente,
                                esEntregado: false,
                                tieneDevolucion: tieneDevolucion,
                                formatearTotal: _formatearTotal,
                              )),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Total reenvío: ${_formatearTotal(totalReenvio)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.black),
                            ),
                          ),
                        ],
                      );
                    }

                    // ── En estado entregado con reenvío: árbol + dos totales ──
                    if (esReenvio && esEntregado) {
                      // Subtotal primera entrega:
                      // - productos yaEntregado
                      // - la parte entregada de productos con devolución parcial
                      double subtotalEntrega = 0;
                      for (final i in items) {
                        if (i.yaEntregado) {
                          subtotalEntrega += i.precioUnitario * i.cantidad;
                        } else if (!i.esProductoReenvio && i.cantidadEntregada > 0) {
                          subtotalEntrega += i.precioUnitario * i.cantidadEntregada;
                        }
                      }

                      // Subtotal reenvío:
                      // - productos nuevos del reenvío (esProductoReenvio)
                      // - la parte reenviada del mismo producto (cantidadReenviada)
                      double subtotalReenvio = 0;
                      for (final i in items) {
                        if (i.esProductoReenvio) {
                          final cant = i.cantidadReenviada > 0 ? i.cantidadReenviada : i.cantidad;
                          subtotalReenvio += i.precioUnitario * cant;
                        } else if (!i.esProductoReenvio && i.cantidadReenviada > 0) {
                          subtotalReenvio += i.precioUnitario * i.cantidadReenviada;
                        }
                      }

                      final totalGeneral = subtotalEntrega + subtotalReenvio;

                      return Column(
                        children: [
                          ...items.map((item) => _ProductoRow(
                                item: item,
                                todosLosItems: items,
                                esPendiente: false,
                                esEntregado: true,
                                tieneDevolucion: tieneDevolucion,
                                formatearTotal: _formatearTotal,
                              )),
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Divider(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Subtotal primera entrega:',
                                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                    Text(_formatearTotal(subtotalEntrega),
                                        style: TextStyle(fontSize: 12, color: Colors.grey[700],
                                            fontWeight: FontWeight.w500)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Subtotal reenvío:',
                                        style: TextStyle(fontSize: 12, color: Colors.teal[700])),
                                    Text(_formatearTotal(subtotalReenvio),
                                        style: TextStyle(fontSize: 12, color: Colors.teal[700],
                                            fontWeight: FontWeight.w500)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Total general:',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    Text(_formatearTotal(totalGeneral),
                                        style: const TextStyle(fontWeight: FontWeight.bold,
                                            fontSize: 15, color: Colors.black)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }

                    // ── Vista normal sin reenvío ──────────────────────────
                    return Column(
                      children: [
                        ...items.map((item) => _ProductoRow(
                              item: item,
                              esPendiente: esPendiente,
                              esEntregado: esEntregado,
                              tieneDevolucion: tieneDevolucion,
                              formatearTotal: _formatearTotal,
                            )),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (tieneOmisiones) ...[
                                Text(
                                  '- ${_formatearTotal((pedido['descuentoOmisiones'] as num?)?.toDouble() ?? 0)} omitido',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red[400],
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                const SizedBox(height: 2),
                              ],
                              Text(
                                'Total: ${_formatearTotal(total)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.black),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const Divider(height: 32),

                // Botones de acción
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (estado == 'pendiente') ...[
                      OutlinedButton.icon(
                        onPressed: () => _editarPedido(context),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Editar pedido'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF00897B),
                          side: const BorderSide(color: Color(0xFF00897B)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _confirmarConValidacion(context),
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('Confirmar pedido'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final ok = await PedidoDialogs.confirmarCancelar(context);
                          if (ok) _cambiarEstado('cancelado');
                        },
                        icon: const Icon(Icons.cancel, size: 18),
                        label: const Text('Cancelar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],

                    if (estado == 'confirmado')
                      ElevatedButton.icon(
                        onPressed: () async {
                          final ok = await PedidoDialogs.confirmarDespacho(context);
                          if (ok) _cambiarEstado('despachado');
                        },
                        icon: const Icon(Icons.local_shipping, size: 18),
                        label: const Text('Marcar como despachado'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),

                    if (estado == 'despachado')
                      ElevatedButton.icon(
                        onPressed: () async {
                          final ok = await PedidoDialogs.confirmarEntrega(context);
                          if (ok) _cambiarEstado('entregado');
                        },
                        icon: const Icon(Icons.done_all, size: 18),
                        label: const Text('Marcar como entregado'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),

                    if (estado == 'entregado' && !tieneDevolucion)
                      OutlinedButton.icon(
                        onPressed: () => _registrarDevolucion(context),
                        icon: const Icon(Icons.assignment_return_outlined, size: 18),
                        label: const Text('Registrar devolución'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange[700],
                          side: BorderSide(color: Colors.orange[700]!),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Widget fila de producto con badge de stock
// ─────────────────────────────────────────────────────────────
class _ProductoRow extends StatelessWidget {
  final ItemConStock item;
  final List<ItemConStock> todosLosItems;
  final bool esPendiente;
  final bool esEntregado;
  final bool tieneDevolucion;
  final String Function(double) formatearTotal;

  const _ProductoRow({
    required this.item,
    required this.formatearTotal,
    this.todosLosItems = const [],
    this.esPendiente   = false,
    this.esEntregado   = false,
    this.tieneDevolucion = false,
  });

  @override
  Widget build(BuildContext context) {
    // ── Vista árbol: entregado CON devolución ────────────────────
    if (esEntregado && tieneDevolucion) {
      return _buildArbol();
    }
    // ── Vista normal ─────────────────────────────────────────────
    return _buildNormal();
  }

  // ─────────────────────────────────────────────────────────────
  // ÁRBOL: clasificación limpia de cada producto
  // Reglas:
  //  1. omitido + !yaEntregado + !canceladoDelReenvio → ocultar (sin stock)
  //  2. yaEntregado                                   → "Ya entregado"
  //  3. canceladoDelReenvio + cantDev==0              → "No reenviado"
  //  4. esProductoReenvio + tieneReemplazo            → ocultar si original visible
  //  5. esProductoReenvio + !tieneReemplazo           → "Reenvío entregado"
  //  6. devuelto + cantDev==0                         → ocultar (legacy)
  //  7. motivoDevolucion + cantDev==0 + cantReenv==0  → ocultar (es original de reemplazo)
  //  8. cantDev > 0                                   → árbol parcial
  //  9. resto                                         → "Ya entregado" (normal entregado)
  // ─────────────────────────────────────────────────────────────
  Widget _buildArbol() {
    final i = item;

    // Regla 1: omitido sin yaEntregado ni cancelado → sin stock al confirmar, ocultar
    if (i.omitido && !i.yaEntregado && !i.canceladoDelReenvio) {
      return const SizedBox.shrink();
    }

    // Regla 2: yaEntregado → primera entrega, mostrar verde
    if (i.yaEntregado) {
      return _fila(i.cantidad, i.nombre, i.precioUnitario,
          tachado: false,
          badge: _Badge(label: 'Ya entregado', color: Colors.green));
    }

    // Regla 3: cancelado del reenvío sin devolución → "No reenviado"
    if (i.canceladoDelReenvio && i.cantidadDevuelta == 0) {
      final cant = i.cantidadOriginal > 0 ? i.cantidadOriginal : i.cantidad;
      return _fila(cant, i.nombre, i.precioUnitario,
          tachado: true,
          badge: _Badge(label: 'No reenviado', color: Colors.grey));
    }

    // Regla 4: producto de reenvío → "Reenvío entregado" simple
    if (i.esProductoReenvio) {
      final cant = i.cantidadReenviada > 0 ? i.cantidadReenviada : i.cantidad;
      return _fila(cant, i.nombre, i.precioUnitario,
          tachado: false,
          badge: _Badge(label: 'Reenvío entregado', color: Colors.teal));
    }

    // Regla 5 eliminada (reemplazo externo ya no existe)

    // Regla 6: devuelto total sin cantidadDevuelta (legacy) → ocultar
    if (i.devuelto && i.cantidadDevuelta == 0) return const SizedBox.shrink();

    // Regla 7: motivoDevolucion sin cantDev ni cantReenv → ocultar (legacy data)
    if (i.motivoDevolucion.isNotEmpty &&
        i.cantidadDevuelta == 0 &&
        i.cantidadReenviada == 0) {
      return const SizedBox.shrink();
    }

    // Regla 8: tiene cantidadDevuelta > 0 → árbol parcial completo
    if (i.cantidadDevuelta > 0) {
      return _buildArbolParcial();
    }

    // Regla 9: producto normal entregado en este reenvío
    return _fila(i.cantidad, i.nombre, i.precioUnitario,
        tachado: false,
        badge: _Badge(label: 'Ya entregado', color: Colors.green));
  }

  // ─────────────────────────────────────────────────────────────
  // Árbol parcial: original → Ya entregado + Devuelto → reenvío/reemplazo
  // ─────────────────────────────────────────────────────────────
  Widget _buildArbolParcial() {
    final i           = item;
    final cantTotal   = i.cantidadOriginal;
    final cantDev     = i.cantidadDevuelta;
    final cantEntrega = cantTotal - cantDev;
    final cantReenv   = i.cantidadReenviada;
    final precio      = i.precioUnitario;

    // Texto adicional en badge Devuelto
    final fueRenviado  = cantReenv > 0;
    final esReenvio    = fueRenviado || i.motivoDevolucion.isNotEmpty;
    final stockLabel   = i.stockRepuesto ? ' • Stock repuesto' : ' • Sin reposición';
    final reenvioLabel = fueRenviado
        ? ' • Se reenviaron'
        : (esReenvio ? ' • No reenviado' : '');
    final devueltoLabel = 'Devuelto$reenvioLabel$stockLabel';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FilaProducto(
            cantidad: cantTotal, nombre: i.nombre, precio: precio,
            tachado: true, badge: null, formatearTotal: formatearTotal, indent: 0,
          ),
          if (cantEntrega > 0)
            _FilaProducto(
              cantidad: cantEntrega, nombre: i.nombre, precio: precio,
              tachado: false,
              badge: _Badge(label: 'Ya entregado', color: Colors.green),
              formatearTotal: formatearTotal, indent: 1,
              esPrimerHijo: true, esUltimoHijo: cantDev == 0,
            ),
          _FilaProducto(
            cantidad: cantDev, nombre: i.nombre, precio: precio,
            tachado: true,
            badge: _Badge(label: devueltoLabel, color: Colors.orange),
            formatearTotal: formatearTotal, indent: 1,
            esPrimerHijo: cantEntrega == 0,
            esUltimoHijo: cantReenv == 0,
          ),
          if (cantReenv > 0)
            _FilaProducto(
              cantidad: cantReenv, nombre: i.nombre, precio: precio,
              tachado: false,
              badge: _Badge(label: 'Reenvío entregado', color: Colors.teal),
              formatearTotal: formatearTotal, indent: 2,
              esPrimerHijo: true, esUltimoHijo: true,
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Vista normal (pendiente / confirmado / despachado)
  // ─────────────────────────────────────────────────────────────
  Widget _buildNormal() {
    final omitido     = item.omitido;
    final devuelto    = item.devuelto;
    final yaEntregado = item.yaEntregado;
    final inactivo    = omitido || devuelto || yaEntregado;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: yaEntregado ? Colors.green[50]
                      : devuelto     ? Colors.orange[50]
                      : omitido      ? Colors.red[50]
                      : Colors.teal[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('${item.cantidad}x',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: yaEntregado ? Colors.green[300]
                        : devuelto     ? Colors.orange[400]
                        : omitido      ? Colors.red[300]
                        : Colors.teal[700],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.nombre,
                      style: TextStyle(
                        decoration: inactivo ? TextDecoration.lineThrough : TextDecoration.none,
                        color: inactivo ? Colors.grey[400] : Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (item.precioUnitario > 0)
                      Text('${formatearTotal(item.precioUnitario)} c/u',
                        style: TextStyle(
                          fontSize: 12,
                          color: inactivo ? Colors.grey[400] : Colors.grey[600],
                          decoration: inactivo ? TextDecoration.lineThrough : TextDecoration.none,
                        ),
                      ),
                  ],
                ),
              ),
              if (yaEntregado)
                _badgeWidget('Ya entregado', Colors.green)
              else if (devuelto)
                _badgeWidget('Devuelto', Colors.orange)
              else if (omitido)
                _badgeWidget('Sin stock', Colors.red),
            ],
          ),
          if (esPendiente && !inactivo) ...[
            const SizedBox(height: 5),
            _StockBadge(item: item),
          ],
        ],
      ),
    );
  }

  // Helper: fila simple sin conector
  Widget _fila(int cantidad, String nombre, double precio,
      {required bool tachado, required _Badge? badge}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: _FilaProducto(
        cantidad: cantidad, nombre: nombre, precio: precio,
        tachado: tachado, badge: badge,
        formatearTotal: formatearTotal, indent: 0,
      ),
    );
  }

  // Helper: badge simple
  Widget _badgeWidget(String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: color[100], borderRadius: BorderRadius.circular(4)),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, color: color[800], fontWeight: FontWeight.w600)),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Modelo para badge de estado
// ─────────────────────────────────────────────────────────────
class _Badge {
  final String label;
  final MaterialColor color;
  const _Badge({required this.label, required this.color});
}

// ─────────────────────────────────────────────────────────────
// Fila individual del árbol con línea de conector
// ─────────────────────────────────────────────────────────────
class _FilaProducto extends StatelessWidget {
  final int cantidad;
  final String nombre;
  final double precio;
  final bool tachado;
  final _Badge? badge;
  final String Function(double) formatearTotal;
  final int indent;
  final bool esPrimerHijo;
  final bool esUltimoHijo;
  final bool mostrarPrecio;

  const _FilaProducto({
    required this.cantidad,
    required this.nombre,
    required this.precio,
    required this.tachado,
    required this.badge,
    required this.formatearTotal,
    required this.indent,
    this.esPrimerHijo  = false,
    this.esUltimoHijo  = false,
    this.mostrarPrecio = true,
  });

  @override
  Widget build(BuildContext context) {
    final bdg = badge;

    Widget fila = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: tachado
                ? (bdg?.color[50] ?? Colors.grey[100]!)
                : (bdg?.color[50] ?? Colors.teal[50]!),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${cantidad}x',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: tachado
                  ? (bdg?.color[300] ?? Colors.grey[400]!)
                  : (bdg?.color[700] ?? Colors.teal[700]!),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nombre,
                style: TextStyle(
                  decoration: tachado ? TextDecoration.lineThrough : TextDecoration.none,
                  color: tachado ? Colors.grey[400] : Colors.black87,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              if (mostrarPrecio && precio > 0)
                Text(
                  '${formatearTotal(precio)} c/u',
                  style: TextStyle(
                    fontSize: 11,
                    color: tachado ? Colors.grey[400] : Colors.grey[600],
                    decoration: tachado ? TextDecoration.lineThrough : TextDecoration.none,
                  ),
                ),
            ],
          ),
        ),
        if (bdg != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: bdg.color[100],
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: bdg.color[200]!),
            ),
            child: Text(
              bdg.label,
              style: TextStyle(
                fontSize: 10,
                color: bdg.color[800],
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );

    if (indent == 0) {
      return Padding(padding: const EdgeInsets.only(bottom: 4), child: fila);
    }

    // Añadir conector tipo git al lado izquierdo
    return Padding(
      padding: EdgeInsets.only(bottom: 4, left: (indent - 1) * 16.0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Línea vertical + curva
            SizedBox(
              width: 20,
              child: CustomPaint(
                painter: _ConectorPainter(
                  esUltimo: esUltimoHijo,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(child: fila),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Dibuja la línea conectora estilo git graph
// ─────────────────────────────────────────────────────────────
class _ConectorPainter extends CustomPainter {
  final bool esUltimo;
  const _ConectorPainter({required this.esUltimo});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[400]!
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Línea vertical (desde arriba hasta el centro, o hasta abajo si no es último)
    canvas.drawLine(
      Offset(cx, 0),
      Offset(cx, esUltimo ? cy : size.height),
      paint,
    );

    // Línea horizontal (desde centro hacia la derecha)
    canvas.drawLine(
      Offset(cx, cy),
      Offset(size.width, cy),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ConectorPainter old) => old.esUltimo != esUltimo;
}

// ─────────────────────────────────────────────────────────────
// Badge de stock
// ─────────────────────────────────────────────────────────────
class _StockBadge extends StatelessWidget {
  final ItemConStock item;
  const _StockBadge({required this.item});

  @override
  Widget build(BuildContext context) {
    final suficiente = item.stockSuficiente;
    final stock      = item.stockActual;
    final cantidad   = item.cantidad;

    final color     = suficiente ? Colors.green : Colors.red;
    final bgColor   = suficiente ? Colors.green[50]! : Colors.red[50]!;
    final borderClr = suficiente ? Colors.green[200]! : Colors.red[200]!;
    final icon      = suficiente
        ? Icons.check_circle_outline
        : Icons.warning_amber_rounded;

    final texto = suficiente
        ? 'Stock suficiente ($stock disponibles)'
        : stock == 0
            ? 'Sin stock (0 disponibles)'
            : 'Stock insuficiente (solo $stock, necesita $cantidad)';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderClr),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            texto,
            style: TextStyle(
              fontSize: 11,
              color: color[800],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _InfoRow
// ─────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        SizedBox(
          width: 100,
          child: Text(label,
              style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        ),
      ],
    );
  }
}