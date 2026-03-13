// lib/models/pedido_model.dart
//
// Representa un documento de la colección 'pedido' en Firestore.
// Uso: en lugar de escribir data['nombreCliente'] en todo el código,
// conviertes el Map a PedidoModel y accedes a pedido.nombreCliente

import 'package:cloud_firestore/cloud_firestore.dart';

class PedidoModel {
  final String    id;
  final String    numeroPedido;
  final String    nombreCliente;
  final String    telefonoContacto;
  final String    direccionEntrega;
  final String    estado;
  final double    total;
  final String    metodoPago;
  final String    observaciones;
  final Timestamp? fechaPedido;

  const PedidoModel({
    required this.id,
    required this.numeroPedido,
    required this.nombreCliente,
    required this.telefonoContacto,
    required this.direccionEntrega,
    required this.estado,
    required this.total,
    required this.metodoPago,
    required this.observaciones,
    this.fechaPedido,
  });

  /// Crea un PedidoModel desde un documento de Firestore.
  /// El [docId] es el ID del documento (doc.id).
  factory PedidoModel.fromFirestore(
      Map<String, dynamic> data, String docId) {
    // Cliente puede venir como campo directo o como sub-mapa
    final clienteMap =
        data['cliente'] is Map ? data['cliente'] as Map : null;

    final nombre = data['nombreCliente']?.toString() ??
        clienteMap?['nombre']?.toString() ??
        'Sin nombre';

    final telefono = data['telefonoContacto']?.toString() ??
        clienteMap?['telefono']?.toString() ??
        '';

    final direccion = data['direccionEntrega']?.toString() ??
        () {
          final d = data['direccion'];
          if (d is Map) {
            return '${d['calle'] ?? ''}, ${d['ciudad'] ?? ''}';
          }
          return '';
        }();

    // Timestamp seguro
    Timestamp? ts;
    final raw = data['fechaPedido'] ?? data['creadoEn'] ?? data['fecha'];
    if (raw is Timestamp) ts = raw;

    return PedidoModel(
      id:               docId,
      numeroPedido:     data['numeroPedido']?.toString() ??
                        data['idPedido']?.toString() ?? '',
      nombreCliente:    nombre,
      telefonoContacto: telefono,
      direccionEntrega: direccion,
      estado:           data['estado']?.toString() ?? 'pendiente',
      total:            (data['total'] as num?)?.toDouble() ?? 0.0,
      metodoPago:       data['metodoPago']?.toString() ?? 'efectivo',
      observaciones:    data['observaciones']?.toString() ?? '',
      fechaPedido:      ts,
    );
  }

  /// Convierte el modelo de vuelta a Map para guardar en Firestore.
  Map<String, dynamic> toMap() => {
        'numeroPedido'     : numeroPedido,
        'nombreCliente'    : nombreCliente,
        'telefonoContacto' : telefonoContacto,
        'direccionEntrega' : direccionEntrega,
        'estado'           : estado,
        'total'            : total,
        'metodoPago'       : metodoPago,
        'observaciones'    : observaciones,
        if (fechaPedido != null) 'fechaPedido': fechaPedido,
      };

  /// Crea una copia con campos modificados
  PedidoModel copyWith({
    String?    estado,
    double?    total,
    Timestamp? fechaPedido,
  }) =>
      PedidoModel(
        id:               id,
        numeroPedido:     numeroPedido,
        nombreCliente:    nombreCliente,
        telefonoContacto: telefonoContacto,
        direccionEntrega: direccionEntrega,
        estado:           estado    ?? this.estado,
        total:            total     ?? this.total,
        metodoPago:       metodoPago,
        observaciones:    observaciones,
        fechaPedido:      fechaPedido ?? this.fechaPedido,
      );
}