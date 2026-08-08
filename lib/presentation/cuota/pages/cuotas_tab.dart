import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../data/models/cuota_model.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/miembro_model.dart';
import '../../../data/models/pago_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/cuota_grupo_provider.dart';
import '../../../providers/cuota_provider.dart';
import '../../../providers/grupo_provider.dart';

const _meses = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
];

class CuotasTab extends ConsumerStatefulWidget {
  final String grupoId;
  const CuotasTab({super.key, required this.grupoId});

  @override
  ConsumerState<CuotasTab> createState() => _CuotasTabState();
}

enum _Filter { todos, activas, vencidas, completadas }

class _CuotasTabState extends ConsumerState<CuotasTab> {
  _Filter _filter = _Filter.todos;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  void _prevMonth() => setState(() =>
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1));
  void _nextMonth() => setState(() =>
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1));

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
    // Admin/tesorero: full member list for per-member stats
    final miembros = canAdd
        ? (ref.watch(miembrosProvider(widget.grupoId)).valueOrNull ?? <MiembroModel>[])
        : <MiembroModel>[];

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: cuotasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const SGErrorState(message: 'Error al cargar las suscripciones'),
        data: (cuotas) {
          final pagos = pagosAsync.valueOrNull ?? [];
          final misPagos = misPagosAsync.valueOrNull ?? [];
          final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
          final now = DateTime.now();

          bool isPagadoPorMi(CuotaModel c) =>
              misPagos.any((p) => p.cuotaId == c.id);

          // Member view: group-level stats for progress bar
          final aprobados =
              pagos.where((p) => p.estado == EstadoPago.aprobado).length;
          final pendientes =
              pagos.where((p) => p.estado == EstadoPago.pendiente).length;
          final rechazados =
              pagos.where((p) => p.estado == EstadoPago.revision).length;

          final misPagosMes = misPagos
              .where((p) =>
                  p.estado == EstadoPago.aprobado &&
                  p.createdAt.year == now.year &&
                  p.createdAt.month == now.month)
              .fold<double>(0, (sum, p) => sum + p.montoEsperado);

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

          // Admin view: cuotas filtered to selected month
          final cuotasMes = cuotas.where((c) =>
              c.vencimiento.year == _selectedMonth.year &&
              c.vencimiento.month == _selectedMonth.month).toList();
          final cuotaIdsMes = cuotasMes.map((c) => c.id).toSet();
          final aprobadosMes = pagos.where((p) =>
              cuotaIdsMes.contains(p.cuotaId) &&
              p.estado == EstadoPago.aprobado).length;
          final pendientesMes = pagos.where((p) =>
              cuotaIdsMes.contains(p.cuotaId) &&
              p.estado == EstadoPago.pendiente).length;
          final rechazadosMes = pagos.where((p) =>
              cuotaIdsMes.contains(p.cuotaId) &&
              p.estado == EstadoPago.revision).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, AppTheme.kBottomNavPadding),
            children: [
              if (canAdd) ...[
                // ── Mis cuotas (personal) ────────────────────────────────
                const SGEyebrow('Mis cuotas'),
                const SizedBox(height: 10),
                Builder(builder: (ctx) {
                  final sinPagar = cuotas
                      .where((c) =>
                          c.activa && !misPagos.any((p) => p.cuotaId == c.id))
                      .toList();
                  final vencidas = sinPagar
                      .where((c) => c.vencimiento.isBefore(now))
                      .length;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '\$ ${_fmt(misPagosMes.toInt())}',
                                style: GoogleFonts.bricolageGrotesque(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 26,
                                  color: AppTheme.text,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                'pagado este mes · ${cuotas.length} cuota${cuotas.length != 1 ? 's' : ''}',
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                        if (vencidas > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.dangerSoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$vencidas vencida${vencidas != 1 ? 's' : ''}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.dangerInk),
                            ),
                          )
                        else if (sinPagar.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.warningSoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${sinPagar.length} pendiente${sinPagar.length != 1 ? 's' : ''}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.warning),
                            ),
                          )
                        else if (cuotas.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.goodSoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Al día',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.goodInk),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                ..._buildCuotaRows(
                  context,
                  cuotas.where((c) => c.activa).toList(),
                  pagos,
                  misPagos,
                  uid,
                  widget.grupoId,
                  puedeConfirmar: false,
                ),
                const SizedBox(height: 24),
                // ── Gestión del grupo ─────────────────────────────────────
                const SGEyebrow('Gestión del grupo'),
                const SizedBox(height: 12),
                _AdminStatsCard(
                  cuotasCount: cuotasMes.length,
                  totalMiembros: miembros.length,
                  aprobados: aprobadosMes,
                  pendientes: pendientesMes,
                  rechazados: rechazadosMes,
                  gc: gc,
                  selectedMonth: _selectedMonth,
                  onPrevMonth: _prevMonth,
                  onNextMonth: _nextMonth,
                  rol: rol,
                ),
                const SizedBox(height: 16),
                ..._buildAdminCuotaRows(
                    context, cuotasMes, pagos, miembros, widget.grupoId, rol),
                // Subscription groups section
                _CuotaGruposSection(grupoId: widget.grupoId),
                if (cuotasMes.isEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 32, 0, 8),
                    child: Center(
                      child: Text(
                        'Sin cuotas en ${_meses[_selectedMonth.month - 1]}',
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                    ),
                  ),
                  if (cuotas.isNotEmpty)
                    _OtherMonthsChips(
                      cuotas: cuotas,
                      selectedMonth: _selectedMonth,
                      onMonthTap: (y, m) =>
                          setState(() => _selectedMonth = DateTime(y, m)),
                    ),
                ],
              ] else ...[
                Builder(builder: (ctx) {
                  final cardBg = Theme.of(ctx).colorScheme.inverseSurface;
                  final cardFg = Theme.of(ctx).colorScheme.onInverseSurface;
                  return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MIS PAGOS ESTE MES',
                        style: GoogleFonts.dmSans(
                          color: cardFg.withValues(alpha: 0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '\$ ${_fmt(misPagosMes.toInt())}',
                        style: GoogleFonts.bricolageGrotesque(
                          color: cardFg,
                          fontWeight: FontWeight.w700,
                          fontSize: 36,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${cuotas.length} ${cuotas.length == 1 ? 'cuota' : 'cuotas'} en el grupo',
                        style: TextStyle(
                            color: cardFg.withValues(alpha: 0.7), fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      if (aprobados + pendientes + rechazados > 0) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: Row(children: [
                            if (aprobados > 0)
                              Expanded(flex: aprobados,
                                child: const ColoredBox(color: AppTheme.good,
                                    child: SizedBox(height: 10))),
                            if (pendientes > 0)
                              Expanded(flex: pendientes,
                                child: const ColoredBox(color: AppTheme.accent,
                                    child: SizedBox(height: 10))),
                            if (rechazados > 0)
                              Expanded(flex: rechazados,
                                child: const ColoredBox(color: AppTheme.danger,
                                    child: SizedBox(height: 10))),
                          ]),
                        ),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: _Stat(color: AppTheme.good,
                              label: 'Aprobados', value: '$aprobados')),
                          Expanded(child: _Stat(color: AppTheme.accent,
                              label: 'Pendientes', value: '$pendientes')),
                          Expanded(child: _Stat(color: AppTheme.danger,
                              label: 'Rechazados', value: '$rechazados')),
                        ]),
                      ],
                    ],
                  ),
                );
                }),

                const SizedBox(height: 16),

                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterChip(
                        label: 'Todas · ${cuotas.length}',
                        tone: SGChipTone.primary,
                        selected: _filter == _Filter.todos,
                        onTap: () => setState(() => _filter = _Filter.todos),
                      ),
                      _FilterChip(
                        label: 'Activas',
                        tone: SGChipTone.good,
                        selected: _filter == _Filter.activas,
                        onTap: () => setState(() => _filter = _Filter.activas),
                      ),
                      _FilterChip(
                        label: 'Vencidas',
                        tone: SGChipTone.danger,
                        selected: _filter == _Filter.vencidas,
                        onTap: () => setState(() => _filter = _Filter.vencidas),
                      ),
                      _FilterChip(
                        label: 'Completadas',
                        tone: SGChipTone.neutral,
                        selected: _filter == _Filter.completadas,
                        onTap: () => setState(() => _filter = _Filter.completadas),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

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
                      context, filtered, pagos, misPagos, uid, widget.grupoId,
                      puedeConfirmar: rol?.puedeGestionarCuotas ?? false),
              ],
            ],
          );
        },
      ),
      floatingActionButton: Builder(builder: (_) {
        if (canAdd) {
          return FloatingActionButton.extended(
            onPressed: () =>
                context.push('/cuotas/crear'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Emitir cuota'),
            backgroundColor: gc,
            foregroundColor: Colors.white,
          );
        }
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
              context.push('/cuota/${primera.id}'),
          icon: const Icon(Icons.payments_outlined),
          label: const Text('Pagar cuota'),
          backgroundColor: gc,
          foregroundColor: Colors.white,
        );
      }),
    );
  }

  List<Widget> _buildAdminCuotaRows(
    BuildContext context,
    List<CuotaModel> cuotas,
    List<PagoModel> pagos,
    List<MiembroModel> miembros,
    String grupoId,
    dynamic rol,
  ) {
    return cuotas.map((c) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _AdminCuotaRow(
        cuota: c,
        pagosDeCuota: pagos.where((p) => p.cuotaId == c.id).toList(),
        miembros: miembros,
        onTap: () => context.push('/cuota/${c.id}'),
        onEdit: rol?.puedeGestionarCuotas == true
            ? () => context.push('/cuota/${c.id}/edit', extra: c)
            : null,
        onDelete: rol?.puedeGestionarCuotas == true
            ? () => _confirmDeleteCuota(context, grupoId, c.id, c.titulo)
            : null,
      ),
    )).toList();
  }

  List<Widget> _buildCuotaRows(
    BuildContext context,
    List<CuotaModel> filtered,
    List<PagoModel> pagos,
    List<PagoModel> misPagos,
    String uid,
    String grupoId, {
    bool puedeConfirmar = false,
  }) {
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
            puedeConfirmar: puedeConfirmar,
          ),
        ));
      } else {
        final miPago = misPagos.where((p) => p.cuotaId == c.id).toList();
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
                .where((p) => p.cuotaId == c.id && p.estado == EstadoPago.aprobado)
                .length,
            pagosPendientes: pagos
                .where((p) => p.cuotaId == c.id && p.estado == EstadoPago.pendiente)
                .length,
            miEstado: miEstado,
            onTap: () => context.push('/cuota/${c.id}'),
            onEdit: puedeConfirmar
                ? () => context.push('/cuota/${c.id}/edit', extra: c)
                : null,
            onDelete: puedeConfirmar
                ? () => _confirmDeleteCuota(context, grupoId, c.id, c.titulo)
                : null,
          ),
        ));
      }
    }
    return rows;
  }

  Future<void> _confirmDeleteCuota(
    BuildContext context,
    String grupoId,
    String cuotaId,
    String titulo,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar suscripción'),
        content: Text('¿Eliminás "$titulo"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(cuotaRepositoryProvider).deleteCuota(grupoId, cuotaId);
  }

  String _fmt(int n) => NumberFormat('#,##0', 'es_AR').format(n);
}

