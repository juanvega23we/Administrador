// lib/pages/super_admin/super_admin_page.dart

import 'package:flutter/material.dart';
import '../../widgets/notificacion_personalizada.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/super_admin_service.dart';

// ── Formatter: solo letras y espacios ────────────────────────
class _SoloLetrasFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final soloLetras = RegExp(r"^[a-zA-ZáéíóúÁÉÍÓÚüÜñÑ\s]*$");
    return soloLetras.hasMatch(newValue.text) ? newValue : oldValue;
  }
}


class SuperAdminPage extends StatefulWidget {
  const SuperAdminPage({super.key});

  @override
  State<SuperAdminPage> createState() => _SuperAdminPageState();
}

class _SuperAdminPageState extends State<SuperAdminPage> {
  final SuperAdminService _service = SuperAdminService();

  @override
  void initState() {
    super.initState();
    _service.verificarVencimientos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0B4D3B), Color(0xFF1A7A57)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: const Color(0xFF0B4D3B).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: const Icon(Icons.shield_rounded, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Panel Super Admin',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF111827), letterSpacing: -0.5)),
                    Text('Gestión de administradores y licencias',
                      style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                  ],
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _mostrarDialogoCrearAdmin(),
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  label: const Text('Nuevo Admin', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B4D3B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _service.obtenerAdmins(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF0B4D3B)));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
                          child: const Icon(Icons.people_outline_rounded, size: 56, color: Color(0xFF16A34A)),
                        ),
                        const SizedBox(height: 20),
                        const Text('No hay administradores registrados',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
                        const SizedBox(height: 8),
                        Text('Crea el primero con el botón "Nuevo Admin"',
                          style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                      ],
                    ),
                  );
                }
                final admins = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.all(28),
                  itemCount: admins.length,
                  itemBuilder: (context, index) {
                    final data = admins[index].data() as Map<String, dynamic>;
                    final uid  = admins[index].id;
                    return _AdminCard(uid: uid, data: data, service: _service, onRefresh: () => setState(() {}));
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoCrearAdmin() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogoCrearAdmin(service: _service),
    );
  }
}

