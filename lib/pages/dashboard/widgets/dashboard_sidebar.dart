// lib/pages/dashboard/widgets/dashboard_sidebar.dart

import 'package:flutter/material.dart';

const Color _green900 = Color(0xFF1B4332);
const Color _green300 = Color(0xFF74C69D);
const Color _accent   = Color(0xFF52B788);

class DashboardSidebar extends StatelessWidget {
  final int selectedIndex;
  final String adminNombre;
  final String adminRol;
  final void Function(int index) onItemSelected;
  final VoidCallback onLogout;

  const DashboardSidebar({
    super.key,
    required this.selectedIndex,
    required this.adminNombre,
    required this.adminRol,
    required this.onItemSelected,
    required this.onLogout,
  });

  static const _itemsBase = [
    _NavItem(Icons.dashboard_rounded,        'Dashboard'),
    _NavItem(Icons.storefront_rounded,       'Productos'),
    _NavItem(Icons.receipt_long_rounded,     'Pedidos'),
    _NavItem(Icons.assignment_return_rounded,'Devoluciones'),
    _NavItem(Icons.bar_chart_rounded,        'Reportes'),
  ];

  static const _itemBackup     = _NavItem(Icons.backup_rounded, 'Backup');
  static const _itemSuperAdmin = _NavItem(Icons.shield_rounded, 'Super Admin');

  @override
  Widget build(BuildContext context) {
    final esSuperAdmin = adminRol == 'super_admin';

    final items = [
      ..._itemsBase,
      if (esSuperAdmin) _itemBackup,
      if (esSuperAdmin) _itemSuperAdmin,
    ];

    return Container(
      width: 90,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_green900, Color(0xFF2D6A4F)],
        ),
        boxShadow: [
          BoxShadow(
            color: _green900.withOpacity(0.45),
            blurRadius: 24,
            offset: const Offset(6, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 30),
          // Avatar sin animación
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [_green300, _accent]),
              boxShadow: [
                BoxShadow(
                  color: _green300.withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: Text(
                adminNombre.isNotEmpty ? adminNombre[0].toUpperCase() : 'A',
                style: const TextStyle(
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Badge rol
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: esSuperAdmin
                  ? Colors.amber.withOpacity(0.18)
                  : Colors.greenAccent.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: esSuperAdmin
                    ? Colors.amber.withOpacity(0.5)
                    : Colors.greenAccent.withOpacity(0.45),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  esSuperAdmin ? Icons.shield_rounded : Icons.circle,
                  size: 6,
                  color: esSuperAdmin ? Colors.amber : Colors.greenAccent,
                ),
                const SizedBox(width: 4),
                Text(
                  esSuperAdmin ? 'Super Admin' : 'Activo',
                  style: TextStyle(
                    fontSize: 9,
                    color: esSuperAdmin ? Colors.amber : Colors.greenAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Divisor
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent,
                _green300.withOpacity(0.35),
                Colors.transparent,
              ]),
            ),
          ),
          const SizedBox(height: 18),
          // Items de navegación — scrollable para que no haga overflow
          // cuando hay muchos items (ej: super admin con Backup + Super Admin)
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: items.asMap().entries.map((e) {
                  final isSuperAdminItem =
                      esSuperAdmin && e.key == items.length - 1;
                  return _SidebarNavItem(
                    icon: e.value.icon,
                    label: e.value.label,
                    selected: selectedIndex == e.key,
                    accentColor: isSuperAdminItem ? Colors.amber : _green300,
                    onTap: () => onItemSelected(e.key),
                  );
                }).toList(),
              ),
            ),
          ),
          // Botón salir
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _SidebarLogout(onTap: onLogout),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

class _SidebarNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.88)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) {
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: ScaleTransition(
          scale: _scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: widget.selected
                ? Colors.white.withOpacity(0.14)
                : Colors.transparent,
          ),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.selected
                      ? widget.accentColor.withOpacity(0.22)
                      : Colors.transparent,
                ),
                child: Icon(
                  widget.icon,
                  color: widget.selected
                      ? widget.accentColor
                      : Colors.white.withOpacity(0.5),
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 9,
                  color: widget.selected
                      ? widget.accentColor
                      : Colors.white.withOpacity(0.5),
                  fontWeight: widget.selected
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
              if (widget.selected) ...[
                const SizedBox(height: 5),
                Container(
                  width: 22,
                  height: 3,
                  decoration: BoxDecoration(
                    color: widget.accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarLogout extends StatefulWidget {
  final VoidCallback onTap;
  const _SidebarLogout({required this.onTap});

  @override
  State<_SidebarLogout> createState() => _SidebarLogoutState();
}

class _SidebarLogoutState extends State<_SidebarLogout> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color:
                  _hovered ? Colors.red.withOpacity(0.2) : Colors.transparent,
            ),
            child: Column(
            children: [
              Icon(
                Icons.logout_rounded,
                color: _hovered
                    ? Colors.red[300]
                    : Colors.white.withOpacity(0.45),
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                'Salir',
                style: TextStyle(
                  fontSize: 9,
                  color: _hovered
                      ? Colors.red[300]
                      : Colors.white.withOpacity(0.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}