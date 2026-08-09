import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/nav_ext.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../data/models/cuota_model.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/miembro_model.dart';
import '../../../providers/cuota_grupo_provider.dart';
import '../../../providers/cuota_provider.dart';
import '../../../providers/grupo_provider.dart';

const _meses = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
];

class SuscripcionesPage extends ConsumerStatefulWidget {
  final String grupoId;
  const SuscripcionesPage({super.key, required this.grupoId});

  @override
  ConsumerState<SuscripcionesPage> createState() => _SuscripcionesPageState();
}

class _SuscripcionesPageState extends ConsumerState<SuscripcionesPage> {
  DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month);

  void _prevMes() =>
      setState(() => _mes = DateTime(_mes.year, _mes.month - 1));
  void _nextMes() =>
      setState(() => _mes = DateTime(_mes.year, _mes.month + 1));

  @override
  Widget build(BuildContext context) {
    final gc = ref.watch(grupoColorProvider(widget.grupoId));
    final cuotas = ref.watch(cuotasProvider(widget.grupoId)).valueOrNull ?? [];
    final pagos = ref.watch(pagosGrupoProvider(widget.grupoId)).valueOrNull ?? [];
    final miembros =
        ref.watch(miembrosProvider(widget.grupoId)).valueOrNull ?? <MiembroModel>[];
    final cuotaGrupos =
        ref.watch(cuotaGruposProvider(widget.grupoId)).valueOrNull ?? [];

    final fmt = NumberFormat('#,##0', 'es_AR');

    // Stats for current month
    final cuotasMes = cuotas.where((c) =>
        c.vencimiento.year == _mes.year &&
        c.vencimiento.month == _mes.month).toList();

    final pagosMes = pagos.where((p) =>
        p.createdAt.year == _mes.year &&
        p.createdAt.month == _mes.month).toList();

    final cobrado = pagosMes
        .where((p) => p.estado == EstadoPago.aprobado)
        .fold(0.0, (s, p) => s + p.montoEsperado);

    final porValidar = pagosMes
        .where((p) =>
            p.estado == EstadoPago.validando ||
            p.estado == EstadoPago.revision)
        .length;

    final pagaron = pagosMes
        .where((p) => p.estado == EstadoPago.aprobado)
        .map((p) => p.usuarioUid)
        .toSet()
        .length;

    final totalMiembros = miembros.isNotEmpty ? miembros.length : 1;
    final pct = (pagaron / totalMiembros).clamp(0.0, 1.0);

    final mesLabel = '${_meses[_mes.month - 1]} ${_mes.year}';

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => context.popOr(),
                    ),
                    Expanded(
                      child: Text(
                        'Cobranza',
                        style: GoogleFonts.bricolageGrotesque(
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                          letterSpacing: -0.3,
                          color: AppTheme.text,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_rounded),
                      tooltip: 'Nueva cuota',
                      onPressed: () => context
                          .push('/cuotas/crear'),
                    ),
                  ],
                ),
              ),
            ),

            // Month nav + cobrado card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _CobradoCard(
                  mesLabel: mesLabel,
                  cobrado: cobrado,
                  pct: pct,
                  pagaron: pagaron,
                  totalMiembros: totalMiembros,
                  porValidar: porValidar,
                  gc: gc,
                  fmt: fmt,
                  onPrev: _prevMes,
                  onNext: _nextMes,
                ),
              ),
            ),

            // Warning banner if pending
            if (porValidar > 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: GestureDetector(
                    // El rol Tesorero está en pausa: valida el administrador.
                    onTap: () => context.push('/admin'),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppTheme.warning.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.hourglass_top_rounded,
                              size: 16, color: AppTheme.warning),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$porValidar comprobante${porValidar != 1 ? 's' : ''} por validar',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.warning,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              size: 16, color: AppTheme.warning),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // "Grupos de suscripción" en pausa: se pueden crear pero nada
            // los convierte en cuotas, así que nunca cobran. Sección oculta
            // hasta que exista la emisión automática.

            // Cuotas emitidas section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Row(
                  children: [
                    const SGEyebrow('Cuotas emitidas'),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceAlt,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(mesLabel,
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),

            if (cuotasMes.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 18, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Sin cuotas en este mes',
                            style: TextStyle(
                                fontSize: 13, color: AppTheme.textMuted),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.push(
                              '/cuotas/crear'),
                          child: Text('Emitir cuota',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: gc)),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.separated(
                  itemCount: cuotasMes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final c = cuotasMes[i];
                    final pagosDeCuota =
                        pagos.where((p) => p.cuotaId == c.id).toList();
                    final aprobados = pagosDeCuota
                        .where((p) => p.estado == EstadoPago.aprobado)
                        .length;
                    final pendientesC = pagosDeCuota
                        .where((p) => p.estado == EstadoPago.pendiente ||
                            p.estado == EstadoPago.validando)
                        .length;
                    return _CuotaRow(
                      cuota: c,
                      aprobados: aprobados,
                      pendientes: pendientesC,
                      total: totalMiembros,
                      gc: gc,
                      fmt: fmt,
                      onTap: () => context.push(
                          '/cuota/${c.id}'),
                    );
                  },
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.push('/cuotas/crear'),
        backgroundColor: gc,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Emitir cuota'),
      ),
    );
  }
}

