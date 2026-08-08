import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/nav_ext.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../data/models/miembro_model.dart';
import '../../../data/models/solicitud_union_model.dart';
import '../../../data/models/enums.dart';
import '../../../providers/grupo_provider.dart';
import '../../../providers/cuota_provider.dart';
import '../../../providers/noticia_provider.dart';

class AdminPanelPage extends ConsumerWidget {
  final String grupoId;
  const AdminPanelPage({super.key, required this.grupoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gc = ref.watch(grupoColorProvider(grupoId));
    final grupo = ref.watch(grupoProvider(grupoId)).valueOrNull;
    final miembros = ref.watch(miembrosProvider(grupoId)).valueOrNull ?? [];
    final solicitudes =
        ref.watch(solicitudesPendientesProvider(grupoId)).valueOrNull ?? [];
    final cuotas = ref.watch(cuotasProvider(grupoId)).valueOrNull ?? [];
    final pagos = ref.watch(pagosGrupoProvider(grupoId)).valueOrNull ?? [];
    final noticias = ref.watch(noticiasProvider(grupoId)).valueOrNull ?? [];

    final aprobados =
        pagos.where((p) => p.estado == EstadoPago.aprobado).length;
    final totalMiembros = miembros.isNotEmpty ? miembros.length : 1;
    final cuotasAlDiaPct = cuotas.isEmpty
        ? 0.0
        : (aprobados / (cuotas.length * totalMiembros) * 100)
            .clamp(0.0, 100.0);

    final eventNoticias = noticias.where((n) => n.tieneListado).toList();
    final asistenciaPct = eventNoticias.isEmpty
        ? 0.0
        : (eventNoticias.where((n) => n.mencionados.isNotEmpty).length /
                eventNoticias.length *
                100)
            .clamp(0.0, 100.0);

    final engagementPct = noticias.isEmpty
        ? 0.0
        : (noticias.where((n) => n.likesCount > 0).length /
                noticias.length *
                100)
            .clamp(0.0, 100.0);

    final hace30Dias = DateTime.now().subtract(const Duration(days: 30));
    final uidsActivos = pagos
        .where((p) => p.createdAt.isAfter(hace30Dias))
        .map((p) => p.usuarioUid)
        .toSet();
    final actividadRecientePct = miembros.isEmpty
        ? 0.0
        : (uidsActivos.length / miembros.length * 100).clamp(0.0, 100.0);

    final healthScore = _healthScore(
        cuotasAlDiaPct, actividadRecientePct, asistenciaPct, engagementPct);

    final oldestDias = solicitudes.isEmpty
        ? 0
        : DateTime.now()
            .difference(solicitudes
                .map((s) => s.createdAt)
                .reduce((a, b) => a.isBefore(b) ? a : b))
            .inDays;

    final staffMembers =
        miembros.where((m) => m.rol != RolMiembro.miembro).toList();

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            // Header
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
                        'Panel Admin',
                        style: GoogleFonts.bricolageGrotesque(
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                          letterSpacing: -0.3,
                          color: AppTheme.text,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_rounded, size: 20),
                      tooltip: 'Configuración del grupo',
                      onPressed: () =>
                          context.push('/ajustes'),
                    ),
                  ],
                ),
              ),
            ),

            // Admin badge
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppTheme.danger.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield_rounded,
                          size: 14, color: AppTheme.danger),
                      const SizedBox(width: 6),
                      Text(
                        'Sos Admin · ${grupo?.nombre ?? ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Health + metrics card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _HealthCard(
                  score: healthScore,
                  cuotasAlDia: cuotasAlDiaPct,
                  asistenciaEventos: asistenciaPct,
                  actividadReciente: actividadRecientePct,
                  engagementNoticias: engagementPct,
                  tieneCuotas: cuotas.isNotEmpty,
                  tieneEventos: eventNoticias.isNotEmpty,
                  tieneNoticias: noticias.isNotEmpty,
                ),
              ),
            ),

            // Solicitudes alert card
            if (solicitudes.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: GestureDetector(
                    onTap: () =>
                        _showSolicitudesSheet(context, ref, solicitudes),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color:
                                AppTheme.warning.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppTheme.warning
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                    Icons.person_add_outlined,
                                    size: 22,
                                    color: AppTheme.warning),
                              ),
                              Positioned(
                                top: -4,
                                right: -4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.warning,
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${solicitudes.length}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${solicitudes.length} pedido${solicitudes.length != 1 ? 's' : ''} de ingreso esperan tu aprobación',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.text,
                                  ),
                                ),
                                if (oldestDias > 0)
                                  Text(
                                    'El más antiguo lleva $oldestDias día${oldestDias != 1 ? 's' : ''}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textMuted),
                                  ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: AppTheme.warning),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Quick actions (3x2 grid)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SGEyebrow('Acciones rápidas'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionTile(
                            icon: Icons.person_add_outlined,
                            label: 'Aprobar\ningresos',
                            badge: solicitudes.isNotEmpty
                                ? '${solicitudes.length}'
                                : null,
                            color: AppTheme.warning,
                            onTap: () => _showSolicitudesSheet(
                                context, ref, solicitudes),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionTile(
                            icon: Icons.manage_accounts_rounded,
                            label: 'Gestionar\nroles',
                            color: gc,
                            onTap: () =>
                                context.push('/miembros'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionTile(
                            icon: Icons.payments_outlined,
                            label: 'Configurar\ncuota',
                            color: AppTheme.good,
                            onTap: () =>
                                context.push('/suscripciones'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionTile(
                            icon: Icons.event_rounded,
                            label: 'Crear\nevento',
                            color: AppTheme.accent,
                            onTap: () => context
                                .push('/evento/crear'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionTile(
                            icon: Icons.campaign_outlined,
                            label: 'Comunicado',
                            color: AppTheme.primary,
                            onTap: () => context
                                .push('/novedades'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionTile(
                            icon: Icons.archive_outlined,
                            label: 'Archivar\ngrupo',
                            color: AppTheme.textMuted,
                            onTap: () => context
                                .push('/ajustes'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Staff activity
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 28, 16, 8),
                child: SGEyebrow('Actividad del staff'),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              sliver: staffMembers.isEmpty
                  ? const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('Sin staff asignado',
                            style:
                                TextStyle(color: AppTheme.textMuted)),
                      ),
                    )
                  : SliverList.separated(
                      itemCount: staffMembers.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 6),
                      itemBuilder: (_, i) => _MiembroRolTile(
                        miembro: staffMembers[i],
                        grupoId: grupoId,
                      ),
                    ),
            ),

            // Danger zone
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 8),
                child: _DangerZone(grupoId: grupoId),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  void _showSolicitudesSheet(BuildContext context, WidgetRef ref,
      List<SolicitudUnionModel> solicitudes) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          _SolicitudesSheet(solicitudes: solicitudes, grupoId: grupoId),
    );
  }

  static double _healthScore(
      double cuotas, double actividad, double asistencia, double engagement) {
    return (cuotas * 0.35 + actividad * 0.30 + asistencia * 0.20 + engagement * 0.15)
        .clamp(0.0, 100.0);
  }
}

// Health Card with 4 real metrics + suggestions

class _HealthCard extends StatelessWidget {
  final double score;
  final double cuotasAlDia;
  final double asistenciaEventos;
  final double actividadReciente;
  final double engagementNoticias;
  final bool tieneCuotas;
  final bool tieneEventos;
  final bool tieneNoticias;

  const _HealthCard({
    required this.score,
    required this.cuotasAlDia,
    required this.asistenciaEventos,
    required this.actividadReciente,
    required this.engagementNoticias,
    required this.tieneCuotas,
    required this.tieneEventos,
    required this.tieneNoticias,
  });

  @override
  Widget build(BuildContext context) {
    final color = score >= 75
        ? AppTheme.good
        : score >= 45
            ? AppTheme.warning
            : AppTheme.danger;
    final label = score >= 75
        ? 'Excelente'
        : score >= 45
            ? 'Bueno'
            : 'Necesita atención';

    String? sugerenciaCuotas;
    if (!tieneCuotas) {
      sugerenciaCuotas = 'Creá la primera cuota para empezar a cobrar';
    } else if (cuotasAlDia < 60) {
      sugerenciaCuotas = 'Enviá recordatorios a los miembros con pagos vencidos';
    }

    String? sugerenciaActividad;
    if (actividadReciente < 30) {
      sugerenciaActividad = 'Publicá novedades para re-enganchar a miembros inactivos';
    }

    String? sugerenciaAsistencia;
    if (!tieneEventos) {
      sugerenciaAsistencia = 'Creá un evento con lista de asistencia para hacer seguimiento';
    } else if (asistenciaEventos < 50) {
      sugerenciaAsistencia = 'Activá el listado de asistencia en tus próximos eventos';
    }

    String? sugerenciaEngagement;
    if (!tieneNoticias) {
      sugerenciaEngagement = 'Publicá tu primera novedad para informar al grupo';
    } else if (engagementNoticias < 30) {
      sugerenciaEngagement = 'Publicá noticias con preguntas o encuestas para generar participación';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Salud del grupo',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                score.toStringAsFixed(0),
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.text,
                  letterSpacing: -1,
                  height: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4),
                child: Text(
                  '/ 100',
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Basado en pagos, actividad, eventos y noticias del grupo',
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 16),
          _MetricBar(
            label: 'Cuotas al día',
            pct: cuotasAlDia,
            color: cuotasAlDia >= 70 ? AppTheme.good : AppTheme.warning,
            origen: tieneCuotas
                ? 'Pagos aprobados / total esperado'
                : 'Sin cuotas creadas aún',
            sugerencia: sugerenciaCuotas,
          ),
          const SizedBox(height: 12),
          _MetricBar(
            label: 'Actividad reciente',
            pct: actividadReciente,
            color: actividadReciente >= 50 ? AppTheme.good : AppTheme.warning,
            origen: 'Miembros con pagos en los últimos 30 días',
            sugerencia: sugerenciaActividad,
          ),
          const SizedBox(height: 12),
          _MetricBar(
            label: 'Asistencia a eventos',
            pct: asistenciaEventos,
            color: asistenciaEventos >= 50 ? AppTheme.good : AppTheme.accent,
            origen: tieneEventos
                ? 'Eventos con al menos 1 confirmación'
                : 'Sin eventos con lista de asistencia',
            sugerencia: sugerenciaAsistencia,
          ),
          const SizedBox(height: 12),
          _MetricBar(
            label: 'Engagement noticias',
            pct: engagementNoticias,
            color: engagementNoticias >= 40 ? AppTheme.good : AppTheme.accent,
            origen: tieneNoticias
                ? 'Noticias con al menos 1 like'
                : 'Sin noticias publicadas aún',
            sugerencia: sugerenciaEngagement,
          ),
        ],
      ),
    );
  }
}

