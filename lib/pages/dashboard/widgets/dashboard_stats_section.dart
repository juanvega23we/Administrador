// lib/pages/dashboard/widgets/dashboard_stats_section.dart

import 'package:flutter/material.dart';
import 'dashboard_stat_card.dart';

class DashboardStatsSection extends StatelessWidget {
  final Stream<Map<String, dynamic>> estadisticasStream;
  final String Function(dynamic) formatNum;

  const DashboardStatsSection({
    super.key,
    required this.estadisticasStream,
    required this.formatNum,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado
        const Text(
          'Resumen del día',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 18),

        // Cards
        StreamBuilder<Map<String, dynamic>>(
          stream: estadisticasStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 100,
                child: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF16A34A),
                    strokeWidth: 2,
                  ),
                ),
              );
            }

            final s = snapshot.data!;

            // ── Iconos y colores más naturales, sin gradientes ──
            final cards = [
              _CardData(
                title: 'Pedidos Hoy',
                value: s['pedidosHoy'].toString(),
                icon: Icons.receipt_long_outlined,      // recibo limpio
                accentColor: const Color(0xFF059669),
                trendIcon: Icons.north_east_rounded,
              ),
              _CardData(
                title: 'Ventas Hoy',
                value: '\$${formatNum(s['ventasHoy'])}',
                icon: Icons.attach_money_rounded,        // dinero directo
                accentColor: const Color(0xFF2563EB),
                trendIcon: Icons.north_east_rounded,
              ),
              _CardData(
                title: 'Pendientes',
                value: s['pedidosPendientes'].toString(),
                icon: Icons.schedule_outlined,           // reloj / tiempo
                accentColor: const Color(0xFFD97706),
                trendIcon: Icons.remove_rounded,
              ),
              _CardData(
                title: 'Productos',
                value: s['productosActivos'].toString(),
                icon: Icons.category_outlined,           // categoría/producto
                accentColor: const Color(0xFF7C3AED),
                trendIcon: Icons.north_east_rounded,
              ),
            ];

            return Row(
              children: cards.asMap().entries.map((e) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        right: e.key < cards.length - 1 ? 14 : 0),
                    child: DashboardStatCard(
                      title: e.value.title,
                      value: e.value.value,
                      icon: e.value.icon,
                      accentColor: e.value.accentColor,
                      delay: e.key * 80,
                      trendIcon: e.value.trendIcon,
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

// ── Modelo interno ──────────────────────────────────────────
class _CardData {
  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;
  final IconData trendIcon;

  const _CardData({
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.trendIcon,
  });
}