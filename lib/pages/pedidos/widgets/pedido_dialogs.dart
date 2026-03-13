// lib/pages/pedidos/widgets/pedido_dialogs.dart

import 'package:flutter/material.dart';

class PedidoDialogs {
  // ── Diálogo: cancelar pedido ────────────────────────────────
  static Future<bool> confirmarCancelar(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: _DialogContainer(
          gradientColors: const [Color(0xFFE53935), Color(0xFFEF5350)],
          icon: Icons.cancel_rounded,
          titulo: 'Cancelar Pedido',
          mensaje:
              '¿Estás seguro de que deseas cancelar este pedido?\n\nEsta acción no se puede deshacer.',
          labelConfirmar: 'Sí, cancelar',
          colorConfirmar: const Color(0xFFE53935),
          labelCancelar: 'No, volver',
          onConfirmar: () => Navigator.pop(ctx, true),
          onCancelar:  () => Navigator.pop(ctx, false),
        ),
      ),
    );
    return result ?? false;
  }

  // ── Diálogo: confirmar entrega ──────────────────────────────
  static Future<bool> confirmarEntrega(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: _DialogContainer(
          gradientColors: const [Color(0xFF2E7D32), Color(0xFF43A047)],
          icon: Icons.done_all_rounded,
          titulo: 'Confirmar Entrega',
          mensaje:
              '¿Confirmas que este pedido fue entregado al cliente?\n\nSe registrará automáticamente como venta.',
          labelConfirmar: 'Sí, entregar',
          colorConfirmar: const Color(0xFF2E7D32),
          labelCancelar: 'Cancelar',
          onConfirmar: () => Navigator.pop(ctx, true),
          onCancelar:  () => Navigator.pop(ctx, false),
        ),
      ),
    );
    return result ?? false;
  }

  // ── Diálogo: confirmar pedido PARCIAL ───────────────────────
  // Se muestra cuando algunos productos no tienen stock pero
  // otros sí. Permite continuar el pedido sin los que faltan.
  static Future<bool?> confirmarParcial(
    BuildContext context, {
    required List<String> productosProblema,
    required int productosOkCount,
  }) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.2),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Cabecera naranja ───────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFE65100), Color(0xFFFFA726)],
                  ),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.white, size: 48),
                    SizedBox(height: 8),
                    Text(
                      'Stock Insuficiente',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Cuerpo ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Descripción
                    Text(
                      'Los siguientes productos no tienen stock suficiente:',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 10),

                    // Lista de productos con problema
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red[100]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: productosProblema
                            .map((nombre) => Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.remove_circle,
                                          color: Colors.red, size: 14),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(nombre,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight:
                                                    FontWeight.w500)),
                                      ),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Productos que sí tienen stock
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green[100]!),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$productosOkCount producto${productosOkCount > 1 ? 's' : ''} '
                              'sí ${productosOkCount > 1 ? 'tienen' : 'tiene'} stock disponible.',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.green[800]),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      '¿Deseas confirmar el pedido con los productos disponibles y omitir los que no tienen stock?',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Botones
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey[700],
                              side: BorderSide(color: Colors.grey[300]!),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                            ),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE65100),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Confirmar igual',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
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

  // ── Loading overlay ─────────────────────────────────────────
  static void mostrarCargando(BuildContext context,
      {String mensaje = 'Cargando...'}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Card(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                    color: Color(0xFF00897B)),
                const SizedBox(height: 16),
                Text(mensaje),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Widget interno reutilizable para los diálogos ─────────────
class _DialogContainer extends StatelessWidget {
  final List<Color> gradientColors;
  final IconData icon;
  final String titulo;
  final String mensaje;
  final String labelConfirmar;
  final String labelCancelar;
  final Color colorConfirmar;
  final VoidCallback onConfirmar;
  final VoidCallback onCancelar;

  const _DialogContainer({
    required this.gradientColors,
    required this.icon,
    required this.titulo,
    required this.mensaje,
    required this.labelConfirmar,
    required this.labelCancelar,
    required this.colorConfirmar,
    required this.onConfirmar,
    required this.onCancelar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withOpacity(0.2),
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
              gradient: LinearGradient(colors: gradientColors),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Icon(icon, color: Colors.white, size: 48),
                const SizedBox(height: 8),
                Text(
                  titulo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
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
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onCancelar,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[700],
                          side: BorderSide(color: Colors.grey[300]!),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(labelCancelar),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onConfirmar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorConfirmar,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text(
                          labelConfirmar,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold),
                        ),
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
}