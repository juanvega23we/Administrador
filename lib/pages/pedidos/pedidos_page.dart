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
  String?   _filtroEspecial; // 'reembolso' | 'cancelado' | 'reenvio'

  final TextEditingController _searchController = TextEditingController();
  final FocusNode             _searchFocus      = FocusNode();

  late Stream<QuerySnapshot> _pedidosStream;

  static const Color _teal = Color(0xFF00897B);

  @override
  void initState() {
    super.initState();
    _pedidosStream = _getPedidosStream();
  }

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
        _pedidosStream = _getPedidosStream();
      });
    }
  }

  void _limpiarFiltros() {
    setState(() {
      _fechaInicio    = null;
      _fechaFin       = null;
      _textoBusqueda  = '';
      _filtroEspecial = null;
      _searchController.clear();
      _pedidosStream = _getPedidosStream();
    });
  }

  bool get _hayFiltrosActivos =>
      _fechaInicio    != null ||
      _fechaFin       != null ||
      _textoBusqueda.isNotEmpty ||
      _filtroEspecial != null;

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
    // ── Filtro especial ──────────────────────────────────────
    if (_filtroEspecial != null) {
      switch (_filtroEspecial) {
        case 'reembolso':
          // Pedidos con devolución y resolución reembolso
          if (data['ultimaDevolucionRes'] != 'reembolso') return false;
          break;
        case 'cancelado':
          // Todos los pedidos cancelados
          if (data['estado'] != 'cancelado') return false;
          break;
        case 'reenvio':
          // Pedidos con devolución y resolución reenvío
          if (data['ultimaDevolucionRes'] != 'reenvio') return false;
          break;
      }
    }
    return true;
  }

  Stream<QuerySnapshot> _getPedidosStream() {
    // Límite de 150 pedidos — suficiente para operación diaria
    // El filtro de fecha reduce esto aún más cuando está activo
    const limite = 150;

    if (_filtroEstado != 'todos') {
      return FirebaseFirestore.instance
          .collection('pedido')
          .where('estado', isEqualTo: _filtroEstado)
          .orderBy('fechaPedido', descending: true)
          .limit(limite)
          .snapshots();
    }

    if (_fechaInicio != null) {
      return FirebaseFirestore.instance
          .collection('pedido')
          .where('fechaPedido',
              isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(
                  _fechaInicio!.year, _fechaInicio!.month, _fechaInicio!.day)))
          .orderBy('fechaPedido', descending: true)
          .limit(limite)
          .snapshots();
    }

    return FirebaseFirestore.instance
        .collection('pedido')
        .orderBy('fechaPedido', descending: true)
        .limit(limite)
        .snapshots();
  }

  // ── Descontar stock ──────────────────────────────────────────
  Future<void> _descontarStock(String docId, Map<String, dynamic> pedido) async {
    try {
      final idPedidoBusqueda = _resolverIdPedido(docId, pedido);

      QuerySnapshot detallesSnap = await FirebaseFirestore.instance
          .collection('detalle_pedido')
          .where('idPedido', isEqualTo: idPedidoBusqueda)
          .get();

      if (detallesSnap.docs.isEmpty) {
        final numeroPedido = pedido['numeroPedido']?.toString() ?? '';
        if (numeroPedido.isNotEmpty && numeroPedido != idPedidoBusqueda) {
          detallesSnap = await FirebaseFirestore.instance
              .collection('detalle_pedido')
              .where('idPedido', isEqualTo: numeroPedido)
              .get();
        }
      }

      List<Map<String, dynamic>> items = [];
      if (detallesSnap.docs.isNotEmpty) {
        items = detallesSnap.docs.map((d) => d.data() as Map<String, dynamic>).toList();
      } else {
        final itemsArray = pedido['items'] as List<dynamic>? ?? [];
        items = itemsArray.whereType<Map<String, dynamic>>().toList();
      }

      if (items.isEmpty) return;

      for (final item in items) {
        if (item['omitido']     == true) continue;
        if (item['yaEntregado'] == true) continue;
        if (item['devuelto']    == true) continue;
        final idProducto = (item['idProducto'] ?? item['id'])?.toString();
        if (idProducto == null || idProducto.isEmpty) continue;
        final cantidad = (item['cantidad'] as num?)?.toInt() ?? 0;
        if (cantidad <= 0) continue;

        await FirebaseFirestore.instance
            .collection('productos')
            .doc(idProducto)
            .update({'stock': FieldValue.increment(-cantidad)});
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

  // ── Marcar cantidadReenviada cuando un reenvío queda entregado ──
  Future<void> _marcarReenviados(String docId, Map<String, dynamic> pedido) async {
    try {
      // Solo aplica si este pedido era un reenvío (esReenvio == true)
      if (pedido['esReenvio'] != true) return;

      final idPedidoBusqueda = _resolverIdPedido(docId, pedido);

      final detallesSnap = await FirebaseFirestore.instance
          .collection('detalle_pedido')
          .where('idPedido', isEqualTo: idPedidoBusqueda)
          .get();

      final batch = FirebaseFirestore.instance.batch();

      for (final doc in detallesSnap.docs) {
        final data   = doc.data();
        if (data['yaEntregado'] == true) continue;
        if (data['devuelto']    == true) continue;
        if (data['omitido']     == true) continue;
        final cantidad = (data['cantidad'] as num?)?.toInt() ?? 0;
        if (cantidad <= 0) continue;

        // cantidadReenviada = lo que realmente se debía reenviar
        // = cantidadDevuelta (lo devuelto originalmente), no la cantidad actual
        // que el admin pudo haber cambiado en el sheet de edición
        final cantDevuelta  = (data['cantidadDevuelta']  as num?)?.toInt() ?? 0;
        final cantOriginal  = (data['cantidadOriginal']  as num?)?.toInt() ?? 0;
        // Si tiene cantidadDevuelta guardada, eso es lo reenviado
        // Si no, usar la cantidad actual (producto nuevo del reenvío)
        final cantReenviada = cantDevuelta > 0 ? cantDevuelta : cantidad;

        batch.update(doc.reference, {
          'cantidadReenviada': cantReenviada,
        });
      }

      await batch.commit();
    } catch (e) {
      debugPrint('❌ Error al marcar reenviados: $e');
    }
  }

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

    if (nuevoEstado == 'confirmado') {
      // El stock lo descuenta automáticamente la Cloud Function onPedidoUpdated
      // al detectar el cambio de estado pendiente → confirmado
    }

    double totalFinal = (pedido['total'] as num?)?.toDouble() ?? 0.0;

    if (nuevoEstado == 'entregado') {
      // Si era un reenvío, marcar cantidadReenviada en detalle_pedido
      await _marcarReenviados(docId, pedido);

      // Recalcular total real: suma de todos los productos activos
      // (yaEntregados + nuevos del reenvío), excluyendo devueltos y omitidos
      double totalFinal = 0;
      try {
        final detalleSnap = await FirebaseFirestore.instance
            .collection('detalle_pedido')
            .where('idPedido', isEqualTo: docId)
            .get();
        for (final doc in detalleSnap.docs) {
          final data = doc.data();
          if (data['devuelto']          == true) continue;
          if (data['canceladoDelReenvio'] == true) continue;
          if (data['omitido'] == true &&
              data['yaEntregado'] != true) continue;

          final precio       = (data['precioUnitario']  as num?)?.toDouble() ?? 0;
          final cantDevuelta = (data['cantidadDevuelta'] as num?)?.toInt()   ?? 0;

          if (data['yaEntregado'] == true) {
            final cant = (data['cantidad'] as num?)?.toDouble() ?? 0;
            totalFinal += cant * precio;
          } else if (cantDevuelta > 0) {
            final cantOriginal  = (data['cantidadOriginal']  as num?)?.toDouble() ?? 0;
            final cantReenviada = (data['cantidadReenviada'] as num?)?.toDouble() ?? 0;
            final cantEntregada = cantOriginal - cantDevuelta;
            totalFinal += (cantEntregada + cantReenviada) * precio;
          } else {
            final cant = (data['cantidad'] as num?)?.toDouble() ?? 0;
            totalFinal += cant * precio;
          }
        }

        // Actualizar total en pedido
        await FirebaseFirestore.instance
            .collection('pedido')
            .doc(docId)
            .update({'total': totalFinal});

        // Actualizar también en venta si ya existe
        final ventaSnap = await FirebaseFirestore.instance
            .collection('venta')
            .where('idPedido', isEqualTo: docId)
            .get();
        if (ventaSnap.docs.isNotEmpty) {
          await ventaSnap.docs.first.reference.update({'total': totalFinal});
        }

      } catch (e) {
        debugPrint('❌ Error recalculando total: $e');
      }

      // Crear o actualizar venta
      final ahora    = DateTime.now();
      // Buscar si ya existe venta para este pedido
      final ventaExistente = await FirebaseFirestore.instance
          .collection('venta')
          .where('idPedido', isEqualTo: docId)
          .get();

      if (ventaExistente.docs.isEmpty) {
        // Crear nueva venta
        final ventaRef = FirebaseFirestore.instance.collection('venta').doc();
        await ventaRef.set({
          'idVenta'      : ventaRef.id,
          'idPedido'     : docId,
          'numeroPedido' : pedido['numeroPedido'] ?? '',
          'idCliente'    : pedido['idCliente'] ?? pedido['uid'] ?? '',
          'nombreCliente': _getNombreCliente(pedido),
          'total'        : totalFinal > 0 ? totalFinal : (pedido['total'] ?? 0.0),
          'metodoPago'   : pedido['metodoPago'] ?? 'efectivo',
          'fechaVenta'   : FieldValue.serverTimestamp(),
          'año'          : ahora.year,
          'mes'          : ahora.month,
          'dia'          : ahora.day,
        });
      }
    }

    if (mounted) {
      NotificacionPersonalizada.mostrarSnack(
        context,
        mensaje: nuevoEstado == 'confirmado'
            ? 'Pedido confirmado y stock descontado correctamente'
            : nuevoEstado == 'despachado'
                ? 'Pedido marcado como despachado'
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

  void _mostrarMenuFiltroEspecial(BuildContext context) {
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
              const Text('Filtrar por tipo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _FiltroOpcion(
                icon: Icons.currency_exchange,
                label: 'Reembolsos',
                descripcion: 'Pedidos con devolución y reembolso al cliente',
                color: Colors.blue,
                activo: _filtroEspecial == 'reembolso',
                onTap: () {
                  setState(() => _filtroEspecial =
                      _filtroEspecial == 'reembolso' ? null : 'reembolso');
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 10),
              _FiltroOpcion(
                icon: Icons.cancel_outlined,
                label: 'Cancelados',
                descripcion: 'Todos los pedidos cancelados',
                color: Colors.red,
                activo: _filtroEspecial == 'cancelado',
                onTap: () {
                  setState(() => _filtroEspecial =
                      _filtroEspecial == 'cancelado' ? null : 'cancelado');
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 10),
              _FiltroOpcion(
                icon: Icons.replay_outlined,
                label: 'Reenvíos',
                descripcion: 'Pedidos con devolución y reenvío del producto',
                color: Colors.orange,
                activo: _filtroEspecial == 'reenvio',
                onTap: () {
                  setState(() => _filtroEspecial =
                      _filtroEspecial == 'reenvio' ? null : 'reenvio');
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 16),
              if (_filtroEspecial != null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _filtroEspecial = null);
                      Navigator.pop(ctx);
                    },
                    child: const Text('Quitar filtro'),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
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
                            tooltip: 'Buscar pedido',
                            isActive: false,
                            onTap: _toggleSearch,
                          ),
                          const SizedBox(width: 8),
                          _IconBtn(
                            icon: Icons.calendar_month,
                            tooltip: 'Filtrar por fecha',
                            isActive: _fechaInicio != null || _fechaFin != null,
                            onTap: () => _mostrarMenuFechas(context),
                          ),
                          const SizedBox(width: 8),
                          _IconBtn(
                            icon: Icons.filter_list,
                            tooltip: 'Filtrar por tipo',
                            isActive: _filtroEspecial != null,
                            onTap: () => _mostrarMenuFiltroEspecial(context),
                          ),
                          if (_hayFiltrosActivos) ...[
                            const SizedBox(width: 8),
                            _IconBtn(
                              icon: Icons.filter_alt_off,
                              tooltip: 'Limpiar filtros',
                              isActive: false,
                              color: Colors.red,
                              onTap: _limpiarFiltros,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                if (_filtroEspecial != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.filter_list, size: 14, color: _teal),
                    const SizedBox(width: 6),
                    Text(
                      _filtroEspecial == 'reembolso'
                          ? 'Filtro: Reembolsos'
                          : _filtroEspecial == 'cancelado'
                              ? 'Filtro: Cancelados'
                              : 'Filtro: Reenvíos',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _teal,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ]),
                ],
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
                  onTap: () => setState(() { _filtroEstado = 'todos'; _pedidosStream = _getPedidosStream(); }),
                ),
                const SizedBox(width: 8),
                PedidoEstadoTab(
                  label: 'Pendientes',
                  icon: Icons.hourglass_empty,
                  color: Colors.orange,
                  isSelected: _filtroEstado == 'pendiente',
                  onTap: () => setState(() { _filtroEstado = 'pendiente'; _pedidosStream = _getPedidosStream(); }),
                ),
                const SizedBox(width: 8),
                PedidoEstadoTab(
                  label: 'Confirmados',
                  icon: Icons.check_circle_outline,
                  color: Colors.blue,
                  isSelected: _filtroEstado == 'confirmado',
                  onTap: () => setState(() { _filtroEstado = 'confirmado'; _pedidosStream = _getPedidosStream(); }),
                ),
                const SizedBox(width: 8),
                PedidoEstadoTab(
                  label: 'Despachados',
                  icon: Icons.local_shipping,
                  color: Colors.purple,
                  isSelected: _filtroEstado == 'despachado',
                  onTap: () => setState(() { _filtroEstado = 'despachado'; _pedidosStream = _getPedidosStream(); }),
                ),
                const SizedBox(width: 8),
                PedidoEstadoTab(
                  label: 'Entregados',
                  icon: Icons.done_all,
                  color: Colors.green,
                  isSelected: _filtroEstado == 'entregado',
                  onTap: () => setState(() { _filtroEstado = 'entregado'; _pedidosStream = _getPedidosStream(); }),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _pedidosStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var pedidos = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return _pedidoCoincide(data);
                }).toList();

                if (_filtroEstado != 'todos') {
                  pedidos.sort((a, b) {
                    final dataA = a.data() as Map<String, dynamic>;
                    final dataB = b.data() as Map<String, dynamic>;
                    final tsA = dataA['fechaPedido'];
                    final tsB = dataB['fechaPedido'];
                    if (tsA == null && tsB == null) return 0;
                    if (tsA == null) return 1;
                    if (tsB == null) return -1;
                    return (tsB as Timestamp).compareTo(tsA as Timestamp);
                  });
                }

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
                  cacheExtent: 500,
                  addRepaintBoundaries: true,
                  itemCount: pedidos.length,
                  itemBuilder: (context, index) {
                    final doc  = pedidos[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return PedidoCard(
                      key: ValueKey(doc.id),
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
          Tooltip(
            message: 'Cerrar búsqueda',
            child: GestureDetector(
              onTap: onClose,
              child: const SizedBox(
                width: 42, height: 42,
                child: Icon(Icons.close, color: Color(0xFF00897B), size: 20),
              ),
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
  final String? tooltip;

  const _IconBtn({
    required this.icon,
    required this.isActive,
    this.color = const Color(0xFF00897B),
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    Widget child = InkWell(
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

    if (tooltip != null) {
      child = Tooltip(
        message: tooltip!,
        child: child,
      );
    }

    return child;
  }
}

// ── Widget opción de filtro especial ──────────────────────────
class _FiltroOpcion extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   descripcion;
  final Color    color;
  final bool     activo;
  final VoidCallback onTap;

  const _FiltroOpcion({
    required this.icon,
    required this.label,
    required this.descripcion,
    required this.color,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: activo ? color.withOpacity(0.08) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: activo ? color : Colors.grey[200]!,
            width: activo ? 2 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: activo ? color : Colors.black87,
                  )),
              Text(descripcion,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ],
          )),
          if (activo)
            Icon(Icons.check_circle, color: color, size: 20),
        ]),
      ),
    );
  }
}