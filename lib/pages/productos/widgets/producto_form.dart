// lib/pages/productos/widgets/producto_form.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../../services/producto_service_admin.dart';
import '../../../widgets/notificacion_personalizada.dart';

// ── Formatters ────────────────────────────────────────────────
class _SoloLetrasFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final soloLetras = RegExp(r"^[a-zA-ZáéíóúÁÉÍÓÚüÜñÑ\s]*$");
    return soloLetras.hasMatch(newValue.text) ? newValue : oldValue;
  }
}

class _SoloNumerosFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final soloNumeros = RegExp(r"^\d*$");
    return soloNumeros.hasMatch(newValue.text) ? newValue : oldValue;
  }
}

class ProductoForm {
  static void mostrar(
    BuildContext context, {
    required List<String> categorias,
    required ProductoServiceAdmin servicio,
    Map<String, dynamic>? productoExistente,
    String? categoriaInicial,
  }) {
    showDialog(
      context: context,
      builder: (_) => _ProductoFormDialog(
        categorias: categorias,
        servicio: servicio,
        productoExistente: productoExistente,
        categoriaInicial: categoriaInicial,
      ),
    );
  }
}

class _ProductoFormDialog extends StatefulWidget {
  final List<String> categorias;
  final ProductoServiceAdmin servicio;
  final Map<String, dynamic>? productoExistente;
  final String? categoriaInicial;

  const _ProductoFormDialog({
    required this.categorias,
    required this.servicio,
    this.productoExistente,
    this.categoriaInicial,
  });

  bool get esEdicion => productoExistente != null;

  @override
  State<_ProductoFormDialog> createState() => _ProductoFormDialogState();
}

