// lib/pages/devoluciones/devoluciones_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../widgets/notificacion_personalizada.dart';

class DevolucionesPage extends StatefulWidget {
  const DevolucionesPage({super.key});

  @override
  State<DevolucionesPage> createState() => _DevolucionesPageState();
}

class _DevolucionesPageState extends State<DevolucionesPage> {
  static const Color _teal  = Color(0xFF00897B);
  static const Color _orange = Color(0xFFE65100);

  String _filtroResolucion = 'todos'; // todos | reenvio | reembolso
  String _textoBusqueda    = '';
  bool   _searchExpanded   = false;

  final _searchController = TextEditingController();
  final _searchFocus      = FocusNode();
  static final _fmt       = NumberFormat('#,###', 'es_CO');

  late Stream<QuerySnapshot> _devolucionesStream;

  @override
  void initState() {
    super.initState();
    _devolucionesStream = FirebaseFirestore.instance
        .collection('devolucion')
        .orderBy('fechaSolicitud', descending: true)
        .snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  String _fmtVal(double v) => '\$${_fmt.format(v.toInt())}';

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

  bool _coincide(Map<String, dynamic> data) {
    if (_textoBusqueda.isNotEmpty) {
      final numero  = (data['numeroPedido'] ?? '').toString().toLowerCase();
      final cliente = (data['nombreCliente'] ?? '').toString().toLowerCase();
      final q       = _textoBusqueda.toLowerCase();
      if (!numero.contains(q) && !cliente.contains(q)) return false;
    }
    if (_filtroResolucion != 'todos') {
      if ((data['resolucion'] ?? '') != _filtroResolucion) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[100],
      child: Column(
        children: [
          // ── Header ─────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_searchExpanded)
                  _SearchBarDev(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    onChanged: (v) => setState(() => _textoBusqueda = v),
                    onClose: _toggleSearch,
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Devoluciones',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      _IconBtn(icon: Icons.search, onTap: _toggleSearch, active: false, tooltip: 'Buscar devolución'),
                    ],
                  ),
                const SizedBox(height: 14),

                // ── Filtros ──────────────────────────────────────
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FiltroChip(
                        label: 'Todos',
                        activo: _filtroResolucion == 'todos',
                        color: Colors.grey,
                        onTap: () => setState(() => _filtroResolucion = 'todos'),
                      ),
                      const SizedBox(width: 8),
                      _FiltroChip(
                        label: 'Reenvíos',
                        activo: _filtroResolucion == 'reenvio',
                        color: Colors.orange,
                        onTap: () => setState(() => _filtroResolucion = 'reenvio'),
                      ),
                      const SizedBox(width: 8),
                      _FiltroChip(
                        label: 'Reembolsos',
                        activo: _filtroResolucion == 'reembolso',
                        color: Colors.blue,
                        onTap: () => setState(() => _filtroResolucion = 'reembolso'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Lista de devoluciones ───────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _devolucionesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs.where((d) {
                  return _coincide(d.data() as Map<String, dynamic>);
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_return_outlined,
                            size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text('No hay devoluciones',
                            style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                      ],
                    ),
                  );
                }

                // ── KPIs rápidos ─────────────────────────────────
                final totalReenvios  = docs.where((d) =>
                    (d.data() as Map<String, dynamic>)['resolucion'] == 'reenvio').length;
                final totalReembolsos = docs.where((d) =>
                    (d.data() as Map<String, dynamic>)['resolucion'] == 'reembolso').length;

                return Column(
                  children: [
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Row(
                        children: [
                          _KpiChip(label: 'Total',      value: '${docs.length}',   color: Colors.grey),
                          const SizedBox(width: 12),
                          _KpiChip(label: 'Reenvíos',   value: '$totalReenvios',   color: Colors.orange),
                          const SizedBox(width: 12),
                          _KpiChip(label: 'Reembolsos', value: '$totalReembolsos', color: Colors.blue),
                          const Spacer(),
                          if (_filtroResolucion != 'reembolso') ...[
                            _KpiChip(
                              label: 'Monto reenvíos',
                              value: _fmtVal(docs.fold<double>(0, (s, d) {
                                final data = d.data() as Map<String, dynamic>;
                                if (data['resolucion'] != 'reenvio') return s;
                                return s + ((data['montoDevolucion'] as num?)?.toDouble() ?? 0);
                              })),
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (_filtroResolucion != 'reenvio')
                            _KpiChip(
                              label: 'Monto reembolsos',
                              value: _fmtVal(docs.fold<double>(0, (s, d) {
                                final data = d.data() as Map<String, dynamic>;
                                if (data['resolucion'] != 'reembolso') return s;
                                return s + ((data['montoDevolucion'] as num?)?.toDouble() ?? 0);
                              })),
                              color: Colors.blue,
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    // ── Cards ──────────────────────────────────────
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: docs.length,
                        itemBuilder: (context, i) {
                          final doc  = docs[i];
                          final data = doc.data() as Map<String, dynamic>;
                          return _DevolucionCard(
                            docId:  doc.id,
                            data:   data,
                            fmtVal: _fmtVal,
                          );
                        },
                      ),
                    ),
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

// ── Card de una devolución ────────────────────────────────────
class _DevolucionCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final String Function(double) fmtVal;

  const _DevolucionCard({
    required this.docId,
    required this.data,
    required this.fmtVal,
  });

  static final _fmt = NumberFormat('#,###', 'es_CO');

  String _formatearFecha(dynamic ts) {
    if (ts == null || ts is! Timestamp) return '—';
    return DateFormat('dd/MM/yyyy HH:mm').format(ts.toDate());
  }

  @override
  Widget build(BuildContext context) {
    final resolucion    = data['resolucion']?.toString()    ?? '';
    final numeroPedido  = data['numeroPedido']?.toString()  ?? '';
    final cliente       = data['nombreCliente']?.toString() ?? '';
    final telefono      = data['telefonoCliente']?.toString() ?? '';
    final monto         = (data['montoDevolucion'] as num?)?.toDouble() ?? 0;
    final fecha         = _formatearFecha(data['fechaSolicitud']);
    final notasAdmin    = data['notasAdmin']?.toString() ?? '';
    final productos     = (data['productosDevueltos'] as List<dynamic>?) ?? [];

    final esReenvio   = resolucion == 'reenvio';

    final colorRes  = esReenvio ? Colors.orange : Colors.blue;
    final labelRes  = esReenvio ? 'Reenvío' : 'Reembolso';
    final iconoRes  = esReenvio ? Icons.replay_outlined : Icons.currency_exchange;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: colorRes.withOpacity(0.15),
          child: Icon(iconoRes, color: colorRes, size: 20),
        ),
        title: Text(numeroPedido,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$cliente  •  $fecha'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: colorRes.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: colorRes.withOpacity(0.4)),
          ),
          child: Text(labelRes,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold, color: colorRes)),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info cliente
                _InfoRow(icon: Icons.person,  label: 'Cliente',  value: cliente),
                const SizedBox(height: 6),
                _InfoRow(icon: Icons.phone,   label: 'Teléfono', value: telefono),
                const SizedBox(height: 6),
                _InfoRow(icon: Icons.receipt, label: 'Pedido',   value: numeroPedido),

                const Divider(height: 24),

                // Productos devueltos
                const Text('Productos devueltos',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                ...productos.map((p) {
                  final prod     = p as Map<String, dynamic>;
                  final nombre   = prod['nombre']?.toString()   ?? '';
                  final cant     = (prod['cantidad'] as num?)?.toInt() ?? 0;
                  final precio   = (prod['precio']   as num?)?.toDouble() ?? 0;
                  final motivo   = prod['motivo']?.toString()   ?? '';
                  final reponer  = prod['reponerStock'] == true;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('${cant}x',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[800])),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nombre,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                          Text('${fmtVal(precio)} c/u  •  Motivo: $motivo',
                              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        ],
                      )),
                      if (reponer)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.teal[50],
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.teal[200]!),
                          ),
                          child: Text('Stock repuesto',
                              style: TextStyle(fontSize: 10,
                                  color: Colors.teal[700], fontWeight: FontWeight.w600)),
                        ),
                    ]),
                  );
                }),

                const Divider(height: 24),

                // Monto devolución
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Monto devolución',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  Text(fmtVal(monto),
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorRes)),
                ]),

                // Notas admin
                if (notasAdmin.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(children: [
                      Icon(Icons.notes, size: 16, color: Colors.grey[500]),
                      const SizedBox(width: 8),
                      Expanded(child: Text(notasAdmin,
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]))),
                    ]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 16, color: Colors.grey[500]),
      const SizedBox(width: 8),
      SizedBox(width: 70,
          child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
      Expanded(child: Text(value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
    ]);
  }
}

