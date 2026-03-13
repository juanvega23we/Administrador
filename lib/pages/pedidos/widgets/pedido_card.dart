// lib/pages/pedidos/widgets/pedido_card.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../../widgets/notificacion_personalizada.dart';
import 'pedido_dialogs.dart';

class PedidoCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> pedido;
  final Future<void> Function(String nuevoEstado) onEstadoChanged;

  const PedidoCard({
    super.key,
    required this.docId,
    required this.pedido,
    required this.onEstadoChanged,
  });

  static final _formatoCOP = NumberFormat('#,###', 'es_CO');

  String _formatearTotal(double valor) =>
      '\$${_formatoCOP.format(valor.toInt())}';

  String get _numeroPedidoLegible {
    final num = pedido['numeroPedido']?.toString() ?? '';
    if (num.isNotEmpty && num.startsWith('PED-')) return num;
    final id = pedido['idPedido']?.toString() ?? '';
    if (id.isNotEmpty && id.startsWith('PED-')) return id;
    if (num.isNotEmpty) return num;
    if (id.isNotEmpty) return id;
    final ts = pedido['fechaPedido'] ?? pedido['creadoEn'];
    if (ts is Timestamp) {
      final f = ts.toDate();
      return 'PED-${f.year}${f.month.toString().padLeft(2, '0')}${f.day.toString().padLeft(2, '0')}-${f.hour.toString().padLeft(2, '0')}${f.minute.toString().padLeft(2, '0')}';
    }
    return 'PED-${docId.substring(0, docId.length.clamp(0, 8))}';
  }

  String get _idPedidoParaBusqueda {
    final idPedido = pedido['idPedido']?.toString() ?? '';
    if (idPedido.isNotEmpty && !idPedido.startsWith('PED-')) return idPedido;
    if (docId.isNotEmpty) return docId;
    return pedido['numeroPedido']?.toString() ?? '';
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

  // ════════════════════════════════════════════════════════════
  // LÓGICA DE STOCK — con confirmación parcial
  // ════════════════════════════════════════════════════════════
  Future<void> _confirmarConValidacion(BuildContext context) async {
    PedidoDialogs.mostrarCargando(context,
        mensaje: 'Verificando stock disponible...');

    final productos = await _cargarProductos();

    if (context.mounted) Navigator.pop(context);

    if (productos.isEmpty) {
      onEstadoChanged('confirmado');
      return;
    }

    final Map<String, int>    cantidadPorProducto  = {};
    final Map<String, String> nombrePorProducto    = {};
    final Map<String, double> precioPorProducto    = {};

    for (final item in productos) {
      final idProducto = (item['idProducto'] ?? item['id'])?.toString();
      if (idProducto == null || idProducto.isEmpty) continue;
      final cantidad = (item['cantidad'] as num?)?.toInt() ?? 0;
      final precio   = (item['precioUnitario'] ?? item['precio'] as num? ?? 0).toDouble();
      final nombre   = (item['nombreProducto'] ?? item['nombre'] ?? idProducto).toString();
      cantidadPorProducto[idProducto] = (cantidadPorProducto[idProducto] ?? 0) + cantidad;
      nombrePorProducto[idProducto]   = nombre;
      precioPorProducto[idProducto]   = precio;
    }

    final List<String> sinStock          = [];  // nombres
    final List<String> stockInsuficiente = [];  // nombres
    final List<String> idsOk             = [];  // ids con stock OK
    final List<String> idsSinStock       = [];  // ids sin stock

    for (final entry in cantidadPorProducto.entries) {
      final idProducto = entry.key;
      final cantidad   = entry.value;
      final nombre     = nombrePorProducto[idProducto] ?? idProducto;

      final productoDoc = await FirebaseFirestore.instance
          .collection('productos')
          .doc(idProducto)
          .get();

      if (!productoDoc.exists) continue;

      final stockActual = (productoDoc.data()?['stock'] as num?)?.toInt() ?? 0;

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

    // ── Todo OK → confirmar directo ──────────────────────────
    if (sinStock.isEmpty && stockInsuficiente.isEmpty) {
      onEstadoChanged('confirmado');
      return;
    }

    // ── Hay productos problemáticos pero TAMBIÉN hay OK
    //    → preguntar si continuar sin los que faltan ────────────
    if (idsOk.isNotEmpty) {
      final productosProblema = [...sinStock, ...stockInsuficiente];

      final continuar = await PedidoDialogs.confirmarParcial(
        context,
        productosProblema: productosProblema,
        productosOkCount: idsOk.length,
      );

      if (continuar == true && context.mounted) {
        // Marcar productos omitidos y recalcular total
        await _aplicarConfirmacionParcial(
          idsSinStock: idsSinStock,
          precioPorProducto: precioPorProducto,
          cantidadPorProducto: cantidadPorProducto,
        );
        onEstadoChanged('confirmado');
      }
      return;
    }

    // ── Todos los productos tienen problema → bloquear ────────
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

  // ── Marcar omitidos en Firestore y recalcular total ──────────
  Future<void> _aplicarConfirmacionParcial({
    required List<String> idsSinStock,
    required Map<String, double> precioPorProducto,
    required Map<String, int> cantidadPorProducto,
  }) async {
    // 1. Calcular cuánto se descuenta del total
    double descuento = 0;
    for (final id in idsSinStock) {
      final precio   = precioPorProducto[id] ?? 0;
      final cantidad = cantidadPorProducto[id] ?? 0;
      descuento += precio * cantidad;
    }

    // 2. Marcar cada detalle_pedido omitido con omitido: true
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

    // 3. Actualizar total en el pedido
    final totalActual = (pedido['total'] as num?)?.toDouble() ?? 0;
    final nuevoTotal  = (totalActual - descuento).clamp(0, double.infinity);

    final pedidoRef = FirebaseFirestore.instance
        .collection('pedido')
        .doc(docId);

    batch.update(pedidoRef, {
      'total':             nuevoTotal,
      'totalConOmisiones': true,
      'descuentoOmisiones': descuento,
    });

    await batch.commit();
  }

  // ── Cargar productos del pedido ──────────────────────────────
  Future<List<Map<String, dynamic>>> _cargarProductos() async {
    final detallesSnap = await FirebaseFirestore.instance
        .collection('detalle_pedido')
        .where('idPedido', isEqualTo: _idPedidoParaBusqueda)
        .get();

    if (detallesSnap.docs.isNotEmpty) {
      return detallesSnap.docs.map((d) => d.data()).toList();
    }

    final numeroPedido = pedido['numeroPedido']?.toString() ?? '';
    if (numeroPedido.isNotEmpty && numeroPedido != _idPedidoParaBusqueda) {
      final detallesPorNumero = await FirebaseFirestore.instance
          .collection('detalle_pedido')
          .where('idPedido', isEqualTo: numeroPedido)
          .get();
      if (detallesPorNumero.docs.isNotEmpty) {
        return detallesPorNumero.docs.map((d) => d.data()).toList();
      }
    }

    final itemsArray = pedido['items'] as List<dynamic>? ?? [];
    return itemsArray.whereType<Map<String, dynamic>>().toList();
  }

  // ── Helpers UI ───────────────────────────────────────────────
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
      case 'entregado':  return 'Entregado';
      case 'cancelado':  return 'Cancelado';
      default:           return estado;
    }
  }

  Color _getColorEstado(String estado) {
    switch (estado) {
      case 'pendiente':  return Colors.orange;
      case 'confirmado': return Colors.blue;
      case 'entregado':  return Colors.green;
      case 'cancelado':  return Colors.red;
      default:           return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fechaPedido =
        _formatearFecha(pedido['fechaPedido'] ?? pedido['creadoEn']);
    final estado = (pedido['estado'] ?? 'pendiente').toString();
    final total  = (pedido['total'] as num?)?.toDouble() ?? 0.0;
    final tieneOmisiones = pedido['totalConOmisiones'] == true;

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
        trailing: Chip(
          label: Text(
            _getNombreEstado(estado),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
          ),
          backgroundColor: _getColorEstado(estado),
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

                // Aviso si el pedido fue confirmado parcialmente
                if (tieneOmisiones) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: Colors.orange[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Pedido confirmado parcialmente. '
                            'Los productos tachados fueron omitidos por falta de stock.',
                            style: TextStyle(
                                fontSize: 12, color: Colors.orange[800]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const Divider(height: 32),
                const Text('Productos',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),

                // Lista de productos con estado omitido
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _cargarProductos(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }
                    final prods = snapshot.data!;
                    if (prods.isEmpty) {
                      return Text('Sin detalle de productos',
                          style: TextStyle(color: Colors.grey[500]));
                    }
                    return Column(
                      children: [
                        ...prods.map((p) {
                          final nombre = (p['nombreProducto'] ??
                                  p['nombre'] ?? 'N/A').toString();
                          final cantidad       = p['cantidad'] ?? 0;
                          final precioUnitario = (p['precioUnitario'] as num?)?.toDouble() ?? 0.0;
                          final omitido        = p['omitido'] == true;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                // Badge cantidad
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: omitido
                                        ? Colors.red[50]
                                        : Colors.teal[50],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${cantidad}x',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: omitido
                                          ? Colors.red[300]
                                          : Colors.teal[700],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Nombre del producto + precio unitario
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nombre,
                                        style: TextStyle(
                                          decoration: omitido
                                              ? TextDecoration.lineThrough
                                              : TextDecoration.none,
                                          color: omitido
                                              ? Colors.grey[400]
                                              : Colors.black87,
                                        ),
                                      ),
                                      if (precioUnitario > 0)
                                        Text(
                                          '${_formatearTotal(precioUnitario)} c/u',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: omitido
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                            decoration: omitido
                                                ? TextDecoration.lineThrough
                                                : TextDecoration.none,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                // Chip "Sin stock" si fue omitido
                                if (omitido)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red[100],
                                      borderRadius:
                                          BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Sin stock',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.red[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),

                        // Total
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Si hubo omisiones, mostrar el descuento
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
                      ElevatedButton.icon(
                        onPressed: () =>
                            _confirmarConValidacion(context),
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('Confirmar pedido'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final ok = await PedidoDialogs
                              .confirmarCancelar(context);
                          if (ok) onEstadoChanged('cancelado');
                        },
                        icon: const Icon(Icons.cancel, size: 18),
                        label: const Text('Cancelar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                    if (estado == 'confirmado')
                      ElevatedButton.icon(
                        onPressed: () async {
                          final ok = await PedidoDialogs
                              .confirmarEntrega(context);
                          if (ok) onEstadoChanged('entregado');
                        },
                        icon: const Icon(Icons.done_all, size: 18),
                        label: const Text('Marcar como entregado'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
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
              style: const TextStyle(
                  fontWeight: FontWeight.w500, fontSize: 14)),
        ),
      ],
    );
  }
}