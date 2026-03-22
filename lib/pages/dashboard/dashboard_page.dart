import 'package:flutter/material.dart';
import '../../widgets/notificacion_personalizada.dart';
import '../login_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../productos/productos_page.dart';
import '../../utils/numero_formato.dart';
import '../pedidos/pedidos_page.dart';
import '../devoluciones/devoluciones_page.dart';
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
  late Stream<Map<String, dynamic>> _estadisticasStream;

  bool get _esSuperAdmin => widget.adminData['rol'] == 'super_admin';

  // Cache de productos para no re-consultar en cada update
  int? _productosActivosCache;

  @override
  void initState() {
    super.initState();
    _estadisticasStream = _getEstadisticasStream();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    // Cargar productos una sola vez al iniciar
    _cargarProductosActivos();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // Productos se cargan una sola vez, no en cada snapshot
  Future<void> _cargarProductosActivos() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('productos')
          .where('activo', isEqualTo: true)
          .count()
          .get();
      if (mounted) {
        setState(() => _productosActivosCache = snap.count ?? 0);
      }
    } catch (_) {
      // Fallback: contar sin filtro
      try {
        final snap = await FirebaseFirestore.instance
            .collection('productos')
            .count()
            .get();
        if (mounted) {
          setState(() => _productosActivosCache = snap.count ?? 0);
        }
      } catch (_) {}
    }
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

  // Solo pedidos de HOY sin límite — el volumen diario es siempre manejable
  Stream<Map<String, dynamic>> _getEstadisticasStream() {
    final hoy = DateTime.now();
    final inicioDia = DateTime(hoy.year, hoy.month, hoy.day);

    return FirebaseFirestore.instance
        .collection('pedido')
        .where('fechaPedido',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDia))
        .orderBy('fechaPedido', descending: true)
        .snapshots()
        .map((snapshot) {
      int pedidosHoy        = 0;
      double ventasHoy      = 0;
      int pedidosPendientes = 0;

      for (final doc in snapshot.docs) {
        final data   = doc.data();
        final estado = data['estado']?.toString() ?? '';
        pedidosHoy++;
        if (estado == 'entregado') {
          // Para pedidos con reenvío usar totalPrimeraEntrega + totalReenvio si existen
          if (data['esReenvio'] == true &&
              data['totalPrimeraEntrega'] != null &&
              data['totalReenvio'] != null) {
            ventasHoy += (data['totalPrimeraEntrega'] as num).toDouble() +
                         (data['totalReenvio'] as num).toDouble();
          } else {
            ventasHoy += ((data['total'] as num?) ?? 0.0).toDouble();
          }
        }
        if (estado == 'pendiente') pedidosPendientes++;
      }

      return {
        'pedidosHoy':        pedidosHoy,
        'ventasHoy':         ventasHoy,
        'pedidosPendientes': pedidosPendientes,
        // Usa el cache en lugar de hacer query extra
        'productosActivos':  _productosActivosCache ?? 0,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildDashboardContent(),
      const ProductosPage(),
      const PedidosPage(),
      const DevolucionesPage(),
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
          DashboardHeader(fechaActual: _obtenerFechaActual()),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DashboardWelcomeBanner(
                    nombreAdmin: _esSuperAdmin
                        ? 'Super Administrador'
                        : widget.adminData['nombre'] ?? 'Admin',
                    subtitulo: _esSuperAdmin ? null : 'Administrador',
                  ),
                  const SizedBox(height: 28),
                  DashboardStatsSection(
                    estadisticasStream: _estadisticasStream,
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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