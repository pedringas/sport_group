import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/sg_widgets.dart';
import '../../providers/auth_provider.dart';
import '../../core/config/app_config.dart';

// â”€â”€ Breakpoint â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/// Shows sidebar + topbar on desktop (â‰¥ 900 px), passes through on mobile.
class ResponsiveShell extends ConsumerWidget {
  final Widget child;
  const ResponsiveShell({super.key, required this.child});

  static const double kBreakpoint = 900;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (MediaQuery.sizeOf(context).width < kBreakpoint) return child;
    return _DesktopShell(child: child);
  }
}

// â”€â”€ Desktop shell â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _DesktopShell extends ConsumerWidget {
  final Widget child;
  const _DesktopShell({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routerState = GoRouterState.of(context);
    final location = routerState.matchedLocation;
    final queryParams = routerState.uri.queryParameters;
    final user = ref.watch(currentUserProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DeskSidebar(location: location, queryParams: queryParams, userName: user?.nombreCompleto ?? ''),
          Container(width: 1, color: AppTheme.border),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DeskTopBar(location: location, queryParams: queryParams, ref: ref),
                Expanded(
                  child: Container(
                    color: AppTheme.background,
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€ Sidebar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _DeskSidebar extends StatelessWidget {
  final String location;
  final Map<String, String> queryParams;
  final String userName;

  const _DeskSidebar({
    required this.location,
    required this.queryParams,
    required this.userName,
  });

  // Debe mantenerse en el mismo orden que _BottomNav._items en home_shell.dart.
  static const _navItems = [
    (id: 'inicio', icon: Icons.home_rounded, label: 'Inicio', path: '/home'),
    (id: 'agenda', icon: Icons.calendar_month_rounded, label: 'Agenda', path: '/home?tab=1'),
    (id: 'caja', icon: Icons.payments_outlined, label: 'Cuotas', path: '/home?tab=2'),
    (id: 'miembros', icon: Icons.groups_rounded, label: 'Miembros', path: '/home?tab=3'),
    (id: 'perfil', icon: Icons.person_rounded, label: 'Mi perfil', path: '/home?tab=4'),
  ];

  bool _isActive(String navId) {
    final onHome = location == '/home';
    final tab = queryParams['tab'];
    switch (navId) {
      case 'inicio':
        return onHome && (tab == null || tab == '0');
      case 'agenda':
        return onHome && tab == '1';
      case 'caja':
        // Cuotas y Gastos cuelgan de Caja.
        return (onHome && tab == '2') ||
            location.startsWith('/cuota') ||
            location.startsWith('/gastos') ||
            location == '/suscripciones';
      case 'miembros':
        return (onHome && tab == '3') || location == '/miembros';
      case 'perfil':
        return (onHome && tab == '4') || location.startsWith('/profile');
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: AppTheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // â”€â”€ Brand
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Row(
                children: [
                  Image.asset(
                    'assets/logo/tacheros.png',
                    height: 52,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Tacheros',
                    style: GoogleFonts.bricolageGrotesque(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: -0.3,
                      color: AppTheme.text,
                    ),
                  ),
                ],
              ),
            ),

            // â”€â”€ Primary nav
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: _navItems.map((n) {
                  final active = _isActive(n.id);
                  return _SideNavRow(
                    icon: n.icon,
                    label: n.label,
                    selected: active,
                    onTap: () => context.go(n.path),
                  );
                }).toList(),
              ),
            ),

            const Spacer(),

            // â”€â”€ User card
            Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  SGAvatar(name: userName.isEmpty ? '?' : userName, size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          userName.isEmpty ? 'Usuario' : userName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/profile'),
                    child: const Icon(
                      Icons.settings_rounded,
                      size: 18,
                      color: AppTheme.textMuted,
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
}

class _SideNavRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SideNavRow({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(10));
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            color: selected ? AppTheme.primarySoft : Colors.transparent,
            borderRadius: radius,
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Container(
              margin: const EdgeInsets.only(bottom: 2),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: selected ? AppTheme.primaryInk : AppTheme.text,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color:
                            selected ? AppTheme.primaryInk : AppTheme.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// â”€â”€ Top bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _DeskTopBar extends ConsumerWidget {
  final String location;
  final Map<String, String> queryParams;
  final WidgetRef ref;
  const _DeskTopBar({required this.location, required this.queryParams, required this.ref});

  static const _titles = <String, String>{
    '/profile': 'Mi perfil',
    '/profile/edit': 'Editar perfil',
    '/busqueda': 'Buscar',
    '/notificaciones': 'Notificaciones',
    '/faq': 'Ayuda y soporte',
    '/ajustes': 'Ajustes del grupo',
    '/miembros': 'Miembros',
    '/novedades': 'Novedades',
    '/evento/crear': 'Nuevo evento',
    '/cuotas': 'Cuotas',
    '/cuotas/crear': 'Nueva cuota',
    '/suscripciones': 'Cobranza',
    '/gastos': 'Gastos',
    '/gastos/crear': 'Nuevo gasto',
    '/admin': 'Panel de administración',
    '/tareas': 'Tareas',
    '/tareas/crear': 'Nueva tarea',
    '/recursos': 'Recursos',
    '/campanas': 'Campañas',
    '/moderador': 'Panel Moderador',
    '/tesorero': 'Panel Tesorero',
    '/delegado': 'Panel Delegado',
  };

  String _title() {
    if (location == '/home') {
      return switch (queryParams['tab']) {
        '1' => 'Agenda',
        '2' => 'Mis cuotas',
        '3' => 'Miembros',
        '4' => 'Mi perfil',
        _ => 'Inicio',
      };
    }
    final exact = _titles[location];
    if (exact != null) return exact;

    // Rutas con parámetros.
    if (location.endsWith('/comentarios')) return 'Comentarios';
    if (location.endsWith('/pay/manual')) return 'Subir comprobante';
    if (location.endsWith('/edit')) return 'Editar cuota';
    if (location.startsWith('/cuota/')) return 'Detalle de cuota';
    if (location.startsWith('/gastos/g/')) return 'Detalle de gasto';
    if (location.startsWith('/recurso/')) return 'Archivo';
    if (location.startsWith('/campana/')) return 'Campaña';

    return kGrupoNombre;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          // â”€â”€ Title
          Expanded(
            child: Text(
              _title(),
              style: GoogleFonts.bricolageGrotesque(
                fontWeight: FontWeight.w700,
                fontSize: 22,
                letterSpacing: -0.4,
                color: AppTheme.text,
              ),
            ),
          ),

          // â”€â”€ Search pill
          GestureDetector(
            onTap: () => context.push('/busqueda'),
            child: Container(
              height: 38,
              width: 260,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 16, color: AppTheme.textMuted),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Buscar novedades, eventos o personas',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: const Text(
                      'Ctrl K',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textMuted,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 10),

          // â”€â”€ Notifications icon
          _TopBarIcon(
            icon: Icons.notifications_rounded,
            tooltip: 'Notificaciones',
            onTap: () => context.push('/notificaciones'),
          ),
          const SizedBox(width: 6),
          _TopBarIcon(
            icon: Icons.help_outline_rounded,
            tooltip: 'Ayuda y soporte',
            onTap: () => context.push('/faq'),
          ),
        ],
      ),
    );
  }
}

class _TopBarIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _TopBarIcon({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: AppTheme.text),
        ),
      ),
    );
  }
}
