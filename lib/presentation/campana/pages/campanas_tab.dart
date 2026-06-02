import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../data/models/campana_model.dart';
import '../../../data/models/enums.dart';
import '../../../providers/campana_provider.dart';
import '../../../providers/grupo_provider.dart';

class CampanasTab extends ConsumerWidget {
  final String grupoId;
  const CampanasTab({super.key, required this.grupoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campanasAsync = ref.watch(campanasProvider(grupoId));
    final miembroAsync = ref.watch(miembroActualProvider(grupoId));
    final puedeGestionar =
        miembroAsync.valueOrNull?.rol.puedeGestionarCampanas ?? false;

    if (campanasAsync.isLoading && !campanasAsync.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    if (campanasAsync.hasError && !campanasAsync.hasValue) {
      return Center(child: Text('Error: ${campanasAsync.error}'));
    }

    final campanas = campanasAsync.valueOrNull ?? [];
    final gc = ref.watch(grupoColorProvider(grupoId));

    if (campanas.isEmpty) {
      return _EmptyCampanas(
        puedeGestionar: puedeGestionar,
        grupoId: grupoId,
        gc: gc,
        onCrear: () => _showCrearCampana(context, ref),
      );
    }

    // Separate hero (first active) from rest
    final activas = campanas.where((c) => c.estado == EstadoCampana.activa).toList();
    final resto = campanas.where((c) => c.estado != EstadoCampana.activa).toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Hero campaign (primera activa)
          if (activas.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: _HeroCampana(campana: activas.first, grupoId: grupoId, gc: gc),
              ),
            ),

          // ── Rest of active campañas
          if (activas.length > 1) ...[
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: SGEyebrow('Otras activas'),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.separated(
                itemCount: activas.length - 1,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _CampanaRow(
                  campana: activas[i + 1],
                  grupoId: grupoId,
                  gc: gc,
                ),
              ),
            ),
          ],

          // ── Pasadas
          if (resto.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: SGEyebrow('Historial'),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.separated(
                itemCount: resto.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _CampanaRow(
                  campana: resto[i],
                  grupoId: grupoId,
                  gc: gc,
                ),
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
      floatingActionButton: puedeGestionar
          ? FloatingActionButton.extended(
              onPressed: () => _showCrearCampana(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nueva campaña'),
              backgroundColor: gc,
              foregroundColor: Colors.white,
            )
          : null,
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
}

// ── Hero Campaña ──────────────────────────────────────────────────────────────

class _HeroCampana extends StatelessWidget {
  final CampanaModel campana;
  final String grupoId;
  final Color gc;
  const _HeroCampana({required this.campana, required this.grupoId, required this.gc});

  @override
  Widget build(BuildContext context) {
    final pct = campana.porcentaje;
    final fmt = NumberFormat('#,##0', 'es_AR');

    return GestureDetector(
      onTap: () => context.push('/group/$grupoId/campana/${campana.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner / cover
            if (campana.imagenUrl != null)
              SizedBox(
                height: 130,
                width: double.infinity,
                child: CachedNetworkImage(imageUrl: campana.imagenUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _GradientBanner(gc: gc)),
              )
            else
              _GradientBanner(gc: gc),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: campana.completada
                              ? AppTheme.good.withValues(alpha: 0.12)
                              : gc.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          campana.completada
                              ? '🎉 Completada'
                              : '🟢 Activa',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: campana.completada
                                ? AppTheme.good
                                : gc,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppTheme.textMuted),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    campana.titulo,
                    style: GoogleFonts.bricolageGrotesque(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: AppTheme.text,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (campana.descripcion != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      campana.descripcion!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textMuted),
                    ),
                  ],
                  const SizedBox(height: 14),

                  // Progress
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 8,
                      backgroundColor: AppTheme.border,
                      valueColor: AlwaysStoppedAnimation(
                          campana.completada ? AppTheme.good : gc),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '\$${fmt.format(campana.montoActual)}',
                            style: GoogleFonts.bricolageGrotesque(
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                              color: campana.completada ? AppTheme.good : gc,
                            ),
                          ),
                          const Text('recaudado',
                              style: TextStyle(
                                  fontSize: 11, color: AppTheme.textMuted)),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${fmt.format(campana.objetivo)}',
                            style: GoogleFonts.bricolageGrotesque(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppTheme.text,
                            ),
                          ),
                          const Text('objetivo',
                              style: TextStyle(
                                  fontSize: 11, color: AppTheme.textMuted)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    campana.completada
                        ? '🎉 ¡Meta alcanzada!'
                        : '${(pct * 100).toStringAsFixed(0)}% completado'
                            ' — faltan \$${fmt.format(campana.faltante)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: campana.completada
                          ? AppTheme.good
                          : AppTheme.textMuted,
                      fontWeight: campana.completada
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  if (campana.fechaLimite != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.schedule_outlined,
                            size: 12, color: AppTheme.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          'Límite: ${DateFormat('dd/MM/yyyy').format(campana.fechaLimite!)}',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientBanner extends StatelessWidget {
  final Color gc;
  const _GradientBanner({required this.gc});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gc.withValues(alpha: 0.18), AppTheme.accentSoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(Icons.savings_outlined,
            size: 36, color: gc.withValues(alpha: 0.5)),
      ),
    );
  }
}

// ── Campaña Row ───────────────────────────────────────────────────────────────

class _CampanaRow extends StatelessWidget {
  final CampanaModel campana;
  final String grupoId;
  final Color gc;
  const _CampanaRow({required this.campana, required this.grupoId, required this.gc});

  @override
  Widget build(BuildContext context) {
    final pct = campana.porcentaje;
    final color = campana.completada
        ? AppTheme.good
        : campana.estado == EstadoCampana.cancelada
            ? AppTheme.textMuted
            : gc;

    return GestureDetector(
      onTap: () => context.push('/group/$grupoId/campana/${campana.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.savings_outlined, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(campana.titulo,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 4,
                      backgroundColor: AppTheme.border,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${(pct * 100).toStringAsFixed(0)}% · ${campana.estado.label}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyCampanas extends StatelessWidget {
  final bool puedeGestionar;
  final String grupoId;
  final Color gc;
  final VoidCallback onCrear;
  const _EmptyCampanas({
    required this.puedeGestionar,
    required this.grupoId,
    required this.gc,
    required this.onCrear,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: gc.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.savings_outlined,
                  size: 36, color: gc),
            ),
            const SizedBox(height: 18),
            Text(
              'No hay campañas activas',
              style: GoogleFonts.bricolageGrotesque(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppTheme.text,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Las campañas sirven para juntar fondos\n'
              'para equipamiento, viajes y más.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
            ),
            if (puedeGestionar) ...[
              const SizedBox(height: 20),
              SGPillButton(
                icon: Icons.add_rounded,
                label: 'Crear campaña',
                onPressed: onCrear,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Crear Campaña Sheet ───────────────────────────────────────────────────────

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
  final _objetivoCtrl = TextEditingController();
  DateTime? _fechaLimite;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descCtrl.dispose();
    _objetivoCtrl.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    if (_tituloCtrl.text.isEmpty || _objetivoCtrl.text.isEmpty) return;
    final objetivo =
        double.tryParse(_objetivoCtrl.text.replaceAll(',', '.'));
    if (objetivo == null || objetivo <= 0) return;
    try {
      await ref.read(crearCampanaProvider.notifier).crear(
            grupoId: widget.grupoId,
            titulo: _tituloCtrl.text.trim(),
            descripcion: _descCtrl.text.trim().isEmpty
                ? null
                : _descCtrl.text.trim(),
            objetivo: objetivo,
            fechaLimite: _fechaLimite,
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text('Nueva campaña',
                style: GoogleFonts.bricolageGrotesque(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: AppTheme.text)),
            const SizedBox(height: 16),
            TextField(
              controller: _tituloCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Título de la campaña',
                hintText: 'Ej: Camisetas nuevas, Viaje al torneo...',
                prefixIcon: Icon(Icons.emoji_events_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _objetivoCtrl,
              decoration: const InputDecoration(
                labelText: 'Objetivo (\$)',
                hintText: 'Monto total a recaudar',
                prefixText: '\$ ',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 730)),
                );
                if (date != null) setState(() => _fechaLimite = date);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 18, color: AppTheme.textMuted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _fechaLimite != null
                            ? 'Límite: ${DateFormat('dd/MM/yyyy').format(_fechaLimite!)}'
                            : 'Fecha límite (opcional)',
                        style: TextStyle(
                            fontSize: 14,
                            color: _fechaLimite != null
                                ? AppTheme.text
                                : AppTheme.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SGPillButton(
              label: 'Lanzar campaña',
              icon: Icons.rocket_launch_outlined,
              expand: true,
              onPressed: isLoading ? null : _crear,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
