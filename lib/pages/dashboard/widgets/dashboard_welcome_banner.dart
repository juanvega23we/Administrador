// lib/pages/dashboard/widgets/dashboard_welcome_banner.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;

class DashboardWelcomeBanner extends StatefulWidget {
  final String nombreAdmin;
  final String? subtitulo;
  const DashboardWelcomeBanner({
    super.key,
    required this.nombreAdmin,
    this.subtitulo,
  });
  @override
  State<DashboardWelcomeBanner> createState() => _DashboardWelcomeBannerState();
}

class _DashboardWelcomeBannerState extends State<DashboardWelcomeBanner>
    with TickerProviderStateMixin {
  late AnimationController _rotateCtrl;
  late AnimationController _entryCtrl;
  late Animation<double> _entryFade;
  late Animation<double> _entryScale;

  @override
  void initState() {
    super.initState();
    _rotateCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entryScale = Tween<double>(begin: 0.92, end: 1.0).animate(
        CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutBack));
  }

  @override
  void dispose() {
    _rotateCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Buenos días' : hour < 18 ? 'Buenas tardes' : 'Buenas noches';
    final emoji = hour < 12 ? '☀️' : hour < 18 ? '⛅' : '🌙';

    return FadeTransition(
      opacity: _entryFade,
      child: ScaleTransition(
        scale: _entryScale,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0B4D3B), Color(0xFF1A7A57), Color(0xFF0E5C42)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0B4D3B).withOpacity(0.4),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              children: [
                // Anillos decorativos
                AnimatedBuilder(
                  animation: _rotateCtrl,
                  builder: (_, __) => Positioned(
                    right: -60, top: -60,
                    child: Transform.rotate(
                      angle: _rotateCtrl.value * 2 * math.pi,
                      child: Container(
                        width: 260, height: 260,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.06), width: 30),
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _rotateCtrl,
                  builder: (_, __) => Positioned(
                    right: -20, top: -20,
                    child: Transform.rotate(
                      angle: -_rotateCtrl.value * 2 * math.pi * 0.7,
                      child: Container(
                        width: 160, height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08), width: 15),
                        ),
                      ),
                    ),
                  ),
                ),
                // Brillo
                Positioned(
                  right: 40, top: 20,
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        Colors.white.withOpacity(0.12),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                ),
                // Línea inferior
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Colors.transparent,
                        const Color(0xFF4ADE80).withOpacity(0.6),
                        const Color(0xFF22C55E).withOpacity(0.4),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                ),
                // Contenido
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(emoji, style: const TextStyle(fontSize: 20)),
                                const SizedBox(width: 10),
                                Text(
                                  greeting,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: const Color(0xFF4ADE80).withOpacity(0.9),
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.nombreAdmin,
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -1.5,
                                height: 1.1,
                              ),
                            ),
                            // ── Subtítulo (rol) ──
                            if (widget.subtitulo != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                widget.subtitulo!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.65),
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _PulseDot(color: const Color(0xFF4ADE80)),
                                  const SizedBox(width: 7),
                                  const Text(
                                    'Granero del Norte · En línea',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        width: 7, height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withOpacity(0.6 + _c.value * 0.4),
          boxShadow: [BoxShadow(
            color: widget.color.withOpacity(_c.value * 0.6),
            blurRadius: 6, spreadRadius: 1)],
        ),
      ),
    );
  }
}