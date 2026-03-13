// lib/pages/pedidos/pedidos_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../widgets/notificacion_personalizada.dart';
import '../../../widgets/fecha_picker_tile.dart';
import 'widgets/pedido_card.dart';
import 'widgets/pedido_estado_tab.dart';

class PedidosPage extends StatefulWidget {
  const PedidosPage({super.key});

  @override
  State<PedidosPage> createState() => _PedidosPageState();
}

class _PedidosPageState extends State<PedidosPage> {
  String    _filtroEstado   = 'todos';
  String    _textoBusqueda  = '';
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  bool      _searchExpanded = false;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode             _searchFocus      = FocusNode();

  static const Color _teal = Color(0xFF00897B);

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchExpanded = !_searchExpanded;
      if (_searchExpanded) {
        Future.delayed(const Duration(milliseconds: 150),
            () => _searchFocus.requestFocus());
      } else {
        _searchController.clear();
        _textoBusqueda = '';
        _searchFocus.unfocus();
      }
    });
  }

  Future<void> _seleccionarFecha(BuildContext context, bool esInicio) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: esInicio
          ? (_fechaInicio ?? DateTime.now())
          : (_fechaFin ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _teal,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (esInicio) _fechaInicio = picked;
        else _fechaFin = picked;
      });
    }
  }

  void _limpiarFiltros() {
    setState(() {
      _fechaInicio   = null;
      _fechaFin      = null;
      _textoBusqueda = '';
      _searchController.clear();
    });
  }

  bool get _hayFiltrosActivos =>
      _fechaInicio != null ||
      _fechaFin    != null ||
      _textoBusqueda.isNotEmpty;

  Timestamp? _safeTimestamp(dynamic value) {
    if (value is Timestamp) return value;
    return null;
  }

  String _getNombreCliente(Map<String, dynamic> pedido) {
    if (pedido['nombreCliente'] != null)
      return pedido['nombreCliente'].toString();
    final cliente = pedido['cliente'];
    if (cliente is Map) return cliente['nombre']?.toString() ?? 'N/A';
    return 'N/A';
  }

  bool _pedidoCoincide(Map<String, dynamic> data) {
    if (_textoBusqueda.isNotEmpty) {
      final numero = (data['numeroPedido'] ?? '').toString().toLowerCase();
      final nombre = _getNombreCliente(data).toLowerCase();
      final query  = _textoBusqueda.toLowerCase();
      if (!numero.contains(query) && !nombre.contains(query)) return false;
    }
    if (_fechaInicio != null || _fechaFin != null) {
      final ts = _safeTimestamp(data['fechaPedido'] ?? data['creadoEn']);
      if (ts == null) return false;
      final fecha = ts.toDate();
      if (_fechaInicio != null &&
          fecha.isBefore(DateTime(
              _fechaInicio!.year, _fechaInicio!.month, _fechaInicio!.day))) {
        return false;
      }
      if (_fechaFin != null) {
        final finDia = DateTime(
            _fechaFin!.year, _fechaFin!.month, _fechaFin!.day, 23, 59, 59);
        if (fecha.isAfter(finDia)) return false;
      }
    }
    return true;
  }

  Stream<QuerySnapshot> _getPedidosStream() {
    if (_filtroEstado == 'todos') {
      return FirebaseFirestore.instance.collection('pedido').snapshots();
    }
    return FirebaseFirestore.instance
        .collection('pedido')
        .where('estado', isEqualTo: _filtroEstado)
        .snapshots();
  }

  // ── Descontar stock de los productos del pedido ──────────────
  // Solo descuenta los que NO están marcados como omitido:true
  Future<void> _descontarStock(String docId, Map<String, dynamic> pedido) async {
    try {
      // Buscar detalles del pedido
      final idPedidoBusqueda = _resolverIdPedido(docId, pedido);

      QuerySnapshot detallesSnap = await FirebaseFirestore.instance
          .collection('detalle_pedido')
          .where('idPedido', isEqualTo: idPedidoBusqueda)
          .get();

      // Fallback por numeroPedido
      if (detallesSnap.docs.isEmpty) {
        final numeroPedido = pedido['numeroPedido']?.toString() ?? '';
        if (numeroPedido.isNotEmpty && numeroPedido != idPedidoBusqueda) {
          detallesSnap = await FirebaseFirestore.instance
              .collection('detalle_pedido')
              .where('idPedido', isEqualTo: numeroPedido)
              .get();
        }
      }

      // Fallback por items embebidos
      List<Map<String, dynamic>> items = [];
      if (detallesSnap.docs.isNotEmpty) {
        items = detallesSnap.docs.map((d) => d.data() as Map<String, dynamic>).toList();
      } else {
        final itemsArray = pedido['items'] as List<dynamic>? ?? [];
        items = itemsArray.whereType<Map<String, dynamic>>().toList();
      }

      if (items.isEmpty) return;

      // Descontar stock producto por producto (ignorar omitidos)
      for (final item in items) {
        // Si el producto fue omitido por falta de stock, no descontar
        if (item['omitido'] == true) continue;

        final idProducto = (item['idProducto'] ?? item['id'])?.toString();
        if (idProducto == null || idProducto.isEmpty) continue;

        final cantidad = (item['cantidad'] as num?)?.toInt() ?? 0;
        if (cantidad <= 0) continue;

        await FirebaseFirestore.instance
            .collection('productos')
            .doc(idProducto)
            .update({
          'stock': FieldValue.increment(-cantidad),
        });
      }
    } catch (e) {
      debugPrint('❌ Error al descontar stock: $e');
    }
  }

  String _resolverIdPedido(String docId, Map<String, dynamic> pedido) {
    final idPedido = pedido['idPedido']?.toString() ?? '';
    if (idPedido.isNotEmpty && !idPedido.startsWith('PED-')) return idPedido;
    if (docId.isNotEmpty) return docId;
    return pedido['numeroPedido']?.toString() ?? '';
  }

  // ── Actualizar estado + descontar stock + registrar venta ────
  Future<void> _actualizarEstado(
    String docId,
    Map<String, dynamic> pedido,
    String nuevoEstado,
  ) async {
    await FirebaseFirestore.instance
        .collection('pedido')
        .doc(docId)
        .update({
      'estado': nuevoEstado,
      'fechaActualizacion': FieldValue.serverTimestamp(),
    });

    // ── Al confirmar → descontar stock ───────────────────────
    if (nuevoEstado == 'confirmado') {
      await _descontarStock(docId, pedido);
    }

    // ── Al entregar → registrar como venta ───────────────────
    if (nuevoEstado == 'entregado') {
      final ahora    = DateTime.now();
      final ventaRef = FirebaseFirestore.instance.collection('venta').doc();
      await ventaRef.set({
        'idVenta'      : ventaRef.id,
        'idPedido'     : docId,
        'numeroPedido' : pedido['numeroPedido'] ?? '',
        'idCliente'    : pedido['idCliente'] ?? pedido['uid'] ?? '',
        'nombreCliente': _getNombreCliente(pedido),
        'total'        : pedido['total'] ?? 0.0,
        'metodoPago'   : pedido['metodoPago'] ?? 'efectivo',
        'fechaVenta'   : FieldValue.serverTimestamp(),
        'año'          : ahora.year,
        'mes'          : ahora.month,
        'dia'          : ahora.day,
      });
    }

    if (mounted) {
      NotificacionPersonalizada.mostrarSnack(
        context,
        mensaje: nuevoEstado == 'confirmado'
            ? 'Pedido confirmado y stock descontado correctamente'
            : nuevoEstado == 'entregado'
                ? 'Pedido marcado como entregado y registrado como venta'
                : nuevoEstado == 'cancelado'
                    ? 'Pedido cancelado correctamente'
                    : 'Estado actualizado a: $nuevoEstado',
        tipo: nuevoEstado == 'cancelado'
            ? TipoNotificacion.error
            : TipoNotificacion.exito,
      );
    }
  }

  void _mostrarMenuFechas(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filtrar por fecha',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FechaPickerTile(
                      label: 'Desde',
                      fecha: _fechaInicio,
                      onTap: () async {
                        await _seleccionarFecha(ctx, true);
                        setModal(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FechaPickerTile(
                      label: 'Hasta',
                      fecha: _fechaFin,
                      onTap: () async {
                        await _seleccionarFecha(ctx, false);
                        setModal(() {});
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _limpiarFiltros();
                        Navigator.pop(ctx);
                      },
                      child: const Text('Limpiar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _teal,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Aplicar'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[100],
      child: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_searchExpanded)
                  _SearchBar(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    onChanged: (v) => setState(() => _textoBusqueda = v),
                    onClose: _toggleSearch,
                  ),
                if (!_searchExpanded)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Gestión de Pedidos',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _IconBtn(
                            icon: Icons.search,
                            isActive: false,
                            onTap: _toggleSearch,
                          ),
                          const SizedBox(width: 8),
                          _IconBtn(
                            icon: Icons.calendar_month,
                            isActive: _fechaInicio != null || _fechaFin != null,
                            onTap: () => _mostrarMenuFechas(context),
                          ),
                          if (_hayFiltrosActivos) ...[
                            const SizedBox(width: 8),
                            _IconBtn(
                              icon: Icons.filter_alt_off,
                              isActive: false,
                              color: Colors.red,
                              onTap: _limpiarFiltros,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                if (_fechaInicio != null || _fechaFin != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.date_range, size: 14, color: _teal),
                      const SizedBox(width: 6),
                      Text(
                        _fechaInicio != null && _fechaFin != null
                            ? 'Del ${DateFormat('dd/MM/yyyy').format(_fechaInicio!)} al ${DateFormat('dd/MM/yyyy').format(_fechaFin!)}'
                            : _fechaInicio != null
                                ? 'Desde ${DateFormat('dd/MM/yyyy').format(_fechaInicio!)}'
                                : 'Hasta ${DateFormat('dd/MM/yyyy').format(_fechaFin!)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _teal,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),

          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Row(
              children: [
                PedidoEstadoTab(
                  label: 'Todos',
                  icon: Icons.list_alt,
                  color: _teal,
                  isSelected: _filtroEstado == 'todos',
                  onTap: () => setState(() => _filtroEstado = 'todos'),
                ),
                const SizedBox(width: 10),
                PedidoEstadoTab(
                  label: 'Pendientes',
                  icon: Icons.hourglass_empty,
                  color: Colors.orange,
                  isSelected: _filtroEstado == 'pendiente',
                  onTap: () => setState(() => _filtroEstado = 'pendiente'),
                ),
                const SizedBox(width: 10),
                PedidoEstadoTab(
                  label: 'Confirmados',
                  icon: Icons.check_circle_outline,
                  color: Colors.blue,
                  isSelected: _filtroEstado == 'confirmado',
                  onTap: () => setState(() => _filtroEstado = 'confirmado'),
                ),
                const SizedBox(width: 10),
                PedidoEstadoTab(
                  label: 'Entregados',
                  icon: Icons.done_all,
                  color: Colors.green,
                  isSelected: _filtroEstado == 'entregado',
                  onTap: () => setState(() => _filtroEstado = 'entregado'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getPedidosStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs.toList();
                docs.sort((a, b) {
                  final da  = a.data() as Map<String, dynamic>;
                  final db  = b.data() as Map<String, dynamic>;
                  final tsA = _safeTimestamp(da['fechaPedido'] ?? da['creadoEn']);
                  final tsB = _safeTimestamp(db['fechaPedido'] ?? db['creadoEn']);
                  if (tsA == null && tsB == null) return 0;
                  if (tsA == null) return 1;
                  if (tsB == null) return -1;
                  return tsB.compareTo(tsA);
                });

                final pedidos = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return _pedidoCoincide(data);
                }).toList();

                if (pedidos.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined,
                            size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text('No hay pedidos',
                            style: TextStyle(
                                fontSize: 18, color: Colors.grey[600])),
                        if (_hayFiltrosActivos) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _limpiarFiltros,
                            icon: const Icon(Icons.filter_alt_off),
                            label: const Text('Limpiar filtros'),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: pedidos.length,
                  itemBuilder: (context, index) {
                    final doc  = pedidos[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return PedidoCard(
                      docId: doc.id,
                      pedido: data,
                      onEstadoChanged: (nuevoEstado) =>
                          _actualizarEstado(doc.id, data, nuevoEstado),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 42,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0xFF00897B), width: 2),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onClose,
            child: const SizedBox(
              width: 42, height: 42,
              child: Icon(Icons.close, color: Color(0xFF00897B), size: 20),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              decoration: const InputDecoration(
                hintText: 'Buscar pedido o cliente...',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.only(right: 12),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.isActive,
    this.color = const Color(0xFF00897B),
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(21),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: isActive
              ? color.withOpacity(0.12)
              : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(21),
          border: Border.all(
              color: isActive ? color : Colors.transparent, width: 2),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}