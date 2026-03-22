// lib/services/producto_service_admin.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';

class ProductoServiceAdmin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ── SUBIR IMAGEN ─────────────────────────────────────────────
  Future<String?> subirImagen({
    required Uint8List bytes,
    required String nombreArchivo,
    String carpeta = 'productos',
  }) async {
    try {
      final ref = _storage.ref().child('$carpeta/$nombreArchivo');
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      await ref.putData(bytes, metadata);
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  // ── CATEGORÍAS ───────────────────────────────────────────────

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

  Future<Map<String, String>> obtenerMapaPrefijos() async {
    try {
      final snapshot = await _firestore
          .collection('tipo_producto')
          .where('activo', isEqualTo: true)
          .get();
      final mapa = <String, String>{};
      for (final doc in snapshot.docs) {
        final data    = doc.data();
        final nombre  = data['nombre']  as String? ?? '';
        final prefijo = data['prefijo'] as String? ?? '';
        if (prefijo.length == 2 && nombre.isNotEmpty) mapa[prefijo] = nombre;
      }
      return mapa;
    } catch (e) {
      return {};
    }
  }

  Future<Map<String, dynamic>?> obtenerCategoriaPorNombre(String nombre) async {
    try {
      final snap = await _firestore
          .collection('tipo_producto')
          .where('nombre', isEqualTo: nombre)
          .where('activo', isEqualTo: true)
          .get();
      if (snap.docs.isEmpty) return null;
      return snap.docs.first.data();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> crearCategoria({
    required String nombre,
    String? descripcion,
    String? prefijo,
    int? iconoCodePoint,
  }) async {
    try {
      final existing = await _firestore
          .collection('tipo_producto')
          .where('nombre', isEqualTo: nombre)
          .where('activo', isEqualTo: true)
          .get();
      if (existing.docs.isNotEmpty) {
        return {'exito': false, 'mensaje': 'Ya existe una categoría con ese nombre'};
      }
      if (prefijo != null && prefijo.length == 2) {
        final prefijoExistente = await _firestore
            .collection('tipo_producto')
            .where('prefijo', isEqualTo: prefijo)
            .where('activo', isEqualTo: true)
            .get();
        if (prefijoExistente.docs.isNotEmpty) {
          final nombreExistente = prefijoExistente.docs.first.data()['nombre'] ?? '';
          return {'exito': false, 'mensaje': 'El prefijo "$prefijo" ya está en uso por "$nombreExistente"'};
        }
      }
      await _firestore.collection('tipo_producto').add({
        'nombre':        nombre,
        'descripcion':   descripcion ?? '',
        'prefijo':       prefijo ?? '',
        'iconoCodePoint': iconoCodePoint ?? 0,
        'activo':        true,
        'fechaCreacion': FieldValue.serverTimestamp(),
      });
      return {'exito': true, 'mensaje': 'Categoría creada exitosamente'};
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error al crear categoría: $e'};
    }
  }

  Future<Map<String, dynamic>> editarCategoria({
    required String nombreActual,
    required String nuevoNombre,
    required String nuevoPrefijo,
    int? nuevoIconoCodePoint,
  }) async {
    try {
      // Buscar el documento por nombre actual
      final snapshot = await _firestore
          .collection('tipo_producto')
          .where('nombre', isEqualTo: nombreActual)
          .where('activo', isEqualTo: true)
          .get();

      if (snapshot.docs.isEmpty) {
        return {'exito': false, 'mensaje': 'Categoría no encontrada'};
      }

      final docRef = snapshot.docs.first.reference;

      // Validar que el nuevo nombre no exista ya (si cambió)
      if (nuevoNombre != nombreActual) {
        final nombreExiste = await _firestore
            .collection('tipo_producto')
            .where('nombre', isEqualTo: nuevoNombre)
            .where('activo', isEqualTo: true)
            .get();
        if (nombreExiste.docs.isNotEmpty) {
          return {'exito': false, 'mensaje': 'Ya existe una categoría llamada "$nuevoNombre"'};
        }
      }

      // Validar que el prefijo no esté en uso por otra categoría (si cambió)
      final prefijoActual = snapshot.docs.first.data()['prefijo'] ?? '';
      if (nuevoPrefijo != prefijoActual && nuevoPrefijo.length == 2) {
        final prefijoExiste = await _firestore
            .collection('tipo_producto')
            .where('prefijo', isEqualTo: nuevoPrefijo)
            .where('activo', isEqualTo: true)
            .get();
        if (prefijoExiste.docs.isNotEmpty) {
          final dueno = prefijoExiste.docs.first.data()['nombre'] ?? '';
          return {'exito': false, 'mensaje': 'El prefijo "$nuevoPrefijo" ya lo usa "$dueno"'};
        }
      }

      // Actualizar documento
      final Map<String, dynamic> updates = {
        'nombre':  nuevoNombre,
        'prefijo': nuevoPrefijo,
        'fechaActualizacion': FieldValue.serverTimestamp(),
      };
      if (nuevoIconoCodePoint != null) {
        updates['iconoCodePoint'] = nuevoIconoCodePoint;
      }
      await docRef.update(updates);

      // Si el nombre cambió, actualizar todos los productos de esa categoría
      if (nuevoNombre != nombreActual) {
        final productos = await _firestore
            .collection('productos')
            .where('categoria', isEqualTo: nombreActual)
            .get();
        final batch = _firestore.batch();
        for (final prod in productos.docs) {
          batch.update(prod.reference, {'categoria': nuevoNombre});
        }
        await batch.commit();
      }

      return {'exito': true, 'mensaje': 'Categoría actualizada correctamente'};
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error al editar categoría: $e'};
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
      await snapshot.docs.first.reference.delete();
      return {'exito': true, 'mensaje': 'Categoría eliminada exitosamente'};
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error al eliminar categoría: $e'};
    }
  }

  // ── PRODUCTOS ────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> obtenerProductosPorCategoria(String categoria) {
    return _firestore
        .collection('productos')
        .where('categoria', isEqualTo: categoria)
        .where('activo', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final productos = snapshot.docs.map((doc) {
        final data = doc.data(); data['id'] = doc.id; return data;
      }).toList();
      productos.sort((a, b) => (a['nombre'] as String).compareTo(b['nombre'] as String));
      return productos;
    });
  }

  Stream<List<Map<String, dynamic>>> obtenerTodosLosProductos() {
    return _firestore.collection('productos').snapshots().map((snapshot) {
      final productos = snapshot.docs.map((doc) {
        final data = doc.data(); data['id'] = doc.id; return data;
      }).toList();
      productos.sort((a, b) => (a['nombre'] as String).compareTo(b['nombre'] as String));
      return productos;
    });
  }

  Future<List<Map<String, dynamic>>> obtenerTodosLosProductosUnaVez() async {
    final snap = await _firestore.collection('productos').orderBy('nombre').get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<Map<String, dynamic>> crearProducto({
    required String nombre,
    required double precio,
    double precioProveedor = 0.0,
    required String categoria,
    required String subtexto,
    required String idAdmin,
    String? imagenUrl,
    int stock = 0,
    String codigo = '',
  }) async {
    try {
      final docRef = await _firestore.collection('productos').add({
        'nombre':          nombre,
        'precio':          precio,
        'precioProveedor': precioProveedor,
        'categoria':       categoria,
        'subtexto':        subtexto,
        'imagen':          (imagenUrl != null && imagenUrl.isNotEmpty) ? imagenUrl : '',
        'activo':          true,
        'stock':           stock,
        'codigo':          codigo,
        'fechaCreacion':   FieldValue.serverTimestamp(),
        'creadoPor':       idAdmin,
      });
      return {'exito': true, 'mensaje': 'Producto creado exitosamente', 'id': docRef.id};
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error al crear producto: $e'};
    }
  }

  Future<Map<String, dynamic>> actualizarProducto({
    required String idProducto,
    required String nombre,
    required double precio,
    double? precioProveedor,
    required String categoria,
    required String subtexto,
    String? imagenUrl,
    int? stock,
    String? codigo,
  }) async {
    try {
      final Map<String, dynamic> datos = {
        'nombre':             nombre,
        'precio':             precio,
        'categoria':          categoria,
        'subtexto':           subtexto,
        'fechaActualizacion': FieldValue.serverTimestamp(),
      };
      if (precioProveedor != null) datos['precioProveedor'] = precioProveedor;
      if (imagenUrl != null) datos['imagen'] = imagenUrl;
      if (stock != null)     datos['stock']  = stock;
      if (codigo != null)    datos['codigo'] = codigo;
      await _firestore.collection('productos').doc(idProducto).update(datos);
      return {'exito': true, 'mensaje': 'Producto actualizado exitosamente'};
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error al actualizar producto: $e'};
    }
  }

  Future<Map<String, dynamic>> actualizarSoloPrecios({
    required String idProducto,
    required double precio,
    required double precioProveedor,
  }) async {
    try {
      await _firestore.collection('productos').doc(idProducto).update({
        'precio':             precio,
        'precioProveedor':    precioProveedor,
        'fechaActualizacion': FieldValue.serverTimestamp(),
      });
      return {'exito': true, 'mensaje': 'Precio actualizado'};
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error: $e'};
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
        'activo': false, 'fechaEliminacion': FieldValue.serverTimestamp(),
      });
      return {'exito': true, 'mensaje': 'Producto desactivado exitosamente'};
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error al desactivar producto: $e'};
    }
  }

  Future<Map<String, dynamic>> activarProducto(String idProducto) async {
    try {
      await _firestore.collection('productos').doc(idProducto).update({'activo': true});
      return {'exito': true, 'mensaje': 'Producto activado exitosamente'};
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error al activar producto: $e'};
    }
  }

  Future<Map<String, dynamic>> eliminarProductoPermanente(String idProducto) async {
    try {
      await _firestore.collection('productos').doc(idProducto).delete();
      return {'exito': true, 'mensaje': 'Producto eliminado permanentemente'};
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error al eliminar producto: $e'};
    }
  }
}