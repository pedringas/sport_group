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
import '../../../providers/cuota_provider.dart';
import '../../../providers/grupo_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Cuotas
//
// Dos vistas bien separadas sobre los mismos datos:
//
// · Miembro  → sólo SUS cuotas, agrupadas en "Por pagar" y "Pagadas", y dentro
//              de cada bloque separadas por mes de vencimiento.
// · Admin    → primero sus propias cuotas (es miembro como cualquier otro) y
//              después el panel de gestión del grupo, acotado al mes elegido.
//
// Reglas que antes estaban dispersas y daban números distintos en cada tarjeta:
// el vencimiento se evalúa por día calendario (`CuotaModel.estaVencida`) y el
// alcance de cada cuota respeta `miembrosUids` / `excluidosUids`
// (`CuotaModel.aplicaA`).
// ─────────────────────────────────────────────────────────────────────────────

const _meses = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
];

String _fmtMoney(num n) => NumberFormat('#,##0', 'es_AR').format(n);

String _mesLabel(DateTime d) => '${_meses[d.month - 1]} ${d.year}';

/// Estado de pago propio de una cuota. `null` = sin pago registrado.
///
/// Un pago aprobado manda sobre cualquier otro; si no hay ninguno aprobado vale
/// el más reciente. Antes se tomaba `misPagos.last` sobre un stream sin orden,
/// así que el estado mostrado dependía del orden en que Firestore devolvía los
/// documentos.
EstadoPago? _miEstado(CuotaModel c, List<PagoModel> misPagos) {
  final propios = misPagos.where((p) => p.cuotaId == c.id).toList();
  if (propios.isEmpty) return null;
  if (propios.any((p) => p.estado == EstadoPago.aprobado)) {
    return EstadoPago.aprobado;
  }
  propios.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return propios.last.estado;
}

/// Agrupa cuotas por mes de vencimiento.
List<(DateTime, List<CuotaModel>)> _porMes(
  List<CuotaModel> cuotas, {
  bool masRecientePrimero = false,
}) {
  final mapa = <DateTime, List<CuotaModel>>{};
  for (final c in cuotas) {
    mapa.putIfAbsent(c.periodo, () => []).add(c);
  }
  final claves = mapa.keys.toList()
    ..sort((a, b) => masRecientePrimero ? b.compareTo(a) : a.compareTo(b));
  return [
    for (final k in claves)
      (k, mapa[k]!..sort((a, b) => a.vencimiento.compareTo(b.vencimiento)))
  ];
}

class CuotasTab extends ConsumerStatefulWidget {
  final String grupoId;
  const CuotasTab({super.key, required this.grupoId});

  @override
  ConsumerState<CuotasTab> createState() => _CuotasTabState();
}

