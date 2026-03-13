import 'package:flutter/material.dart';
import '../widgets/notificacion_personalizada.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../../services/auth_admin_service.dart';
import 'dashboard/dashboard_page.dart';
import 'cambiar_password_page.dart';

class AdminLoginPage extends StatefulWidget {
  final bool mensajeSesionCerrada;
  const AdminLoginPage({super.key, this.mensajeSesionCerrada = false});
  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage>
    with TickerProviderStateMixin {
  final _formKey     = GlobalKey<FormState>();
  final _emailCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _authService = AuthAdminService();

  bool _cargando    = false;
  bool _mostrarPass = false;

  late AnimationController _entradaCtrl;
  late AnimationController _floatCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _staggerCtrl;

  late Animation<double> _bgFade;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<Offset>  _logoSlide;
  late Animation<double>  _titleFade;
  late Animation<Offset>  _titleSlide;
  late Animation<double>  _cardScale;
  late Animation<double>  _cardFade;
  late Animation<Offset>  _cardSlide;
  late Animation<double>  _feature1Fade;
  late Animation<double>  _feature2Fade;
  late Animation<double>  _feature3Fade;
  late Animation<double>  _feature4Fade;
  late Animation<Offset>  _feature1Slide;
  late Animation<Offset>  _feature2Slide;
  late Animation<Offset>  _feature3Slide;
  late Animation<Offset>  _feature4Slide;
  late Animation<double>  _floatY;
  late Animation<double>  _pulse;

  static const _verde      = Color(0xFF1B6B2F);
  static const _verdeClaro = Color(0xFF27AE60);
  static const _verdeLight = Color(0xFFE8F5E9);
  static const _blanco     = Colors.white;
  static const _gris       = Color(0xFFF7F8FA);
  static const _texto      = Color(0xFF1A1A2E);
  static const _subtexto   = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();

    _entradaCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800));
    _staggerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200));
    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3500))
      ..repeat(reverse: true);
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);

    _bgFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _entradaCtrl,
            curve: const Interval(0.0, 0.3, curve: Curves.easeIn)));
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _entradaCtrl,
            curve: const Interval(0.1, 0.45, curve: Curves.easeOut)));
    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _entradaCtrl,
            curve: const Interval(0.1, 0.5, curve: Curves.elasticOut)));
    _logoSlide = Tween<Offset>(
        begin: const Offset(-0.3, 0), end: Offset.zero).animate(
        CurvedAnimation(parent: _entradaCtrl,
            curve: const Interval(0.1, 0.5, curve: Curves.easeOutCubic)));
    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _entradaCtrl,
            curve: const Interval(0.25, 0.55, curve: Curves.easeOut)));
    _titleSlide = Tween<Offset>(
        begin: const Offset(-0.2, 0), end: Offset.zero).animate(
        CurvedAnimation(parent: _entradaCtrl,
            curve: const Interval(0.25, 0.55, curve: Curves.easeOutCubic)));
    _cardFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _entradaCtrl,
            curve: const Interval(0.35, 0.75, curve: Curves.easeOut)));
    _cardScale = Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(parent: _entradaCtrl,
            curve: const Interval(0.35, 0.8, curve: Curves.easeOutBack)));
    _cardSlide = Tween<Offset>(
        begin: const Offset(0.2, 0.05), end: Offset.zero).animate(
        CurvedAnimation(parent: _entradaCtrl,
            curve: const Interval(0.35, 0.75, curve: Curves.easeOutCubic)));

    _feature1Fade  = _featureFadeAnim(0.0);
    _feature2Fade  = _featureFadeAnim(0.15);
    _feature3Fade  = _featureFadeAnim(0.30);
    _feature4Fade  = _featureFadeAnim(0.45);
    _feature1Slide = _featureSlideAnim(0.0);
    _feature2Slide = _featureSlideAnim(0.15);
    _feature3Slide = _featureSlideAnim(0.30);
    _feature4Slide = _featureSlideAnim(0.45);

    _floatY = Tween<double>(begin: -6.0, end: 6.0).animate(
        CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
    _pulse = Tween<double>(begin: 0.95, end: 1.05).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    Future.delayed(const Duration(milliseconds: 100), () {
      _entradaCtrl.forward();
      _staggerCtrl.forward();
    });

    if (widget.mensajeSesionCerrada) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) NotificacionPersonalizada.mostrarSnack(context,
            mensaje: 'Sesión cerrada exitosamente',
            tipo: TipoNotificacion.exito);
      });
    }

    _verificarSesion();
  }

  Animation<double> _featureFadeAnim(double start) =>
      Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
          parent: _staggerCtrl,
          curve: Interval(0.4 + start, 0.7 + start, curve: Curves.easeOut)));

  Animation<Offset> _featureSlideAnim(double start) =>
      Tween<Offset>(begin: const Offset(-0.3, 0), end: Offset.zero)
          .animate(CurvedAnimation(
          parent: _staggerCtrl,
          curve: Interval(0.4 + start, 0.7 + start,
              curve: Curves.easeOutCubic)));

  // ✅ CORREGIDO: también chequea primerLogin en sesión activa
  Future<void> _verificarSesion() async {
    final s = await _authService.verificarSesionActiva();
    if (s != null && mounted) {
      if (s['primerLogin'] == true) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) =>
                CambiarPasswordPage(adminData: s),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
        return;
      }
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => DashboardPage(adminData: s)));
    }
  }

  // ✅ CORREGIDO: lee primerLogin del resultado del login
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _cargando = true);

    final res = await _authService.loginAdmin(
        _emailCtrl.text.trim(), _passCtrl.text.trim());

    if (!mounted) return;
    setState(() => _cargando = false);

    if (res['exito'] == true) {
      // Primer login → forzar cambio de contraseña
      if (res['primerLogin'] == true) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) =>
                CambiarPasswordPage(adminData: res['admin']),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
        return;
      }

      // Login normal
      Navigator.pushReplacement(context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) =>
                DashboardPage(adminData: res['admin']),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 600),
          ));
    } else {
      HapticFeedback.vibrate();
      _entradaCtrl.reverse().then((_) => _entradaCtrl.forward());
      NotificacionPersonalizada.mostrarSnack(context,
          mensaje: res['mensaje'], tipo: TipoNotificacion.error);
    }
  }

  @override
  void dispose() {
    _entradaCtrl.dispose();
    _staggerCtrl.dispose();
    _floatCtrl.dispose();
    _pulseCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size   = MediaQuery.of(context).size;
    final isWide = size.width > 800;

    return Scaffold(
      backgroundColor: _gris,
      body: FadeTransition(
        opacity: _bgFade,
        child: Stack(
          children: [
            _buildBgDecorations(size),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                      horizontal: isWide ? 48 : 24, vertical: 32),
                  child: isWide ? _wideLayout() : _narrowLayout(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBgDecorations(Size size) {
    return Stack(children: [
      Positioned(
        top: -100, left: -100,
        child: AnimatedBuilder(
          animation: _floatCtrl,
          builder: (_, __) => Transform.translate(
            offset: Offset(_floatY.value * 0.5, _floatY.value),
            child: Container(
              width: 350, height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  _verde.withOpacity(0.08), _verde.withOpacity(0.0),
                ]),
              ),
            ),
          ),
        ),
      ),
      Positioned(
        bottom: -80, right: -80,
        child: AnimatedBuilder(
          animation: _floatCtrl,
          builder: (_, __) => Transform.translate(
            offset: Offset(-_floatY.value * 0.3, -_floatY.value * 0.7),
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  _verdeClaro.withOpacity(0.07), _verdeClaro.withOpacity(0.0),
                ]),
              ),
            ),
          ),
        ),
      ),
      Positioned(
        top: size.height * 0.15, right: size.width * 0.08,
        child: AnimatedBuilder(
          animation: _floatCtrl,
          builder: (_, __) => Transform.translate(
            offset: Offset(0, _floatY.value * 1.2),
            child: Container(width: 14, height: 14,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: _verdeClaro.withOpacity(0.3))),
          ),
        ),
      ),
      Positioned(
        top: size.height * 0.6, left: size.width * 0.05,
        child: AnimatedBuilder(
          animation: _floatCtrl,
          builder: (_, __) => Transform.translate(
            offset: Offset(0, -_floatY.value),
            child: Container(width: 10, height: 10,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: _verde.withOpacity(0.2))),
          ),
        ),
      ),
      Positioned(
        top: size.height * 0.35, right: size.width * 0.03,
        child: AnimatedBuilder(
          animation: _floatCtrl,
          builder: (_, __) => Transform.translate(
            offset: Offset(_floatY.value * 0.5, _floatY.value * 0.8),
            child: Container(width: 7, height: 7,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: _verde.withOpacity(0.15))),
          ),
        ),
      ),
    ]);
  }

  Widget _wideLayout() => Container(
    constraints: const BoxConstraints(maxWidth: 980),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(flex: 5, child: _leftPanel()),
        const SizedBox(width: 56),
        Expanded(flex: 5, child: _cardForm()),
      ],
    ),
  );

  Widget _narrowLayout() => Column(children: [
    _logoSection(),
    const SizedBox(height: 36),
    _cardForm(),
  ]);

  Widget _leftPanel() => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      FadeTransition(
        opacity: _logoFade,
        child: SlideTransition(
          position: _logoSlide,
          child: ScaleTransition(
            scale: _logoScale,
            child: AnimatedBuilder(
              animation: _floatCtrl,
              builder: (_, child) => Transform.translate(
                  offset: Offset(0, _floatY.value * 0.4), child: child),
              child: _logoWidget(190),
            ),
          ),
        ),
      ),
      const SizedBox(height: 28),
      FadeTransition(
        opacity: _titleFade,
        child: SlideTransition(
          position: _titleSlide,
          child: Column(children: [
            const Text('Granero del Norte',
              style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900,
                  color: _verde, letterSpacing: -1, height: 1.1),
              textAlign: TextAlign.center),
            const SizedBox(height: 12),
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, child) =>
                  Transform.scale(scale: _pulse.value, child: child),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _verdeLight,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: _verde.withOpacity(0.25)),
                  boxShadow: [BoxShadow(color: _verde.withOpacity(0.15),
                      blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Panel Administrativo',
                    style: TextStyle(fontSize: 13, color: _verde,
                        fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 44),
      _featureAnimado(_feature1Fade, _feature1Slide,
          Icons.speed_rounded, 'Dashboard en tiempo real', 0),
      _featureAnimado(_feature2Fade, _feature2Slide,
          Icons.inventory_2_rounded, 'Gestión de inventario', 1),
      _featureAnimado(_feature3Fade, _feature3Slide,
          Icons.receipt_long_rounded, 'Control de pedidos', 2),
      _featureAnimado(_feature4Fade, _feature4Slide,
          Icons.insights_rounded, 'Reportes y análisis', 3),
    ],
  );

  Widget _featureAnimado(Animation<double> fade, Animation<Offset> slide,
      IconData icon, String label, int index) =>
      FadeTransition(
        opacity: fade,
        child: SlideTransition(
          position: slide,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _FeatureCard(icon: icon, label: label, index: index),
          ),
        ),
      );

  Widget _logoSection() => FadeTransition(
    opacity: _logoFade,
    child: ScaleTransition(
      scale: _logoScale,
      child: AnimatedBuilder(
        animation: _floatCtrl,
        builder: (_, child) => Transform.translate(
            offset: Offset(0, _floatY.value * 0.3), child: child),
        child: Column(children: [
          _logoWidget(100),
          const SizedBox(height: 14),
          const Text('Granero del Norte',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900,
                color: _verde)),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, child) =>
                Transform.scale(scale: _pulse.value, child: child),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                  color: _verdeLight,
                  borderRadius: BorderRadius.circular(20)),
              child: const Text('Panel Administrativo',
                style: TextStyle(fontSize: 11, color: _verde,
                    fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    ),
  );

  Widget _logoWidget(double size) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle, color: _blanco,
      boxShadow: [
        BoxShadow(color: _verde.withOpacity(0.2),
            blurRadius: 30, spreadRadius: 2, offset: const Offset(0, 8)),
        BoxShadow(color: Colors.black.withOpacity(0.06),
            blurRadius: 15, offset: const Offset(0, 4)),
      ],
      border: Border.all(color: _verde.withOpacity(0.15), width: 3),
    ),
    child: ClipOval(
      child: Image.asset('assets/images/logo_granero.jpeg',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: _verdeLight,
          child: Icon(Icons.eco_rounded, color: _verde, size: size * 0.42),
        ),
      ),
    ),
  );

  Widget _cardForm() => FadeTransition(
    opacity: _cardFade,
    child: ScaleTransition(
      scale: _cardScale,
      child: SlideTransition(
        position: _cardSlide,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          decoration: BoxDecoration(
            color: _blanco,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.09),
                  blurRadius: 40, offset: const Offset(0, 16)),
              BoxShadow(color: _verde.withOpacity(0.07),
                  blurRadius: 20, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(children: [
            const _CardHeader(),
            Padding(
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: Column(children: [
                  _campo(ctrl: _emailCtrl,
                    label: 'Correo electrónico',
                    icon: Icons.alternate_email_rounded,
                    tipo: TextInputType.emailAddress,
                    accion: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Ingresa tu correo';
                      if (!v.contains('@')) return 'Correo inválido';
                      return null;
                    }),
                  const SizedBox(height: 16),
                  _campo(ctrl: _passCtrl,
                    label: 'Contraseña',
                    icon: Icons.lock_outline_rounded,
                    obscure: !_mostrarPass,
                    accion: TextInputAction.done,
                    onSubmit: (_) => _login(),
                    suffix: GestureDetector(
                      onTap: () => setState(() => _mostrarPass = !_mostrarPass),
                      child: Icon(
                        _mostrarPass
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: _subtexto, size: 20),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Ingresa tu contraseña';
                      if (v.length < 6) return 'Mínimo 6 caracteres';
                      return null;
                    }),
                  const SizedBox(height: 28),
                  _BotonLogin(cargando: _cargando, onPressed: _login),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _verdeLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _verde.withOpacity(0.15)),
                    ),
                    child: Row(children: [
                      Icon(Icons.shield_outlined,
                          color: _verde.withOpacity(0.7), size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(
                        'Acceso exclusivo para personal autorizado',
                        style: TextStyle(fontSize: 12,
                            color: _verde.withOpacity(0.8),
                            fontWeight: FontWeight.w500),
                      )),
                    ]),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    ),
  );

  Widget _campo({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    TextInputType tipo = TextInputType.text,
    TextInputAction accion = TextInputAction.next,
    bool obscure = false,
    Widget? suffix,
    ValueChanged<String>? onSubmit,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: ctrl,
    enabled: !_cargando,
    keyboardType: tipo,
    textInputAction: accion,
    obscureText: obscure,
    onFieldSubmitted: onSubmit,
    validator: validator,
    style: const TextStyle(color: _texto, fontSize: 14,
        fontWeight: FontWeight.w500),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _subtexto, fontSize: 13),
      prefixIcon: Icon(icon, color: _verde.withOpacity(0.6), size: 20),
      suffixIcon: suffix != null
          ? Padding(padding: const EdgeInsets.only(right: 12), child: suffix)
          : null,
      filled: true,
      fillColor: _gris,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _verde, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE53935), width: 2)),
      errorStyle: const TextStyle(color: Color(0xFFE53935), fontSize: 11),
    ),
  );
}

