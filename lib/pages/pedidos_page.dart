import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PedidosPage extends StatefulWidget {
  const PedidosPage({super.key});

  @override
  State<PedidosPage> createState() => _PedidosPageState();
}

class _PedidosPageState extends State<PedidosPage> {
  String _filtroEstado = 'todos';

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[100],
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Gestión de Pedidos',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Filtros
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'todos', label: Text('Todos')),
                    ButtonSegment(value: 'pendiente', label: Text('Pendientes')),
                    ButtonSegment(value: 'confirmado', label: Text('Confirmados')),
                    ButtonSegment(value: 'entregado', label: Text('Entregados')),
                  ],
                  selected: {_filtroEstado},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() => _filtroEstado = newSelection.first);
                  },
                ),
              ],
            ),
          ),

          // Lista de pedidos
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getPedidosStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final pedidos = snapshot.data!.docs;

                if (pedidos.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No hay pedidos',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: pedidos.length,
                  itemBuilder: (context, index) {
                    final data = pedidos[index].data() as Map<String, dynamic>;
                    return _PedidoCard(
                      pedido: data,
                      onEstadoChanged: (nuevoEstado) async {
                        await _actualizarEstado(data['idPedido'], nuevoEstado);
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

  Stream<QuerySnapshot> _getPedidosStream() {
    Query query = FirebaseFirestore.instance
        .collection('pedido')
        .orderBy('fechaPedido', descending: true);

    if (_filtroEstado != 'todos') {
      query = query.where('estado', isEqualTo: _filtroEstado);
    }

    return query.snapshots();
  }

  Future<void> _actualizarEstado(String idPedido, String nuevoEstado) async {
    await FirebaseFirestore.instance.collection('pedido').doc(idPedido).update({
      'estado': nuevoEstado,
      'fechaActualizacion': FieldValue.serverTimestamp(),
    });

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

class _PedidoCard extends StatelessWidget {
  final Map<String, dynamic> pedido;
  final Function(String) onEstadoChanged;

  const _PedidoCard({
    required this.pedido,
    required this.onEstadoChanged,
  });

  @override
  Widget build(BuildContext context) {
    final fechaPedido = _formatearFecha(pedido['fechaPedido']);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getColorEstado(pedido['estado']),
          child: const Icon(Icons.receipt_long, color: Colors.white),
        ),
        title: Text(
          pedido['numeroPedido'] ?? 'Sin número',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${pedido['nombreCliente']} • $fechaPedido'),
        trailing: Chip(
          label: Text(
            pedido['estado'] ?? 'pendiente',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          backgroundColor: _getColorEstado(pedido['estado']),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Información del cliente
                _InfoRow(
                  icon: Icons.person,
                  label: 'Cliente',
                  value: pedido['nombreCliente'] ?? 'N/A',
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.phone,
                  label: 'Teléfono',
                  value: pedido['telefonoContacto'] ?? 'N/A',
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.location_on,
                  label: 'Dirección',
                  value: pedido['direccionEntrega'] ?? 'N/A',
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.attach_money,
                  label: 'Total',
                  value: '\$${pedido['total']?.toStringAsFixed(0) ?? '0'}',
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.shopping_bag,
                  label: 'Artículos',
                  value: '${pedido['totalArticulos'] ?? 0}',
                ),

                if (pedido['observaciones'] != null &&
                    pedido['observaciones'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.note,
                    label: 'Observaciones',
                    value: pedido['observaciones'],
                  ),
                ],

                const Divider(height: 32),

                // Detalles del pedido
                const Text(
                  'Productos',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),

                FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('detalle_pedido')
                      .where('idPedido', isEqualTo: pedido['idPedido'])
                      .get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const CircularProgressIndicator();
                    }

                    final detalles = snapshot.data!.docs;

                    return Column(
                      children: detalles.map((doc) {
                        final detalle = doc.data() as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.teal[50],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${detalle['cantidad']}x',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(detalle['nombreProducto'] ?? 'N/A'),
                              ),
                              Text(
                                '\$${detalle['subtotal']?.toStringAsFixed(0) ?? '0'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

                const Divider(height: 32),

                // Acciones
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (pedido['estado'] == 'pendiente') ...[
                      ElevatedButton.icon(
                        onPressed: () => onEstadoChanged('confirmado'),
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Confirmar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => onEstadoChanged('cancelado'),
                        icon: const Icon(Icons.cancel),
                        label: const Text('Cancelar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ],
                    if (pedido['estado'] == 'confirmado')
                      ElevatedButton.icon(
                        onPressed: () => onEstadoChanged('preparando'),
                        icon: const Icon(Icons.kitchen),
                        label: const Text('Preparando'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    if (pedido['estado'] == 'preparando')
                      ElevatedButton.icon(
                        onPressed: () => onEstadoChanged('enviado'),
                        icon: const Icon(Icons.local_shipping),
                        label: const Text('Enviar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    if (pedido['estado'] == 'enviado')
                      ElevatedButton.icon(
                        onPressed: () => onEstadoChanged('entregado'),
                        icon: const Icon(Icons.done_all),
                        label: const Text('Marcar Entregado'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
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

  String _formatearFecha(dynamic timestamp) {
    if (timestamp == null) return 'Sin fecha';
    try {
      final fecha = (timestamp as Timestamp).toDate();
      return DateFormat('dd/MM/yyyy HH:mm').format(fecha);
    } catch (e) {
      return 'Fecha inválida';
    }
  }

  Color _getColorEstado(String? estado) {
    switch (estado) {
      case 'pendiente':
        return Colors.orange;
      case 'confirmado':
        return Colors.blue;
      case 'preparando':
        return Colors.purple;
      case 'enviado':
        return Colors.indigo;
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

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}