class _CuotasTabState extends ConsumerState<CuotasTab> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  void _prevMonth() => setState(() =>
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1));
  void _nextMonth() => setState(() =>
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1));

  @override
  Widget build(BuildContext context) {
    final cuotasAsync = ref.watch(cuotasProvider(widget.grupoId));
    final miembroAsync = ref.watch(miembroActualProvider(widget.grupoId));
    final gc = ref.watch(grupoColorProvider(widget.grupoId));

    final rol = miembroAsync.valueOrNull?.rol;
    final puedeGestionar = rol?.puedeGestionarCuotas ?? false;

    final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
    final misPagos = ref
            .watch(misPagosGrupoProvider((grupoId: widget.grupoId, uid: uid)))
            .valueOrNull ??
        const <PagoModel>[];

    // Los pagos y el padrón completo son datos de administración: para un
    // miembro común las reglas de Firestore los rechazan, así que ni se piden.
    final pagosGrupo = puedeGestionar
        ? (ref.watch(pagosGrupoProvider(widget.grupoId)).valueOrNull ??
            const <PagoModel>[])
        : const <PagoModel>[];
    final miembros = puedeGestionar
        ? (ref.watch(miembrosProvider(widget.grupoId)).valueOrNull ??
            const <MiembroModel>[])
        : const <MiembroModel>[];

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: cuotasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const SGErrorState(message: 'Error al cargar las cuotas'),
        data: (cuotas) {
          final mias = cuotas.where((c) => c.aplicaA(uid)).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(
                16, 12, 16, AppTheme.kBottomNavPadding),
            children: [
              ..._buildMisCuotas(mias, misPagos),
              if (puedeGestionar) ...[
                const SizedBox(height: 28),
                ..._buildGestion(cuotas, pagosGrupo, miembros, gc, rol),
              ],
            ],
          );
        },
      ),
      floatingActionButton: _buildFab(cuotasAsync.valueOrNull ?? const [],
          misPagos, uid, puedeGestionar, gc),
    );
  }

  // ── Vista personal (miembro y admin por igual) ─────────────────────────────

  List<Widget> _buildMisCuotas(
      List<CuotaModel> mias, List<PagoModel> misPagos) {
    final porPagar = mias
        .where((c) => c.activa && _miEstado(c, misPagos) != EstadoPago.aprobado)
        .toList()
      ..sort((a, b) => a.vencimiento.compareTo(b.vencimiento));
    final pagadas = mias
        .where((c) => _miEstado(c, misPagos) == EstadoPago.aprobado)
        .toList();

    final vencidas = porPagar.where((c) => c.estaVencida).toList();
    final aVencer = porPagar.where((c) => !c.estaVencida).toList();
    final totalPorPagar = porPagar.fold<double>(0, (s, c) => s + c.monto);
    final totalPagado = pagadas.fold<double>(0, (s, c) => s + c.monto);

    return [
      const SGEyebrow('Mis cuotas'),
      const SizedBox(height: 10),
      if (mias.isEmpty)
        const _SinCuotasCard()
      else
        _ResumenPersonalCard(
          totalPorPagar: totalPorPagar,
          totalPagado: totalPagado,
          cantPorPagar: porPagar.length,
          cantVencidas: vencidas.length,
        ),

      // ── Por pagar: primero lo vencido, después por mes de vencimiento.
      if (porPagar.isNotEmpty) ...[
        const SizedBox(height: 20),
        _BloqueHeader(
          label: 'Por pagar',
          count: porPagar.length,
          color: vencidas.isNotEmpty ? AppTheme.danger : AppTheme.warning,
        ),
        if (vencidas.isNotEmpty) ...[
          const SizedBox(height: 10),
          const _MesHeader(label: 'Vencidas', destacado: true),
          const SizedBox(height: 6),
          ...vencidas.map((c) => _fila(c, _miEstado(c, misPagos))),
        ],
        for (final (mes, delMes) in _porMes(aVencer)) ...[
          const SizedBox(height: 10),
          _MesHeader(label: _mesLabel(mes)),
          const SizedBox(height: 6),
          ...delMes.map((c) => _fila(c, _miEstado(c, misPagos))),
        ],
      ],

      // ── Pagadas: historial, de lo más nuevo a lo más viejo.
      if (pagadas.isNotEmpty) ...[
        const SizedBox(height: 22),
        _BloqueHeader(
          label: 'Pagadas',
          count: pagadas.length,
          color: AppTheme.good,
        ),
        for (final (mes, delMes)
            in _porMes(pagadas, masRecientePrimero: true)) ...[
          const SizedBox(height: 10),
          _MesHeader(label: _mesLabel(mes)),
          const SizedBox(height: 6),
          ...delMes.map((c) => _fila(c, EstadoPago.aprobado)),
        ],
      ],
    ];
  }

  Widget _fila(CuotaModel c, EstadoPago? estado) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _MiCuotaCard(
          cuota: c,
          estado: estado,
          onTap: () => context.push('/cuota/${c.id}'),
        ),
      );

  // ── Vista de gestión (sólo admin/tesorero) ─────────────────────────────────

  List<Widget> _buildGestion(
    List<CuotaModel> cuotas,
    List<PagoModel> pagos,
    List<MiembroModel> miembros,
    Color gc,
    RolMiembro? rol,
  ) {
    final cuotasMes = cuotas
        .where((c) =>
            c.periodo.year == _selectedMonth.year &&
            c.periodo.month == _selectedMonth.month)
        .toList()
      ..sort((a, b) => a.vencimiento.compareTo(b.vencimiento));

    // Un "cobro" es el par (cuota, miembro alcanzado). Antes se comparaban
    // pagos contra la cantidad de miembros, así que con dos cuotas en el mes
    // el panel podía decir "14/8 miembros pagaron".
    final alcanzadosPorCuota = {
      for (final c in cuotasMes)
        c.id: miembros.where((m) => c.aplicaA(m.uid)).toList(),
    };
    final cobrosEsperados = alcanzadosPorCuota.values
        .fold<int>(0, (s, ms) => s + ms.length);

    int cobros(EstadoPago estado) => cuotasMes.fold<int>(0, (s, c) {
          final uids = alcanzadosPorCuota[c.id]!.map((m) => m.uid).toSet();
          return s +
              pagos
                  .where((p) =>
                      p.cuotaId == c.id &&
                      p.estado == estado &&
                      uids.contains(p.usuarioUid))
                  .length;
        });

    final aprobados = cobros(EstadoPago.aprobado);
    final pendientes =
        cobros(EstadoPago.pendiente) + cobros(EstadoPago.validando);
    final rechazados = cobros(EstadoPago.revision);

    return [
      const SGEyebrow('Gestión del grupo'),
      const SizedBox(height: 12),
      _AdminStatsCard(
        cuotasCount: cuotasMes.length,
        cobrosEsperados: cobrosEsperados,
        aprobados: aprobados,
        pendientes: pendientes,
        rechazados: rechazados,
        gc: gc,
        selectedMonth: _selectedMonth,
        onPrevMonth: _prevMonth,
        onNextMonth: _nextMonth,
        rol: rol,
      ),
      const SizedBox(height: 16),
      if (cuotasMes.isEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
          child: Center(
            child: Text(
              'Sin cuotas con vencimiento en ${_mesLabel(_selectedMonth)}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textMuted),
            ),
          ),
        ),
        if (cuotas.isNotEmpty)
          _OtherMonthsChips(
            cuotas: cuotas,
            selectedMonth: _selectedMonth,
            onMonthTap: (y, m) => setState(() => _selectedMonth = DateTime(y, m)),
          ),
      ] else
        ...cuotasMes.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AdminCuotaRow(
                cuota: c,
                pagosDeCuota: pagos.where((p) => p.cuotaId == c.id).toList(),
                // Sólo los miembros a los que esa cuota les corresponde: un
                // cobro a 3 personas se contaba sobre el padrón entero.
                miembros: alcanzadosPorCuota[c.id]!,
                onTap: () => context.push('/cuota/${c.id}'),
                onEdit: () => context.push('/cuota/${c.id}/edit', extra: c),
                onDelete: () =>
                    _confirmDeleteCuota(context, widget.grupoId, c.id, c.titulo),
              ),
            )),
    ];
  }

  // ── FAB ────────────────────────────────────────────────────────────────────

  Widget _buildFab(
    List<CuotaModel> cuotas,
    List<PagoModel> misPagos,
    String uid,
    bool puedeGestionar,
    Color gc,
  ) {
    if (puedeGestionar) {
      return FloatingActionButton.extended(
        onPressed: () => context.push('/cuotas/crear'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Emitir cuota'),
        backgroundColor: gc,
        foregroundColor: AppTheme.onColor(gc),
      );
    }
    // La más urgente de las impagas que le corresponden, no la primera del
    // grupo: antes podía mandar a pagar una cuota ajena.
    final pendientes = cuotas
        .where((c) =>
            c.activa &&
            c.aplicaA(uid) &&
            _miEstado(c, misPagos) != EstadoPago.aprobado)
        .toList()
      ..sort((a, b) => a.vencimiento.compareTo(b.vencimiento));
    if (pendientes.isEmpty) return const SizedBox.shrink();
    return FloatingActionButton.extended(
      onPressed: () => context.push('/cuota/${pendientes.first.id}'),
      icon: const Icon(Icons.payments_outlined),
      label: const Text('Pagar cuota'),
      backgroundColor: gc,
      foregroundColor: AppTheme.onColor(gc),
    );
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
        title: const Text('Eliminar cuota'),
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
}

// ── Resumen personal ─────────────────────────────────────────────────────────

class _SinCuotasCard extends StatelessWidget {
  const _SinCuotasCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: const Row(children: [
        Icon(Icons.receipt_long_outlined, size: 22, color: AppTheme.textMuted),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Todavía no tenés cuotas',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              SizedBox(height: 2),
              Text('Cuando el administrador emita una, la vas a ver acá.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            ],
          ),
        ),
      ]),
    );
  }
}

