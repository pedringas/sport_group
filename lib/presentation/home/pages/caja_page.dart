import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../data/models/cuota_model.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/pago_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/cuota_provider.dart';
import '../../../providers/grupo_provider.dart';

// ── Caja ──────────────────────────────────────────────────────────────────────
//
// Panel personal del miembro: sólo sus cuotas del grupo, separadas entre
// pendientes de abonar y ya pagadas. La información de caja del grupo
// (ingresos, gastos, balances entre miembros) es de administración y vive en
// el panel de admin, no acá.

/// ¿Esta cuota me corresponde a mí?
///
/// `miembrosUids` acota el cobro a una lista; `excluidosUids` exceptúa. Si no
/// hay ninguno de los dos, la cuota es para todo el grupo.
bool _meCorresponde(CuotaModel c, String uid) {
  final incluidos = c.miembrosUids;
  if (incluidos != null && incluidos.isNotEmpty) return incluidos.contains(uid);
  final excluidos = c.excluidosUids;
  if (excluidos != null && excluidos.contains(uid)) return false;
  return true;
}

class CajaPage extends ConsumerStatefulWidget {
  const CajaPage({super.key});

  @override
  ConsumerState<CajaPage> createState() => _CajaPageState();
}

class _CajaPageState extends ConsumerState<CajaPage> {
  int _tab = 0; // 0 = Pendientes, 1 = Pagadas

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
    final cuotasAsync = ref.watch(cuotasProvider(kGrupoId));
    final misPagos = ref
            .watch(misPagosGrupoProvider((grupoId: kGrupoId, uid: uid)))
            .valueOrNull ??
        <PagoModel>[];
    final esAdmin = ref.watch(miRolProvider)?.esAdmin ?? false;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        bottom: false,
        child: cuotasAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              const SGErrorState(message: 'Error al cargar tus cuotas'),
          data: (todas) {
            final mias = todas.where((c) => _meCorresponde(c, uid)).toList()
              ..sort((a, b) => b.vencimiento.compareTo(a.vencimiento));

            // Estado de pago propio por cuota.
            EstadoPago? estadoDe(CuotaModel c) {
              final pagos = misPagos.where((p) => p.cuotaId == c.id).toList();
              if (pagos.isEmpty) return null;
              if (pagos.any((p) => p.estado == EstadoPago.aprobado)) {
                return EstadoPago.aprobado;
              }
              return pagos.last.estado;
            }

            final pagadas = mias
                .where((c) => estadoDe(c) == EstadoPago.aprobado)
                .toList();
            final pendientes = mias
                .where((c) =>
                    c.activa && estadoDe(c) != EstadoPago.aprobado)
                .toList();

            final totalPendiente =
                pendientes.fold<double>(0, (s, c) => s + c.monto);
            final totalPagado =
                pagadas.fold<double>(0, (s, c) => s + c.monto);
            final vencidas = pendientes
                .where((c) => c.vencimiento.isBefore(DateTime.now()))
                .length;

            final lista = _tab == 0 ? pendientes : pagadas;

            return CustomScrollView(
              slivers: [
                // ── Encabezado
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mis cuotas',
                          style: GoogleFonts.bricolageGrotesque(
                            fontWeight: FontWeight.w700,
                            fontSize: 28,
                            letterSpacing: -0.6,
                            color: AppTheme.text,
                          ),
                        ),
                        const Text(
                          'Lo que te toca pagar en Tacheros',
                          style: TextStyle(
                              fontSize: 13, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Resumen personal
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _ResumenCard(
                      totalPendiente: totalPendiente,
                      totalPagado: totalPagado,
                      vencidas: vencidas,
                      cantPendientes: pendientes.length,
                    ),
                  ),
                ),

                // ── Pestañas
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Row(children: [
                      _TabBtn(
                        label: 'Pendientes · ${pendientes.length}',
                        selected: _tab == 0,
                        onTap: () => setState(() => _tab = 0),
                      ),
                      const SizedBox(width: 8),
                      _TabBtn(
                        label: 'Pagadas · ${pagadas.length}',
                        selected: _tab == 1,
                        onTap: () => setState(() => _tab = 1),
                      ),
                    ]),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                // ── Lista
                if (lista.isEmpty)
                  SliverToBoxAdapter(
                    child: _Vacio(
                      pendientes: _tab == 0,
                      sinCuotas: mias.isEmpty,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    sliver: SliverList.separated(
                      itemCount: lista.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final c = lista[i];
                        return _CuotaRow(cuota: c, estado: estadoDe(c));
                      },
                    ),
                  ),

                // ── Acceso de administración (sólo admin)
                if (esAdmin)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _AdminLink(),
                    ),
                  ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: AppTheme.kBottomNavPadding),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Resumen ───────────────────────────────────────────────────────────────────

class _ResumenCard extends StatelessWidget {
  final double totalPendiente;
  final double totalPagado;
  final int vencidas;
  final int cantPendientes;

