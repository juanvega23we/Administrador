// lib/pages/dashboard/widgets/dashboard_pedidos_recientes.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

const _kColor = Color(0xFF00897B);

class DashboardPedidosRecientes extends StatefulWidget {
  final VoidCallback onVerTodos;
  final Color Function(String?) colorEstado;

  const DashboardPedidosRecientes({
    super.key, required this.onVerTodos, required this.colorEstado,
  });

  @override
  State<DashboardPedidosRecientes> createState() => _DashboardPedidosRecientesState();
}

class _DashboardPedidosRecientesState extends State<DashboardPedidosRecientes> {
  late Stream<QuerySnapshot> _pedidosStream;

  @override
  void initState() {
    super.initState();
    _pedidosStream = FirebaseFirestore.instance
        .collection('pedido')
        .orderBy('fechaPedido', descending: true)
        .limit(5)
        .snapshots();
  }

  Timestamp? _safeTs(dynamic v) => v is Timestamp ? v : null;

  String _hora(dynamic ts) {
    if (ts == null) return '';
    try {
      final d = (ts as Timestamp).toDate();
      return '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
    } catch (_) { return ''; }
  }

  IconData _icon(String? e) {
    switch (e) {
      case 'pendiente':  return Icons.schedule_rounded;
      case 'confirmado': return Icons.check_circle_rounded;
      case 'preparando': return Icons.restaurant_rounded;
      case 'enviado':    return Icons.local_shipping_rounded;
      case 'entregado':  return Icons.done_all_rounded;
      case 'cancelado':  return Icons.cancel_rounded;
      default:           return Icons.receipt_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pedidos Recientes',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A2E), letterSpacing: -0.5)),
                    const SizedBox(height: 3),
                    Text('Últimas 5 transacciones',
                      style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                  ],
                ),
                TextButton(
                  onPressed: widget.onVerTodos,
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF667EEA).withOpacity(0.08),
                    foregroundColor: const Color(0xFF667EEA),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Ver todos →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: _pedidosStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator(
                    color: Color(0xFF667EEA), strokeWidth: 2)),
                );
              }
              final docs = snapshot.data!.docs.toList();
              docs.sort((a, b) {
                final da = a.data() as Map<String, dynamic>;
                final db = b.data() as Map<String, dynamic>;
                final tsA = _safeTs(da['fechaPedido'] ?? da['creadoEn']);
                final tsB = _safeTs(db['fechaPedido'] ?? db['creadoEn']);
                if (tsA == null && tsB == null) return 0;
                if (tsA == null) return 1;
                if (tsB == null) return -1;
                return tsB.compareTo(tsA);
              });
              final pedidos = docs.take(5).toList();

              if (pedidos.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(48),
                  child: Center(child: Column(children: [
                    Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text('Sin pedidos recientes', style: TextStyle(color: Colors.grey[400])),
                  ])),
                );
              }

              return Column(
                children: pedidos.asMap().entries.map((e) {
                  final idx    = e.key;
                  final data   = e.value.data() as Map<String, dynamic>;
                  final docId  = e.value.id;
                  final isLast = idx == pedidos.length - 1;
                  final estado = data['estado']?.toString();
                  return _PedidoRow(
                    key: ValueKey(docId),
                    data: data,
                    docId: docId,
                    isLast: isLast,
                    colorEstado: widget.colorEstado(estado),
                    iconEstado: _icon(estado),
                    hora: _hora(data['fechaPedido'] ?? data['creadoEn']),
                    index: idx,
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _PedidoRow extends StatefulWidget {
  final Map<String, dynamic> data;
  final String docId;
  final bool isLast;
  final Color colorEstado;
  final IconData iconEstado;
  final String hora;
  final int index;

  const _PedidoRow({
    super.key,
    required this.data,
    required this.docId,
    required this.isLast,
    required this.colorEstado,
    required this.iconEstado,
    required this.hora,
    required this.index,
  });

  @override
  State<_PedidoRow> createState() => _PedidoRowState();
}

class _PedidoRowState extends State<_PedidoRow> {
  bool _expandido = false;

  List<Map<String, dynamic>> _productos     = [];
  bool                       _cargandoProds = false;
  bool                       _yaCargoProds  = false;

  String get _num {
    final n = widget.data['numeroPedido']?.toString() ?? '';
    if (n.isNotEmpty) return n;
    final id = widget.data['idPedido']?.toString() ?? '';
    if (id.isNotEmpty) return '#${id.substring(0, id.length.clamp(0, 8)).toUpperCase()}';
    return 'SIN-NUM';
  }

  String get _cliente => widget.data['nombreCliente']?.toString() ?? 'Sin nombre';

  String _formatPrecio(double v) => NumberFormat('#,##0', 'es_CO').format(v.toInt());

  Future<void> _cargarProductos() async {
    if (_yaCargoProds) return;
    final idPedido     = widget.docId.isNotEmpty ? widget.docId : (widget.data['idPedido']?.toString() ?? '');
    final numeroPedido = widget.data['numeroPedido']?.toString() ?? '';
    if (idPedido.isEmpty && numeroPedido.isEmpty) {
      setState(() => _yaCargoProds = true);
      return;
    }
    setState(() => _cargandoProds = true);
    try {
      var snap = await FirebaseFirestore.instance
          .collection('detalle_pedido')
          .where('idPedido', isEqualTo: idPedido)
          .get();
      if (snap.docs.isEmpty) {
        final idCampo = widget.data['idPedido']?.toString() ?? '';
        if (idCampo.isNotEmpty && idCampo != idPedido) {
          snap = await FirebaseFirestore.instance
              .collection('detalle_pedido')
              .where('idPedido', isEqualTo: idCampo)
              .get();
        }
      }
      if (snap.docs.isEmpty && numeroPedido.isNotEmpty) {
        snap = await FirebaseFirestore.instance
            .collection('detalle_pedido')
            .where('idPedido', isEqualTo: numeroPedido)
            .get();
      }
      if (mounted) setState(() {
        _productos     = snap.docs.map((d) => d.data()).toList();
        _cargandoProds = false;
        _yaCargoProds  = true;
      });
    } catch (_) {
      if (mounted) setState(() { _cargandoProds = false; _yaCargoProds = true; });
    }
  }

  void _toggleExpandido() {
    setState(() => _expandido = !_expandido);
    if (_expandido) _cargarProductos();
  }

  @override
  Widget build(BuildContext context) {
    final estado = widget.data['estado']?.toString() ?? 'pendiente';
    // Para pedidos con reenvío usar totalPrimeraEntrega + totalReenvio si existen
    final _rawTotal = (widget.data['total'] as num?)?.toDouble() ?? 0.0;
    final _esReenvio = widget.data['esReenvio'] == true;
    final _pEntrega  = (widget.data['totalPrimeraEntrega'] as num?)?.toDouble();
    final _pReenvio  = (widget.data['totalReenvio'] as num?)?.toDouble();
    final total = (_esReenvio && _pEntrega != null && _pReenvio != null)
        ? _pEntrega + _pReenvio
        : _rawTotal;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        // Sin color en hover, solo cuando está expandido
        color: _expandido ? const Color(0xFFF8F9FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: _expandido
            ? Border.all(color: widget.colorEstado.withOpacity(0.2), width: 1)
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Usamos Material + InkWell con todos los efectos en transparent
          // para eliminar CUALQUIER sombra/gris al pasar el cursor
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggleExpandido,
              borderRadius: BorderRadius.circular(16),
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              focusColor: Colors.transparent,
              overlayColor: MaterialStateProperty.all(Colors.transparent),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.colorEstado.withOpacity(0.8),
                            widget.colorEstado,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          _cliente.isNotEmpty ? _cliente[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w800, fontSize: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Nombre + código
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_cliente,
                            style: const TextStyle(fontWeight: FontWeight.w700,
                                fontSize: 14, color: Color(0xFF1A1A2E)),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(_num,
                            style: TextStyle(fontSize: 11, color: Colors.grey[400],
                                letterSpacing: 0.3)),
                        ],
                      ),
                    ),
                    // Hora
                    if (widget.hora.isNotEmpty) ...[
                      Text(widget.hora,
                        style: TextStyle(fontSize: 11, color: Colors.grey[400],
                            fontWeight: FontWeight.w500)),
                      const SizedBox(width: 14),
                    ],
                    // Total + estado
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('\$${_formatPrecio(total)}',
                          style: const TextStyle(fontWeight: FontWeight.w900,
                              fontSize: 15, color: Color(0xFF1A1A2E),
                              letterSpacing: -0.5)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: widget.colorEstado.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(widget.iconEstado, size: 10, color: widget.colorEstado),
                              const SizedBox(width: 4),
                              Text(estado,
                                style: TextStyle(fontSize: 10,
                                    color: widget.colorEstado,
                                    fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    // Chevron
                    Tooltip(
                      message: _expandido ? 'Ocultar detalles' : 'Ver detalles',
                      child: AnimatedRotation(
                        turns: _expandido ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(Icons.keyboard_arrow_down_rounded,
                            size: 20, color: Colors.grey[400]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Panel expandido
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: _expandido ? _buildDetalle() : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildDetalle() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFFE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0F2F1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 3, height: 16,
                decoration: BoxDecoration(
                    color: _kColor, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Text('Productos',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
                    color: Colors.grey[700])),
          ]),
          const SizedBox(height: 10),
          if (_cargandoProds)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(color: _kColor, strokeWidth: 2),
              ),
            )
          else if (_productos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Sin detalles de productos',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            )
          else
            Column(children: _productos.map((p) => _buildProductoRow(p)).toList()),
        ],
      ),
    );
  }

  Widget _buildProductoRow(Map<String, dynamic> prod) {
    final nombre            = (prod['nombreProducto'] ?? prod['nombre'] ?? 'N/A').toString();
    final cantidad          = (prod['cantidad']          as num?)?.toInt()    ?? 0;
    final precioUnitario    = (prod['precioUnitario']    as num?)?.toDouble() ?? 0.0;
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
            // Fila raíz tachada
            _filaProd(cantOriginal, nombre, precioUnitario,
                tachado: true, esUltimoHijo: false, indent: 0),
            // Ya entregado
            if (cantEntregada > 0)
              _filaProd(cantEntregada, nombre, precioUnitario,
                  badgeLabel: 'Ya entregado', badgeColor: Colors.green,
                  esPrimerHijo: true, esUltimoHijo: cantDevuelta == 0, indent: 1),
            // Devuelto
            _filaProd(cantDevuelta, nombre, precioUnitario,
                tachado: true,
                badgeLabel: devLabel, badgeColor: Colors.orange,
                esPrimerHijo: cantEntregada == 0,
                esUltimoHijo: cantReenviada == 0, indent: 1),
            // Reenvío
            if (cantReenviada > 0)
              _filaProd(cantReenviada, nombre, precioUnitario,
                  badgeLabel: 'Reenvío entregado', badgeColor: Colors.teal,
                  esPrimerHijo: true, esUltimoHijo: true, indent: 2),
          ],
        ),
      );
    }

    // ── Vista normal: badge según estado ──────────────────────
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

    return _filaProd(cantidad, nombre, precioUnitario,
        tachado: tachado, badgeLabel: badgeLabel, badgeColor: badgeColor, indent: 0);
  }

  Widget _filaProd(int cantidad, String nombre, double precio, {
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
                  fontWeight: FontWeight.bold, fontSize: 11,
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
                      fontWeight: FontWeight.w600, fontSize: 12,
                      decoration: tachado ? TextDecoration.lineThrough : TextDecoration.none,
                      color: tachado ? Colors.grey[400] : const Color(0xFF1A1A2E),
                    )),
                Text('\$ ${_formatPrecio(precio)} c/u',
                    style: TextStyle(
                      fontSize: 10,
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
            Text('\$ ${_formatPrecio(subtotal)}',
                style: const TextStyle(fontWeight: FontWeight.bold,
                    fontSize: 12, color: _kColor)),
        ],
      ),
    );

    if (indent == 0) return fila;

    // Añadir conector estilo git igual que en pedido_card
    return Padding(
      padding: EdgeInsets.only(left: (indent - 1) * 16.0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 20,
              child: CustomPaint(
                painter: _ConectorPainter(esUltimo: esUltimoHijo),
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

// ── Conector estilo git (igual que en pedido_card.dart) ──────────
class _ConectorPainter extends CustomPainter {
  final bool esUltimo;
  const _ConectorPainter({required this.esUltimo});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[400]!
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;

    canvas.drawLine(
      Offset(cx, 0),
      Offset(cx, esUltimo ? cy : size.height),
      paint,
    );
    canvas.drawLine(Offset(cx, cy), Offset(size.width, cy), paint);
  }

  @override
  bool shouldRepaint(_ConectorPainter old) => old.esUltimo != esUltimo;
}