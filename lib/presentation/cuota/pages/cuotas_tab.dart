import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../data/models/cuota_model.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/pago_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/cuota_provider.dart';
import '../../../providers/grupo_provider.dart';

class CuotasTab extends ConsumerStatefulWidget {
  final String grupoId;
  const CuotasTab({super.key, required this.grupoId});

  @override
  ConsumerState<CuotasTab> createState() => _CuotasTabState();
}

enum _Filter { todos, activas, vencidas, completadas }

class _CuotasTabState extends ConsumerState<CuotasTab> {
  _Filter _filter = _Filter.todos;

  @override
  Widget build(BuildContext context) {
    final cuotasAsync = ref.watch(cuotasProvider(widget.grupoId));
    final pagosAsync = ref.watch(pagosGrupoProvider(widget.grupoId));
    final miembroAsync = ref.watch(miembroActualProvider(widget.grupoId));
    final gc = ref.watch(grupoColorProvider(widget.grupoId));

    final rol = miembroAsync.valueOrNull?.rol;
    final canAdd = rol?.puedeGestionarCuotas ?? false;

    // Fetch user's own pagos separately — avoids the Firestore 10-get() limit
    // on security rule evaluation that breaks `pagosGrupoProvider` for members.
    final uidEarly = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
    final misPagosAsync = ref.watch(misPagosGrupoProvider(
        (grupoId: widget.grupoId, uid: uidEarly)));

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: cuotasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (cuotas) {
          // All group pagos — for group-wide stats (progress bar).
          // May return empty for members due to Firestore get() limit — that's OK.
          final pagos = pagosAsync.valueOrNull ?? [];
          // User's own pagos — reliable, no get() in security rule evaluation.
          final misPagos = misPagosAsync.valueOrNull ?? [];
          final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
          final now = DateTime.now();

          // A cuota is "done" from the member's perspective once they've
          // submitted any payment (pendiente, validando, revision, aprobado).
          bool isPagadoPorMi(CuotaModel c) =>
              misPagos.any((p) => p.cuotaId == c.id);

          // Returns the user's latest pago state for a cuota (null if none).
          EstadoPago? miEstado(CuotaModel c) {
            final mine =
                misPagos.where((p) => p.cuotaId == c.id).toList();
            if (mine.isEmpty) return null;
            if (mine.any((p) => p.estado == EstadoPago.aprobado)) {
              return EstadoPago.aprobado;
            }
            return mine.last.estado;
          }

          // My payments this month (approved) — use misPagos for accuracy

          // Group-level stats (for progress bar)
          final aprobados =
              pagos.where((p) => p.estado == EstadoPago.aprobado).length;
          final pendientes =
              pagos.where((p) => p.estado == EstadoPago.pendiente).length;
          final rechazados =
              pagos.where((p) => p.estado == EstadoPago.revision).length;

          // My payments this month (approved) — use misPagos (reliable)
          final misPagosMes = misPagos
              .where((p) =>
                  p.estado == EstadoPago.aprobado &&
                  p.createdAt.year == now.year &&
                  p.createdAt.month == now.month)
              .fold<double>(0, (sum, p) => sum + p.montoEsperado);

          // Filter cuotas based on current user's payment status
          final filtered = _filter == _Filter.todos
              ? cuotas
              : cuotas.where((c) {
                  return switch (_filter) {
                    _Filter.activas =>
                      !isPagadoPorMi(c) && c.activa && !c.vencimiento.isBefore(now),
                    _Filter.vencidas =>
                      !isPagadoPorMi(c) && c.activa && c.vencimiento.isBefore(now),
                    _Filter.completadas => isPagadoPorMi(c),
                    _Filter.todos => true,
                  };
                }).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              // â”€â”€ Hero stats card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.text,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MIS PAGOS ESTE MES',
                      style: GoogleFonts.dmSans(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '\$ ${_fmt(misPagosMes.toInt())}',
                      style: GoogleFonts.bricolageGrotesque(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 36,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${cuotas.length} ${cuotas.length == 1 ? 'cuota' : 'cuotas'} en el grupo',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 14),

                    // Progress bar (aprobados vs pendientes vs rechazados)
                    if (aprobados + pendientes + rechazados > 0) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: Row(children: [
                          if (aprobados > 0)
                            Expanded(
                              flex: aprobados,
                              child: const ColoredBox(
                                color: AppTheme.good,
                                child: SizedBox(height: 10),
                              ),
                            ),
                          if (pendientes > 0)
                            Expanded(
                              flex: pendientes,
                              child: const ColoredBox(
                                color: AppTheme.accent,
                                child: SizedBox(height: 10),
                              ),
                            ),
                          if (rechazados > 0)
                            Expanded(
                              flex: rechazados,
                              child: const ColoredBox(
                                color: AppTheme.danger,
                                child: SizedBox(height: 10),
                              ),
                            ),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: _Stat(
                            color: AppTheme.good,
                            label: 'Aprobados',
                            value: '$aprobados',
                          ),
                        ),
                        Expanded(
                          child: _Stat(
                            color: AppTheme.accent,
                            label: 'Pendientes',
                            value: '$pendientes',
                          ),
                        ),
                        Expanded(
                          child: _Stat(
                            color: AppTheme.danger,
                            label: 'Rechazados',
                            value: '$rechazados',
                          ),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // â”€â”€ Filter chips
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _FilterChip(
                      label: 'Todas · ${cuotas.length}',
                      tone: SGChipTone.primary,
                      selected: _filter == _Filter.todos,
                      onTap: () =>
                          setState(() => _filter = _Filter.todos),
                    ),
                    _FilterChip(
                      label: 'Activas',
                      tone: SGChipTone.good,
                      selected: _filter == _Filter.activas,
                      onTap: () =>
                          setState(() => _filter = _Filter.activas),
                    ),
                    _FilterChip(
                      label: 'Vencidas',
                      tone: SGChipTone.danger,
                      selected: _filter == _Filter.vencidas,
                      onTap: () =>
                          setState(() => _filter = _Filter.vencidas),
                    ),
                    _FilterChip(
                      label: 'Completadas',
                      tone: SGChipTone.neutral,
                      selected: _filter == _Filter.completadas,
                      onTap: () => setState(
                          () => _filter = _Filter.completadas),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // â”€â”€ Cuota rows (grouped by serieId)
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      cuotas.isEmpty
                          ? 'No hay cuotas todavía'
                          : 'Sin cuotas en este filtro',
                      style: const TextStyle(color: AppTheme.textMuted),
                    ),
                  ),
                )
              else
                ..._buildCuotaRows(
                    context, filtered, pagos, misPagos, uid, widget.grupoId),
            ],
          );
        },
      ),
      floatingActionButton: Builder(builder: (_) {
        if (canAdd) {
          return FloatingActionButton.extended(
            onPressed: () =>
                context.push('/group/${widget.grupoId}/cuotas/crear'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Emitir cuota'),
            backgroundColor: gc,
            foregroundColor: Colors.white,
          );
        }
        // For regular members: show "Pagar cuota" pointing to the first
        // unpaid active cuota — use misPagos (reliable for members).
        final allCuotas = cuotasAsync.valueOrNull ?? [];
        final uidFab = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
        final misPagosFab = ref.watch(misPagosGrupoProvider(
            (grupoId: widget.grupoId, uid: uidFab))).valueOrNull ?? [];
        final primera = allCuotas.where((c) =>
            c.activa && !misPagosFab.any((p) => p.cuotaId == c.id)
        ).firstOrNull;
        if (primera == null) return const SizedBox.shrink();
        return FloatingActionButton.extended(
          onPressed: () =>
              context.push('/group/${widget.grupoId}/cuota/${primera.id}'),
          icon: const Icon(Icons.payments_outlined),
          label: const Text('Pagar cuota'),
          backgroundColor: gc,
          foregroundColor: Colors.white,
        );
      }),
    );
  }

  /// Groups cuotas by serieId and returns list items (series collapsed or standalone).
  List<Widget> _buildCuotaRows(
    BuildContext context,
    List<CuotaModel> filtered,
    List<PagoModel> pagos,       // all group pagos (for group-wide counts)
    List<PagoModel> misPagos,    // current user's own pagos (reliable)
    String uid,
    String grupoId,
  ) {
    final rows = <Widget>[];
    final visited = <String>{};

    for (final c in filtered) {
      if (c.serieId != null) {
        if (visited.contains(c.serieId)) continue;
        visited.add(c.serieId!);
        final serie = filtered
            .where((x) => x.serieId == c.serieId)
            .toList()
          ..sort((a, b) => (a.numeroCuota ?? 0).compareTo(b.numeroCuota ?? 0));
        rows.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _SerieGroup(
            serie: serie,
            pagos: pagos,
            misPagos: misPagos,
            grupoId: grupoId,
            uid: uid,
          ),
        ));
      } else {
        // Current user's payment state — use misPagos (reliable for members)
        final miPago =
            misPagos.where((p) => p.cuotaId == c.id).toList();
        EstadoPago? miEstado;
        if (miPago.isNotEmpty) {
          miEstado = miPago.any((p) => p.estado == EstadoPago.aprobado)
              ? EstadoPago.aprobado
              : miPago.last.estado;
        }
        rows.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _CuotaCard(
            cuota: c,
            pagosAprobados: pagos
                .where((p) =>
                    p.cuotaId == c.id &&
                    p.estado == EstadoPago.aprobado)
                .length,
            pagosPendientes: pagos
                .where((p) =>
                    p.cuotaId == c.id &&
                    p.estado == EstadoPago.pendiente)
                .length,
            miEstado: miEstado,
            onTap: () =>
                context.push('/group/$grupoId/cuota/${c.id}'),
          ),
        ));
      }
    }
    return rows;
  }

  String _fmt(int n) => NumberFormat('#,##0', 'es_AR').format(n);
}

