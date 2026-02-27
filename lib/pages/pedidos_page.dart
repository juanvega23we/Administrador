import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PedidosPage extends StatefulWidget {
  const PedidosPage({super.key});

  @override
  State<PedidosPage> createState() => _PedidosPageState();
}

class _PedidosPageState extends State<PedidosPage>
    with SingleTickerProviderStateMixin {
  String _filtroEstado = 'todos';
  String _textoBusqueda = '';
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  bool _searchExpanded = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

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
        Future.delayed(const Duration(milliseconds: 150), () {
          _searchFocus.requestFocus();
        });
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
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF00897B),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (esInicio) {
          _fechaInicio = picked;
        } else {
          _fechaFin = picked;
        }
      });
    }
  }

  void _limpiarFiltros() {
    setState(() {
      _fechaInicio = null;
      _fechaFin = null;
      _textoBusqueda = '';
      _searchController.clear();
    });
  }

  /// Extrae un Timestamp seguro — ignora bool, String, null, etc.
  Timestamp? _safeTimestamp(dynamic value) {
    if (value is Timestamp) return value;
    return null;
  }

  bool _pedidoCoincide(Map<String, dynamic> data) {
    // Filtro por texto
    if (_textoBusqueda.isNotEmpty) {
      final numero = (data['numeroPedido'] ?? '').toString().toLowerCase();
      final nombre = _getNombreCliente(data).toLowerCase();
      final query = _textoBusqueda.toLowerCase();
      if (!numero.contains(query) && !nombre.contains(query)) return false;
    }

    // Filtro por fecha — seguro contra tipos inesperados
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

  String _getNombreCliente(Map<String, dynamic> pedido) {
    if (pedido['nombreCliente'] != null) {
      return pedido['nombreCliente'].toString();
    }
    final cliente = pedido['cliente'];
    if (cliente is Map) return cliente['nombre']?.toString() ?? 'N/A';
    return 'N/A';
  }

  bool get _hayFiltrosActivos =>
      _fechaInicio != null || _fechaFin != null || _textoBusqueda.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[100],
      child: Column(
        children: [
          // ── Header ──
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cuando búsqueda expandida: muestra solo la barra full width
                if (_searchExpanded)
                  Row(
                    children: [
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(21),
                            border: Border.all(
                              color: const Color(0xFF00897B),
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: _toggleSearch,
                                child: const SizedBox(
                                  width: 42,
                                  height: 42,
                                  child: Icon(Icons.close,
                                      color: Color(0xFF00897B), size: 20),
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  focusNode: _searchFocus,
                                  onChanged: (v) =>
                                      setState(() => _textoBusqueda = v),
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
                        ),
                      ),
                    ],
                  ),
                // Cuando búsqueda cerrada: muestra título + íconos
                if (!_searchExpanded)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Gestión de Pedidos',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Ícono lupa
                          _IconBtn(
                            icon: Icons.search,
                            isActive: false,
                            onTap: _toggleSearch,
                          ),
                          const SizedBox(width: 8),
                          // Ícono calendario
                          _IconBtn(
                            icon: Icons.calendar_month,
                            isActive: _fechaInicio != null || _fechaFin != null,
                            onTap: () => _mostrarMenuFechas(context),
                          ),
                          // Limpiar filtros
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

                // Indicador de rango de fechas activo
                if (_fechaInicio != null || _fechaFin != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.date_range,
                          size: 14, color: Color(0xFF00897B)),
                      const SizedBox(width: 6),
                      Text(
                        _fechaInicio != null && _fechaFin != null
                            ? 'Del ${DateFormat('dd/MM/yyyy').format(_fechaInicio!)} al ${DateFormat('dd/MM/yyyy').format(_fechaFin!)}'
                            : _fechaInicio != null
                                ? 'Desde ${DateFormat('dd/MM/yyyy').format(_fechaInicio!)}'
                                : 'Hasta ${DateFormat('dd/MM/yyyy').format(_fechaFin!)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF00897B),
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

          // ── Tabs de estado ──
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Row(
              children: [
                _EstadoTab(
                  label: 'Todos',
                  icon: Icons.list_alt,
                  color: const Color(0xFF00897B),
                  isSelected: _filtroEstado == 'todos',
                  onTap: () => setState(() => _filtroEstado = 'todos'),
                ),
                const SizedBox(width: 10),
                _EstadoTab(
                  label: 'Pendientes',
                  icon: Icons.hourglass_empty,
                  color: Colors.orange,
                  isSelected: _filtroEstado == 'pendiente',
                  onTap: () => setState(() => _filtroEstado = 'pendiente'),
                ),
                const SizedBox(width: 10),
                _EstadoTab(
                  label: 'Confirmados',
                  icon: Icons.check_circle_outline,
                  color: Colors.blue,
                  isSelected: _filtroEstado == 'confirmado',
                  onTap: () => setState(() => _filtroEstado = 'confirmado'),
                ),
                const SizedBox(width: 10),
                _EstadoTab(
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

          // ── Lista de pedidos ──
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

                // Ordenar en memoria — seguro contra cualquier tipo
                docs.sort((a, b) {
                  final da = a.data() as Map<String, dynamic>;
                  final db = b.data() as Map<String, dynamic>;
                  final tsA =
                      _safeTimestamp(da['fechaPedido'] ?? da['creadoEn']);
                  final tsB =
                      _safeTimestamp(db['fechaPedido'] ?? db['creadoEn']);
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
                    final doc = pedidos[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _PedidoCard(
                      docId: doc.id,
                      pedido: data,
                      onEstadoChanged: (nuevoEstado) async {
                        await _actualizarEstado(doc.id, data, nuevoEstado);
                      },
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

  void _mostrarMenuFechas(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModal) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Filtrar por fecha',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _FechaPickerTile(
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
                      child: _FechaPickerTile(
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
                          backgroundColor: const Color(0xFF00897B),
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
          );
        });
      },
    );
  }

  Stream<QuerySnapshot> _getPedidosStream() {
    if (_filtroEstado == 'todos') {
      return FirebaseFirestore.instance.collection('pedido').snapshots();
    } else {
      return FirebaseFirestore.instance
          .collection('pedido')
          .where('estado', isEqualTo: _filtroEstado)
          .snapshots();
    }
  }

  Future<void> _actualizarEstado(
    String docId,
    Map<String, dynamic> pedido,
    String nuevoEstado,
  ) async {
    final ref = FirebaseFirestore.instance.collection('pedido').doc(docId);
    await ref.update({
      'estado': nuevoEstado,
      'fechaActualizacion': FieldValue.serverTimestamp(),
    });

    if (nuevoEstado == 'entregado') {
      final ahora = DateTime.now();
      final ventaRef = FirebaseFirestore.instance.collection('venta').doc();
      await ventaRef.set({
        'idVenta': ventaRef.id,
        'idPedido': docId,
        'numeroPedido': pedido['numeroPedido'] ?? '',
        'idCliente': pedido['idCliente'] ?? pedido['uid'] ?? '',
        'nombreCliente': _getNombreCliente(pedido),
        'total': pedido['total'] ?? 0.0,
        'metodoPago': pedido['metodoPago'] ?? 'efectivo',
        'fechaVenta': FieldValue.serverTimestamp(),
        'año': ahora.year,
        'mes': ahora.month,
        'dia': ahora.day,
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Estado actualizado a: $nuevoEstado'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}

// ── Botón ícono circular ──
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
    return Tooltip(
      message: '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isActive ? color.withOpacity(0.12) : color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(21),
            border: Border.all(
              color: isActive ? color : Colors.transparent,
              width: 2,
            ),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

// ── Tile para seleccionar fecha en el modal ──
class _FechaPickerTile extends StatelessWidget {
  final String label;
  final DateTime? fecha;
  final VoidCallback onTap;

  const _FechaPickerTile({
    required this.label,
    required this.fecha,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: fecha != null
              ? const Color(0xFF00897B).withOpacity(0.08)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: fecha != null
                ? const Color(0xFF00897B)
                : Colors.grey[300]!,
            width: fecha != null ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 14,
                    color: fecha != null
                        ? const Color(0xFF00897B)
                        : Colors.grey[500]),
                const SizedBox(width: 6),
                Text(
                  fecha != null
                      ? DateFormat('dd/MM/yyyy').format(fecha!)
                      : 'Seleccionar',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: fecha != null
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: fecha != null
                        ? const Color(0xFF00897B)
                        : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab de estado animado ──
class _EstadoTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _EstadoTab({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3))
                  ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  color: isSelected ? Colors.white : color, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Card de pedido ──
class _PedidoCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> pedido;
  final Function(String) onEstadoChanged;

  const _PedidoCard({
    required this.docId,
    required this.pedido,
    required this.onEstadoChanged,
  });

  String get _nombreCliente {
    if (pedido['nombreCliente'] != null) {
      return pedido['nombreCliente'].toString();
    }
    final c = pedido['cliente'];
    if (c is Map) return c['nombre']?.toString() ?? 'N/A';
    return 'N/A';
  }

  String get _telefono {
    if (pedido['telefonoContacto'] != null) {
      return pedido['telefonoContacto'].toString();
    }
    final c = pedido['cliente'];
    if (c is Map) return c['telefono']?.toString() ?? 'N/A';
    return 'N/A';
  }

  String get _direccion {
    if (pedido['direccionEntrega'] != null) {
      return pedido['direccionEntrega'].toString();
    }
    final d = pedido['direccion'];
    if (d is Map) return '${d['calle'] ?? ''}, ${d['ciudad'] ?? ''}';
    return 'N/A';
  }

  String get _idPedido => pedido['idPedido']?.toString() ?? docId;

  /// Valida stock antes de confirmar y muestra alerta si hay problema
  Future<void> _confirmarConValidacion(BuildContext context) async {
    // Cargar productos del pedido
    final productos = await _cargarProductos();

    if (productos.isEmpty) {
      // Sin detalle de productos → confirmar directamente
      onEstadoChanged('confirmado');
      return;
    }

    // Verificar stock de cada producto
    final List<String> sinStock = [];

    for (final item in productos) {
      final idProducto = item['idProducto'] ?? item['id'];
      if (idProducto == null) continue;

      final cantidad = (item['cantidad'] as num?)?.toInt() ?? 0;

      final productoDoc = await FirebaseFirestore.instance
          .collection('producto')
          .doc(idProducto.toString())
          .get();

      if (!productoDoc.exists) continue;

      final stockActual = (productoDoc.data()?['stock'] as num?)?.toInt() ?? 0;
      final nombre = (item['nombreProducto'] ?? item['nombre'] ?? idProducto).toString();

      if (stockActual < cantidad) {
        sinStock.add('• $nombre (stock: $stockActual, necesita: $cantidad)');
      }
    }

    if (!context.mounted) return;

    if (sinStock.isNotEmpty) {
      // Mostrar alerta de stock insuficiente
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Stock insuficiente'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Los siguientes productos no tienen stock suficiente:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              ...sinStock.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(s,
                        style: const TextStyle(
                            color: Colors.red, fontSize: 13)),
                  )),
              const SizedBox(height: 12),
              const Text(
                '¿Deseas confirmar el pedido de todas formas?',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar igual'),
            ),
          ],
        ),
      );

      if (confirmar == true) {
        onEstadoChanged('confirmado');
      }
    } else {
      // Stock OK → confirmar directamente
      onEstadoChanged('confirmado');
    }
  }

  @override
  Widget build(BuildContext context) {
    final fechaPedido =
        _formatearFecha(pedido['fechaPedido'] ?? pedido['creadoEn']);
    final estado = (pedido['estado'] ?? 'pendiente').toString();
    final total = (pedido['total'] as num?)?.toDouble() ?? 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getColorEstado(estado),
          child: const Icon(Icons.receipt_long, color: Colors.white),
        ),
        title: Text(
          pedido['numeroPedido']?.toString() ?? pedido['idPedido']?.toString() ?? docId,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('$_nombreCliente • $fechaPedido'),
        trailing: Chip(
          label: Text(
            _getNombreEstado(estado),
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12),
          ),
          backgroundColor: _getColorEstado(estado),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                    icon: Icons.person,
                    label: 'Cliente',
                    value: _nombreCliente),
                const SizedBox(height: 8),
                _InfoRow(
                    icon: Icons.phone,
                    label: 'Teléfono',
                    value: _telefono),
                const SizedBox(height: 8),
                _InfoRow(
                    icon: Icons.location_on,
                    label: 'Dirección',
                    value: _direccion),
                const SizedBox(height: 8),
                _InfoRow(
                    icon: Icons.attach_money,
                    label: 'Total',
                    value: 'S/ ${total.toStringAsFixed(2)}'),
                if (pedido['observaciones'] != null &&
                    pedido['observaciones'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                      icon: Icons.note,
                      label: 'Observaciones',
                      value: pedido['observaciones'].toString()),
                ],
                const Divider(height: 32),
                const Text('Productos',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _cargarProductos(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }
                    final productos = snapshot.data!;
                    if (productos.isEmpty) {
                      return Text('Sin detalle de productos',
                          style: TextStyle(color: Colors.grey[500]));
                    }
                    return Column(
                      children: productos.map((p) {
                        final nombre = (p['nombreProducto'] ??
                                p['nombre'] ??
                                'N/A')
                            .toString();
                        final cantidad = p['cantidad'] ?? 0;
                        final subtotal =
                            (p['subtotal'] as num?)?.toDouble() ?? 0.0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.teal[50],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('${cantidad}x',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(nombre)),
                              Text('S/ ${subtotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const Divider(height: 32),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (estado == 'pendiente') ...[
                      ElevatedButton.icon(
                        onPressed: () => _confirmarConValidacion(context),
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Confirmar'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => onEstadoChanged('cancelado'),
                        icon: const Icon(Icons.cancel),
                        label: const Text('Cancelar'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red),
                      ),
                    ],
                    if (estado == 'confirmado')
                      ElevatedButton.icon(
                        onPressed: () => onEstadoChanged('entregado'),
                        icon: const Icon(Icons.done_all),
                        label: const Text('Marcar Entregado'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _cargarProductos() async {
    final detallesSnap = await FirebaseFirestore.instance
        .collection('detalle_pedido')
        .where('idPedido', isEqualTo: _idPedido)
        .get();

    if (detallesSnap.docs.isNotEmpty) {
      return detallesSnap.docs.map((d) => d.data()).toList();
    }

    final itemsArray = pedido['items'] as List<dynamic>? ?? [];
    return itemsArray.whereType<Map<String, dynamic>>().toList();
  }

  String _formatearFecha(dynamic timestamp) {
    if (timestamp == null || timestamp is! Timestamp) return 'Sin fecha';
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate());
    } catch (_) {
      return 'Fecha inválida';
    }
  }

  String _getNombreEstado(String estado) {
    switch (estado) {
      case 'pendiente':
        return 'Pendiente';
      case 'confirmado':
        return 'Confirmado';
      case 'entregado':
        return 'Entregado';
      case 'cancelado':
        return 'Cancelado';
      default:
        return estado;
    }
  }

  Color _getColorEstado(String estado) {
    switch (estado) {
      case 'pendiente':
        return Colors.orange;
      case 'confirmado':
        return Colors.blue;
      case 'entregado':
        return Colors.green;
      case 'cancelado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        SizedBox(
          width: 100,
          child: Text(label,
              style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w500, fontSize: 14)),
        ),
      ],
    );
  }
}