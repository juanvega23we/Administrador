// lib/pages/reportes/widgets/chart_card.dart
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

const _kColor = Color(0xFF00897B); // antes 0xFF8B0000

class ChartCard extends StatefulWidget {
  final int pendientes, confirmados, entregados, cancelados, total;

  const ChartCard({
    super.key,
    required this.pendientes,
    required this.confirmados,
    required this.entregados,
    required this.cancelados,
    required this.total,
  });

  @override
  State<ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<ChartCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = [
      _Segment('Pendientes', widget.pendientes, Colors.orange),
      _Segment('Confirmados', widget.confirmados, const Color(0xFF1976D2)),
      _Segment('Entregados',  widget.entregados,  _kColor),   // antes 0xFF2E8B57
      _Segment('Cancelados',  widget.cancelados,  Colors.redAccent),
    ];

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              // _SectionHeader inline (igual al original)
              Row(children: [
                const Icon(Icons.donut_large_rounded, size: 18, color: _kColor),
                const SizedBox(width: 8),
                const Text('Distribución de Pedidos',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF004D40))),
              ]),
              const Spacer(),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _isHovered ? _kColor.withOpacity(0.08) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    _isHovered ? Icons.bar_chart_rounded : Icons.donut_large_rounded,
                    size: 14,
                    color: _isHovered ? _kColor : Colors.grey[500],
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _isHovered ? 'Barras' : 'Pastel',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _isHovered ? _kColor : Colors.grey[500]),
                  ),
                ]),
              ),
            ]),
            const SizedBox(height: 4),
            Text('Pasa el cursor sobre el gráfico para ver barras',
                style: TextStyle(fontSize: 11, color: Colors.grey[400])),
            const SizedBox(height: 20),
            MouseRegion(
              onEnter: (_) { setState(() => _isHovered = true);  _ctrl.forward(); },
              onExit:  (_) { setState(() => _isHovered = false); _ctrl.reverse(); },
              child: AnimatedBuilder(
                animation: _anim,
                builder: (ctx, _) => SizedBox(
                  height: 200,
                  child: Stack(children: [
                    Opacity(opacity: 1 - _anim.value,
                        child: _PieChart(data: data, total: widget.total)),
                    Opacity(opacity: _anim.value,
                        child: _BarChart(data: data, total: widget.total)),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16, runSpacing: 8,
              children: data.map((s) {
                final pct = widget.total > 0
                    ? (s.valor / widget.total * 100).toStringAsFixed(1)
                    : '0.0';
                return Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('${s.nombre}  $pct%',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500)),
                ]);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Modelos y painters (igual al original) ────────────────────
class _Segment {
  final String nombre;
  final int    valor;
  final Color  color;
  const _Segment(this.nombre, this.valor, this.color);
}

class _PieChart extends StatelessWidget {
  final List<_Segment> data;
  final int total;
  const _PieChart({required this.data, required this.total});

  @override
  Widget build(BuildContext context) => CustomPaint(
      painter: _PiePainter(data: data, total: total),
      child: const SizedBox.expand());
}

class _PiePainter extends CustomPainter {
  final List<_Segment> data;
  final int total;
  const _PiePainter({required this.data, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    double startAngle = -math.pi / 2;

    for (final seg in data) {
      if (seg.valor == 0) continue;
      final sweep = (seg.valor / total) * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle, sweep - 0.04, false,
        Paint()
          ..color       = seg.color
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 28,
      );
      startAngle += sweep;
    }

    final tp = TextPainter(
      text: TextSpan(children: [
        TextSpan(
            text: '$total\n',
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF004D40), // antes 0xFF2C0A0A
                height: 1.2)),
        TextSpan(
            text: 'pedidos',
            style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500)),
      ]),
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_PiePainter old) =>
      old.total != total || old.data != data;
}

class _BarChart extends StatelessWidget {
  final List<_Segment> data;
  final int total;
  const _BarChart({required this.data, required this.total});

  @override
  Widget build(BuildContext context) {
    final maxVal = data.map((s) => s.valor).fold(0, (a, b) => a > b ? a : b);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: data.map((seg) {
          final ratio = maxVal > 0 ? seg.valor / maxVal : 0.0;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('${seg.valor}',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: seg.color)),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    height: 140 * ratio,
                    decoration: BoxDecoration(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(8)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [seg.color, seg.color.withOpacity(0.65)],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(seg.nombre,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}