// ── Cabecera ──────────────────────────────────────────────────
class _CardHeader extends StatelessWidget {
  const _CardHeader();
  static const _verde      = Color(0xFF1B6B2F);
  static const _verdeClaro = Color(0xFF27AE60);
  static const _blanco     = Colors.white;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_verde, _verdeClaro],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _blanco.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.admin_panel_settings_rounded,
                color: _blanco, size: 26),
          ),
          const SizedBox(height: 18),
          const Text('Bienvenido',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                color: _blanco, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text('Ingresa tus credenciales para continuar',
            style: TextStyle(fontSize: 13, color: _blanco.withOpacity(0.75))),
        ],
      ),
    );
  }
}

// ── Feature card ──────────────────────────────────────────────
class _FeatureCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final int index;
  const _FeatureCard({required this.icon, required this.label, required this.index});

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late AnimationController _hoverCtrl;
  late Animation<double> _hoverScale;
  late Animation<double> _hoverElevation;

  static const _verde      = Color(0xFF1B6B2F);
  static const _verdeLight = Color(0xFFE8F5E9);
  static const _blanco     = Colors.white;
  static const _texto      = Color(0xFF1A1A2E);
  static const _subtexto   = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _hoverCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 200));
    _hoverScale = Tween<double>(begin: 1.0, end: 1.02)
        .animate(CurvedAnimation(parent: _hoverCtrl, curve: Curves.easeOut));
    _hoverElevation = Tween<double>(begin: 0.04, end: 0.12)
        .animate(CurvedAnimation(parent: _hoverCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _hoverCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) { setState(() => _hovered = true); _hoverCtrl.forward(); },
      onExit:  (_) { setState(() => _hovered = false); _hoverCtrl.reverse(); },
      child: AnimatedBuilder(
        animation: _hoverCtrl,
        builder: (_, child) => Transform.scale(
          scale: _hoverScale.value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: _blanco,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _hovered ? _verde.withOpacity(0.3) : Colors.transparent,
                width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_hoverElevation.value),
                  blurRadius: _hovered ? 20 : 12, offset: const Offset(0, 4)),
                if (_hovered) BoxShadow(
                  color: _verde.withOpacity(0.08),
                  blurRadius: 16, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _hovered ? _verde : _verdeLight,
                  borderRadius: BorderRadius.circular(10)),
                child: Icon(widget.icon,
                    color: _hovered ? _blanco : _verde, size: 18),
              ),
              const SizedBox(width: 14),
              Text(widget.label,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                    color: _hovered ? _verde : _texto)),
              const Spacer(),
              AnimatedOpacity(
                opacity: _hovered ? 1.0 : 0.3,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.arrow_forward_ios_rounded,
                    size: 12, color: _subtexto),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Botón login ───────────────────────────────────────────────