class _ResumenPersonalCard extends StatelessWidget {
  final double totalPorPagar;
  final double totalPagado;
  final int cantPorPagar;
  final int cantVencidas;

  const _ResumenPersonalCard({
    required this.totalPorPagar,
    required this.totalPagado,
    required this.cantPorPagar,
    required this.cantVencidas,
  });

  @override
  Widget build(BuildContext context) {
    final alDia = cantPorPagar == 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: alDia ? AppTheme.goodSoft : AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: alDia ? AppTheme.good.withValues(alpha: 0.3) : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            alDia ? 'ESTÁS AL DÍA' : 'TENÉS QUE ABONAR',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: alDia ? AppTheme.goodInk : AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            alDia ? '¡Todo pago!' : '\$ ${_fmtMoney(totalPorPagar.round())}',
            style: GoogleFonts.bricolageGrotesque(
              fontWeight: FontWeight.w800,
              fontSize: 32,
              letterSpacing: -1,
              color: alDia ? AppTheme.goodInk : AppTheme.text,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, children: [
            if (cantVencidas > 0)
              SGChip(
                icon: Icons.error_outline_rounded,
                label: '$cantVencidas vencida${cantVencidas != 1 ? 's' : ''}',
                tone: SGChipTone.danger,
                filled: true,
              ),
            if (cantPorPagar > 0)
              SGChip(
                icon: Icons.schedule_rounded,
                label: '$cantPorPagar por pagar',
                tone: SGChipTone.neutral,
              ),
            if (totalPagado > 0)
              SGChip(
                icon: Icons.check_circle_outline_rounded,
                label: 'Pagaste \$ ${_fmtMoney(totalPagado.round())}',
                tone: SGChipTone.good,
              ),
          ]),
        ],
      ),
    );
  }
}

