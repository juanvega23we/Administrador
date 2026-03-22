// lib/pages/productos/widgets/producto_card.dart
//
// Extraído de productos_page.dart → _buildProductoCard()
// Incluye la imagen, precio con formato colombiano,
// badge de activo/inactivo, badge de stock y el menú de acciones.

import 'package:flutter/material.dart';
import '../../../services/producto_service_admin.dart';
import '../../../utils/numero_formato.dart';
import 'stock_dialog.dart';

class ProductoCard extends StatelessWidget {
  final Map<String, dynamic> producto;
  final List<String> categorias;

  /// true cuando se muestra en la pestaña "Todo"
  final bool enTabTodo;

  final ProductoServiceAdmin servicio;

  /// Callback para abrir el diálogo de edición
  final void Function(Map<String, dynamic> producto) onEditar;

  /// Callback para cambiar activo/inactivo
  final Future<void> Function(String id, bool nuevoEstado) onCambiarEstado;

  /// Callback para eliminar permanentemente (solo en tab Todo)
  final Future<void> Function(Map<String, dynamic> producto)? onEliminar;

  const ProductoCard({
    super.key,
    required this.producto,
    required this.categorias,
    required this.enTabTodo,
    required this.servicio,
    required this.onEditar,
    required this.onCambiarEstado,
    this.onEliminar,
  });

  // ── Color e indicador de stock ───────────────────────────────
  Color _colorStock(int stock) {
    if (stock == 0)   return Colors.red;
    if (stock <= 10)  return Colors.orange;
    return Colors.green;
  }

  String _textoStock(int stock) {
    if (stock == 0)   return 'Sin stock';
    if (stock <= 10)  return 'Stock bajo: $stock';
    return 'Stock: $stock';
  }

  // ── Imagen del producto ──────────────────────────────────────
  Widget _buildImagen(String? urlImagen, {double size = 60}) {
    if (urlImagen == null ||
        urlImagen.isEmpty ||
        urlImagen.startsWith('assets/')) {
      return Icon(Icons.image, size: size * 0.5, color: Colors.grey);
    }
    if (urlImagen.startsWith('http')) {
      return Image.network(
        urlImagen,
        fit: BoxFit.cover,
        width: size,
        height: size,
        cacheWidth: 200,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.teal,
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) =>
            Icon(Icons.broken_image, size: size * 0.5, color: Colors.grey),
      );
    }
    return Icon(Icons.image, size: size * 0.5, color: Colors.grey);
  }

  @override
  Widget build(BuildContext context) {
    final activo    = producto['activo'] ?? false;
    final urlImagen = producto['imagen'] as String?;
    final stock     = (producto['stock'] ?? 0) as int;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        // Imagen
        leading: Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _buildImagen(urlImagen, size: 60),
          ),
        ),
        // Nombre
        title: Text(
          producto['nombre'] ?? 'Sin nombre',
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 16),
        ),
        // Subtítulo: categoría, subtexto, precio, badges
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (enTabTodo)
              Text(
                producto['categoria'] ?? '',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.teal[700],
                    fontWeight: FontWeight.w600),
              ),
            Text(producto['subtexto'] ?? ''),
            const SizedBox(height: 4),
            Row(
              children: [
                // Precio
                Text(
                  formatearPrecioCOP(producto['precio']),
                  style: const TextStyle(
                    color: Colors.teal,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 12),
                // Badge activo/inactivo
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: activo ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: activo ? Colors.green : Colors.red),
                  ),
                  child: Text(
                    activo ? 'Activo' : 'Inactivo',
                    style: TextStyle(
                      fontSize: 11,
                      color: activo
                          ? Colors.green[700]
                          : Colors.red[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Badge stock (toca para editar)
                Tooltip(
                  message: 'Actualizar stock',
                  child: GestureDetector(
                    onTap: () => StockDialog.mostrar(
                      context,
                      producto: producto,
                      servicio: servicio,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _colorStock(stock).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: _colorStock(stock)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2,
                              size: 11, color: _colorStock(stock)),
                          const SizedBox(width: 4),
                          Text(
                            _textoStock(stock),
                            style: TextStyle(
                              fontSize: 11,
                              color: _colorStock(stock),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        // Menú de tres puntos
        trailing: PopupMenuButton(
          tooltip: 'Opciones',
          icon: const Icon(Icons.more_vert),
          itemBuilder: (_) => [
            PopupMenuItem(
              child: const Row(children: [
                Icon(Icons.edit, size: 20),
                SizedBox(width: 12),
                Text('Editar'),
              ]),
              onTap: () => Future.delayed(
                Duration.zero, () => onEditar(producto)),
            ),
            PopupMenuItem(
              child: Row(children: [
                Icon(
                  activo ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(activo ? 'Desactivar' : 'Activar'),
              ]),
              onTap: () =>
                  onCambiarEstado(producto['id'], !activo),
            ),
            if (enTabTodo && onEliminar != null)
              PopupMenuItem(
                child: const Row(children: [
                  Icon(Icons.delete_forever,
                      size: 20, color: Colors.red),
                  SizedBox(width: 12),
                  Text('Eliminar',
                      style: TextStyle(color: Colors.red)),
                ]),
                onTap: () => Future.delayed(
                  Duration.zero, () => onEliminar!(producto)),
              ),
          ],
        ),
      ),
    );
  }
}