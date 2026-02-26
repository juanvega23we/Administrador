import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html show window; // Solo para web

/// Servicio de autenticación para administradores
class AuthAdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // Clave para localStorage (solo web)
  static const String _sessionKey = 'admin_session_id';

  /// Crear admin inicial (SOLO PARA DESARROLLO)
  Future<void> crearAdminInicial() async {
    try {
      // Verificar si ya existe un admin
      final adminQuery = await _db
          .collection('administradores')
          .where('usuario', isEqualTo: 'admin')
          .limit(1)
          .get();

      if (adminQuery.docs.isEmpty) {
        // Crear admin por defecto
        final adminRef = _db.collection('administradores').doc();
        await adminRef.set({
          'idAdmin': adminRef.id,
          'usuario': 'admin',
          'password': '1234', // ⚠️ EN PRODUCCIÓN usar hash
          'nombre': 'Administrador',
          'email': 'admin@granmolino.com',
          'rol': 'super_admin',
          'activo': true,
          'fechaCreacion': FieldValue.serverTimestamp(),
        });
        print('✅ Admin inicial creado: admin / 1234');
      }
    } catch (e) {
      print('Error al crear admin inicial: $e');
    }
  }

  /// Login de administrador
  Future<Map<String, dynamic>> loginAdmin(
    String usuario,
    String password,
  ) async {
    try {
      // Buscar admin en Firestore
      final querySnapshot = await _db
          .collection('administradores')
          .where('usuario', isEqualTo: usuario)
          .where('activo', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return {
          'exito': false,
          'mensaje': 'Usuario no encontrado o inactivo',
        };
      }

      final adminDoc = querySnapshot.docs.first;
      final adminData = adminDoc.data();

      // Verificar contraseña (en producción usar hash)
      if (adminData['password'] != password) {
        return {
          'exito': false,
          'mensaje': 'Contraseña incorrecta',
        };
      }

      // Guardar sesión (solo en web)
      if (kIsWeb) {
        html.window.localStorage[_sessionKey] = adminDoc.id;
      }

      // Registrar último acceso
      await adminDoc.reference.update({
        'ultimoAcceso': FieldValue.serverTimestamp(),
      });

      return {
        'exito': true,
        'mensaje': 'Bienvenido ${adminData['nombre']}',
        'admin': {
          'idAdmin': adminDoc.id,
          'usuario': adminData['usuario'],
          'nombre': adminData['nombre'],
          'email': adminData['email'],
          'rol': adminData['rol'],
        },
      };
    } catch (e) {
      return {
        'exito': false,
        'mensaje': 'Error en el servidor: $e',
      };
    }
  }

  /// Verificar si hay sesión activa (⭐ MÉTODO NUEVO)
  Future<Map<String, dynamic>?> verificarSesionActiva() async {
    try {
      // Solo funciona en web
      if (!kIsWeb) return null;

      // Obtener ID de sesión del localStorage
      final sessionId = html.window.localStorage[_sessionKey];
      
      if (sessionId == null || sessionId.isEmpty) {
        return null; // No hay sesión guardada
      }

      // Verificar que el admin aún existe y está activo
      final adminDoc = await _db
          .collection('administradores')
          .doc(sessionId)
          .get();

      if (!adminDoc.exists) {
        // La sesión no es válida, limpiar localStorage
        html.window.localStorage.remove(_sessionKey);
        return null;
      }

      final adminData = adminDoc.data()!;

      // Verificar que el admin está activo
      if (adminData['activo'] != true) {
        html.window.localStorage.remove(_sessionKey);
        return null;
      }

      // Sesión válida, retornar datos del admin
      return {
        'idAdmin': adminDoc.id,
        'usuario': adminData['usuario'],
        'nombre': adminData['nombre'],
        'email': adminData['email'],
        'rol': adminData['rol'],
      };
    } catch (e) {
      print('Error al verificar sesión: $e');
      return null;
    }
  }

  /// Cerrar sesión
  Future<void> cerrarSesion() async {
    if (kIsWeb) {
      html.window.localStorage.remove(_sessionKey);
    }
  }

  /// Cambiar contraseña de administrador
  Future<Map<String, dynamic>> cambiarPassword(
    String idAdmin,
    String passwordActual,
    String passwordNueva,
  ) async {
    try {
      final adminDoc = await _db.collection('administradores').doc(idAdmin).get();
      
      if (!adminDoc.exists) {
        return {
          'exito': false,
          'mensaje': 'Administrador no encontrado',
        };
      }

      final adminData = adminDoc.data()!;

      // Verificar contraseña actual
      if (adminData['password'] != passwordActual) {
        return {
          'exito': false,
          'mensaje': 'Contraseña actual incorrecta',
        };
      }

      // Actualizar contraseña
      await adminDoc.reference.update({
        'password': passwordNueva, // ⚠️ EN PRODUCCIÓN usar hash
        'fechaUltimoCambioPassword': FieldValue.serverTimestamp(),
      });

      return {
        'exito': true,
        'mensaje': 'Contraseña actualizada exitosamente',
      };
    } catch (e) {
      return {
        'exito': false,
        'mensaje': 'Error al cambiar contraseña: $e',
      };
    }
  }

  /// Crear nuevo administrador (solo super_admin)
  Future<Map<String, dynamic>> crearNuevoAdmin({
    required String usuario,
    required String password,
    required String nombre,
    required String email,
    String rol = 'admin',
  }) async {
    try {
      // Verificar si el usuario ya existe
      final existeQuery = await _db
          .collection('administradores')
          .where('usuario', isEqualTo: usuario)
          .limit(1)
          .get();

      if (existeQuery.docs.isNotEmpty) {
        return {
          'exito': false,
          'mensaje': 'El usuario ya existe',
        };
      }

      // Crear nuevo admin
      final adminRef = _db.collection('administradores').doc();
      await adminRef.set({
        'idAdmin': adminRef.id,
        'usuario': usuario,
        'password': password, // ⚠️ EN PRODUCCIÓN usar hash
        'nombre': nombre,
        'email': email,
        'rol': rol,
        'activo': true,
        'fechaCreacion': FieldValue.serverTimestamp(),
      });

      return {
        'exito': true,
        'mensaje': 'Administrador creado exitosamente',
        'idAdmin': adminRef.id,
      };
    } catch (e) {
      return {
        'exito': false,
        'mensaje': 'Error al crear administrador: $e',
      };
    }
  }

  /// Obtener todos los administradores
  Stream<List<Map<String, dynamic>>> obtenerAdministradores() {
    return _db
        .collection('administradores')
        .orderBy('fechaCreacion', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// Activar/Desactivar administrador
  Future<Map<String, dynamic>> cambiarEstadoAdmin(
    String idAdmin,
    bool activo,
  ) async {
    try {
      await _db.collection('administradores').doc(idAdmin).update({
        'activo': activo,
        'fechaActualizacion': FieldValue.serverTimestamp(),
      });

      return {
        'exito': true,
        'mensaje': activo ? 'Administrador activado' : 'Administrador desactivado',
      };
    } catch (e) {
      return {
        'exito': false,
        'mensaje': 'Error al actualizar estado: $e',
      };
    }
  }
}