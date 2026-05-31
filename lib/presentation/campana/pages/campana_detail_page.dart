import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/campana_model.dart';
import '../../../data/models/enums.dart';
import '../../../providers/campana_provider.dart';
import '../../../providers/grupo_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/theme/sg_widgets.dart';
import 'aporte_comprobante_page.dart';

class CampanaDetailPage extends ConsumerWidget {
  final String grupoId;
  final String campanaId;
  const CampanaDetailPage(
      {super.key, required this.grupoId, required this.campanaId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campanaAsync =
        ref.watch(campanaProvider((grupoId: grupoId, campanaId: campanaId)));
    final aportesAsync =
        ref.watch(aportesProvider((grupoId: grupoId, campanaId: campanaId)));
    final miembroAsync = ref.watch(miembroActualProvider(grupoId));
    final puedeGestionar =
        miembroAsync.valueOrNull?.rol.puedeGestionarCampanas ?? false;
    final gc = ref.watch(grupoColorProvider(grupoId));

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: campanaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (campana) {
          if (campana == null) {
            return const Center(child: Text('Campaña no encontrada'));
          }
          final activa = campana.estado == EstadoCampana.activa;

          // ── Mis aportes (excluir rechazados) ──────────────────────────
          final currentUid =
              ref.watch(authStateProvider).valueOrNull?.uid ?? '';
          final misAportes = aportesAsync.valueOrNull
                  ?.where((a) =>
                      a.usuarioUid == currentUid &&
                      a.estado != EstadoAporte.rechazado)
                  .toList() ??
              [];
          final misAportesTotal =
              misAportes.fold(0.0, (s, a) => s + a.monto);
          final yaAporto = misAportes.isNotEmpty;

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // â”€â”€ TopBar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  SliverToBoxAdapter(
                    child: SafeArea(
                      bottom: false,
                      child: _TopBar(
                        puedeGestionar: puedeGestionar,
                        activa: activa,
                        grupoId: grupoId,
                        onAction: (action) =>
                            _handleAction(context, ref, campana, action),
                      ),
                    ),
                  ),

                  // â”€â”€ Hero card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: _HeroCard(campana: campana, gc: gc),
                    ),
                  ),