class _MetricBar extends StatelessWidget {
  final String label;
  final double pct;
  final Color color;
  final String origen;
  final String? sugerencia;

  const _MetricBar({
    required this.label,
    required this.pct,
    required this.color,
    required this.origen,
    this.sugerencia,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.text),
              ),
            ),
            Text(
              '${pct.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: pct / 100,
            minHeight: 6,
            backgroundColor: AppTheme.border,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          origen,
          style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
        ),
        if (sugerencia != null) ...[
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('→ ', style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w700)),
              Expanded(
                child: Text(
                  sugerencia!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// Action Tile

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String? badge;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                if (badge != null)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(badge!,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.text,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// Solicitudes Sheet

class _SolicitudesSheet extends ConsumerWidget {
  final List<SolicitudUnionModel> solicitudes;
  final String grupoId;

  const _SolicitudesSheet(
      {required this.solicitudes, required this.grupoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Text(
                  'Solicitudes pendientes',
                  style: GoogleFonts.bricolageGrotesque(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppTheme.text,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${solicitudes.length}',
                      style: const TextStyle(
                          color: AppTheme.warning,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              itemCount: solicitudes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                      GestureDetector(
                        onTap: () => _responder(context, ref, s, false),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color:
                                AppTheme.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.close_rounded,
                              size: 18, color: AppTheme.danger),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _responder(context, ref, s, true),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color:
                                AppTheme.good.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.check_rounded,
                              size: 18, color: AppTheme.good),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _responder(BuildContext context, WidgetRef ref,
      SolicitudUnionModel s, bool aprobar) async {
    if (!aprobar) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Rechazar solicitud'),
          content: Text(
              '¿Rechazás la solicitud de ${s.usuarioNombre}? No podrá unirse al grupo.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style:
                  TextButton.styleFrom(foregroundColor: AppTheme.danger),
              child: const Text('Rechazar'),
            ),
          ],
        ),
      );
      if (confirm != true || !context.mounted) return;
    }
    await ref.read(grupoRepositoryProvider).responderSolicitud(
        grupoId, s.usuarioUid, aprobar, s.usuarioNombre, s.usuarioAvatar);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(aprobar ? 'Solicitud aprobada ✓' : 'Solicitud rechazada'),
        backgroundColor: aprobar ? AppTheme.good : AppTheme.danger,
      ));
    }
  }
}

