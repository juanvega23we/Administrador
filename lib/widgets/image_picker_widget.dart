import 'package:flutter/material.dart';
import 'dart:typed_data';

/// Widget para seleccionar y previsualizar imagen
class ImagePickerWidget extends StatelessWidget {
  final Uint8List? imageBytes;
  final String? imageUrl;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const ImagePickerWidget({
    super.key,
    this.imageBytes,
    this.imageUrl,
    required this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageBytes != null || (imageUrl != null && imageUrl!.isNotEmpty);

    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey[300]!,
                width: 2,
                style: BorderStyle.solid,
              ),
            ),
            child: hasImage
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _buildImage(),
                      ),
                      if (onRemove != null)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: onRemove,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Toca para seleccionar imagen',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
          ),
        ),
        if (hasImage)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Toca para cambiar imagen',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildImage() {
    if (imageBytes != null) {
      // Mostrar imagen desde bytes (nueva selección)
      return Image.memory(
        imageBytes!,
        fit: BoxFit.cover,
      );
    } else if (imageUrl != null && imageUrl!.startsWith('http')) {
      // Mostrar imagen desde URL (imagen existente)
      return Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.broken_image, size: 64);
        },
      );
    } else {
      // Sin imagen
      return const Icon(Icons.image, size: 64);
    }
  }
}