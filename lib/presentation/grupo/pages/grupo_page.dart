import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/nav_ext.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/grupo_model.dart';
import '../../../providers/grupo_provider.dart';
import '../../../providers/noticia_provider.dart';
import '../../../providers/cuota_provider.dart';

/// Group hub with design-handoff curtain transition.
/// Entry: slides up from bottom (handled in router).
/// Cover: collapses 150→104px on non-Resumen tabs with a gradient + watermark.
/// Escudo: springs in (scale 0.4→1 + fade) 420ms after 120ms delay on mount.
class GrupoPage extends ConsumerStatefulWidget {
  final String grupoId;
  const GrupoPage({super.key, required this.grupoId});

  @override
  ConsumerState<GrupoPage> createState() => _GrupoPageState();
}

class _GrupoPageState extends ConsumerState<GrupoPage>
    with SingleTickerProviderStateMixin {
  // 0=Resumen (in-page), 1=Novedades, 2=Miembros, 3=Agenda, 4=Más
  int _activeTab = 0;

  late final AnimationController _escudoCtrl;
  late final Animation<double> _escudoScale;
  late final Animation<double> _escudoOpacity;

  static const _coverExpanded = 150.0;
  static const _coverCollapsed = 104.0;
  static const _springCurve = Cubic(0.34, 1.56, 0.5, 1);
  static const _baseCurve = Cubic(0.2, 0.85, 0.25, 1);

  @override
  void initState() {
    super.initState();
    _escudoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _escudoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _escudoCtrl, curve: _springCurve),
    );
    _escudoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _escudoCtrl,
          curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) _escudoCtrl.forward();
    });
  }

  @override
  void dispose() {
    _escudoCtrl.dispose();
    super.dispose();
  }

  void _onTabTap(int index, BuildContext context, Color gc) {
    if (index == 0) {
      setState(() => _activeTab = 0);
      return;
    }
    if (index == 4) {
      _showMasSheet(context, gc);
      return;
    }
    setState(() => _activeTab = index);
    const routes = ['', '/novedades', '/miembros', '/agenda', ''];
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) context.push('${routes[index]}');
    });
  }

  @override
  Widget build(BuildContext context) {
    final grupoAsync = ref.watch(grupoProvider(widget.grupoId));
    final miembroAsync = ref.watch(miembroActualProvider(widget.grupoId));
    final grupo = grupoAsync.valueOrNull;
    final gc = ref.watch(grupoColorProvider(widget.grupoId));
    final rol = miembroAsync.valueOrNull?.rol;
    final isAdmin = rol?.esAdmin ?? false;
    final esModerador = rol == RolMiembro.moderador;
    final esTesorero = rol == RolMiembro.tesorero;
    final esDelegado = rol == RolMiembro.delegado;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: Column(
        children: [
          // ── Animated collapsible cover
          AnimatedContainer(
            duration: const Duration(milliseconds: 340),
            curve: _baseCurve,
            height: _activeTab == 0 ? _coverExpanded : _coverCollapsed,
            child: _GrupoCover(
              grupo: grupo,
              gc: gc,
              escudoScale: _escudoScale,
              escudoOpacity: _escudoOpacity,
              isCollapsed: _activeTab != 0,
              onBack: () =>
                  context.popOr('/home'),
              onShare: () => _shareLink(context),
              onMenu: (v) => _onMenuAction(context, ref, v),
              isAdmin: isAdmin,
              esModerador: esModerador,
              esTesorero: esTesorero,
              esDelegado: esDelegado,
            ),
          ),

          // ── Dashboard body (Resumen tab only — others push routes)
          Expanded(
            child: grupoAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => const SGErrorState(message: 'Error al cargar el grupo'),
              data: (grupo) {
                if (grupo == null) {
                  return const Center(child: Text('Grupo no encontrado'));
                }
                final isDesktop = MediaQuery.sizeOf(context).width >= AppTheme.kResponsiveBreakpoint;
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 800 : double.infinity,
                    ),
                    child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                  children: [
                    // ── Desktop nav chips (tabs hidden on desktop)
                    if (isDesktop)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Wrap(
                          spacing: 8,
                          children: [
                            _DesktopNavChip(
                              icon: Icons.newspaper_outlined,
                              label: 'Novedades',
                              onTap: () => context.push('/novedades'),
                            ),
                            _DesktopNavChip(
                              icon: Icons.group_outlined,
                              label: 'Miembros',
                              onTap: () => context.push('/miembros'),
                            ),
                            _DesktopNavChip(
                              icon: Icons.calendar_month_outlined,
                              label: 'Agenda',
                              onTap: () => context.push('/agenda'),
                            ),
                          ],
                        ),
                      ),
                    if (rol != null && rol != RolMiembro.miembro)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(children: [
                          SGChip(
                            icon: _roleIcon(rol),
                            label: 'Sos ${_roleLabel(rol)}',
                            tone: _roleTone(rol),
                            filled: true,
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () =>
                                _onMenuAction(context, ref, _roleAction(rol)),
                            child: const Text('Panel del rol →',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ]),
                      ),
                    _ProximoEventoCard(grupoId: widget.grupoId),
                    const SizedBox(height: 16),
                    _BentoGrid(grupoId: widget.grupoId, gc: gc),
                    const SizedBox(height: 24),
                    _UltimasNoticias(grupoId: widget.grupoId),
                  ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton:
          grupo == null ? null : _smartFab(context, rol, gc),
      bottomNavigationBar:
          grupo == null ? null : _buildTabBar(context, gc),
    );
  }

  Widget _buildTabBar(BuildContext context, Color gc) {
    // Hide bottom nav on desktop — sidebar already provides navigation
    if (MediaQuery.sizeOf(context).width >= AppTheme.kResponsiveBreakpoint) return const SizedBox.shrink();
    final tabs = [
      (label: 'Resumen', icon: Icons.home_outlined, filled: Icons.home_rounded),
      (label: 'Novedades', icon: Icons.newspaper_outlined, filled: Icons.newspaper_rounded),
      (label: 'Miembros', icon: Icons.group_outlined, filled: Icons.group_rounded),
      (label: 'Agenda', icon: Icons.calendar_month_outlined, filled: Icons.calendar_month_rounded),
      (label: 'Más', icon: Icons.more_horiz_rounded, filled: Icons.more_horiz_rounded),
    ];

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(tabs.length, (i) {
            final t = tabs[i];
            final active = _activeTab == i;
            return GestureDetector(
              onTap: () => _onTabTap(i, context, gc),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: active
                            ? AppTheme.primarySoft
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Icon(
                        active ? t.filled : t.icon,
                        size: 22,
                        color: active ? gc : AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? gc : AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget? _smartFab(BuildContext context, RolMiembro? rol, Color gc) {
    if (rol == RolMiembro.administrador) {
      return FloatingActionButton.extended(
        onPressed: () => _showAdminFabSheet(context, gc),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Acciones'),
      );
    }
    if (rol == RolMiembro.tesorero) {
      return FloatingActionButton.extended(
        onPressed: () =>
            context.push('/cuotas/crear'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Cobrar cuota'),
      );
    }
    if (rol == RolMiembro.delegado) {
      return FloatingActionButton.extended(
        onPressed: () =>
            context.push('/evento/crear'),
        icon: const Icon(Icons.event_rounded),
        label: const Text('Crear evento'),
      );
    }
    return FloatingActionButton.extended(
      onPressed: () => context.push('/novedades'),
      icon: const Icon(Icons.newspaper_rounded),
      label: const Text('Ver noticias'),
    );
  }

  void _showAdminFabSheet(BuildContext context, Color gc) {
    final id = widget.grupoId;
    final actions = [
      (Icons.event_rounded, gc.withValues(alpha: 0.12), gc,
          'Crear evento', '/evento/crear'),
      (Icons.payments_outlined, AppTheme.dangerSoft,
          AppTheme.dangerInk, 'Emitir suscripción',
          '/cuotas/crear'),
      (Icons.newspaper_outlined, AppTheme.goodSoft,
          AppTheme.goodInk, 'Noticias', '/novedades'),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surf(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('¿Qué querés crear?',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              const SizedBox(height: 12),
              ...actions.map((a) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                          color: a.$2,
                          borderRadius: BorderRadius.circular(14)),
                      alignment: Alignment.center,
                      child: Icon(a.$1, size: 22, color: a.$3),
                    ),
                    title: Text(a.$4,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppTheme.textMuted),
                    onTap: () {
                      Navigator.pop(context);
                      context.push(a.$5);
                    },
                  )),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  void _showMasSheet(BuildContext context, Color gc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surf(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) =>
          _GrupoMoreSheet(grupoId: widget.grupoId, gc: gc),
    );
  }

  void _shareLink(BuildContext context) {
    Clipboard.setData(ClipboardData(
        text: 'https://sports-groups-app.web.app/join/${widget.grupoId}'));
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Link copiado!')));
  }

  void _onMenuAction(BuildContext context, WidgetRef ref, String action) {
    final id = widget.grupoId;
    switch (action) {
      case 'admin': context.push('/admin'); break;
      case 'settings': context.push('/ajustes'); break;
      case 'moderador': context.push('/moderador'); break;
      case 'tesorero': context.push('/tesorero'); break;
      case 'delegado': context.push('/delegado'); break;
      case 'leave': _confirmLeave(context, ref); break;
      case 'delete': _confirmDelete(context, ref); break;
    }
  }

  void _confirmLeave(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Abandonar grupo'),
        content: const Text(
            'Vas a perder acceso al grupo, sus noticias y eventos. ¿Seguir?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.danger),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref
                    .read(abandonarGrupoProvider.notifier)
                    .abandonar(widget.grupoId);
                if (context.mounted) context.go('/home');
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Sí, abandonar'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('⚠️ Eliminar grupo'),
        content: const Text(
            'IRREVERSIBLE. El grupo y todos sus contenidos se borran. ¿Seguir?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.danger),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref
                    .read(eliminarGrupoProvider.notifier)
                    .eliminar(widget.grupoId);
                if (context.mounted) context.go('/home');
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Eliminar definitivamente'),
          ),
        ],
      ),
    );
  }

  // ── Role helpers ─────────────────────────────────────────────────────────
  String _roleLabel(RolMiembro r) => switch (r) {
        RolMiembro.administrador => 'Admin',
        RolMiembro.moderador => 'Moderador',
        RolMiembro.tesorero => 'Tesorero',
        RolMiembro.delegado => 'Delegado',
        RolMiembro.miembro => 'Miembro',
      };
  IconData _roleIcon(RolMiembro r) => switch (r) {
        RolMiembro.administrador => Icons.shield_outlined,
        RolMiembro.moderador => Icons.shield_outlined,
        RolMiembro.tesorero => Icons.account_balance_outlined,
        RolMiembro.delegado => Icons.assignment_outlined,
        RolMiembro.miembro => Icons.person_outline_rounded,
      };
  SGChipTone _roleTone(RolMiembro r) => switch (r) {
        RolMiembro.administrador => SGChipTone.primary,
        RolMiembro.moderador => SGChipTone.neutral,
        RolMiembro.tesorero => SGChipTone.good,
        RolMiembro.delegado => SGChipTone.accent,
        RolMiembro.miembro => SGChipTone.neutral,
      };
  String _roleAction(RolMiembro r) => switch (r) {
        RolMiembro.administrador => 'admin',
        RolMiembro.moderador => 'moderador',
        RolMiembro.tesorero => 'tesorero',
        RolMiembro.delegado => 'delegado',
        RolMiembro.miembro => '',
      };
}

// ── Collapsible group cover ───────────────────────────────────────────────────
class _GrupoCover extends StatelessWidget {
  final GrupoModel? grupo;
  final Color gc;
  final Animation<double> escudoScale;
  final Animation<double> escudoOpacity;
  final bool isCollapsed;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final void Function(String) onMenu;
  final bool isAdmin, esModerador, esTesorero, esDelegado;

  const _GrupoCover({
    required this.grupo,
    required this.gc,
    required this.escudoScale,
    required this.escudoOpacity,
    required this.isCollapsed,
    required this.onBack,
    required this.onShare,
    required this.onMenu,
    required this.isAdmin,
    required this.esModerador,
    required this.esTesorero,
    required this.esDelegado,
  });

  Color get _coverTop => gc;
  Color get _coverBot => Color.lerp(gc, const Color(0xFF100808), 0.48)!;

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;
    final escudoSize = isCollapsed ? 42.0 : 60.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Gradient background
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_coverTop, _coverBot],
            ),
          ),
        ),

        // Diagonal stripe overlay
        CustomPaint(painter: _StripePainter()),

        // Sport watermark
        const Positioned(
          right: -16, bottom: -16,
          child: Opacity(
            opacity: 0.13,
            child: Icon(Icons.sports_soccer_rounded,
                size: 200, color: Colors.white),
          ),
        ),

        // Back button
        Positioned(
          top: safeTop + 8, left: 12,
          child: GestureDetector(
            onTap: onBack,
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18, color: Colors.white),
            ),
          ),
        ),

        // Share + menu
        Positioned(
          top: safeTop + 8, right: 8,
          child: Row(
            children: [
              GestureDetector(
                onTap: onShare,
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.ios_share,
                      size: 18, color: Colors.white),
                ),
              ),
              const SizedBox(width: 4),
              if (grupo != null)
                _CoverMenu(
                  isAdmin: isAdmin,
                  esModerador: esModerador,
                  esTesorero: esTesorero,
                  esDelegado: esDelegado,
                  onAction: onMenu,
                ),
            ],
          ),
        ),

        // Escudo + title (expanded)
        if (grupo != null)
          Positioned(
            left: 16, right: 56, bottom: 12,
            child: Row(
              children: [
                FadeTransition(
                  opacity: escudoOpacity,
                  child: ScaleTransition(
                    scale: escudoScale,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 340),
                      width: escudoSize, height: escudoSize,
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(escudoSize * 0.25),
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x660A0000),
                            blurRadius: 20, offset: Offset(0, 8),
                          )
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(escudoSize * 0.25 - 3),
                        child: grupo!.logoUrl?.isNotEmpty == true
                            ? CachedNetworkImage(imageUrl: grupo!.logoUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) =>
                                    _fallback(escudoSize))
                            : _fallback(escudoSize),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AnimatedOpacity(
                    opacity: isCollapsed ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          grupo!.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.bricolageGrotesque(
                            fontWeight: FontWeight.w800, fontSize: 20,
                            letterSpacing: -0.4, color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${grupo!.miembrosCount} miembros · '
                          '${grupo!.tipo == TipoGrupo.publico ? "Público" : "Privado"}',
                          style: const TextStyle(
                            fontSize: 12, color: Color(0xE6FFFFFF),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Compact title (collapsed only)
        if (grupo != null && isCollapsed)
          Positioned(
            left: 62, right: 56, bottom: 14,
            child: Text(
              grupo!.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.bricolageGrotesque(
                fontWeight: FontWeight.w700, fontSize: 16,
                letterSpacing: -0.2, color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  Widget _fallback(double size) => Container(
        color: gc.withValues(alpha: 0.3),
        child: Icon(Icons.groups_rounded,
            size: size * 0.55, color: Colors.white),
      );
}

// ── Diagonal stripe painter ───────────────────────────────────────────────────
class _StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 2;
    for (double i = -size.height; i < size.width + size.height; i += 22) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), paint);
    }
  }
  @override
  bool shouldRepaint(_StripePainter _) => false;
}

// ── Cover menu ────────────────────────────────────────────────────────────────
class _CoverMenu extends StatelessWidget {
  final bool isAdmin, esModerador, esTesorero, esDelegado;
  final void Function(String) onAction;
  const _CoverMenu({
    required this.isAdmin, required this.esModerador,
    required this.esTesorero, required this.esDelegado,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onAction,
      icon: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.more_horiz_rounded,
            size: 20, color: Colors.white),
      ),
      itemBuilder: (_) => [
        if (isAdmin)
          const PopupMenuItem(value: 'admin',
            child: ListTile(dense: true, contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.admin_panel_settings_outlined),
              title: Text('Panel Admin'))),
        // Paneles Moderador / Tesorero / Delegado en pausa (roles ocultos).
        if (isAdmin) ...[
          const PopupMenuItem(value: 'settings',
            child: ListTile(dense: true, contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.settings_outlined),
              title: Text('Configuración'))),
          const PopupMenuDivider(),
          const PopupMenuItem(value: 'delete',
            child: ListTile(dense: true, contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_forever, color: AppTheme.danger),
              title: Text('Eliminar grupo',
                  style: TextStyle(color: AppTheme.danger)))),
        ] else
          const PopupMenuItem(value: 'leave',
            child: ListTile(dense: true, contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.exit_to_app, color: AppTheme.danger),
              title: Text('Abandonar grupo',
                  style: TextStyle(color: AppTheme.danger)))),
      ],
    );
  }
}