// Miembro Rol Tile

class _MiembroRolTile extends ConsumerWidget {
  final MiembroModel miembro;
  final String grupoId;

  const _MiembroRolTile({required this.miembro, required this.grupoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gc = ref.watch(grupoColorProvider(grupoId));
    final color = _rolColor(miembro.rol, gc);
    final esAdmin = miembro.rol == RolMiembro.administrador;
    final grupoNombre =
        ref.watch(grupoProvider(grupoId)).valueOrNull?.nombre ?? '';

    return SGCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          SGAvatar(
              name: miembro.nombreCompleto,
              imageUrl: miembro.avatarUrl,
              size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(miembro.nombreCompleto,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                Text(
                  'Desde ${DateFormat('dd/MM/yy').format(miembro.joinedAt)}',
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () =>
                _showRolPicker(context, ref, grupoNombre, gc),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_rolLabel(miembro.rol),
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                  const SizedBox(width: 3),
                  Icon(Icons.unfold_more_rounded, color: color, size: 14),
                ],
              ),
            ),
          ),
          if (!esAdmin) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => _confirmExpulsar(context, ref),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person_remove_outlined,
                    size: 16, color: AppTheme.danger),
              ),
            ),
          ],
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
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.danger),
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

  void _showRolPicker(BuildContext context, WidgetRef ref,
      String grupoNombre, Color gc) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Text(
              'Rol de ${miembro.nombreCompleto.split(' ').first}',
              style: GoogleFonts.bricolageGrotesque(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppTheme.text,
              ),
            ),
            const SizedBox(height: 12),
            ...rolesAsignables.map((rol) {
              final selected = rol == miembro.rol;
              final color = _rolColor(rol, gc);
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_rolIcon(rol), size: 15, color: color),
                ),
                title: Text(_rolLabel(rol),
                    style: TextStyle(
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500)),
                subtitle: Text(_rolDesc(rol),
                    style: const TextStyle(fontSize: 11)),
                trailing: selected
                    ? Icon(Icons.check_rounded, color: color)
                    : null,
                onTap: () async {
                  Navigator.pop(context);
                  if (!selected) {
                    await ref
                        .read(grupoRepositoryProvider)
                        .updateRolMiembro(
                          grupoId,
                          miembro.uid,
                          rol,
                          nombreMiembro: miembro.nombreCompleto,
                          grupoNombre: grupoNombre,
                        );
                  }
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}

