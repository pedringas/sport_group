import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/campana_model.dart';
import '../../../data/models/gasto_model.dart';
import '../../../data/models/grupo_model.dart';
import '../../../data/models/pago_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/campana_provider.dart';
import '../../../providers/cuota_provider.dart';
import '../../../providers/gasto_provider.dart';
import '../../../providers/grupo_provider.dart';
import '../../../data/repositories/gasto_repository.dart';

// ── Caja page ─────────────────────────────────────────────────────────────────

class CajaPage extends ConsumerStatefulWidget {
  const CajaPage({super.key});

  @override
  ConsumerState<CajaPage> createState() => _CajaPageState();
}

class _CajaPageState extends ConsumerState<CajaPage> {
  int _tab = 0; // 0 = Egresos, 1 = Ingresos, 2 = Balance

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
    final grupos = ref.watch(userGruposProvider).valueOrNull ?? [];

    // ── Aggregate egresos ────────────────────────────────────────────────────
    // Suscripciones pagadas (PagoModel aprobados)
    final List<({PagoModel pago, GrupoModel grupo})> suscs = [];
    // Aportes de campañas
    final List<({AporteModel aporte, GrupoModel grupo})> aportes = [];
    // Liquidaciones como deudor (pagué a alguien)
    final List<({LiquidacionModel liq, GrupoModel grupo})> liquidEgreso = [];
    // Liquidaciones como acreedor (alguien me pagó)
    final List<({LiquidacionModel liq, GrupoModel grupo})> liquidIngreso = [];
    // Balance (existing)
    final List<_BalanceItem> debenAMi = [];
    final List<_BalanceItem> deboA = [];
    double totalDebenA = 0;
    double totalDeboA = 0;
    final List<({GrupoModel grupo, double neto})> gruposConBalance = [];

    for (final grupo in grupos) {
      // Suscripciones
      final pagos = ref
          .watch(misPagosAprobadosProvider((grupoId: grupo.id, uid: uid)))
          .valueOrNull ?? [];
      for (final p in pagos) {
        suscs.add((pago: p, grupo: grupo));
      }

      // Aportes a campañas
      final misAportes = ref
          .watch(misAportesGrupoProvider((grupoId: grupo.id, uid: uid)))
          .valueOrNull ?? [];
      for (final a in misAportes) {
        aportes.add((aporte: a, grupo: grupo));
      }

      // Liquidaciones
      final liqs = ref.watch(liquidacionesProvider(grupo.id)).valueOrNull ?? [];
      for (final l in liqs) {
        if (l.deudorUid == uid) {
          liquidEgreso.add((liq: l, grupo: grupo));
        }
        if (l.acreedorUid == uid) {
          liquidIngreso.add((liq: l, grupo: grupo));
        }
      }

      // Balance de gastos (existing logic)
      final balances = ref.watch(balancesProvider(grupo.id));
      final debenVal = GastoRepository.totalDebenA(balances);
      final deboVal = GastoRepository.totalDebeA(balances);
      totalDebenA += debenVal;
      totalDeboA += deboVal;
      for (final b in balances) {
        if (b.monto > 0.5) {
          debenAMi.add(_BalanceItem(grupoId: grupo.id, grupoNombre: grupo.nombre, balance: b));
        } else if (b.monto < -0.5) {
          deboA.add(_BalanceItem(grupoId: grupo.id, grupoNombre: grupo.nombre, balance: b));
        }
      }
      final neto = debenVal - deboVal;
      if (neto.abs() > 0.5) gruposConBalance.add((grupo: grupo, neto: neto));
    }