// ── Encabezados de bloque / mes ──────────────────────────────────────────────

class _BloqueHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _BloqueHeader(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Text(label,
          style: GoogleFonts.bricolageGrotesque(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppTheme.text,
              letterSpacing: -0.2)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('$count',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ),
    ]);
  }
}

class _MesHeader extends StatelessWidget {
  final String label;
  final bool destacado;
  const _MesHeader({required this.label, this.destacado = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: destacado ? AppTheme.danger : AppTheme.textMuted,
        ),
      ),
    );
  }
}

// ── Fila de cuota (vista personal) ───────────────────────────────────────────

class _MiCuotaCard extends StatelessWidget {
  final CuotaModel cuota;
  final EstadoPago? estado;
  final VoidCallback onTap;

  const _MiCuotaCard(
      {required this.cuota, required this.estado, required this.onTap});

  /// Un pago rechazado (`revision`) volvía a contarse como "pagada" y la cuota
  /// desaparecía de lo pendiente. Acá vuelve a estar por pagar, marcada.
  (String, SGChipTone, IconData) _badge() {
    switch (estado) {
      case EstadoPago.aprobado:
        return ('Pagada', SGChipTone.good, Icons.check_circle_rounded);
      case EstadoPago.validando:
      case EstadoPago.pendiente:
        return ('En revisión', SGChipTone.accent, Icons.schedule_rounded);
      case EstadoPago.revision:
        return ('Rechazada', SGChipTone.danger, Icons.error_outline_rounded);
      case null:
        return cuota.estaVencida
            ? ('Vencida', SGChipTone.danger, Icons.error_outline_rounded)
            : ('A pagar', SGChipTone.neutral, Icons.payments_outlined);
    }
  }

