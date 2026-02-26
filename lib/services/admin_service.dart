import 'package:cloud_firestore/cloud_firestore.dart';

/// Servicio de autenticación para ADMINISTRADORES
class AuthAdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Verificar credenciales de administrador
  Future<Map<String, dynamic>> loginAdmin(String usuario, String password) async {
    try {
      // Buscar en la colección 'usuarios' donde rol = 'admin'
      final snapshot = await _db
          .collection('usuarios')
          .where('usuario', isEqualTo: usuario)
          .where('rol', isEqualTo: 'admin')
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return {
          'exito': false,
          'mensaje': 'Usuario no encontrado',
        };
      }

      final adminData = snapshot.docs.first.data();

      // Verificar contraseña
      if (adminData['password'] != password) {
        return {
          'exito': false,
          'mensaje': 'Contraseña incorrecta',
        };
      }

      // Login exitoso
      return {
        'exito': true,
        'mensaje': 'Bienvenido ${adminData['nombre']}',
        'admin': {
          'id': snapshot.docs.first.id,
          'nombre': adminData['nombre'],
          'usuario': adminData['usuario'],
          'rol': adminData['rol'],
          'email': adminData['email'] ?? '',
        },
      };

    } catch (e) {
      return {
        'exito': false,
        'mensaje': 'Error: $e',
      };
    }
  }

  /// Crear usuario administrador inicial (ejecutar una sola vez)
  Future<void> crearAdminInicial() async {
    try {
      // Verificar si ya existe un admin
      final snapshot = await _db
          .collection('usuarios')
          .where('rol', isEqualTo: 'admin')
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        // Crear primer admin
        await _db.collection('usuarios').add({
          'nombre': 'Administrador',
          'usuario': 'admin',
          'password': '1234', // ⚠️ Cambiar en producción
          'rol': 'admin',
          'email': 'admin@elgranmolino.com',
          'activo': true,
          'fechaCreacion': FieldValue.serverTimestamp(),
        });
        print('✅ Administrador inicial creado');
      } else {
        print('ℹ️ Ya existe un administrador');
      }
    } catch (e) {
      print('❌ Error al crear admin: $e');
    }
  }

  /// Obtener información del admin por ID
  Future<Map<String, dynamic>?> obtenerInfoAdmin(String idAdmin) async {
    try {
      final doc = await _db.collection('usuarios').doc(idAdmin).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error al obtener info admin: $e');
      return null;
    }
  }

  /// Cambiar contraseña del admin
  Future<bool> cambiarPassword(
    String idAdmin,
    String passwordActual,
    String passwordNueva,
  ) async {
    try {
      final doc = await _db.collection('usuarios').doc(idAdmin).get();
      
      if (!doc.exists) return false;
      
      final data = doc.data()!;
      
      if (data['password'] != passwordActual) {
        return false;
      }

      await _db.collection('usuarios').doc(idAdmin).update({
        'password': passwordNueva,
        'fechaActualizacion': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error al cambiar password: $e');
      return false;
    }
  }
}