class _FiltroChip extends StatelessWidget {
  final String label;
  final bool activo;
  final Color color;
  final VoidCallback onTap;
  const _FiltroChip({required this.label, required this.activo,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: activo ? color.withOpacity(0.12) : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: activo ? color : Colors.grey[300]!,
              width: activo ? 1.5 : 1),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: activo ? FontWeight.bold : FontWeight.normal,
                color: activo ? color : Colors.grey[600])),
      ),
    );
  }
}

class _KpiChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _KpiChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(children: [
        Text(value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style: TextStyle(fontSize: 10, color: color.withOpacity(0.8))),
      ]),
    );
  }
}

class _SearchBarDev extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;
  const _SearchBarDev({required this.controller, required this.focusNode,
      required this.onChanged, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0xFF00897B), width: 2),
      ),
      child: Row(children: [
        Tooltip(
          message: 'Cerrar búsqueda',
          child: GestureDetector(
            onTap: onClose,
            child: const SizedBox(width: 42, height: 42,
                child: Icon(Icons.close, color: Color(0xFF00897B), size: 20)),
          ),
        ),
        Expanded(child: TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          decoration: const InputDecoration(
            hintText: 'Buscar por pedido o cliente...',
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.only(right: 12),
          ),
          style: const TextStyle(fontSize: 14),
        )),
      ]),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final String? tooltip;
  const _IconBtn({required this.icon, required this.onTap, required this.active, this.tooltip});

  @override
  Widget build(BuildContext context) {
    Widget child = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(21),
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF00897B).withOpacity(0.08),
          borderRadius: BorderRadius.circular(21),
        ),
        child: Icon(icon, color: const Color(0xFF00897B), size: 20),
      ),
    );
    if (tooltip != null) return Tooltip(message: tooltip!, child: child);
    return child;
  }
}