// ── Admin stats card ─────────────────────────────────────────────────────────

class _AdminStatsCard extends StatelessWidget {
  final int cuotasCount;
  final int totalMiembros;
  final int aprobados;
  final int pendientes;
  final int rechazados;
  final Color gc;
  final DateTime selectedMonth;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final RolMiembro? rol;

  const _AdminStatsCard({
    required this.cuotasCount,
    required this.totalMiembros,
    required this.aprobados,
    required this.pendientes,
    required this.rechazados,
    required this.gc,
    required this.selectedMonth,
    required this.onPrevMonth,
    required this.onNextMonth,
    this.rol,
  });

  @override
  Widget build(BuildContext context) {
    final total = totalMiembros > 0 ? totalMiembros : 1;
    final pct = (aprobados / total).clamp(0.0, 1.0);
    final mesLabel = '${_meses[selectedMonth.month - 1]} ${selectedMonth.year}';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gc, Color.lerp(gc, Colors.black, 0.18)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: gc.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.manage_accounts_rounded, size: 12, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    rol == RolMiembro.administrador ? 'Panel admin' : 'Gestión de cuotas',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                        color: Colors.white, letterSpacing: 0.5),
                  ),
                ]),
              ),
              Row(children: [
                GestureDetector(
                  onTap: onPrevMonth,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.chevron_left_rounded, color: Colors.white, size: 22),
                  ),
                ),
                Text(mesLabel,
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w700, fontSize: 13)),
                GestureDetector(
                  onTap: onNextMonth,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.chevron_right_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ]),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$aprobados / $totalMiembros',
            style: GoogleFonts.bricolageGrotesque(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 36,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'miembros pagaron · $cuotasCount ${cuotasCount == 1 ? 'cuota' : 'cuotas'} este mes',
            style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            _MiniStat(color: Colors.white, label: 'Pagaron', value: '$aprobados'),
            const SizedBox(width: 16),
            _MiniStat(color: Colors.white70, label: 'Pendientes', value: '$pendientes'),
            const SizedBox(width: 16),
            _MiniStat(color: Colors.white54, label: 'Rechazados', value: '$rechazados'),
          ]),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final Color color;
  final String label, value;
  const _MiniStat({required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: GoogleFonts.bricolageGrotesque(
                color: color, fontWeight: FontWeight.w700, fontSize: 18)),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ── Stats widget ──────────────────────────────────────────────────────────────

class _Stat extends StatelessWidget {
  final Color color;
  final String label, value;
  const _Stat({required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.dmSans(
                color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 2),
        Text(value,
            style: GoogleFonts.bricolageGrotesque(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 22)),
      ],
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final SGChipTone tone;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.tone,
      required this.selected, required this.onTap});

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

// ── Other months chips ────────────────────────────────────────────────────────

class _OtherMonthsChips extends StatelessWidget {
  final List<CuotaModel> cuotas;
  final DateTime selectedMonth;
  final void Function(int year, int month) onMonthTap;

  const _OtherMonthsChips({
    required this.cuotas,
    required this.selectedMonth,
    required this.onMonthTap,
  });

  @override
  Widget build(BuildContext context) {
    final months = cuotas
        .map((c) => (c.vencimiento.year, c.vencimiento.month))
        .toSet()
        .where((ym) =>
            ym.$1 != selectedMonth.year || ym.$2 != selectedMonth.month)
        .toList()
      ..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));

    if (months.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(children: [
        const Text('Hay cuotas en:',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: months.map((ym) {
            final label = '${_meses[ym.$2 - 1]} ${ym.$1}';
            return InkWell(
              onTap: () => onMonthTap(ym.$1, ym.$2),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.text)),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }
}

// ── Admin cuota row ───────────────────────────────────────────────────────────

class _AdminCuotaRow extends StatefulWidget {
  final CuotaModel cuota;
  final List<PagoModel> pagosDeCuota;
  final List<MiembroModel> miembros;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _AdminCuotaRow({
    required this.cuota, required this.pagosDeCuota,
    required this.miembros, required this.onTap,
    this.onEdit, this.onDelete,
  });

  @override
  State<_AdminCuotaRow> createState() => _AdminCuotaRowState();
}

class _AdminCuotaRowState extends State<_AdminCuotaRow> {
  bool _expanded = false;

  PagoModel? _mejorPago(String uid) =>
      widget.pagosDeCuota.where((p) => p.usuarioUid == uid).fold<PagoModel?>(
        null, (best, p) {
          if (best == null) return p;
          const ord = [EstadoPago.aprobado, EstadoPago.validando,
                       EstadoPago.revision, EstadoPago.pendiente];
          return ord.indexOf(p.estado) < ord.indexOf(best.estado) ? p : best;
        });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'es_AR');
    final c = widget.cuota;
    final vencida = c.vencimiento.isBefore(DateTime.now());
    final (bg, fg) = c.activa
        ? vencida
            ? (AppTheme.dangerSoft, AppTheme.dangerInk)
            : (AppTheme.goodSoft, AppTheme.goodInk)
        : (AppTheme.surfaceAlt, AppTheme.textMuted);
    final pagaron = widget.miembros
        .where((m) => _mejorPago(m.uid)?.estado == EstadoPago.aprobado)
        .length;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(children: [
        InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
                child: Icon(
                  c.activa
                      ? (vencida ? Icons.warning_amber_outlined : Icons.receipt_long_rounded)
                      : Icons.check_circle_outline_rounded,
                  size: 20, color: fg,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.tituloConNumero,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.text),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('vence ${DateFormat('dd/MM').format(c.vencimiento)}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('\$ ${fmt.format(c.monto.toInt())}',
                    style: GoogleFonts.bricolageGrotesque(
                        fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.text)),
                Text('$pagaron/${widget.miembros.length} pagaron',
                    style: TextStyle(
                        fontSize: 10,
                        color: pagaron == widget.miembros.length && widget.miembros.isNotEmpty
                            ? AppTheme.good : AppTheme.textMuted,
                        fontWeight: FontWeight.w600)),
              ]),
              if (widget.onEdit != null || widget.onDelete != null)
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero, iconSize: 20,
                  icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppTheme.textMuted),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  itemBuilder: (_) => [
                    if (widget.onEdit != null)
                      const PopupMenuItem(value: 'editar',
                          child: Row(children: [
                            Icon(Icons.edit_outlined, size: 18), SizedBox(width: 10), Text('Editar')])),
                    if (widget.onDelete != null)
                      const PopupMenuItem(value: 'eliminar',
                          child: Row(children: [
                            Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.danger),
                            SizedBox(width: 10),
                            Text('Eliminar', style: TextStyle(color: AppTheme.danger))])),
                  ],
                  onSelected: (v) {
                    if (v == 'editar') widget.onEdit?.call();
                    if (v == 'eliminar') widget.onDelete?.call();
                  },
                ),
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 20, color: AppTheme.textMuted),
                  ),
                ),
              ),
            ]),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: _buildMemberList(),
          crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
        ),
      ]),
    );
  }

  Widget _buildMemberList() {
    final pagaron = <(MiembroModel, PagoModel)>[];
    final pendientes = <MiembroModel>[];
    final sinPagar = <MiembroModel>[];

    for (final m in widget.miembros) {
      final p = _mejorPago(m.uid);
      if (p == null) {
        sinPagar.add(m);
      } else if (p.estado == EstadoPago.aprobado) {
        pagaron.add((m, p));
      } else {
        pendientes.add(m);
      }
    }

    Widget memberRow(MiembroModel m,
        {required IconData icon, required Color color, String? sub}) =>
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: Row(children: [
            SGAvatar(name: m.nombreCompleto, imageUrl: m.avatarUrl, size: 28),
            const SizedBox(width: 10),
            Expanded(child: Text(m.nombreCompleto,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (sub != null)
              Text(sub, style: TextStyle(fontSize: 11, color: color)),
            const SizedBox(width: 6),
            Icon(icon, size: 14, color: color),
          ]),
        );

    return Column(children: [
      const Divider(height: 1, color: AppTheme.border, indent: 12, endIndent: 12),
      ...pagaron.map((entry) => memberRow(entry.$1,
          icon: Icons.check_circle_rounded, color: AppTheme.good,
          sub: DateFormat('dd/MM').format(entry.$2.createdAt))),
      if (pendientes.isNotEmpty) ...[
        if (pagaron.isNotEmpty)
          const Divider(height: 1, color: AppTheme.border, indent: 12, endIndent: 12),
        ...pendientes.map((m) => memberRow(m,
            icon: Icons.hourglass_top_rounded, color: AppTheme.warning,
            sub: 'En revisión')),
      ],
      if (sinPagar.isNotEmpty) ...[
        if (pagaron.isNotEmpty || pendientes.isNotEmpty)
          const Divider(height: 1, color: AppTheme.border, indent: 12, endIndent: 12),
        ...sinPagar.map((m) => memberRow(m,
            icon: Icons.close_rounded, color: AppTheme.danger,
            sub: 'Sin pagar')),
      ],
    ]);
  }
}

