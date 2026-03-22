// lib/pages/pedidos/models/item_con_stock.dart

class ItemConStock {
  final Map<String, dynamic> item;
  final int stockActual;

  const ItemConStock({
    required this.item,
    required this.stockActual,
  });

  bool get omitido             => item['omitido']             == true;
  bool get devuelto            => item['devuelto']            == true;
  bool get yaEntregado         => item['yaEntregado']         == true;
  bool get esProductoReenvio   => item['esProductoReenvio']   == true;
  bool get canceladoDelReenvio => item['canceladoDelReenvio'] == true;
  bool get stockRepuesto       => item['stockRepuesto']       == true;

  String get motivoDevolucion => item['motivoDevolucion']?.toString() ?? '';

  int    get cantidad       => (item['cantidad']      as num?)?.toInt()    ?? 0;
  double get precioUnitario => ((item['precioUnitario'] ?? item['precio'] ?? 0) as num).toDouble();
  String get nombre         => (item['nombreProducto'] ?? item['nombre']   ?? 'N/A').toString();
  String get idProducto     => (item['idProducto']     ?? item['id']       ?? '').toString();

  bool get stockSuficiente => stockActual >= cantidad;

  int get cantidadDevuelta  => (item['cantidadDevuelta']  as num?)?.toInt() ?? 0;
  int get cantidadReenviada => (item['cantidadReenviada'] as num?)?.toInt() ?? 0;

  int get cantidadOriginal {
    final guardado = (item['cantidadOriginal'] as num?)?.toInt();
    if (guardado != null && guardado > 0) return guardado;
    final cant     = cantidad;
    final devuelta = cantidadDevuelta;
    if (devuelto && cant == 0 && devuelta > 0) return devuelta;
    return cant + devuelta;
  }

  int get cantidadEntregada => cantidadOriginal - cantidadDevuelta;
}