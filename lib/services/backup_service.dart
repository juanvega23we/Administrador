// lib/services/backup_service.dart

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';

class BackupService {
  final FirebaseFirestore _db      = FirebaseFirestore.instance;
  final FirebaseStorage   _storage = FirebaseStorage.instance;
  final FirebaseAuth      _auth    = FirebaseAuth.instance;

  static const _colecciones = [
    'pedido',
    'productos',
    'usuarios',
    'detalle_pedido',
    'venta',
  ];

  // ─────────────────────────────────────────────────────────────
  // 1. EXPORTAR LOCAL
  // ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> exportarLocal() async {
    try {
      final resultado = await _leerFirestore();
      final jsonStr   = _construirJson(resultado['datos'], resultado['totalDocs']);
      final fecha     = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
      final archivo   = 'backup_$fecha.json';

      final bytes  = utf8.encode(jsonStr);
      final blob   = html.Blob([bytes], 'application/json');
      final url    = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..download = archivo
        ..style.display = 'none';
      html.document.body!.children.add(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);

      return {
        'exito': true,
        'archivo': archivo,
        'totalDocs': resultado['totalDocs'],
        'fecha': DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
      };
    } catch (e) {
      return {'exito': false, 'error': e.toString()};
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 2. BACKUP AUTOMÁTICO
  // ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> backupAutomatico() async {
    final ahora = DateTime.now();
    try {
      final resultado = await _leerFirestore();
      final jsonStr   = _construirJson(resultado['datos'], resultado['totalDocs']);
      final fechaStr  = DateFormat('yyyy-MM-dd_HH-mm-ss').format(ahora);
      final ruta      = 'backups/sistema/backup_$fechaStr.json';

      final uploadTask = await _storage.ref().child(ruta).putData(
        Uint8List.fromList(utf8.encode(jsonStr)),
        SettableMetadata(contentType: 'application/json'),
      );

      final tamanoKB = ((uploadTask.metadata?.size ?? 0) / 1024).round();

      // ✅ Registrar en Firestore para que el banner lo muestre
      await _db.collection('sistema').doc('ultimoBackup').set({
        'fecha':      Timestamp.fromDate(ahora),
        'exito':      true,
        'ruta':       ruta,
        'totalDocs':  resultado['totalDocs'],
        'tamanoKB':   tamanoKB,
        'error':      null,
      });

      await _limpiarBackupsViejos();

      return {
        'exito':     true,
        'ruta':      ruta,
        'totalDocs': resultado['totalDocs'],
        'tamanoKB':  tamanoKB,
        'fecha':     DateFormat('dd/MM/yyyy HH:mm').format(ahora),
      };
    } catch (e) {
      // ✅ Registrar también el fallo en Firestore
      await _db.collection('sistema').doc('ultimoBackup').set({
        'fecha':     Timestamp.fromDate(ahora),
        'exito':     false,
        'error':     e.toString(),
        'totalDocs': 0,
        'tamanoKB':  0,
      }).catchError((_) {});
      return {'exito': false, 'error': e.toString()};
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 3. LISTAR backups en Storage
  // ─────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> listarBackups() async {
    try {
      print('🔍 [BackupService] Listando backups en backups/sistema...');
      final list = await _storage.ref().child('backups/sistema').listAll();
      print('🔍 [BackupService] Archivos encontrados: ${list.items.length}');

      final backups = <Map<String, dynamic>>[];
      for (final item in list.items) {
        print('🔍 [BackupService] Archivo: ${item.fullPath}');
        final meta = await item.getMetadata();
        backups.add({
          'nombre': item.name,
          'ruta':   item.fullPath,
          'fecha':  meta.timeCreated != null
              ? DateFormat('dd/MM/yyyy HH:mm').format(meta.timeCreated!)
              : '—',
          'size':   _formatSize(meta.size ?? 0),
          'auto':   item.name.contains('auto'),
        });
      }

      backups.sort((a, b) => b['nombre'].compareTo(a['nombre']));
      print('✅ [BackupService] Backups cargados: ${backups.length}');
      return backups;
    } catch (e) {
      print('❌ [BackupService] ERROR listarBackups: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 4. RESTAURAR desde Storage
  // ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> restaurarDesdeStorage(String ruta) async {
    try {
      final bytes = await _storage.ref().child(ruta).getData();
      if (bytes == null) return {'exito': false, 'error': 'No se pudo leer el archivo'};
      return _restaurar(utf8.decode(bytes));
    } catch (e) {
      return {'exito': false, 'error': e.toString()};
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 5. RESTAURAR desde archivo local
  // ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> restaurarDesdeArchivo(Uint8List bytes) async {
    if (bytes.isEmpty) return {'exito': false, 'error': 'El archivo esta vacio'};
    if (bytes.length < 50) return {'exito': false, 'error': 'El archivo es demasiado pequeno'};

    String jsonStr;
    try {
      jsonStr = utf8.decode(bytes);
    } catch (_) {
      return {'exito': false, 'error': 'El archivo no es texto valido'};
    }
    if (jsonStr.trim().isEmpty) return {'exito': false, 'error': 'El archivo esta vacio'};

    try {
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      if (!decoded.containsKey('metadata') || !decoded.containsKey('datos')) {
        return {'exito': false, 'error': 'El archivo no es un backup valido — falta estructura'};
      }
      if (decoded['datos'] is! Map) return {'exito': false, 'error': 'El archivo esta corrupto'};
      final totalDocs = (decoded['metadata']?['totalDocumentos'] ?? 0) as int;
      if (totalDocs == 0) return {'exito': false, 'error': 'El backup no tiene documentos'};
    } catch (_) {
      return {'exito': false, 'error': 'El archivo no es un JSON valido'};
    }

    try {
      return _restaurar(jsonStr);
    } catch (e) {
      return {'exito': false, 'error': 'Error al restaurar: ${e.toString()}'};
    }
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS PRIVADOS
  // ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _leerFirestore() async {
    final Map<String, dynamic> datos = {};
    int totalDocs = 0;
    for (final col in _colecciones) {
      try {
        final snap = await _db.collection(col).get();
        datos[col] = {};
        for (final doc in snap.docs) {
          datos[col][doc.id] = _serializar(doc.data());
          totalDocs++;
        }
      } catch (_) {
        datos[col] = {};
      }
    }
    return {'datos': datos, 'totalDocs': totalDocs};
  }

  String _construirJson(Map<String, dynamic> datos, int totalDocs) {
    return const JsonEncoder.withIndent('  ').convert({
      'metadata': {
        'fecha': DateTime.now().toIso8601String(),
        'version': '1.0',
        'colecciones': _colecciones,
        'totalDocumentos': totalDocs,
      },
      'datos': datos,
    });
  }

  Future<Map<String, dynamic>> _restaurar(String jsonStr) async {
    try {
      final decoded     = jsonDecode(jsonStr) as Map<String, dynamic>;
      final datosBackup = decoded['datos'] as Map<String, dynamic>;
      int restaurados   = 0;
      int errores       = 0;

      for (final colNombre in datosBackup.keys) {
        final docs = datosBackup[colNombre] as Map<String, dynamic>;
        for (final docId in docs.keys) {
          try {
            final data = _deserializar(docs[docId]) as Map<String, dynamic>;
            await _db.collection(colNombre).doc(docId).set(data);
            restaurados++;
          } catch (_) {
            errores++;
          }
        }
      }

      return {'exito': true, 'restaurados': restaurados, 'errores': errores};
    } catch (e) {
      return {'exito': false, 'error': 'JSON inválido: ${e.toString()}'};
    }
  }

  Future<void> _limpiarBackupsViejos() async {
    try {
      final list   = await _storage.ref().child('backups/sistema').listAll();
      final limite = DateTime.now().subtract(const Duration(days: 30));

      for (final item in list.items) {
        try {
          final meta = await item.getMetadata();
          if (meta.timeCreated != null && meta.timeCreated!.isBefore(limite)) {
            await item.delete();
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  dynamic _serializar(dynamic v) {
    if (v is Map<String, dynamic>) return v.map((k, val) => MapEntry(k, _serializar(val)));
    if (v is List)      return v.map(_serializar).toList();
    if (v is Timestamp) return {'__tipo': 'Timestamp', 'iso': v.toDate().toIso8601String()};
    if (v is GeoPoint)  return {'__tipo': 'GeoPoint',  'lat': v.latitude, 'lng': v.longitude};
    return v;
  }

  dynamic _deserializar(dynamic v) {
    if (v is Map<String, dynamic>) {
      if (v['__tipo'] == 'Timestamp') return Timestamp.fromDate(DateTime.parse(v['iso']));
      if (v['__tipo'] == 'GeoPoint')  return GeoPoint(v['lat'] as double, v['lng'] as double);
      return v.map((k, val) => MapEntry(k, _deserializar(val)));
    }
    if (v is List) return v.map(_deserializar).toList();
    return v;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024)        return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}