// â”€â”€ Stats widget â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _Stat extends StatelessWidget {
  final Color color;
  final String label, value;
  const _Stat(
      {required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ]),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.bricolageGrotesque(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
      ],
    );
  }
}

// â”€â”€ Filter chip â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _FilterChip extends StatelessWidget {
  final String label;
  final SGChipTone tone;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label,
      required this.tone,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: SGChip(label: label, tone: tone, filled: selected),
      ),
    );
  }
}

// â”€â”€ Cuota card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _CuotaCard extends StatelessWidget {
  final CuotaModel cuota;
  final int pagosAprobados;
  final int pagosPendientes;
  final EstadoPago? miEstado; // current user's payment state
  final VoidCallback onTap;

  const _CuotaCard({
    required this.cuota,
    required this.pagosAprobados,
    required this.pagosPendientes,
    required this.onTap,
    this.miEstado,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'es_AR');
    final vencida = cuota.vencimiento.isBefore(DateTime.now());
    final (bg, fg, badge) = cuota.activa
        ? vencida
            ? (AppTheme.dangerSoft, const Color(0xFF8C2A14), 'Vencida')
            : (AppTheme.goodSoft, const Color(0xFF1F7A5A), 'Activa')
        : (AppTheme.surfaceAlt, AppTheme.textMuted, 'Cerrada');

    return SGCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            cuota.activa
                ? (vencida
                    ? Icons.warning_amber_outlined
                    : Icons.receipt_long_rounded)
                : Icons.check_circle_outline_rounded,
            size: 22,
            color: fg,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cuota.tituloConNumero,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.text,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: fg),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'vence ${DateFormat('dd/MM').format(cuota.vencimiento)}',
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textMuted),
                ),
              ]),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$ ${fmt.format(cuota.monto.toInt())}',
              style: GoogleFonts.bricolageGrotesque(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppTheme.text,
              ),
            ),
            const SizedBox(height: 2),
            if (miEstado == EstadoPago.aprobado)
              Row(mainAxisSize: MainAxisSize.min, children: const [
                Icon(Icons.check_circle_rounded,
                    size: 11, color: AppTheme.good),
                SizedBox(width: 3),
                Text('Pagada',
                    style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.good,
                        fontWeight: FontWeight.w700)),
              ])
            else if (miEstado != null)
              Row(mainAxisSize: MainAxisSize.min, children: const [
                Icon(Icons.hourglass_top_rounded,
                    size: 11, color: Color(0xFFF59E0B)),
                SizedBox(width: 3),
                Text('En revisión',
                    style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFFF59E0B),
                        fontWeight: FontWeight.w700)),
              ])
            else if (pagosAprobados > 0 || pagosPendientes > 0)
              Text(
                '$pagosAprobados ✓ · $pagosPendientes pend.',
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.textMuted),
              ),
          ],
        ),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right_rounded,
            size: 18, color: AppTheme.textMuted),
      ]),
    );
  }
}

