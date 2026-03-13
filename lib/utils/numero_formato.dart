// lib/utils/numero_formato.dart
//
// Helpers de formato numérico compartidos por:
//   - dashboard_page.dart  (_formatNum)
//   - productos_page.dart  (_formatearPrecio)
//
// USO:
//   import '../utils/numero_formato.dart';
//   String precio = formatearPrecioCOP(producto['precio']);
//   String resumen = formatearNumeroCorto(stats['ventasHoy']);

/// Formatea un precio en pesos colombianos con separadores de miles.
/// Ej: 1500000 → "$1.500.000"
String formatearPrecioCOP(dynamic precio) {
  if (precio == null) return '\$0';
  final numero = (precio as num).toInt();
  final formatted = numero.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]}.',
  );
  return '\$$formatted';
}

/// Formatea un número grande a forma abreviada.
/// Ej: 1500000 → "1.5M" | 2500 → "3K" | 500 → "500"
String formatearNumeroCorto(dynamic v) {
  final n = ((v ?? 0.0) as num).toDouble();
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000)    return '${(n / 1000).toStringAsFixed(0)}K';
  return n.toStringAsFixed(0);
}