// ── Redesigned More Sheet ─────────────────────────────────────────────────────
class _GrupoMoreSheet extends StatelessWidget {
  final String grupoId;
  final Color gc;
  const _GrupoMoreSheet({required this.grupoId, required this.gc});

  @override
  Widget build(BuildContext context) {
    final sections = [
      (
        title: 'GESTIÓN',
        items: [
          (Icons.account_balance_wallet_outlined, 'Caja',
              'Movimientos del grupo', '/cuotas'),
          (Icons.receipt_long_outlined, 'Gastos',
              'Registro de gastos', '/gastos'),
          (Icons.payments_outlined, 'Mi cuota',
              'Estado de tus pagos', '/cuotas'),
        ],
      ),
      (
        title: 'DEL GRUPO',
        items: [
          (Icons.bar_chart_rounded, 'Estadísticas',
              'Actividad del grupo', '/admin'),
          (Icons.person_add_outlined, 'Invitar',
              'Compartir link de acceso', ''),
        ],
      ),
      (
        title: 'AJUSTES',
        items: [
          (Icons.notifications_outlined, 'Notificaciones',
              'Push y alertas del grupo', ''),
          (Icons.settings_outlined, 'Ajustes del grupo',
              'Configuración y privacidad', '/ajustes'),
        ],
      ),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 38, height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text('Opciones del grupo',
                  style: GoogleFonts.bricolageGrotesque(
                    fontWeight: FontWeight.w700, fontSize: 18,
                    color: AppTheme.text, letterSpacing: -0.3,
                  )),
            ),
            ...sections.map((section) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
                  child: SGEyebrow(section.title),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    children: List.generate(section.items.length, (i) {
                      final item = section.items[i];
                      return Column(children: [
                        if (i > 0)
                          const Divider(
                              height: 1, indent: 60,
                              color: AppTheme.border),
                        ListTile(
                          dense: true,
                          leading: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: gc.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(item.$1, size: 18, color: gc),
                          ),
                          title: Text(item.$2,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                          subtitle: Text(item.$3,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textMuted)),
                          trailing: const Icon(
                              Icons.chevron_right_rounded,
                              size: 16, color: AppTheme.textMuted),
                          onTap: () {
                            Navigator.pop(context);
                            if (item.$4.isNotEmpty) {
                              context.push('${item.$4}');
                            }
                          },
                        ),
                      ]);
                    }),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            )),
            // Danger zone
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: ListTile(
                leading: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.dangerSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.exit_to_app,
                      size: 18, color: AppTheme.danger),
                ),
                title: const Text('Salir del grupo',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14,
                        color: AppTheme.danger)),
                subtitle: const Text('Perderás acceso al grupo',
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.textMuted)),
                onTap: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final GrupoModel grupo;
  const _GroupHeader({required this.grupo});

  @override
  Widget build(BuildContext context) {
    final color = grupo.primaryColor;
    final hasPortada = grupo.portadaUrl?.isNotEmpty == true;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 130,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background: portada image or color gradient
            if (hasPortada)
              CachedNetworkImage(
                imageUrl: grupo.portadaUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _buildGradient(color),
              )
            else
              _buildGradient(color),

            // Subtle dark vignette at the bottom
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.38),
                    ],
                  ),
                ),
              ),
            ),

            // Description overlay (bottom-left) if present
            if (grupo.descripcion != null && grupo.descripcion!.isNotEmpty)
              Positioned(
                left: 14, right: 14, bottom: 10,
                child: Text(
                  grupo.descripcion!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradient(Color color) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color,
              Color.lerp(color, Colors.black, 0.28)!,
            ],
          ),
        ),
      );
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _ProximoEventoCard extends ConsumerWidget {
  final String grupoId;
  const _ProximoEventoCard({required this.grupoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gc = ref.watch(grupoColorProvider(grupoId));
    final evento = ref.watch(proximoEventoGrupoProvider(grupoId));

    if (evento == null) return const SizedBox.shrink();

    final eventDate = evento.fechaEvento ?? evento.fechaCaducidad;
    final fechaFmt = eventDate != null
        ? DateFormat('EEE dd/MM', 'es_AR').format(eventDate)
        : '';
    final diffDays = eventDate != null
        ? eventDate.difference(DateTime.now()).inDays
        : null;
    final daysLabel = diffDays == null
        ? ''
        : diffDays == 0
            ? '¡Hoy!'
            : diffDays == 1
                ? 'Mañana'
                : 'en $diffDays días';

    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/novedades'),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: gc.withValues(alpha: 0.12),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event_rounded, size: 18, color: gc),
                    const SizedBox(width: 8),
                    Text(
                      (fechaFmt.isNotEmpty ? 'PRÓXIMO · $fechaFmt' : 'PRÓXIMO EVENTO')
                          .toUpperCase(),
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700, fontSize: 11,
                        letterSpacing: 1, color: gc,
                      ),
                    ),
                    const Spacer(),
                    if (daysLabel.isNotEmpty)
                      Text(daysLabel,
                          style: GoogleFonts.dmSans(
                            fontSize: 11, color: gc,
                            fontWeight: FontWeight.w600,
                          )),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(evento.titulo,
                        style: GoogleFonts.bricolageGrotesque(
                          fontWeight: FontWeight.w700, fontSize: 18,
                          letterSpacing: -0.3,
                        )),
                    if (evento.contenido.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(evento.contenido,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.textMuted)),
                    ],
                    const SizedBox(height: 10),
                    Row(children: [
                      Icon(Icons.checklist_rounded, size: 14, color: gc),
                      const SizedBox(width: 4),
                      Text('Ver asistencia →',
                          style: TextStyle(
                              fontSize: 12, color: gc,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _BentoTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg, iconColor;
  final String label, big;
  final String? sub;
  final VoidCallback? onTap;

  const _BentoTile({
    required this.icon, required this.iconBg, required this.iconColor,
    required this.label, required this.big, this.sub, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  SGIconTile(
                    icon: icon, background: iconBg, iconColor: iconColor,
                    size: 32, radius: 10,
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(label,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textMuted,
                          fontWeight: FontWeight.w600))),
                ],
              ),
              const SizedBox(height: 14),
              Text(big,
                  style: GoogleFonts.bricolageGrotesque(
                    fontWeight: FontWeight.w700, fontSize: 18,
                    letterSpacing: -0.3, height: 1.1,
                  )),
              if (sub != null) ...[
                const SizedBox(height: 4),
                Text(sub!,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textMuted)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// ── Bento KPI grid wired to real data ────────────────────────────────────────
class _BentoGrid extends ConsumerWidget {
  final String grupoId;
  final Color gc;
  const _BentoGrid({required this.grupoId, required this.gc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cuotas = ref.watch(cuotasProvider(grupoId)).valueOrNull ?? [];

    // Next active unpaid cuota
    final now = DateTime.now();
    final cuotasPendientes = cuotas.where((c) => c.activa).toList();
    cuotasPendientes.sort((a, b) => a.vencimiento.compareTo(b.vencimiento));
    final proxCuota = cuotasPendientes.isNotEmpty ? cuotasPendientes.first : null;
    String cuotaBig, cuotaSub;
    if (proxCuota == null) {
      cuotaBig = 'Sin cuotas';
      cuotaSub = '';
    } else {
      final diff = proxCuota.vencimiento.difference(now).inDays;
      cuotaBig = diff < 0 ? 'Vencida' : diff == 0 ? 'Vence hoy' : diff == 1 ? 'Vence mañana' : 'Vence en $diff días';
      cuotaSub = proxCuota.titulo;
    }

    // Módulos "Tareas" y "Recursos" en pausa — sólo se muestran Gastos y Cuota.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _BentoTile(
            icon: Icons.account_balance_wallet_outlined,
            iconBg: AppTheme.goodSoft, iconColor: AppTheme.goodInk,
            label: 'Gastos',
            big: 'Ver gastos',
            onTap: () => context.push('/gastos'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _BentoTile(
            icon: Icons.payments_outlined,
            iconBg: AppTheme.dangerSoft, iconColor: AppTheme.dangerInk,
            label: 'Tu cuota',
            big: cuotaBig,
            sub: cuotaSub.isNotEmpty ? cuotaSub : null,
            onTap: () => context.push('/cuotas'),
          ),
        ),
      ],
    );
  }
}

// ── Últimas noticias reales del grupo ────────────────────────────────────────
class _UltimasNoticias extends ConsumerWidget {
  final String grupoId;
  const _UltimasNoticias({required this.grupoId});

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'hace ${diff.inHours}h';
    if (diff.inDays < 7) return 'hace ${diff.inDays}d';
    return DateFormat('dd/MM/yy').format(dt);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noticiasAsync = ref.watch(noticiasProvider(grupoId));
    final noticias = noticiasAsync.valueOrNull
            ?.where((n) => !n.caducada)
            .take(3)
            .toList() ??
        [];

    if (noticiasAsync.isLoading) return const SizedBox.shrink();
    if (noticias.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SGEyebrow('Últimas noticias'),
        const SizedBox(height: 8),
        ...noticias.map((n) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => context.push('/novedades'),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.primarySoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.newspaper_outlined,
                            size: 18, color: AppTheme.primaryInk),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n.titulo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 2),
                            Text('${n.autorNombre} · ${_timeAgo(n.createdAt)}',
                                style: const TextStyle(
                                    fontSize: 11, color: AppTheme.textMuted)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          size: 16, color: AppTheme.textMuted),
                    ],
                  ),
                ),
              ),
            )),
        Center(
          child: TextButton(
            onPressed: () => context.push('/novedades'),
            child: const Text('Ver todas las noticias →',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

class _DesktopNavChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _DesktopNavChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppTheme.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
