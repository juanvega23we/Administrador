// lib/pages/reportes/widgets/reportes_header.dart
//
// Contiene todos los widgets de soporte del header:
//   ExportBtn, HeaderIconBtn, PeriodChip, FechaTile, SectionHeader
//
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const _kColor = Color(0xFF00897B); // antes 0xFF8B0000


class ExportBtn extends StatelessWidget {
  final String   label;
  final IconData icon;
  final Color    color;
  final bool     loading;
  final VoidCallback onTap;

  const ExportBtn({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: loading ? 0.5 : 1.0,
      child: Material(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: loading ? null : onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                loading
                    ? SizedBox(
                        width: 15, height: 15,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: color))
                    : Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Botón icono header  (igual al original, color rojo→verde)
// ═══════════════════════════════════════════════════════════════
class HeaderIconBtn extends StatelessWidget {
  final IconData icon;
  final bool     isActive;
  final String   tooltip;
  final VoidCallback onTap;

  const HeaderIconBtn({
    super.key,
    required this.icon,
    required this.isActive,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: isActive
                ? _kColor.withOpacity(0.12)
                : _kColor.withOpacity(0.07),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: isActive ? _kColor : Colors.transparent, width: 2),
          ),
          child: Icon(icon, color: _kColor, size: 20),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Chip de período  (igual al original, color rojo→verde)
// ═══════════════════════════════════════════════════════════════
class PeriodChip extends StatelessWidget {
  final String   label;
  final bool     isSelected;
  final VoidCallback onTap;
  final Color?   color;

  const PeriodChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? _kColor;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? c : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? c : Colors.grey.shade300),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey[600])),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  FechaTile  (igual al original, color rojo→verde)
// ═══════════════════════════════════════════════════════════════
class FechaTile extends StatelessWidget {
  final String    label;
  final DateTime? fecha;
  final VoidCallback onTap;

  const FechaTile({
    super.key,
    required this.label,
    required this.fecha,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: fecha != null ? _kColor.withOpacity(0.06) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: fecha != null ? _kColor : Colors.grey.shade300,
              width: fecha != null ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 5),
            Row(children: [
              Icon(Icons.calendar_today,
                  size: 14,
                  color: fecha != null ? _kColor : Colors.grey[500]),
              const SizedBox(width: 6),
              Text(
                fecha != null
                    ? DateFormat('dd/MM/yyyy').format(fecha!)
                    : 'Seleccionar',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        fecha != null ? FontWeight.bold : FontWeight.normal,
                    color: fecha != null ? _kColor : Colors.grey[600]),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SectionHeader  (igual al original, color rojo→verde)
// ═══════════════════════════════════════════════════════════════
class SectionHeader extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String?  badge;

  const SectionHeader({
    super.key,
    required this.icon,
    required this.label,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 18, color: _kColor),
      const SizedBox(width: 8),
      Text(label,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF004D40))), // antes 0xFF2C0A0A
      if (badge != null) ...[
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
              color: _kColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20)),
          child: Text(badge!,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _kColor)),
        ),
      ],
    ]);
  }
}