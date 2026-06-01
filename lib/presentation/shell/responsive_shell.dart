import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/sg_widgets.dart';
import '../../providers/auth_provider.dart';
import '../../providers/grupo_provider.dart';
import '../../data/models/grupo_model.dart';

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
    final location = GoRouterState.of(context).matchedLocation;
    final grupos = ref.watch(userGruposProvider).valueOrNull ?? [];
    final user = ref.watch(currentUserProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DeskSidebar(location: location, grupos: grupos, userName: user?.nombreCompleto ?? ''),
          Container(width: 1, color: AppTheme.border),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DeskTopBar(location: location, ref: ref),
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
  final List<GrupoModel> grupos;
  final String userName;

  const _DeskSidebar({
    required this.location,
    required this.grupos,
    required this.userName,
  });

  static const _navItems = [
    (id: 'inicio', icon: Icons.home_rounded, label: 'Inicio', path: '/home'),
    (id: 'search', icon: Icons.search_rounded, label: 'Buscar grupos', path: '/search'),
    (id: 'agenda', icon: Icons.calendar_month_rounded, label: 'Agenda', path: '/home?tab=2'),
    (id: 'notifs', icon: Icons.notifications_rounded, label: 'Novedades', path: '/notificaciones'),
  ];

  bool _isActive(String navId) {
    if (navId == 'inicio') return location == '/home' && !location.contains('tab=');
    if (navId == 'search') return location.startsWith('/search');
    if (navId == 'agenda') return location.contains('tab=2');
    if (navId == 'notifs') return location.startsWith('/notificaciones');
    return false;
  }

  bool _isGroupActive(String grupoId) => location.contains('/group/$grupoId');

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
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'SG',
                      style: GoogleFonts.bricolageGrotesque(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'SportGroups',
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

            const SizedBox(height: 16),

            // â”€â”€ Groups header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 16, 6),
              child: Text(
                'MIS GRUPOS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppTheme.textMuted,
                ),
              ),
            ),

            // â”€â”€ Groups list
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    ...grupos.map((g) => _SideGroupRow(
                      grupo: g,
                      selected: _isGroupActive(g.id),
                      onTap: () => context.go('/group/${g.id}'),
                    )),
                    _SideNavRow(
                      icon: Icons.add_circle_outline_rounded,
                      label: 'Crear o sumarte',
                      selected: false,
                      muted: true,
                      onTap: () => context.push('/create-group'),
                    ),
                  ],
                ),
              ),
            ),

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
  final bool muted;
  final VoidCallback onTap;
  const _SideNavRow({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected
                  ? AppTheme.primaryInk
                  : (muted ? AppTheme.textMuted : AppTheme.text),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? AppTheme.primaryInk
                      : (muted ? AppTheme.textMuted : AppTheme.text),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideGroupRow extends StatelessWidget {
  final GrupoModel grupo;
  final bool selected;
  final VoidCallback onTap;
  const _SideGroupRow({
    required this.grupo,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppTheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: selected
              ? Border.all(color: AppTheme.border)
              : Border.all(color: Colors.transparent),
        ),
        child: Row(
          children: [
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(7),
              ),
              alignment: Alignment.center,
              child: Text(
                grupo.nombre.characters.first.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                grupo.nombre,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: AppTheme.text,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Top bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _DeskTopBar extends ConsumerWidget {
  final String location;
  final WidgetRef ref;
  const _DeskTopBar({required this.location, required this.ref});

  String _title(WidgetRef r) {
    if (location == '/home') return 'Inicio';
    if (location == '/profile') return 'Mi perfil';
    if (location == '/search') return 'Buscar grupos';
    if (location == '/create-group') return 'Crear grupo';
    if (location == '/faq') return 'Ayuda y soporte';
    if (location.contains('/noticias')) return 'Novedades';
    if (location.contains('/cuotas/crear')) return 'Nueva suscripción';
    if (location.contains('/cuotas')) return 'Suscripciones';
    if (location.contains('/gastos/crear')) return 'Nuevo gasto';
    if (location.contains('/gastos')) return 'Gastos';
    if (location.contains('/tareas/crear')) return 'Nueva tarea';
    if (location.contains('/tareas')) return 'Tareas';
    if (location.contains('/recursos')) return 'Recursos';
    if (location.contains('/campanas')) return 'Campañas';
    if (location.contains('/evento/crear')) return 'Nuevo evento';
    if (location.contains('/settings')) return 'Configuración';
    if (location.contains('/admin')) return 'Panel Admin';
    if (location.contains('/delegado')) return 'Panel Delegado';
    if (location.contains('/tesorero')) return 'Panel Tesorero';
    if (location.contains('/moderador')) return 'Panel Moderador';
    if (location.contains('/comentarios')) return 'Comentarios';
    if (location.contains('/group/')) {
      // Extract grupoId and show group name
      final match = RegExp(r'/group/([^/]+)').firstMatch(location);
      if (match != null) {
        final nombre = r.watch(grupoProvider(match.group(1)!)).valueOrNull?.nombre;
        if (nombre != null) return nombre;
      }
      return 'Grupo';
    }
    return 'SportGroups';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          // â”€â”€ Title
          Expanded(
            child: Text(
              _title(ref),
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
                  Expanded(
                    child: Text(
                      'Buscar grupos, miembros, archivos...',
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
                    child: Text(
                      'âŒ˜K',
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
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Notificaciones ”” próximamente'))),
          ),
          const SizedBox(width: 6),
          _TopBarIcon(
            icon: Icons.help_outline_rounded,
            onTap: () => context.push('/faq'),
          ),
        ],
      ),
    );
  }
}

class _TopBarIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _TopBarIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
    );
  }
}
