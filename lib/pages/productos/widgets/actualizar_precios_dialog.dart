// lib/pages/productos/widgets/actualizar_precios_dialog.dart

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../../../services/producto_service_admin.dart';
import '../../../services/actualizacion_precios_service.dart';
import '../../../widgets/notificacion_personalizada.dart';

class ActualizarPreciosDialog extends StatefulWidget {
  final ProductoServiceAdmin servicio;

  const ActualizarPreciosDialog({super.key, required this.servicio});

  static void mostrar(BuildContext context,
      {required ProductoServiceAdmin servicio}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ActualizarPreciosDialog(servicio: servicio),
    );
  }

  @override
  State<ActualizarPreciosDialog> createState() =>
      _ActualizarPreciosDialogState();
}

class _ActualizarPreciosDialogState extends State<ActualizarPreciosDialog> {
  late final ActualizacionPreciosService _preciosSvc;

  bool   _descargando = false;
  bool   _subiendo    = false;
  String _estadoTexto = '';

  ResultadoActualizacion? _resultado;

  @override
  void initState() {
    super.initState();
    _preciosSvc = ActualizacionPreciosService(widget.servicio);
  }

  // ── 1. Descargar plantilla (Flutter Web — dart:html) ─────────
  Future<void> _descargarPlantilla() async {
    if (!mounted) return;
    setState(() {
      _descargando = true;
      _estadoTexto = 'Generando plantilla...';
      _resultado   = null;
    });

    try {
      final bytes = await _preciosSvc.generarPlantillaExcel();

      final blob = html.Blob(
        [bytes],
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      final url    = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'plantilla_precios_${_timestamp()}.xlsx')
        ..click();
      html.Url.revokeObjectUrl(url);

      if (!mounted) return;
      NotificacionPersonalizada.mostrarSnack(
        context,
        mensaje: 'Plantilla descargada correctamente',
        tipo: TipoNotificacion.exito,
      );
    } catch (e) {
      if (!mounted) return;
      NotificacionPersonalizada.mostrarSnack(
        context,
        mensaje: 'Error al generar la plantilla: $e',
        tipo: TipoNotificacion.error,
      );
    } finally {
      if (mounted) setState(() { _descargando = false; _estadoTexto = ''; });
    }
  }

  // ── 2. Subir Excel y actualizar precios ───────────────────────
  Future<void> _subirExcel() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;

    final bytes = picked.files.first.bytes;
    if (bytes == null) {
      if (!mounted) return;
      NotificacionPersonalizada.mostrarSnack(
        context,
        mensaje: 'No se pudo leer el archivo',
        tipo: TipoNotificacion.error,
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aplicar cambios de precios'),
        content: Text(
          'Archivo: ${picked.files.first.name}\n\n'
          'Solo se actualizarán los productos cuyo precio haya cambiado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sí, actualizar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() {
      _subiendo    = true;
      _estadoTexto = 'Comparando precios y aplicando cambios...';
      _resultado   = null;
    });

    ResultadoActualizacion? res;
    String? errorMsg;

    try {
      res = await _preciosSvc.procesarExcelPrecios(bytes);
    } catch (e) {
      errorMsg = e.toString();
    }

    if (!mounted) return;
    setState(() {
      _subiendo    = false;
      _estadoTexto = '';
      _resultado   = res;
    });

    if (errorMsg != null) {
      NotificacionPersonalizada.mostrarSnack(
        context,
        mensaje: 'Error: $errorMsg',
        tipo: TipoNotificacion.error,
      );
    }
  }

  String _timestamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final ocupado = _descargando || _subiendo;

