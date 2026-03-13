// lib/services/auth_admin_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthAdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Map<String, dynamic>> loginAdmin(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(), password: password.trim(),
      );
      final uid = credential.user!.uid;

      final adminDoc = await _db.collection('administradores').doc(uid).get();
      if (!adminDoc.exists) {
        await _auth.signOut();
        return {'exito': false, 'mensaje': 'No tienes permisos de administrador'};
      }

      final data = adminDoc.data()!;

      // Verificar activo
      if (data['activo'] != true) {
        await _auth.signOut();
        return {'exito': false, 'mensaje': 'Tu cuenta ha sido suspendida. Contacta al proveedor.'};
      }

      // Verificar vencimiento (solo para rol admin, no super_admin)
      if (data['rol'] == 'admin') {
        final venc = data['fechaVencimiento'] as Timestamp?;
        if (venc != null && venc.toDate().isBefore(DateTime.now())) {
          await _db.collection('administradores').doc(uid).update({'activo': false});
          await _auth.signOut();
          return {'exito': false, 'mensaje': 'Tu licencia ha vencido. Contacta al proveedor para renovar.'};
        }
      }

      // Verificar rol
      if (data['rol'] != 'super_admin' && data['rol'] != 'admin') {
        await _auth.signOut();
        return {'exito': false, 'mensaje': 'No tienes permisos suficientes'};
      }

      await _db.collection('administradores').doc(uid).update({
        'ultimoAcceso': FieldValue.serverTimestamp(),
      });

      return {
        'exito': true,
        'mensaje': 'Bienvenido ${data['nombre']}',
        'primerLogin': data['primerLogin'] == true, // ✅ CORREGIDO
        'admin': {
          'id': uid,
          'nombre': data['nombre'],
          'email': data['email'],
          'rol': data['rol'],
          'negocio': data['negocio'] ?? 'Granero del Norte',
        },
      };
    } on FirebaseAuthException catch (e) {
      return {'exito': false, 'mensaje': _traducirError(e.code)};
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error inesperado, intenta de nuevo'};
    }
  }

  Future<Map<String, dynamic>?> verificarSesionActiva() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final adminDoc = await _db.collection('administradores').doc(user.uid).get();
      if (!adminDoc.exists) return null;

      final data = adminDoc.data()!;
      if (data['activo'] != true) return null;
      if (data['rol'] != 'super_admin' && data['rol'] != 'admin') return null;

      // Verificar vencimiento
      if (data['rol'] == 'admin') {
        final venc = data['fechaVencimiento'] as Timestamp?;
        if (venc != null && venc.toDate().isBefore(DateTime.now())) {
          await _db.collection('administradores').doc(user.uid).update({'activo': false});
          await _auth.signOut();
          return null;
        }
      }

      return {
        'id': user.uid,
        'nombre': data['nombre'],
        'email': data['email'],
        'rol': data['rol'],
        'negocio': data['negocio'] ?? 'Granero del Norte',
        'primerLogin': data['primerLogin'] == true, // ✅ CORREGIDO
      };
    } catch (_) { return null; }
  }

  Future<void> cerrarSesion() async => await _auth.signOut();

  Future<Map<String, dynamic>> cambiarPassword(String passwordActual, String passwordNueva) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {'exito': false, 'mensaje': 'No hay sesión activa'};
      final credential = EmailAuthProvider.credential(email: user.email!, password: passwordActual);
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(passwordNueva);
      return {'exito': true, 'mensaje': 'Contraseña actualizada correctamente'};
    } on FirebaseAuthException catch (e) {
      return {'exito': false, 'mensaje': _traducirError(e.code)};
    } catch (_) {
      return {'exito': false, 'mensaje': 'Error al cambiar contraseña'};
    }
  }

  Future<bool> marcarPrimerLoginCompleto() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      await FirebaseFirestore.instance
          .collection('administradores')
          .doc(user.uid)
          .update({
        'primerLogin': false,
        'actualizadoEn': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print("Error: $e");
      return false;
    }
  }

  String _traducirError(String code) {
    switch (code) {
      case 'user-not-found': return 'No existe una cuenta con este email';
      case 'wrong-password': return 'Contraseña incorrecta';
      case 'invalid-email': return 'El email no es válido';
      case 'user-disabled': return 'Esta cuenta está desactivada';
      case 'too-many-requests': return 'Demasiados intentos, espera unos minutos';
      case 'network-request-failed': return 'Sin conexión a internet';
      case 'invalid-credential': return 'Email o contraseña incorrectos';
      default: return 'Error de autenticación';
    }
  }

  Future<void> crearAdminInicial() async {}
}