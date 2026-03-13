// lib/pages/reportes/widgets/kpi_grid.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const _kColor = Color(0xFF00897B); // antes 0xFF8B0000

class KpiGrid extends StatelessWidget {
  final int    totalPedidos;
  final double ingresos;
  final double ticketPromedio;
  final int    entregados;
  final int    pendientes;
  final int    cancelados;

  const KpiGrid({
    super.key,
    required this.totalPedidos,
    required this.ingresos,
    required this.ticketPromedio,
    required this.entregados,
    required this.pendientes,
    required this.cancelados,
  });

  @override
  Widget build(BuildContext context) {
    String pct(int n) => totalPedidos > 0
        ? '${(n / totalPedidos * 100).toStringAsFixed(1)}% del total'
        : '0% del total';

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        _KpiCard(
            label: 'Total Pedidos',
            value: '$totalPedidos',
            icon: Icons.shopping_cart_rounded,
            accent: const Color(0xFFD35400),
            sub: 'en el período'),
        _KpiCard(
            label: 'Ingresos',
            value: '\$ ${NumberFormat('#,##0', 'es_CO').format(ingresos.round())}',
            icon: Icons.payments_rounded,
            accent: _kColor,
            sub: 'confirmados + entregados'),
        _KpiCard(
            label: 'Ticket Promedio',
            value: '\$ ${NumberFormat('#,##0', 'es_CO').format(ticketPromedio.round())}',
            icon: Icons.trending_up_rounded,
            accent: const Color(0xFF00695C), // antes 0xFF8B0000
            sub: 'por pedido activo'),
        _KpiCard(
            label: 'Entregados',
            value: '$entregados',
            icon: Icons.check_circle_rounded,
            accent: _kColor,
            sub: pct(entregados)),
        _KpiCard(
            label: 'Pendientes',
            value: '$pendientes',
            icon: Icons.hourglass_empty_rounded,
            accent: Colors.orange,
            sub: pct(pendientes)),
        _KpiCard(
            label: 'Cancelados',
            value: '$cancelados',
            icon: Icons.cancel_rounded,
            accent: Colors.redAccent,
            sub: pct(cancelados)),
      ],
    );
  }
}

// ── _KpiCard (mismo diseño original) ─────────────────────────
class _KpiCard extends StatelessWidget {
  final String label, value, sub;
  final IconData icon;
  final Color accent;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: accent.withOpacity(0.15), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
                color: accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: accent,
                      height: 1.1)),
              const SizedBox(height: 2),
              Text(sub,
                  style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          )),
        ]),
      ),
    );
  }
}