import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../providers/tarea_provider.dart';
import '../../../providers/grupo_provider.dart';
import '../../../data/models/tarea_model.dart';
import '../../../data/models/miembro_model.dart';

final _crearTareaProvider =
    AsyncNotifierProvider<TareaNotifier, void>(TareaNotifier.new);

enum _Prioridad { baja, normal, urgente }

enum _Vencimiento { hoy, manana, semana, sinFecha }

class CrearTareaPage extends ConsumerStatefulWidget {
  final String grupoId;
  const CrearTareaPage({super.key, required this.grupoId});

  @override
  ConsumerState<CrearTareaPage> createState() => _CrearTareaPageState();
}

class _CrearTareaPageState extends ConsumerState<CrearTareaPage> {
  final _tituloCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  _Prioridad _prioridad = _Prioridad.normal;
  _Vencimiento _venc = _Vencimiento.semana;
  final List<MiembroModel> _asignados = [];

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  DateTime? get _fechaVencimiento {
    final now = DateTime.now();
    return switch (_venc) {
      _Vencimiento.hoy => DateTime(now.year, now.month, now.day, 23, 59),
      _Vencimiento.manana =>
        DateTime(now.year, now.month, now.day + 1, 23, 59),
      _Vencimiento.semana =>
        DateTime(now.year, now.month, now.day + 7, 23, 59),
      _Vencimiento.sinFecha => null,
    };
  }

  Future<void> _asignar() async {
    final titulo = _tituloCtrl.text.trim();
    if (titulo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribí un título para la tarea')),
      );
      return;
    }

    final asignadosA = _asignados
        .map((m) => AsignadoTarea(uid: m.uid, nombre: m.nombreCompleto))
        .toList();

