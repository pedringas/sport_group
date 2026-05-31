import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../data/models/cuota_model.dart';
import '../../../data/models/pago_model.dart';
import '../../../data/models/campana_model.dart';
import '../../../data/models/enums.dart';
import '../../../providers/cuota_provider.dart';
import '../../../providers/campana_provider.dart';
import '../../../providers/grupo_provider.dart';

class TesoreroPanelPage extends ConsumerWidget {
  final String grupoId;
  const TesoreroPanelPage({super.key, required this.grupoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gc = ref.watch(grupoColorProvider(grupoId));
    final cuotas = ref.watch(cuotasProvider(grupoId)).valueOrNull ?? [];
    final pagos = ref.watch(pagosGrupoProvider(grupoId)).valueOrNull ?? [];
    final campanas =
        ref.watch(campanasProvider(grupoId)).valueOrNull ?? [];

    final pendientes = pagos
        .where((p) =>
            p.estado == EstadoPago.validando ||
            p.estado == EstadoPago.revision ||
            (p.comprobanteUrl != null &&
                p.estado != EstadoPago.aprobado))
        .toList();

    final totalRecaudado = pagos
        .where((p) => p.estado == EstadoPago.aprobado)
        .fold(0.0, (s, p) => s + p.montoEsperado);

    final campanasActivas =
        campanas.where((c) => c.estado == EstadoCampana.activa).length;

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
                        'Panel Tesorero',
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
                      child: _TresStat(
                        label: 'Por validar',
                        value: '${pendientes.length}',
                        icon: Icons.hourglass_top_rounded,
                        color: pendientes.isNotEmpty
                            ? const Color(0xFFF59E0B)
                            : AppTheme.textMuted,
                        highlight: pendientes.isNotEmpty,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _TresStat(
                        label: 'Recaudado',
                        value: '\$${_compact(totalRecaudado)}',
                        icon: Icons.savings_outlined,
                        color: AppTheme.good,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _TresStat(
                        label: 'Campañas',
                        value: '$campanasActivas activa${campanasActivas != 1 ? 's' : ''}',
                        icon: Icons.flag_rounded,
                        color: AppTheme.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // â”€â”€ Comprobantes pendientes
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Row(
                  children: [
                    SGEyebrow('Comprobantes pendientes'),
                    if (pendientes.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${pendientes.length}',
                            style: const TextStyle(
                                color: Color(0xFFF59E0B),
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
              sliver: pendientes.isEmpty
                  ? SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.check_circle_outline_rounded,
                                size: 40, color: AppTheme.good),
                            const SizedBox(height: 8),
                            Text('Todo al día',
                                style: GoogleFonts.bricolageGrotesque(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: AppTheme.text,
                                )),
                            const SizedBox(height: 4),
                            Text('No hay comprobantes por validar',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textMuted)),
                          ],
                        ),
                      ),
                    )
                  : SliverList.separated(
                      itemCount: pendientes.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (_, i) => _ComprobanteCard(
                        pago: pendientes[i],
                        grupoId: grupoId,
                      ),
                    ),
            ),

            // â”€â”€ Suscripciones
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Row(
                  children: [
                    SGEyebrow('Suscripciones'),
                    const Spacer(),
                    GestureDetector(
                      onTap: () =>
                          context.push('/group/$grupoId/cuotas'),
                      child: Text(
                        'Ver todas →',
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
              sliver: cuotas.isEmpty
                  ? SliverToBoxAdapter(
                      child: _EmptyAction(
                        label: 'No hay suscripciones',
                        btnLabel: 'Nueva suscripción',
                        gc: gc,
                        onTap: () =>
                            _showCrearCuota(context, ref),
                      ),
                    )
                  : SliverList.separated(
                      itemCount: cuotas.take(4).length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 6),
                      itemBuilder: (_, i) => _CuotaRow(
                        cuota: cuotas[i],
                        grupoId: grupoId,
                        gc: gc,
                      ),
                    ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: SGPillButton(
                  label: 'Nueva suscripción',
                  icon: Icons.add_rounded,
                  tone: SGTone.outline,
                  expand: true,
                  onPressed: () => _showCrearCuota(context, ref),
                ),
              ),
            ),

            // â”€â”€ Campañas
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Row(
                  children: [
                    SGEyebrow('Campañas'),
                    const Spacer(),
                    GestureDetector(
                      onTap: () =>
                          context.push('/group/$grupoId/campanas'),
                      child: Text(
                        'Ver todas →',
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
              sliver: campanas.isEmpty
                  ? SliverToBoxAdapter(
                      child: _EmptyAction(
                        label: 'No hay campañas',
                        btnLabel: 'Nueva campaña',
                        gc: gc,
                        onTap: () =>
                            _showCrearCampana(context, ref),
                      ),
                    )
                  : SliverList.separated(
                      itemCount: campanas.take(3).length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 6),
                      itemBuilder: (_, i) => _CampanaRow(
                        campana: campanas[i],
                        grupoId: grupoId,
                        gc: gc,
                      ),
                    ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: SGPillButton(
                  label: 'Nueva campaña',
                  icon: Icons.add_rounded,
                  tone: SGTone.outline,
                  expand: true,
                  onPressed: () => _showCrearCampana(context, ref),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  void _showCrearCuota(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CrearCuotaSheet(grupoId: grupoId),
    );
  }

  void _showCrearCampana(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CrearCampanaSheet(grupoId: grupoId),
    );
  }

  static String _compact(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}

// â”€â”€ Tres Stat â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _TresStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool highlight;

  const _TresStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.bricolageGrotesque(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: highlight ? color : AppTheme.text,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

// â”€â”€ Comprobante Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ComprobanteCard extends ConsumerWidget {
  final PagoModel pago;
  final String grupoId;
  const _ComprobanteCard({required this.pago, required this.grupoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = switch (pago.estado) {
      EstadoPago.validando => const Color(0xFFF59E0B),
      EstadoPago.revision => Colors.blue,
      EstadoPago.aprobado => AppTheme.good,
      EstadoPago.pendiente => AppTheme.textMuted,
    };
    final estadoLabel = switch (pago.estado) {
      EstadoPago.validando => 'Validando',
      EstadoPago.revision => 'En revisión',
      EstadoPago.aprobado => 'Aprobado',
      EstadoPago.pendiente => 'Pendiente',
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SGAvatar(name: pago.usuarioNombre, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pago.usuarioNombre,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(
                      '\$${pago.montoEsperado.toStringAsFixed(0)} · ${DateFormat('dd/MM/yyyy').format(pago.createdAt)}',
                      style: TextStyle(
                          color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(estadoLabel,
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),

          // OCR result
          if (pago.montoDetectado != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: pago.montosCoinciden
                    ? AppTheme.good.withValues(alpha: 0.06)
                    : AppTheme.danger.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: pago.montosCoinciden
                        ? AppTheme.good.withValues(alpha: 0.2)
                        : AppTheme.danger.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    pago.montosCoinciden
                        ? Icons.check_circle_outline
                        : Icons.warning_amber_outlined,
                    size: 14,
                    color: pago.montosCoinciden
                        ? AppTheme.good
                        : AppTheme.danger,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'OCR detectó \$${pago.montoDetectado!.toStringAsFixed(0)}'
                      '${pago.ocrConfianza != null ? ' (${(pago.ocrConfianza! * 100).toStringAsFixed(0)}% confianza)' : ''}',
                      style: TextStyle(
                          fontSize: 11,
                          color: pago.montosCoinciden
                              ? AppTheme.good
                              : AppTheme.danger,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              if (pago.comprobanteUrl != null)
                Expanded(
                  child: _ComprobanteBtn(
                    icon: Icons.image_outlined,
                    label: 'Ver',
                    onTap: () async {
                      final uri = Uri.parse(pago.comprobanteUrl!);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ),
              if (pago.comprobanteUrl != null) const SizedBox(width: 8),
              if (pago.estado == EstadoPago.validando ||
                  pago.estado == EstadoPago.revision) ...[
                Expanded(
                  child: _ComprobanteBtn(
                    icon: Icons.close_rounded,
                    label: 'Rechazar',
                    color: AppTheme.danger,
                    onTap: () => ref
                        .read(cuotaRepositoryProvider)
                        .updatePagoEstado(
                            pago.id, EstadoPago.pendiente),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ComprobanteBtn(
                    icon: Icons.check_rounded,
                    label: 'Confirmar',
                    color: AppTheme.good,
                    onTap: () => ref
                        .read(cuotaRepositoryProvider)
                        .updatePagoEstado(
                            pago.id, EstadoPago.aprobado),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ComprobanteBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _ComprobanteBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: c),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: c)),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Cuota Row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _CuotaRow extends StatelessWidget {
  final CuotaModel cuota;
  final String grupoId;
  final Color gc;
  const _CuotaRow({required this.cuota, required this.grupoId, required this.gc});

  @override
  Widget build(BuildContext context) {
    final overdue =
        cuota.vencimiento.isBefore(DateTime.now()) && cuota.activa;
    return GestureDetector(
      onTap: () => context.push('/group/$grupoId/cuota/${cuota.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: overdue
                  ? AppTheme.danger.withValues(alpha: 0.3)
                  : AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: gc.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.payments_outlined,
                  size: 18, color: gc),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cuota.titulo,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(
                    'Vence ${DateFormat('dd/MM/yy').format(cuota.vencimiento)}',
                    style: TextStyle(
                        color: overdue
                            ? AppTheme.danger
                            : AppTheme.textMuted,
                        fontSize: 11,
                        fontWeight: overdue ? FontWeight.w600 : null),
                  ),
                ],
              ),
            ),
            Text(
              '\$${cuota.monto.toStringAsFixed(0)}',
              style: GoogleFonts.bricolageGrotesque(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppTheme.text,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                size: 16, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Campaña Row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _CampanaRow extends StatelessWidget {
  final CampanaModel campana;
  final String grupoId;
  final Color gc;
  const _CampanaRow({required this.campana, required this.grupoId, required this.gc});

  @override
  Widget build(BuildContext context) {
    final progress = campana.objetivo > 0
        ? (campana.montoActual / campana.objetivo).clamp(0.0, 1.0)
        : 0.0;
    return GestureDetector(
      onTap: () =>
          context.push('/group/$grupoId/campana/${campana.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(campana.titulo,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: campana.estado == EstadoCampana.activa
                        ? AppTheme.good.withValues(alpha: 0.1)
                        : AppTheme.border,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(campana.estado.label,
                      style: TextStyle(
                          color: campana.estado == EstadoCampana.activa
                              ? AppTheme.good
                              : AppTheme.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: AppTheme.border,
                valueColor: AlwaysStoppedAnimation(gc),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '\$${campana.montoActual.toStringAsFixed(0)} / \$${campana.objetivo.toStringAsFixed(0)}',
              style: TextStyle(
                  fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Empty Action â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _EmptyAction extends StatelessWidget {
  final String label;
  final String btnLabel;
  final Color gc;
  final VoidCallback onTap;
  const _EmptyAction(
      {required this.label,
      required this.btnLabel,
      required this.gc,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style:
                    TextStyle(fontSize: 13, color: AppTheme.textMuted)),
          ),
          GestureDetector(
            onTap: onTap,
            child: Text(btnLabel,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: gc)),
          ),
        ],
      ),
    );
  }
}

// â”€â”€ Crear Cuota Sheet â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _CrearCuotaSheet extends ConsumerStatefulWidget {
  final String grupoId;
  const _CrearCuotaSheet({required this.grupoId});

  @override
  ConsumerState<_CrearCuotaSheet> createState() => _CrearCuotaSheetState();
}

class _CrearCuotaSheetState extends ConsumerState<_CrearCuotaSheet> {
  final _tituloCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime _vencimiento = DateTime.now().add(const Duration(days: 30));
  bool _esRecurrente = false;
  FrecuenciaCuota _frecuencia = FrecuenciaCuota.mensual;
  int _totalCuotas = 12;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _montoCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _vencimiento,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _vencimiento = picked);
  }

  Future<void> _guardar() async {
    if (_tituloCtrl.text.isEmpty) return;
    final monto =
        double.tryParse(_montoCtrl.text.replaceAll(',', '.')) ?? 0;
    if (monto <= 0) return;
    try {
      if (_esRecurrente) {
        await ref.read(crearCuotaProvider.notifier).crearSerie(
              grupoId: widget.grupoId,
              titulo: _tituloCtrl.text.trim(),
              descripcion: _descCtrl.text.trim().isEmpty
                  ? null
                  : _descCtrl.text.trim(),
              monto: monto,
              primerVencimiento: _vencimiento,
              frecuencia: _frecuencia,
              totalCuotas: _totalCuotas,
            );
      } else {
        await ref.read(crearCuotaProvider.notifier).crear(
              grupoId: widget.grupoId,
              titulo: _tituloCtrl.text.trim(),
              descripcion: _descCtrl.text.trim().isEmpty
                  ? null
                  : _descCtrl.text.trim(),
              monto: monto,
              vencimiento: _vencimiento,
            );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gc = ref.watch(grupoColorProvider(widget.grupoId));
    final isLoading = ref.watch(crearCuotaProvider).isLoading;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20, right: 20, top: 8,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Center(
              child: Text('Nueva suscripción',
                  style: GoogleFonts.bricolageGrotesque(
                    fontWeight: FontWeight.w700, fontSize: 18, color: AppTheme.text)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tituloCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nombre de la suscripción',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _montoCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Monto', prefixText: '\$ ',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Vencimiento',
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      child: Text(DateFormat('dd/MM/yyyy').format(_vencimiento),
                          style: const TextStyle(fontSize: 14)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Suscripción recurrente', style: TextStyle(fontSize: 14)),
              value: _esRecurrente,
              activeThumbColor: gc,
              onChanged: (v) => setState(() => _esRecurrente = v),
            ),
            if (_esRecurrente) ...[
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<FrecuenciaCuota>(
                      value: _frecuencia,
                      decoration: const InputDecoration(labelText: 'Frecuencia'),
                      items: FrecuenciaCuota.values
                          .map((f) => DropdownMenuItem(value: f, child: Text(f.label)))
                          .toList(),
                      onChanged: (v) => setState(() => _frecuencia = v ?? _frecuencia),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Cantidad', hintText: '12'),
                      onChanged: (v) => setState(() => _totalCuotas = int.tryParse(v) ?? 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Se crearán $_totalCuotas suscripciones ${_frecuencia.label.toLowerCase()}s',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),
            SGPillButton(
              label: _esRecurrente
                  ? 'Crear serie de suscripciones'
                  : 'Crear suscripción',
              expand: true,
              onPressed: isLoading ? null : _guardar,
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Crear Campaña Sheet â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _CrearCampanaSheet extends ConsumerStatefulWidget {
  final String grupoId;
  const _CrearCampanaSheet({required this.grupoId});

  @override
  ConsumerState<_CrearCampanaSheet> createState() =>
      _CrearCampanaSheetState();
}

class _CrearCampanaSheetState extends ConsumerState<_CrearCampanaSheet> {
  final _tituloCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _metaCtrl = TextEditingController();
  DateTime? _fechaFin;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descCtrl.dispose();
    _metaCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _fechaFin = picked);
  }

  Future<void> _guardar() async {
    if (_tituloCtrl.text.isEmpty) return;
    final meta = double.tryParse(_metaCtrl.text.replaceAll(',', '.')) ?? 0;
    if (meta <= 0) return;
    try {
      await ref.read(crearCampanaProvider.notifier).crear(
            grupoId: widget.grupoId,
            titulo: _tituloCtrl.text.trim(),
            descripcion: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
            objetivo: meta,
            fechaLimite: _fechaFin,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(crearCampanaProvider).isLoading;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20, right: 20, top: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text('Nueva campaña',
              style: GoogleFonts.bricolageGrotesque(
                  fontWeight: FontWeight.w700, fontSize: 18, color: AppTheme.text)),
          const SizedBox(height: 16),
          TextField(
            controller: _tituloCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nombre de la campaña',
              prefixIcon: Icon(Icons.savings_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Descripción', alignLabelWithHint: true,
              prefixIcon: Icon(Icons.article_outlined),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _metaCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Meta', prefixText: '\$ ',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fecha límite',
                      prefixIcon: Icon(Icons.event_outlined),
                    ),
                    child: Text(
                      _fechaFin != null
                          ? DateFormat('dd/MM/yyyy').format(_fechaFin!)
                          : 'Sin límite',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SGPillButton(
            label: 'Crear campaña',
            expand: true,
            onPressed: isLoading ? null : _guardar,
          ),
        ],
      ),
    );
  }
}
