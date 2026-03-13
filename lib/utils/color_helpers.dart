// lib/utils/color_helpers.dart
//
// Helpers de color y nombre de estado compartidos por:
//   - dashboard_page.dart
//   - pedidos_page.dart
//   - reportes_page.dart
//
// USO:
//   import '../utils/color_helpers.dart';
//   Color c = colorEstado(pedido['estado']);
//   String n = nombreEstado(pedido['estado']);

import 'package:flutter/material.dart';

/// Devuelve el Color asociado al estado de un pedido.
Color colorEstado(String? estado) {
  switch (estado) {
    case 'pendiente':  return Colors.orange;
    case 'confirmado': return Colors.blue;
    case 'preparando': return Colors.purple;
    case 'enviado':    return Colors.indigo;
    case 'entregado':  return Colors.green;
    case 'cancelado':  return Colors.red;
    default:           return Colors.grey;
  }
}

/// Devuelve el texto legible del estado de un pedido.
String nombreEstado(String? estado) {
  switch (estado) {
    case 'pendiente':  return 'Pendiente';
    case 'confirmado': return 'Confirmado';
    case 'preparando': return 'Preparando';
    case 'enviado':    return 'Enviado';
    case 'entregado':  return 'Entregado';
    case 'cancelado':  return 'Cancelado';
    default:           return estado ?? '—';
  }
}