    // Totals
    final totalSuscs  = suscs.fold<double>(0, (s, e) => s + e.pago.montoEsperado);
    final totalAportes = aportes.fold<double>(0, (s, e) => s + e.aporte.monto);
    final totalLiqEgreso = liquidEgreso.fold<double>(0, (s, e) => s + e.liq.monto);
    final totalLiqIngreso = liquidIngreso.fold<double>(0, (s, e) => s + e.liq.monto);
    final totalEgresos = totalSuscs + totalAportes + totalLiqEgreso;
    final totalIngresos = totalLiqIngreso;
    final netBalance = totalDebenA - totalDeboA;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            // ── Header ─────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  'Caja',
                  style: GoogleFonts.bricolageGrotesque(
                    fontWeight: FontWeight.w700,
                    fontSize: 28,
                    letterSpacing: -0.6,
                    color: AppTheme.text,
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 2, 16, 0),
                child: Text(
                  'Historial financiero de todos tus grupos',
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                ),
              ),
            ),

            // ── Summary bar ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(children: [
                  Expanded(
                    child: _SummaryCard(
                      label: 'Egresos',
                      amount: totalEgresos,
                      color: AppTheme.danger,
                      icon: Icons.arrow_upward_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryCard(
                      label: 'Ingresos',
                      amount: totalIngresos,
                      color: AppTheme.good,
                      icon: Icons.arrow_downward_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryCard(
                      label: 'Balance gastos',
                      amount: netBalance.abs(),
                      color: netBalance >= 0 ? AppTheme.good : AppTheme.danger,
                      icon: netBalance >= 0
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      prefix: netBalance >= 0 ? '+' : '-',
                    ),
                  ),
                ]),
              ),
            ),

            // ── Tabs ────────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(children: [
                  _TabBtn(label: 'Egresos', selected: _tab == 0, onTap: () => setState(() => _tab = 0)),
                  const SizedBox(width: 8),
                  _TabBtn(label: 'Ingresos', selected: _tab == 1, onTap: () => setState(() => _tab = 1)),
                  const SizedBox(width: 8),
                  _TabBtn(label: 'Balance', selected: _tab == 2, onTap: () => setState(() => _tab = 2)),
                ]),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // ── Tab content ──────────────────────────────────────────────────
            if (_tab == 0) ..._buildEgresos(context, suscs, aportes, liquidEgreso),
            if (_tab == 1) ..._buildIngresos(context, liquidIngreso),
            if (_tab == 2) ..._buildBalance(context, debenAMi, deboA, netBalance, gruposConBalance),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  // ── EGRESOS ──────────────────────────────────────────────────────────────────

  List<Widget> _buildEgresos(
    BuildContext context,
    List<({PagoModel pago, GrupoModel grupo})> suscs,
    List<({AporteModel aporte, GrupoModel grupo})> aportes,
    List<({LiquidacionModel liq, GrupoModel grupo})> liquidEgreso,
  ) {
    final sections = <Widget>[];

    // Suscripciones
    sections.add(SliverToBoxAdapter(
      child: _Section(
        title: 'Suscripciones',
        icon: Icons.receipt_long_rounded,
        total: suscs.fold(0, (s, e) => s + e.pago.montoEsperado),
        color: AppTheme.accent,
        emptyText: 'Ningún pago de cuota aprobado aún',
        items: suscs.map((e) => _TxRow(
          title: e.pago.cuotaId.isNotEmpty ? 'Pago de cuota' : 'Pago',
          subtitle: e.grupo.nombre,
          amount: e.pago.montoEsperado,
          date: e.pago.createdAt,
          color: AppTheme.accent,
          onTap: () => context.push('/group/${e.grupo.id}/cuotas'),
        )).toList(),
      ),
    ));

    // Campañas
    sections.add(SliverToBoxAdapter(
      child: _Section(
        title: 'Campañas',
        icon: Icons.campaign_rounded,
        total: aportes.fold(0, (s, e) => s + e.aporte.monto),
        color: AppTheme.primary,
        emptyText: 'Ningún aporte a campañas aún',
        items: aportes.map((e) => _TxRow(
          title: e.aporte.campanaId.isNotEmpty ? 'Aporte a campaña' : 'Aporte',
          subtitle: e.grupo.nombre,
          amount: e.aporte.monto,
          date: e.aporte.createdAt,
          color: AppTheme.primary,
          onTap: () => context.push('/group/${e.grupo.id}/campanas'),
        )).toList(),
      ),
    ));

    // Gastos de grupo (liquidaciones como deudor)
    sections.add(SliverToBoxAdapter(
      child: _Section(
        title: 'Gastos de grupo',
        icon: Icons.group_rounded,
        total: liquidEgreso.fold(0, (s, e) => s + e.liq.monto),
        color: AppTheme.danger,
        emptyText: 'Ninguna liquidación de gasto registrada',
        items: liquidEgreso.map((e) => _TxRow(
          title: 'Le pagué a ${e.liq.acreedorNombre}',
          subtitle: e.grupo.nombre,
          amount: e.liq.monto,
          date: e.liq.createdAt,
          color: AppTheme.danger,
          onTap: () => context.push('/group/${e.grupo.id}/gastos'),
        )).toList(),
      ),
    ));

    return sections;
  }

  // ── INGRESOS ─────────────────────────────────────────────────────────────────

  List<Widget> _buildIngresos(
    BuildContext context,
    List<({LiquidacionModel liq, GrupoModel grupo})> liquidIngreso,
  ) {
    return [
      SliverToBoxAdapter(
        child: _Section(
          title: 'Gastos de grupo',
          icon: Icons.group_rounded,
          total: liquidIngreso.fold(0, (s, e) => s + e.liq.monto),
          color: AppTheme.good,
          emptyText: 'Ningún ingreso por gastos registrado',
          items: liquidIngreso.map((e) => _TxRow(
            title: '${e.liq.deudorNombre} me pagó',
            subtitle: e.grupo.nombre,
            amount: e.liq.monto,
            date: e.liq.createdAt,
            color: AppTheme.good,
            onTap: () => context.push('/group/${e.grupo.id}/gastos'),
          )).toList(),
        ),
      ),
    ];
  }

  // ── BALANCE ──────────────────────────────────────────────────────────────────

  List<Widget> _buildBalance(
    BuildContext context,
    List<_BalanceItem> debenAMi,
    List<_BalanceItem> deboA,
    double netBalance,
    List<({GrupoModel grupo, double neto})> gruposConBalance,
  ) {
    final totalDebenA = debenAMi.fold<double>(0, (s, e) => s + e.balance.monto.abs());
    final totalDeboA  = deboA.fold<double>(0, (s, e) => s + e.balance.monto.abs());

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Row(children: [
            Expanded(child: _SummaryCard(
              label: 'Te deben',
              amount: totalDebenA,
              color: AppTheme.good,
              icon: Icons.arrow_downward_rounded,
            )),
            const SizedBox(width: 10),
            Expanded(child: _SummaryCard(
              label: 'Debés',
              amount: totalDeboA,
              color: AppTheme.danger,
              icon: Icons.arrow_upward_rounded,
            )),
          ]),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 12)),
      if (debenAMi.isNotEmpty) SliverToBoxAdapter(
        child: _Section(
          title: 'Quién te debe',
          icon: Icons.arrow_downward_rounded,
          total: totalDebenA,
          color: AppTheme.good,
          emptyText: '',
          items: debenAMi.map((e) => _TxRow(
            title: e.balance.nombre,
            subtitle: e.grupoNombre,
            amount: e.balance.monto.abs(),
            date: null,
            color: AppTheme.good,
          )).toList(),
        ),
      ),
      if (deboA.isNotEmpty) SliverToBoxAdapter(
        child: _Section(
          title: 'A quién le debés',
          icon: Icons.arrow_upward_rounded,
          total: totalDeboA,
          color: AppTheme.danger,
          emptyText: '',
          items: deboA.map((e) => _TxRow(
            title: e.balance.nombre,
            subtitle: e.grupoNombre,
            amount: e.balance.monto.abs(),
            date: null,
            color: AppTheme.danger,
          )).toList(),
        ),
      ),
      if (debenAMi.isEmpty && deboA.isEmpty) SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.goodSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(children: [
              Icon(Icons.check_circle_rounded, color: AppTheme.good, size: 20),
              SizedBox(width: 10),
              Text('¡Todo saldado! No hay deudas pendientes.',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
          ),
        ),
      ),
    ];
  }
}