                  // â”€â”€ Tu contribución â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  if (yaAporto)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        child: _MiContribucionCard(
                          misAportes: misAportes,
                          total: misAportesTotal,
                          gc: gc,
                        ),
                      ),
                    ),

                  // â”€â”€ Quick aportar button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  if (activa)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        child: SGPillButton(
                          label: yaAporto ? 'Aportar nuevamente' : 'Quiero aportar',
                          icon: Icons.favorite_rounded,
                          onPressed: () =>
                              _showAportarSheet(context, ref, campana),
                          expand: true,
                        ),
                      ),
                    ),

                  // â”€â”€ Description â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  if (campana.descripcion != null) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                        child: SGEyebrow('DE QUÉ SE TRATA'),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                        child: Text(
                          campana.descripcion!,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.55,
                            color: AppTheme.text,
                          ),
                        ),
                      ),
                    ),
                  ],

                  // â”€â”€ Creator â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          children: [
                            SGAvatar(
                              name: 'Campaña',
                              size: 32,
                              background: gc,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Campaña creada',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          color: AppTheme.text,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'el ${DateFormat('dd/MM/yyyy').format(campana.createdAt)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (campana.fechaLimite != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceAlt,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Límite: ${DateFormat('dd/MM').format(campana.fechaLimite!)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // â”€â”€ Quick amount presets â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  if (activa) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                        child: SGEyebrow('APORTES RÁPIDOS'),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _QuickAmounts(
                          gc: gc,
                          onSelect: (amount) =>
                              _showAportarSheet(context, ref, campana,
                                  initialAmount: amount),
                        ),
                      ),
                    ),
                  ],

                  // â”€â”€ Tesorero/Admin: pending aportes panel â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  if (puedeGestionar)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                        child: _AportesPendientesPanel(
                          grupoId: grupoId,
                          campanaId: campanaId,
                        ),
                      ),
                    ),

                  // â”€â”€ Aportes list â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                      child: SGEyebrow('ÚLTIMOS APORTES'),
                    ),
                  ),

                  aportesAsync.when(
                    loading: () => const SliverToBoxAdapter(
                        child: Center(child: CircularProgressIndicator())),
                    error: (e, _) => SliverToBoxAdapter(
                        child: Center(child: Text('Error: $e'))),
                    data: (aportes) {
                      if (aportes.isEmpty) {
                        return SliverToBoxAdapter(
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16),
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: const Center(
                              child: Text(
                                'Todavía no hay aportes\nSé el primero en contribuir 🙌',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      return SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border:
                                Border.all(color: AppTheme.border),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Column(
                            children: List.generate(
                              aportes.length,
                              (i) => _AporteRow(
                                aporte: aportes[i],
                                hasBorder: i < aportes.length - 1,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),

              // â”€â”€ Sticky bottom bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              if (activa)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      border: const Border(
                          top: BorderSide(color: AppTheme.border)),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      12 +
                          MediaQuery.of(context)
                              .padding
                              .bottom,
                    ),
                    child: Row(
                      children: [
                        // Share button
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: const Icon(Icons.ios_share_rounded,
                              size: 22, color: AppTheme.text),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SGPillButton(
                            label: yaAporto
                                ? 'Aportar nuevamente'
                                : 'Aportar',
                            icon: Icons.favorite_rounded,
                            onPressed: () => _showAportarSheet(
                                context, ref, campana),
                            expand: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _handleAction(
      BuildContext context, WidgetRef ref, CampanaModel c, _CampanaAction a) {
    final estado = a == _CampanaAction.completar
        ? EstadoCampana.completada
        : EstadoCampana.cancelada;
    final msg = a == _CampanaAction.completar
        ? '¿Marcar esta campaña como completada?'
        : '¿Cancelar la campaña?';
    final label =
        a == _CampanaAction.completar ? 'Completar' : 'Cancelar campaña';

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: Text(msg),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('No')),
          ElevatedButton(
            style: a == _CampanaAction.cancelar
                ? ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.danger,
                    foregroundColor: Colors.white,
                  )
                : null,
            onPressed: () async {
              Navigator.pop(dlgCtx);
              try {
                await ref
                    .read(estadoCampanaProvider.notifier)
                    .cambiar(grupoId, campanaId, estado);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        a == _CampanaAction.completar
                            ? 'Campaña marcada como completada'
                            : 'Campaña cancelada',
                      ),
                      backgroundColor:
                          a == _CampanaAction.completar
                              ? AppTheme.good
                              : AppTheme.textMuted,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: AppTheme.danger,
                    ),
                  );
                }
              }
            },
            child: Text(label),
          ),
        ],
      ),
    );
  }

  void _showAportarSheet(BuildContext context, WidgetRef ref, CampanaModel campana,
      {double? initialAmount}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AportarSheet(
        grupoId: grupoId,
        campana: campana,
        initialAmount: initialAmount,
      ),
    );
  }
}

enum _CampanaAction { completar, cancelar }

