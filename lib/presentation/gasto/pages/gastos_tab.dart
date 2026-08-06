import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/gasto_model.dart';
import '../../../data/models/grupo_gasto_model.dart';
import '../../../providers/gasto_provider.dart';
import '../../../providers/grupo_provider.dart';
// â”€â”€ Selected month provider â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final _selectedMonthProvider =
    StateProvider.family<DateTime, String>((ref, grupoId) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

// Computed: gruposGasto filtered for the selected month.
// Open groups always show; closed groups only in months they were active.
final _gruposGastoFiltradosProvider =
    Provider.family<List<GrupoGastoModel>, String>((ref, grupoId) {
  final all = ref.watch(gruposGastoProvider(grupoId)).valueOrNull ?? [];
  final sel = ref.watch(_selectedMonthProvider(grupoId));
  final selYM = DateTime(sel.year, sel.month);
  return all.where((g) {
    if (!g.cerrado) return true;
    final createdYM = DateTime(g.createdAt.year, g.createdAt.month);
    final closedYM = g.cerradoAt != null
        ? DateTime(g.cerradoAt!.year, g.cerradoAt!.month)
        : createdYM;
    return !selYM.isBefore(createdYM) && !selYM.isAfter(closedYM);
  }).toList();
});

// Computed: total of gasto-type movements for the selected month.
final _totalGastosMesProvider =
    Provider.family<double, String>((ref, grupoId) {
  final all = ref.watch(todosGastosProvider(grupoId)).valueOrNull ?? [];
  final sel = ref.watch(_selectedMonthProvider(grupoId));
  return all
      .where((g) =>
          g.createdAt.year == sel.year &&
          g.createdAt.month == sel.month &&
          g.tipo == TipoMovimiento.gasto)
      .fold(0.0, (s, g) => s + g.monto);
});

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Main tab
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class GastosTab extends ConsumerWidget {
  final String grupoId;
  const GastosTab({super.key, required this.grupoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gc = ref.watch(grupoColorProvider(grupoId));
    final selectedMonth = ref.watch(_selectedMonthProvider(grupoId));
    final todosGastosAsync = ref.watch(todosGastosProvider(grupoId));
    final gruposGastoAsync = ref.watch(gruposGastoProvider(grupoId));
    final rol = ref.watch(miembroActualProvider(grupoId)).valueOrNull?.rol;
    final isStaff = rol?.puedeCerrarGrupoGasto ?? false;

    final allGastos = todosGastosAsync.valueOrNull ?? [];

    final gruposGasto = ref.watch(_gruposGastoFiltradosProvider(grupoId));
    final totalGastosMes = ref.watch(_totalGastosMesProvider(grupoId));
    final isDesktop = MediaQuery.sizeOf(context).width >= AppTheme.kResponsiveBreakpoint;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: isDesktop ? null : AppBar(
        backgroundColor: AppTheme.surf(context),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        titleSpacing: 4,
        title: Text(
          'Gastos',
          style: GoogleFonts.bricolageGrotesque(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          if (isStaff)
            IconButton(
              icon: const Icon(Icons.create_new_folder_outlined, size: 22),
              tooltip: 'Nuevo grupo',
              onPressed: () => _showCrearGrupoSheet(context, ref, grupoId),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.border),
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, AppTheme.kBottomNavPadding),
        children: [
          // â”€â”€ Month navigator â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          _MonthSwitcher(
            month: selectedMonth,
            onPrev: () => ref
                .read(_selectedMonthProvider(grupoId).notifier)
                .state = DateTime(selectedMonth.year, selectedMonth.month - 1),
            onNext: () {
              final next =
                  DateTime(selectedMonth.year, selectedMonth.month + 1);
              final now = DateTime.now();
              if (next.isBefore(DateTime(now.year, now.month + 1))) {
                ref
                    .read(_selectedMonthProvider(grupoId).notifier)
                    .state = next;
              }
            },
          ),

          const SizedBox(height: 12),

          // â”€â”€ Summary card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          _TotalCard(
            label: 'GASTOS DEL MES',
            amount: totalGastosMes,
            icon: Icons.arrow_upward_rounded,
            positive: false,
          ),

          const SizedBox(height: 28),

          // â”€â”€ Grupos de gastos section header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Row(
            children: [
              const SGEyebrow('Grupos de gastos'),
              const Spacer(),
              if (isStaff)
                GestureDetector(
                  onTap: () => _showCrearGrupoSheet(context, ref, grupoId),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: gc.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.add_rounded,
                            size: 14, color: gc),
                        const SizedBox(width: 4),
                        Text(
                          'Nuevo',
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: gc,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),


          // â”€â”€ Created expense groups â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          ...gruposGasto.map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _GrupoGastoTile(
                  grupoId: grupoId,
                  grupoGastoId: g.id,
                  nombre: g.nombre,
                  cerrado: g.cerrado,
                  allGastos: allGastos,
                  gc: gc,
                  onTap: () =>
                      context.push('/group/$grupoId/gastos/g/${g.id}'),
                ),
              )),
        ],
      ),

      // â”€â”€ FAB â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      floatingActionButton: FloatingActionButton(
        backgroundColor: gc,
        foregroundColor: Colors.white,
        onPressed: () {
          final active = gruposGasto.where((g) => !g.cerrado).toList();
          if (active.isEmpty) {
            _showCrearGrupoSheet(context, ref, grupoId);
          } else {
            _onFabPressed(context, active, gc);
          }
        },
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  // â”€â”€ FAB: pick group then navigate to crear â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _onFabPressed(BuildContext context, List<GrupoGastoModel> activeGrupos, Color gc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                '¿A qué grupo?',
                style: GoogleFonts.bricolageGrotesque(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
            ),
            ...activeGrupos.map((g) => ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: gc.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.folder_rounded,
                        size: 18, color: gc),
                  ),
                  title: Text(g.nombre,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    context.push(
                      '/group/$grupoId/gastos/crear',
                      extra: {
                        'grupoGastoId': g.id,
                        'grupoGastoNombre': g.nombre,
                      },
                    );
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // â”€â”€ Create group sheet â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _showCrearGrupoSheet(
      BuildContext context, WidgetRef ref, String gId) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20, 20, 20,
          MediaQuery.viewInsetsOf(ctx).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nuevo grupo de gastos',
              style: GoogleFonts.bricolageGrotesque(
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Usá grupos para organizar gastos por evento: asados, viajes, torneos...',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Nombre del grupo',
                hintText: 'Ej: Asado del viernes',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            Consumer(builder: (_, r, __) {
              return SGPillButton(
                label: 'Crear grupo',
                icon: Icons.add_rounded,
                expand: true,
                onPressed: () async {
                  if (ctrl.text.trim().isEmpty) return;
                  await r
                      .read(grupoGastoNotifierProvider.notifier)
                      .crear(grupoId: gId, nombre: ctrl.text.trim());
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Compact grupo de gasto tile
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _GrupoGastoTile extends StatelessWidget {
  final String grupoId;
  final String? grupoGastoId; // null = General
  final String nombre;
  final bool cerrado;
  final List<GastoModel> allGastos;
  final Color gc;
  final VoidCallback onTap;

  const _GrupoGastoTile({
    required this.grupoId,
    required this.grupoGastoId,
    required this.nombre,
    required this.cerrado,
    required this.allGastos,
    required this.gc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final movimientos =
        allGastos.where((g) => g.grupoGastoId == grupoGastoId).toList();
    final totalGastos = movimientos
        .where((g) => g.tipo == TipoMovimiento.gasto)
        .fold(0.0, (s, g) => s + g.monto);
    final totalIngresos = movimientos
        .where((g) => g.tipo == TipoMovimiento.ingreso)
        .fold(0.0, (s, g) => s + g.monto);

    final isGeneral = grupoGastoId == null;

    final iconBg = cerrado
        ? AppTheme.surfaceAlt
        : isGeneral
            ? AppTheme.accentSoft
            : gc.withValues(alpha: 0.12);
    final iconColor = cerrado
        ? AppTheme.textMuted
        : isGeneral
            ? AppTheme.accent
            : gc;
    final iconData = cerrado
        ? Icons.folder_off_outlined
        : isGeneral
            ? Icons.inbox_rounded
            : Icons.folder_rounded;

    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              // â”€â”€ Folder icon â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(iconData, size: 20, color: iconColor),
              ),

              const SizedBox(width: 12),

              // â”€â”€ Name + meta â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            nombre,
                            style: GoogleFonts.bricolageGrotesque(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: cerrado
                                  ? AppTheme.textMuted
                                  : AppTheme.text,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (cerrado) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceAlt,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Cerrado',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      movimientos.isEmpty
                          ? 'Sin movimientos'
                          : '${movimientos.length} movimiento${movimientos.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),

              // â”€â”€ Amounts â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              if (totalGastos > 0 || totalIngresos > 0) ...[
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (totalGastos > 0)
                      Text(
                        '− \$ ${_fmt(totalGastos)}',
                        style: GoogleFonts.bricolageGrotesque(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTheme.dangerInk,
                        ),
                      ),
                    if (totalIngresos > 0)
                      Text(
                        '+ \$ ${_fmt(totalIngresos)}',
                        style: GoogleFonts.bricolageGrotesque(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTheme.goodInk,
                        ),
                      ),
                  ],
                ),
              ],

              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppTheme.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(double v) => v
      .round()
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Month switcher
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _MonthSwitcher extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _MonthSwitcher({
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    String label;
    try {
      label = DateFormat('MMMM yyyy', 'es_AR').format(month);
    } catch (_) {
      label = DateFormat('MMMM yyyy').format(month);
    }
    final labelCap = label.isNotEmpty
        ? label[0].toUpperCase() + label.substring(1)
        : label;

    final isCurrentMonth = month.year == DateTime.now().year &&
        month.month == DateTime.now().month;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 24),
            onPressed: onPrev,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            color: AppTheme.textMuted,
          ),
          Text(
            labelCap,
            style: GoogleFonts.bricolageGrotesque(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              letterSpacing: -0.2,
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.chevron_right_rounded,
              size: 24,
              color: isCurrentMonth ? AppTheme.border : AppTheme.textMuted,
            ),
            onPressed: isCurrentMonth ? null : onNext,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Total card
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _TotalCard extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final bool positive;

  const _TotalCard({
    required this.label,
    required this.amount,
    required this.icon,
    required this.positive,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = amount == 0;
    final bg = isEmpty
        ? AppTheme.surfaceAlt
        : positive
            ? AppTheme.goodSoft
            : AppTheme.dangerSoft;
    final textColor = isEmpty
        ? AppTheme.textMuted
        : positive
            ? AppTheme.goodInk
            : AppTheme.dangerInk;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: textColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isEmpty ? '\$ 0' : '${positive ? '+' : '−'} \$ ${_fmt(amount)}',
            style: GoogleFonts.bricolageGrotesque(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: textColor,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) => v
      .round()
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
}

