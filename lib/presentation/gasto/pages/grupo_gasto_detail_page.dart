import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/gasto_model.dart';
import '../../../data/repositories/gasto_repository.dart';
import '../../../providers/gasto_provider.dart';
import '../../../providers/grupo_provider.dart';
import '../../../providers/auth_provider.dart';

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Página de detalle de un grupo de gastos
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class GrupoGastoDetailPage extends ConsumerStatefulWidget {
  final String grupoId;
  final String? grupoGastoId; // null → grupo "General"

  const GrupoGastoDetailPage({
    super.key,
    required this.grupoId,
    required this.grupoGastoId,
  });

  @override
  ConsumerState<GrupoGastoDetailPage> createState() =>
      _GrupoGastoDetailPageState();
}

class _GrupoGastoDetailPageState extends ConsumerState<GrupoGastoDetailPage> {
  bool _conciliating = false;

  bool get _esGeneral => widget.grupoGastoId == null;

  // â”€â”€ conciliar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _showConciliarModal(
    BuildContext context,
    List<PagoSugerido> settlements,
    String nombre,
    bool cerrarDespues,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.surf(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _ConciliarSheet(
        settlements: settlements,
        grupoId: widget.grupoId,
        grupoGastoId: widget.grupoGastoId,
        nombre: nombre,
        cerrarDespues: cerrarDespues,
      ),
    );
  }

  Future<void> _confirmarSoloCerrar(BuildContext context, String nombre) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar grupo'),
        content: Text('¿Cerrás "$nombre"? Ya no se podrán agregar gastos.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted || widget.grupoGastoId == null) return;
    setState(() => _conciliating = true);
    try {
      await ref
          .read(grupoGastoNotifierProvider.notifier)
          .cerrar(widget.grupoId, widget.grupoGastoId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Grupo cerrado ✓'),
            backgroundColor: AppTheme.good,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cerrar: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _conciliating = false);
    }
  }

  // â”€â”€ build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  Widget build(BuildContext context) {
    final gc = ref.watch(grupoColorProvider(widget.grupoId));
    final allGastos =
        ref.watch(todosGastosProvider(widget.grupoId)).valueOrNull ?? [];
    final allLiquidaciones =
        ref.watch(liquidacionesProvider(widget.grupoId)).valueOrNull ?? [];
    final gruposGasto =
        ref.watch(gruposGastoProvider(widget.grupoId)).valueOrNull ?? [];
    final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
    final rol =
        ref.watch(miembroActualProvider(widget.grupoId)).valueOrNull?.rol;
    final isStaff = rol?.puedeCerrarGrupoGasto ?? false;

    // â”€â”€ Resolve grupo info â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    final currentGrupo = widget.grupoGastoId == null
        ? null
        : gruposGasto.where((g) => g.id == widget.grupoGastoId).firstOrNull;

    final nombre = _esGeneral ? 'General' : (currentGrupo?.nombre ?? '…');
    final cerrado = currentGrupo?.cerrado ?? false;

    // â”€â”€ Filter movimientos & liquidaciones â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    final movimientos = allGastos
        .where((g) => g.grupoGastoId == widget.grupoGastoId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final liqGrupo = allLiquidaciones
        .where((l) => l.grupoGastoId == widget.grupoGastoId)
        .toList();

    final gastosOnly =
        movimientos.where((g) => g.tipo == TipoMovimiento.gasto).toList();
    final ingresosOnly =
        movimientos.where((g) => g.tipo == TipoMovimiento.ingreso).toList();
    final totalGastos = gastosOnly.fold(0.0, (s, g) => s + g.monto);
    final totalIngresos = ingresosOnly.fold(0.0, (s, g) => s + g.monto);

    // â”€â”€ Participantes set â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    final participantes = <String>{};
    for (final g in gastosOnly) {
      participantes.add(g.pagadorUid);
      for (final p in g.participantes) { participantes.add(p.uid); }
    }

    // â”€â”€ Compute balances â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    final netBalances = GastoRepository.computeNetBalances(
        gastos: gastosOnly, liquidaciones: liqGrupo);
    final settlements = GastoRepository.computeSettlements(netBalances);
    final myBalance = netBalances[uid]?.saldo ?? 0.0;
    final hasDebts = settlements.isNotEmpty;

    final canAdd = !cerrado;

    // â”€â”€ Body â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: _buildAppBar(
          nombre, cerrado, isStaff, context, gc),
      body: movimientos.isEmpty && liqGrupo.isEmpty
          ? _EmptyState(cerrado: cerrado, esGeneral: _esGeneral)
          : _buildBody(
              context: context,
              movimientos: movimientos,
              gastosOnly: gastosOnly,
              totalGastos: totalGastos,
              totalIngresos: totalIngresos,
              participantesCount: participantes.length,
              netBalances: netBalances,
              settlements: settlements,
              myBalance: myBalance,
              uid: uid,
              rol: rol,
              liqGrupo: liqGrupo,
              nombre: nombre,
              isStaff: isStaff,
              cerrado: cerrado,
              hasDebts: hasDebts,
              gc: gc,
            ),
      floatingActionButton: canAdd
          ? FloatingActionButton(
              backgroundColor: gc,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add_rounded),
              onPressed: () => context.push(
                '/group/${widget.grupoId}/gastos/crear',
                extra: _esGeneral
                    ? null
                    : {
                        'grupoGastoId': widget.grupoGastoId,
                        'grupoGastoNombre': nombre,
                      },
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      // Bottom bar: Conciliar button (staff + open)
      bottomNavigationBar:
          isStaff && !cerrado && !_esGeneral
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: hasDebts
                        ? SGPillButton(
                            icon: Icons.balance_rounded,
                            label: _conciliating
                                ? 'Procesando…'
                                : 'Conciliar y cerrar',
                            expand: true,
                            onPressed: _conciliating
                                ? null
                                : () => _showConciliarModal(
                                    context, settlements, nombre, true),
                          )
                        : SGPillButton(
                            icon: Icons.lock_outline_rounded,
                            label: _conciliating
                                ? 'Procesando…'
                                : 'Cerrar grupo (sin deudas)',
                            expand: true,
                            onPressed: _conciliating
                                ? null
                                : () => _confirmarSoloCerrar(context, nombre),
                          ),
                  ),
                )
              : null,
    );
  }

  // â”€â”€ AppBar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  PreferredSizeWidget _buildAppBar(
      String nombre, bool cerrado, bool isStaff, BuildContext context, Color gc) {
    return AppBar(
      backgroundColor: AppTheme.surf(context),
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () =>
            context.canPop() ? context.pop() : context.go('/home'),
      ),
      titleSpacing: 4,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(nombre,
              style: GoogleFonts.bricolageGrotesque(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  letterSpacing: -0.2)),
          if (!_esGeneral)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cerrado ? AppTheme.textMuted : AppTheme.good,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                cerrado ? 'Cerrado' : 'Activo',
                style: TextStyle(
                    fontSize: 11,
                    color:
                        cerrado ? AppTheme.textMuted : AppTheme.good,
                    fontWeight: FontWeight.w600),
              ),
            ]),
        ],
      ),
      actions: [
        if (isStaff && !_esGeneral && cerrado)
          TextButton.icon(
            onPressed: () => ref
                .read(grupoGastoNotifierProvider.notifier)
                .reabrir(widget.grupoId, widget.grupoGastoId!),
            icon: const Icon(Icons.lock_open_rounded, size: 16),
            label: const Text('Reabrir'),
            style: TextButton.styleFrom(
                foregroundColor: gc),
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppTheme.border),
      ),
    );
  }

  // â”€â”€ Body â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildBody({
    required BuildContext context,
    required List<GastoModel> movimientos,
    required List<GastoModel> gastosOnly,
    required double totalGastos,
    required double totalIngresos,
    required int participantesCount,
    required Map<String, ({String nombre, double saldo})> netBalances,
    required List<PagoSugerido> settlements,
    required double myBalance,
    required String uid,
    required RolMiembro? rol,
    required List<LiquidacionModel> liqGrupo,
    required String nombre,
    required bool isStaff,
    required bool cerrado,
    required bool hasDebts,
    required Color gc,
  }) {
    // A member can edit/delete their own gasto; admin/tesorero can edit any.
    bool canEdit(GastoModel g) =>
        g.pagadorUid == uid || (rol?.puedeEditarGasto ?? false);

    return ListView(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, isStaff && !cerrado ? 100 : 32),
      children: [
        // â”€â”€ Stats banner â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        _StatsBanner(
          totalGastos: totalGastos,
          totalIngresos: totalIngresos,
          participantesCount: participantesCount,
          movimientosCount: movimientos.length,
          cerrado: cerrado,
          gc: gc,
        ),
        const SizedBox(height: 20),

        // â”€â”€ Quién pagó â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        if (gastosOnly.isNotEmpty) ...[
          const SGEyebrow('Quién pagó'),
          const SizedBox(height: 8),
          _ContribucionesSection(gastos: gastosOnly, gc: gc),
          const SizedBox(height: 20),
        ],

        // â”€â”€ Balances detallados â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        if (netBalances.length > 1) ...[
          const SGEyebrow('Balances por miembro'),
          const SizedBox(height: 8),
          _BalancesDetalladosCard(
            netBalances: netBalances,
            currentUid: uid,
          ),
          const SizedBox(height: 20),
        ],

        // â”€â”€ Mi posición â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        if (myBalance.abs() > 0.5) ...[
          _MiPosicionCard(
            myBalance: myBalance,
            netBalances: netBalances,
            currentUid: uid,
            grupoId: widget.grupoId,
            grupoGastoId: widget.grupoGastoId,
            miPagado: gastosOnly
                .where((g) => g.pagadorUid == uid)
                .fold(0.0, (s, g) => s + g.monto),
          ),
          const SizedBox(height: 20),
        ] else if (netBalances.isNotEmpty && movimientos.isNotEmpty) ...[
          const _AllSettledBanner(),
          const SizedBox(height: 20),
        ],

        // â”€â”€ Liquidaciones sugeridas â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        if (settlements.isNotEmpty) ...[
          const SGEyebrow('Liquidaciones sugeridas'),
          const SizedBox(height: 6),
          const Text(
            'Para saldar todas las deudas del grupo con el mínimo de pagos:',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 10),
          ...settlements.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _SettlementRow(
                  pago: s,
                  currentUid: uid,
                  grupoId: widget.grupoId,
                  grupoGastoId: widget.grupoGastoId,
                ),
              )),
          const SizedBox(height: 20),
        ],

        // â”€â”€ Movimientos â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        Row(children: [
          const SGEyebrow('Movimientos'),
          const Spacer(),
          Text('${movimientos.length}',
              style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        if (movimientos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                cerrado
                    ? 'Grupo cerrado sin movimientos'
                    : 'Todavía no hay movimientos',
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textMuted),
              ),
            ),
          )
        else
          ...movimientos.map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _MovimientoRow(
                  gasto: g,
                  uid: uid,
                  grupoId: widget.grupoId,
                  canEdit: canEdit(g) && !cerrado,
                ),
              )),
      ],
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Stats banner
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _StatsBanner extends StatelessWidget {
  final double totalGastos, totalIngresos;
  final int participantesCount, movimientosCount;
  final bool cerrado;
  final Color gc;

  const _StatsBanner({
    required this.totalGastos,
    required this.totalIngresos,
    required this.participantesCount,
    required this.movimientosCount,
    required this.cerrado,
    required this.gc,
  });

  String _fmt(double v) => v
      .round()
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');

  @override
  Widget build(BuildContext context) {
    final net = totalIngresos - totalGastos;
    final netPositive = net >= 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: cerrado
              ? [AppTheme.surfaceAlt, AppTheme.surfaceAlt]
              : [gc, Color.lerp(gc, Colors.black, 0.15)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: cerrado
            ? null
            : [
                BoxShadow(
                  color: gc.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main stat: total gastos
          Text(
            '− \$ ${_fmt(totalGastos)}',
            style: GoogleFonts.bricolageGrotesque(
              fontWeight: FontWeight.w800,
              fontSize: 28,
              color: cerrado ? AppTheme.textMuted : Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'en gastos',
            style: TextStyle(
              fontSize: 12,
              color: cerrado
                  ? AppTheme.textMuted
                  : Colors.white.withValues(alpha: 0.75),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          // Secondary stats row
          Row(children: [
            _StatPill(
              label: '${movimientosCount}mov',
              icon: Icons.receipt_long_outlined,
              light: !cerrado,
            ),
            const SizedBox(width: 8),
            _StatPill(
              label: '${participantesCount}pers',
              icon: Icons.people_outline_rounded,
              light: !cerrado,
            ),
            if (totalIngresos > 0) ...[
              const SizedBox(width: 8),
              _StatPill(
                label: '+ \$ ${_fmt(totalIngresos)}',
                icon: Icons.arrow_downward_rounded,
                light: !cerrado,
              ),
            ],
            const Spacer(),
            // Net balance pill
            if (totalGastos > 0 || totalIngresos > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: cerrado
                      ? AppTheme.border
                      : Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  net == 0
                      ? 'Equilibrado'
                      : '${netPositive ? 'Saldo +' : 'Déficit '}\$ ${_fmt(net.abs())}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cerrado
                        ? AppTheme.textMuted
                        : Colors.white,
                  ),
                ),
              ),
          ]),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool light;

  const _StatPill(
      {required this.label, required this.icon, required this.light});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: light
            ? Colors.white.withValues(alpha: 0.15)
            : AppTheme.border,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon,
            size: 11,
            color: light ? Colors.white : AppTheme.textMuted),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: light ? Colors.white : AppTheme.textMuted,
          ),
        ),
      ]),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Mi posición card
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _MiPosicionCard extends ConsumerWidget {
  final double myBalance;
  final Map<String, ({String nombre, double saldo})> netBalances;
  final String currentUid;
  final String grupoId;
  final String? grupoGastoId;
  final double miPagado;

  const _MiPosicionCard({
    required this.myBalance,
    required this.netBalances,
    required this.currentUid,
    required this.grupoId,
    required this.grupoGastoId,
    required this.miPagado,
  });

  String _fmt(double v) => v
      .round()
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iOwe = myBalance < 0; // I owe money
    final amount = myBalance.abs();
    final bg = iOwe ? AppTheme.dangerSoft : AppTheme.goodSoft;
    final textColor =
        iOwe ? const Color(0xFF8C2A14) : const Color(0xFF1F7A5A);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iOwe
                    ? const Color(0xFF8C2A14).withValues(alpha: 0.15)
                    : const Color(0xFF1F7A5A).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                  iOwe
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  color: textColor,
                  size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    iOwe ? 'Tu deuda neta' : 'Te deben en total',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textColor),
                  ),
                  Text(
                    '\$ ${_fmt(amount)}',
                    style: GoogleFonts.bricolageGrotesque(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: textColor,
                        letterSpacing: -0.3),
                  ),
                ],
              ),
            ),
          ]),
          if (miPagado > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Icon(Icons.payments_outlined, size: 14, color: textColor),
                const SizedBox(width: 6),
                Text(
                  'Pagáste \$ ${_fmt(miPagado)} en total',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Balances detallados (expandable)
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _BalancesDetalladosCard extends StatefulWidget {
  final Map<String, ({String nombre, double saldo})> netBalances;
  final String currentUid;

  const _BalancesDetalladosCard(
      {required this.netBalances, required this.currentUid});

  @override
  State<_BalancesDetalladosCard> createState() =>
      _BalancesDetalladosCardState();
}

class _BalancesDetalladosCardState extends State<_BalancesDetalladosCard> {
  bool _expanded = false;

  String _fmt(double v) => v
      .round()
      .abs()
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');

  @override
  Widget build(BuildContext context) {
    // Sort: creditors (saldo > 0) first, then debtors
    final sorted = widget.netBalances.entries.toList()
      ..sort((a, b) => b.value.saldo.compareTo(a.value.saldo));

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.brd(context)),
      ),
      child: Column(
        children: [
          // Header — always visible, tap to expand
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(children: [
                const Icon(Icons.account_balance_wallet_outlined,
                    size: 18, color: AppTheme.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${sorted.length} participantes',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.text,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 22, color: AppTheme.textMuted),
                ),
              ]),
            ),
          ),

          // Expandable list
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                const Divider(height: 1, color: AppTheme.border),
                ...sorted.asMap().entries.map((entry) {
                  final i = entry.key;
                  final uid = entry.value.key;
                  final info = entry.value.value;
                  final saldo = info.saldo;
                  final isMe = uid == widget.currentUid;
                  final isCreditor = saldo > 0.5;
                  final isDebtor = saldo < -0.5;

                  Color? rowBg;
                  Color amtColor;
                  IconData statusIcon;

                  if (isCreditor) {
                    rowBg = null;
                    amtColor = const Color(0xFF1F7A5A);
                    statusIcon = Icons.arrow_downward_rounded;
                  } else if (isDebtor) {
                    rowBg = null;
                    amtColor = const Color(0xFF8C2A14);
                    statusIcon = Icons.arrow_upward_rounded;
                  } else {
                    rowBg = null;
                    amtColor = AppTheme.textMuted;
                    statusIcon = Icons.check_rounded;
                  }

                  return Container(
                    color: rowBg,
                    padding: EdgeInsets.fromLTRB(
                        14, i == 0 ? 12 : 8, 14, 8),
                    child: Row(children: [
                      SGAvatar(
                        name: info.nombre,
                        size: 30,
                        background: isCreditor
                            ? AppTheme.good
                            : isDebtor
                                ? AppTheme.danger
                                : AppTheme.textMuted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Row(children: [
                          Text(
                            info.nombre.split(' ').first,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isMe
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: AppTheme.text,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.brd(context),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'vos',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textMuted,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ]),
                      ),
                      Icon(statusIcon, size: 14, color: amtColor),
                      const SizedBox(width: 4),
                      Text(
                        isCreditor
                            ? 'le deben \$ ${_fmt(saldo)}'
                            : isDebtor
                                ? 'debe \$ ${_fmt(saldo)}'
                                : 'al día',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: amtColor,
                        ),
                      ),
                    ]),
                  );
                }),
                const SizedBox(height: 8),
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

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// All settled banner
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _AllSettledBanner extends StatelessWidget {
  const _AllSettledBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.goodSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(children: [
        Icon(Icons.check_circle_outline_rounded,
            color: AppTheme.good, size: 22),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Todos los saldos están al día ✓',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.good),
          ),
        ),
      ]),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Settlement row (who pays whom)
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _SettlementRow extends ConsumerStatefulWidget {
  final PagoSugerido pago;
  final String currentUid;
  final String grupoId;
  final String? grupoGastoId;

  const _SettlementRow({
    required this.pago,
    required this.currentUid,
    required this.grupoId,
    required this.grupoGastoId,
  });

  @override
  ConsumerState<_SettlementRow> createState() => _SettlementRowState();
}

class _SettlementRowState extends ConsumerState<_SettlementRow> {
  bool _loading = false;

  String _fmt(double v) => v
      .round()
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');

  Future<void> _liquidar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar pago'),
        content: Text(
          '¿Registrar que ${widget.pago.fromNombre} le pagó \$ ${_fmt(widget.pago.monto)} a ${widget.pago.toNombre}?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _loading = true);
    try {
      await ref.read(liquidarProvider.notifier).liquidar(
            grupoId: widget.grupoId,
            deudorUid: widget.pago.fromUid,
            deudorNombre: widget.pago.fromNombre,
            acreedorUid: widget.pago.toUid,
            acreedorNombre: widget.pago.toNombre,
            monto: widget.pago.monto,
            grupoGastoId: widget.grupoGastoId,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Liquidación registrada ✓'),
              backgroundColor: AppTheme.good),
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
    final p = widget.pago;
    final isMyDebt = p.fromUid == widget.currentUid;
    final isMyCredit = p.toUid == widget.currentUid;
    final highlight = isMyDebt || isMyCredit;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: highlight
            ? (isMyDebt ? AppTheme.dangerSoft : AppTheme.goodSoft)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight
              ? (isMyDebt
                  ? const Color(0xFF8C2A14).withValues(alpha: 0.2)
                  : const Color(0xFF1F7A5A).withValues(alpha: 0.2))
              : AppTheme.border,
        ),
      ),
      child: Row(children: [
        SGAvatar(name: p.fromNombre, size: 32),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${p.fromNombre.split(' ').first} → ${p.toNombre.split(' ').first}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isMyDebt
                      ? const Color(0xFF8C2A14)
                      : isMyCredit
                          ? const Color(0xFF1F7A5A)
                          : AppTheme.text,
                ),
              ),
              Text(
                '\$ ${_fmt(p.monto)}',
                style: GoogleFonts.bricolageGrotesque(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: isMyDebt
                      ? const Color(0xFF8C2A14)
                      : isMyCredit
                          ? const Color(0xFF1F7A5A)
                          : AppTheme.text,
                ),
              ),
            ],
          ),
        ),
        SGAvatar(name: p.toNombre, size: 32),
        const SizedBox(width: 8),
        // Liquidar button (only for payer or creditor or staff)
        if (isMyDebt || isMyCredit)
          _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : TextButton(
                  onPressed: _liquidar,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    foregroundColor: isMyDebt
                        ? const Color(0xFF8C2A14)
                        : const Color(0xFF1F7A5A),
                  ),
                  child: Text(
                    isMyDebt ? 'Pagué' : 'Cobré',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
      ]),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Conciliar sheet (modal)
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ConciliarSheet extends ConsumerStatefulWidget {
  final List<PagoSugerido> settlements;
  final String grupoId;
  final String? grupoGastoId;
  final String nombre;
  final bool cerrarDespues;

  const _ConciliarSheet({
    required this.settlements,
    required this.grupoId,
    required this.grupoGastoId,
    required this.nombre,
    required this.cerrarDespues,
  });

  @override
  ConsumerState<_ConciliarSheet> createState() => _ConciliarSheetState();
}