// ── Tarjeta de admin ──────────────────────────────────────────
class _AdminCard extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> data;
  final SuperAdminService service;
  final VoidCallback onRefresh;

  const _AdminCard({required this.uid, required this.data, required this.service, required this.onRefresh});

  bool get _estaVencido {
    final venc = data['fechaVencimiento'] as Timestamp?;
    if (venc == null) return false;
    return venc.toDate().isBefore(DateTime.now());
  }

  String _formatFecha(Timestamp? ts) {
    if (ts == null) return 'Sin fecha';
    final d = ts.toDate();
    const meses = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    return '${d.day} ${meses[d.month - 1]} ${d.year}';
  }

  int _diasRestantes() {
    final venc = data['fechaVencimiento'] as Timestamp?;
    if (venc == null) return 0;
    return venc.toDate().difference(DateTime.now()).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final activo      = data['activo'] == true;
    final vencido     = _estaVencido;
    final dias        = _diasRestantes();
    final estadoColor = !activo ? Colors.red : vencido ? Colors.orange : const Color(0xFF16A34A);
    final estadoTexto = !activo ? 'Bloqueado' : vencido ? 'Vencido' : 'Activo';
    final estadoIcon  = !activo ? Icons.block_rounded : vencido ? Icons.timer_off_rounded : Icons.check_circle_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: !activo ? Colors.red.withOpacity(0.2) : vencido ? Colors.orange.withOpacity(0.2) : const Color(0xFFF3F4F6),
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: activo && !vencido
                          ? [const Color(0xFF0B4D3B), const Color(0xFF1A7A57)]
                          : [Colors.grey[400]!, Colors.grey[300]!],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      (data['nombre'] as String? ?? 'A')[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(data['nombre'] ?? 'Sin nombre',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: estadoColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: estadoColor.withOpacity(0.3)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(estadoIcon, size: 11, color: estadoColor),
                              const SizedBox(width: 4),
                              Text(estadoTexto, style: TextStyle(fontSize: 10, color: estadoColor, fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(data['email']   ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      Text(data['negocio'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF0B4D3B), fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: const Icon(Icons.more_horiz_rounded, size: 18, color: Color(0xFF6B7280)),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'toggle',
                      child: Row(children: [
                        Icon(activo ? Icons.block_rounded : Icons.check_circle_rounded,
                          color: activo ? Colors.red : Colors.green, size: 18),
                        const SizedBox(width: 10),
                        Text(activo ? 'Bloquear acceso' : 'Activar acceso',
                          style: TextStyle(color: activo ? Colors.red : Colors.green, fontWeight: FontWeight.w600)),
                      ])),
                    PopupMenuItem(value: 'renovar',
                      child: Row(children: [
                        const Icon(Icons.calendar_month_rounded, color: Color(0xFF2563EB), size: 18),
                        const SizedBox(width: 10),
                        const Text('Renovar licencia', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                      ])),
                    PopupMenuItem(value: 'eliminar',
                      child: Row(children: [
                        const Icon(Icons.delete_rounded, color: Colors.red, size: 18),
                        const SizedBox(width: 10),
                        const Text('Eliminar cuenta', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                      ])),
                  ],
                  onSelected: (val) => _accion(context, val),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF3F4F6)),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 15, color: estadoColor),
                  const SizedBox(width: 8),
                  Text('Vence: ${_formatFecha(data['fechaVencimiento'] as Timestamp?)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: estadoColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      vencido ? 'Vencido' : '$dias días restantes',
                      style: TextStyle(fontSize: 11, color: estadoColor, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _accion(BuildContext context, String accion) async {
    switch (accion) {
      case 'toggle':
        final activo = data['activo'] == true;
        final ok = await service.toggleActivo(uid, !activo);
        if (context.mounted) {
          NotificacionPersonalizada.mostrarSnack(context, mensaje: ok ? (activo ? 'Admin bloqueado' : 'Admin activado') : 'Error al actualizar', tipo: ok ? (activo ? TipoNotificacion.advertencia : TipoNotificacion.exito) : TipoNotificacion.error);
        }
        break;
      case 'renovar':
        if (context.mounted) _mostrarDialogoRenovar(context);
        break;
      case 'eliminar':
        if (context.mounted) _mostrarDialogoEliminar(context);
        break;
    }
  }

  void _mostrarDialogoRenovar(BuildContext context) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 30));
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Row(children: [
            Icon(Icons.calendar_month_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 10),
            Text('Renovar Licencia', style: TextStyle(fontWeight: FontWeight.w800)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Admin: ${data['nombre']}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [15, 30, 60, 90, 180, 365].map((dias) =>
                  ActionChip(
                    label: Text('$dias días'),
                    backgroundColor: const Color(0xFFDCFCE7),
                    labelStyle: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w700),
                    onPressed: () => setS(() => selectedDate = DateTime.now().add(Duration(days: dias))),
                  ),
                ).toList(),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(children: [
                  const Icon(Icons.event_rounded, color: Color(0xFF16A34A), size: 18),
                  const SizedBox(width: 8),
                  Text('Nueva fecha: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                    style: const TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.w700)),
                ]),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await service.actualizarVencimiento(uid, selectedDate);
                if (context.mounted) {
                  NotificacionPersonalizada.mostrarSnack(context,
                    mensaje: ok ? 'Licencia renovada hasta ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}' : 'Error al renovar',
                    tipo: ok ? TipoNotificacion.exito : TipoNotificacion.error);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0B4D3B), foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Renovar', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoEliminar(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(children: [
          Icon(Icons.warning_rounded, color: Colors.red),
          SizedBox(width: 10),
          Text('Eliminar Admin', style: TextStyle(fontWeight: FontWeight.w800)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('¿Eliminar la cuenta de ${data['nombre']}?', style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, color: Colors.red, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text('Esta acción no se puede deshacer', style: TextStyle(fontSize: 12, color: Colors.red))),
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await service.eliminarAdmin(uid);
              if (context.mounted) {
                NotificacionPersonalizada.mostrarSnack(context, mensaje: ok ? 'Admin eliminado exitosamente' : 'Error al eliminar', tipo: ok ? TipoNotificacion.exito : TipoNotificacion.error);
              }
            },
            icon: const Icon(Icons.delete_rounded, size: 16),
            label: const Text('Eliminar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  Diálogo crear admin — con contadores de caracteres
// ═════════════════════════════════════════════════════════════
class _DialogoCrearAdmin extends StatefulWidget {
  final SuperAdminService service;
  const _DialogoCrearAdmin({required this.service});

  @override
  State<_DialogoCrearAdmin> createState() => _DialogoCrearAdminState();
}

class _DialogoCrearAdminState extends State<_DialogoCrearAdmin> {
  final _formKey      = GlobalKey<FormState>();
  final _nombreCtrl   = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _negocioCtrl  = TextEditingController();

  DateTime _fechaVenc         = DateTime.now().add(const Duration(days: 30));
  bool     _cargando          = false;
  bool     _verPassword       = false;
  int      _diasSeleccionados = 30;

  // Validación contraseña en tiempo real
  bool _tieneMayuscula = false;
  bool _tieneMinuscula = false;
  bool _tieneDigito    = false;
  bool _tieneEspecial  = false;
  bool _tieneLongitud  = false;
  bool _passwordTocada = false;

  // ── Límites de caracteres (igual que producto_form) ───────
  static const int _maxNombre  = 100;
  static const int _maxNegocio = 100;
  static const int _maxEmail   = 100;

  static const _dominiosPermitidos = ['gmail.com', 'yahoo.com', 'outlook.com'];

  @override
  void initState() {
    super.initState();
    _passwordCtrl.addListener(_evaluarPassword);
    _nombreCtrl.addListener(()  => setState(() {}));
    _negocioCtrl.addListener(() => setState(() {}));
    _emailCtrl.addListener(()   => setState(() {}));
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _negocioCtrl.dispose();
    super.dispose();
  }

  void _evaluarPassword() {
    final v = _passwordCtrl.text;
    setState(() {
      _passwordTocada  = v.isNotEmpty;
      _tieneMayuscula  = v.contains(RegExp(r'[A-Z]'));
      _tieneMinuscula  = v.contains(RegExp(r'[a-z]'));
      _tieneDigito     = v.contains(RegExp(r'[0-9]'));
      _tieneEspecial   = v.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-\+\=\[\]\\\/]'));
      _tieneLongitud   = v.length >= 6;
    });
  }

  bool get _passwordValida =>
      _tieneMayuscula && _tieneMinuscula && _tieneDigito && _tieneEspecial && _tieneLongitud;

  void _seleccionarDias(int dias) {
    setState(() {
      _diasSeleccionados = dias;
      _fechaVenc = DateTime.now().add(Duration(days: dias));
    });
  }

  String? _validarNombre(String? v) {
    if (v == null || v.trim().isEmpty) return 'El nombre es obligatorio';
    if (v.trim().length < 3) return 'Mínimo 3 caracteres';
    if (!RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$').hasMatch(v.trim()))
      return 'Solo letras y espacios';
    return null;
  }

  String? _validarNegocio(String? v) {
    if (v == null || v.trim().isEmpty) return 'El nombre del negocio es obligatorio';
    if (v.trim().length < 2) return 'Mínimo 2 caracteres';
    return null;
  }

  String? _validarEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'El email es obligatorio';
    final email = v.trim().toLowerCase();
    if (!email.contains('@')) return 'Formato de email inválido';
    final partes = email.split('@');
    if (partes.length != 2 || partes[0].isEmpty) return 'Formato de email inválido';
    if (!_dominiosPermitidos.contains(partes[1]))
      return 'Solo @gmail.com, @yahoo.com o @outlook.com';
    return null;
  }

  String? _validarPassword(String? v) {
    if (v == null || v.isEmpty) return 'La contraseña es obligatoria';
    if (!_passwordValida) return 'La contraseña no cumple los requisitos';
    return null;
  }

  // ── Contador igual al de producto_form ────────────────────
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

  // ── Decoración reutilizable con contador en suffix ────────
  InputDecoration _deco({
    required String label,
    required String helper,
    required Widget contador,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      helperText: helper,
      helperStyle: TextStyle(fontSize: 11, color: Colors.grey[600]),
      prefixIcon: Icon(prefixIcon, color: const Color(0xFF0B4D3B), size: 20),
      suffixIcon: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: contador,
      ),
      suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF0B4D3B), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
    );
  }

  Future<void> _crear() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);

    final result = await widget.service.crearAdmin(
      nombre:           _nombreCtrl.text.trim(),
      email:            _emailCtrl.text.trim().toLowerCase(),
      password:         _passwordCtrl.text,
      negocio:          _negocioCtrl.text.trim(),
      fechaVencimiento: _fechaVenc,
    );

    if (!mounted) return;
    setState(() => _cargando = false);

    if (result['exito'] == true) {
      Navigator.pop(context);
      NotificacionPersonalizada.mostrarSnack(context, mensaje: 'Administrador creado exitosamente', tipo: TipoNotificacion.exito);
    } else {
      NotificacionPersonalizada.mostrarSnack(context, mensaje: result['mensaje'] ?? 'Error al crear el administrador', tipo: TipoNotificacion.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombreLen  = _nombreCtrl.text.length;
    final negocioLen = _negocioCtrl.text.length;
    final emailLen   = _emailCtrl.text.length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(32),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ───────────────────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF0B4D3B), Color(0xFF1A7A57)]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Nuevo Administrador',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
                        Text('Crea una cuenta de admin',
                          style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                      ],
                    ),
                    const Spacer(),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
                const SizedBox(height: 28),

                // ── Nombre completo ───────────────────────────
                TextFormField(
                  controller: _nombreCtrl,
                  keyboardType: TextInputType.name,
                  inputFormatters: [
                    _SoloLetrasFormatter(),
                    LengthLimitingTextInputFormatter(_maxNombre),
                  ],
                  textCapitalization: TextCapitalization.words,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: _validarNombre,
                  decoration: _deco(
                    label: 'Nombre completo',
                    helper: 'Solo letras · Máx. $_maxNombre caracteres',
                    prefixIcon: Icons.person_rounded,
                    contador: _contador(nombreLen, _maxNombre),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Nombre del negocio ────────────────────────
                TextFormField(
                  controller: _negocioCtrl,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(_maxNegocio),
                  ],
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: _validarNegocio,
                  decoration: _deco(
                    label: 'Nombre del negocio',
                    helper: 'Máx. $_maxNegocio caracteres',
                    prefixIcon: Icons.storefront_rounded,
                    contador: _contador(negocioLen, _maxNegocio),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Email ─────────────────────────────────────
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(_maxEmail),
                  ],
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: _validarEmail,
                  decoration: _deco(
                    label: 'Email',
                    helper: 'Solo @gmail.com · @yahoo.com · @outlook.com',
                    prefixIcon: Icons.email_rounded,
                    contador: _contador(emailLen, _maxEmail),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Contraseña ────────────────────────────────
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: !_verPassword,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: _validarPassword,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_rounded, color: Color(0xFF0B4D3B), size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(_verPassword ? Icons.visibility_off : Icons.visibility,
                          size: 18, color: Colors.grey),
                      onPressed: () => setState(() => _verPassword = !_verPassword),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF0B4D3B), width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.red, width: 1.5),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                  ),
                ),

                // ── Indicador de fortaleza ────────────────────
                if (_passwordTocada) ...[
                  const SizedBox(height: 12),
                  _IndicadorPassword(
                    tieneMayuscula: _tieneMayuscula,
                    tieneMinuscula: _tieneMinuscula,
                    tieneDigito:    _tieneDigito,
                    tieneEspecial:  _tieneEspecial,
                    tieneLongitud:  _tieneLongitud,
                  ),
                ],
                const SizedBox(height: 20),

                // ── Duración de licencia ──────────────────────
                const Text('Duración de licencia',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [15, 30, 60, 90, 180, 365].map((dias) =>
                    ChoiceChip(
                      label: Text(
                        dias >= 365 ? '1 año'
                        : dias >= 30 ? '${dias ~/ 30} ${dias ~/ 30 == 1 ? "mes" : "meses"}'
                        : '$dias días',
                      ),
                      selected: _diasSeleccionados == dias,
                      onSelected: (_) => _seleccionarDias(dias),
                      selectedColor: const Color(0xFF0B4D3B),
                      labelStyle: TextStyle(
                        color: _diasSeleccionados == dias ? Colors.white : const Color(0xFF374151),
                        fontWeight: FontWeight.w700, fontSize: 12,
                      ),
                    ),
                  ).toList(),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.event_rounded, color: Color(0xFF16A34A), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Vence el ${_fechaVenc.day}/${_fechaVenc.month}/${_fechaVenc.year}',
                      style: const TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),

                // ── Botón crear ───────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _cargando ? null : _crear,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0B4D3B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _cargando
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text('Crear Administrador',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
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

// ── Indicador de fortaleza de contraseña ─────────────────────
class _IndicadorPassword extends StatelessWidget {
  final bool tieneMayuscula;
  final bool tieneMinuscula;
  final bool tieneDigito;
  final bool tieneEspecial;
  final bool tieneLongitud;

  const _IndicadorPassword({
    required this.tieneMayuscula,
    required this.tieneMinuscula,
    required this.tieneDigito,
    required this.tieneEspecial,
    required this.tieneLongitud,
  });

  int get _cumplidos =>
      (tieneLongitud  ? 1 : 0) + (tieneMayuscula ? 1 : 0) +
      (tieneMinuscula ? 1 : 0) + (tieneDigito    ? 1 : 0) +
      (tieneEspecial  ? 1 : 0);

  Color get _barColor {
    if (_cumplidos <= 1) return Colors.red;
    if (_cumplidos <= 3) return Colors.orange;
    if (_cumplidos == 4) return Colors.amber;
    return const Color(0xFF16A34A);
  }

  String get _nivelTexto {
    if (_cumplidos <= 1) return 'Muy débil';
    if (_cumplidos <= 3) return 'Débil';
    if (_cumplidos == 4) return 'Buena';
    return 'Fuerte ✓';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _cumplidos / 5,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor: AlwaysStoppedAnimation<Color>(_barColor),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(_nivelTexto,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _barColor)),
          ]),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 6,
            children: [
              _Requisito(cumple: tieneLongitud,  texto: 'Mín. 6 caracteres'),
              _Requisito(cumple: tieneMayuscula, texto: 'Mayúscula'),
              _Requisito(cumple: tieneMinuscula, texto: 'Minúscula'),
              _Requisito(cumple: tieneDigito,    texto: 'Número'),
              _Requisito(cumple: tieneEspecial,  texto: 'Carácter especial'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Requisito extends StatelessWidget {
  final bool cumple;
  final String texto;
  const _Requisito({required this.cumple, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          cumple ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 14,
          color: cumple ? const Color(0xFF16A34A) : Colors.grey[400],
        ),
        const SizedBox(width: 4),
        Text(
          texto,
          style: TextStyle(
            fontSize: 11,
            color: cumple ? const Color(0xFF16A34A) : Colors.grey[500],
            fontWeight: cumple ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}