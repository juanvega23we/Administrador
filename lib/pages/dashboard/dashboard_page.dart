import 'package:flutter/material.dart';
import '../../widgets/notificacion_personalizada.dart';
import '../login_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../productos/productos_page.dart';
import '../../utils/numero_formato.dart';
import '../pedidos/pedidos_page.dart';
import '../reportes/reportes_page.dart';
import '../super_admin/backup_page.dart';
import '../../services/auth_admin_service.dart';
import '../super_admin/super_admin_page.dart';

import 'widgets/dashboard_sidebar.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/dashboard_welcome_banner.dart';
import 'widgets/dashboard_stats_section.dart';
import 'widgets/dashboard_pedidos_recientes.dart';

class DashboardPage extends StatefulWidget {
  final Map<String, dynamic> adminData;
  const DashboardPage({super.key, required this.adminData});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  final AuthAdminService _authService = AuthAdminService();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  bool get _esSuperAdmin => widget.adminData['rol'] == 'super_admin';

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Color _colorEstado(String? estado) {
    switch (estado) {
      case 'pendiente':  return Colors.orange;
      case 'confirmado': return Colors.blue;
      case 'preparando': return Colors.purple;
      case 'enviado':    return Colors.indigo;
      case 'entregado':  return Colors.green;
      case 'cancelado':  return Colors.red;
      default:           return Colors.grey;
    }
  }

  String _obtenerFechaActual() {
    final now = DateTime.now();
    const meses = [
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
        final estado = data['estado']?.toString() ?? '';
        Timestamp? ts;
        final raw = data['fechaPedido'] ?? data['creadoEn'] ?? data['fecha'];
        if (raw is Timestamp) ts = raw;
        if (ts != null && !ts.toDate().isBefore(inicioDia)) {
          pedidosHoy++;
          if (estado == 'confirmado' || estado == 'entregado') {
            ventasHoy += ((data['total'] as num?) ?? 0.0).toDouble();
          }
        }
        if (estado == 'pendiente') pedidosPendientes++;
      }
      int productosActivos = 0;
      try {
        final s1 = await FirebaseFirestore.instance
            .collection('productos')
            .where('activo', isEqualTo: true)
            .get();
        if (s1.docs.isNotEmpty) {
          productosActivos = s1.docs.length;
        } else {
          final s2 = await FirebaseFirestore.instance
              .collection('producto')
              .where('activo', isEqualTo: true)
              .get();
          if (s2.docs.isNotEmpty) {
            productosActivos = s2.docs.length;
          } else {
            final s3 = await FirebaseFirestore.instance
                .collection('productos')
                .get();
            if (s3.docs.isNotEmpty) {
              productosActivos = s3.docs.length;
            } else {
              final s4 = await FirebaseFirestore.instance
                  .collection('producto')
                  .get();
              productosActivos = s4.docs.length;
            }
          }
        }
      } catch (_) {}
      return {
        'pedidosHoy': pedidosHoy,
        'ventasHoy': ventasHoy,
        'pedidosPendientes': pedidosPendientes,
        'productosActivos': productosActivos,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildDashboardContent(),
      const ProductosPage(),
      const PedidosPage(),
      const ReportesPage(),
      if (_esSuperAdmin) const BackupPage(),
      if (_esSuperAdmin) const SuperAdminPage(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5FAF7),
      body: Row(
        children: [
          DashboardSidebar(
            selectedIndex: _selectedIndex,
            adminNombre: widget.adminData['nombre'] ?? '',
            adminRol: widget.adminData['rol'] ?? 'admin',
            onItemSelected: (i) {
              if (_selectedIndex != i) {
                _fadeController.reset();
                _fadeController.forward();
              }
              setState(() => _selectedIndex = i);
            },
            onLogout: _mostrarDialogoCerrarSesion,
          ),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: IndexedStack(
                index: _selectedIndex,
                children: pages,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    return Container(
      color: const Color(0xFFF5FAF7),
      child: Column(
        children: [
          DashboardHeader(
            fechaActual: _obtenerFechaActual(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DashboardWelcomeBanner(
                    nombreAdmin: widget.adminData['nombre'] ?? 'Admin',
                  ),
                  const SizedBox(height: 28),
                  DashboardStatsSection(
                    estadisticasStream: _getEstadisticasStream(),
                    formatNum: formatearNumeroCorto,
                  ),
                  const SizedBox(height: 32),
                  DashboardPedidosRecientes(
                    onVerTodos: () => setState(() => _selectedIndex = 2),
                    colorEstado: _colorEstado,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoCerrarSesion() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.logout_rounded, color: Colors.red[400]),
            ),
            const SizedBox(width: 12),
            const Text('Cerrar Sesión',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('¿Estás seguro de que deseas cerrar sesión?',
                style: TextStyle(fontSize: 15)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.orange[600]),
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
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _cerrarSesion();
            },
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Cerrar Sesión'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cerrarSesion() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Center(
          child: Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const Padding(
              padding: EdgeInsets.all(24),
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
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const AdminLoginPage(mensajeSesionCerrada: true),
        ),
        (r) => false,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      NotificacionPersonalizada.mostrarSnack(context,
          mensaje: 'Error al cerrar sesión: $e',
          tipo: TipoNotificacion.error);
    }
  }
}