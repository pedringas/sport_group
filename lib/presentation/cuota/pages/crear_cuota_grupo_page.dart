import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../data/models/cuota_grupo_model.dart';
import '../../../data/models/miembro_model.dart';
import '../../../providers/cuota_grupo_provider.dart';
import '../../../providers/grupo_provider.dart';

class CrearCuotaGrupoPage extends ConsumerStatefulWidget {
  final String grupoId;
  final CuotaGrupoModel? para;

  const CrearCuotaGrupoPage({super.key, required this.grupoId, this.para});

  @override
  ConsumerState<CrearCuotaGrupoPage> createState() =>
      _CrearCuotaGrupoPageState();
}

class _CrearCuotaGrupoPageState extends ConsumerState<CrearCuotaGrupoPage> {
  final _nombreCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  double _monto = 5000;
  int _diaVencimiento = 10;
  bool _incluirPrimerMes = true;
  bool _loading = false;
  String _busqueda = '';

  final Set<String> _selectedUids = {};

  @override
  void initState() {
    super.initState();
    final p = widget.para;
    if (p != null) {
      _nombreCtrl.text = p.nombre;
      _descCtrl.text = p.descripcion;
      _monto = p.montoMensual;
      _diaVencimiento = p.diaVencimiento;
      _selectedUids.addAll(p.miembrosUids);
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  bool get _valid =>
      _nombreCtrl.text.trim().isNotEmpty && _selectedUids.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final miembros =
        ref.watch(miembrosProvider(widget.grupoId)).valueOrNull ?? [];
    final gc = ref.watch(grupoColorProvider(widget.grupoId));

    final filtrados = _busqueda.isEmpty
        ? miembros
        : miembros
            .where((m) => m.nombreCompleto
                .toLowerCase()
                .contains(_busqueda.toLowerCase()))
            .toList();

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: AppTheme.bg(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.para == null
              ? 'Nuevo grupo de suscripción'
              : 'Editar grupo',
          style: GoogleFonts.bricolageGrotesque(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppTheme.text,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          // Nombre
          const SGEyebrow('Nombre del grupo'),
          const SizedBox(height: 8),
          TextField(
            controller: _nombreCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Ej: Cuota mensual, Subs. fútbol sala…',
              filled: true,
              fillColor: AppTheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Descripción
          const SGEyebrow('Descripción (opcional)'),
          const SizedBox(height: 8),
          TextField(
            controller: _descCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Para qué sirve este cobro…',
              filled: true,
              fillColor: AppTheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Monto mensual
          const SGEyebrow('Monto mensual'),
          const SizedBox(height: 12),
          SGCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () =>
                      setState(() => _monto = (_monto - 500).clamp(500, 99999)),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.remove_rounded,
                        size: 18, color: AppTheme.text),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '\$ ${_monto.toInt()}',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.text,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () =>
                      setState(() => _monto = (_monto + 500).clamp(500, 99999)),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: gc.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child:
                        Icon(Icons.add_rounded, size: 18, color: gc),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Día de vencimiento
          const SGEyebrow('Día de vencimiento'),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [5, 10, 15, 20, 25, 28].map((d) {
                final sel = _diaVencimiento == d;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _diaVencimiento = d),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? gc : AppTheme.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: sel ? gc : AppTheme.border,
                          width: sel ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        'Día $d',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : AppTheme.text,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 20),

          // Primer mes
          if (widget.para == null)
            SGCard(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Incluir mes actual',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppTheme.text)),
                        Text('Emitir cuota del mes en curso',
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                  Switch(
                    value: _incluirPrimerMes,
                    onChanged: (v) => setState(() => _incluirPrimerMes = v),
                    activeThumbColor: gc,
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // Miembros
          Row(
            children: [
              const Expanded(child: SGEyebrow('Miembros del grupo')),
              if (_selectedUids.isNotEmpty)
                Text(
                  '${_selectedUids.length} seleccionados',
                  style: TextStyle(
                    fontSize: 12,
                    color: gc,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            onChanged: (v) => setState(() => _busqueda = v),
            decoration: InputDecoration(
              hintText: 'Buscar miembro…',
              prefixIcon: const Icon(Icons.search_rounded,
                  size: 18, color: AppTheme.textMuted),
              isDense: true,
              filled: true,
              fillColor: AppTheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (miembros.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                  child: Text('Sin miembros',
                      style: TextStyle(color: AppTheme.textMuted))),
            )
          else
            ...filtrados.map((m) => _MemberTile(
                  miembro: m,
                  selected: _selectedUids.contains(m.uid),
                  gc: gc,
                  onToggle: () => setState(() {
                    if (_selectedUids.contains(m.uid)) {
                      _selectedUids.remove(m.uid);
                    } else {
                      _selectedUids.add(m.uid);
                    }
                  }),
                )),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _valid && !_loading ? _guardar : null,
        backgroundColor: _valid ? gc : AppTheme.border,
        foregroundColor: _valid ? Colors.white : AppTheme.textMuted,
        icon: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.check_rounded),
        label: Text(widget.para == null ? 'Crear grupo' : 'Guardar'),
      ),
    );
  }

  Future<void> _guardar() async {
    if (!_valid) return;
    setState(() => _loading = true);
    try {
      final model = CuotaGrupoModel(
        id: widget.para?.id ?? '',
        nombre: _nombreCtrl.text.trim(),
        descripcion: _descCtrl.text.trim(),
        montoMensual: _monto,
        diaVencimiento: _diaVencimiento,
        miembrosUids: _selectedUids.toList(),
        createdAt: widget.para?.createdAt ?? DateTime.now(),
      );
      final repo = ref.read(cuotaGrupoRepositoryProvider);
      if (widget.para == null) {
        await repo.createCuotaGrupo(widget.grupoId, model);
      } else {
        await repo.updateCuotaGrupo(widget.grupoId, model);
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _MemberTile extends StatelessWidget {
  final MiembroModel miembro;
  final bool selected;
  final Color gc;
  final VoidCallback onToggle;

  const _MemberTile({
    required this.miembro,
    required this.selected,
    required this.gc,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            SGAvatar(
                name: miembro.nombreCompleto,
                imageUrl: miembro.avatarUrl,
                size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                miembro.nombreCompleto,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: selected ? gc : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: selected ? gc : AppTheme.border,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