// ── Cuota card ────────────────────────────────────────────────────────────────

class _CuotaCard extends StatelessWidget {
  final CuotaModel cuota;
  final int pagosAprobados;
  final int pagosPendientes;
  final EstadoPago? miEstado;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _CuotaCard({
    required this.cuota,
    required this.pagosAprobados,
    required this.pagosPendientes,
    required this.onTap,
    this.miEstado,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'es_AR');
    final vencida = cuota.vencimiento.isBefore(DateTime.now());
    final (bg, fg, badge) = cuota.activa
        ? vencida
            ? (AppTheme.dangerSoft, AppTheme.dangerInk, 'Vencida')
            : (AppTheme.goodSoft, AppTheme.goodInk, 'Activa')
        : (AppTheme.surfaceAlt, AppTheme.textMuted, 'Cerrada');

    return SGCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
          child: Icon(
            cuota.activa
                ? (vencida ? Icons.warning_amber_outlined : Icons.receipt_long_rounded)
                : Icons.check_circle_outline_rounded,
            size: 22, color: fg,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cuota.tituloConNumero,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.text),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
                child: Text(badge,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
              ),
              const SizedBox(width: 6),
              Text('vence ${DateFormat('dd/MM').format(cuota.vencimiento)}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            ]),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('\$ ${fmt.format(cuota.monto.toInt())}',
              style: GoogleFonts.bricolageGrotesque(
                  fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.text)),
          const SizedBox(height: 2),
          if (miEstado == EstadoPago.aprobado)
            const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle_rounded, size: 11, color: AppTheme.good),
              SizedBox(width: 3),
              Text('Pagada', style: TextStyle(fontSize: 10, color: AppTheme.good, fontWeight: FontWeight.w700)),
            ])
          else if (miEstado != null)
            const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.hourglass_top_rounded, size: 11, color: AppTheme.warning),
              SizedBox(width: 3),
              Text('En revisión', style: TextStyle(fontSize: 10, color: AppTheme.warning, fontWeight: FontWeight.w700)),
            ])
          else if (pagosAprobados > 0 || pagosPendientes > 0)
            Text('$pagosAprobados ✓ · $pagosPendientes pend.',
                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
        ]),
        const SizedBox(width: 4),
        if (onEdit != null || onDelete != null)
          PopupMenuButton<String>(
            padding: EdgeInsets.zero, iconSize: 20,
            icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppTheme.textMuted),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            itemBuilder: (_) => [
              if (onEdit != null)
                const PopupMenuItem(value: 'editar',
                    child: Row(children: [
                      Icon(Icons.edit_outlined, size: 18), SizedBox(width: 10), Text('Editar')])),
              if (onDelete != null)
                const PopupMenuItem(value: 'eliminar',
                    child: Row(children: [
                      Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.danger),
                      SizedBox(width: 10),
                      Text('Eliminar', style: TextStyle(color: AppTheme.danger))])),
            ],
            onSelected: (v) {
              if (v == 'editar') onEdit?.call();
              if (v == 'eliminar') onDelete?.call();
            },
          )
        else
          const Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.textMuted),
      ]),
    );
  }
}

