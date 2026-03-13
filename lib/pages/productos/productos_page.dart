// lib/pages/productos/productos_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/producto_service_admin.dart';
import '../../widgets/notificacion_personalizada.dart';
import 'widgets/producto_card.dart';
import 'widgets/producto_form.dart';

class ProductosPage extends StatefulWidget {
  const ProductosPage({super.key});

  @override
  State<ProductosPage> createState() => _ProductosPageState();
}

class _ProductosPageState extends State<ProductosPage>
    with TickerProviderStateMixin {
  final ProductoServiceAdmin _servicio = ProductoServiceAdmin();

  TabController? _tabController;
  List<String>   _categoriasActuales = [];
  bool           _actualizandoController = false;

  bool   _mostrandoBusqueda = false;
  String _textoBusqueda     = '';
  final TextEditingController _busquedaCtrl  = TextEditingController();
  final FocusNode             _busquedaFocus = FocusNode();

  static const String _tabTodo = 'Todo';

  @override
  void dispose() {
    _tabController?.dispose();
    _busquedaCtrl.dispose();
    _busquedaFocus.dispose();
    super.dispose();
  }

  List<String> _buildTabs(List<String> categorias) =>
      [_tabTodo, ...categorias];

  void _actualizarTabController(List<String> todasLasTabs) {
    if (_actualizandoController) return;

    final mismaLista =
        todasLasTabs.length == _categoriasActuales.length &&
            todasLasTabs.every((c) => _categoriasActuales.contains(c));

    if (mismaLista && _tabController != null) return;

    _actualizandoController = true;

    final indexActual = _tabController?.index ?? 0;
    final nuevoIndex =
        indexActual < todasLasTabs.length ? indexActual : 0;

    final controllerViejo = _tabController;
    final controllerNuevo = TabController(
      length: todasLasTabs.length,
      vsync: this,
      initialIndex: nuevoIndex,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        controllerNuevo.dispose();
        _actualizandoController = false;
        return;
      }
      setState(() {
        _tabController          = controllerNuevo;
        _categoriasActuales     = List.from(todasLasTabs);
        _actualizandoController = false;
      });
      controllerViejo?.dispose();
    });
  }

  List<Map<String, dynamic>> _filtrarProductos(
      List<Map<String, dynamic>> productos) {
    if (_textoBusqueda.isEmpty) return productos;
    final query = _textoBusqueda.toLowerCase();
    return productos.where((p) {
      final nombre    = (p['nombre']    ?? '').toString().toLowerCase();
      final categoria = (p['categoria'] ?? '').toString().toLowerCase();
      final subtexto  = (p['subtexto']  ?? '').toString().toLowerCase();
      return nombre.contains(query) ||
             categoria.contains(query) ||
             subtexto.contains(query);
    }).toList();
  }

  // ── Acciones ─────────────────────────────────────────────────
  Future<void> _cambiarEstado(String idProducto, bool nuevoEstado) async {
    final resultado = nuevoEstado
        ? await _servicio.activarProducto(idProducto)
        : await _servicio.desactivarProducto(idProducto);
    if (!mounted) return;
    NotificacionPersonalizada.mostrarSnack(
      context,
      mensaje: resultado['mensaje'],
      tipo: resultado['exito'] ? TipoNotificacion.exito : TipoNotificacion.error,
    );
  }

  Future<void> _eliminarProducto(Map<String, dynamic> producto) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Producto'),
        content: Text(
          '¿Estás seguro de eliminar "${producto['nombre']}" permanentemente?\n\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    final resultado =
        await _servicio.eliminarProductoPermanente(producto['id']);
    if (!mounted) return;
    NotificacionPersonalizada.mostrarSnack(
      context,
      mensaje: resultado['mensaje'],
      tipo: resultado['exito'] ? TipoNotificacion.exito : TipoNotificacion.error,
    );
  }

  void _mostrarDialogoCrearCategoria(
      BuildContext context, List<String> categorias) {
    final ctrlNombre  = TextEditingController();
    final ctrlPrefijo = TextEditingController(); // ← NUEVO

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva Categoría'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Nombre de la categoría
              TextField(
                controller: ctrlNombre,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la categoría',
                  hintText: 'Ej: Carnes Frías',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),

              // ── PREFIJO ── NUEVO ──────────────────────────────
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
                  helperText:
                      'Los productos con este prefijo se asignarán aquí automáticamente',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nombre  = ctrlNombre.text.trim();
              final prefijo = ctrlPrefijo.text.trim();

              if (nombre.isEmpty) {
                NotificacionPersonalizada.mostrarSnack(
                  context,
                  mensaje: 'Ingresa el nombre de la categoría',
                  tipo: TipoNotificacion.error,
                );
                return;
              }
              if (prefijo.length != 2) {
                NotificacionPersonalizada.mostrarSnack(
                  context,
                  mensaje: 'El prefijo debe tener exactamente 2 dígitos',
                  tipo: TipoNotificacion.error,
                );
                return;
              }

              Navigator.pop(ctx);
              final resultado = await _servicio.crearCategoria(
                nombre: nombre,
                prefijo: prefijo,   // ← NUEVO
              );
              if (!mounted) return;
              NotificacionPersonalizada.mostrarSnack(
                context,
                mensaje: resultado['mensaje'],
                tipo: resultado['exito']
                    ? TipoNotificacion.exito
                    : TipoNotificacion.error,
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  void _confirmarEliminarCategoria(
      BuildContext context, String categoria) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Categoría'),
        content: Text(
          '¿Eliminar la categoría "$categoria"?\n\nLos productos de esta categoría seguirán visibles en la pestaña "Todo".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final resultado =
                  await _servicio.eliminarCategoria(categoria);
              if (!mounted) return;
              NotificacionPersonalizada.mostrarSnack(
                context,
                mensaje: resultado['mensaje'],
                tipo: resultado['exito']
                    ? TipoNotificacion.exito
                    : TipoNotificacion.error,
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: _servicio.obtenerCategoriasStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(
                child: CircularProgressIndicator(color: Colors.teal)),
          );
        }

        final categorias   = snapshot.data!;
        final todasLasTabs = _buildTabs(categorias);

        if (_tabController == null || _categoriasActuales.isEmpty) {
          _tabController = TabController(
              length: todasLasTabs.length, vsync: this);
          _categoriasActuales = List.from(todasLasTabs);
        } else {
          _actualizarTabController(todasLasTabs);
        }

        final tabsParaMostrar = _categoriasActuales.isNotEmpty
            ? _categoriasActuales
            : todasLasTabs;

        if (_tabController == null ||
            _tabController!.length != tabsParaMostrar.length) {
          return const Scaffold(
            body: Center(
                child: CircularProgressIndicator(color: Colors.teal)),
          );
        }

        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            elevation: 0,
            title: _mostrandoBusqueda
                ? _SearchBar(
                    controller: _busquedaCtrl,
                    focusNode: _busquedaFocus,
                    onChanged: (v) =>
                        setState(() => _textoBusqueda = v),
                    onClose: () {
                      setState(() {
                        _mostrandoBusqueda = false;
                        _textoBusqueda = '';
                        _busquedaCtrl.clear();
                      });
                    },
                  )
                : const Text('Gestionar Productos',
                    style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              if (!_mostrandoBusqueda)
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Buscar',
                  onPressed: () {
                    setState(() => _mostrandoBusqueda = true);
                    Future.delayed(
                      const Duration(milliseconds: 100),
                      () => _busquedaFocus.requestFocus(),
                    );
                  },
                ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: SizedBox(
                height: 48,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TabBar(
                        controller: _tabController,
                        indicatorColor: Colors.white,
                        indicatorWeight: 3,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white70,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        tabs: tabsParaMostrar.map((tab) {
                          if (tab == _tabTodo) {
                            return const Tab(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.grid_view, size: 16),
                                  SizedBox(width: 6),
                                  Text('Todo'),
                                ],
                              ),
                            );
                          }
                          return Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(tab),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () =>
                                      _confirmarEliminarCategoria(
                                          context, tab),
                                  child: const Icon(Icons.close,
                                      size: 14,
                                      color: Colors.white70),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      GestureDetector(
                        onTap: () => _mostrarDialogoCrearCategoria(
                            context, categorias),
                        child: Container(
                          width: 44, height: 48,
                          alignment: Alignment.center,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.add,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: tabsParaMostrar.map((tab) {
              if (tab == _tabTodo) {
                return _buildListaTodosProductos(categorias);
              }
              return _buildListaProductos(tab, categorias);
            }).toList(),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              if (categorias.isEmpty) {
                NotificacionPersonalizada.mostrarSnack(
                  context,
                  mensaje: 'Primero crea una categoría',
                  tipo: TipoNotificacion.advertencia,
                );
                return;
              }
              final index = _tabController!.index;
              final tabActual = index < tabsParaMostrar.length
                  ? tabsParaMostrar[index]
                  : tabsParaMostrar.first;
              final catInicial = tabActual == _tabTodo
                  ? (categorias.isNotEmpty ? categorias.first : null)
                  : tabActual;
              ProductoForm.mostrar(
                context,
                categorias: categorias,
                servicio: _servicio,
                categoriaInicial: catInicial,
              );
            },
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Nuevo Producto'),
          ),
        );
      },
    );
  }

  Widget _buildListaTodosProductos(List<String> todasCategorias) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _servicio.obtenerTodosLosProductos(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.teal));
        }
        final productos = _filtrarProductos(snapshot.data!);
        if (productos.isEmpty) {
          return _EmptyState(
              texto: _textoBusqueda.isNotEmpty
                  ? 'Sin resultados para "$_textoBusqueda"'
                  : 'No hay productos todavía');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: productos.length,
          itemBuilder: (_, i) => ProductoCard(
            producto: productos[i],
            categorias: todasCategorias,
            enTabTodo: true,
            servicio: _servicio,
            onEditar: (p) => ProductoForm.mostrar(
              context,
              categorias: todasCategorias,
              servicio: _servicio,
              productoExistente: p,
            ),
            onCambiarEstado: _cambiarEstado,
            onEliminar: _eliminarProducto,
          ),
        );
      },
    );
  }

  Widget _buildListaProductos(
      String categoria, List<String> todasCategorias) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _servicio.obtenerProductosPorCategoria(categoria),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.teal));
        }
        final productos = _filtrarProductos(snapshot.data!);
        if (productos.isEmpty) {
          return _EmptyState(
            texto: _textoBusqueda.isNotEmpty
                ? 'Sin resultados para "$_textoBusqueda"'
                : 'No hay productos en $categoria',
            accion: _textoBusqueda.isEmpty
                ? TextButton.icon(
                    onPressed: () => ProductoForm.mostrar(
                      context,
                      categorias: todasCategorias,
                      servicio: _servicio,
                      categoriaInicial: categoria,
                    ),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Agregar Primero'),
                  )
                : null,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: productos.length,
          itemBuilder: (_, i) => ProductoCard(
            producto: productos[i],
            categorias: todasCategorias,
            enTabTodo: false,
            servicio: _servicio,
            onEditar: (p) => ProductoForm.mostrar(
              context,
              categorias: todasCategorias,
              servicio: _servicio,
              productoExistente: p,
            ),
            onCambiarEstado: _cambiarEstado,
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String  texto;
  final Widget? accion;

  const _EmptyState({required this.texto, this.accion});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(texto,
              style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          if (accion != null) ...[
            const SizedBox(height: 8),
            accion!,
          ],
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.teal.shade600, width: 2),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: onClose,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.close,
                    color: Colors.teal.shade600, size: 20),
              ),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                style: const TextStyle(color: Colors.black87, fontSize: 15),
                cursorColor: Colors.teal,
                decoration: InputDecoration(
                  hintText: 'Buscar producto...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}