  const _ResumenCard({
    required this.totalPendiente,
    required this.totalPagado,
    required this.vencidas,
    required this.cantPendientes,
  });

  @override
  Widget build(BuildContext context) {
    final alDia = cantPendientes == 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: alDia ? AppTheme.goodSoft : AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: alDia
              ? AppTheme.good.withValues(alpha: 0.3)
              : AppTheme.border,
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
            alDia ? '¡Todo pago!' : _money(totalPendiente),
            style: GoogleFonts.bricolageGrotesque(
              fontWeight: FontWeight.w800,
              fontSize: 32,
              letterSpacing: -1,
              color: alDia ? AppTheme.goodInk : AppTheme.text,
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            if (vencidas > 0) ...[
              SGChip(
                icon: Icons.error_outline_rounded,
                label: '$vencidas vencida${vencidas != 1 ? 's' : ''}',
                tone: SGChipTone.danger,
                filled: true,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              'Pagaste ${_money(totalPagado)} hasta ahora',
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textMuted),
            ),
          ]),
        ],
      ),
    );
  }
}

String _money(double v) =>
    '\$ ${NumberFormat('#,##0', 'es_AR').format(v.round())}';

// ── Fila de cuota ─────────────────────────────────────────────────────────────

class _CuotaRow extends StatelessWidget {
  final CuotaModel cuota;
  final EstadoPago? estado;

  const _CuotaRow({required this.cuota, required this.estado});

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
        final vencida = cuota.vencimiento.isBefore(DateTime.now());
        return vencida
            ? ('Vencida', SGChipTone.danger, Icons.error_outline_rounded)
            : ('A pagar', SGChipTone.neutral, Icons.payments_outlined);
    }
  }

  String _vence() {
    final dias = cuota.vencimiento.difference(DateTime.now()).inDays;
    if (estado == EstadoPago.aprobado) {
      return DateFormat('d MMM yyyy', 'es_AR').format(cuota.vencimiento);
    }
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
      onTap: () => context.push('/cuota/${cuota.id}'),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cuota.titulo,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(children: [
                  SGChip(label: label, icon: icon, tone: tone),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _vence(),
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _money(cuota.monto),
            style: GoogleFonts.bricolageGrotesque(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppTheme.text,
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              size: 18, color: AppTheme.textMuted),
        ],
      ),
    );
  }
}

// ── Estado vacío ──────────────────────────────────────────────────────────────

class _Vacio extends StatelessWidget {
  final bool pendientes;
  final bool sinCuotas;
  const _Vacio({required this.pendientes, required this.sinCuotas});

  @override
  Widget build(BuildContext context) {
    final (icon, titulo, sub) = sinCuotas
        ? (
            Icons.receipt_long_outlined,
            'Todavía no hay cuotas',
            'Cuando el administrador emita una, la vas a ver acá.'
          )
        : pendientes
            ? (
                Icons.check_circle_outline_rounded,
                'No debés nada',
                'Todas tus cuotas están pagas.'
              )
            : (
                Icons.history_rounded,
                'Sin pagos todavía',
                'Acá van a aparecer las cuotas que ya abonaste.'
              );

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppTheme.border),
          const SizedBox(height: 12),
          Text(
            titulo,
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: AppTheme.text),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Acceso de administración ──────────────────────────────────────────────────

class _AdminLink extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/cuotas'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.admin_panel_settings_outlined,
                  size: 18, color: AppTheme.primary),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gestionar cuotas del grupo',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  Text('Emitir, cobrar y validar pagos',
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppTheme.textMuted),
          ]),
        ),
      ),
    );
  }
}

// ── _TabBtn ───────────────────────────────────────────────────────────────────

class _TabBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabBtn(
      {required this.label, required this.selected, required this.onTap});

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
          border:
              Border.all(color: selected ? AppTheme.text : AppTheme.border),
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