// â”€â”€ TopBar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _TopBar extends StatelessWidget {
  final bool puedeGestionar;
  final bool activa;
  final void Function(_CampanaAction) onAction;
  final String grupoId;

  const _TopBar({
    required this.puedeGestionar,
    required this.activa,
    required this.onAction,
    required this.grupoId,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text(
              'Campañas',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMuted,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.ios_share_rounded, size: 20),
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(
                    text:
                        'https://sports-groups-app.web.app/group/$grupoId'),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Link del grupo copiado ✓')),
                );
              }
            },
          ),
          if (puedeGestionar && activa)
            PopupMenuButton<_CampanaAction>(
              icon: const Icon(Icons.more_horiz_rounded, size: 22),
              onSelected: onAction,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _CampanaAction.completar,
                  child: ListTile(
                    leading: Icon(Icons.check_circle_outline,
                        color: AppTheme.good),
                    title: Text('Marcar como completada'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: _CampanaAction.cancelar,
                  child: ListTile(
                    leading: Icon(Icons.cancel_outlined,
                        color: AppTheme.danger),
                    title: Text('Cancelar campaña'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// â”€â”€ Hero card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _HeroCard extends StatelessWidget {
  final CampanaModel campana;
  final Color gc;
  const _HeroCard({required this.campana, required this.gc});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'es_AR');
    final pct = (campana.porcentaje * 100).round();
    final activa = campana.estado == EstadoCampana.activa;

    Color heroBg;
    if (campana.completada) {
      heroBg = AppTheme.good;
    } else if (campana.estado == EstadoCampana.cancelada) {
      heroBg = AppTheme.textMuted;
    } else {
      heroBg = gc; // active campaign uses group color
    }

    return Container(
      decoration: BoxDecoration(
        color: heroBg,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(22),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          // decorative circles
          Positioned(
            right: -50,
            top: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            left: -30,
            bottom: -60,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),

          // Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status badge
              Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded,
                      size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    activa
                        ? 'ACTIVA${campana.fechaLimite != null ? ' · ${campana.fechaLimite!.difference(DateTime.now()).inDays} DÍAS' : ''}'
                        : campana.estado.name.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                campana.titulo,
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  height: 1.15,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 18),

              // Ring + amounts
              Row(
                children: [
                  _RingProgress(pct: pct, size: 86),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '\$ ${fmt.format(campana.montoActual)}',
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'de \$ ${fmt.format(campana.objetivo)} objetivo',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (!campana.completada)
                          Text(
                            'Faltan \$ ${fmt.format(campana.faltante)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// â”€â”€ Ring progress painter â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _RingProgress extends StatelessWidget {
  final int pct;
  final double size;
  const _RingProgress({required this.pct, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(pct / 100),
        child: Center(
          child: Text(
            '$pct%',
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  const _RingPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;

    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, trackPaint);

    final progressPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * value.clamp(0, 1),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value;
}

// â”€â”€ Quick amounts â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _QuickAmounts extends StatelessWidget {
  final void Function(double) onSelect;
  final Color gc;
  static const _presets = [500.0, 1000.0, 2000.0];

  const _QuickAmounts({required this.onSelect, required this.gc});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'es_AR');
    return Column(
      children: [
        Row(
          children: _presets.map((amount) {
            return Expanded(
              child: GestureDetector(
                onTap: () => onSelect(amount),
                child: Container(
                  margin: EdgeInsets.only(
                    right: amount != _presets.last ? 8 : 0,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Center(
                    child: Text(
                      '\$ ${fmt.format(amount)}',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.text,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => onSelect(0),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Center(
              child: Text(
                '+ Otro monto personalizado',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: gc,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// â”€â”€ Aporte row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _AporteRow extends StatelessWidget {
  final AporteModel aporte;
  final bool hasBorder;
  const _AporteRow({required this.aporte, required this.hasBorder});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'es_AR');
    final when = _relativeTime(aporte.createdAt);

    return Container(
      decoration: hasBorder
          ? const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: AppTheme.border)))
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          SGAvatar(
            name: aporte.usuarioNombre,
            size: 32,
            background: AppTheme.good,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  aporte.usuarioNombre,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.text,
                  ),
                ),
                if (aporte.mensaje != null)
                  Text(
                    aporte.mensaje!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$ ${fmt.format(aporte.monto)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.good,
                ),
              ),
              Text(
                when,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'hace ${diff.inHours}h';
    if (diff.inDays == 1) return 'ayer';
    if (diff.inDays < 7) return 'hace ${diff.inDays}d';
    return DateFormat('dd/MM').format(dt);
  }
}

// â”€â”€ Mi contribución card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _MiContribucionCard extends StatelessWidget {
  final List<AporteModel> misAportes;
  final double total;
  final Color gc;
  const _MiContribucionCard(
      {required this.misAportes, required this.total, required this.gc});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'es_AR');
    final pendientes = misAportes
        .where((a) =>
            a.estado == EstadoAporte.pendiente ||
            a.estado == EstadoAporte.validando)
        .length;
    final aprobados =
        misAportes.where((a) => a.estado == EstadoAporte.aprobado).length;

    final statusParts = <String>[];
    if (aprobados > 0) {
      statusParts.add('$aprobados confirmado${aprobados > 1 ? 's' : ''}');
    }
    if (pendientes > 0) {
      statusParts.add('$pendientes pendiente${pendientes > 1 ? 's' : ''}');
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.goodSoftDyn(context),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppTheme.good.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.good.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite_rounded,
                color: AppTheme.good, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tu contribución',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: AppTheme.good,
                  ),
                ),
                Text(
                  '\$ ${fmt.format(total)}',
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: AppTheme.text,
                  ),
                ),
                if (statusParts.isNotEmpty)
                  Text(
                    statusParts.join(' · '),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          if (misAportes.length > 1)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.good.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '×${misAportes.length} aportes',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.good,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// â”€â”€ Aportar sheet â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

enum _MetodoAporte { efectivo, transferencia }

class _AportarSheet extends ConsumerStatefulWidget {
  final String grupoId;
  final CampanaModel campana;
  final double? initialAmount;
  const _AportarSheet(
      {required this.grupoId, required this.campana, this.initialAmount});

  @override
  ConsumerState<_AportarSheet> createState() => _AportarSheetState();
}

class _AportarSheetState extends ConsumerState<_AportarSheet> {
  final _montoCtrl = TextEditingController();
  final _mensajeCtrl = TextEditingController();
  _MetodoAporte _metodo = _MetodoAporte.efectivo;

  static const _quickAmounts = [500.0, 1000.0, 2000.0, 5000.0];

  @override
  void initState() {
    super.initState();
    if (widget.initialAmount != null && widget.initialAmount! > 0) {
      _montoCtrl.text = widget.initialAmount!.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    _mensajeCtrl.dispose();
    super.dispose();
  }

  Future<void> _aportar() async {
    final monto = double.tryParse(_montoCtrl.text.replaceAll(',', '.'));
    if (monto == null || monto <= 0) return;
    final mensaje =
        _mensajeCtrl.text.trim().isEmpty ? null : _mensajeCtrl.text.trim();

    if (_metodo == _MetodoAporte.transferencia) {
      // Navigate to comprobante upload page
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ProviderScope(
          parent: ProviderScope.containerOf(context),
          child: AporteComprobantePage(
            grupoId: widget.grupoId,
            campanaId: widget.campana.id,
            campanaTitle: widget.campana.titulo,
            monto: monto,
            mensaje: mensaje,
          ),
        ),
      ));
      return;
    }

    // Efectivo ”” register as pending, tesorero confirms
    try {
      final user = ref.read(authStateProvider).valueOrNull;
      if (user == null) return;
      final perfil = await ref.read(authRepositoryProvider).getUser(user.uid);
      final nombre = perfil?.nombreCompleto ?? user.displayName ?? 'Usuario';

      await ref.read(campanaRepositoryProvider).addAportePendiente(
            grupoId: widget.grupoId,
            campanaId: widget.campana.id,
            usuarioUid: user.uid,
            usuarioNombre: nombre,
            monto: monto,
            mensaje: mensaje,
            metodo: 'efectivo',
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aporte registrado. El tesorero lo confirmará 🙌'),
            backgroundColor: AppTheme.good,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'es_AR');
    final faltante = widget.campana.faltante;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                const Icon(Icons.favorite_rounded,
                    color: AppTheme.good, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contribuir a la campaña',
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.text,
                        ),
                      ),
                      Text(
                        widget.campana.titulo,
                        style: const TextStyle(
                            color: AppTheme.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Faltan \$ ${fmt.format(faltante)} para la meta',
              style: const TextStyle(
                color: AppTheme.good,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),

            // â”€â”€ Method selector
            Text(
              'Método de pago',
              style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _MetodoPill(
                  label: 'Efectivo',
                  icon: Icons.payments_rounded,
                  selected: _metodo == _MetodoAporte.efectivo,
                  onTap: () =>
                      setState(() => _metodo = _MetodoAporte.efectivo),
                ),
                const SizedBox(width: 8),
                _MetodoPill(
                  label: 'Transferencia',
                  icon: Icons.account_balance_rounded,
                  selected: _metodo == _MetodoAporte.transferencia,
                  onTap: () =>
                      setState(() => _metodo = _MetodoAporte.transferencia),
                ),
              ],
            ),

            // Transferencia hint
            if (_metodo == _MetodoAporte.transferencia) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        size: 14, color: AppTheme.accentInk),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'En el siguiente paso subís el comprobante. Lo verificamos automáticamente.',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.accentInk,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Quick amounts
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickAmounts.map((amount) {
                final selected =
                    _montoCtrl.text == amount.toStringAsFixed(0);
                return GestureDetector(
                  onTap: () => setState(
                      () => _montoCtrl.text = amount.toStringAsFixed(0)),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.good : AppTheme.surfaceAlt,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color:
                              selected ? AppTheme.good : AppTheme.border),
                    ),
                    child: Text(
                      '\$ ${fmt.format(amount)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color:
                            selected ? Colors.white : AppTheme.textMuted,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _montoCtrl,
              decoration: const InputDecoration(
                labelText: 'Monto de tu aporte',
                prefixText: '\$ ',
                prefixIcon: Icon(Icons.attach_money_rounded),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _mensajeCtrl,
              decoration: const InputDecoration(
                labelText: 'Mensaje (opcional)',
                hintText: '¡Vamos equipo!',
                prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
              ),
            ),
            const SizedBox(height: 24),

            SGPillButton(
              label: _metodo == _MetodoAporte.transferencia
                  ? 'Siguiente ”” subir comprobante'
                  : 'Registrar aporte en efectivo',
              icon: _metodo == _MetodoAporte.transferencia
                  ? Icons.arrow_forward_rounded
                  : Icons.payments_rounded,
              onPressed: _aportar,
              expand: true,
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Método pill â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _MetodoPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _MetodoPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppTheme.good : AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: selected ? AppTheme.good : AppTheme.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: selected ? Colors.white : AppTheme.textMuted),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// â”€â”€ Aportes Pendientes Panel (Tesorero/Admin) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _AportesPendientesPanel extends ConsumerWidget {
  final String grupoId;
  final String campanaId;
  const _AportesPendientesPanel(
      {required this.grupoId, required this.campanaId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aportesAsync =
        ref.watch(aportesProvider((grupoId: grupoId, campanaId: campanaId)));

    return aportesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (aportes) {
        final pendientes = aportes
            .where((a) =>
                a.estado == EstadoAporte.pendiente ||
                a.estado == EstadoAporte.validando)
            .toList();

        if (pendientes.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Aportes pendientes de confirmación',
                  style: GoogleFonts.bricolageGrotesque(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${pendientes.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...pendientes.map((a) => _AportePendienteRow(
                  aporte: a,
                  grupoId: grupoId,
                  campanaId: campanaId,
                )),
          ],
        );
      },
    );
  }
}

class _AportePendienteRow extends ConsumerStatefulWidget {
  final AporteModel aporte;
  final String grupoId;
  final String campanaId;
  const _AportePendienteRow(
      {required this.aporte, required this.grupoId, required this.campanaId});

  @override
  ConsumerState<_AportePendienteRow> createState() =>
      _AportePendienteRowState();
}

class _AportePendienteRowState extends ConsumerState<_AportePendienteRow> {
  bool _loading = false;

  Future<void> _accion(bool aprobar) async {
    setState(() => _loading = true);
    try {
      if (aprobar) {
        await ref.read(campanaRepositoryProvider).aprobarAporte(
              grupoId: widget.grupoId,
              campanaId: widget.campanaId,
              aporteId: widget.aporte.id,
              miembroUid: widget.aporte.usuarioUid,
              monto: widget.aporte.monto,
            );
      } else {
        await ref.read(campanaRepositoryProvider).rechazarAporte(
              grupoId: widget.grupoId,
              campanaId: widget.campanaId,
              aporteId: widget.aporte.id,
              miembroUid: widget.aporte.usuarioUid,
              monto: widget.aporte.monto,
            );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(aprobar ? 'Aporte aprobado ✓' : 'Aporte rechazado'),
            backgroundColor: aprobar ? AppTheme.good : AppTheme.textMuted,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gc = ref.watch(grupoColorProvider(widget.grupoId));
    final a = widget.aporte;
    final fmt = NumberFormat('#,##0', 'es_AR');
    final isTransferencia = a.metodo == 'transferencia';
    final isValidando = a.estado == EstadoAporte.validando;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.goodSoft,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    (a.usuarioNombre.isNotEmpty ? a.usuarioNombre[0] : '?')
                        .toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppTheme.good,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.usuarioNombre,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.text,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: isTransferencia
                                ? AppTheme.accentSoft
                                : gc.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isTransferencia ? 'Transferencia' : 'Efectivo',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isTransferencia
                                  ? AppTheme.accentInk
                                  : gc,
                            ),
                          ),
                        ),
                        if (isValidando) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color:
                                  Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Verificando...',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                '\$${fmt.format(a.monto.toInt())}',
                style: GoogleFonts.bricolageGrotesque(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppTheme.text,
                ),
              ),
            ],
          ),

          if (a.mensaje != null && a.mensaje!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                a.mensaje!,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textMuted),
              ),
            ),
          ],

          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.close_rounded, size: 15),
                    label: const Text('Rechazar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.danger,
                      side: BorderSide(
                          color: AppTheme.danger.withValues(alpha: 0.4)),
                      minimumSize: const Size(0, 40),
                      textStyle: GoogleFonts.dmSans(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () => _accion(false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check_rounded, size: 15),
                    label: const Text('Aprobar'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.good,
                      minimumSize: const Size(0, 40),
                      textStyle: GoogleFonts.dmSans(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () => _accion(true),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