// Danger Zone

class _DangerZone extends ConsumerWidget {
  final String grupoId;
  const _DangerZone({required this.grupoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 16, color: AppTheme.danger),
              SizedBox(width: 6),
              Text(
                'Zona de peligro',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _confirmEliminar(context, ref),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppTheme.danger.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.delete_forever_rounded,
                      size: 18, color: AppTheme.danger),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Eliminar grupo',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.danger,
                          ),
                        ),
                        Text(
                          'Esta acción no se puede deshacer',
                          style: TextStyle(
                              fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: AppTheme.danger, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmEliminar(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar grupo'),
        content: const Text(
            'Se eliminarán permanentemente el grupo, todos sus miembros, cuotas, pagos, noticias, tareas y archivos. Esta acción no se puede deshacer.'),
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
                    .deleteGrupo(grupoId);
                if (context.mounted) context.go('/home');
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al eliminar: $e'),
                      backgroundColor: AppTheme.danger,
                    ),
                  );
                }
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

// Helpers

String _rolLabel(RolMiembro rol) => switch (rol) {
      RolMiembro.administrador => 'Admin',
      RolMiembro.moderador => 'Moderador',
      RolMiembro.tesorero => 'Tesorero',
      RolMiembro.delegado => 'Delegado',
      RolMiembro.miembro => 'Miembro',
    };

String _rolDesc(RolMiembro rol) => switch (rol) {
      RolMiembro.administrador => 'Control total del grupo',
      RolMiembro.moderador => 'Gestiona miembros y noticias',
      RolMiembro.tesorero => 'Gestiona suscripciones y campañas',
      RolMiembro.delegado => 'Puede publicar noticias',
      RolMiembro.miembro => 'Acceso básico',
    };

Color _rolColor(RolMiembro rol, Color gc) => switch (rol) {
      RolMiembro.administrador => gc,
      _ => AppTheme.roleColor(rol),
    };

IconData _rolIcon(RolMiembro rol) => switch (rol) {
      RolMiembro.administrador => Icons.shield_rounded,
      RolMiembro.moderador => Icons.security_rounded,
      RolMiembro.tesorero => Icons.account_balance_wallet_rounded,
      RolMiembro.delegado => Icons.record_voice_over_rounded,
      RolMiembro.miembro => Icons.person_outline_rounded,
    };
