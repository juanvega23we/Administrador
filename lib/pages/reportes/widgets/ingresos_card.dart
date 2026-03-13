// lib/pages/reportes/widgets/ingresos_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const _kColor = Color(0xFF00897B); // antes 0xFF8B0000

class IngresosCard extends StatelessWidget {
  final double ingresos;
  final double ticketPromedio;
  final int    totalPedidos;
  final int    entregados;

  const IngresosCard({
    super.key,
    required this.ingresos,
    required this.ticketPromedio,
    required this.totalPedidos,
    required this.entregados,
  });

  @override
  Widget build(BuildContext context) {
    final tasa = totalPedidos > 0 ? entregados / totalPedidos : 0.0;
    return Card(
      elevation: 0,
      color: _kColor,  // antes 0xFF8B0000 rojo
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.monetization_on_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Ingresos',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 14),
            Text(
              '\$ ${NumberFormat('#,##0', 'es_CO').format(ingresos.round())}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5),
            ),
            const SizedBox(height: 4),
            Text('confirmados + entregados',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.55), fontSize: 11)),
            const SizedBox(height: 20),
            _IngresoDato(
                label: 'Ticket promedio',
                value: '\$ ${ticketPromedio.toStringAsFixed(0)}'),
            const SizedBox(height: 12),
            _IngresoDato(
                label: 'Tasa de entrega',
                value: '${(tasa * 100).toStringAsFixed(1)}%'),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Entregados vs Total',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.6), fontSize: 11)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: tasa,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFB2DFDB)), // verde claro (antes 0xFF90EE90)
                    minHeight: 8,
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

class _IngresoDato extends StatelessWidget {
  final String label, value;
  const _IngresoDato({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.6), fontSize: 12)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ],
      );
}