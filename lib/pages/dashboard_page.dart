import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pedidos_page.dart';
import 'productos_page.dart';
import 'reportes_page.dart';
import '../services/auth_admin_service.dart';

class DashboardPage extends StatefulWidget {
  final Map<String, dynamic> adminData;

  const DashboardPage({super.key, required this.adminData});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;
  final AuthAdminService _authService = AuthAdminService();

  @override
  Widget build(BuildContext context) {
    // ✅ StreamBuilder en la raíz del dashboard — escucha en tiempo real
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('configuracion')
          .doc('licencia')
          .snapshots(),
      builder: (context, snapshot) {
        // Si hay datos y la licencia está desactivada → bloquear al instante
        if (snapshot.hasData) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final activo = data?['Activo'] ?? true;

          if (activo == false) {
            // Cerrar sesión automáticamente y mostrar pantalla de bloqueo
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await _authService.cerrarSesion();
            });
            return const _PantallaAdminBloqueado();
          }
        }

        // Licencia activa → mostrar dashboard normal
        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (int index) {
                  setState(() => _selectedIndex = index);
                },
                labelType: NavigationRailLabelType.all,
                backgroundColor: Colors.teal[50],
                selectedIconTheme:
                    const IconThemeData(color: Colors.teal, size: 28),
                selectedLabelTextStyle: const TextStyle(
                  color: Colors.teal,
                  fontWeight: FontWeight.bold,
                ),
                unselectedIconTheme:
                    IconThemeData(color: Colors.grey[600], size: 24),
                leading: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.teal,
                        child: Text(
                          widget.adminData['nombre']?[0].toUpperCase() ?? 'A',
                          style: const TextStyle(
                            fontSize: 24,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.adminData['nombre'] ?? 'Admin',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle,
                                size: 8, color: Colors.green[700]),
                            const SizedBox(width: 4),
                            Text(
                              'Activo',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                trailing: Padding(
                  padding: const EdgeInsets.all(16),
                  child: IconButton(
                    icon: const Icon(Icons.logout, color: Colors.red),
                    onPressed: _mostrarDialogoCerrarSesion,
                    tooltip: 'Cerrar Sesión',
                  ),
                ),
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard),
                    label: Text('Dashboard'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.shopping_bag_outlined),
                    selectedIcon: Icon(Icons.shopping_bag),
                    label: Text('Productos'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.receipt_long_outlined),
                    selectedIcon: Icon(Icons.receipt_long),
                    label: Text('Pedidos'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.bar_chart_outlined),
                    selectedIcon: Icon(Icons.bar_chart),
                    label: Text('Reportes'),
                  ),
                ],
              ),

              const VerticalDivider(thickness: 1, width: 1),

              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: [
                    _buildDashboard(),
                    const ProductosPage(),
                    const PedidosPage(),
                    const ReportesPage(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _mostrarDialogoCerrarSesion() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.logout, color: Colors.orange[700]),
              const SizedBox(width: 12),
              const Text('Cerrar Sesión'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('¿Estás seguro de que deseas cerrar sesión?',
                  style: TextStyle(fontSize: 16)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 20, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Tendrás que iniciar sesión nuevamente',
                          style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child:
                  const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _cerrarSesion();
              },
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Cerrar Sesión'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[400],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _cerrarSesion() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cerrando sesión...'),
                ],
              ),
            ),
          ),
        ),
      );

      await _authService.cerrarSesion();
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/login', (route) => false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Sesión cerrada exitosamente'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Error al cerrar sesión: $e')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Widget _buildDashboard() {
    return Container(
      color: Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Panel de Administración',
                      style: TextStyle(
                          fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.store, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(
                          'El Gran Molino',
                          style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.teal[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.teal[200]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person,
                                  size: 14, color: Colors.teal[700]),
                              const SizedBox(width: 4),
                              Text(
                                widget.adminData['nombre'] ?? 'Admin',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.teal[700],
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Datos actualizados'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Actualizar',
                      color: Colors.teal,
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _mostrarDialogoCerrarSesion,
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Cerrar Sesión'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red[600],
                        side: BorderSide(color: Colors.red[300]!),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Estadísticas en Tiempo Real',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Chip(
                        avatar: Icon(Icons.access_time,
                            size: 16, color: Colors.blue[700]),
                        label: Text(_obtenerFechaActual(),
                            style: const TextStyle(fontSize: 12)),
                        backgroundColor: Colors.blue[50],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  StreamBuilder<Map<String, dynamic>>(
                    stream: _getEstadisticasStream(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child:
                                CircularProgressIndicator(color: Colors.teal),
                          ),
                        );
                      }

                      final stats = snapshot.data!;
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _StatCard(
                            title: 'Pedidos Hoy',
                            value: stats['pedidosHoy'].toString(),
                            icon: Icons.shopping_cart,
                            color: Colors.blue,
                          ),
                          _StatCard(
                            title: 'Ventas Hoy',
                            value:
                                '\$${stats['ventasHoy'].toStringAsFixed(0)}',
                            icon: Icons.attach_money,
                            color: Colors.green,
                          ),
                          _StatCard(
                            title: 'Pendientes',
                            value: stats['pedidosPendientes'].toString(),
                            icon: Icons.pending_actions,
                            color: Colors.orange,
                          ),
                          _StatCard(
                            title: 'Productos Activos',
                            value: stats['productosActivos'].toString(),
                            icon: Icons.inventory_2,
                            color: Colors.purple,
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Pedidos Recientes',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _selectedIndex = 2),
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: const Text('Ver todos'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('pedido')
                        .orderBy('fechaPedido', descending: true)
                        .limit(5)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child:
                                CircularProgressIndicator(color: Colors.teal),
                          ),
                        );
                      }

                      final pedidos = snapshot.data!.docs;

                      if (pedidos.isEmpty) {
                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey[200]!),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(48),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.inbox_outlined,
                                      size: 64, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No hay pedidos recientes',
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          children: pedidos.asMap().entries.map((entry) {
                            final index = entry.key;
                            final doc = entry.value;
                            final data =
                                doc.data() as Map<String, dynamic>;
                            final isLast = index == pedidos.length - 1;

                            return Column(
                              children: [
                                ListTile(
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                  leading: CircleAvatar(
                                    radius: 24,
                                    backgroundColor:
                                        _getColorEstado(data['estado'])
                                            .withOpacity(0.2),
                                    child: Icon(Icons.receipt,
                                        color: _getColorEstado(
                                            data['estado']),
                                        size: 24),
                                  ),
                                  title: Text(
                                    data['numeroPedido'] ?? 'Sin número',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      data['nombreCliente'] ?? 'Sin nombre',
                                      style: TextStyle(
                                          color: Colors.grey[600]),
                                    ),
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '\$${data['total']?.toStringAsFixed(0) ?? '0'}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: Colors.teal),
                                      ),
                                      Text(
                                        data['estado'] ?? 'pendiente',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[500]),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isLast)
                                  Divider(
                                      height: 1, color: Colors.grey[200]),
                              ],
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _obtenerFechaActual() {
    final now = DateTime.now();
    final meses = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return '${now.day} de ${meses[now.month - 1]}, ${now.year}';
  }

  Stream<Map<String, dynamic>> _getEstadisticasStream() {
    final hoy = DateTime.now();
    final inicioDia = DateTime(hoy.year, hoy.month, hoy.day);

    return FirebaseFirestore.instance
        .collection('pedido')
        .snapshots()
        .asyncMap((snapshot) async {
      int pedidosHoy = 0;
      double ventasHoy = 0;
      int pedidosPendientes = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final fechaPedido =
            (data['fechaPedido'] as Timestamp?)?.toDate();

        if (fechaPedido != null && fechaPedido.isAfter(inicioDia)) {
          pedidosHoy++;
          ventasHoy += (data['total'] ?? 0.0) as double;
        }

        if (data['estado'] == 'pendiente') {
          pedidosPendientes++;
        }
      }

      final productosSnapshot = await FirebaseFirestore.instance
          .collection('productos')
          .where('activo', isEqualTo: true)
          .get();

      return {
        'pedidosHoy': pedidosHoy,
        'ventasHoy': ventasHoy,
        'pedidosPendientes': pedidosPendientes,
        'productosActivos': productosSnapshot.docs.length,
      };
    });
  }

  Color _getColorEstado(String? estado) {
    switch (estado) {
      case 'pendiente': return Colors.orange;
      case 'confirmado': return Colors.blue;
      case 'preparando': return Colors.purple;
      case 'enviado': return Colors.indigo;
      case 'entregado': return Colors.green;
      case 'cancelado': return Colors.red;
      default: return Colors.grey;
    }
  }
}

// ── Pantalla de admin bloqueado ───────────────────────────────
class _PantallaAdminBloqueado extends StatelessWidget {
  const _PantallaAdminBloqueado();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock_outline,
                      size: 72, color: Colors.red[400]),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Acceso Suspendido',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'La licencia del panel de administración ha sido suspendida.',
                  style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Para reactivar el acceso, comunícate con el proveedor del sistema.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Contactar proveedor',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.phone, color: Colors.teal, size: 20),
                          SizedBox(width: 10),
                          // ✅ Cambia este número por el tuyo
                          Text(
                            '+57 321 972 8449',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey[200]!),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, color.withOpacity(0.02)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(height: 20),
                Text(
                  value,
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: color),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}