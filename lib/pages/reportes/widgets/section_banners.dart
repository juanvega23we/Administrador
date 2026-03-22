// lib/features/reportes/widgets/section_banners.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const _kColor     = Color(0xFF00897B);
const _kColorDark = Color(0xFF004D40);
const _kBg        = Color(0xFFF0FAF8);

// ═══════════════════════════════════════════════════════════════
// Widget principal: los 3 banners en fila
// ═══════════════════════════════════════════════════════════════
class SectionBanners extends StatelessWidget {
  final List<Map<String, dynamic>> topProductos;
  final bool loadingProds;
  final List<Map<String, dynamic>> pedidos;
  final String Function(double) formatPrecio;
  final int kStockMinDefault;

  const SectionBanners({
    super.key,
    required this.topProductos,
    required this.loadingProds,
    required this.pedidos,
    required this.formatPrecio,
    required this.kStockMinDefault,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _InfoBanner(
            icon: Icons.local_fire_department_rounded,
            iconColor: const Color(0xFFFF7043),
            iconBg: const Color(0xFFFBE9E7),
            title: 'Productos Top',
            subtitle: 'Más vendidos del periodo',
            badge: loadingProds ? '…' : '${topProductos.length} items',
            badgeColor: const Color(0xFFFF7043),
            loading: loadingProds,
            onTap: () => _openModal(
              context,
              title: 'Productos Top',
              icon: Icons.local_fire_department_rounded,
              iconColor: const Color(0xFFFF7043),
              child: _TopProductosDetalle(
                productos: topProductos,
                formatPrecio: formatPrecio,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),

        Expanded(
          child: _StockBannerLoader(
            kStockMinDefault: kStockMinDefault,
            formatPrecio: formatPrecio,
            onTap: (productos) => _openModal(
              context,
              title: 'Stock de Productos',
              icon: Icons.inventory_2_rounded,
              iconColor: _kColor,
              child: _StockDetalle(
                productos: productos,
                kStockMinDefault: kStockMinDefault,
                formatPrecio: formatPrecio,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),

        Expanded(
          child: _InfoBanner(
            icon: Icons.receipt_long_rounded,
            iconColor: _kColor,
            iconBg: const Color(0xFFE0F2F1),
            title: 'Pedidos del Periodo',
            subtitle: '${pedidos.length} pedidos registrados',
            badge: '${pedidos.length}',
            badgeColor: _kColor,
            onTap: () => _openModal(
              context,
              title: 'Pedidos del Periodo',
              icon: Icons.receipt_long_rounded,
              iconColor: _kColor,
              child: _PedidosDetalle(
                pedidos: pedidos,
                formatPrecio: formatPrecio,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openModal(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    showDialog(
      context: context,
      builder: (_) => _ReporteDialog(
        title: title,
        icon: icon,
        iconColor: iconColor,
        child: child,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Banner genérico clicable
// ═══════════════════════════════════════════════════════════════
class _InfoBanner extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final bool loading;
  final VoidCallback onTap;

  const _InfoBanner({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    this.loading = false,
    required this.onTap,
  });

  @override
  State<_InfoBanner> createState() => _InfoBannerState();
}

class _InfoBannerState extends State<_InfoBanner> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hovered ? -3 : 0, 0),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          elevation: _hovered ? 6 : 0,
          shadowColor: widget.badgeColor.withOpacity(0.18),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _hovered
                      ? widget.badgeColor.withOpacity(0.4)
                      : Colors.grey.shade100,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: widget.iconBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(widget.icon, color: widget.iconColor, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: _kColorDark)),
                        const SizedBox(height: 3),
                        Text(widget.subtitle,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.badgeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: widget.loading
                            ? SizedBox(
                                width: 14, height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: widget.badgeColor))
                            : Text(widget.badge,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: widget.badgeColor)),
                      ),
                      const SizedBox(height: 6),
                      Icon(Icons.open_in_new_rounded,
                          size: 15, color: Colors.grey.shade400),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Banner de stock
// FIX: se agrega 'precioProveedor' al mapa del caché para que
//      _StockDetalle pueda calcular Val. inv. proveedor y % Gan.
// ═══════════════════════════════════════════════════════════════
class _StockBannerLoader extends StatefulWidget {
  final int kStockMinDefault;
  final String Function(double) formatPrecio;
  final void Function(List<Map<String, dynamic>>) onTap;

  const _StockBannerLoader({
    required this.kStockMinDefault,
    required this.formatPrecio,
    required this.onTap,
  });

  @override
  State<_StockBannerLoader> createState() => _StockBannerLoaderState();
}

class _StockBannerLoaderState extends State<_StockBannerLoader> {
  // Caché estático: se comparte entre rebuilds del widget
  static List<Map<String, dynamic>>? _cache;
  static bool _cargando = false;

  List<Map<String, dynamic>> get _productos => _cache ?? [];
  int get _sinStock => _productos.where((p) => _esEstado(p, 'sinStock')).length;
  int get _bajos    => _productos.where((p) => _esEstado(p, 'bajo')).length;

  bool _esEstado(Map<String, dynamic> p, String estado) {
    final s = (p['stock'] as num?)?.toInt() ?? 0;
    final m = (p['stockMinimo'] as num?)?.toInt() ?? widget.kStockMinDefault;
    if (estado == 'sinStock') return s <= 0;
    if (estado == 'bajo')     return s > 0 && s <= m;
    return false;
  }

  @override
  void initState() {
    super.initState();
    if (_cache == null && !_cargando) _cargar();
  }

  Future<void> _cargar() async {
    _cargando = true;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('productos')
          .orderBy('nombre')
          .get();

      final lista = snap.docs.map((d) {
        final raw = d.data();
        return {
          'nombre':          (raw['nombre'] ?? raw['name'] ?? '—').toString(),
          'categoria':       (raw['categoria'] ?? '—').toString(),
          'stock':           (raw['stock']       as num?)?.toInt()    ?? 0,
          'stockMinimo':     (raw['stockMinimo'] as num?)?.toInt()    ?? widget.kStockMinDefault,
          'precio':          (raw['precio']      as num?)?.toDouble() ?? 0.0,
          // ── FIX: campo que faltaba ──────────────────────────
          'precioProveedor': (raw['precioProveedor'] as num?)?.toDouble() ?? 0.0,
        };
      }).toList();

      _cache = lista;
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() {});
    } finally {
      _cargando = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cargando   = _cache == null;
    final alertas    = _sinStock + _bajos;
    final badgeColor = _sinStock > 0
        ? Colors.redAccent
        : _bajos > 0
            ? Colors.orange
            : _kColor;

    return _InfoBanner(
      icon: Icons.inventory_2_rounded,
      iconColor: badgeColor,
      iconBg: badgeColor.withOpacity(0.1),
      title: 'Stock de Productos',
      subtitle: cargando
          ? 'Cargando…'
          : alertas > 0
              ? '$alertas producto(s) con alerta'
              : '${_productos.length} productos en catálogo',
      badge: cargando ? '…' : '${_productos.length}',
      badgeColor: badgeColor,
      loading: cargando,
      onTap: () => widget.onTap(_productos),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Dialog contenedor
// ═══════════════════════════════════════════════════════════════
class _ReporteDialog extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  const _ReporteDialog({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Container(
        width: 820,
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 40,
                offset: const Offset(0, 16)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
              decoration: const BoxDecoration(
                color: _kColorDark,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white70),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Detalle: Productos Top
// ═══════════════════════════════════════════════════════════════
class _TopProductosDetalle extends StatelessWidget {
  final List<Map<String, dynamic>> productos;
  final String Function(double) formatPrecio;

  const _TopProductosDetalle(
      {required this.productos, required this.formatPrecio});

  static const List<Color> _colores = [
    Color(0xFFFFC107), Color(0xFF9E9E9E), Color(0xFFCD7F32),
    Color(0xFF00897B), Color(0xFF5C6BC0),
  ];
  static const List<String> _medallas = ['🥇', '🥈', '🥉', '4', '5'];

  @override
  Widget build(BuildContext context) {
    if (productos.isEmpty) {
      return const _EmptyInfo(
          msg: 'No hay productos vendidos en este periodo');
    }
    final maxCant = (productos.first['cantidad'] as int?) ?? 1;

    return Column(
      children: productos.asMap().entries.map((e) {
        final idx      = e.key;
        final p        = e.value;
        final cant     = (p['cantidad'] as int?)    ?? 0;
        final ingresos = (p['ingresos'] as double?) ?? 0.0;
        final color    = _colores[idx % _colores.length];
        final pct      = maxCant > 0 ? cant / maxCant : 0.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: idx == 0 ? color.withOpacity(0.06) : _kBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: idx == 0
                    ? color.withOpacity(0.3)
                    : Colors.grey.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(_medallas[idx],
                      style: TextStyle(
                          fontSize: idx < 3 ? 18 : 13,
                          fontWeight: FontWeight.bold,
                          color: color)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p['nombre']?.toString() ?? '—',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                      const SizedBox(height: 2),
                      Text('Vendidas: $cant unidades',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                Text('\$ ${formatPrecio(ingresos)}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: color)),
                Text('  en ingresos',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade400)),
              ]),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Detalle: Stock
// ═══════════════════════════════════════════════════════════════
class _StockDetalle extends StatelessWidget {
  final List<Map<String, dynamic>> productos;
  final int kStockMinDefault;
  final String Function(double) formatPrecio;

  const _StockDetalle({
    required this.productos,
    required this.kStockMinDefault,
    required this.formatPrecio,
  });

  String _estadoStock(Map p) {
    final s = (p['stock']      as num?)?.toInt() ?? 0;
    final m = (p['stockMinimo'] as num?)?.toInt() ?? kStockMinDefault;
    if (s <= 0) return 'sinStock';
    if (s <= m) return 'bajo';
    return 'optimo';
  }

  @override
  Widget build(BuildContext context) {
    if (productos.isEmpty) {
      return const _EmptyInfo(msg: 'No hay productos en catálogo');
    }

    final sinStock = productos.where((p) => _estadoStock(p) == 'sinStock').length;
    final bajos    = productos.where((p) => _estadoStock(p) == 'bajo').length;
    final ok       = productos.length - sinStock - bajos;

    final valorInv = productos.fold<double>(0.0, (s, p) =>
        s + ((p['stock'] as num?)?.toDouble() ?? 0) *
            ((p['precio'] as num?)?.toDouble() ?? 0));

    final valorInvProveedor = productos.fold<double>(0.0, (s, p) =>
        s + ((p['stock'] as num?)?.toDouble() ?? 0) *
            ((p['precioProveedor'] as num?)?.toDouble() ?? 0));

    final ganancia   = valorInv - valorInvProveedor;
    final pctGanTotal = valorInv > 0
        ? (ganancia / valorInv * 100)
        : 0.0;

    final sorted = List<Map<String, dynamic>>.from(productos)
      ..sort((a, b) {
        int ord(Map p) {
          final e = _estadoStock(p);
          if (e == 'sinStock') return 0;
          if (e == 'bajo')     return 1;
          return 2;
        }
        return ord(a).compareTo(ord(b));
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          _stockKpi('Total',      '${productos.length}', Colors.grey.shade600,    Colors.grey.shade50),
          const SizedBox(width: 10),
          _stockKpi('Óptimo',     '$ok',       _kColor,          const Color(0xFFE0F2F1)),
          const SizedBox(width: 10),
          _stockKpi('Stock bajo', '$bajos',    Colors.orange,    const Color(0xFFFFF8E1)),
          const SizedBox(width: 10),
          _stockKpi('Sin stock',  '$sinStock', Colors.redAccent, const Color(0xFFFFEBEE)),
          const SizedBox(width: 10),
          _stockKpi('Valor inv.', '\$ ${formatPrecio(valorInv)}',
              _kColorDark, const Color(0xFFE0F2F1)),
          const SizedBox(width: 10),
          // ── FIX: ahora muestra el valor real porque precioProveedor ya llega ──
          _stockKpi('Val. inv. proveedor', '\$ ${formatPrecio(valorInvProveedor)}',
              const Color(0xFFE65100), const Color(0xFFFFF8E1)),
          const SizedBox(width: 10),
          _stockKpi('% Gan. total',
              valorInv > 0 ? '${pctGanTotal.toStringAsFixed(1)}%' : '—',
              const Color(0xFF2E7D32), const Color(0xFFE8F5E9)),
        ]),
        const SizedBox(height: 20),
        ...sorted.map((p) {
          final stock    = (p['stock']    as num?)?.toInt()    ?? 0;
          final min      = (p['stockMinimo'] as num?)?.toInt() ?? kStockMinDefault;
          final precio   = (p['precio']   as num?)?.toDouble() ?? 0.0;
          final precioProveedor = (p['precioProveedor'] as num?)?.toDouble() ?? 0.0;
          final est      = _estadoStock(p);

          Color bgColor, borderColor, textColor;
          String estadoTxt;
          IconData estIcon;

          if (est == 'sinStock') {
            bgColor     = const Color(0xFFFFEBEE);
            borderColor = Colors.red.shade200;
            textColor   = Colors.redAccent;
            estadoTxt   = 'Sin stock';
            estIcon     = Icons.cancel_rounded;
          } else if (est == 'bajo') {
            bgColor     = const Color(0xFFFFF8E1);
            borderColor = Colors.orange.shade200;
            textColor   = Colors.orange;
            estadoTxt   = 'Stock bajo';
            estIcon     = Icons.warning_amber_rounded;
          } else {
            bgColor     = Colors.white;
            borderColor = Colors.grey.shade100;
            textColor   = _kColor;
            estadoTxt   = 'Óptimo';
            estIcon     = Icons.check_circle_rounded;
          }

          final pct    = min > 0 ? (stock / (min * 3)).clamp(0.0, 1.0) : 1.0;
          final margen = precio - precioProveedor;
          final pctGan = precio > 0 ? (margen / precio * 100) : 0.0;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(estIcon, color: textColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['nombre'].toString(),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        Text(p['categoria'].toString(),
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  Text('$stock',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textColor)),
                  const SizedBox(width: 4),
                  Text('uds',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade400)),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: textColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(estadoTxt,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: textColor)),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 5,
                        backgroundColor: Colors.grey.shade200,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(textColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('Mín: $min uds',
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey.shade400)),
                  if (precio > 0) ...[
                    const SizedBox(width: 10),
                    Text('\$ ${formatPrecio(precio)}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600)),
                  ],
                  if (precioProveedor > 0) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: const Color(0xFFE65100)
                                .withOpacity(0.3)),
                      ),
                      child: Text(
                          'Prov: \$ ${formatPrecio(precioProveedor)}',
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFE65100))),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: pctGan >= 0
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: (pctGan >= 0
                                    ? Colors.green
                                    : Colors.red)
                                .withOpacity(0.3)),
                      ),
                      child: Text('${pctGan.toStringAsFixed(1)}% gan.',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: pctGan >= 0
                                  ? const Color(0xFF2E7D32)
                                  : Colors.redAccent)),
                    ),
                  ],
                ]),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _stockKpi(
      String label, String value, Color color, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10, color: color.withOpacity(0.8))),
            const SizedBox(height: 3),
            Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Detalle: Pedidos
// ═══════════════════════════════════════════════════════════════
class _PedidosDetalle extends StatelessWidget {
  final List<Map<String, dynamic>> pedidos;
  final String Function(double) formatPrecio;

  const _PedidosDetalle(
      {required this.pedidos, required this.formatPrecio});

  @override
  Widget build(BuildContext context) {
    if (pedidos.isEmpty) {
      return const _EmptyInfo(msg: 'No hay pedidos en este periodo');
    }
    return Column(
      children: pedidos
          .asMap()
          .entries
          .map((e) => _PedidoExpandible(
                pedido: e.value,
                isEven: e.key.isEven,
                formatPrecio: formatPrecio,
              ))
          .toList(),
    );
  }
}

// ── Card expandible de un pedido con lazy load de productos ───
class _PedidoExpandible extends StatefulWidget {
  final Map<String, dynamic> pedido;
  final bool isEven;
  final String Function(double) formatPrecio;

  const _PedidoExpandible({
    required this.pedido,
    required this.isEven,
    required this.formatPrecio,
  });

  @override
  State<_PedidoExpandible> createState() => _PedidoExpandibleState();
}

class _PedidoExpandibleState extends State<_PedidoExpandible> {
  bool _expandido = false;
  bool _cargando  = false;
  List<Map<String, dynamic>> _productos = [];
  bool _cargado = false;

  Future<void> _cargarProductos() async {
    if (_cargado) return;
    final idPedido =
        widget.pedido['idPedido']?.toString() ?? '';
    if (idPedido.isEmpty) {
      setState(() => _cargado = true);
      return;
    }
    setState(() => _cargando = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('detalle_pedido')
          .where('idPedido', isEqualTo: idPedido)
          .get();
      if (mounted) {
        setState(() {
          _productos = snap.docs.map((d) => d.data()).toList();
          _cargando  = false;
          _cargado   = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _cargando = false;
          _cargado  = true;
        });
      }
    }
  }

  Color _colorEstado(String? e) {
    switch (e) {
      case 'pendiente':  return Colors.orange;
      case 'confirmado': return const Color(0xFF1976D2);
      case 'entregado':  return _kColor;
      case 'cancelado':  return Colors.redAccent;
      default:           return Colors.grey;
    }
  }

  String _labelEstado(String? e) {
    switch (e) {
      case 'pendiente':  return 'Pendiente';
      case 'confirmado': return 'Confirmado';
      case 'entregado':  return 'Entregado';
      case 'cancelado':  return 'Cancelado';
      default:           return e ?? '—';
    }
  }

  String _formatFecha(dynamic ts) {
    if (ts == null || ts is! Timestamp) return '—';
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(ts.toDate());
    } catch (_) {
      return '—';
    }
  }

  String get _cliente {
    if (widget.pedido['nombreCliente'] != null)
      return widget.pedido['nombreCliente'].toString();
    final c = widget.pedido['cliente'] as Map<String, dynamic>?;
    return c?['nombre']?.toString() ?? 'Sin nombre';
  }

  String get _codigo =>
      widget.pedido['numeroPedido']?.toString() ??
      widget.pedido['idPedido']?.toString() ??
      '—';

  @override
  Widget build(BuildContext context) {
    final estado = widget.pedido['estado']?.toString() ?? 'pendiente';
    final total  = ((widget.pedido['total'] as num?) ?? 0.0).toDouble();
    final color  = _colorEstado(estado);
    final fecha  = _formatFecha(
        widget.pedido['fechaPedido'] ?? widget.pedido['creadoEn']);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: widget.isEven ? _kBg : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: _expandido
                ? color.withOpacity(0.3)
                : Colors.grey.shade100),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() => _expandido = !_expandido);
              if (_expandido) _cargarProductos();
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              child: Row(children: [
                Container(
                  width: 4, height: 44,
                  decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(width: 12),
                CircleAvatar(
                  radius: 20,
                  backgroundColor: color.withOpacity(0.12),
                  child: Text(
                    _cliente.isNotEmpty
                        ? _cliente[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_cliente,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                      const SizedBox(height: 3),
                      Text(_codigo,
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(fecha,
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400)),
                    ],
                  ),
                ),
                Text('\$ ${widget.formatPrecio(total)}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: _kColor)),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_labelEstado(estado),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: color)),
                ),
                const SizedBox(width: 8),
                Icon(
                  _expandido
                      ? Icons.expand_less
                      : Icons.expand_more,
                  color: Colors.grey.shade400,
                ),
              ]),
            ),
          ),
          if (_expandido) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Productos del pedido',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.grey.shade700)),
                  const SizedBox(height: 10),
                  if (_cargando)
                    const Center(
                        child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: CircularProgressIndicator(
                          color: _kColor, strokeWidth: 2),
                    ))
                  else if (_productos.isEmpty)
                    Text('Sin detalles de productos',
                        style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 12))
                  else
                    ..._productos.map((prod) =>
                        _ProductoArbol(prod: prod, formatPrecio: widget.formatPrecio)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Estado vacío genérico ─────────────────────────────────────
class _EmptyInfo extends StatelessWidget {
  final String msg;
  const _EmptyInfo({required this.msg});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(children: [
            Icon(Icons.inbox_rounded,
                size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(msg,
                style: TextStyle(
                    color: Colors.grey.shade500, fontSize: 14)),
          ]),
        ),
      );
}
// ═══════════════════════════════════════════════════════════════
// Árbol de producto con conectores estilo git (igual que pedido_card)
// ═══════════════════════════════════════════════════════════════
class _ProductoArbol extends StatelessWidget {
  final Map<String, dynamic> prod;
  final String Function(double) formatPrecio;

  const _ProductoArbol({required this.prod, required this.formatPrecio});

  @override
  Widget build(BuildContext context) {
    final nombre            = (prod['nombreProducto'] ?? prod['nombre'] ?? 'N/A').toString();
    final cantidad          = (prod['cantidad']          as num?)?.toInt()    ?? 0;
    final precioUnit        = (prod['precioUnitario']    as num?)?.toDouble() ?? 0.0;
    final omitido           = prod['omitido']           == true;
    final yaEntregado       = prod['yaEntregado']       == true;
    final devuelto          = prod['devuelto']          == true;
    final esProductoReenvio = prod['esProductoReenvio'] == true;
    final cantDevuelta      = (prod['cantidadDevuelta']  as num?)?.toInt() ?? 0;
    final cantReenviada     = (prod['cantidadReenviada'] as num?)?.toInt() ?? 0;
    final cantOriginal      = (prod['cantidadOriginal']  as num?)?.toInt() ?? cantidad;
    final stockRepuesto     = prod['stockRepuesto']     == true;

    // ── Devolución parcial → árbol con conectores ──────────────
    if (cantDevuelta > 0 && !esProductoReenvio) {
      final cantEntregada = cantOriginal - cantDevuelta;
      final stockLabel    = stockRepuesto ? ' • Stock repuesto' : ' • Sin reposición';
      final reenvioLabel  = cantReenviada > 0 ? ' • Se reenviaron' : ' • No reenviado';
      final devLabel      = 'Devuelto$reenvioLabel$stockLabel';

      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fila(cantOriginal, nombre, precioUnit, tachado: true, indent: 0),
            if (cantEntregada > 0)
              _fila(cantEntregada, nombre, precioUnit,
                  badgeLabel: 'Ya entregado', badgeColor: Colors.green,
                  esPrimerHijo: true, esUltimoHijo: cantDevuelta == 0, indent: 1),
            _fila(cantDevuelta, nombre, precioUnit,
                tachado: true,
                badgeLabel: devLabel, badgeColor: Colors.orange,
                esPrimerHijo: cantEntregada == 0, esUltimoHijo: cantReenviada == 0, indent: 1),
            if (cantReenviada > 0)
              _fila(cantReenviada, nombre, precioUnit,
                  badgeLabel: 'Reenvío entregado', badgeColor: Colors.teal,
                  esPrimerHijo: true, esUltimoHijo: true, indent: 2),
          ],
        ),
      );
    }

    // ── Vista normal ───────────────────────────────────────────
    String? badgeLabel;
    MaterialColor? badgeColor;
    bool tachado = false;

    if (omitido && !yaEntregado) {
      badgeLabel = 'Sin stock';         badgeColor = Colors.red;    tachado = true;
    } else if (yaEntregado) {
      badgeLabel = 'Ya entregado';      badgeColor = Colors.green;
    } else if (esProductoReenvio) {
      badgeLabel = 'Reenvío entregado'; badgeColor = Colors.teal;
    } else if (devuelto) {
      badgeLabel = 'Devuelto';          badgeColor = Colors.orange; tachado = true;
    }

    return _fila(cantidad, nombre, precioUnit,
        tachado: tachado, badgeLabel: badgeLabel, badgeColor: badgeColor, indent: 0);
  }

  Widget _fila(int cantidad, String nombre, double precio, {
    bool           tachado      = false,
    String?        badgeLabel,
    MaterialColor? badgeColor,
    int            indent       = 0,
    bool           esPrimerHijo = false,
    bool           esUltimoHijo = true,
  }) {
    final subtotal = precio * cantidad;

    Widget fila = Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: tachado
                  ? (badgeColor?[50]  ?? Colors.grey[100]!)
                  : (badgeColor?[50]  ?? Colors.teal[50]!),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text('${cantidad}x',
                style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 12,
                  color: tachado
                      ? (badgeColor?[300] ?? Colors.grey[400]!)
                      : (badgeColor?[700] ?? Colors.teal[700]!),
                )),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre,
                    style: TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13,
                      decoration: tachado ? TextDecoration.lineThrough : TextDecoration.none,
                      color: tachado ? Colors.grey[400] : Colors.black87,
                    )),
                Text('\$ ${formatPrecio(precio)} c/u',
                    style: TextStyle(
                      fontSize: 11,
                      decoration: tachado ? TextDecoration.lineThrough : TextDecoration.none,
                      color: tachado ? Colors.grey[400] : Colors.grey[500],
                    )),
              ],
            ),
          ),
          if (badgeLabel != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor?[100] ?? Colors.teal[100]!,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: badgeColor?[200] ?? Colors.teal[200]!),
              ),
              child: Text(badgeLabel,
                  style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w700,
                    color: badgeColor?[800] ?? Colors.teal[800]!,
                  )),
            )
          else if (!tachado)
            Text('\$ ${formatPrecio(subtotal)}',
                style: const TextStyle(fontWeight: FontWeight.bold,
                    fontSize: 13, color: _kColor)),
        ],
      ),
    );

    if (indent == 0) return fila;

    return Padding(
      padding: EdgeInsets.only(left: (indent - 1) * 16.0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 20,
              child: CustomPaint(
                painter: _SectionConectorPainter(esUltimo: esUltimoHijo),
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

class _SectionConectorPainter extends CustomPainter {
  final bool esUltimo;
  const _SectionConectorPainter({required this.esUltimo});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[400]!
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.drawLine(Offset(cx, 0), Offset(cx, esUltimo ? cy : size.height), paint);
    canvas.drawLine(Offset(cx, cy), Offset(size.width, cy), paint);
  }

  @override
  bool shouldRepaint(_SectionConectorPainter old) => old.esUltimo != esUltimo;
}