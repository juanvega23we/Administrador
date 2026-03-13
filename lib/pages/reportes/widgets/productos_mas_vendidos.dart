// lib/pages/reportes/widgets/productos_mas_vendidos.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const _kColor     = Color(0xFF00897B);
const _kColorDark = Color(0xFF004D40);

class ProductosMasVendidos extends StatefulWidget {
  /// Lista ya ordenada mayor→menor por 'cantidad'.
  /// Cada mapa: { 'nombre': String, 'cantidad': int, 'ingresos': double }
  final List<Map<String, dynamic>> productos;

  const ProductosMasVendidos({super.key, required this.productos});

  @override
  State<ProductosMasVendidos> createState() => _ProductosMasVendidosState();
}

class _ProductosMasVendidosState extends State<ProductosMasVendidos>
    with TickerProviderStateMixin {
  late AnimationController _staggeredController;
  final Set<int> _hoveredIndices = {};

  @override
  void initState() {
    super.initState();
    _staggeredController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _staggeredController.forward();
    });
  }

  @override
  void dispose() {
    _staggeredController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxCant = widget.productos.isEmpty
        ? 1
        : widget.productos.map((p) => p['cantidad'] as int).reduce(math.max);

    const medalColors = [
      Color(0xFFFFB300), // oro
      Color(0xFF90A4AE), // plata
      Color(0xFFBF8A67), // bronce
    ];

    final formateador = NumberFormat('#,##0', 'es_CO');

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
            // ── ENCABEZADO DINÁMICO ──────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _kColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.local_fire_department_rounded,
                        color: _kColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Productos Top',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _kColorDark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Más vendidos del período',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (widget.productos.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _kColor.withOpacity(0.15),
                          _kColor.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _kColor.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.trending_up_rounded,
                          color: _kColor,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${widget.productos.length} items',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _kColor,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 28),

            // ── CONTENIDO ────────────────────────────────────────────
            if (widget.productos.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 56,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Sin datos de ventas',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: widget.productos.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final prod = entry.value;
                  final nombre = prod['nombre'] as String;
                  final cantidad = prod['cantidad'] as int;
                  final ingresos = prod['ingresos'] as double;
                  final ratio = maxCant > 0 ? cantidad / maxCant : 0.0;
                  final accent = idx < 3 ? medalColors[idx] : _kColor;

                  // Animación escalonada para cada tarjeta
                  final delay = idx * 80.0;
                  final itemAnimation = Tween<double>(begin: 0, end: 1).animate(
                    CurvedAnimation(
                      parent: _staggeredController,
                      curve: Interval(
                        (delay / 1200).clamp(0.0, 1.0),
                        ((delay + 500) / 1200).clamp(0.0, 1.0),
                        curve: Curves.easeOut,
                      ),
                    ),
                  );

                  return AnimatedBuilder(
                    animation: itemAnimation,
                    builder: (context, _) {
                      final opacity = itemAnimation.value;
                      final translateY = (1 - opacity) * 30;

                      return Transform.translate(
                        offset: Offset(0, translateY),
                        child: Opacity(
                          opacity: opacity,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: MouseRegion(
                              onEnter: (_) =>
                                  setState(() => _hoveredIndices.add(idx)),
                              onExit: (_) =>
                                  setState(() => _hoveredIndices.remove(idx)),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _hoveredIndices.contains(idx)
                                        ? accent
                                        : accent.withOpacity(0.15),
                                    width: _hoveredIndices.contains(idx)
                                        ? 2
                                        : 1,
                                  ),
                                  boxShadow: _hoveredIndices.contains(idx)
                                      ? [
                                          BoxShadow(
                                            color: accent.withOpacity(0.25),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : [],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Stack(
                                    children: [
                                      // Fondo degradado sutil
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              accent.withOpacity(
                                                  _hoveredIndices
                                                      .contains(idx)
                                                  ? 0.08
                                                  : 0.04),
                                              accent.withOpacity(
                                                  _hoveredIndices
                                                      .contains(idx)
                                                  ? 0.03
                                                  : 0.01),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Contenido
                                      Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Fila 1: Posición + Nombre + Cantidad
                                            Row(
                                              children: [
                                                // Posición (Medalla o número)
                                                AnimatedScale(
                                                  scale: _hoveredIndices
                                                      .contains(idx)
                                                      ? 1.12
                                                      : 1.0,
                                                  duration: const Duration(
                                                      milliseconds: 200),
                                                  child: Container(
                                                    width: 36,
                                                    height: 36,
                                                    decoration:
                                                        BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: accent
                                                          .withOpacity(0.2),
                                                      border: Border.all(
                                                        color: accent,
                                                        width: 2,
                                                      ),
                                                      boxShadow: _hoveredIndices
                                                          .contains(idx)
                                                          ? [
                                                              BoxShadow(
                                                                color: accent
                                                                    .withOpacity(
                                                                        0.4),
                                                                blurRadius: 8,
                                                                offset:
                                                                    const Offset(
                                                                        0, 2),
                                                              ),
                                                            ]
                                                          : [],
                                                    ),
                                                    child: Center(
                                                      child: idx < 3
                                                          ? Icon(
                                                              Icons
                                                                  .emoji_events_rounded,
                                                              color: accent,
                                                              size: 20,
                                                            )
                                                          : Text(
                                                              '${idx + 1}',
                                                              style: TextStyle(
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: accent,
                                                              ),
                                                            ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 14),
                                                // Nombre (expandible)
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        nombre,
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: _kColorDark,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      const SizedBox(
                                                          height: 2),
                                                      Text(
                                                        'Vendidas: $cantidad unidades',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors
                                                              .grey[500],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                // Badge cantidad
                                                AnimatedContainer(
                                                  duration: const Duration(
                                                      milliseconds: 200),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 11,
                                                    vertical: 5,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: _hoveredIndices
                                                        .contains(idx)
                                                        ? accent
                                                        : accent.withOpacity(
                                                            0.2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                    border: Border.all(
                                                      color: accent
                                                          .withOpacity(0.4),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    '$cantidad',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: _hoveredIndices
                                                          .contains(idx)
                                                          ? Colors.white
                                                          : accent,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),

                                            // Fila 2: Barra de progreso
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  child: LinearProgressIndicator(
                                                    value: ratio,
                                                    backgroundColor:
                                                        Colors.grey[200],
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                            Color>(accent),
                                                    minHeight: 8,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          Icons
                                                              .trending_up_rounded,
                                                          color: accent,
                                                          size: 16,
                                                        ),
                                                        const SizedBox(
                                                            width: 6),
                                                        Text(
                                                          '\$ ${formateador.format(ingresos.toInt())}',
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold,
                                                            color: accent,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    Text(
                                                      'en ingresos',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors
                                                            .grey[400],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}