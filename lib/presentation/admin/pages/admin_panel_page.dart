import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../data/models/miembro_model.dart';
import '../../../data/models/solicitud_union_model.dart';
import '../../../data/models/enums.dart';
import '../../../providers/grupo_provider.dart';
import '../../../providers/cuota_provider.dart';
import '../../../providers/gasto_provider.dart';

class AdminPanelPage extends ConsumerWidget {
  final String grupoId;
  const AdminPanelPage({super.key, required this.grupoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gc = ref.watch(grupoColorProvider(grupoId));
    final miembros = ref.watch(miembrosProvider(grupoId)).valueOrNull ?? [];
    final solicitudes =
        ref.watch(solicitudesPendientesProvider(grupoId)).valueOrNull ?? [];
    final cuotas = ref.watch(cuotasProvider(grupoId)).valueOrNull ?? [];
    final pagos = ref.watch(pagosGrupoProvider(grupoId)).valueOrNull ?? [];
    final gastos = ref.watch(todosGastosProvider(grupoId)).valueOrNull ?? [];

    final aprobados =
        pagos.where((p) => p.estado == EstadoPago.aprobado).length;
    final pendientesCount = pagos
        .where((p) =>
            p.estado == EstadoPago.pendiente ||
            p.estado == EstadoPago.validando)
        .length;
    final totalPosibles =
        (miembros.isNotEmpty && cuotas.isNotEmpty) ? miembros.length * cuotas.length : 1;
    final pagoPct = (aprobados / totalPosibles * 100).clamp(0.0, 100.0);
    final totalRecaudado = pagos
        .where((p) => p.estado == EstadoPago.aprobado)
        .fold(0.0, (s, p) => s + p.montoEsperado);
    final totalGastos = gastos.fold(0.0, (s, g) => s + g.monto);
    final healthScore = _health(miembros.length, solicitudes.length, pagoPct);

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
                      onPressed: () => context.pop(),
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
                          context.push('/group/$grupoId/settings'),
                    ),
                  ],
                ),
              ),
            ),

            // â”€â”€ Health score card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _HealthCard(score: healthScore),
              ),
            ),

            // â”€â”€ Quick stats
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                        label: 'Miembros',
                        value: '${miembros.length}',
                        icon: Icons.people_outline_rounded,
                        color: gc,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniStat(
                        label: 'Recaudado',
                        value: '\$${_compact(totalRecaudado)}',
                        icon: Icons.savings_outlined,
                        color: AppTheme.good,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniStat(
                        label: 'Gastos',
                        value: '\$${_compact(totalGastos)}',
                        icon: Icons.receipt_long_outlined,
                        color: AppTheme.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // â”€â”€ Solicitudes alert
            if (solicitudes.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _AlertBanner(
                    icon: Icons.person_add_outlined,
                    color: AppTheme.warning,
                    label: '${solicitudes.length} solicitud${solicitudes.length != 1 ? 'es' : ''} de ingreso pendiente${solicitudes.length != 1 ? 's' : ''}',
                    onTap: () => _showSolicitudesSheet(context, ref, solicitudes),
                  ),
                ),
              ),

            // â”€â”€ Pagos pendientes alert
            if (pendientesCount > 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _AlertBanner(
                    icon: Icons.hourglass_top_rounded,
                    color: AppTheme.accent,
                    label:
                        '$pendientesCount comprobante${pendientesCount != 1 ? 's' : ''} por validar',
                    onTap: () =>
                        context.push('/group/$grupoId/tesorero'),
                  ),
                ),
              ),

            // â”€â”€ Quick actions
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SGEyebrow('Acciones rápidas'),
                    const SizedBox(height: 8),
                    // Row 1
                    Row(
                      children: [
                        Expanded(
                          child: _ActionTile(
                            icon: Icons.person_add_outlined,
                            label: 'Solicitudes',
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
                            label: 'Roles',
                            color: gc,
                            onTap: () =>
                                context.push('/group/$grupoId/miembros'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionTile(
                            icon: Icons.payments_outlined,
                            label: 'Suscripciones',
                            color: AppTheme.good,
                            onTap: () =>
                                context.push('/group/$grupoId/cuotas'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Row 2
                    Row(
                      children: [
                        Expanded(
                          child: _ActionTile(
                            icon: Icons.receipt_long_outlined,
                            label: 'Gastos',
                            color: AppTheme.accent,
                            onTap: () =>
                                context.push('/group/$grupoId/gastos'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionTile(
                            icon: Icons.task_alt_rounded,
                            label: 'Tareas',
                            color: AppTheme.good,
                            onTap: () =>
                                context.push('/group/$grupoId/tareas'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionTile(
                            icon: Icons.settings_rounded,
                            label: 'Configuración',
                            color: AppTheme.textMuted,
                            onTap: () =>
                                context.push('/group/$grupoId/settings'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // â”€â”€ Roles section
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: SGEyebrow('Roles del grupo'),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: miembros.isEmpty
                  ? const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text('Sin miembros',
                              style:
                                  TextStyle(color: AppTheme.textMuted)),
                        ),
                      ),
                    )
                  : SliverList.separated(
                      itemCount: miembros.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 6),
                      itemBuilder: (_, i) => _MiembroRolTile(
                        miembro: miembros[i],
                        grupoId: grupoId,
                      ),
                    ),
            ),

            // â”€â”€ Danger zone
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

  double _health(int members, int pending, double pagoPct) {
    double score = 55.0;
    if (members >= 5) score += 10;
    if (members >= 15) score += 5;
    if (pending == 0) score += 10;
    score += pagoPct * 0.20;
    return score.clamp(0.0, 100.0);
  }

  static String _compact(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}

// â”€â”€ Health Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _HealthCard extends StatelessWidget {
  final double score;
  const _HealthCard({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score >= 80
        ? AppTheme.good
        : score >= 60
            ? AppTheme.warning
            : AppTheme.danger;
    final label = score >= 80
        ? 'Excelente'
        : score >= 60
            ? 'Bueno'
            : 'Necesita atención';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          // Circular score
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(80, 80),
                  painter: _ArcPainter(
                    progress: score / 100,
                    color: color,
                    trackColor: AppTheme.border,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      score.toStringAsFixed(0),
                      style: GoogleFonts.bricolageGrotesque(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        color: color,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Text(
                      '/100',
                      style: TextStyle(
                          fontSize: 10, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Salud del grupo',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: GoogleFonts.bricolageGrotesque(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: color,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: score / 100,
                    minHeight: 6,
                    backgroundColor: AppTheme.border,
                    valueColor: AlwaysStoppedAnimation(color),
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

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  const _ArcPainter(
      {required this.progress,
      required this.color,
      required this.trackColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 6;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..color = trackColor;
    canvas.drawCircle(center, radius, trackPaint);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.color != color;
}

// â”€â”€ Mini Stat â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.bricolageGrotesque(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: AppTheme.text,
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

// â”€â”€ Alert Banner â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _AlertBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  const _AlertBanner(
      {required this.icon,
      required this.color,
      required this.label,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            if (onTap != null)
              Icon(Icons.arrow_forward_ios_rounded, size: 12, color: color),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Action Tile â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Solicitudes Sheet â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
          // Handle
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
                      // Reject
                      GestureDetector(
                        onTap: () => _responder(context, ref, s, false),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.close_rounded,
                              size: 18, color: AppTheme.danger),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Approve
                      GestureDetector(
                        onTap: () => _responder(context, ref, s, true),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.good.withValues(alpha: 0.1),
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
              style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
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
        content: Text(aprobar ? 'Solicitud aprobada ✓' : 'Solicitud rechazada'),
        backgroundColor: aprobar ? AppTheme.good : AppTheme.danger,
      ));
    }
  }
}

// â”€â”€ Miembro Rol Tile â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
                  style:
                      const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          // Role pill
          GestureDetector(
            onTap: () => _showRolPicker(context, ref, grupoNombre, gc),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.3)),
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
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Expulsar'),
          ),
        ],
      ),
    );
  }

  void _showRolPicker(BuildContext context, WidgetRef ref, String grupoNombre, Color gc) {
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
            ...RolMiembro.values.map((rol) {
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

// â”€â”€ Danger Zone â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
        border:
            Border.all(color: AppTheme.danger.withValues(alpha: 0.2)),
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

// â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
