import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../data/models/actividad_model.dart';
import '../../../data/models/notificacion_rol_model.dart';
import '../../../providers/notificacion_provider.dart';
import '../../../providers/auth_provider.dart';

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Notificaciones page
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class NotificacionesPage extends ConsumerStatefulWidget {
  const NotificacionesPage({super.key});

  @override
  ConsumerState<NotificacionesPage> createState() =>
      _NotificacionesPageState();
}

class _NotificacionesPageState extends ConsumerState<NotificacionesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(unreadRolCountProvider).valueOrNull ?? 0;

    final isDesktop = MediaQuery.sizeOf(context).width >= AppTheme.kResponsiveBreakpoint;

    final tabBar = TabBar(
      controller: _tab,
      labelStyle: GoogleFonts.bricolageGrotesque(
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
      unselectedLabelStyle: GoogleFonts.bricolageGrotesque(
        fontWeight: FontWeight.w500,
        fontSize: 13,
      ),
      indicatorColor: AppTheme.primary,
      labelColor: AppTheme.primary,
      unselectedLabelColor: AppTheme.textMuted,
      tabs: [
        const Tab(text: 'Generales'),
        Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('De rol'),
              if (unread > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.danger,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '$unread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: AppTheme.surf(context),
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/home'),
              ),
              titleSpacing: 4,
              title: Text(
                'Notificaciones',
                style: GoogleFonts.bricolageGrotesque(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  letterSpacing: -0.2,
                ),
              ),
              actions: [
                if (unread > 0)
                  TextButton(
                    onPressed: _marcarTodasLeidas,
                    child: const Text(
                      'Marcar leídas',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(49),
                child: Column(
                  children: [
                    Container(height: 1, color: AppTheme.border),
                    tabBar,
                  ],
                ),
              ),
            ),
      body: Column(
        children: [
          if (isDesktop) ...[
            Container(
              color: AppTheme.surf(context),
              child: Column(
                children: [
                  Container(height: 1, color: AppTheme.border),
                  Row(
                    children: [
                      Expanded(child: tabBar),
                      if (unread > 0)
                        Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: TextButton(
                            onPressed: _marcarTodasLeidas,
                            child: const Text(
                              'Marcar leídas',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: const [
                _GeneralesTab(),
                _RolTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _marcarTodasLeidas() {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    ref.read(notificacionRepositoryProvider).marcarTodasLeidas(uid);
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Generales tab
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _GeneralesTab extends ConsumerWidget {
  const _GeneralesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(actividadAgregadaProvider);

    return async.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      ),
      error: (e, _) => const SGErrorState(message: 'Error al cargar las notificaciones'),
      data: (items) {
        if (items.isEmpty) {
          return const _EmptyState(
            icon: Icons.notifications_none_rounded,
            message: 'Sin actividad reciente en tus grupos',
          );
        }
        return RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: () => ref.refresh(actividadAgregadaProvider.future),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              indent: 68,
              color: AppTheme.border,
            ),
            itemBuilder: (_, i) => _ActividadTile(item: items[i]),
          ),
        );
      },
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Rol tab
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _RolTab extends ConsumerWidget {
  const _RolTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    final async = ref.watch(notificacionesRolProvider);

    return async.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      ),
      error: (e, _) => const SGErrorState(message: 'Error al cargar las notificaciones'),
      data: (notifs) {
        if (notifs.isEmpty) {
          return const _EmptyState(
            icon: Icons.shield_outlined,
            message: 'No tenés notificaciones de rol',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: notifs.length,
          separatorBuilder: (_, __) => const Divider(
            height: 1,
            indent: 68,
            color: AppTheme.border,
          ),
          itemBuilder: (_, i) => _RolTile(notif: notifs[i], uid: uid ?? ''),
        );
      },
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Actividad tile (Generales)
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ActividadTile extends StatelessWidget {
  final ActividadModel item;
  const _ActividadTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: _ActividadIcon(tipo: item.tipo, actorNombre: item.actorNombre,
          actorAvatarUrl: item.actorAvatarUrl),
      title: Text(
        item.titulo,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.mensaje,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            item.grupoNombre,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      trailing: Text(
        _dateLabel(item.createdAt),
        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
      ),
      onTap: item.referenciaId != null
          ? () => context.push(
              '/novedades/${item.referenciaId}/comentarios')
          : () => context.go('/home'),
    );
  }

  static String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'hace ${diff.inHours}h';
    try {
      return DateFormat('d MMM', 'es_AR').format(dt);
    } catch (_) {
      return DateFormat('d MMM').format(dt);
    }
  }
}

class _ActividadIcon extends StatelessWidget {
  final String tipo;
  final String actorNombre;
  final String? actorAvatarUrl;

  const _ActividadIcon(
      {required this.tipo,
      required this.actorNombre,
      this.actorAvatarUrl});

  @override
  Widget build(BuildContext context) {
    if (tipo == 'noticia' || tipo == 'nuevo_miembro') {
      return SGAvatar(
          name: actorNombre, imageUrl: actorAvatarUrl, size: 40);
    }
    final (icon, bg, fg) = switch (tipo) {
      'nueva_cuota' => (
          Icons.payments_rounded,
          AppTheme.accentSoft,
          AppTheme.accent
        ),
      'nueva_tarea' => (
          Icons.task_alt_rounded,
          AppTheme.primarySoft,
          AppTheme.primary
        ),
      'gasto' => (
          Icons.receipt_long_rounded,
          AppTheme.dangerSoft,
          AppTheme.danger
        ),
      _ => (
          Icons.notifications_rounded,
          AppTheme.surfaceAlt,
          AppTheme.textMuted
        ),
    };
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, size: 20, color: fg),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Rol tile
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _RolTile extends ConsumerWidget {
  final NotificacionRolModel notif;
  final String uid;
  const _RolTile({required this.notif, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (icon, bg, fg) = switch (notif.tipo) {
      'admin' => (
          Icons.admin_panel_settings_rounded,
          AppTheme.dangerSoft,
          AppTheme.danger
        ),
      'moderador' => (
          Icons.shield_rounded,
          AppTheme.primarySoft,
          AppTheme.primary
        ),
      'tesorero' => (
          Icons.account_balance_wallet_rounded,
          AppTheme.goodSoft,
          AppTheme.good
        ),
      'delegado' => (
          Icons.assignment_ind_rounded,
          AppTheme.accentSoft,
          AppTheme.accent
        ),
      _ => (
          Icons.notifications_rounded,
          AppTheme.surfaceAlt,
          AppTheme.textMuted
        ),
    };

    return ListTile(
      tileColor: notif.leida
          ? null
          : AppTheme.primarySoft.withValues(alpha: 0.25),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 40,
        height: 40,
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, size: 20, color: fg),
      ),
      title: Text(
        notif.titulo,
        style: TextStyle(
          fontWeight: notif.leida ? FontWeight.w500 : FontWeight.w700,
          fontSize: 13,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            notif.mensaje,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            notif.grupoNombre,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _dateLabel(notif.createdAt),
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
          if (!notif.leida) ...[
            const SizedBox(height: 4),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
      onTap: () {
        if (!notif.leida && uid.isNotEmpty) {
          ref
              .read(notificacionRepositoryProvider)
              .marcarLeida(uid, notif.id);
        }
        context.go('/home');
      },
    );
  }

  static String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'hace ${diff.inHours}h';
    try {
      return DateFormat('d MMM', 'es_AR').format(dt);
    } catch (_) {
      return DateFormat('d MMM').format(dt);
    }
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Empty state
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppTheme.border),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
