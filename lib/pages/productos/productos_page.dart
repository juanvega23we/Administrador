// lib/pages/productos/productos_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/producto_service_admin.dart';
import '../../widgets/notificacion_personalizada.dart';
import 'widgets/producto_card.dart';
import 'widgets/producto_form.dart';
import 'widgets/actualizar_precios_dialog.dart';

const List<Map<String, dynamic>> _iconosCategorias = [
  {'icono': Icons.set_meal,            'label': 'Carnes Frías'},
  {'icono': Icons.egg_alt,             'label': 'Lácteos'},
  {'icono': Icons.egg,                 'label': 'Huevos'},
  {'icono': Icons.water_drop,          'label': 'Salsas/Líquidos'},
  {'icono': Icons.inventory,           'label': 'Enlatados'},
  {'icono': Icons.bakery_dining,       'label': 'Pan/Arepas'},
  {'icono': Icons.ac_unit,             'label': 'Congelados'},
  {'icono': Icons.fastfood,            'label': 'Fritos/Pollo'},
  {'icono': Icons.spa,                 'label': 'Condimentos'},
  {'icono': Icons.cookie,              'label': 'Snacks/Mecato'},
  {'icono': Icons.local_drink,         'label': 'Bebidas'},
  {'icono': Icons.liquor,              'label': 'Licores/Cerveza'},
  {'icono': Icons.takeout_dining,      'label': 'Portacomidas'},
  {'icono': Icons.local_cafe,          'label': 'Vasos/Platos'},
  {'icono': Icons.shopping_bag,        'label': 'Bolsas/Plástico'},
  {'icono': Icons.cleaning_services,   'label': 'Aseo'},
  {'icono': Icons.sanitizer,           'label': 'Desinfección'},
  {'icono': Icons.inventory_2,         'label': 'General'},
];

class ProductosPage extends StatefulWidget {
  const ProductosPage({super.key});
  @override
  State<ProductosPage> createState() => _ProductosPageState();
}

class _ProductosPageState extends State<ProductosPage> {
  final ProductoServiceAdmin _servicio = ProductoServiceAdmin();

  bool   _mostrandoBusqueda = false;
  String _textoBusqueda     = '';
  final TextEditingController _busquedaCtrl  = TextEditingController();
  final FocusNode             _busquedaFocus = FocusNode();

  List<Map<String, dynamic>> _todosLosProductos = [];
  bool _productosListos = false;

  List<String> _categorias = [];
  bool _categoriasListas = false;
  String _categoriaSeleccionada = 'Todo';

  StreamSubscription? _prodSub;
  StreamSubscription? _catSub;