class _BotonLogin extends StatefulWidget {
  final bool cargando;
  final VoidCallback onPressed;
  const _BotonLogin({required this.cargando, required this.onPressed});

  @override
  State<_BotonLogin> createState() => _BotonLoginState();
}

class _BotonLoginState extends State<_BotonLogin>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late AnimationController _hoverCtrl;
  late Animation<double> _hoverScale;

  static const _verde      = Color(0xFF1B6B2F);
  static const _verdeClaro = Color(0xFF27AE60);
  static const _blanco     = Colors.white;

  @override
  void initState() {
    super.initState();
    _hoverCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 150));
    _hoverScale = Tween<double>(begin: 1.0, end: 1.02)
        .animate(CurvedAnimation(parent: _hoverCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _hoverCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) { setState(() => _hovered = true); _hoverCtrl.forward(); },
      onExit:  (_) { setState(() => _hovered = false); _hoverCtrl.reverse(); },
      child: AnimatedBuilder(
        animation: _hoverCtrl,
        builder: (_, __) => Transform.scale(
          scale: _hoverScale.value,
          child: SizedBox(
            width: double.infinity, height: 54,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: widget.cargando ? null : const LinearGradient(
                  colors: [_verde, _verdeClaro],
                  begin: Alignment.centerLeft, end: Alignment.centerRight),
                borderRadius: BorderRadius.circular(14),
                boxShadow: widget.cargando ? [] : [
                  BoxShadow(
                    color: _verde.withOpacity(_hovered ? 0.5 : 0.3),
                    blurRadius: _hovered ? 24 : 16,
                    offset: const Offset(0, 6)),
                ],
              ),
              child: ElevatedButton(
                onPressed: widget.cargando ? null : widget.onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  disabledBackgroundColor: Colors.grey[200],
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: widget.cargando
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(
                            color: _verde, strokeWidth: 2.5))
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.login_rounded, color: _blanco, size: 20),
                          SizedBox(width: 10),
                          Text('Ingresar al Panel',
                            style: TextStyle(fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: _blanco, letterSpacing: 0.3)),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}