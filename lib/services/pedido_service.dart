import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Servicio mejorado para gestionar pedidos en Firebase
class PedidoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _coleccionDetalle = 'detalle_pedido';
  static const String _coleccionPedido  = 'pedido';
  static const String _coleccionVenta   = 'venta';

  // ─────────────────────────────────────────────────────────────────────────
  // FIX BUG-02: Contadores separados para pedidos y ventas.
  // Antes ambos usaban 'contadorPedidos', lo que corrompía la secuencia
  // de numeración cada vez que un pedido se marcaba como entregado.
  // ─────────────────────────────────────────────────────────────────────────

  /// Generar número de PEDIDO único (contador atómico independiente)
  Future<String> _generarNumeroPedido() async {
    final contadorRef = _db.collection('config').doc('contadorPedidos');
    return await _db.runTransaction((transaction) async {
      final snap = await transaction.get(contadorRef);
      final nuevoNumero = ((snap.data()?['ultimo'] ?? 0) as int) + 1;
      transaction.set(contadorRef, {'ultimo': nuevoNumero});
      final fecha = DateFormat('yyyyMMdd').format(DateTime.now());
      return 'PED-$fecha-${nuevoNumero.toString().padLeft(4, '0')}';
    });
  }

  /// Generar número de VENTA único (contador atómico independiente)
  /// CORRECCIÓN BUG-02: usa 'contadorVentas', no 'contadorPedidos'
  Future<String> _generarNumeroVenta() async {
    final contadorRef = _db.collection('config').doc('contadorVentas');
    return await _db.runTransaction((transaction) async {
      final snap = await transaction.get(contadorRef);
      final nuevoNumero = ((snap.data()?['ultimo'] ?? 0) as int) + 1;
      transaction.set(contadorRef, {'ultimo': nuevoNumero});
      final fecha = DateFormat('yyyyMMdd').format(DateTime.now());
      return 'VEN-$fecha-${nuevoNumero.toString().padLeft(4, '0')}';
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FIX BUG-01: Crear pedido con WriteBatch (atómico).
  // Antes: loop for + await uno por uno → pedidos incompletos si fallaba
  //        alguna escritura intermedia.
  // Ahora: WriteBatch acumula todas las escrituras y las confirma de golpe.
  //        Si una falla, ninguna se guarda → base de datos siempre consistente.
  // ─────────────────────────────────────────────────────────────────────────

  /// Crear un nuevo pedido completo — escritura atómica via WriteBatch
  Future<Map<String, dynamic>> crearPedido({
    required String idCliente,
    required String nombreCliente,
    required List<Map<String, dynamic>> items,
    required String direccion,
    required String telefono,
    String? observaciones,
    String metodoPago = 'efectivo',
  }) async {
    try {
      debugPrint('🚀 Iniciando crearPedido...');
      debugPrint('👤 Cliente: $nombreCliente ($idCliente)');
      debugPrint('📦 Cantidad de items: ${items.length}');
      debugPrint('📦 Items: $items');

      // 1. Calcular totales
      double subtotal = items.fold(0.0, (sum, item) =>
        sum + ((item['cantidad'] as num) * (item['precio'] as num))
      );

      int totalArticulos = items.fold(0, (sum, item) =>
        sum + (item['cantidad'] as int)
      );

      const double descuento = 0.0;
      final double total = subtotal - descuento;

      debugPrint('💰 Subtotal: $subtotal | Total: $total');

      // 2. Generar IDs antes del batch
      final pedidoRef    = _db.collection(_coleccionPedido).doc();
      final idPedido     = pedidoRef.id;
      final numeroPedido = await _generarNumeroPedido();

      debugPrint('🔑 idPedido: $idPedido');
      debugPrint('🔑 numeroPedido: $numeroPedido');

      final ahora = DateTime.now();

      // 3. Preparar refs de detalles antes de abrir el batch
      final detalleRefs = items.map((_) => _db.collection(_coleccionDetalle).doc()).toList();
      final idsDetalles  = detalleRefs.map((r) => r.id).toList();

      // 4. Construir el documento del pedido (incluye idsDetalles desde el inicio)
      final datosPedido = {
        'idPedido'             : idPedido,
        'numeroPedido'         : numeroPedido,
        'idCliente'            : idCliente,
        'nombreCliente'        : nombreCliente,
        'fechaPedido'          : FieldValue.serverTimestamp(),
        'fechaCreacion'        : FieldValue.serverTimestamp(),
        'fechaActualizacion'   : FieldValue.serverTimestamp(),
        'fechaEstimadaEntrega' : Timestamp.fromDate(ahora.add(const Duration(days: 1))),
        'estado'               : 'pendiente',
        'estadoAnterior'       : null,
        'historialEstados'     : [
          {'estado': 'pendiente', 'cambiadoPor': 'sistema'},
        ],
        'direccionEntrega'     : direccion,
        'telefonoContacto'     : telefono,
        'subtotal'             : subtotal,
        'descuento'            : descuento,
        'total'                : total,
        'totalArticulos'       : totalArticulos,
        'idsDetalles'          : idsDetalles,
        'cantidadDetalles'     : idsDetalles.length,
        'metodoPago'           : metodoPago,
        'observaciones'        : observaciones ?? '',
        'actualizado_por'      : 'cliente',
        'cancelado'            : false,
        'año'                  : ahora.year,
        'mes'                  : ahora.month,
        'dia'                  : ahora.day,
        'diaSemana'            : ahora.weekday,
      };

      // 5. CORRECCIÓN BUG-01: WriteBatch — todo o nada
      //    Firestore limita a 500 ops/batch; validamos por si acaso.
      if (items.length > 490) {
        throw Exception(
          'El pedido tiene ${items.length} items. El máximo soportado por operación es 490.',
        );
      }

      final batch = _db.batch();

      batch.set(pedidoRef, datosPedido);
      debugPrint('📝 Batch: pedido agregado');

      for (int i = 0; i < items.length; i++) {
        final item     = items[i];
        final ref      = detalleRefs[i];
        final idDet    = idsDetalles[i];
        final cantidad = (item['cantidad'] as num).toInt();
        final precio   = (item['precio']   as num).toDouble();

        batch.set(ref, {
          'idDetalle'      : idDet,
          'idPedido'       : idPedido,
          'numeroPedido'   : numeroPedido,
          'idProducto'     : item['idProducto'] ?? '',
          'nombreProducto' : item['nombre']      ?? '',
          'cantidad'       : cantidad,
          'precioUnitario' : precio,
          'subtotal'       : cantidad * precio,
          'imagen'         : item['imagen']      ?? '',
          'fechaRegistro'  : FieldValue.serverTimestamp(),
        });
        debugPrint('📝 Batch: detalle ${i + 1}/${items.length} agregado (${item['nombre']})');
      }

      await batch.commit();
      debugPrint('✅ Batch committed: pedido + ${items.length} detalles guardados atómicamente');
      debugPrint('🎉 crearPedido completado exitosamente');

      return {
        'exito'        : true,
        'idPedido'     : idPedido,
        'numeroPedido' : numeroPedido,
        'total'        : total,
        'fechaPedido'  : ahora.toIso8601String(),
        'mensaje'      : 'Pedido creado exitosamente',
      };

    } catch (e, stack) {
      debugPrint('❌ ERROR en crearPedido: $e');
      debugPrint('📚 Stack: $stack');
      return {
        'exito'  : false,
        'error'  : e.toString(),
        'mensaje': 'Error al crear el pedido',
      };
    }
  }

  /// Obtener pedidos de un cliente
  Stream<List<Map<String, dynamic>>> obtenerPedidosCliente(String idCliente) {
    return _db
        .collection(_coleccionPedido)
        .where('idCliente', isEqualTo: idCliente)
        .orderBy('fechaPedido', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            if (data['fechaPedido'] != null) {
              final timestamp = data['fechaPedido'] as Timestamp;
              data['fechaPedidoFormateada'] =
                DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate());
            }
            return data;
          }).toList();
        });
  }

  /// Obtener detalles de un pedido específico
  Future<List<Map<String, dynamic>>> obtenerDetallesPedido(String idPedido) async {
    final snapshot = await _db
        .collection(_coleccionDetalle)
        .where('idPedido', isEqualTo: idPedido)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// Obtener pedidos por estado
  Stream<List<Map<String, dynamic>>> obtenerPedidosPorEstado(String estado) {
    return _db
        .collection(_coleccionPedido)
        .where('estado', isEqualTo: estado)
        .orderBy('fechaPedido', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// Obtener RECIBO COMPLETO
  Future<Map<String, dynamic>> obtenerReciboPedido(String idPedido) async {
    try {
      final pedidoDoc = await _db.collection(_coleccionPedido).doc(idPedido).get();

      if (!pedidoDoc.exists) {
        return {'exito': false, 'mensaje': 'Pedido no encontrado'};
      }

      final pedido   = pedidoDoc.data()!;
      final detalles = await obtenerDetallesPedido(idPedido);

      String fechaPedido = '';
      if (pedido['fechaPedido'] != null) {
        final timestamp = pedido['fechaPedido'] as Timestamp;
        fechaPedido = DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate());
      }

      return {
        'exito': true,
        'recibo': {
          'negocio'      : 'Granero del Norte',
          'numeroPedido' : pedido['numeroPedido'],
          'fechaPedido'  : fechaPedido,
          'cliente': {
            'nombre'   : pedido['nombreCliente'],
            'telefono' : pedido['telefonoContacto'],
            'direccion': pedido['direccionEntrega'],
          },
          'items': detalles.map((detalle) => {
            'producto'       : detalle['nombreProducto'],
            'cantidad'       : detalle['cantidad'],
            'precioUnitario' : detalle['precioUnitario'],
            'subtotal'       : detalle['subtotal'],
          }).toList(),
          'totales': {
            'subtotal'       : pedido['subtotal'],
            'descuento'      : pedido['descuento'] ?? 0.0,
            'total'          : pedido['total'],
            'totalArticulos' : pedido['totalArticulos'],
          },
          'estado'       : pedido['estado'],
          'observaciones': pedido['observaciones'],
        },
      };

    } catch (e) {
      return {
        'exito'  : false,
        'error'  : e.toString(),
        'mensaje': 'Error al obtener el recibo',
      };
    }
  }

  /// Actualizar estado del pedido
  Future<void> actualizarEstadoPedido(
    String idPedido,
    String nuevoEstado,
    String idAdmin,
  ) async {
    final pedidoRef    = _db.collection(_coleccionPedido).doc(idPedido);
    final pedidoDoc    = await pedidoRef.get();
    final pedidoActual = pedidoDoc.data()!;

    List<dynamic> historial = List.from(pedidoActual['historialEstados'] ?? []);
    historial.add({
      'estado'         : nuevoEstado,
      'estadoAnterior' : pedidoActual['estado'],
      'fecha'          : FieldValue.serverTimestamp(),
      'cambiadoPor'    : idAdmin,
    });

    await pedidoRef.update({
      'estado'             : nuevoEstado,
      'estadoAnterior'     : pedidoActual['estado'],
      'historialEstados'   : historial,
      'fechaActualizacion' : FieldValue.serverTimestamp(),
      'actualizado_por'    : idAdmin,
    });

    if (nuevoEstado == 'entregado') {
      // CORRECCIÓN BUG-02: _generarNumeroVenta() — contador independiente
      final ventaRef    = _db.collection(_coleccionVenta).doc();
      final numeroVenta = await _generarNumeroVenta();

      await ventaRef.set({
        'idVenta'       : ventaRef.id,
        'numeroVenta'   : numeroVenta,
        'idPedido'      : idPedido,
        'numeroPedido'  : pedidoActual['numeroPedido'],
        'idCliente'     : pedidoActual['idCliente'],
        'nombreCliente' : pedidoActual['nombreCliente'],
        'fechaVenta'    : FieldValue.serverTimestamp(),
        'total'         : pedidoActual['total'],
        'registradoPor' : idAdmin,
        'año'           : DateTime.now().year,
        'mes'           : DateTime.now().month,
        'dia'           : DateTime.now().day,
      });

      await pedidoRef.update({
        'fechaPago': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Obtener estadísticas del día
  Future<Map<String, dynamic>> obtenerEstadisticasHoy() async {
    final hoy       = DateTime.now();
    final inicioDia = DateTime(hoy.year, hoy.month, hoy.day);

    final snapshot = await _db
        .collection(_coleccionPedido)
        .where('fechaPedido', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDia))
        .get();

    double totalVentas      = 0;
    int    totalPedidos      = snapshot.docs.length;
    int    pedidosPendientes = 0;
    int    pedidosEntregados = 0;

    for (var doc in snapshot.docs) {
      final data  = doc.data();
      totalVentas += (data['total'] ?? 0.0) as double;
      if (data['estado'] == 'pendiente') pedidosPendientes++;
      if (data['estado'] == 'entregado') pedidosEntregados++;
    }

    return {
      'fecha'             : DateFormat('dd/MM/yyyy').format(hoy),
      'totalPedidos'      : totalPedidos,
      'totalVentas'       : totalVentas,
      'pedidosPendientes' : pedidosPendientes,
      'pedidosEntregados' : pedidosEntregados,
      'ticketPromedio'    : totalPedidos > 0 ? totalVentas / totalPedidos : 0,
    };
  }
}