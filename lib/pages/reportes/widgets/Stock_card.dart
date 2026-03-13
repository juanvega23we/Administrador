// lib/pages/reportes/widgets/stock_card.dart
//
// Widget que muestra el resumen de stock de productos
// en la página de Reportes.  Se alimenta de Firestore
// en tiempo real (StreamBuilder sobre 'productos').
//
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

const _kColor     = Color(0xFF00897B);
const _kColorDark = Color(0xFF004D40);

// ─────────────────────────────────────────────────────────────
//  Widget principal
// ─────────────────────────────────────────────────────────────
class StockCard extends StatefulWidget {
  const StockCard({super.key});

  @override
  State<StockCard> createState() => _StockCardState();
}

class _StockCardState extends State<StockCard> {
  /// 'todos' | 'sinStock' | 'bajo' | 'optimo'
  String _filtro = 'todos';

  static const _kStockMinDefault = 5;

  _EstadoStock _estadoProducto(Map<String, dynamic> p) {
    final stock = (p['stock'] as num?)?.toInt() ?? 0;
    final min   = (p['stockMinimo'] as num?)?.toInt() ?? _kStockMinDefault;
    if (stock <= 0)    return _EstadoStock.sinStock;
    if (stock <= min)  return _EstadoStock.bajo;
    return _EstadoStock.optimo;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('productos')
          .orderBy('nombre')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const _LoadingCard();
        }

        final todos = snap.data!.docs
            .map((d) => d.data() as Map<String, dynamic>)
            .toList();

        final sinStock = todos.where((p) => _estadoProducto(p) == _EstadoStock.sinStock).toList();
        final bajo     = todos.where((p) => _estadoProducto(p) == _EstadoStock.bajo).toList();
        final optimo   = todos.where((p) => _estadoProducto(p) == _EstadoStock.optimo).toList();

        // Filtro activo
        List<Map<String, dynamic>> lista;
        switch (_filtro) {
          case 'sinStock': lista = sinStock; break;
          case 'bajo':     lista = bajo;     break;
          case 'optimo':   lista = optimo;   break;
          default:
            // orden: sin stock primero, luego bajo, luego óptimo
            lista = [...sinStock, ...bajo, ...optimo];
        }

        final valorInventario = todos.fold<double>(
          0.0,
          (s, p) =>
              s +
              ((p['stock'] as num?)?.toDouble() ?? 0) *
              ((p['precio'] ?? p['precioVenta'] as num?)?.toDouble() ?? 0),
        );

        return Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── ENCABEZADO ──────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _kColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.inventory_2_rounded,
                            color: _kColor, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Stock de Productos',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _kColorDark)),
                        const SizedBox(height: 3),
                        Text('${todos.length} productos en catálogo',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w500)),
                      ]),
                    ]),
                    // Badge valor inventario
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          _kColor.withOpacity(0.15),
                          _kColor.withOpacity(0.05),
                        ]),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _kColor.withOpacity(0.2)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.monetization_on_rounded,
                            color: _kColor, size: 15),
                        const SizedBox(width: 6),
                        Text(
                          '\$ ${NumberFormat('#,##0', 'es_CO').format(valorInventario.round())}',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _kColor),
                        ),
                      ]),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── KPI CHIPS ───────────────────────────────────
                Row(children: [
                  _KpiChip(
                    label: 'Sin stock',
                    count: sinStock.length,
                    color: Colors.redAccent,
                    icon: Icons.cancel_rounded,
                    isActive: _filtro == 'sinStock',
                    onTap: () => setState(
                        () => _filtro = _filtro == 'sinStock' ? 'todos' : 'sinStock'),
                  ),
                  const SizedBox(width: 8),
                  _KpiChip(
                    label: 'Stock bajo',
                    count: bajo.length,
                    color: const Color(0xFFF57F17),
                    icon: Icons.warning_amber_rounded,
                    isActive: _filtro == 'bajo',
                    onTap: () => setState(
                        () => _filtro = _filtro == 'bajo' ? 'todos' : 'bajo'),
                  ),
                  const SizedBox(width: 8),
                  _KpiChip(
                    label: 'Óptimo',
                    count: optimo.length,
                    color: _kColor,
                    icon: Icons.check_circle_rounded,
                    isActive: _filtro == 'optimo',
                    onTap: () => setState(
                        () => _filtro = _filtro == 'optimo' ? 'todos' : 'optimo'),
                  ),
                ]),
                const SizedBox(height: 20),

                // ── BARRA RESUMEN VISUAL ─────────────────────────
                if (todos.isNotEmpty) ...[
                  _StockSummaryBar(
                      total: todos.length,
                      sinStock: sinStock.length,
                      bajo: bajo.length,
                      optimo: optimo.length),
                  const SizedBox(height: 20),
                ],

                // ── LISTA DE PRODUCTOS ──────────────────────────
                if (lista.isEmpty)
                  _EmptyFiltro(filtro: _filtro)
                else
                  Column(
                    children: lista.map((p) {
                      final estado = _estadoProducto(p);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ProductoStockTile(
                            producto: p, estado: estado),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Barra visual resumen
// ─────────────────────────────────────────────────────────────
class _StockSummaryBar extends StatelessWidget {
  final int total, sinStock, bajo, optimo;
  const _StockSummaryBar({
    required this.total,
    required this.sinStock,
    required this.bajo,
    required this.optimo,
  });

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox.shrink();
    final pctSin  = sinStock / total;
    final pctBajo = bajo     / total;
    final pctOpt  = optimo   / total;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Distribución del catálogo',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600])),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Row(children: [
          if (pctSin  > 0) Expanded(flex: (pctSin  * 100).round(),
              child: Container(height: 12, color: Colors.redAccent)),
          if (pctBajo > 0) Expanded(flex: (pctBajo * 100).round(),
              child: Container(height: 12, color: const Color(0xFFF57F17))),
          if (pctOpt  > 0) Expanded(flex: (pctOpt  * 100).round(),
              child: Container(height: 12, color: _kColor)),
        ]),
      ),
      const SizedBox(height: 8),
      Row(children: [
        _BarLegend(color: Colors.redAccent,         label: 'Sin stock ($sinStock)'),
        const SizedBox(width: 16),
        _BarLegend(color: const Color(0xFFF57F17),  label: 'Stock bajo ($bajo)'),
        const SizedBox(width: 16),
        _BarLegend(color: _kColor,                  label: 'Óptimo ($optimo)'),
      ]),
    ]);
  }
}

