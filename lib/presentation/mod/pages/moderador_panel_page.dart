import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/nav_ext.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/miembro_model.dart';
import '../../../data/models/noticia_model.dart';
import '../../../providers/grupo_provider.dart';
import '../../../providers/noticia_provider.dart';

class ModeradorPanelPage extends ConsumerWidget {
  final String grupoId;
  const ModeradorPanelPage({super.key, required this.grupoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gc = ref.watch(grupoColorProvider(grupoId));
    final solicitudesAsync = ref.watch(solicitudesPendientesProvider(grupoId));
    final miembrosAsync = ref.watch(miembrosProvider(grupoId));
    final noticiasAsync = ref.watch(noticiasProvider(grupoId));

    final solicitudes = solicitudesAsync.valueOrNull ?? [];
    final miembros = miembrosAsync.valueOrNull ?? [];
    final noticias = noticiasAsync.valueOrNull ?? [];

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            // â”€â”€ Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => context.popOr(),
                    ),
                    Expanded(
                      child: Text(
                        'Panel Moderador',
                        style: GoogleFonts.bricolageGrotesque(
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                          letterSpacing: -0.3,
                          color: AppTheme.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // â”€â”€ Stats row
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _ModStat(
                        label: 'Miembros',
                        value: '${miembros.length}',
                        icon: Icons.people_outline_rounded,
                        color: gc,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ModStat(
                        label: 'Solicitudes',
                        value: '${solicitudes.length}',
                        icon: Icons.person_add_outlined,
                        color: solicitudes.isNotEmpty
                            ? AppTheme.warning
                            : AppTheme.textMuted,
                        highlight: solicitudes.isNotEmpty,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ModStat(
                        label: 'Noticias',
                        value: '${noticias.length}',
                        icon: Icons.newspaper_rounded,
                        color: AppTheme.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // â”€â”€ Solicitudes pendientes
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Row(
                  children: [
                    const SGEyebrow('Solicitudes de ingreso'),
                    if (solicitudes.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.warning
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${solicitudes.length}',
                            style: const TextStyle(
                                color: AppTheme.warning,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: solicitudes.isEmpty
                  ? const SliverToBoxAdapter(
                      child: _EmptySection(
                        icon: Icons.check_circle_outline_rounded,
                        label: 'No hay solicitudes pendientes',
                        color: AppTheme.good,
                      ),
                    )
                  : SliverList.separated(
                      itemCount: solicitudes.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final s = solicitudes[i];
                        return SGCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              SGAvatar(
                                  name: s.usuarioNombre,
                                  imageUrl: s.usuarioAvatar,
                                  size: 42),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(s.usuarioNombre,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14)),
                                    Text(
                                      DateFormat('dd/MM/yyyy')
                                          .format(s.createdAt),
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              _ActionBtn(
                                icon: Icons.close_rounded,
                                color: AppTheme.danger,
                                onTap: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Rechazar solicitud'),
                                      content: Text(
                                          '¿Rechazás la solicitud de ${s.usuarioNombre}?'),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('Cancelar')),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          style: TextButton.styleFrom(
                                              foregroundColor: AppTheme.danger),
                                          child: const Text('Rechazar'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm != true || !context.mounted) return;
                                  ref.read(grupoRepositoryProvider).responderSolicitud(
                                      grupoId, s.usuarioUid, false,
                                      s.usuarioNombre, s.usuarioAvatar);
                                },
                              ),
                              const SizedBox(width: 8),
                              _ActionBtn(
                                icon: Icons.check_rounded,
                                color: AppTheme.good,
                                onTap: () => ref
                                    .read(grupoRepositoryProvider)
                                    .responderSolicitud(
                                        grupoId,
                                        s.usuarioUid,
                                        true,
                                        s.usuarioNombre,
                                        s.usuarioAvatar),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            // â”€â”€ Miembros section (expel)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Row(
                  children: [
                    const SGEyebrow('Miembros'),
                    const Spacer(),
                    GestureDetector(
                      onTap: () =>
                          context.push('/miembros'),
                      child: Text(
                        'Ver todos →',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: gc,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: miembros.isEmpty
                  ? const SliverToBoxAdapter(
                      child: _EmptySection(
                        icon: Icons.people_outline,
                        label: 'Sin miembros',
                        color: AppTheme.textMuted,
                      ),
                    )
                  : SliverList.separated(
                      itemCount: miembros.take(5).length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 6),
                      itemBuilder: (_, i) => _MiembroModTile(
                        miembro: miembros[i],
                        grupoId: grupoId,
                      ),
                    ),
            ),

            if (miembros.length > 5)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: GestureDetector(
                    onTap: () =>
                        context.push('/miembros'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Ver todos los miembros (${miembros.length})',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: gc,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // â”€â”€ Noticias section
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: SGEyebrow('Noticias recientes'),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: noticias.isEmpty
                  ? const SliverToBoxAdapter(
                      child: _EmptySection(
                        icon: Icons.newspaper_outlined,
                        label: 'No hay noticias',
                        color: AppTheme.textMuted,
                      ),
                    )
                  : SliverList.separated(
                      itemCount: noticias.take(3).length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, i) => _NoticiaModCard(
                        noticia: noticias[i],
                        grupoId: grupoId,
                      ),
                    ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Mod Stat â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ModStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool highlight;

  const _ModStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlight
            ? color.withValues(alpha: 0.08)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: highlight
                ? color.withValues(alpha: 0.25)
                : AppTheme.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.bricolageGrotesque(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: highlight ? color : AppTheme.text,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

// â”€â”€ Action Button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

// â”€â”€ Empty Section â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _EmptySection extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _EmptySection(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}

// â”€â”€ Miembro Mod Tile â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _MiembroModTile extends ConsumerWidget {
  final MiembroModel miembro;
  final String grupoId;

  const _MiembroModTile(
      {required this.miembro, required this.grupoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gc = ref.watch(grupoColorProvider(grupoId));
    final esAdmin = miembro.rol == RolMiembro.administrador;
    final rolColor = switch (miembro.rol) {
      RolMiembro.administrador => gc,
      _ => AppTheme.roleColor(miembro.rol),
    };
    final rolLabel = switch (miembro.rol) {
      RolMiembro.administrador => 'Admin',
      RolMiembro.moderador => 'Moderador',
      RolMiembro.tesorero => 'Tesorero',
      RolMiembro.delegado => 'Delegado',
      RolMiembro.miembro => 'Miembro',
    };

    return SGCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          SGAvatar(
              name: miembro.nombreCompleto,
              imageUrl: miembro.avatarUrl,
              size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(miembro.nombreCompleto,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: rolColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(rolLabel,
                      style: TextStyle(
                          color: rolColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          if (!esAdmin)
            GestureDetector(
              onTap: () => _confirmExpulsar(context, ref),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person_remove_outlined,
                    size: 16, color: AppTheme.danger),
              ),
            ),
        ],
      ),
    );
  }

  void _confirmExpulsar(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Expulsar miembro'),
        content: Text(
            '¿Expulsás a ${miembro.nombreCompleto}? Perderá todo acceso.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref
                    .read(grupoRepositoryProvider)
                    .leaveGrupo(grupoId, miembro.uid);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        '${miembro.nombreCompleto} fue expulsado/a ✓'),
                    backgroundColor: AppTheme.danger,
                  ));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Expulsar'),
          ),
        ],
      ),
    );
  }
}

// â”€â”€ Noticia Mod Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _NoticiaModCard extends ConsumerWidget {
  final NoticiaModel noticia;
  final String grupoId;
  const _NoticiaModCard({required this.noticia, required this.grupoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SGCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Text(noticia.categoria.emoji,
              style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  noticia.titulo,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  noticia.autorNombre,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          // Pin toggle
          GestureDetector(
            onTap: () => ref
                .read(crearNoticiaProvider.notifier)
                .toggleFijada(grupoId, noticia.id, !noticia.fijada),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                noticia.fijada ? Icons.push_pin : Icons.push_pin_outlined,
                size: 16,
                color: noticia.fijada
                    ? AppTheme.warning
                    : AppTheme.textMuted,
              ),
            ),
          ),
          // Delete
          GestureDetector(
            onTap: () => _confirmDelete(context, ref),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  size: 15, color: AppTheme.danger),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar noticia'),
        content: Text('¿Eliminás "${noticia.titulo}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(noticiaRepositoryProvider)
                  .deleteNoticia(grupoId, noticia.id);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