// ── _BalanceItem (helper, kept for Balance tab) ───────────────────────────────

class _BalanceItem {
  final String grupoId;
  final String grupoNombre;
  final BalanceConMiembro balance;
  const _BalanceItem({required this.grupoId, required this.grupoNombre, required this.balance});
}

// ── _SummaryCard ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;
  final String prefix;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    this.prefix = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Flexible(child: Text(label,
                style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 4),
          Text(
            '$prefix\$${_fmt(amount)}',
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 15, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) => NumberFormat('#,##0', 'es_AR').format(v.round());
}

// ── _TabBtn ───────────────────────────────────────────────────────────────────

class _TabBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabBtn({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.text : AppTheme.surface,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: selected ? AppTheme.text : AppTheme.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}

// ── _Section (collapsible) ────────────────────────────────────────────────────

class _Section extends StatefulWidget {
  final String title;
  final IconData icon;
  final double total;
  final Color color;
  final String emptyText;
  final List<Widget> items;

  const _Section({
    required this.title,
    required this.icon,
    required this.total,
    required this.color,
    required this.emptyText,
    required this.items,
  });

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final fmt = '\$${NumberFormat('#,##0', 'es_AR').format(widget.total.round())}';
    final isEmpty = widget.items.isEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            InkWell(
              onTap: isEmpty ? null : () => setState(() => _expanded = !_expanded),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(widget.icon, size: 16, color: widget.color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(widget.title,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(fmt,
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700, color: widget.color)),
                  ),
                  if (!isEmpty) ...[
                    const SizedBox(width: 6),
                    Icon(
                      _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      size: 18, color: AppTheme.textMuted,
                    ),
                  ],
                ]),
              ),
            ),

            // Items
            if (!isEmpty && _expanded) ...[
              const Divider(height: 1, color: AppTheme.border),
              ...widget.items,
            ],

            if (isEmpty) ...[
              const Divider(height: 1, color: AppTheme.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Text(widget.emptyText,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── _TxRow ────────────────────────────────────────────────────────────────────

class _TxRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final double amount;
  final DateTime? date;
  final Color color;
  final VoidCallback? onTap;

  const _TxRow({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = date != null
        ? DateFormat('d MMM yyyy', 'es_AR').format(date!)
        : null;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Row(children: [
                  Text(subtitle,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  if (dateStr != null) ...[
                    const Text(' · ', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    Text(dateStr,
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ]),
              ],
            ),
          ),
          Text(
            '\$${NumberFormat('#,##0', 'es_AR').format(amount.round())}',
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14, color: color),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 14, color: AppTheme.textMuted),
          ],
        ]),
      ),
    );
  }
}