class _ProductoFormDialogState extends State<_ProductoFormDialog> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _precioCtrl;
  late final TextEditingController _subtextoCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _codigoCtrl;

  String?             _categoriaSeleccionada;
  String              _imagenUrlExistente = '';
  Uint8List?          _imagenBytesNueva;
  bool                _guardando          = false;
  Map<String, String> _mapaPrefijos       = {};
  String?             _categoriaSugerida;

  // ── Errores de validación ─────────────────────────────────
  bool _intentoGuardar    = false;
  bool get _errorImagen    => _intentoGuardar && _imagenBytesNueva == null && _imagenUrlExistente.isEmpty;
  bool get _errorCodigo    => _intentoGuardar && _codigoCtrl.text.trim().isEmpty;
  bool get _errorNombre    => _intentoGuardar && _nombreCtrl.text.trim().isEmpty;
  bool get _errorPrecio    => _intentoGuardar && _precioCtrl.text.trim().isEmpty;
  bool get _errorStock     => _intentoGuardar && _stockCtrl.text.trim().isEmpty;
  bool get _errorDescripcion => _intentoGuardar && _subtextoCtrl.text.trim().isEmpty;
  // _errorCategoria eliminado — categoría es opcional

  // ── Límites ───────────────────────────────────────────────
  static const int _maxNombre      = 100;
  static const int _maxDescripcion = 100;
  static const int _maxStock       = 20;
  static const int _maxPrecio      = 15;

  @override
  void initState() {
    super.initState();
    final p = widget.productoExistente;

    _nombreCtrl   = TextEditingController(text: p?['nombre']   ?? '');
    _precioCtrl   = TextEditingController(text: p?['precio']?.toString()  ?? '');
    _subtextoCtrl = TextEditingController(text: p?['subtexto'] ?? '');
    _stockCtrl    = TextEditingController(text: p != null ? (p['stock'] ?? 0).toString() : '');
    _codigoCtrl   = TextEditingController(text: p?['codigo']?.toString()  ?? '');

    final img = p?['imagen'] as String? ?? '';
    _imagenUrlExistente = img.startsWith('http') ? img : '';

    final catProducto = p?['categoria'] as String? ?? '';
    if (widget.categorias.contains(catProducto)) {
      _categoriaSeleccionada = catProducto;
    } else if (widget.categoriaInicial != null &&
        widget.categorias.contains(widget.categoriaInicial)) {
      _categoriaSeleccionada = widget.categoriaInicial!;
    } else {
      _categoriaSeleccionada = null;
    }

    _nombreCtrl.addListener(() => setState(() {}));
    _precioCtrl.addListener(() => setState(() {}));
    _subtextoCtrl.addListener(() => setState(() {}));
    _stockCtrl.addListener(() => setState(() {}));
    _codigoCtrl.addListener(() => setState(() {}));

    _cargarPrefijos();
  }

  Future<void> _cargarPrefijos() async {
    final mapa = await widget.servicio.obtenerMapaPrefijos();
    if (!mounted) return;
    setState(() {
      _mapaPrefijos = mapa;
      final codigo = _codigoCtrl.text;
      if (codigo.length >= 2) {
        _categoriaSugerida = _mapaPrefijos[codigo.substring(0, 2)];
      }
    });
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _precioCtrl.dispose();
    _subtextoCtrl.dispose();
    _stockCtrl.dispose();
    _codigoCtrl.dispose();
    super.dispose();
  }

  void _onCodigoChanged(String valor) {
    if (valor.length >= 2) {
      final sugerida = _mapaPrefijos[valor.substring(0, 2)];
      setState(() {
        _categoriaSugerida = sugerida;
        if (sugerida != null && widget.categorias.contains(sugerida)) {
          _categoriaSeleccionada = sugerida;
        }
      });
    } else {
      setState(() => _categoriaSugerida = null);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile  = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (xfile != null) {
      final bytes = await xfile.readAsBytes();
      setState(() => _imagenBytesNueva = bytes);
    }
  }

  // ── Validar todos los campos ──────────────────────────────
  bool _validar() {
    return _codigoCtrl.text.trim().isNotEmpty &&
        _nombreCtrl.text.trim().isNotEmpty &&
        _precioCtrl.text.trim().isNotEmpty &&
        _stockCtrl.text.trim().isNotEmpty &&
        _subtextoCtrl.text.trim().isNotEmpty &&
        (_imagenBytesNueva != null || _imagenUrlExistente.isNotEmpty);
    // categoría ya no es obligatoria
  }

  Future<void> _guardar() async {
    setState(() => _intentoGuardar = true);

    if (!_validar()) {
      NotificacionPersonalizada.mostrarSnack(
        context,
        mensaje: 'Completa todos los campos obligatorios',
        tipo: TipoNotificacion.error,
      );
      return;
    }

    setState(() => _guardando = true);

    String? urlSubida;
    if (_imagenBytesNueva != null) {
      final nombreArchivo = widget.esEdicion
          ? '${widget.productoExistente!['id']}_${DateTime.now().millisecondsSinceEpoch}.jpg'
          : '${DateTime.now().millisecondsSinceEpoch}.jpg';
      urlSubida = await widget.servicio.subirImagen(
        bytes: _imagenBytesNueva!, nombreArchivo: nombreArchivo,
      );
      if (urlSubida == null && mounted) {
        NotificacionPersonalizada.mostrarSnack(
          context, mensaje: 'Error al subir la imagen',
          tipo: TipoNotificacion.error,
        );
        setState(() => _guardando = false);
        return;
      }
    }

    final imagenFinal = urlSubida ?? _imagenUrlExistente;
    Map<String, dynamic> resultado;

    if (widget.esEdicion) {
      resultado = await widget.servicio.actualizarProducto(
        idProducto: widget.productoExistente!['id'],
        nombre:    _nombreCtrl.text.trim(),
        precio:    double.tryParse(_precioCtrl.text) ?? 0,
        subtexto:  _subtextoCtrl.text.trim(),
        categoria: _categoriaSeleccionada ?? '',
        imagenUrl: imagenFinal,
        stock:     int.tryParse(_stockCtrl.text) ?? 0,
        codigo:    _codigoCtrl.text.trim(),
      );
    } else {
      resultado = await widget.servicio.crearProducto(
        nombre:    _nombreCtrl.text.trim(),
        precio:    double.tryParse(_precioCtrl.text) ?? 0,
        categoria: _categoriaSeleccionada ?? '',
        subtexto:  _subtextoCtrl.text.trim(),
        idAdmin:   'admin',
        imagenUrl: imagenFinal,
        stock:     int.tryParse(_stockCtrl.text) ?? 0,
        codigo:    _codigoCtrl.text.trim(),
      );
    }

    if (mounted) {
      Navigator.pop(context);
      NotificacionPersonalizada.mostrarSnack(
        context,
        mensaje: resultado['mensaje'],
        tipo: resultado['exito'] ? TipoNotificacion.exito : TipoNotificacion.error,
      );
    }
  }

  // ── Color del contador ────────────────────────────────────
  Color _colorContador(int actual, int maximo) {
    final pct = actual / maximo;
    if (pct >= 1.0)  return Colors.red;
    if (pct >= 0.85) return Colors.orange;
    return Colors.grey;
  }

  Widget _contador(int actual, int maximo) => Text(
        '$actual/$maximo',
        style: TextStyle(
          fontSize: 11,
          color: _colorContador(actual, maximo),
          fontWeight: actual >= maximo ? FontWeight.bold : FontWeight.normal,
        ),
      );

  // ── Borde del campo según error ───────────────────────────
  InputBorder _borde(bool hayError) => OutlineInputBorder(
        borderSide: BorderSide(
          color: hayError ? Colors.red : Colors.grey.shade400,
          width: hayError ? 1.8 : 1.0,
        ),
      );

  InputDecoration _deco({
    required String label,
    required bool hayError,
    String? helper,
    String? hint,
    Widget? prefix,
    Widget? suffix,
    BoxConstraints? suffixConstraints,
    String? prefixText,
    String? suffixText,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: hayError ? Colors.red : null),
      hintText: hint,
      helperText: hayError ? '⚠ Campo obligatorio' : helper,
      helperStyle: TextStyle(
        color: hayError ? Colors.red : Colors.grey[600],
        fontSize: 11,
      ),
      border: _borde(false),
      enabledBorder: _borde(hayError),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: hayError ? Colors.red : Colors.teal,
          width: 2,
        ),
      ),
      filled: true,
      fillColor: hayError ? Colors.red.withOpacity(0.04) : Colors.white,
      prefixIcon: prefix,
      prefixText: prefixText,
      suffixText: suffixText,
      suffixIcon: suffix,
      suffixIconConstraints: suffixConstraints,
    );
  }

  @override
  Widget build(BuildContext context) {
    final nombreLen  = _nombreCtrl.text.length;
    final precioLen  = _precioCtrl.text.length;
    final descripLen = _subtextoCtrl.text.length;
    final stockLen   = _stockCtrl.text.length;

    return AlertDialog(
      backgroundColor: const Color(0xFFF0FAF9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: EdgeInsets.zero,
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),

      // ── Título ──────────────────────────────────────────────
      title: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 8, 14),
        decoration: const BoxDecoration(
          color: Colors.teal,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.esEdicion ? 'Editar Producto' : 'Nuevo Producto',
              style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700,
              ),
            ),
            IconButton(
              onPressed: _guardando ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Colors.white),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: 20,
            ),
          ],
        ),
      ),

      // ── Contenido ───────────────────────────────────────────
      content: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              // ── Imagen + Código ──────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Imagen con borde de error
                  Column(
                    children: [
                      _ImagenSelector(
                        imagenBytes: _imagenBytesNueva,
                        imagenUrl: _imagenUrlExistente,
                        hayError: _errorImagen,
                        onTap: _pickImage,
                        onRemover: () => setState(() => _imagenBytesNueva = null),
                      ),
                      if (_errorImagen) ...[
                        const SizedBox(height: 4),
                        const Text('⚠ Obligatoria',
                            style: TextStyle(fontSize: 10, color: Colors.red)),
                      ],
                    ],
                  ),
                  const SizedBox(width: 12),

                  // Código
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _codigoCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [_SoloNumerosFormatter()],
                          onChanged: _onCodigoChanged,
                          decoration: _deco(
                            label: 'Código',
                            hayError: _errorCodigo,
                            hint: 'Ej: 2233443',
                            helper: 'Solo números',
                            prefix: Icon(Icons.qr_code,
                                color: _errorCodigo ? Colors.red : Colors.teal),
                          ),
                        ),
                        const SizedBox(height: 6),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _categoriaSugerida != null
                              ? Container(
                                  key: const ValueKey('sugerencia'),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors.teal.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.auto_awesome,
                                          size: 12, color: Colors.teal),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          _categoriaSugerida!,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.teal,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox(key: ValueKey('vacio'), height: 0),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Nombre ──────────────────────────────────────
              TextField(
                controller: _nombreCtrl,
                inputFormatters: [
                  _SoloLetrasFormatter(),
                  LengthLimitingTextInputFormatter(_maxNombre),
                ],
                textCapitalization: TextCapitalization.words,
                decoration: _deco(
                  label: 'Nombre del producto',
                  hayError: _errorNombre,
                  helper: 'Solo letras · Máx. $_maxNombre caracteres',
                  suffix: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _contador(nombreLen, _maxNombre),
                  ),
                  suffixConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                ),
              ),
              const SizedBox(height: 14),

              // ── Precio y Stock ───────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _precioCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        _SoloNumerosFormatter(),
                        LengthLimitingTextInputFormatter(_maxPrecio),
                      ],
                      decoration: _deco(
                        label: 'Precio',
                        hayError: _errorPrecio,
                        prefixText: '\$ ',
                        helper: 'Solo números · Máx. $_maxPrecio dígitos',
                        suffix: Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: _contador(precioLen, _maxPrecio),
                        ),
                        suffixConstraints:
                            const BoxConstraints(minWidth: 0, minHeight: 0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _stockCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(_maxStock),
                      ],
                      decoration: _deco(
                        label: 'Stock',
                        hayError: _errorStock,
                        suffixText: 'und',
                        helper: 'Solo números · Máx. $_maxStock dígitos',
                        prefix: Icon(Icons.inventory_2,
                            color: _errorStock ? Colors.red : Colors.teal),
                        suffix: Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: _contador(stockLen, _maxStock),
                        ),
                        suffixConstraints:
                            const BoxConstraints(minWidth: 0, minHeight: 0),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Descripción ──────────────────────────────────
              TextField(
                controller: _subtextoCtrl,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(_maxDescripcion),
                ],
                decoration: _deco(
                  label: 'Descripción (ej: 500g, 1L)',
                  hayError: _errorDescripcion,
                  helper: 'Máx. $_maxDescripcion caracteres',
                  suffix: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _contador(descripLen, _maxDescripcion),
                  ),
                  suffixConstraints:
                      const BoxConstraints(minWidth: 0, minHeight: 0),
                ),
              ),
              const SizedBox(height: 14),

              // ── Categoría (opcional) ─────────────────────────
              DropdownButtonFormField<String>(
                value: _categoriaSeleccionada,
                dropdownColor: Colors.white,
                decoration: InputDecoration(
                  labelText: 'Categoría (opcional)',
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  filled: true,
                  fillColor: _categoriaSugerida != null
                      ? Colors.teal.withOpacity(0.06)
                      : Colors.white,
                  suffixIcon: _categoriaSugerida != null
                      ? const Tooltip(
                          message: 'Asignada automáticamente por el código',
                          child: Icon(Icons.auto_awesome,
                              color: Colors.teal, size: 18),
                        )
                      : null,
                ),
                hint: const Text('Sin categoría',
                    style: TextStyle(color: Colors.grey)),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Sin categoría',
                        style: TextStyle(color: Colors.grey)),
                  ),
                  ...widget.categorias.map((c) =>
                      DropdownMenuItem(value: c, child: Text(c))),
                ],
                onChanged: (v) => setState(() => _categoriaSeleccionada = v),
              ),

              if (_guardando) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(color: Colors.teal),
                const SizedBox(height: 8),
                Text(
                  widget.esEdicion ? 'Actualizando...' : 'Guardando producto...',
                  style: const TextStyle(fontSize: 12, color: Colors.teal),
                ),
              ],
            ],
          ),
        ),
      ),

      // ── Acciones ─────────────────────────────────────────────
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: _guardando ? null : _guardar,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          icon: Icon(widget.esEdicion ? Icons.save_rounded : Icons.add_rounded,
              size: 18),
          label: Text(widget.esEdicion ? 'Guardar' : 'Crear'),
        ),
      ],
    );
  }
}

