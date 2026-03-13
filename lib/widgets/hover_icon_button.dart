// lib/widgets/hover_icon_button.dart
//
// Botón de ícono con efecto hover animado.
// Estaba como _HoverIconButton en dashboard_page.dart
// y como _IconBtn en pedidos_page.dart — misma idea, distinta implementación.
// Este archivo unifica ambos.
//
// USO básico (como en dashboard):
//   HoverIconButton(
//     icon: Icons.refresh_rounded,
//     color: Colors.teal,
//     onTap: () => setState(() {}),
//   )
//
// USO con estado activo (como en pedidos — botón de calendario activo/inactivo):
//   HoverIconButton(
//     icon: Icons.calendar_month,
//     color: Colors.teal,
//     isActive: _fechaInicio != null,
//     onTap: () => _mostrarMenuFechas(context),
//   )

import 'package:flutter/material.dart';

class HoverIconButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  /// Si es true, el botón se muestra con fondo y borde resaltado
  /// aunque no esté en hover. Útil para indicar filtro activo.
  final bool isActive;

  /// Color de fondo base (opcional). Por defecto usa [color] con opacidad baja.
  final Color? backgroundColor;

  /// Color del borde base (opcional).
  final Color? borderColor;

  /// Tamaño del ícono.
  final double iconSize;

  /// Padding interno del botón.
  final double padding;

  const HoverIconButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isActive = false,
    this.backgroundColor,
    this.borderColor,
    this.iconSize = 20,
    this.padding = 10,
  });

  @override
  State<HoverIconButton> createState() => _HoverIconButtonState();
}

class _HoverIconButtonState extends State<HoverIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final resaltado = _hovered || widget.isActive;
    final bgColor = resaltado
        ? widget.color.withOpacity(0.12)
        : (widget.backgroundColor ?? widget.color.withOpacity(0.07));
    final bdColor = resaltado
        ? widget.color
        : (widget.borderColor ?? Colors.transparent);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.all(widget.padding),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: bdColor, width: resaltado ? 2 : 1),
          ),
          child: Icon(widget.icon, color: widget.color, size: widget.iconSize),
        ),
      ),
    );
  }
}