// â"€â"€ Serie group â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€

class _SerieGroup extends StatefulWidget {
  final List<CuotaModel> serie;
  final List<PagoModel> pagos;      // all group pagos
  final List<PagoModel> misPagos;   // current user's pagos
  final String grupoId;
  final String uid;

  const _SerieGroup({
    required this.serie,
    required this.pagos,
    required this.misPagos,
    required this.grupoId,
    required this.uid,
  });

  @override
  State<_SerieGroup> createState() => _SerieGroupState();
}

class _SerieGroupState extends State<_SerieGroup> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'es_AR');
    final first = widget.serie.first;
    final total = widget.serie.length;
    // Count cuotas where the current user has submitted any payment
    final completadas = widget.serie
        .where((c) => widget.misPagos.any((p) => p.cuotaId == c.id))
        .length;
    final vencidas = widget.serie
        .where((c) => c.activa && c.vencimiento.isBefore(DateTime.now()))
        .length;

    final (headerBg, headerFg) = vencidas > 0
        ? (AppTheme.dangerSoft, const Color(0xFF8C2A14))
        : completadas == total
            ? (AppTheme.surfaceAlt, AppTheme.textMuted)
            : (AppTheme.goodSoft, const Color(0xFF1F7A5A));

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          // Header row
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
                bottom: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: headerBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.repeat_rounded,
                        size: 22, color: headerFg),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          first.titulo,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: headerBg,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              first.frecuencia?.label ?? 'Serie',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: headerFg),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$completadas/$total pagadas',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textMuted),
                          ),
                          if (vencidas > 0) ...[
                            const SizedBox(width: 6),
                            Text(
                              '$vencidas vencida${vencidas > 1 ? 's' : ''}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.danger,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ]),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$ ${fmt.format(first.monto.toInt())}',
                        style: GoogleFonts.bricolageGrotesque(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'c/cuota',
                        style: const TextStyle(
                            fontSize: 10, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 20, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ),
          // Expanded cuotas list
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                Divider(
                    height: 1,
                    color: AppTheme.border,
                    indent: 12,
                    endIndent: 12),
                ...widget.serie.map((c) {
                  // User's own pago state — use misPagos (reliable)
                  final misP = widget.misPagos
                      .where((p) => p.cuotaId == c.id)
                      .toList();
                  final miEst = misP.isEmpty
                      ? null
                      : misP.any((p) => p.estado == EstadoPago.aprobado)
                          ? EstadoPago.aprobado
                          : misP.last.estado;
                  return InkWell(
                    onTap: () => GoRouter.of(context).push(
                        '/group/${widget.grupoId}/cuota/${c.id}'),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Row(children: [
                        const SizedBox(width: 56),
                        Expanded(
                          child: Text(
                            c.tituloConNumero,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                        if (miEst == EstadoPago.aprobado)
                          const Icon(Icons.check_circle_rounded,
                              size: 14, color: AppTheme.good)
                        else if (miEst != null)
                          const Icon(Icons.hourglass_top_rounded,
                              size: 14, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 6),
                        Text(
                          'vence ${DateFormat('dd/MM').format(c.vencimiento)}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textMuted),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded,
                            size: 16, color: AppTheme.textMuted),
                      ]),
                    ),
                  );
                }),
              ],
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }
}