    try {
      await ref.read(_crearTareaProvider.notifier).crear(
            grupoId: widget.grupoId,
            titulo: titulo,
            descripcion: _notasCtrl.text.trim().isEmpty
                ? null
                : _notasCtrl.text.trim(),
            asignadosA: asignadosA,
            fechaVencimiento: _fechaVencimiento,
          );
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _showMemberPicker(Color gc) async {
    final miembros =
        ref.read(miembrosProvider(widget.grupoId)).valueOrNull ?? [];
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => _MemberPickerSheet(
        miembros: miembros,
        selected: _asignados,
        gc: gc,
        onToggle: (m) {
          setState(() {
            if (_asignados.any((a) => a.uid == m.uid)) {
              _asignados.removeWhere((a) => a.uid == m.uid);
            } else {
              _asignados.add(m);
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gc = ref.watch(grupoColorProvider(widget.grupoId));
    final loading = ref.watch(_crearTareaProvider).isLoading;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        child: Column(
          children: [
            // â”€â”€ Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Text(
                      'Nueva tarea',
                      style: GoogleFonts.bricolageGrotesque(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: AppTheme.text,
                      ),
                    ),
                  ),
                  SGPillButton(
                    label: 'Asignar',
                    size: SGSize.sm,
                    onPressed: loading ? null : _asignar,
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, AppTheme.kBottomNavPadding),
                children: [
                  // â”€â”€ Title
                  TextField(
                    controller: _tituloCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: '¿Qué hay que hacer?',
                      hintStyle: GoogleFonts.bricolageGrotesque(
                        fontWeight: FontWeight.w700,
                        fontSize: 24,
                        letterSpacing: -0.3,
                        color: AppTheme.border,
                      ),
                    ),
                    style: GoogleFonts.bricolageGrotesque(
                      fontWeight: FontWeight.w700,
                      fontSize: 24,
                      letterSpacing: -0.3,
                      color: AppTheme.text,
                    ),
                  ),

                  // â”€â”€ Notes
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: TextField(
                      controller: _notasCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Detalles, links, lo que sea necesario...',
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // â”€â”€ Assigned to
                  const SGEyebrow('A quién le toca'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ..._asignados.map((m) => _AssigneePill(
                              name: m.nombreCompleto,
                              onRemove: () =>
                                  setState(() => _asignados.remove(m)),
                              gc: gc,
                            )),
                        GestureDetector(
                          onTap: () => _showMemberPicker(gc),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceAlt,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_rounded,
                                    size: 14, color: AppTheme.textMuted),
                                SizedBox(width: 4),
                                Text('Sumar',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textMuted)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // â”€â”€ Due date
                  const SGEyebrow('Vencimiento'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _Vencimiento.values.map((v) {
                      final sel = v == _venc;
                      final labels = {
                        _Vencimiento.hoy: 'Hoy',
                        _Vencimiento.manana: 'Mañana',
                        _Vencimiento.semana: 'Esta semana',
                        _Vencimiento.sinFecha: 'Sin fecha',
                      };
                      return GestureDetector(
                        onTap: () => setState(() => _venc = v),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel ? AppTheme.text : AppTheme.surface,
                            borderRadius: BorderRadius.circular(999),
                            border: sel
                                ? null
                                : Border.all(color: AppTheme.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (sel) ...[
                                const Icon(Icons.check_rounded,
                                    size: 14, color: Colors.white),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                labels[v]!,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: sel ? Colors.white : AppTheme.text,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // â”€â”€ Priority
                  const SGEyebrow('Prioridad'),
                  const SizedBox(height: 8),
                  Row(
                    children: _Prioridad.values.map((p) {
                      final sel = p == _prioridad;
                      final cfg = switch (p) {
                        _Prioridad.baja => (label: 'Baja', color: AppTheme.textMuted),
                        _Prioridad.normal => (label: 'Normal', color: AppTheme.accent),
                        _Prioridad.urgente => (label: 'Urgente', color: AppTheme.danger),
                      };
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _prioridad = p),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            margin: EdgeInsets.only(
                                right: p != _Prioridad.urgente ? 8 : 0),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: sel ? cfg.color : AppTheme.border,
                                width: sel ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.flag_rounded,
                                  size: 20,
                                  color: cfg.color,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  cfg.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: sel ? cfg.color : AppTheme.text,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: SGPillButton(
            icon: Icons.task_alt_rounded,
            label: 'Asignar tarea',
            expand: true,
            onPressed: loading ? null : _asignar,
          ),
        ),
      ),
    );
  }
}

// â”€â”€ Member picker sheet â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _MemberPickerSheet extends StatelessWidget {
  final List<MiembroModel> miembros;
  final List<MiembroModel> selected;
  final void Function(MiembroModel) onToggle;
  final Color gc;
  const _MemberPickerSheet({
    required this.miembros,
    required this.selected,
    required this.onToggle,
    required this.gc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.6),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Seleccionar miembros',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: miembros.length,
              itemBuilder: (_, i) {
                final m = miembros[i];
                final sel = selected.any((s) => s.uid == m.uid);
                return ListTile(
                  leading: SGAvatar(name: m.nombreCompleto, size: 36),
                  title: Text(m.nombreCompleto),
                  trailing: sel
                      ? Icon(Icons.check_circle_rounded,
                          color: gc)
                      : const Icon(Icons.circle_outlined,
                          color: AppTheme.border),
                  onTap: () => onToggle(m),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SGPillButton(
                label: 'Listo',
                expand: true,
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€ Assignee pill â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _AssigneePill extends StatelessWidget {
  final String name;
  final VoidCallback onRemove;
  final Color gc;
  const _AssigneePill({required this.name, required this.onRemove, required this.gc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
      decoration: BoxDecoration(
        color: gc.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SGAvatar(
              name: name,
              size: 20,
              background: gc,
              foreground: Colors.white),
          const SizedBox(width: 6),
          Text(
            name.split(' ').first,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: gc,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close_rounded,
                size: 14, color: gc),
          ),
        ],
      ),
    );
  }
}