  static const String _tabTodo = 'Todo';

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  void _cargarDatos() {
    _prodSub = _servicio.obtenerTodosLosProductos().listen((lista) {
      if (mounted) {
        setState(() {
          _todosLosProductos = lista;
          _productosListos = true;
        });
      }
    });

    _catSub = _servicio.obtenerCategoriasStream().cast<List<dynamic>>().listen((raw) {
      if (mounted) {
        setState(() {
          _categorias = raw.map((e) {
            if (e is String) return e;
            if (e is Map) return (e['nombre'] ?? '').toString();
            return e.toString();
          }).where((s) => s.isNotEmpty).toList();
          
          _categoriasListas = true;

          // Si la categoría seleccionada ya no existe (y no es Todo), volver a Todo
          if (_categoriaSeleccionada != _tabTodo && !_categorias.contains(_categoriaSeleccionada)) {
            _categoriaSeleccionada = _tabTodo;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    _busquedaFocus.dispose();
    _prodSub?.cancel();
    _catSub?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> get _productosFiltrados {
    final lista = _categoriaSeleccionada == _tabTodo
        ? _todosLosProductos
        : _todosLosProductos.where((p) => p['categoria'] == _categoriaSeleccionada).toList();
        
    if (_textoBusqueda.isEmpty) return lista;
    final query = _textoBusqueda.toLowerCase();
    return lista.where((p) {
      final nombre   = (p['nombre']   ?? '').toString().toLowerCase();
      final cat      = (p['categoria'] ?? '').toString().toLowerCase();
      final subtexto = (p['subtexto'] ?? '').toString().toLowerCase();
      return nombre.contains(query) || cat.contains(query) || subtexto.contains(query);
    }).toList();
  }

  Future<void> _cambiarEstado(String id, bool nuevoEstado) async {
    final r = nuevoEstado ? await _servicio.activarProducto(id) : await _servicio.desactivarProducto(id);
    if (!mounted) return;
    NotificacionPersonalizada.mostrarSnack(context,
        mensaje: r['mensaje'],
        tipo: r['exito'] ? TipoNotificacion.exito : TipoNotificacion.error);
  }

  Future<void> _eliminarProducto(Map<String, dynamic> producto) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Producto'),
        content: Text('¿Eliminar "${producto['nombre']}" permanentemente?\n\nEsta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    final r = await _servicio.eliminarProductoPermanente(producto['id']);
    if (!mounted) return;
    NotificacionPersonalizada.mostrarSnack(context,
        mensaje: r['mensaje'],
        tipo: r['exito'] ? TipoNotificacion.exito : TipoNotificacion.error);
  }

  void _mostrarDialogoCrearCategoria(BuildContext context, List<String> categorias) {
    final ctrlNombre  = TextEditingController();
    final ctrlPrefijo = TextEditingController();
    IconData iconoSeleccionado = Icons.inventory_2;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.create_new_folder_outlined, color: Colors.teal, size: 22),
            SizedBox(width: 8),
            Text('Nueva Categoría'),
          ]),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: ctrlNombre,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la categoría',
                      hintText: 'Ej: Carnes Frías',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrlPrefijo,
                    keyboardType: TextInputType.number,
                    maxLength: 2,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Prefijo (2 dígitos)',
                      hintText: 'Ej: 22',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.tag, color: Colors.teal),
                      counterText: '',
                      helperText: 'Los productos con este prefijo se asignan aquí',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Ícono de la categoría',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _IconSelectorGrid(
                    seleccionado: iconoSeleccionado,
                    onSelect: (ico) => setDialog(() => iconoSeleccionado = ico),
                  ),
                ],
              ),
            ),
          ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () async {
              final nombre  = ctrlNombre.text.trim();
              final prefijo = ctrlPrefijo.text.trim();
              if (nombre.isEmpty) {
                NotificacionPersonalizada.mostrarSnack(context, mensaje: 'Ingresa el nombre', tipo: TipoNotificacion.error);
                return;
              }
              if (prefijo.length != 2) {
                NotificacionPersonalizada.mostrarSnack(context, mensaje: 'El prefijo debe tener 2 dígitos', tipo: TipoNotificacion.error);
                return;
              }
              Navigator.pop(ctx);
              final r = await _servicio.crearCategoria(
                nombre: nombre, 
                prefijo: prefijo,
                iconoCodePoint: iconoSeleccionado.codePoint,
              );
              if (!mounted) return;
              NotificacionPersonalizada.mostrarSnack(context,
                  mensaje: r['mensaje'],
                  tipo: r['exito'] ? TipoNotificacion.exito : TipoNotificacion.error);
            },
            child: const Text('Crear'),
          ),
        ],
      ),
     ),
    );
  }

  void _mostrarDialogoEditarCategoria(BuildContext context, String categoriaActual) async {
    String prefijoActual = '';
    int? iconCode;
    try {
      final catData = await _servicio.obtenerCategoriaPorNombre(categoriaActual);
      if (catData != null) {
        prefijoActual = catData['prefijo']?.toString() ?? '';
        iconCode = catData['iconoCodePoint'] as int?;
      }
    } catch (_) {}

    final ctrlNombre  = TextEditingController(text: categoriaActual);
    final ctrlPrefijo = TextEditingController(text: prefijoActual);
    
    IconData iconoSeleccionado = Icons.inventory_2;
    if (iconCode != null) {
      for (final item in _iconosCategorias) {
        final currentIco = item['icono'] as IconData;
        if (currentIco.codePoint == iconCode) {
          iconoSeleccionado = currentIco;
          break;
        }
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.edit_outlined, color: Colors.teal, size: 22),
            SizedBox(width: 8),
            Text('Editar Categoría'),
          ]),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(
                  controller: ctrlNombre,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrlPrefijo,
                  keyboardType: TextInputType.number,
                  maxLength: 2,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Prefijo (2 dígitos)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.tag, color: Colors.teal),
                    counterText: '',
                    helperText: 'Todos los productos se actualizarán automáticamente',
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Ícono de la categoría',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _IconSelectorGrid(
                  seleccionado: iconoSeleccionado,
                  onSelect: (ico) => setDialog(() => iconoSeleccionado = ico),
                ),
              ]),
            ),
          ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () async {
              final nuevoNombre  = ctrlNombre.text.trim();
              final nuevoPrefijo = ctrlPrefijo.text.trim();
              if (nuevoNombre.isEmpty) {
                NotificacionPersonalizada.mostrarSnack(context,
                    mensaje: 'El nombre no puede estar vacío', tipo: TipoNotificacion.error);
                return;
              }
              if (nuevoPrefijo.length != 2) {
                NotificacionPersonalizada.mostrarSnack(context,
                    mensaje: 'El prefijo debe tener 2 dígitos', tipo: TipoNotificacion.error);
                return;
              }
              Navigator.pop(ctx);
              final r = await _servicio.editarCategoria(
                nombreActual:        categoriaActual,
                nuevoNombre:         nuevoNombre,
                nuevoPrefijo:        nuevoPrefijo,
                nuevoIconoCodePoint: iconoSeleccionado.codePoint,
              );
              if (!mounted) return;
              NotificacionPersonalizada.mostrarSnack(context,
                  mensaje: r['mensaje'],
                  tipo: r['exito'] ? TipoNotificacion.exito : TipoNotificacion.error);
            },
            child: const Text('Guardar'),
          ),
        ],
      ), // Cierra AlertDialog
     ), // Cierra StatefulBuilder
    ); // Cierra showDialog
  }

  void _confirmarEliminarCategoria(BuildContext context, String categoria) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Categoría'),
        content: Text('¿Eliminar "$categoria"?\n\nLos productos seguirán visibles en "Todo".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final r = await _servicio.eliminarCategoria(categoria);
              if (!mounted) return;
              NotificacionPersonalizada.mostrarSnack(context,
                  mensaje: r['mensaje'],
                  tipo: r['exito'] ? TipoNotificacion.exito : TipoNotificacion.error);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String cat) {
    final bool isSelected = _categoriaSeleccionada == cat;
    final bool isTodo = cat == _tabTodo;

    return GestureDetector(
      onTap: () => setState(() => _categoriaSeleccionada = cat),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(right: 12),
        padding: EdgeInsets.only(
          left: 16, 
          right: (isSelected && !isTodo) ? 4 : 16, 
        ),
        decoration: BoxDecoration(
          color: isSelected ? Colors.teal : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? Colors.teal : Colors.grey.shade300,
            width: isSelected ? 0 : 1.5,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.teal.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
              : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (isTodo) ...[
              Icon(Icons.grid_view_rounded, size: 16, color: isSelected ? Colors.white : Colors.black54),
              const SizedBox(width: 8),
            ],
            Text(cat, style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 14,
            )),
            
            // Acciones de categoría (sólo si está seleccionada y no es 'Todo')
            if (isSelected && !isTodo) ...[
              const SizedBox(width: 12),
              Container(width: 1, height: 20, color: Colors.white38),
              const SizedBox(width: 4),
              
              // Botón Editar
              Tooltip(
                message: 'Editar categoría',
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.hardEdge,
                  child: InkWell(
                    onTap: () => _mostrarDialogoEditarCategoria(context, cat),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.edit, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ),
              
              // Botón Eliminar
              Tooltip(
                message: 'Eliminar categoría',
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.hardEdge,
                  child: InkWell(
                    onTap: () => _confirmarEliminarCategoria(context, cat),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.close, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriasBar() {
    if (!_categoriasListas) return const SizedBox.shrink();

    final todasLasTabs = [_tabTodo, ..._categorias];

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), offset: const Offset(0, 2), blurRadius: 4),
        ],
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: todasLasTabs.length + 1,
        itemBuilder: (context, index) {
          if (index == todasLasTabs.length) {
            return Padding(
              padding: const EdgeInsets.only(left: 4),
              child: ActionChip(
                tooltip: 'Crear nueva categoría',
                backgroundColor: Colors.teal.shade50,
                side: BorderSide(color: Colors.teal.shade200),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                label: const Row(
                  children: [
                    Icon(Icons.add, size: 16, color: Colors.teal),
                    SizedBox(width: 6),
                    Text('Categoría', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                onPressed: () => _mostrarDialogoCrearCategoria(context, _categorias),
              ),
            );
          }
          return _buildCategoryChip(todasLasTabs[index]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_productosListos || !_categoriasListas) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F6F8),
        body: Center(child: CircularProgressIndicator(color: Colors.teal)),
      );
    }

    final productos = _productosFiltrados;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: _mostrandoBusqueda
            ? _SearchBar(
                controller: _busquedaCtrl,
                focusNode: _busquedaFocus,
                onChanged: (v) => setState(() => _textoBusqueda = v),
                onClose: () => setState(() {
                  _mostrandoBusqueda = false;
                  _textoBusqueda = '';
                  _busquedaCtrl.clear();
                }),
              )
            : Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.inventory_2_rounded, size: 18, color: Colors.white),
                ),
                const SizedBox(width: 10),
                const Text('Gestionar Productos',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, letterSpacing: -0.3)),
              ]),
        actions: [
          if (!_mostrandoBusqueda) ...[
            _AppBarIconBtn(
              icon: Icons.price_change_rounded,
              tooltip: 'Actualizar precios masivo',
              onTap: () => ActualizarPreciosDialog.mostrar(context, servicio: _servicio),
            ),
            _AppBarIconBtn(
              icon: Icons.search_rounded,
              tooltip: 'Buscar producto',
              onTap: () {
                setState(() => _mostrandoBusqueda = true);
                Future.delayed(const Duration(milliseconds: 100), () => _busquedaFocus.requestFocus());
              },
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCategoriasBar(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: productos.isEmpty
                  ? _EmptyState(
                      key: ValueKey('empty_$_categoriaSeleccionada$_textoBusqueda'),
                      texto: _textoBusqueda.isNotEmpty
                          ? 'Sin resultados para "$_textoBusqueda"'
                          : _categoriaSeleccionada == _tabTodo 
                              ? 'No hay productos todavía' 
                              : 'No hay productos en $_categoriaSeleccionada',
                      accion: _textoBusqueda.isEmpty && _categoriaSeleccionada != _tabTodo
                          ? TextButton.icon(
                              onPressed: () => ProductoForm.mostrar(context,
                                  categorias: _categorias, servicio: _servicio, categoriaInicial: _categoriaSeleccionada),
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.teal.shade50,
                                foregroundColor: Colors.teal.shade700,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                              icon: const Icon(Icons.add_circle_outline),
                              label: const Text('Agregar Primero', style: TextStyle(fontWeight: FontWeight.bold)),
                            )
                          : null,
                    )
                  : ListView.builder(
                      key: ValueKey('list_$_categoriaSeleccionada$_textoBusqueda'),
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
                      itemCount: productos.length,
                      itemBuilder: (_, i) => ProductoCard(
                        producto: productos[i],
                        categorias: _categorias,
                        enTabTodo: _categoriaSeleccionada == _tabTodo,
                        servicio: _servicio,
                        onEditar: (p) => ProductoForm.mostrar(context,
                            categorias: _categorias, servicio: _servicio, productoExistente: p),
                        onCambiarEstado: _cambiarEstado,
                        onEliminar: _categoriaSeleccionada == _tabTodo ? _eliminarProducto : null,
                      ),
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_categorias.isEmpty) {
            NotificacionPersonalizada.mostrarSnack(context,
                mensaje: 'Primero crea una categoría', tipo: TipoNotificacion.advertencia);
            return;
          }
          final catInicial = _categoriaSeleccionada == _tabTodo
              ? (_categorias.isNotEmpty ? _categorias.first : null)
              : _categoriaSeleccionada;
              
          ProductoForm.mostrar(context, categorias: _categorias, servicio: _servicio, categoriaInicial: catInicial);
        },
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo Producto', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _AppBarIconBtn extends StatelessWidget {
  final IconData icon;
  final String   tooltip;
  final VoidCallback onTap;
  const _AppBarIconBtn({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    ),
  );
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;
  const _SearchBar({required this.controller, required this.focusNode, required this.onChanged, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.teal.shade300, width: 1.5),
      ),
      child: Row(children: [
        Tooltip(
          message: 'Cerrar búsqueda',
          child: GestureDetector(
            onTap: onClose,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Icon(Icons.close, color: Colors.teal.shade600, size: 18),
            ),
          ),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: true,
            style: const TextStyle(color: Colors.black87, fontSize: 14),
            cursorColor: Colors.teal,
            decoration: InputDecoration(
              hintText: 'Buscar producto...',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 12),
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String  texto;
  final Widget? accion;
  const _EmptyState({super.key, required this.texto, this.accion});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(color: Colors.teal.shade50, shape: BoxShape.circle),
          child: Icon(Icons.inventory_2_outlined, size: 38, color: Colors.teal.shade300),
        ),
        const SizedBox(height: 20),
        Text(texto, style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w500)),
        if (accion != null) ...[const SizedBox(height: 16), accion!],
      ]),
    );
  }
}

class _IconSelectorGrid extends StatelessWidget {
  final IconData seleccionado;
  final ValueChanged<IconData> onSelect;
  const _IconSelectorGrid({required this.seleccionado, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1,
        ),
        itemCount: _iconosCategorias.length,
        itemBuilder: (_, i) {
          final item = _iconosCategorias[i];
          final sel  = seleccionado == item['icono'];
          return GestureDetector(
            onTap: () => onSelect(item['icono'] as IconData),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: sel ? Colors.teal.shade50 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: sel ? Colors.teal : Colors.grey.shade200, width: sel ? 2 : 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item['icono'] as IconData, color: sel ? Colors.teal : Colors.grey.shade600, size: 24),
                  const SizedBox(height: 3),
                  Text(item['label'] as String,
                    style: TextStyle(
                      fontSize: 9,
                      color: sel ? Colors.teal.shade700 : Colors.grey.shade500,
                      fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
