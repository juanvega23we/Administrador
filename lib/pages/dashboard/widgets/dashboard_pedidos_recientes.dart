// lib/pages/dashboard/widgets/dashboard_pedidos_recientes.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

const _kColor = Color(0xFF00897B);

class DashboardPedidosRecientes extends StatelessWidget {
  final VoidCallback onVerTodos;
  final Color Function(String?) colorEstado;

  const DashboardPedidosRecientes({
    super.key, required this.onVerTodos, required this.colorEstado,
  });

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
          // Header
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
                  onPressed: onVerTodos,
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
          // Lista
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('pedido').limit(20).snapshots(),
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
                  final idx   = e.key;
                  final data  = e.value.data() as Map<String, dynamic>;
                  // ── Pasamos el docId real de Firestore al widget ──
                  final docId = e.value.id;
                  final isLast = idx == pedidos.length - 1;
                  final estado = data['estado']?.toString();
                  return _PedidoRow(
                    data: data,
                    docId: docId,
                    isLast: isLast,
                    colorEstado: colorEstado(estado),
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

// ─────────────────────────────────────────────────────────────────────────────
// Fila expandible con detalle de productos
// ─────────────────────────────────────────────────────────────────────────────
class _PedidoRow extends StatefulWidget {
  final Map<String, dynamic> data;
  final String docId;
  final bool isLast;
  final Color colorEstado;
  final IconData iconEstado;
  final String hora;
  final int index;

  const _PedidoRow({
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

class _PedidoRowState extends State<_PedidoRow> with SingleTickerProviderStateMixin {
  bool _hovered   = false;
  bool _expandido = false;

  // Animación de entrada
  late AnimationController _entryCtrl;
  late Animation<double>   _fade;
  late Animation<double>   _slide;

  // Productos del detalle
  List<Map<String, dynamic>> _productos       = [];
  bool                       _cargandoProds   = false;
  bool                       _yaCargoProds    = false;

  String get _num {
    final n = widget.data['numeroPedido']?.toString() ?? '';
    if (n.isNotEmpty) return n;
    final id = widget.data['idPedido']?.toString() ?? '';
    if (id.isNotEmpty) return '#${id.substring(0, id.length.clamp(0, 8)).toUpperCase()}';
    return 'SIN-NUM';
  }

  String get _cliente => widget.data['nombreCliente']?.toString() ?? 'Sin nombre';

  String _formatPrecio(double v) {
    final f = NumberFormat('#,##0', 'es_CO');
    return f.format(v.toInt());
  }

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _fade  = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slide = Tween<double>(begin: 20, end: 0)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: widget.index * 70), () {
      if (mounted) _entryCtrl.forward();
    });
  }

  @override
  void dispose() { _entryCtrl.dispose(); super.dispose(); }

  Future<void> _cargarProductos() async {
    if (_yaCargoProds) return;

    // Usamos el docId real de Firestore como fuente de verdad
    final idPedido     = widget.docId.isNotEmpty ? widget.docId : (widget.data['idPedido']?.toString() ?? '');
    final numeroPedido = widget.data['numeroPedido']?.toString() ?? '';

    if (idPedido.isEmpty && numeroPedido.isEmpty) {
      setState(() => _yaCargoProds = true);
      return;
    }

    setState(() => _cargandoProds = true);
    try {
      // 1. Buscar por docId real de Firestore
      var snap = await FirebaseFirestore.instance
          .collection('detalle_pedido')
          .where('idPedido', isEqualTo: idPedido)
          .get();

      // 2. Fallback: buscar por el campo idPedido guardado en el documento
      if (snap.docs.isEmpty) {
        final idPedidoCampo = widget.data['idPedido']?.toString() ?? '';
        if (idPedidoCampo.isNotEmpty && idPedidoCampo != idPedido) {
          snap = await FirebaseFirestore.instance
              .collection('detalle_pedido')
              .where('idPedido', isEqualTo: idPedidoCampo)
              .get();
        }
      }

      // 3. Fallback: buscar por numeroPedido
      if (snap.docs.isEmpty && numeroPedido.isNotEmpty) {
        snap = await FirebaseFirestore.instance
            .collection('detalle_pedido')
            .where('idPedido', isEqualTo: numeroPedido)
            .get();
      }

      if (mounted) {
        setState(() {
          _productos     = snap.docs.map((d) => d.data()).toList();
          _cargandoProds = false;
          _yaCargoProds  = true;
        });
      }
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
    final estado   = widget.data['estado']?.toString() ?? 'pendiente';
    final total    = (widget.data['total'] as num?)?.toDouble() ?? 0.0;
    final totalStr = '\$${_formatPrecio(total)}';

    return AnimatedBuilder(
      animation: _entryCtrl,
      builder: (_, child) => Transform.translate(
        offset: Offset(_slide.value, 0),
        child: Opacity(opacity: _fade.value, child: child),
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
          decoration: BoxDecoration(
            color: _hovered || _expandido ? const Color(0xFFF8F9FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: _expandido
                ? Border.all(color: widget.colorEstado.withOpacity(0.2), width: 1)
                : null,
          ),
          child: Column(
            children: [
              // ── Fila principal (clickeable) ──────────────────────────
              InkWell(
                onTap: _toggleExpandido,
                borderRadius: BorderRadius.circular(16),
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
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
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
                          style: TextStyle(fontSize: 11, color: Colors.grey[350],
                              fontWeight: FontWeight.w500)),
                        const SizedBox(width: 14),
                      ],
                      // Total + estado
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(totalStr,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15,
                                color: Color(0xFF1A1A2E), letterSpacing: -0.5)),
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
                                  style: TextStyle(fontSize: 10, color: widget.colorEstado,
                                      fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      // Chevron
                      AnimatedRotation(
                        turns: _expandido ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(Icons.keyboard_arrow_down_rounded,
                            size: 20, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Panel expandido con productos ────────────────────────
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 250),
                crossFadeState: _expandido
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: _buildDetalle(),
              ),
            ],
          ),
        ),
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
            Column(
              children: _productos.map((prod) => _buildProductoRow(prod)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildProductoRow(Map<String, dynamic> prod) {
    final nombre         = (prod['nombreProducto'] ?? prod['nombre'] ?? 'N/A').toString();
    final cantidad       = prod['cantidad'] ?? 0;
    final precioUnitario = (prod['precioUnitario'] as num?)?.toDouble() ?? 0.0;
    final subtotal       = (prod['subtotal'] as num?)?.toDouble() ?? 0.0;
    final omitido        = prod['omitido'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          // Badge cantidad
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: omitido ? Colors.red[50] : Colors.teal[50],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('${cantidad}x',
                style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 11,
                  color: omitido ? Colors.red[300] : Colors.teal[700],
                )),
          ),
          const SizedBox(width: 10),
          // Nombre y precio unitario
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      decoration: omitido ? TextDecoration.lineThrough : TextDecoration.none,
                      decorationColor: omitido ? Colors.grey[700] : null,
                      decorationThickness: omitido ? 2.0 : null,
                      color: omitido ? Colors.grey[700] : const Color(0xFF1A1A2E),
                    )),
                const SizedBox(height: 2),
                Text('\$ ${_formatPrecio(precioUnitario)} c/u',
                    style: TextStyle(
                      fontSize: 10,
                      decoration: omitido ? TextDecoration.lineThrough : TextDecoration.none,
                      decorationColor: omitido ? Colors.grey[600] : null,
                      decorationThickness: omitido ? 2.0 : null,
                      color: omitido ? Colors.grey[600] : Colors.grey[500],
                    )),
              ],
            ),
          ),
          // Subtotal o badge "Sin stock"
          if (omitido)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('Sin stock',
                  style: TextStyle(fontSize: 10, color: Colors.red[700],
                      fontWeight: FontWeight.w700)),
            )
          else
            Text('\$ ${_formatPrecio(subtotal)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 12, color: _kColor)),
        ],
      ),
    );
  }
}