class _BarLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _BarLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500)),
      ]);
}

// ─────────────────────────────────────────────────────────────
//  Tile individual de producto
// ─────────────────────────────────────────────────────────────
class _ProductoStockTile extends StatelessWidget {
  final Map<String, dynamic> producto;
  final _EstadoStock estado;

  const _ProductoStockTile({required this.producto, required this.estado});

  Color get _color {
    switch (estado) {
      case _EstadoStock.sinStock: return Colors.redAccent;
      case _EstadoStock.bajo:     return const Color(0xFFF57F17);
      case _EstadoStock.optimo:   return _kColor;
    }
  }

  Color get _bgColor {
    switch (estado) {
      case _EstadoStock.sinStock: return const Color(0xFFFFEBEE);
      case _EstadoStock.bajo:     return const Color(0xFFFFF9C4);
      case _EstadoStock.optimo:   return const Color(0xFFE8F5E9);
    }
  }

  String get _estadoLabel {
    switch (estado) {
      case _EstadoStock.sinStock: return 'Sin stock';
      case _EstadoStock.bajo:     return 'Stock bajo';
      case _EstadoStock.optimo:   return 'Óptimo';
    }
  }

  IconData get _estadoIcon {
    switch (estado) {
      case _EstadoStock.sinStock: return Icons.cancel_rounded;
      case _EstadoStock.bajo:     return Icons.warning_amber_rounded;
      case _EstadoStock.optimo:   return Icons.check_circle_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombre    = (producto['nombre'] ?? producto['name'] ?? 'Sin nombre').toString();
    final categoria = (producto['categoria'] ?? '—').toString();
    final stock     = (producto['stock'] as num?)?.toInt() ?? 0;
    final stockMin  = (producto['stockMinimo'] as num?)?.toInt() ?? 5;
    final precio    = (producto['precio'] ?? producto['precioVenta'] as num?)?.toDouble() ?? 0.0;
    final ratio     = stockMin > 0 ? math.min(1.0, stock / (stockMin * 2.0)) : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Row(children: [
        // Icono estado
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: _color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_estadoIcon, color: _color, size: 22),
        ),
        const SizedBox(width: 14),
        // Info producto
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(nombre,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(categoria,
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          const SizedBox(height: 8),
          // Barra de stock
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(_color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          Text('Stock mín: $stockMin unidades',
              style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        ])),
        const SizedBox(width: 14),
        // Columna derecha
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // Cantidad stock
          Text(
            '$stock',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _color),
          ),
          Text('unidades',
              style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          const SizedBox(height: 6),
          // Badge estado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _color.withOpacity(0.3)),
            ),
            child: Text(_estadoLabel,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _color)),
          ),
          if (precio > 0) ...[
            const SizedBox(height: 4),
            Text(
              '\$ ${NumberFormat('#,##0', 'es_CO').format(precio.round())}',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500),
            ),
          ],
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  KpiChip  (filtro clickeable)
// ─────────────────────────────────────────────────────────────
class _KpiChip extends StatelessWidget {
  final String   label;
  final int      count;
  final Color    color;
  final IconData icon;
  final bool     isActive;
  final VoidCallback onTap;

  const _KpiChip({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isActive ? color : color.withOpacity(0.25),
              width: isActive ? 2 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 14,
              color: isActive ? Colors.white : color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : color)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white.withOpacity(0.25)
                  : color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.white : color)),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────────────────────
enum _EstadoStock { sinStock, bajo, optimo }

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(48),
          child: Center(child: CircularProgressIndicator(color: _kColor)),
        ),
      );
}

class _EmptyFiltro extends StatelessWidget {
  final String filtro;
  const _EmptyFiltro({required this.filtro});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 10),
            Text(
              filtro == 'todos'
                  ? 'No hay productos en catálogo'
                  : 'No hay productos con este estado',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ]),
        ),
      );
}