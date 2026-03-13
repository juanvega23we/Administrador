// lib/services/super_admin_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class SuperAdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ✅ Región explícita para evitar CORS en Flutter Web
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<bool> esSuperAdmin() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      final doc = await _db.collection('administradores').doc(user.uid).get();
      if (!doc.exists) return false;
      return doc.data()?['rol'] == 'super_admin';
    } catch (_) {
      return false;
    }
  }

  // ── Crear admin usando Firebase Function (no cierra sesión) ──
  Future<Map<String, dynamic>> crearAdmin({
    required String nombre,
    required String email,
    required String password,
    required String negocio,
    required DateTime fechaVencimiento,
  }) async {
    try {
      final callable = _functions.httpsCallable(
        'crearAdminUsuario',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 60),
        ),
      );

      final result = await callable.call({
        'nombre':           nombre.trim(),
        'email':            email.trim(),
        'password':         password.trim(),
        'negocio':          negocio.trim(),
        'fechaVencimiento': fechaVencimiento.toIso8601String(),
      });

      return {
        'exito':   true,
        'mensaje': result.data['mensaje'] ?? 'Administrador creado',
        'uid':     result.data['uid'],
      };
    } on FirebaseFunctionsException catch (e) {
      String msg;
      switch (e.code) {
        case 'already-exists':
          msg = 'Este email ya está registrado';
          break;
        case 'permission-denied':
          msg = 'No tienes permisos para crear admins';
          break;
        case 'unauthenticated':
          msg = 'Sesión expirada, vuelve a iniciar sesión';
          break;
        case 'invalid-argument':
          msg = 'Faltan campos requeridos';
          break;
        default:
          msg = e.message ?? 'Error al crear administrador';
      }
      return {'exito': false, 'mensaje': msg};
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error inesperado: $e'};
    }
  }

  // ── Obtener todos los admins ───────────────────────────────
  Stream<QuerySnapshot> obtenerAdmins() {
    return _db
        .collection('administradores')
        .where('rol', isEqualTo: 'admin')
        .snapshots();
  }

  // ── Bloquear / desbloquear ────────────────────────────────
  Future<bool> toggleActivo(String uid, bool nuevoEstado) async {
    try {
      await _db.collection('administradores').doc(uid).update({
        'activo': nuevoEstado,
        'actualizadoEn': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Renovar licencia ──────────────────────────────────────
  Future<bool> actualizarVencimiento(String uid, DateTime nuevaFecha) async {
    try {
      await _db.collection('administradores').doc(uid).update({
        'fechaVencimiento': Timestamp.fromDate(nuevaFecha),
        'activo':           true,
        'actualizadoEn':    FieldValue.serverTimestamp(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Eliminar admin ────────────────────────────────────────
  Future<bool> eliminarAdmin(String uid) async {
    try {
      await _db.collection('administradores').doc(uid).delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Verificar vencimientos ────────────────────────────────
  Future<void> verificarVencimientos() async {
    try {
      final ahora = Timestamp.now();
      final snap = await _db
          .collection('administradores')
          .where('rol', isEqualTo: 'admin')
          .where('activo', isEqualTo: true)
          .get();
      for (var doc in snap.docs) {
        final venc = doc.data()['fechaVencimiento'] as Timestamp?;
        if (venc != null && venc.compareTo(ahora) < 0) {
          await doc.reference.update({'activo': false});
        }
      }
    } catch (_) {}
  }
}