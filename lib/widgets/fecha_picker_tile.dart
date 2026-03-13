

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FechaPickerTile extends StatelessWidget {
  final String label;
  final DateTime? fecha;
  final VoidCallback onTap;
  final Color accentColor;

  const FechaPickerTile({
    super.key,
    required this.label,
    required this.fecha,
    required this.onTap,
    this.accentColor = const Color(0xFF00897B),
  });

  @override
  Widget build(BuildContext context) {
    final seleccionada = fecha != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: seleccionada ? accentColor.withOpacity(0.08) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: seleccionada ? accentColor : Colors.grey[300]!,
            width: seleccionada ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: seleccionada ? accentColor : Colors.grey[500],
                ),
                const SizedBox(width: 6),
                Text(
                  seleccionada
                      ? DateFormat('dd/MM/yyyy').format(fecha!)
                      : 'Seleccionar',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        seleccionada ? FontWeight.bold : FontWeight.normal,
                    color: seleccionada ? accentColor : Colors.grey[600],
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