// lib/services/actualizacion_precios_service.dart

import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'producto_service_admin.dart';

class ActualizacionPreciosService {
  final ProductoServiceAdmin _servicio;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ActualizacionPreciosService(this._servicio);

  // ── Genera el Excel con los productos actuales ───────────────
  Future<Uint8List> generarPlantillaExcel() async {
    final productos = await _servicio.obtenerTodosLosProductosUnaVez();

    final excel = Excel.createExcel();
    final Sheet hoja = excel['Precios'];

    // Fila 1: instrucción
    final instruccion = hoja.cell(CellIndex.indexByString('A1'));
    instruccion.value = TextCellValue(
        'Solo edita las columnas D (Precio) y E (Precio Proveedor). '
        'No modifiques ID ni Código.');
    instruccion.cellStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#FBE9E7'),
      fontColorHex: ExcelColor.fromHexString('#BF360C'),
      italic: true,
    );
    hoja.merge(
      CellIndex.indexByString('A1'),
      CellIndex.indexByString('F1'),
    );

    // Fila 2: headers
    final headers = [
      'ID',
      'Código',
      'Nombre del Producto',
      'Precio (COP)',
      'Precio Proveedor (COP)',
      'Categoría',
    ];
    for (var i = 0; i < headers.length; i++) {
      final cell = hoja.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#00695C'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        horizontalAlign: HorizontalAlign.Center,
      );
    }

    // Filas de productos (rowIndex empieza en 2 = fila 3 de Excel)
    for (var i = 0; i < productos.length; i++) {
      final p   = productos[i];
      final row = i + 2;

      void celda(int col, CellValue val, {CellStyle? style}) {
        final c = hoja.cell(
            CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
        c.value = val;
        if (style != null) c.cellStyle = style;
      }

      celda(0, TextCellValue(p['id']?.toString() ?? ''),
          style: CellStyle(
            fontColorHex: ExcelColor.fromHexString('#9E9E9E'),
            fontSize: 9,
          ));
      celda(1, TextCellValue(p['codigo']?.toString() ?? ''),
          style: CellStyle(
            bold: true,
            fontColorHex: ExcelColor.fromHexString('#00695C'),
          ));
      celda(2, TextCellValue(p['nombre']?.toString() ?? ''));
      celda(3, DoubleCellValue((p['precio'] as num?)?.toDouble() ?? 0),
          style: CellStyle(
            backgroundColorHex: ExcelColor.fromHexString('#FFF9C4'),
            bold: true,
            fontColorHex: ExcelColor.fromHexString('#1B5E20'),
          ));
      celda(4,
          DoubleCellValue(
              (p['precioProveedor'] as num?)?.toDouble() ?? 0),
          style: CellStyle(
            backgroundColorHex: ExcelColor.fromHexString('#FFF9C4'),
            bold: true,
            fontColorHex: ExcelColor.fromHexString('#1B5E20'),
          ));
      celda(5, TextCellValue(p['categoria']?.toString() ?? ''));
    }

    hoja.setColumnWidth(0, 24);
    hoja.setColumnWidth(1, 12);
    hoja.setColumnWidth(2, 40);
    hoja.setColumnWidth(3, 22);
    hoja.setColumnWidth(4, 26);
    hoja.setColumnWidth(5, 20);

    excel.delete('Sheet1');

    final bytes = excel.encode();
    if (bytes == null) throw Exception('No se pudo generar el Excel');
    return Uint8List.fromList(bytes);
  }

  // ── Procesa el Excel y actualiza SOLO los precios que cambiaron
  // Usa WriteBatch → una sola operación atómica, mucho más rápido.
  Future<ResultadoActualizacion> procesarExcelPrecios(
      Uint8List bytes) async {
    // 1. Decodificar el Excel
    Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (_) {
      throw Exception('El archivo no es un Excel válido (.xlsx)');
    }

    final hoja = excel['Precios'];
    if (hoja == null) {
      throw Exception(
          'El archivo no tiene la hoja "Precios". '
          'Usa la plantilla descargada desde la app.');
    }

    final rows = hoja.rows;
    if (rows.length < 3) {
      throw Exception('El archivo no contiene productos.');
    }

    // 2. Cargar precios actuales de Firestore para comparar
    final productosActuales =
        await _servicio.obtenerTodosLosProductosUnaVez();
    final mapaActual = <String, Map<String, dynamic>>{
      for (final p in productosActuales) p['id'] as String: p,
    };

    // 3. Parsear filas y detectar solo los que cambiaron
    final aActualizar = <_CambiosPrecio>[];
    final errores     = <String>[];
    int sinCambios    = 0;

    for (var i = 2; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      final id     = row[0]?.value?.toString().trim() ?? '';
      final nombre = row[2]?.value?.toString().trim() ?? '';
      if (id.isEmpty) continue;

      final precioRaw    = row.length > 3 ? row[3]?.value : null;
      final proveedorRaw = row.length > 4 ? row[4]?.value : null;

      final nuevoPrecio    = _parsearNumero(precioRaw);
      final nuevoProveedor = _parsearNumero(proveedorRaw);

      if (nuevoPrecio == null || nuevoPrecio < 0) {
        errores.add('Fila ${i + 1} ($nombre): precio inválido');
        continue;
      }
      if (nuevoProveedor == null || nuevoProveedor < 0) {
        errores.add('Fila ${i + 1} ($nombre): precio proveedor inválido');
        continue;
      }

      // Comparar con valores actuales — solo agregar si realmente cambió
      final actual = mapaActual[id];
      if (actual != null) {
        final precioActual    = (actual['precio'] as num?)?.toDouble() ?? 0;
        final proveedorActual =
            (actual['precioProveedor'] as num?)?.toDouble() ?? 0;

        final mismoP = (nuevoPrecio - precioActual).abs() < 0.01;
        final mismoProv = (nuevoProveedor - proveedorActual).abs() < 0.01;

        if (mismoP && mismoProv) {
          sinCambios++;
          continue; // sin cambio real → omitir
        }
      }

      aActualizar.add(_CambiosPrecio(
        id:              id,
        nombre:          nombre,
        precio:          nuevoPrecio,
        precioProveedor: nuevoProveedor,
      ));
    }

    if (aActualizar.isEmpty && errores.isEmpty) {
      // Ningún precio fue modificado en el Excel
      return ResultadoActualizacion(
        total:      0,
        exitosos:   0,
        fallidos:   0,
        sinCambios: sinCambios,
        errores:    errores,
      );
    }

    // 4. Aplicar con WriteBatch (máx 500 docs por batch — Firestore limit)
    int exitosos = 0;
    final chunks = _chunked(aActualizar, 500);

    for (final chunk in chunks) {
      try {
        final batch = _firestore.batch();
        for (final c in chunk) {
          final ref =
              _firestore.collection('productos').doc(c.id);
          batch.update(ref, {
            'precio'             : c.precio,
            'precioProveedor'    : c.precioProveedor,
            'fechaActualizacion' : FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
        exitosos += chunk.length;
      } catch (e) {
        for (final c in chunk) {
          errores.add('${c.nombre}: error al guardar ($e)');
        }
      }
    }

    return ResultadoActualizacion(
      total:      aActualizar.length,
      exitosos:   exitosos,
      fallidos:   aActualizar.length - exitosos,
      sinCambios: sinCambios,
      errores:    errores,
    );
  }

  // ── Helpers ──────────────────────────────────────────────────
  double? _parsearNumero(dynamic raw) {
    if (raw == null) return null;
    if (raw is DoubleCellValue) return raw.value;
    if (raw is IntCellValue)    return raw.value.toDouble();
    final str = raw.toString().replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(str);
  }

  List<List<T>> _chunked<T>(List<T> list, int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += size) {
      chunks.add(list.sublist(
          i, i + size > list.length ? list.length : i + size));
    }
    return chunks;
  }
}

class _CambiosPrecio {
  final String id;
  final String nombre;
  final double precio;
  final double precioProveedor;
  const _CambiosPrecio({
    required this.id,
    required this.nombre,
    required this.precio,
    required this.precioProveedor,
  });
}

class ResultadoActualizacion {
  final int          total;
  final int          exitosos;
  final int          fallidos;
  final int          sinCambios;
  final List<String> errores;
  const ResultadoActualizacion({
    required this.total,
    required this.exitosos,
    required this.fallidos,
    required this.sinCambios,
    required this.errores,
  });
}