// Cobrado Card

class _CobradoCard extends StatelessWidget {
  final String mesLabel;
  final double cobrado;
  final double pct;
  final int pagaron;
  final int totalMiembros;
  final int porValidar;
  final Color gc;
  final NumberFormat fmt;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _CobradoCard({
    required this.mesLabel,
    required this.cobrado,
    required this.pct,
    required this.pagaron,
    required this.totalMiembros,
    required this.porValidar,
    required this.gc,
    required this.fmt,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month nav
          Row(
            children: [
              GestureDetector(
                onTap: onPrev,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(Icons.chevron_left_rounded,
                      color: Colors.white.withValues(alpha: 0.5), size: 22),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    mesLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: onNext,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(Icons.chevron_right_rounded,
                      color: Colors.white.withValues(alpha: 0.5), size: 22),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Cobrado label
          Text(
            'COBRADO',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.5),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '\$ ${fmt.format(cobrado.toInt())}',
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1,
              height: 1,
            ),
          ),

          const SizedBox(height: 14),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(gc),
            ),
          ),

          const SizedBox(height: 10),

          // Stats row
          Row(
            children: [
              _CardStat(
                  label: 'Pagaron',
                  value: '$pagaron / $totalMiembros',
                  color: Colors.white),
              const SizedBox(width: 20),
              if (porValidar > 0)
                _CardStat(
                    label: 'Por validar',
                    value: '$porValidar',
                    color: AppTheme.warning)
              else
                _CardStat(
                    label: 'Impagos',
                    value: '${totalMiembros - pagaron}',
                    color: Colors.white.withValues(alpha: 0.5)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _CardStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: GoogleFonts.bricolageGrotesque(
                color: color, fontWeight: FontWeight.w700, fontSize: 16)),
        Text(label,
            style: TextStyle(
                color: color.withValues(alpha: 0.7),
                fontSize: 10,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// CuotaGrupo Card

class _CuotaGrupoCard extends StatelessWidget {
  final String grupoId;
  final String id;
  final String nombre;
  final double monto;
  final int miembros;
  final int diaVencimiento;
  final Color gc;
  final NumberFormat fmt;

  const _CuotaGrupoCard({
    required this.grupoId,
    required this.id,
    required this.nombre,
    required this.monto,
    required this.miembros,
    required this.diaVencimiento,
    required this.gc,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return SGCard(
      padding: const EdgeInsets.all(14),
      onTap: () =>
          context.push('/cuotas/grupo/$id'),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: gc.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.repeat_rounded, size: 22, color: gc),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
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

// Cuota Row

class _CuotaRow extends StatelessWidget {
  final CuotaModel cuota;
  final int aprobados;
  final int pendientes;
  final int total;
  final Color gc;
  final NumberFormat fmt;
  final VoidCallback onTap;

  const _CuotaRow({
    required this.cuota,
    required this.aprobados,
    required this.pendientes,
    required this.total,
    required this.gc,
    required this.fmt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final vencida =
        cuota.vencimiento.isBefore(DateTime.now()) && cuota.activa;
    final (iconColor, bgColor) = vencida
        ? (AppTheme.danger, AppTheme.dangerSoft)
        : aprobados == total && total > 0
            ? (AppTheme.good, AppTheme.goodSoft)
            : (AppTheme.warning, AppTheme.warningSoft);

    return SGCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(Icons.payments_outlined, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cuota.tituloConNumero,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Vence ${DateFormat('dd/MM').format(cuota.vencimiento)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: vencida ? AppTheme.danger : AppTheme.textMuted,
                    fontWeight:
                        vencida ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
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
                    color: AppTheme.text),
              ),
              Text(
                '$aprobados / $total pagaron',
                style: TextStyle(
                  fontSize: 10,
                  color: aprobados == total && total > 0
                      ? AppTheme.good
                      : AppTheme.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded,
              size: 16, color: AppTheme.textMuted),
        ],
      ),
    );
  }
}
