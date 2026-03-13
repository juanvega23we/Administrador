// lib/utils/fecha_helpers.dart
//
// Helpers de fechas compartidos por:
//   - dashboard_page.dart
//   - pedidos_page.dart
//   - reportes_page.dart
//
// USO:
//   import '../utils/fecha_helpers.dart';
//   String txt = formatearFecha(pedido['fechaPedido']);
//   Timestamp? ts = safeTimestamp(pedido['creadoEn']);

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Convierte un valor dinámico a Timestamp de forma segura.
/// Devuelve null si el valor no es un Timestamp.
Timestamp? safeTimestamp(dynamic value) {
  if (value is Timestamp) return value;
  return null;
}

/// Formatea un Timestamp (o cualquier valor) a texto legible.
/// [formato] por defecto: 'dd/MM/yyyy HH:mm'
String formatearFecha(
  dynamic timestamp, {
  String formato = 'dd/MM/yyyy HH:mm',
}) {
  if (timestamp == null || timestamp is! Timestamp) return 'Sin fecha';
  try {
    return DateFormat(formato).format(timestamp.toDate());
  } catch (_) {
    return '—';
  }
}

/// Devuelve la fecha actual en formato legible en español.
/// Ej: "2 de Marzo, 2026"
String fechaActualTexto() {
  final now = DateTime.now();
  const meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];
  return '${now.day} de ${meses[now.month - 1]}, ${now.year}';
}

/// Genera un número de pedido legible a partir de los datos del pedido.
/// Lógica extraída de dashboard_page.dart y pedidos_page.dart.
String generarNumeroPedido(Map<String, dynamic> data) {
  final num = data['numeroPedido']?.toString() ?? '';
  if (num.isNotEmpty) return num;

  final id = data['idPedido']?.toString() ?? '';
  if (id.isNotEmpty) return id;

  final ts = safeTimestamp(data['fechaPedido'] ?? data['creadoEn']);
  if (ts != null) {
    final f  = ts.toDate();
    final y  = f.year.toString();
    final m  = f.month.toString().padLeft(2, '0');
    final d  = f.day.toString().padLeft(2, '0');
    final hh = f.hour.toString().padLeft(2, '0');
    final mm = f.minute.toString().padLeft(2, '0');
    return 'PED-$y$m$d-$hh$mm';
  }

  return 'Sin número';
}