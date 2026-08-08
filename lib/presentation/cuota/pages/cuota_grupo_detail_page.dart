import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/nav_ext.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../data/models/cuota_grupo_model.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/miembro_model.dart';
import '../../../providers/cuota_grupo_provider.dart';
import '../../../providers/cuota_provider.dart';
import '../../../providers/grupo_provider.dart';

const _meses = [
  'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
  'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
];

class CuotaGrupoDetailPage extends ConsumerStatefulWidget {
  final String grupoId;
  final String cuotaGrupoId;

  const CuotaGrupoDetailPage({
    super.key,
    required this.grupoId,
    required this.cuotaGrupoId,
  });

  @override
  ConsumerState<CuotaGrupoDetailPage> createState() =>
      _CuotaGrupoDetailPageState();
}

enum _TabFilter { todos, impagos }

class _CuotaGrupoDetailPageState
    extends ConsumerState<CuotaGrupoDetailPage> {
  DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month);
  _TabFilter _tab = _TabFilter.todos;

  void _prevMes() =>
      setState(() => _mes = DateTime(_mes.year, _mes.month - 1));
  void _nextMes() =>
      setState(() => _mes = DateTime(_mes.year, _mes.month + 1));

  @override
  Widget build(BuildContext context) {
    final gc = ref.watch(grupoColorProvider(widget.grupoId));
    final cuotaGrupo =
        ref.watch(cuotaGruposProvider(widget.grupoId)).valueOrNull?.firstWhere(
              (c) => c.id == widget.cuotaGrupoId,
              orElse: () => CuotaGrupoModel(
                id: '',
                nombre: '',
                descripcion: '',
                montoMensual: 0,
                diaVencimiento: 10,
                miembrosUids: [],
                createdAt: DateTime.now(),
              ),
            );
    final miembros =
        ref.watch(miembrosProvider(widget.grupoId)).valueOrNull ?? [];
    final pagos =
        ref.watch(pagosGrupoProvider(widget.grupoId)).valueOrNull ?? [];

    if (cuotaGrupo == null || cuotaGrupo.id.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final membrosDelGrupo = miembros
        .where((m) => cuotaGrupo.miembrosUids.contains(m.uid))
        .toList();

    // Per-member status for selected month
    final pagosMes = pagos.where((p) =>
        p.createdAt.year == _mes.year && p.createdAt.month == _mes.month);

    MemberStatus statusDe(MiembroModel m) {
      final mp = pagosMes.where((p) => p.usuarioUid == m.uid).toList();
      if (mp.isEmpty) return MemberStatus.sinPagar;
      if (mp.any((p) => p.estado == EstadoPago.aprobado)) {
        return MemberStatus.alDia;
      }
      if (mp.any((p) => p.estado == EstadoPago.pendiente ||
          p.estado == EstadoPago.validando)) {
        return MemberStatus.pendiente;
      }
      return MemberStatus.sinPagar;
    }

    final statusMap = {for (var m in membrosDelGrupo) m: statusDe(m)};
    final alDia = statusMap.values.where((s) => s == MemberStatus.alDia).length;
    final pendientes =
        statusMap.values.where((s) => s == MemberStatus.pendiente).length;
    final sinPagar =
        statusMap.values.where((s) => s == MemberStatus.sinPagar).length;

    final filtered = _tab == _TabFilter.todos
        ? membrosDelGrupo
        : membrosDelGrupo
            .where((m) => statusMap[m] != MemberStatus.alDia)
            .toList();

    final vencimiento = cuotaGrupo.vencimientoFor(_mes.year, _mes.month);
    final vencida = vencimiento.isBefore(DateTime.now());
    final fmt = NumberFormat('#,##0', 'es_AR');

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => context.popOr(),
                  ),
                  Expanded(
                    child: Text(
                      cuotaGrupo.nombre,
                      style: GoogleFonts.bricolageGrotesque(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        letterSpacing: -0.3,
                        color: AppTheme.text,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: () => context.push(
                      '/cuotas/grupo/${widget.cuotaGrupoId}/editar',
                      extra: cuotaGrupo,
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded,
                        size: 20, color: AppTheme.textMuted),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    itemBuilder: (_) => [
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
                    onSelected: (v) {
                      if (v == 'eliminar') _confirmEliminar(cuotaGrupo);
                    },
                  ),
                ],
              ),
            ),

            // Month nav + amount
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _prevMes,
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.chevron_left_rounded,
                                color: AppTheme.textMuted, size: 22),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              '${_meses[_mes.month - 1]} ${_mes.year}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.text,
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _nextMes,
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.chevron_right_rounded,
                                color: AppTheme.textMuted, size: 22),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$ ${fmt.format(cuotaGrupo.montoMensual.toInt())}',
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.text,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            'por miembro · vence día ${cuotaGrupo.diaVencimiento}',
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Stats row
                    Row(
                      children: [
                        _StatChip(
                          label: 'Al día',
                          value: alDia,
                          color: AppTheme.good,
                        ),
                        const SizedBox(width: 8),
                        _StatChip(
                          label: 'Pendientes',
                          value: pendientes,
                          color: AppTheme.warning,
                        ),
                        const SizedBox(width: 8),
                        _StatChip(
                          label: vencida ? 'Vencidos' : 'Sin pagar',
                          value: sinPagar,
                          color: vencida ? AppTheme.danger : AppTheme.textMuted,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _Tab(
                    label: 'Todos',
                    selected: _tab == _TabFilter.todos,
                    gc: gc,
                    onTap: () => setState(() => _tab = _TabFilter.todos),
                  ),
                  const SizedBox(width: 8),
                  _Tab(
                    label: 'Impagos · $sinPagar',
                    selected: _tab == _TabFilter.impagos,
                    gc: gc,
                    onTap: () => setState(() => _tab = _TabFilter.impagos),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Member list
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text('Sin miembros en este filtro',
                          style: TextStyle(color: AppTheme.textMuted)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                          16, 4, 16, AppTheme.kBottomNavPadding + 72),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final m = filtered[i];
                        final status = statusMap[m] ?? MemberStatus.sinPagar;
                        return _MemberRow(
                          miembro: m,
                          status: status,
                          vencida: vencida,
                          onCobrar: () => context.push(
                            '/cuotas/crear',
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: sinPagar > 0
          ? FloatingActionButton.extended(
              onPressed: () => _enviarRecordatorio(membrosDelGrupo, statusMap),
              backgroundColor: gc,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.notifications_outlined),
              label: const Text('Recordatorio'),
            )
          : null,
    );
  }

  void _confirmEliminar(CuotaGrupoModel cuotaGrupo) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar grupo de suscripción'),
        content: Text(
            '¿Eliminás "${cuotaGrupo.nombre}"? Los miembros ya no tendrán esta suscripción asignada.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(cuotaGrupoRepositoryProvider)
                  .deleteCuotaGrupo(widget.grupoId, widget.cuotaGrupoId);
              if (mounted) context.popOr();
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _enviarRecordatorio(
      List<MiembroModel> miembros,
      Map<MiembroModel, MemberStatus> statusMap) {
    final impagos = miembros
        .where((m) => statusMap[m] != MemberStatus.alDia)
        .map((m) => m.nombreCompleto)
        .toList();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Recordatorio enviado a ${impagos.length} miembro${impagos.length != 1 ? 's' : ''} ✓'),
        backgroundColor: AppTheme.good,
      ),
    );
  }
}

enum MemberStatus { alDia, pendiente, sinPagar }

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: 0.8)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool selected;
  final Color gc;
  final VoidCallback onTap;

  const _Tab(
      {required this.label,
      required this.selected,
      required this.gc,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? gc : AppTheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: selected ? gc : AppTheme.border,
              width: selected ? 2 : 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppTheme.text,
          ),
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final MiembroModel miembro;
  final MemberStatus status;
  final bool vencida;
  final VoidCallback onCobrar;

  const _MemberRow({
    required this.miembro,
    required this.status,
    required this.vencida,
    required this.onCobrar,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (status) {
      MemberStatus.alDia => (
          Icons.check_circle_rounded,
          AppTheme.good,
          'Al día'
        ),
      MemberStatus.pendiente => (
          Icons.hourglass_top_rounded,
          AppTheme.warning,
          'En revisión'
        ),
      MemberStatus.sinPagar => vencida
          ? (Icons.warning_amber_rounded, AppTheme.danger, 'Vencido')
          : (Icons.radio_button_unchecked, AppTheme.textMuted, 'Sin pagar'),
    };

    return SGCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          SGAvatar(
              name: miembro.nombreCompleto,
              imageUrl: miembro.avatarUrl,
              size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              miembro.nombreCompleto,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          if (status != MemberStatus.alDia) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onCobrar,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Cobrar',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
