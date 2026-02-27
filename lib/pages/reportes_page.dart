import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ReportesPage extends StatefulWidget {
  const ReportesPage({super.key});

  @override
  State<ReportesPage> createState() => _ReportesPageState();
}

class _ReportesPageState extends State<ReportesPage> {
  // Filtro por período
  String _periodo = 'mes'; // 'hoy', 'semana', 'mes'

  DateTime get _fechaInicio {
    final ahora = DateTime.now();
    switch (_periodo) {
      case 'hoy':
        return DateTime(ahora.year, ahora.month, ahora.day);
      case 'semana':
        return ahora.subtract(const Duration(days: 7));
      case 'mes':
      default:
        return DateTime(ahora.year, ahora.month, 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[100],
      child: Column(
        children: [
          // Header con filtros
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Reportes',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'hoy', label: Text('Hoy')),
                    ButtonSegment(value: 'semana', label: Text('7 días')),
                    ButtonSegment(value: 'mes', label: Text('Este mes')),
                  ],
                  selected: {_periodo},
                  onSelectionChanged: (s) =>
                      setState(() => _periodo = s.first),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('pedido')
                  .where('fechaPedido',
                      isGreaterThanOrEqualTo:
                          Timestamp.fromDate(_fechaInicio))
                  .orderBy('fechaPedido', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final pedidos = snapshot.data!.docs
                    .map((d) => d.data() as Map<String, dynamic>)
                    .toList();

                // Calcular métricas
                final totalPedidos = pedidos.length;
                final pedidosPendientes =
                    pedidos.where((p) => p['estado'] == 'pendiente').length;
                final pedidosConfirmados =
                    pedidos.where((p) => p['estado'] == 'confirmado').length;
                final pedidosEntregados =
                    pedidos.where((p) => p['estado'] == 'entregado').length;
                final pedidosCancelados =
                    pedidos.where((p) => p['estado'] == 'cancelado').length;

                double totalVentas = pedidos
                    .where((p) =>
                        p['estado'] == 'entregado' ||
                        p['estado'] == 'confirmado')
                    .fold(0.0, (s, p) => s + ((p['total'] as num?) ?? 0.0));

                double ticketPromedio = (totalPedidos - pedidosCancelados) > 0
                    ? totalVentas / (totalPedidos - pedidosCancelados)
                    : 0;

                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    // ── Tarjetas de resumen ──────────────────────────
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.6,
                      children: [
                        _MetricCard(
                          titulo: 'Total Pedidos',
                          valor: '$totalPedidos',
                          icono: Icons.receipt_long,
                          color: Colors.teal,
                        ),
                        _MetricCard(
                          titulo: 'Ingresos',
                          valor: 'S/ ${totalVentas.toStringAsFixed(0)}',
                          icono: Icons.attach_money,
                          color: Colors.green,
                        ),
                        _MetricCard(
                          titulo: 'Ticket Promedio',
                          valor: 'S/ ${ticketPromedio.toStringAsFixed(0)}',
                          icono: Icons.trending_up,
                          color: Colors.blue,
                        ),
                        _MetricCard(
                          titulo: 'Entregados',
                          valor: '$pedidosEntregados',
                          icono: Icons.done_all,
                          color: Colors.green,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Estados ──────────────────────────────────────
                    _SectionTitle('Estado de Pedidos'),
                    const SizedBox(height: 12),
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _EstadoRow('Pendientes', pedidosPendientes,
                                totalPedidos, Colors.orange),
                            _EstadoRow('Confirmados', pedidosConfirmados,
                                totalPedidos, Colors.blue),
                            _EstadoRow('Entregados', pedidosEntregados,
                                totalPedidos, Colors.green),
                            _EstadoRow('Cancelados', pedidosCancelados,
                                totalPedidos, Colors.red),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Lista de pedidos del período ─────────────────
                    _SectionTitle('Pedidos del período'),
                    const SizedBox(height: 12),

                    if (pedidos.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(Icons.bar_chart,
                                  size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                'Sin pedidos en este período',
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...pedidos.map((pedido) => _PedidoReporteCard(pedido: pedido)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Fila de estado con barra de progreso ──────────────────────
class _EstadoRow extends StatelessWidget {
  final String nombre;
  final int cantidad;
  final int total;
  final Color color;

  const _EstadoRow(this.nombre, this.cantidad, this.total, this.color);

  @override
  Widget build(BuildContext context) {
    final porcentaje = total > 0 ? cantidad / total : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: Text(nombre, style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: porcentaje,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$cantidad',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: color, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ── Tarjeta de métrica ────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icono;
  final Color color;

  const _MetricCard({
    required this.titulo,
    required this.valor,
    required this.icono,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  titulo,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icono, color: color, size: 18),
                ),
              ],
            ),
            Text(
              valor,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Título de sección ─────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }
}

// ── Tarjeta individual de pedido en reportes ──────────────────
class _PedidoReporteCard extends StatelessWidget {
  final Map<String, dynamic> pedido;

  const _PedidoReporteCard({required this.pedido});

  String get _nombreCliente {
    if (pedido['nombreCliente'] != null) return pedido['nombreCliente'];
    final c = pedido['cliente'] as Map<String, dynamic>?;
    return c?['nombre'] ?? 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    final estado = pedido['estado'] ?? 'pendiente';
    final total = (pedido['total'] as num?)?.toDouble() ?? 0.0;
    final fecha = _formatearFecha(pedido['fechaPedido'] ?? pedido['creadoEn']);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 40,
              decoration: BoxDecoration(
                color: _getColorEstado(estado),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _nombreCliente,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    fecha,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'S/ ${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getColorEstado(estado).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _getNombreEstado(estado),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _getColorEstado(estado),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatearFecha(dynamic timestamp) {
    if (timestamp == null) return 'Sin fecha';
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format((timestamp as Timestamp).toDate());
    } catch (_) {
      return 'Fecha inválida';
    }
  }

  String _getNombreEstado(String? estado) {
    switch (estado) {
      case 'pendiente': return 'Pendiente';
      case 'confirmado': return 'Confirmado';
      case 'entregado': return 'Entregado';
      case 'cancelado': return 'Cancelado';
      default: return estado ?? '?';
    }
  }

  Color _getColorEstado(String? estado) {
    switch (estado) {
      case 'pendiente': return Colors.orange;
      case 'confirmado': return Colors.blue;
      case 'entregado': return Colors.green;
      case 'cancelado': return Colors.red;
      default: return Colors.grey;
    }
  }
}