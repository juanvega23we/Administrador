// lib/pages/admin/cambiar_password_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_admin_service.dart';
import '../../widgets/notificacion_personalizada.dart';
import 'dashboard/dashboard_page.dart';

class CambiarPasswordPage extends StatefulWidget {
  final Map<String, dynamic> adminData;
  const CambiarPasswordPage({super.key, required this.adminData});

  @override
  State<CambiarPasswordPage> createState() => _CambiarPasswordPageState();
}

class _CambiarPasswordPageState extends State<CambiarPasswordPage>
    with SingleTickerProviderStateMixin {
  final _formKey       = GlobalKey<FormState>();
  final _actualCtrl    = TextEditingController();
  final _nuevaCtrl     = TextEditingController();
  final _confirmaCtrl  = TextEditingController();
  final _authService   = AuthAdminService();

  bool _cargando       = false;
  bool _verActual      = false;
  bool _verNueva       = false;
  bool _verConfirma    = false;

  // Validación en tiempo real
  bool _tieneMayuscula = false;
  bool _tieneMinuscula = false;
  bool _tieneDigito    = false;
  bool _tieneEspecial  = false;
  bool _tieneLongitud  = false;
  bool _passwordTocada = false;

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  static const _verde      = Color(0xFF1B6B2F);
  static const _verdeClaro = Color(0xFF27AE60);
  static const _verdeLight = Color(0xFFE8F5E9);
  static const _gris       = Color(0xFFF7F8FA);

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut)
        as Animation<double>;
    _fadeAnim  = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
    _nuevaCtrl.addListener(_evaluarPassword);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _actualCtrl.dispose();
    _nuevaCtrl.dispose();
    _confirmaCtrl.dispose();
    super.dispose();
  }

  void _evaluarPassword() {
    final v = _nuevaCtrl.text;
    setState(() {
      _passwordTocada  = v.isNotEmpty;
      _tieneMayuscula  = v.contains(RegExp(r'[A-Z]'));
      _tieneMinuscula  = v.contains(RegExp(r'[a-z]'));
      _tieneDigito     = v.contains(RegExp(r'[0-9]'));
      _tieneEspecial   = v.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-\+\=\[\]\\\/]'));
      _tieneLongitud   = v.length >= 8;
    });
  }

  bool get _passwordValida =>
      _tieneMayuscula && _tieneMinuscula && _tieneDigito &&
      _tieneEspecial && _tieneLongitud;

  int get _cumplidos =>
      (_tieneLongitud  ? 1 : 0) + (_tieneMayuscula ? 1 : 0) +
      (_tieneMinuscula ? 1 : 0) + (_tieneDigito    ? 1 : 0) +
      (_tieneEspecial  ? 1 : 0);

  Color get _barColor {
    if (_cumplidos <= 1) return Colors.red;
    if (_cumplidos <= 3) return Colors.orange;
    if (_cumplidos == 4) return Colors.amber;
    return _verdeClaro;
  }

  String get _nivelTexto {
    if (_cumplidos <= 1) return 'Muy débil';
    if (_cumplidos <= 3) return 'Débil';
    if (_cumplidos == 4) return 'Buena';
    return 'Fuerte ✓';
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _cargando = true);

    final res = await _authService.cambiarPassword(
      _actualCtrl.text.trim(),
      _nuevaCtrl.text.trim(),
    );

    if (!mounted) return;

    if (res['exito'] == true) {
      await _authService.marcarPrimerLoginCompleto();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) =>
              DashboardPage(adminData: widget.adminData),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } else {
      setState(() => _cargando = false);
      HapticFeedback.vibrate();
      NotificacionPersonalizada.mostrarSnack(
        context,
        mensaje: res['mensaje'] ?? 'Error al cambiar contraseña',
        tipo: TipoNotificacion.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _gris,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.09),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Cabecera ──────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(32, 32, 32, 28),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_verde, _verdeClaro],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.vertical(
                            top: Radius.circular(28)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.lock_reset_rounded,
                                color: Colors.white, size: 26),
                          ),
                          const SizedBox(height: 18),
                          const Text('Cambia tu contraseña',
                            style: TextStyle(
                              fontSize: 26, fontWeight: FontWeight.w900,
                              color: Colors.white, letterSpacing: -0.5,
                            )),
                          const SizedBox(height: 6),
                          Text(
                            'Por seguridad, debes establecer una contraseña personal antes de continuar.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Aviso de seguridad ────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFFFCC02).withOpacity(0.5)),
                        ),
                        child: const Row(children: [
                          Icon(Icons.info_outline_rounded,
                              color: Color(0xFFF57F17), size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Esta contraseña fue asignada por el Super administrador. '
                              'Crea una nueva que solo tú conozcas.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF795548),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ),

                    // ── Formulario ────────────────────────────
                    Padding(
                      padding: const EdgeInsets.all(28),
                      child: Form(
                        key: _formKey,
                        child: Column(children: [

                          // Contraseña actual
                          _campo(
                            ctrl: _actualCtrl,
                            label: 'Contraseña actual',
                            icon: Icons.lock_outline_rounded,
                            obscure: !_verActual,
                            suffix: _eyeIcon(
                              visible: _verActual,
                              onTap: () =>
                                  setState(() => _verActual = !_verActual),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty)
                                return 'Ingresa tu contraseña actual';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Nueva contraseña
                          _campo(
                            ctrl: _nuevaCtrl,
                            label: 'Nueva contraseña',
                            icon: Icons.lock_rounded,
                            obscure: !_verNueva,
                            suffix: _eyeIcon(
                              visible: _verNueva,
                              onTap: () =>
                                  setState(() => _verNueva = !_verNueva),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty)
                                return 'Ingresa la nueva contraseña';
                              if (!_passwordValida)
                                return 'La contraseña no cumple los requisitos';
                              return null;
                            },
                          ),

                          // Indicador de fortaleza
                          if (_passwordTocada) ...[
                            const SizedBox(height: 12),
                            _indicadorFortaleza(),
                          ],
                          const SizedBox(height: 16),

                          // Confirmar contraseña
                          _campo(
                            ctrl: _confirmaCtrl,
                            label: 'Confirmar contraseña',
                            icon: Icons.lock_rounded,
                            obscure: !_verConfirma,
                            accion: TextInputAction.done,
                            onSubmit: (_) => _guardar(),
                            suffix: _eyeIcon(
                              visible: _verConfirma,
                              onTap: () =>
                                  setState(() => _verConfirma = !_verConfirma),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty)
                                return 'Confirma tu nueva contraseña';
                              if (v != _nuevaCtrl.text)
                                return 'Las contraseñas no coinciden';
                              return null;
                            },
                          ),
                          const SizedBox(height: 28),

                          // Botón guardar
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: _cargando
                                    ? null
                                    : const LinearGradient(
                                        colors: [_verde, _verdeClaro],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: _cargando
                                    ? []
                                    : [
                                        BoxShadow(
                                          color: _verde.withOpacity(0.35),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                              ),
                              child: ElevatedButton(
                                onPressed: _cargando ? null : _guardar,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  disabledBackgroundColor: Colors.grey[200],
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                                child: _cargando
                                    ? const SizedBox(
                                        width: 22, height: 22,
                                        child: CircularProgressIndicator(
                                            color: _verde, strokeWidth: 2.5))
                                    : const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.check_circle_rounded,
                                              color: Colors.white, size: 20),
                                          SizedBox(width: 10),
                                          Text('Guardar y continuar',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            )),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _eyeIcon({required bool visible, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Icon(
          visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: Colors.grey[500], size: 20,
        ),
      );

  Widget _campo({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputAction accion = TextInputAction.next,
    ValueChanged<String>? onSubmit,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: ctrl,
        obscureText: obscure,
        textInputAction: accion,
        onFieldSubmitted: onSubmit,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: validator,
        enabled: !_cargando,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
          prefixIcon: Icon(icon, color: _verde.withOpacity(0.6), size: 20),
          suffixIcon: suffix != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 12), child: suffix)
              : null,
          suffixIconConstraints:
              const BoxConstraints(minWidth: 0, minHeight: 0),
          filled: true,
          fillColor: _gris,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: Colors.grey[200]!, width: 1.5)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _verde, width: 2)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFE53935), width: 1.5)),
          focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFE53935), width: 2)),
        ),
      );

  Widget _indicadorFortaleza() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _gris,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey[200]!),
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
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(_barColor),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(_nivelTexto,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _barColor)),
            ]),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 6,
              children: [
                _req(_tieneLongitud,  'Mín. 8 caracteres'),
                _req(_tieneMayuscula, 'Mayúscula'),
                _req(_tieneMinuscula, 'Minúscula'),
                _req(_tieneDigito,    'Número'),
                _req(_tieneEspecial,  'Carácter especial'),
              ],
            ),
          ],
        ),
      );

  Widget _req(bool cumple, String texto) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            cumple
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 14,
            color: cumple ? _verdeClaro : Colors.grey[400],
          ),
          const SizedBox(width: 4),
          Text(texto,
            style: TextStyle(
              fontSize: 11,
              color: cumple ? _verdeClaro : Colors.grey[500],
              fontWeight: cumple ? FontWeight.w600 : FontWeight.normal,
            )),
        ],
      );
}