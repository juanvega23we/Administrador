import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Agregar al pubspec.yaml

/// Servicio mejorado para gestionar pedidos en Firebase
class PedidoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Generar número de pedido único y legible
  String _generarNumeroPedido() {
    final now = DateTime.now();
    // Formato: PED-20260209-1234 (año/mes/día-hora/minuto)
    return 'PED-${DateFormat('yyyyMMdd-HHmm').format(now)}';
  }

  /// Crear un nuevo pedido completo con TODOS los campos automáticos
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
      // 1. Calcular totales automáticamente
      double subtotal = items.fold(0.0, (sum, item) => 
        sum + (item['cantidad'] * item['precio'])
      );
      
      int totalArticulos = items.fold(0, (sum, item) => 
        sum + (item['cantidad'] as int)
      );

      // Puedes agregar cálculo de descuentos, impuestos, etc.
      double descuento = 0.0;
      double total = subtotal - descuento;

      // 2. Generar ID y número de pedido automáticamente
      final pedidoRef = _db.collection('pedido').doc();
      String idPedido = pedidoRef.id;
      String numeroPedido = _generarNumeroPedido();

      // 3. Obtener timestamp actual
      final ahora = DateTime.now();

      // 4. Crear el documento del pedido con CAMPOS AUTOMÁTICOS
      final datosPedido = {
        // IDs
        'idPedido': idPedido,
        'numeroPedido': numeroPedido, // ⭐ GENERADO AUTOMÁTICAMENTE
        'idCliente': idCliente,
        'nombreCliente': nombreCliente,

        // Fechas (AUTOMÁTICAS)
        'fechaPedido': FieldValue.serverTimestamp(),
        'fechaCreacion': FieldValue.serverTimestamp(),
        'fechaActualizacion': FieldValue.serverTimestamp(),
        'fechaEstimadaEntrega': Timestamp.fromDate(
          ahora.add(const Duration(days: 1))
        ), // ⭐ Auto: entrega en 24h

        // Estado
        'estado': 'pendiente',
        'estadoAnterior': null,
        'historialEstados': [
          {
            'estado': 'pendiente',
            'fecha': FieldValue.serverTimestamp(),
            'cambiadoPor': 'sistema',
          }
        ],

        // Información de contacto
        'direccionEntrega': direccion,
        'telefonoContacto': telefono,

        // Totales (CALCULADOS AUTOMÁTICAMENTE)
        'subtotal': subtotal,
        'descuento': descuento,
        'total': total,
        'totalArticulos': totalArticulos, // ⭐ GENERADO AUTO

        // Pago
        'metodoPago': metodoPago,
        'estadoPago': 'pendiente',

        // Otros
        'observaciones': observaciones ?? '',
        'actualizado_por': 'cliente',
        'cancelado': false,
        
        // Metadata útil para reportes
        'año': ahora.year,
        'mes': ahora.month,
        'dia': ahora.day,
        'diaSemana': ahora.weekday,
      };

      // 5. Guardar el pedido
      await pedidoRef.set(datosPedido);

      // 6. Crear detalles del pedido (cada producto)
      List<String> idsDetalles = [];
      
      for (var item in items) {
        final detalleRef = _db.collection('detalle_pedido').doc();
        String idDetalle = detalleRef.id;
        idsDetalles.add(idDetalle);

        await detalleRef.set({
          'idDetalle': idDetalle,
          'idPedido': idPedido,
          'numeroPedido': numeroPedido, // Referencia al número legible
          'idProducto': item['idProducto'],
          'nombreProducto': item['nombre'],
          'cantidad': item['cantidad'],
          'precioUnitario': item['precio'],
          'subtotal': item['cantidad'] * item['precio'],
          'fechaRegistro': FieldValue.serverTimestamp(),
        });
      }

      // 7. Actualizar el pedido con los IDs de los detalles
      await pedidoRef.update({
        'idsDetalles': idsDetalles,
        'cantidadDetalles': idsDetalles.length,
      });

      // 8. Retornar toda la información del recibo
      return {
        'exito': true,
        'idPedido': idPedido,
        'numeroPedido': numeroPedido,
        'total': total,
        'fechaPedido': ahora.toIso8601String(),
        'mensaje': 'Pedido creado exitosamente',
        'datosPedido': datosPedido,
      };

    } catch (e) {
      return {
        'exito': false,
        'error': e.toString(),
        'mensaje': 'Error al crear el pedido',
      };
    }
  }

  /// Obtener pedidos de un cliente con toda la información
  Stream<List<Map<String, dynamic>>> obtenerPedidosCliente(String idCliente) {
    return _db
        .collection('pedido')
        .where('idCliente', isEqualTo: idCliente)
        .orderBy('fechaPedido', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            // Convertir timestamps a fechas legibles
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
        .collection('detalle_pedido')
        .where('idPedido', isEqualTo: idPedido)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// Obtener pedidos por estado
  Stream<List<Map<String, dynamic>>> obtenerPedidosPorEstado(String estado) {
    return _db
        .collection('pedido')
        .where('estado', isEqualTo: estado)
        .orderBy('fechaPedido', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// Obtener RECIBO COMPLETO (para mostrar o imprimir)
  Future<Map<String, dynamic>> obtenerReciboPedido(String idPedido) async {
    try {
      // Obtener pedido
      final pedidoDoc = await _db.collection('pedido').doc(idPedido).get();
      
      if (!pedidoDoc.exists) {
        return {'exito': false, 'mensaje': 'Pedido no encontrado'};
      }

      final pedido = pedidoDoc.data()!;

      // Obtener detalles
      final detalles = await obtenerDetallesPedido(idPedido);

      // Obtener información del cliente
      final clienteDoc = await _db
          .collection('clientes')
          .doc(pedido['idCliente'])
          .get();
      
      final cliente = clienteDoc.data() ?? {};

      // Formatear fechas
      String fechaPedido = '';
      if (pedido['fechaPedido'] != null) {
        final timestamp = pedido['fechaPedido'] as Timestamp;
        fechaPedido = DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate());
      }

      // Construir recibo completo
      return {
        'exito': true,
        'recibo': {
          // Encabezado
          'negocio': 'El Gran Molino',
          'numeroPedido': pedido['numeroPedido'],
          'fechaPedido': fechaPedido,
          
          // Cliente
          'cliente': {
            'nombre': pedido['nombreCliente'],
            'telefono': pedido['telefonoContacto'],
            'direccion': pedido['direccionEntrega'],
          },
          
          // Detalles de productos
          'items': detalles.map((detalle) => {
            'producto': detalle['nombreProducto'],
            'cantidad': detalle['cantidad'],
            'precioUnitario': detalle['precioUnitario'],
            'subtotal': detalle['subtotal'],
          }).toList(),
          
          // Totales
          'totales': {
            'subtotal': pedido['subtotal'],
            'descuento': pedido['descuento'] ?? 0.0,
            'total': pedido['total'],
            'totalArticulos': pedido['totalArticulos'],
          },
          
          // Estado y pago
          'estado': pedido['estado'],
          'metodoPago': pedido['metodoPago'],
          'estadoPago': pedido['estadoPago'],
          'observaciones': pedido['observaciones'],
        },
      };

    } catch (e) {
      return {
        'exito': false,
        'error': e.toString(),
        'mensaje': 'Error al obtener el recibo',
      };
    }
  }

  /// Actualizar estado del pedido con historial automático
  Future<void> actualizarEstadoPedido(
    String idPedido,
    String nuevoEstado,
    String idAdmin,
  ) async {
    final pedidoRef = _db.collection('pedido').doc(idPedido);
    final pedidoDoc = await pedidoRef.get();
    final pedidoActual = pedidoDoc.data()!;

    // Crear registro en el historial
    List<dynamic> historial = pedidoActual['historialEstados'] ?? [];
    historial.add({
      'estado': nuevoEstado,
      'estadoAnterior': pedidoActual['estado'],
      'fecha': FieldValue.serverTimestamp(),
      'cambiadoPor': idAdmin,
    });

    // Actualizar pedido
    await pedidoRef.update({
      'estado': nuevoEstado,
      'estadoAnterior': pedidoActual['estado'],
      'historialEstados': historial,
      'fechaActualizacion': FieldValue.serverTimestamp(),
      'actualizado_por': idAdmin,
    });

    // Si se marca como entregado, crear venta automáticamente
    if (nuevoEstado == 'entregado') {
      final ventaRef = _db.collection('venta').doc();
      await ventaRef.set({
        'idVenta': ventaRef.id,
        'numeroVenta': _generarNumeroPedido().replaceAll('PED', 'VEN'),
        'idPedido': idPedido,
        'numeroPedido': pedidoActual['numeroPedido'],
        'idCliente': pedidoActual['idCliente'],
        'nombreCliente': pedidoActual['nombreCliente'],
        'fechaVenta': FieldValue.serverTimestamp(),
        'total': pedidoActual['total'],
        'metodoPago': pedidoActual['metodoPago'],
        'registradoPor': idAdmin,
        // Metadata
        'año': DateTime.now().year,
        'mes': DateTime.now().month,
      });

      // Actualizar estado de pago
      await pedidoRef.update({
        'estadoPago': 'pagado',
        'fechaPago': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Obtener estadísticas del día (para reportes)
  Future<Map<String, dynamic>> obtenerEstadisticasHoy() async {
    final hoy = DateTime.now();
    final inicioDia = DateTime(hoy.year, hoy.month, hoy.day);
    
    final snapshot = await _db
        .collection('pedido')
        .where('fechaPedido', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDia))
        .get();

    double totalVentas = 0;
    int totalPedidos = snapshot.docs.length;
    int pedidosPendientes = 0;
    int pedidosEntregados = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      totalVentas += (data['total'] ?? 0.0) as double;
      
      if (data['estado'] == 'pendiente') pedidosPendientes++;
      if (data['estado'] == 'entregado') pedidosEntregados++;
    }

    return {
      'fecha': DateFormat('dd/MM/yyyy').format(hoy),
      'totalPedidos': totalPedidos,
      'totalVentas': totalVentas,
      'pedidosPendientes': pedidosPendientes,
      'pedidosEntregados': pedidosEntregados,
      'ticketPromedio': totalPedidos > 0 ? totalVentas / totalPedidos : 0,
    };
  }
}