  String _vence() {
    if (estado == EstadoPago.aprobado) {
      return 'Venció el ${DateFormat('d/MM/yyyy').format(cuota.vencimiento)}';
    }
    final dias = cuota.diasRestantes;
    if (dias < 0) return 'Venció hace ${-dias} día${dias != -1 ? 's' : ''}';
    if (dias == 0) return 'Vence hoy';
    if (dias == 1) return 'Vence mañana';
    return 'Vence en $dias días';
  }

  @override
  Widget build(BuildContext context) {
    final (label, tone, icon) = _badge();

    return SGCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(cuota.tituloConNumero,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                SGChip(label: label, icon: icon, tone: tone),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(_vence(),
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text('\$ ${_fmtMoney(cuota.monto.round())}',
            style: GoogleFonts.bricolageGrotesque(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppTheme.text)),
        const Icon(Icons.chevron_right_rounded,
            size: 18, color: AppTheme.textMuted),
      ]),
    );
  }
}

// ── Admin stats card ─────────────────────────────────────────────────────────

class _AdminStatsCard extends StatelessWidget {
  final int cuotasCount;
  final int cobrosEsperados;
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
    required this.cobrosEsperados,
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
    final pct = cobrosEsperados > 0
        ? (aprobados / cobrosEsperados).clamp(0.0, 1.0)
        : 0.0;
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
                  const Icon(Icons.manage_accounts_rounded,
                      size: 12, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    rol == RolMiembro.administrador
                        ? 'Panel admin'
                        : 'Gestión de cuotas',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5),
                  ),
                ]),
              ),
              Row(children: [
                GestureDetector(
                  onTap: onPrevMonth,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.chevron_left_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
                Text(_mesLabel(selectedMonth),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                GestureDetector(
                  onTap: onNextMonth,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.chevron_right_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
              ]),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$aprobados / $cobrosEsperados',
            style: GoogleFonts.bricolageGrotesque(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 36,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'cobros confirmados · $cuotasCount ${cuotasCount == 1 ? 'cuota vence' : 'cuotas vencen'} este mes',
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
            _MiniStat(
                color: Colors.white, label: 'Pagaron', value: '$aprobados'),
            const SizedBox(width: 16),
            _MiniStat(
                color: Colors.white70,
                label: 'Por confirmar',
                value: '$pendientes'),
            const SizedBox(width: 16),
            _MiniStat(
                color: Colors.white54, label: 'Rechazados', value: '$rechazados'),
          ]),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final Color color;
  final String label, value;
  const _MiniStat(
      {required this.color, required this.label, required this.value});

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

// ── Other months chips ───────────────────────────────────────────────────────

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
        .map((c) => (c.periodo.year, c.periodo.month))
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
            return InkWell(
              onTap: () => onMonthTap(ym.$1, ym.$2),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text('${_meses[ym.$2 - 1]} ${ym.$1}',
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

// ── Admin cuota row ──────────────────────────────────────────────────────────

class _AdminCuotaRow extends StatefulWidget {
  final CuotaModel cuota;
  final List<PagoModel> pagosDeCuota;
  final List<MiembroModel> miembros;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _AdminCuotaRow({
    required this.cuota,
    required this.pagosDeCuota,
    required this.miembros,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<_AdminCuotaRow> createState() => _AdminCuotaRowState();
}

class _AdminCuotaRowState extends State<_AdminCuotaRow> {
  bool _expanded = false;

  PagoModel? _mejorPago(String uid) =>
      widget.pagosDeCuota.where((p) => p.usuarioUid == uid).fold<PagoModel?>(
        null,
        (best, p) {
          if (best == null) return p;
          const ord = [
            EstadoPago.aprobado,
            EstadoPago.validando,
            EstadoPago.revision,
            EstadoPago.pendiente
          ];
          return ord.indexOf(p.estado) < ord.indexOf(best.estado) ? p : best;
        },
      );

  @override
  Widget build(BuildContext context) {
    final c = widget.cuota;
    final vencida = c.estaVencida;
    final (bg, fg) = c.activa
        ? vencida
            ? (AppTheme.dangerSoft, AppTheme.dangerInk)
            : (AppTheme.goodSoft, AppTheme.goodInk)
        : (AppTheme.surfaceAlt, AppTheme.textMuted);
    final total = widget.miembros.length;
    final pagaron = widget.miembros
        .where((m) => _mejorPago(m.uid)?.estado == EstadoPago.aprobado)
        .length;
    final completa = total > 0 && pagaron == total;

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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: bg, borderRadius: BorderRadius.circular(10)),
                child: Icon(
                  c.activa
                      ? (vencida
                          ? Icons.warning_amber_outlined
                          : Icons.receipt_long_rounded)
                      : Icons.check_circle_outline_rounded,
                  size: 20,
                  color: fg,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.tituloConNumero,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.text),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Row(children: [
                        Text(
                            '${vencida ? 'venció' : 'vence'} ${DateFormat('dd/MM').format(c.vencimiento)}',
                            style: TextStyle(
                                fontSize: 11,
                                color: vencida
                                    ? AppTheme.danger
                                    : AppTheme.textMuted)),
                        if (c.esSegmentada) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.person_outline_rounded,
                              size: 11, color: AppTheme.textMuted),
                          Text(' sólo $total',
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.textMuted)),
                        ],
                      ]),
                    ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('\$ ${_fmtMoney(c.monto.round())}',
                    style: GoogleFonts.bricolageGrotesque(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppTheme.text)),
                Text('$pagaron/$total pagaron',
                    style: TextStyle(
                        fontSize: 10,
                        color: completa ? AppTheme.good : AppTheme.textMuted,
                        fontWeight: FontWeight.w600)),
              ]),
              if (widget.onEdit != null || widget.onDelete != null)
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  iconSize: 20,
                  icon: const Icon(Icons.more_vert_rounded,
                      size: 20, color: AppTheme.textMuted),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  itemBuilder: (_) => [
                    if (widget.onEdit != null)
                      const PopupMenuItem(
                          value: 'editar',
                          child: Row(children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 10),
                            Text('Editar')
                          ])),
                    if (widget.onDelete != null)
                      const PopupMenuItem(
                          value: 'eliminar',
                          child: Row(children: [
                            Icon(Icons.delete_outline_rounded,
                                size: 18, color: AppTheme.danger),
                            SizedBox(width: 10),
                            Text('Eliminar',
                                style: TextStyle(color: AppTheme.danger))
                          ])),
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
          crossFadeState:
              _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
        ),
      ]),
    );
  }

  Widget _buildMemberList() {
    if (widget.miembros.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: Text('Esta cuota no alcanza a ningún miembro',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
      );
    }

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
            Expanded(
                child: Text(m.nombreCompleto,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)),
            if (sub != null)
              Text(sub, style: TextStyle(fontSize: 11, color: color)),
            const SizedBox(width: 6),
            Icon(icon, size: 14, color: color),
          ]),
        );

    final vencida = widget.cuota.estaVencida;

    return Column(children: [
      const Divider(height: 1, color: AppTheme.border, indent: 12, endIndent: 12),
      ...pagaron.map((entry) => memberRow(entry.$1,
          icon: Icons.check_circle_rounded,
          color: AppTheme.good,
          sub: DateFormat('dd/MM').format(entry.$2.updatedAt ?? entry.$2.createdAt))),
      if (pendientes.isNotEmpty) ...[
        if (pagaron.isNotEmpty)
          const Divider(
              height: 1, color: AppTheme.border, indent: 12, endIndent: 12),
        ...pendientes.map((m) => memberRow(m,
            icon: Icons.hourglass_top_rounded,
            color: AppTheme.warning,
            sub: 'Por confirmar')),
      ],
      if (sinPagar.isNotEmpty) ...[
        if (pagaron.isNotEmpty || pendientes.isNotEmpty)
          const Divider(
              height: 1, color: AppTheme.border, indent: 12, endIndent: 12),
        // Antes decía "Sin pagar" incluso para cuotas que todavía no vencieron.
        ...sinPagar.map((m) => memberRow(m,
            icon: vencida ? Icons.close_rounded : Icons.schedule_rounded,
            color: vencida ? AppTheme.danger : AppTheme.textMuted,
            sub: vencida ? 'Adeuda' : 'Sin pagar')),
      ],
    ]);
  }
}
