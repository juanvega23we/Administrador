// lib/widgets/notificacion_personalizada.dart

import 'package:flutter/material.dart';

enum TipoNotificacion { exito, error, advertencia, info, stockAgotado }

class NotificacionPersonalizada {
  // ── GlobalKey compartido — ya registrado en main.dart ────────
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static OverlayState? get _overlay =>
      navigatorKey.currentState?.overlay;

  static void mostrar(
    BuildContext context, {
    required String titulo,
    required String mensaje,
    required TipoNotificacion tipo,
    List<Widget>? acciones,
  }) {
    final config = _getConfig(tipo);
    showDialog(
      context: context,
      barrierDismissible: tipo != TipoNotificacion.stockAgotado,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: config.color.withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [config.color, config.color.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(config.icono, color: Colors.white, size: 36),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      titulo,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      mensaje,
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey[700], height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    if (acciones != null)
                      ...acciones
                    else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: config.color,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text('Entendido',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Toast flotante esquina superior derecha ───────────────────
  static void mostrarSnack(
    BuildContext context, {
    required String mensaje,
    required TipoNotificacion tipo,
  }) {
    final config  = _getConfig(tipo);
    // Usa el overlay del navigatorKey (raíz) para garantizar visibilidad
    final overlay = _overlay ?? Overlay.of(context);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastFlotante(
        mensaje: mensaje,
        config: config,
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }

  static _NotifConfig _getConfig(TipoNotificacion tipo) {
    switch (tipo) {
      case TipoNotificacion.exito:
        return _NotifConfig(
            color: const Color(0xFF00897B),
            icono: Icons.check_circle_rounded);
      case TipoNotificacion.error:
        return _NotifConfig(
            color: const Color(0xFFE53935),
            icono: Icons.cancel_rounded);
      case TipoNotificacion.advertencia:
        return _NotifConfig(
            color: const Color(0xFFF57C00),
            icono: Icons.warning_amber_rounded);
      case TipoNotificacion.info:
        return _NotifConfig(
            color: const Color(0xFF1E88E5),
            icono: Icons.info_rounded);
      case TipoNotificacion.stockAgotado:
        return _NotifConfig(
            color: const Color(0xFFD32F2F),
            icono: Icons.inventory_2_rounded);
    }
  }
}

// ── Widget animado del toast ──────────────────────────────────
class _ToastFlotante extends StatefulWidget {
  final String mensaje;
  final _NotifConfig config;
  final VoidCallback onDismiss;

  const _ToastFlotante({
    required this.mensaje,
    required this.config,
    required this.onDismiss,
  });

  @override
  State<_ToastFlotante> createState() => _ToastFlotanteState();
}

class _ToastFlotanteState extends State<_ToastFlotante>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset>   _slide;
  late Animation<double>   _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slide = Tween<Offset>(
      begin: const Offset(1.2, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 3500), _dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _ctrl.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: GestureDetector(
            onTap: _dismiss,
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 340,
                  minWidth: 260,
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.config.color.withOpacity(0.25),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.config.color.withOpacity(0.18),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: widget.config.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        widget.config.icono,
                        color: widget.config.color,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        widget.mensaje,
                        style: TextStyle(
                          color: Colors.grey[850],
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _dismiss,
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotifConfig {
  final Color    color;
  final IconData icono;
  _NotifConfig({required this.color, required this.icono});
}