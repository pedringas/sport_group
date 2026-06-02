import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../data/models/tarea_model.dart';
import '../../../data/models/miembro_model.dart';
import '../../../data/models/enums.dart';
import '../../../providers/tarea_provider.dart';
import '../../../providers/grupo_provider.dart';
import '../../../providers/auth_provider.dart';

class TareasTab extends ConsumerStatefulWidget {
  final String grupoId;
  const TareasTab({super.key, required this.grupoId});

  @override
  ConsumerState<TareasTab> createState() => _TareasTabState();
}

class _TareasTabState extends ConsumerState<TareasTab> {
  TareaEstado? _filtro;

  @override
  Widget build(BuildContext context) {
    final gc = ref.watch(grupoColorProvider(widget.grupoId));
    final tareasAsync = ref.watch(tareasProvider(widget.grupoId));
    final miembroAsync = ref.watch(miembroActualProvider(widget.grupoId));
    final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
    final puedeGestionar =
        miembroAsync.valueOrNull?.rol.puedeGestionarTareas ?? false;
    final puedeEliminar = miembroAsync.valueOrNull?.rol.esAdmin == true ||
        miembroAsync.valueOrNull?.rol == RolMiembro.moderador;

    final tareas = tareasAsync.valueOrNull ?? [];
    final filtered = _filtro == null
        ? tareas
        : tareas.where((t) => t.estado == _filtro).toList();

    // Count by estado for badges
    final counts = {
      for (final e in TareaEstado.values)
        e: tareas.where((t) => t.estado == e).length
    };

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.surf(context),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: Text(
          'Tareas',
          style: GoogleFonts.bricolageGrotesque(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.2,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppTheme.border),
        ),
      ),
      body: Column(
        children: [
          // â”€â”€ Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                _TabChip(
                  label: 'Todas',
                  count: tareas.length,
                  selected: _filtro == null,
                  onTap: () => setState(() => _filtro = null),
                  gc: gc,
                ),
                const SizedBox(width: 6),
                ...TareaEstado.values.map((e) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _TabChip(
                        label: '${e.emoji} ${e.label}',
                        count: counts[e] ?? 0,
                        selected: _filtro == e,
                        onTap: () => setState(() => _filtro = e),
                        gc: gc,
                      ),
                    )),
              ],
            ),
          ),

          // â”€â”€ Vencidas alert
          if (tareas.any((t) => t.vencida && t.estado != TareaEstado.completada))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppTheme.danger.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 14, color: AppTheme.danger),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${tareas.where((t) => t.vencida && t.estado != TareaEstado.completada).length} tarea(s) vencida(s)',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.danger,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // â”€â”€ List
          Expanded(
            child: tareasAsync.isLoading && !tareasAsync.hasValue
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? _EmptyTareas(filtro: _filtro)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) => _TareaCard(
                          tarea: filtered[i],
                          uid: uid,
                          grupoId: widget.grupoId,
                          puedeEliminar: puedeEliminar ||
                              filtered[i].creadoPorUid == uid,
                          puedeEditar: puedeGestionar ||
                              filtered[i].creadoPorUid == uid ||
                              filtered[i].asignadoA(uid),
                          miembrosAsync:
                              ref.watch(miembrosProvider(widget.grupoId)),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: puedeGestionar
          ? FloatingActionButton.extended(
              onPressed: () => _showCrearTarea(context, ref),
              icon: const Icon(Icons.add_task_rounded),
              label: const Text('Nueva tarea'),
              backgroundColor: gc,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  void _showCrearTarea(BuildContext context, WidgetRef ref) {
    final miembrosAsync = ref.read(miembrosProvider(widget.grupoId));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _TareaSheet(
        grupoId: widget.grupoId,
        miembros: miembrosAsync.valueOrNull ?? [],
      ),
    );
  }
}