// ── Selector de imagen compacto ───────────────────────────────
class _ImagenSelector extends StatelessWidget {
  final Uint8List?   imagenBytes;
  final String       imagenUrl;
  final bool         hayError;
  final VoidCallback onTap;
  final VoidCallback onRemover;

  const _ImagenSelector({
    required this.imagenBytes,
    required this.imagenUrl,
    required this.hayError,
    required this.onTap,
    required this.onRemover,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100, height: 100,
        decoration: BoxDecoration(
          color: hayError ? Colors.red.withOpacity(0.04) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hayError
                ? Colors.red
                : imagenBytes != null
                    ? Colors.teal
                    : Colors.grey[300]!,
            width: hayError ? 1.8 : 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: _contenido(),
      ),
    );
  }

  Widget _contenido() {
    if (imagenBytes != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(imagenBytes!, fit: BoxFit.cover),
          Positioned(
            top: 4, right: 4,
            child: GestureDetector(
              onTap: onRemover,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                    color: Colors.red, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      );
    }
    if (imagenUrl.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(imagenUrl, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.broken_image, size: 36)),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              color: Colors.black45,
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: const Text('Cambiar',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 9)),
            ),
          ),
        ],
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_outlined,
            size: 32, color: hayError ? Colors.red[300] : Colors.grey[400]),
        const SizedBox(height: 4),
        Text('Imagen',
            style: TextStyle(
                fontSize: 11,
                color: hayError ? Colors.red[400] : Colors.grey[500])),
      ],
    );
  }
}