// ── Serie group ───────────────────────────────────────────────────────────────

class _SerieGroup extends StatefulWidget {
  final List<CuotaModel> serie;
  final List<PagoModel> pagos;
  final List<PagoModel> misPagos;
  final String grupoId;
  final String uid;
  final bool puedeConfirmar;

  const _SerieGroup({
    required this.serie, required this.pagos, required this.misPagos,
    required this.grupoId, required this.uid, this.puedeConfirmar = false,
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
    final completadas = widget.puedeConfirmar && widget.pagos.isNotEmpty
        ? widget.serie.where((c) =>
            widget.pagos.any((p) => p.cuotaId == c.id && p.estado == EstadoPago.aprobado)).length
        : widget.serie.where((c) =>
            widget.misPagos.any((p) => p.cuotaId == c.id)).length;
    final vencidas = widget.serie
        .where((c) => c.activa && c.vencimiento.isBefore(DateTime.now())).length;

    final (headerBg, headerFg) = vencidas > 0
        ? (AppTheme.dangerSoft, AppTheme.dangerInk)
        : completadas == total
            ? (AppTheme.surfaceAlt, AppTheme.textMuted)
            : (AppTheme.goodSoft, AppTheme.goodInk);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(16), bottom: Radius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: headerBg, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.repeat_rounded, size: 22, color: headerFg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(first.titulo,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: headerBg, borderRadius: BorderRadius.circular(4)),
                      child: Text(first.frecuencia?.label ?? 'Serie',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: headerFg)),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.puedeConfirmar
                          ? '$completadas/$total miembros pagaron'
                          : '$completadas/$total pagadas',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                    if (vencidas > 0) ...[
                      const SizedBox(width: 6),
                      Text('$vencidas vencida${vencidas > 1 ? 's' : ''}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.danger, fontWeight: FontWeight.w600)),
                    ],
                  ]),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('\$ ${fmt.format(first.monto.toInt())}',
                    style: GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w700, fontSize: 14)),
                const Text('c/cuota',
                    style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              ]),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppTheme.textMuted),
              ),
            ]),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Column(children: [
            const Divider(height: 1, color: AppTheme.border, indent: 12, endIndent: 12),
            ...widget.serie.map((c) {
              final misP = widget.misPagos.where((p) => p.cuotaId == c.id).toList();
              final miEst = misP.isEmpty
                  ? null
                  : misP.any((p) => p.estado == EstadoPago.aprobado)
                      ? EstadoPago.aprobado
                      : misP.last.estado;
              return InkWell(
                onTap: () => GoRouter.of(context).push(
                    '/cuota/${c.id}'),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Row(children: [
                    const SizedBox(width: 56),
                    Expanded(child: Text(c.tituloConNumero,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                    if (miEst == EstadoPago.aprobado)
                      const Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.good)
                    else if (miEst != null)
                      const Icon(Icons.hourglass_top_rounded, size: 14, color: AppTheme.warning),
                    const SizedBox(width: 6),
                    Text('vence ${DateFormat('dd/MM').format(c.vencimiento)}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.textMuted),
                  ]),
                ),
              );
            }),
          ]),
          crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
        ),
      ]),
    );
  }
}

