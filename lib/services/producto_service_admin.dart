import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';

class ProductoServiceAdmin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ── SUBIR IMAGEN A FIREBASE STORAGE ─────────────────────────────────────────
  /// Sube los bytes de una imagen y retorna la URL pública de descarga.
  /// [idProducto] se usa como nombre de archivo para sobreescribir si ya existe.
  Future<String?> subirImagen({
    required Uint8List bytes,
    required String nombreArchivo,
    String carpeta = 'productos',
  }) async {
    try {
      print('📤 Subiendo imagen: $carpeta/$nombreArchivo');
      final ref = _storage.ref().child('$carpeta/$nombreArchivo');
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      await ref.putData(bytes, metadata);
      final url = await ref.getDownloadURL();
      print('✅ Imagen subida exitosamente: $url');
      return url;
    } catch (e) {
      print('❌ Error al subir imagen: $e');
      return null;
    }
  }

  // ── CATEGORÍAS ──────────────────────────────────────────────────────────────

  Stream<List<String>> obtenerCategoriasStream() {
    return _firestore
        .collection('tipo_producto')
        .where('activo', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final categorias = snapshot.docs
          .map((doc) => doc.data()['nombre'] as String)
          .toList();
      categorias.sort();
      return categorias;
    });
  }

  Future<Map<String, dynamic>> crearCategoria({
    required String nombre,
    String? descripcion,
  }) async {
    try {
      final existing = await _firestore
          .collection('tipo_producto')
          .where('nombre', isEqualTo: nombre)
          .get();

      if (existing.docs.isNotEmpty) {
        final doc = existing.docs.first;
        final estaActivo = doc.data()['activo'] == true;
        if (estaActivo) {
          return {
            'exito': false,
            'mensaje': 'Ya existe una categoría con ese nombre',
          };
        } else {
          await doc.reference.update({
            'activo': true,
            'fechaReactivacion': FieldValue.serverTimestamp(),
          });
          return {'exito': true, 'mensaje': 'Categoría creada exitosamente'};
        }
      }

      await _firestore.collection('tipo_producto').add({
        'nombre': nombre,
        'descripcion': descripcion ?? '',
        'activo': true,
        'fechaCreacion': FieldValue.serverTimestamp(),
      });

      return {'exito': true, 'mensaje': 'Categoría creada exitosamente'};
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error al crear categoría: $e'};
    }
  }

  Future<Map<String, dynamic>> eliminarCategoria(String nombre) async {
    try {
      final snapshot = await _firestore
          .collection('tipo_producto')
          .where('nombre', isEqualTo: nombre)
          .get();

      if (snapshot.docs.isEmpty) {
        return {'exito': false, 'mensaje': 'Categoría no encontrada'};
      }

      await snapshot.docs.first.reference.update({
        'activo': false,
        'fechaEliminacion': FieldValue.serverTimestamp(),
      });

      return {'exito': true, 'mensaje': 'Categoría eliminada exitosamente'};
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error al eliminar categoría: $e'};
    }
  }

  // ── PRODUCTOS ───────────────────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> obtenerProductosPorCategoria(
      String categoria) {
    return _firestore
        .collection('productos')
        .where('categoria', isEqualTo: categoria)
        .where('activo', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final productos = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      productos.sort((a, b) =>
          (a['nombre'] as String).compareTo(b['nombre'] as String));
      return productos;
    });
  }

  Stream<List<Map<String, dynamic>>> obtenerTodosLosProductos() {
    return _firestore
        .collection('productos')
        .snapshots()
        .map((snapshot) {
      final productos = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      productos.sort((a, b) =>
          (a['nombre'] as String).compareTo(b['nombre'] as String));
      return productos;
    });
  }

  Future<Map<String, dynamic>> crearProducto({
    required String nombre,
    required double precio,
    required String categoria,
    required String subtexto,
    required String idAdmin,
    String? imagenUrl,
    int stock = 0,
  }) async {
    try {
      // Debug: verificar la URL antes de guardar
      print('💾 Guardando producto con imagen URL: $imagenUrl');
      
      final docRef = await _firestore.collection('productos').add({
        'nombre': nombre,
        'precio': precio,
        'categoria': categoria,
        'subtexto': subtexto,
        'imagen': (imagenUrl != null && imagenUrl.isNotEmpty) ? imagenUrl : '',
        'activo': true,
        'stock': stock,
        'fechaCreacion': FieldValue.serverTimestamp(),
        'creadoPor': idAdmin,
      });

      print('✅ Producto guardado con ID: ${docRef.id}');

      return {
        'exito': true,
        'mensaje': 'Producto creado exitosamente',
        'id': docRef.id,
      };
    } catch (e) {
      print('❌ Error al crear producto: $e');
      return {'exito': false, 'mensaje': 'Error al crear producto: $e'};
    }
  }

  Future<Map<String, dynamic>> actualizarProducto({
    required String idProducto,
    required String nombre,
    required double precio,
    required String categoria,
    required String subtexto,
    String? imagenUrl,
    int? stock,
  }) async {
    try {
      final Map<String, dynamic> datos = {
        'nombre': nombre,
        'precio': precio,
        'categoria': categoria,
        'subtexto': subtexto,
        'fechaActualizacion': FieldValue.serverTimestamp(),
      };

      if (imagenUrl != null) {
        datos['imagen'] = imagenUrl;
      }

      if (stock != null) {
        datos['stock'] = stock;
      }

      await _firestore
          .collection('productos')
          .doc(idProducto)
          .update(datos);

      return {'exito': true, 'mensaje': 'Producto actualizado exitosamente'};
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error al actualizar producto: $e'};
    }
  }

  Future<Map<String, dynamic>> actualizarStock({
    required String idProducto,
    required int nuevoStock,
  }) async {
    try {
      await _firestore.collection('productos').doc(idProducto).update({
        'stock': nuevoStock,
        'fechaActualizacion': FieldValue.serverTimestamp(),
      });
      return {'exito': true, 'mensaje': 'Stock actualizado exitosamente'};
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error al actualizar stock: $e'};
    }
  }

  Future<Map<String, dynamic>> desactivarProducto(String idProducto) async {
    try {
      await _firestore.collection('productos').doc(idProducto).update({
        'activo': false,
        'fechaEliminacion': FieldValue.serverTimestamp(),
      });
      return {'exito': true, 'mensaje': 'Producto desactivado exitosamente'};
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error al desactivar producto: $e'};
    }
  }

  Future<Map<String, dynamic>> activarProducto(String idProducto) async {
    try {
      await _firestore
          .collection('productos')
          .doc(idProducto)
          .update({'activo': true});
      return {'exito': true, 'mensaje': 'Producto activado exitosamente'};
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error al activar producto: $e'};
    }
  }

  Future<Map<String, dynamic>> eliminarProductoPermanente(
      String idProducto) async {
    try {
      await _firestore.collection('productos').doc(idProducto).delete();
      return {'exito': true, 'mensaje': 'Producto eliminado permanentemente'};
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error al eliminar producto: $e'};
    }
  }
}