// â”€â”€ Tab Chip â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _TabChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final Color gc;

  const _TabChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    required this.gc,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? gc : AppTheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: selected ? gc : AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppTheme.text,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.25)
                      : AppTheme.border,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppTheme.textMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Empty State â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _EmptyTareas extends StatelessWidget {
  final TareaEstado? filtro;
  const _EmptyTareas({this.filtro});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.task_alt_rounded,
                size: 28, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 14),
          Text(
            filtro == null
                ? 'No hay tareas todavía'
                : 'Sin tareas ${filtro!.label.toLowerCase()}s',
            style:
                const TextStyle(fontSize: 15, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

// â”€â”€ Tarea Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _TareaCard extends ConsumerWidget {
  final TareaModel tarea;
  final String uid;
  final String grupoId;
  final bool puedeEliminar;
  final bool puedeEditar;
  final AsyncValue<List<MiembroModel>> miembrosAsync;

  const _TareaCard({
    required this.tarea,
    required this.uid,
    required this.grupoId,
    required this.puedeEliminar,
    required this.puedeEditar,
    required this.miembrosAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _estadoColor(tarea.estado);
    final isVencida = tarea.vencida;

    return GestureDetector(
      onTap: () => _showOptions(context, ref),
      onLongPress: () => _showOptions(context, ref),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isVencida
                  ? AppTheme.danger.withValues(alpha: 0.3)
                  : AppTheme.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Urgency bar
              Container(
                width: 4,
                color: color,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              tarea.titulo,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppTheme.text,
                                decoration:
                                    tarea.estado == TareaEstado.completada
                                        ? TextDecoration.lineThrough
                                        : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${tarea.estado.emoji} ${tarea.estado.label}',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: color,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      if (tarea.descripcion != null &&
                          tarea.descripcion!.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          tarea.descripcion!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                      const SizedBox(height: 8),

                      // Assignees
                      if (tarea.asignadosA.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(Icons.person_pin_outlined,
                                size: 12, color: AppTheme.textMuted),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                tarea.asignadosA
                                    .map((a) =>
                                        a.nombre.split(' ').first)
                                    .join(', '),
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textMuted),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],

                      // Footer
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Por ${tarea.creadoPorNombre.split(' ').first}',
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.textMuted),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (tarea.fechaVencimiento != null) ...[
                            Icon(
                              isVencida
                                  ? Icons.warning_amber_rounded
                                  : Icons.calendar_today_outlined,
                              size: 12,
                              color: isVencida
                                  ? AppTheme.danger
                                  : AppTheme.textMuted,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              DateFormat('dd/MM/yy')
                                  .format(tarea.fechaVencimiento!),
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isVencida
                                      ? AppTheme.danger
                                      : AppTheme.textMuted,
                                  fontWeight: isVencida
                                      ? FontWeight.w600
                                      : FontWeight.normal),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _estadoColor(TareaEstado e) => switch (e) {
        TareaEstado.pendiente => AppTheme.warning,
        TareaEstado.en_curso => AppTheme.info,
        TareaEstado.completada => AppTheme.good,
        TareaEstado.cancelada => AppTheme.textMuted,
      };

  void _showOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // â”€â”€ Título de la tarea â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tarea.titulo,
                      style: GoogleFonts.bricolageGrotesque(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppTheme.text),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _estadoColor(tarea.estado)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${tarea.estado.emoji} ${tarea.estado.label}',
                      style: TextStyle(
                          fontSize: 11,
                          color: _estadoColor(tarea.estado),
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 16),
            // â”€â”€ Cambiar estado (solo si tiene permiso) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            if (puedeEditar) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Cambiar estado',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: AppTheme.textMuted)),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: TareaEstado.values.map((e) {
                    final selected = tarea.estado == e;
                    final color = switch (e) {
                      TareaEstado.pendiente => AppTheme.warning,
                      TareaEstado.en_curso => AppTheme.info,
                      TareaEstado.completada => AppTheme.good,
                      TareaEstado.cancelada => AppTheme.textMuted,
                    };
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          ref
                              .read(tareaNotifierProvider.notifier)
                              .updateEstado(grupoId, tarea.id, e);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: selected
                                ? color.withValues(alpha: 0.12)
                                : AppTheme.surface,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: selected
                                    ? color.withValues(alpha: 0.4)
                                    : AppTheme.border),
                          ),
                          child: Text('${e.emoji} ${e.label}',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: selected ? color : AppTheme.text)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Divider(height: 1),
            ],
            if (puedeEditar)
              ListTile(
                dense: true,
                leading: const Icon(Icons.person_add_outlined, size: 20),
                title: const Text('Editar asignados',
                    style: TextStyle(fontSize: 14)),
                onTap: () {
                  Navigator.pop(context);
                  _showEditarAsignados(context, ref);
                },
              ),
            if (puedeEditar)
              ListTile(
                dense: true,
                leading: const Icon(Icons.edit_outlined, size: 20),
                title:
                    const Text('Editar', style: TextStyle(fontSize: 14)),
                onTap: () {
                  Navigator.pop(context);
                  final miembros =
                      ref.read(miembrosProvider(grupoId)).valueOrNull ?? [];
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => _TareaSheet(
                        grupoId: grupoId,
                        tareaExistente: tarea,
                        miembros: miembros),
                  );
                },
              ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.chat_bubble_outline,
                  size: 20, color: Color(0xFF25D366)),
              title: const Text('Compartir por WhatsApp',
                  style: TextStyle(fontSize: 14)),
              onTap: () {
                Navigator.pop(context);
                _shareWhatsApp();
              },
            ),
            if (puedeEliminar)
              ListTile(
                dense: true,
                leading: const Icon(Icons.delete_outline,
                    size: 20, color: AppTheme.danger),
                title: const Text('Eliminar',
                    style: TextStyle(
                        fontSize: 14, color: AppTheme.danger)),
                onTap: () {
                  Navigator.pop(context);
                  ref
                      .read(tareaNotifierProvider.notifier)
                      .eliminar(grupoId, tarea.id);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showEditarAsignados(BuildContext context, WidgetRef ref) {
    final miembros = miembrosAsync.valueOrNull ?? [];
    final selected = Set<String>.from(tarea.asignadosA.map((a) => a.uid));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.surf(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header: title + Guardar button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Asignar miembros',
                    style: GoogleFonts.bricolageGrotesque(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      final nuevos = miembros
                          .where((m) => selected.contains(m.uid))
                          .map((m) => AsignadoTarea(
                                uid: m.uid,
                                nombre: m.nombreCompleto,
                                avatarUrl: m.avatarUrl,
                              ))
                          .toList();
                      ref
                          .read(tareaNotifierProvider.notifier)
                          .updateAsignados(grupoId, tarea.id, nuevos);
                    },
                    child: const Text('Guardar'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Member list ”” bounded so it never overflows
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: miembros
                    .map((m) => CheckboxListTile(
                          value: selected.contains(m.uid),
                          onChanged: (v) => setBS(() {
                            if (v == true) {
                              selected.add(m.uid);
                            } else {
                              selected.remove(m.uid);
                            }
                          }),
                          secondary: SGAvatar(
                              name: m.nombreCompleto,
                              imageUrl: m.avatarUrl,
                              size: 36),
                          title: Text(m.nombreCompleto),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _shareWhatsApp() {
    const base = 'https://sports-groups-app.web.app';
    final venc = tarea.fechaVencimiento != null
        ? '\n📅 Vence: ${DateFormat('dd/MM/yyyy').format(tarea.fechaVencimiento!)}'
        : '';
    final asignados = tarea.asignadosA.isNotEmpty
        ? '\n👥 ${tarea.asignadosA.map((a) => a.nombre).join(', ')}'
        : '';
    final msg = '📋 *${tarea.titulo}*$venc$asignados'
        '\n\n🔗 $base/group/$grupoId';
    launchUrl(
        Uri.parse('https://wa.me/?text=${Uri.encodeComponent(msg)}'),
        mode: LaunchMode.externalApplication);
  }
}

// â”€â”€ Tarea Sheet (create/edit) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _TareaSheet extends ConsumerStatefulWidget {
  final String grupoId;
  final List<MiembroModel> miembros;
  final TareaModel? tareaExistente;

  const _TareaSheet({
    required this.grupoId,
    required this.miembros,
    this.tareaExistente,
  });

  @override
  ConsumerState<_TareaSheet> createState() => _TareaSheetState();
}

class _TareaSheetState extends ConsumerState<_TareaSheet> {
  final _tituloCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final Set<String> _selectedUids = {};
  DateTime? _fechaVenc;

  @override
  void initState() {
    super.initState();
    final t = widget.tareaExistente;
    if (t != null) {
      _tituloCtrl.text = t.titulo;
      _descCtrl.text = t.descripcion ?? '';
      _selectedUids.addAll(t.asignadosA.map((a) => a.uid));
      _fechaVenc = t.fechaVencimiento;
    }
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_tituloCtrl.text.trim().isEmpty) return;
    final asignados = widget.miembros
        .where((m) => _selectedUids.contains(m.uid))
        .map((m) => AsignadoTarea(
            uid: m.uid,
            nombre: m.nombreCompleto,
            avatarUrl: m.avatarUrl))
        .toList();
    try {
      if (widget.tareaExistente == null) {
        final id = await ref.read(tareaNotifierProvider.notifier).crear(
              grupoId: widget.grupoId,
              titulo: _tituloCtrl.text.trim(),
              descripcion: _descCtrl.text.trim().isEmpty
                  ? null
                  : _descCtrl.text.trim(),
              asignadosA: asignados,
              fechaVencimiento: _fechaVenc,
            );
        if (mounted) Navigator.pop(context);
        if (mounted) _offerWhatsApp(id, _tituloCtrl.text.trim(), asignados);
      } else {
        await ref.read(tareaNotifierProvider.notifier).updateTarea(
              grupoId: widget.grupoId,
              tareaId: widget.tareaExistente!.id,
              titulo: _tituloCtrl.text.trim(),
              descripcion: _descCtrl.text.trim().isEmpty
                  ? null
                  : _descCtrl.text.trim(),
              asignadosA: asignados,
              estado: widget.tareaExistente!.estado,
              fechaVencimiento: _fechaVenc,
            );
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _offerWhatsApp(
      String id, String titulo, List<AsignadoTarea> asignados) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Notificar por WhatsApp?'),
        content: Text('¿Compartís la tarea "$titulo"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('No')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              const base = 'https://sports-groups-app.web.app';
              final n = asignados.isNotEmpty
                  ? '\n👥 ${asignados.map((a) => a.nombre).join(', ')}'
                  : '';
              final msg =
                  '📋 *$titulo*$n\n🔗 $base/group/${widget.grupoId}';
              launchUrl(
                  Uri.parse(
                      'https://wa.me/?text=${Uri.encodeComponent(msg)}'),
                  mode: LaunchMode.externalApplication);
            },
            child: const Text('Compartir'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate:
          _fechaVenc ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _fechaVenc = d);
  }

  @override
  Widget build(BuildContext context) {
    final gc = ref.watch(grupoColorProvider(widget.grupoId));
    final isLoading = ref.watch(tareaNotifierProvider).isLoading;
    final isEditing = widget.tareaExistente != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20, right: 20, top: 8,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            Text(isEditing ? 'Editar tarea' : 'Nueva tarea',
                style: GoogleFonts.bricolageGrotesque(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: AppTheme.text)),
            const SizedBox(height: 16),
            TextField(
              controller: _tituloCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Título de la tarea *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),

            // Date row
            GestureDetector(
              onTap: _pickDate,
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
                    Icon(
                      _fechaVenc != null
                          ? Icons.calendar_today_outlined
                          : Icons.calendar_today_outlined,
                      size: 18, color: AppTheme.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _fechaVenc == null
                            ? 'Sin fecha de vencimiento'
                            : 'Vence: ${DateFormat('dd/MM/yyyy').format(_fechaVenc!)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: _fechaVenc != null
                              ? AppTheme.text
                              : AppTheme.textMuted,
                        ),
                      ),
                    ),
                    if (_fechaVenc != null)
                      GestureDetector(
                        onTap: () =>
                            setState(() => _fechaVenc = null),
                        child: const Icon(Icons.clear,
                            size: 16, color: AppTheme.textMuted),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Assignees
            const Text('Asignar miembros (opcional)',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppTheme.textMuted)),
            const SizedBox(height: 8),
            if (widget.miembros.isEmpty)
              const Text('Cargando miembros…',
                  style: TextStyle(color: AppTheme.textMuted))
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: widget.miembros.map((m) {
                  final sel = _selectedUids.contains(m.uid);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (sel) {
                        _selectedUids.remove(m.uid);
                      } else {
                        _selectedUids.add(m.uid);
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel
                            ? gc
                            : AppTheme.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: sel
                                ? gc
                                : AppTheme.border),
                      ),
                      child: Text(
                        m.nombreCompleto.split(' ').first,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: sel
                                ? Colors.white
                                : AppTheme.text),
                      ),
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 20),
            SGPillButton(
              label:
                  isEditing ? 'Guardar cambios' : 'Crear tarea',
              expand: true,
              onPressed: isLoading ? null : _guardar,
            ),
          ],
        ),
      ),
    );
  }
}