// Subscription groups section for tesorero view

class _CuotaGruposSection extends ConsumerWidget {
  final String grupoId;
  const _CuotaGruposSection({required this.grupoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cuotaGrupos =
        ref.watch(cuotaGruposProvider(grupoId)).valueOrNull ?? [];
    final gc = ref.watch(grupoColorProvider(grupoId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            const SGEyebrow('Grupos de suscripción'),
            const Spacer(),
            GestureDetector(
              onTap: () =>
                  GoRouter.of(context).push('/cuotas/grupo/crear'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: gc.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 14, color: gc),
                    const SizedBox(width: 4),
                    Text('Nuevo',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: gc)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (cuotaGrupos.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Sin grupos de suscripción. Creá uno para gestionar cobros recurrentes.',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
          )
        else
          ...cuotaGrupos.map((cg) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CuotaGrupoTile(
                  grupoId: grupoId,
                  cuotaGrupoId: cg.id,
                  nombre: cg.nombre,
                  monto: cg.montoMensual,
                  miembros: cg.miembrosUids.length,
                  diaVencimiento: cg.diaVencimiento,
                  gc: gc,
                ),
              )),
      ],
    );
  }
}

class _CuotaGrupoTile extends StatelessWidget {
  final String grupoId;
  final String cuotaGrupoId;
  final String nombre;
  final double monto;
  final int miembros;
  final int diaVencimiento;
  final Color gc;

  const _CuotaGrupoTile({
    required this.grupoId,
    required this.cuotaGrupoId,
    required this.nombre,
    required this.monto,
    required this.miembros,
    required this.diaVencimiento,
    required this.gc,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'es_AR');
    return SGCard(
      padding: const EdgeInsets.all(12),
      onTap: () => GoRouter.of(context)
          .push('/cuotas/grupo/$cuotaGrupoId'),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: gc.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.repeat_rounded, size: 20, color: gc),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$miembros miembro${miembros != 1 ? 's' : ''} · vence día $diaVencimiento',
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$ ${fmt.format(monto.toInt())}',
                style: GoogleFonts.bricolageGrotesque(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppTheme.text),
              ),
              const Text('/ mes',
                  style:
                      TextStyle(fontSize: 10, color: AppTheme.textMuted)),
            ],
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded,
              size: 18, color: AppTheme.textMuted),
        ],
      ),
    );
  }
}
