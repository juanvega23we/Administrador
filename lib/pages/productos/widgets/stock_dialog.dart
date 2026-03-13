// lib/pages/productos/widgets/stock_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/producto_service_admin.dart';
import '../../../widgets/notificacion_personalizada.dart';

class StockDialog {
  static void mostrar(
    BuildContext context, {
    required Map<String, dynamic> producto,
    required ProductoServiceAdmin servicio,
  }) {
    final stock     = (producto['stock'] ?? 0) as int;
    final stockCtrl = TextEditingController(text: stock.toString());

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.inventory_2, color: Colors.teal),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Stock: ${producto['nombre']}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Stock actual: $stock unidades',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: stockCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nuevo stock',
                hintText: 'Ej: 150',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.inventory_2, color: Colors.teal),
                suffixText: 'unidades',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nuevoStock = int.tryParse(stockCtrl.text);
              if (nuevoStock == null || nuevoStock < 0) {
                NotificacionPersonalizada.mostrarSnack(
                  context,
                  mensaje: 'Ingresa un número válido',
                  tipo: TipoNotificacion.error,
                );
                return;
              }
              Navigator.pop(dialogContext);
              final resultado = await servicio.actualizarStock(
                idProducto: producto['id'],
                nuevoStock: nuevoStock,
              );
              if (context.mounted) {
                NotificacionPersonalizada.mostrarSnack(
                  context,
                  mensaje: resultado['mensaje'],
                  tipo: resultado['exito']
                      ? TipoNotificacion.exito
                      : TipoNotificacion.error,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}