class _ConciliarSheetState extends ConsumerState<_ConciliarSheet> {
  bool _loading = false;

  String _fmt(double v) => v
      .round()
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');

  Future<void> _confirmar() async {
    setState(() => _loading = true);
    try {
      // Register all settlements as liquidaciones
      for (final s in widget.settlements) {
        await ref.read(liquidarProvider.notifier).liquidar(
              grupoId: widget.grupoId,
              deudorUid: s.fromUid,
              deudorNombre: s.fromNombre,
              acreedorUid: s.toUid,
              acreedorNombre: s.toNombre,
              monto: s.monto,
              grupoGastoId: widget.grupoGastoId,
            );
      }
      // Close the group
      if (widget.cerrarDespues && widget.grupoGastoId != null) {
        await ref
            .read(grupoGastoNotifierProvider.notifier)
            .cerrar(widget.grupoId, widget.grupoGastoId!);
      }
      if (mounted) {
        // Grab the messenger BEFORE popping so the snackbar lands on the
        // parent scaffold, not on the now-dismissed sheet's context.
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(widget.cerrarDespues
                ? 'Grupo conciliado y cerrado ✓'
                : 'Deudas liquidadas ✓'),
            backgroundColor: AppTheme.good,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            widget.cerrarDespues
                ? 'Conciliar y cerrar'
                : 'Conciliar deudas',
            style: GoogleFonts.bricolageGrotesque(
                fontWeight: FontWeight.w700, fontSize: 20),
          ),
          const SizedBox(height: 4),
          Text(
            widget.cerrarDespues
                ? 'Se registrarán los siguientes pagos y el grupo "${widget.nombre}" quedará cerrado.'
                : 'Se registrarán los siguientes pagos para saldar todas las deudas.',
            style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 16),
          if (widget.settlements.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Row(children: [
                Icon(Icons.check_circle_outline_rounded,
                    color: AppTheme.good),
                SizedBox(width: 10),
                Text('No hay deudas pendientes.',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.good)),
              ]),
            )
          else
            ...widget.settlements.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    SGAvatar(name: s.fromNombre, size: 34),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${s.fromNombre.split(' ').first} le paga a ${s.toNombre.split(' ').first}',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                          Text('\$ ${_fmt(s.monto)}',
                              style: GoogleFonts.bricolageGrotesque(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: const Color(0xFF8C2A14))),
                        ],
                      ),
                    ),
                    SGAvatar(name: s.toNombre, size: 34),
                  ]),
                )),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _loading
                    ? null
                    : () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _loading ? null : _confirmar,
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Icon(widget.cerrarDespues
                        ? Icons.lock_outline_rounded
                        : Icons.balance_rounded),
                label: Text(_loading
                    ? 'Procesando…'
                    : widget.cerrarDespues
                        ? 'Confirmar y cerrar'
                        : 'Confirmar'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Movimiento row  (with edit / delete menu for authorised users)
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _MovimientoRow extends ConsumerStatefulWidget {
  final GastoModel gasto;
  final String uid;
  final String grupoId;
  final bool canEdit;

  const _MovimientoRow({
    required this.gasto,
    required this.uid,
    required this.grupoId,
    required this.canEdit,
  });

  @override
  ConsumerState<_MovimientoRow> createState() => _MovimientoRowState();
}

class _MovimientoRowState extends ConsumerState<_MovimientoRow> {
  bool _deleting = false;

  String _fmt(double v) => v
      .round()
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');

  Future<void> _confirmarEliminar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar movimiento'),
        content: Text(
            '¿Eliminar "${widget.gasto.titulo}"? Esta acción no se puede deshacer.'),
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
    if (ok != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await ref.read(gastoRepositoryProvider).deleteGasto(
            widget.grupoId,
            widget.gasto.id,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppTheme.danger),
        );
        setState(() => _deleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gasto = widget.gasto;
    final isPayer = gasto.pagadorUid == widget.uid;
    final isIngreso = gasto.tipo == TipoMovimiento.ingreso;
    String dateLabel;
    try {
      dateLabel = DateFormat('d MMM', 'es_AR').format(gasto.createdAt);
    } catch (_) {
      dateLabel = DateFormat('d MMM').format(gasto.createdAt);
    }

    return Container(
      padding: EdgeInsets.fromLTRB(12, 12, widget.canEdit ? 6 : 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(children: [
        // Category icon
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isIngreso
                ? AppTheme.goodSoft
                : isPayer
                    ? AppTheme.dangerSoft
                    : AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(gasto.categoria.emoji,
                style: const TextStyle(fontSize: 18)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(gasto.titulo,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(
                '$dateLabel · ${gasto.pagadorNombre.split(' ').first}',
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Amount
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isIngreso ? '+' : '−'} \$ ${_fmt(gasto.monto)}',
              style: GoogleFonts.bricolageGrotesque(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: isIngreso
                    ? const Color(0xFF1F7A5A)
                    : isPayer
                        ? const Color(0xFF8C2A14)
                        : AppTheme.text,
              ),
            ),
            Text(
              gasto.tipo.label,
              style: const TextStyle(
                  fontSize: 10, color: AppTheme.textMuted),
            ),
          ],
        ),
        // Edit / delete menu
        if (widget.canEdit) ...[
          const SizedBox(width: 4),
          if (_deleting)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppTheme.textMuted),
            )
          else
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              iconSize: 20,
              icon: const Icon(Icons.more_vert_rounded,
                  size: 20, color: AppTheme.textMuted),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'editar',
                  child: Row(children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Editar'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'eliminar',
                  child: Row(children: [
                    Icon(Icons.delete_outline_rounded,
                        size: 18, color: AppTheme.danger),
                    SizedBox(width: 10),
                    Text('Eliminar',
                        style: TextStyle(color: AppTheme.danger)),
                  ]),
                ),
              ],
              onSelected: (val) {
                if (val == 'editar') {
                  context.push(
                    '/group/${widget.grupoId}/gastos/crear',
                    extra: {'gastoExistente': gasto},
                  );
                } else if (val == 'eliminar') {
                  _confirmarEliminar();
                }
              },
            ),
        ],
      ]),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Contribuciones por miembro
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ContribucionesSection extends StatelessWidget {
  final List<GastoModel> gastos;
  final Color gc;

  const _ContribucionesSection({required this.gastos, required this.gc});

  String _fmt(double v) => v
      .round()
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');

  @override
  Widget build(BuildContext context) {
    // Aggregate total paid per pagadorUid
    final Map<String, ({String nombre, double total})> map = {};
    for (final g in gastos) {
      if (g.tipo != TipoMovimiento.gasto) continue;
      final cur = map[g.pagadorUid]?.total ?? 0.0;
      map[g.pagadorUid] = (nombre: g.pagadorNombre, total: cur + g.monto);
    }
    if (map.isEmpty) return const SizedBox.shrink();

    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));
    final grand = sorted.fold(0.0, (s, e) => s + e.value.total);
    if (grand <= 0) return const SizedBox.shrink();

    final maxVal = sorted.first.value.total;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: sorted.asMap().entries.map((entry) {
          final i = entry.key;
          final e = entry.value;
          final pct = grand > 0
              ? (e.value.total / grand * 100).round()
              : 0;
          final barFrac = maxVal > 0 ? (e.value.total / maxVal) : 0.0;
          final isTop = i == 0;

          return Column(
            children: [
              if (i > 0) ...[
                const Divider(height: 20, color: AppTheme.border),
              ],
              Row(
                children: [
                  SGAvatar(name: e.value.nombre, size: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                e.value.nombre.split(' ').first,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            Text(
                              '\$ ${_fmt(e.value.total)}',
                              style: GoogleFonts.bricolageGrotesque(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.text,
                              ),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 32,
                              child: Text(
                                '$pct%',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textMuted,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: barFrac,
                            backgroundColor: AppTheme.border,
                            color: isTop
                                ? gc
                                : gc.withValues(alpha: 0.45 + 0.35 * barFrac),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Empty state
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _EmptyState extends StatelessWidget {
  final bool cerrado, esGeneral;
  const _EmptyState({required this.cerrado, required this.esGeneral});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              cerrado
                  ? Icons.lock_outline_rounded
                  : Icons.receipt_long_outlined,
              size: 56,
              color: AppTheme.border,
            ),
            const SizedBox(height: 12),
            Text(
              cerrado
                  ? 'Grupo cerrado sin movimientos'
                  : 'Sin movimientos todavía',
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted),
              textAlign: TextAlign.center,
            ),
            if (!cerrado && !esGeneral) ...[
              const SizedBox(height: 6),
              const Text(
                'Tocá + para agregar el primer gasto.',
                style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
