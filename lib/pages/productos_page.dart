import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../services/producto_service_admin.dart';

class ProductosPage extends StatefulWidget {
  const ProductosPage({super.key});

  @override
  State<ProductosPage> createState() => _ProductosPageState();
}

class _ProductosPageState extends State<ProductosPage>
    with TickerProviderStateMixin {
  final ProductoServiceAdmin _productoService = ProductoServiceAdmin();

  TabController? _tabController;
  List<String> _categoriasActuales = [];
  bool _actualizandoController = false;

  static const String _tabTodo = 'Todo';

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  List<String> _buildTabs(List<String> categorias) {
    return [_tabTodo, ...categorias];
  }

  void _actualizarTabController(List<String> todasLasTabs) {
    if (_actualizandoController) return;

    final mismaLista = todasLasTabs.length == _categoriasActuales.length &&
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
        _tabController = controllerNuevo;
        _categoriasActuales = List.from(todasLasTabs);
        _actualizandoController = false;
      });
      controllerViejo?.dispose();
    });
  }

  Widget _buildImagen(String? urlImagen, {double size = 60}) {
    // Debug: imprimir la URL para verificar
    print('🖼️ URL de imagen: $urlImagen');
    
    if (urlImagen == null ||
        urlImagen.isEmpty ||
        urlImagen.startsWith('assets/')) {
      return Icon(Icons.image, size: size * 0.5, color: Colors.grey);
    }

    if (urlImagen.startsWith('http')) {
      return Image.network(
        urlImagen,
        fit: BoxFit.cover,
        width: size,
        height: size,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.teal,
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          print('❌ Error cargando imagen: $error');
          return Icon(Icons.broken_image, size: size * 0.5, color: Colors.grey);
        },
      );
    }

    return Icon(Icons.image, size: size * 0.5, color: Colors.grey);
  }

  // ── COLOR DEL STOCK ─────────────────────────────────────────────────────────
  Color _colorStock(int stock) {
    if (stock == 0) return Colors.red;
    if (stock <= 10) return Colors.orange;
    return Colors.green;
  }

  String _textoStock(int stock) {
    if (stock == 0) return 'Sin stock';
    if (stock <= 10) return 'Stock bajo: $stock';
    return 'Stock: $stock';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: _productoService.obtenerCategoriasStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
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
            body:
                Center(child: CircularProgressIndicator(color: Colors.teal)),
          );
        }

        final categorias = snapshot.data!;
        final todasLasTabs = _buildTabs(categorias);

        if (_tabController == null || _categoriasActuales.isEmpty) {
          _tabController =
              TabController(length: todasLasTabs.length, vsync: this);
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
            body:
                Center(child: CircularProgressIndicator(color: Colors.teal)),
          );
        }

        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            title: const Text('Gestionar Productos',
                style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Nueva Categoría',
                onPressed: () =>
                    _mostrarDialogoCrearCategoria(context, categorias),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              isScrollable: true,
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
                            _confirmarEliminarCategoria(context, tab),
                        child: const Icon(Icons.close,
                            size: 14, color: Colors.white70),
                      ),
                    ],
                  ),
                );
              }).toList(),
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
              final index = _tabController!.index;
              final tabActual = index < tabsParaMostrar.length
                  ? tabsParaMostrar[index]
                  : tabsParaMostrar.first;
              final catInicial = tabActual == _tabTodo
                  ? (categorias.isNotEmpty ? categorias.first : null)
                  : tabActual;
              if (categorias.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Primero crea una categoría'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              _mostrarDialogoCrear(context, categorias,
                  categoriaInicial: catInicial);
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

  // ── TAB "TODO" ──────────────────────────────────────────────────────────────
  Widget _buildListaTodosProductos(List<String> todasCategorias) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _productoService.obtenerTodosLosProductos(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.teal));
        }

        final productos = snapshot.data!;

        if (productos.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('No hay productos todavía',
                    style:
                        TextStyle(fontSize: 18, color: Colors.grey[600])),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: productos.length,
          itemBuilder: (_, i) =>
              _buildProductoCard(productos[i], todasCategorias, enTabTodo: true),
        );
      },
    );
  }

  // ── TABS DE CATEGORÍA ───────────────────────────────────────────────────────
  Widget _buildListaProductos(
      String categoria, List<String> todasCategorias) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _productoService.obtenerProductosPorCategoria(categoria),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
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

        final productos = snapshot.data!;

        if (productos.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('No hay productos en $categoria',
                    style:
                        TextStyle(fontSize: 18, color: Colors.grey[600])),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _mostrarDialogoCrear(
                      context, todasCategorias,
                      categoriaInicial: categoria),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Agregar Primero'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: productos.length,
          itemBuilder: (_, i) => _buildProductoCard(
              productos[i], todasCategorias,
              enTabTodo: false),
        );
      },
    );
  }

  // ── CARD DE PRODUCTO ────────────────────────────────────────────────────────
  Widget _buildProductoCard(
      Map<String, dynamic> producto, List<String> categorias,
      {bool enTabTodo = false}) {
    final activo = producto['activo'] ?? false;
    final urlImagen = producto['imagen'] as String?;
    final stock = (producto['stock'] ?? 0) as int;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _buildImagen(urlImagen, size: 60),
          ),
        ),
        title: Text(producto['nombre'] ?? 'Sin nombre',
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (enTabTodo)
              Text(producto['categoria'] ?? '',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.teal[700],
                      fontWeight: FontWeight.w600)),
            Text(producto['subtexto'] ?? ''),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '\$${producto['precio']?.toStringAsFixed(0) ?? '0'}',
                  style: const TextStyle(
                    color: Colors.teal,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: activo ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: activo ? Colors.green : Colors.red),
                  ),
                  child: Text(
                    activo ? 'Activo' : 'Inactivo',
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          activo ? Colors.green[700] : Colors.red[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // ── BADGE DE STOCK ──────────────────────────
                GestureDetector(
                  onTap: () => _mostrarDialogoStock(context, producto),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _colorStock(stock).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _colorStock(stock)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2,
                            size: 11, color: _colorStock(stock)),
                        const SizedBox(width: 4),
                        Text(
                          _textoStock(stock),
                          style: TextStyle(
                            fontSize: 11,
                            color: _colorStock(stock),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (_) => [
            PopupMenuItem(
              child: const Row(children: [
                Icon(Icons.edit, size: 20),
                SizedBox(width: 12),
                Text('Editar'),
              ]),
              onTap: () => Future.delayed(
                  Duration.zero,
                  () => _mostrarDialogoEditar(
                      context, producto, categorias)),
            ),
            PopupMenuItem(
              child: const Row(children: [
                Icon(Icons.inventory_2, size: 20, color: Colors.blue),
                SizedBox(width: 12),
                Text('Actualizar Stock',
                    style: TextStyle(color: Colors.blue)),
              ]),
              onTap: () => Future.delayed(
                  Duration.zero,
                  () => _mostrarDialogoStock(context, producto)),
            ),
            PopupMenuItem(
              child: Row(children: [
                Icon(
                    activo
                        ? Icons.visibility_off
                        : Icons.visibility,
                    size: 20),
                const SizedBox(width: 12),
                Text(activo ? 'Desactivar' : 'Activar'),
              ]),
              onTap: () => _cambiarEstado(producto['id'], !activo),
            ),
            if (enTabTodo)
              PopupMenuItem(
                child: const Row(children: [
                  Icon(Icons.delete_forever,
                      size: 20, color: Colors.red),
                  SizedBox(width: 12),
                  Text('Eliminar',
                      style: TextStyle(color: Colors.red)),
                ]),
                onTap: () => Future.delayed(
                    Duration.zero,
                    () => _confirmarEliminarPermanente(
                        context, producto)),
              ),
          ],
        ),
      ),
    );
  }

  // ── DIÁLOGO ACTUALIZAR STOCK ────────────────────────────────────────────────
  void _mostrarDialogoStock(
      BuildContext context, Map<String, dynamic> producto) {
    final stock = (producto['stock'] ?? 0) as int;
    final stockCtrl = TextEditingController(text: stock.toString());

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.inventory_2, color: Colors.teal),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Stock: ${producto['nombre']}',
                  style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Stock actual: $stock unidades',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: stockCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nuevo stock',
                hintText: 'Ej: 150',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.inventory_2, color: Colors.teal),
                suffixText: 'unidades',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nuevoStock = int.tryParse(stockCtrl.text);
              if (nuevoStock == null || nuevoStock < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ingresa un número válido'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(dialogContext);
              final resultado = await _productoService.actualizarStock(
                idProducto: producto['id'],
                nuevoStock: nuevoStock,
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(resultado['mensaje']),
                  backgroundColor:
                      resultado['exito'] ? Colors.green : Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // ── DIÁLOGOS ─────────────────────────────────────────────────────────────────

  void _mostrarDialogoCrearCategoria(
      BuildContext context, List<String> categorias) {
    final nombreController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nueva Categoría'),
        content: SizedBox(
          width: 320,
          child: TextField(
            controller: nombreController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nombre de la categoría',
              hintText: 'Ej: Carnes Frías',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nombre = nombreController.text.trim();
              if (nombre.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ingresa el nombre de la categoría'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(dialogContext);
              final resultado =
                  await _productoService.crearCategoria(nombre: nombre);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(resultado['mensaje']),
                  backgroundColor:
                      resultado['exito'] ? Colors.green : Colors.red,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar Categoría'),
        content: Text(
          '¿Eliminar la categoría "$categoria"?\n\nLos productos de esta categoría seguirán visibles en la pestaña "Todo".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final resultado =
                  await _productoService.eliminarCategoria(categoria);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(resultado['mensaje']),
                  backgroundColor:
                      resultado['exito'] ? Colors.green : Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _confirmarEliminarPermanente(
      BuildContext context, Map<String, dynamic> producto) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar Producto'),
        content: Text(
          '¿Estás seguro de eliminar "${producto['nombre']}" permanentemente?\n\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final resultado = await _productoService
                  .eliminarProductoPermanente(producto['id']);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(resultado['mensaje']),
                  backgroundColor:
                      resultado['exito'] ? Colors.green : Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  // ── CREAR PRODUCTO ──────────────────────────────────────────────────────────
  void _mostrarDialogoCrear(
    BuildContext context,
    List<String> categorias, {
    String? categoriaInicial,
  }) {
    final nombreCtrl = TextEditingController();
    final precioCtrl = TextEditingController();
    final subtextoCtrl = TextEditingController();
    final stockCtrl = TextEditingController(text: '0');
    String categoriaSeleccionada =
        categoriaInicial ?? categorias.first;
    bool guardando = false;
    Uint8List? imagenBytes; // ✅ imagen local seleccionada

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Nuevo Producto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatefulBuilder(
                  builder: (_, setPreview) => Column(
                    children: [
                      // ✅ Preview imagen local
                      GestureDetector(
                        onTap: () async {
                          final picker = ImagePicker();
                          final xfile = await picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 85,
                          );
                          if (xfile != null) {
                            final bytes = await xfile.readAsBytes();
                            setPreview(() => imagenBytes = bytes);
                          }
                        },
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: imagenBytes != null
                                  ? Colors.teal
                                  : Colors.grey[300]!,
                              width: 2,
                              style: imagenBytes != null
                                  ? BorderStyle.solid
                                  : BorderStyle.solid,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: imagenBytes != null
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.memory(imagenBytes!,
                                        fit: BoxFit.cover),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () => setPreview(
                                            () => imagenBytes = null),
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle),
                                          child: const Icon(Icons.close,
                                              color: Colors.white,
                                              size: 16),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate_outlined,
                                        size: 48, color: Colors.grey[400]),
                                    const SizedBox(height: 8),
                                    Text('Seleccionar imagen',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600])),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        imagenBytes != null
                            ? 'Imagen seleccionada ✓'
                            : 'Toca para elegir del dispositivo',
                        style: TextStyle(
                            fontSize: 11,
                            color: imagenBytes != null
                                ? Colors.teal
                                : Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del producto',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: precioCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Precio',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                // ── CAMPO STOCK ──────────────────────────────
                TextField(
                  controller: stockCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Stock disponible',
                    hintText: 'Ej: 100',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.inventory_2, color: Colors.teal),
                    suffixText: 'unidades',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: subtextoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descripción (ej: 500g, 1L)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: categorias.contains(categoriaSeleccionada)
                      ? categoriaSeleccionada
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Categoría',
                    border: OutlineInputBorder(),
                  ),
                  items: categorias
                      .map((c) =>
                          DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) =>
                      setDlgState(() => categoriaSeleccionada = v!),
                ),
                if (guardando) ...[
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 8),
                  const Text('Guardando producto...',
                      style: TextStyle(fontSize: 12)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  guardando ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: guardando
                  ? null
                  : () async {
                      if (nombreCtrl.text.isEmpty ||
                          precioCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Completa nombre y precio'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      setDlgState(() => guardando = true);
                      // ✅ Subir imagen a Firebase Storage si se seleccionó una
                      String? urlFinal;
                      if (imagenBytes != null) {
                        final nombreArchivo =
                            '${DateTime.now().millisecondsSinceEpoch}.jpg';
                        urlFinal = await _productoService.subirImagen(
                          bytes: imagenBytes!,
                          nombreArchivo: nombreArchivo,
                        );
                        if (urlFinal == null && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Error al subir la imagen'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          setDlgState(() => guardando = false);
                          return;
                        }
                      }
                      final resultado =
                          await _productoService.crearProducto(
                        nombre: nombreCtrl.text.trim(),
                        precio:
                            double.tryParse(precioCtrl.text) ?? 0,
                        categoria: categoriaSeleccionada,
                        subtexto: subtextoCtrl.text.trim(),
                        idAdmin: 'admin',
                        imagenUrl: urlFinal ?? '',
                        stock: int.tryParse(stockCtrl.text) ?? 0,
                      );
                      if (mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(resultado['mensaje']),
                            backgroundColor: resultado['exito']
                                ? Colors.green
                                : Colors.red,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
  }

  // ── EDITAR PRODUCTO ─────────────────────────────────────────────────────────
  void _mostrarDialogoEditar(
    BuildContext context,
    Map<String, dynamic> producto,
    List<String> categorias,
  ) {
    final nombreCtrl =
        TextEditingController(text: producto['nombre']);
    final precioCtrl = TextEditingController(
        text: producto['precio']?.toString() ?? '0');
    final subtextoCtrl =
        TextEditingController(text: producto['subtexto']);
    final stockCtrl = TextEditingController(
        text: (producto['stock'] ?? 0).toString());

    final imgExistente = producto['imagen'] as String? ?? '';
    // ✅ URL existente (para mostrar la imagen actual)
    String imagenUrlExistente =
        imgExistente.startsWith('http') ? imgExistente : '';
    // ✅ Bytes de nueva imagen local (si el admin cambia la imagen)
    Uint8List? imagenBytesNueva;

    final catProducto = producto['categoria'] as String? ?? '';
    String categoriaSeleccionada = categorias.contains(catProducto)
        ? catProducto
        : (categorias.isNotEmpty ? categorias.first : '');

    bool guardando = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Editar Producto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatefulBuilder(
                  builder: (_, setPreview) => Column(
                    children: [
                      // ✅ Preview: nueva imagen local o la existente
                      GestureDetector(
                        onTap: () async {
                          final picker = ImagePicker();
                          final xfile = await picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 85,
                          );
                          if (xfile != null) {
                            final bytes = await xfile.readAsBytes();
                            setPreview(() => imagenBytesNueva = bytes);
                          }
                        },
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: imagenBytesNueva != null
                                  ? Colors.teal
                                  : Colors.grey[300]!,
                              width: 2,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: imagenBytesNueva != null
                              // Nueva imagen seleccionada
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.memory(imagenBytesNueva!,
                                        fit: BoxFit.cover),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () => setPreview(
                                            () => imagenBytesNueva = null),
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle),
                                          child: const Icon(Icons.close,
                                              color: Colors.white,
                                              size: 16),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : imagenUrlExistente.isNotEmpty
                                  // Imagen actual de Firestore
                                  ? Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.network(
                                          imagenUrlExistente,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.broken_image,
                                                  size: 40),
                                        ),
                                        // Indicador de que se puede cambiar
                                        Positioned(
                                          bottom: 0,
                                          left: 0,
                                          right: 0,
                                          child: Container(
                                            color: Colors.black45,
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    vertical: 4),
                                            child: const Text(
                                              'Toca para cambiar',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  // Sin imagen
                                  : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_photo_alternate_outlined,
                                            size: 48,
                                            color: Colors.grey[400]),
                                        const SizedBox(height: 8),
                                        Text('Seleccionar imagen',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600])),
                                      ],
                                    ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        imagenBytesNueva != null
                            ? 'Nueva imagen seleccionada ✓'
                            : imagenUrlExistente.isNotEmpty
                                ? 'Imagen actual — toca para reemplazar'
                                : 'Sin imagen — toca para agregar',
                        style: TextStyle(
                            fontSize: 11,
                            color: imagenBytesNueva != null
                                ? Colors.teal
                                : Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del producto',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: precioCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Precio',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                // ── CAMPO STOCK ──────────────────────────────
                TextField(
                  controller: stockCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Stock disponible',
                    hintText: 'Ej: 100',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.inventory_2, color: Colors.teal),
                    suffixText: 'unidades',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: subtextoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: categorias.contains(categoriaSeleccionada)
                      ? categoriaSeleccionada
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Categoría',
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('Selecciona una categoría'),
                  items: categorias
                      .map((c) =>
                          DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setDlgState(() => categoriaSeleccionada = v);
                    }
                  },
                ),
                if (guardando) ...[
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 8),
                  const Text('Actualizando...',
                      style: TextStyle(fontSize: 12)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  guardando ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: guardando
                  ? null
                  : () async {
                      if (categoriaSeleccionada.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Selecciona una categoría'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      setDlgState(() => guardando = true);
                      final resultado =
                          await _productoService.actualizarProducto(
                        idProducto: producto['id'],
                        nombre: nombreCtrl.text.trim(),
                        precio:
                            double.tryParse(precioCtrl.text) ?? 0,
                        subtexto: subtextoCtrl.text.trim(),
                        categoria: categoriaSeleccionada,
                        // ✅ Si hay nueva imagen local, subirla; si no, conservar la existente
                        imagenUrl: imagenBytesNueva != null
                            ? await _productoService.subirImagen(
                                bytes: imagenBytesNueva!,
                                nombreArchivo:
                                    '${producto['id']}_${DateTime.now().millisecondsSinceEpoch}.jpg',
                              ) ?? imagenUrlExistente
                            : imagenUrlExistente,
                        stock: int.tryParse(stockCtrl.text) ?? 0,
                      );
                      if (mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(resultado['mensaje']),
                            backgroundColor: resultado['exito']
                                ? Colors.green
                                : Colors.red,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cambiarEstado(
      String idProducto, bool nuevoEstado) async {
    final resultado = nuevoEstado
        ? await _productoService.activarProducto(idProducto)
        : await _productoService.desactivarProducto(idProducto);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(resultado['mensaje']),
        backgroundColor:
            resultado['exito'] ? Colors.green : Colors.red,
      ),
    );
  }
}