    return AlertDialog(
      backgroundColor: const Color(0xFFF0FAF9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: EdgeInsets.zero,
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),

      title: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 8, 14),
        decoration: const BoxDecoration(
          color: Colors.teal,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Row(
          children: [
            const Icon(Icons.price_change_rounded,
                color: Colors.white, size: 24),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Actualización Masiva de Precios',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              onPressed: ocupado ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Colors.white),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: 20,
            ),
          ],
        ),
      ),

      content: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Instrucciones
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.info_outline,
                          size: 16, color: Colors.blue[700]),
                      const SizedBox(width: 6),
                      Text('¿Cómo funciona?',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[800])),
                    ]),
                    const SizedBox(height: 8),
                    _Paso(numero: '1',
                        texto: 'Descarga la plantilla — ya trae todos los productos con sus precios actuales.'),
                    _Paso(numero: '2',
                        texto: 'Edita las columnas "Precio" y "Precio Proveedor" en Excel.'),
                    _Paso(numero: '3',
                        texto: 'Sube el archivo. Solo se actualizarán los productos que cambiaron.'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Botón 1: Descargar
              ElevatedButton.icon(
                onPressed: ocupado ? null : _descargarPlantilla,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: _descargando
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download_rounded, size: 22),
                label: Text(
                  _descargando ? 'Generando...' : '⬇  Descargar plantilla Excel',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 12),

              Row(children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('luego',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ),
                const Expanded(child: Divider()),
              ]),
              const SizedBox(height: 12),

              // Botón 2: Subir
              ElevatedButton.icon(
                onPressed: ocupado ? null : _subirExcel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: _subiendo
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.upload_rounded, size: 22),
                label: Text(
                  _subiendo ? 'Procesando...' : '⬆  Subir precios (.xlsx)',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),

              // Estado mientras procesa
              if (_subiendo && _estadoTexto.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(children: [
                  const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.teal),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_estadoTexto,
                        style: const TextStyle(
                            color: Colors.teal, fontSize: 13)),
                  ),
                ]),
              ],

              // Resultado cuando terminó
              if (!_subiendo && _resultado != null) ...[
                const SizedBox(height: 16),
                _ResultadoPanel(resultado: _resultado!),
              ],
            ],
          ),
        ),
      ),

      actions: [
        TextButton(
          onPressed: ocupado ? null : () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

// ── Paso numerado ─────────────────────────────────────────────
class _Paso extends StatelessWidget {
  final String numero;
  final String texto;
  const _Paso({required this.numero, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18, height: 18,
            decoration: const BoxDecoration(
                color: Colors.teal, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(numero,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(texto,
                style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          ),
        ],
      ),
    );
  }
}

// ── Panel de resultado ────────────────────────────────────────
class _ResultadoPanel extends StatelessWidget {
  final ResultadoActualizacion resultado;
  const _ResultadoPanel({required this.resultado});

  @override
  Widget build(BuildContext context) {
    // Caso especial: nadie cambió nada
    if (resultado.total == 0 && resultado.errores.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.blue.shade300),
        ),
        child: Row(children: [
          Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Ningún precio fue modificado en el archivo.\n'
              'Los ${resultado.sinCambios} productos ya tenían esos precios.',
              style: TextStyle(fontSize: 12, color: Colors.blue[800]),
            ),
          ),
        ]),
      );
    }

    final hayErrores = resultado.errores.isNotEmpty;
    final color = resultado.fallidos == 0 ? Colors.green : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(
              resultado.fallidos == 0
                  ? Icons.check_circle
                  : Icons.warning_amber_rounded,
              color: color, size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                resultado.fallidos == 0
                    ? '¡Actualización completada!'
                    : 'Completado con advertencias',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: resultado.fallidos == 0
                        ? Colors.green[800]
                        : Colors.orange[800]),
              ),
            ),
          ]),
          const SizedBox(height: 10),

          // Estadísticas
          _Stat('Precios modificados en el Excel',
              resultado.total.toString()),
          _Stat('Actualizados en la app',
              resultado.exitosos.toString(),
              color: Colors.green[700]),
          if (resultado.sinCambios > 0)
            _Stat('Sin cambios (omitidos)',
                resultado.sinCambios.toString(),
                color: Colors.grey[600]),
          if (resultado.fallidos > 0)
            _Stat('Con errores',
                resultado.fallidos.toString(),
                color: Colors.red[700]),

          // Detalle errores
          if (hayErrores) ...[
            const Divider(height: 14),
            Text('Detalle de errores:',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.red[700])),
            const SizedBox(height: 4),
            ...resultado.errores.take(5).map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('• $e',
                      style: TextStyle(
                          fontSize: 11, color: Colors.red[600])),
                )),
            if (resultado.errores.length > 5)
              Text('... y ${resultado.errores.length - 5} más',
                  style: TextStyle(
                      fontSize: 11, color: Colors.red[400])),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String valor;
  final Color? color;
  const _Stat(this.label, this.valor, {this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          ),
          Text(valor,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color ?? Colors.grey[800])),
        ],
      ),
    );
  }
}