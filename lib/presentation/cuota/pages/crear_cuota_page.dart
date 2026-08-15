import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/router/nav_ext.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../data/models/cuota_model.dart';
import '../../../data/models/enums.dart';
import '../../../providers/cuota_provider.dart';
import '../../../providers/grupo_provider.dart';
import '../../../providers/auth_provider.dart';

/// Crear/emitir cuota (vista tesorero/admin). También sirve para editar
/// una cuota existente cuando se pasa [cuotaParaEditar].
class CrearCuotaPage extends ConsumerStatefulWidget {
  final String grupoId;
  final CuotaModel? cuotaParaEditar;
  const CrearCuotaPage({super.key, required this.grupoId, this.cuotaParaEditar});

  @override
  ConsumerState<CrearCuotaPage> createState() => _CrearCuotaPageState();
}

enum _Recurrencia { unaVez, mensual, trimestral, anual }
enum _AQuien { todos, algunos, exceptoAlgunos }

class _CrearCuotaPageState extends ConsumerState<CrearCuotaPage> {
  late final TextEditingController _conceptoCtrl;
  late final TextEditingController _montoCtrl;
  late DateTime _vencimiento;
  // Emitir una sola cuota es el caso normal. El default anterior era "Mensual",
  // que sin avisar generaba una serie de 3 cuotas: el admin creía emitir la de
  // este mes y aparecían también las de los dos meses siguientes.
  _Recurrencia _rec = _Recurrencia.unaVez;
  int _cantidad = 6;
  _AQuien _quien = _AQuien.todos;
  // Member targeting: uid → nombreCompleto
  final Map<String, String> _seleccionados = {};
  bool _saving = false;

  bool get _editMode => widget.cuotaParaEditar != null;
  bool get _esSerie => !_editMode && _rec != _Recurrencia.unaVez;
  int get _cuotasAEmitir => _esSerie ? _cantidad : 1;

  /// Día 10 del mes que viene: lo habitual es cobrar la cuota del mes
  /// siguiente. El default anterior (mañana) hacía que toda cuota naciera
  /// venciendo el día de su creación y apareciera vencida al día siguiente.
  static DateTime _vencimientoPorDefecto() {
    final hoy = DateTime.now();
    return DateTime(hoy.year, hoy.month + 1, 10);
  }

  static String _tituloSugerido(DateTime v) =>
      'Cuota ${_monthNameOf(v.month)} ${v.year}';

  @override
  void initState() {
    super.initState();
    final c = widget.cuotaParaEditar;
    _vencimiento = c?.vencimiento ?? _vencimientoPorDefecto();
    _conceptoCtrl =
        TextEditingController(text: c?.titulo ?? _tituloSugerido(_vencimiento));
    _montoCtrl =
        TextEditingController(text: c != null ? c.monto.toInt().toString() : '');
  }

  @override
  void dispose() {
    _conceptoCtrl.dispose();
    _montoCtrl.dispose();
    super.dispose();
  }

  void _setVencimiento(DateTime d) {
    setState(() {
      // Si el concepto sigue siendo el sugerido para la fecha anterior, lo
      // seguimos al mes nuevo; si el admin lo escribió a mano, no se toca.
      if (_conceptoCtrl.text.trim() == _tituloSugerido(_vencimiento)) {
        _conceptoCtrl.text = _tituloSugerido(d);
      }
      _vencimiento = d;
    });
  }

  Future<void> _pickFecha() async {
    final hoy = DateTime.now();
    // En alta no tiene sentido emitir con vencimiento pasado, pero al editar
    // una cuota vieja sí: con `firstDate: now` el picker reventaba por
    // assertion (initialDate < firstDate) y no abría.
    final first = _editMode
        ? DateTime(hoy.year - 2)
        : DateTime(hoy.year, hoy.month, hoy.day);
    final last = DateTime(hoy.year + 3, hoy.month, hoy.day);
    final initial = _vencimiento.isBefore(first)
        ? first
        : _vencimiento.isAfter(last)
            ? last
            : _vencimiento;
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: 'Fecha de vencimiento',
      confirmText: 'Listo',
      cancelText: 'Cancelar',
    );
    if (d != null) _setVencimiento(d);
  }

  /// Vencimientos que generaría la serie — se muestran antes de emitir.
  List<DateTime> _vencimientosSerie() {
    if (!_esSerie) return [_vencimiento];
    final saltoMeses = switch (_rec) {
      _Recurrencia.trimestral => 3,
      _Recurrencia.anual => 12,
      _ => 1,
    };
    return List.generate(
      _cantidad,
      (i) => DateTime(_vencimiento.year, _vencimiento.month + saltoMeses * i,
          _vencimiento.day),
    );
  }

  double? _parseMonto() => double.tryParse(
      _montoCtrl.text.replaceAll('.', '').replaceAll(',', '.'));

  Future<void> _guardarEdicion(String titulo, double monto) async {
    setState(() => _saving = true);
    try {
      await ref.read(cuotaRepositoryProvider).updateCuota(
        widget.grupoId,
        widget.cuotaParaEditar!.id,
        titulo: titulo,
        descripcion: widget.cuotaParaEditar!.descripcion,
        monto: monto,
        vencimiento: _vencimiento,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _saving = false);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cuota actualizada ✓')),
    );
    context.popOr('/cuotas');
  }

  Future<void> _emitir() async {
    final titulo = _conceptoCtrl.text.trim();
    final monto = _parseMonto();
    if (titulo.isEmpty || monto == null || monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completá el concepto y el monto')),
      );
      return;
    }

    if (_editMode) {
      await _guardarEdicion(titulo, monto);
      return;
    }

    if (_quien != _AQuien.todos && _seleccionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_quien == _AQuien.algunos
            ? 'Elegí a qué miembros cobrarles'
            : 'Elegí a qué miembros excluir')),
      );
      return;
    }

    // Emitir una serie crea N cuotas de una: se confirma antes.
    if (_esSerie && !await _confirmarSerie()) return;

    try {
      final notifier = ref.read(crearCuotaProvider.notifier);
      final uids = _seleccionados.keys.toList();
      final miembrosUids = _quien == _AQuien.algunos && uids.isNotEmpty
          ? uids : null;
      final excluidosUids = _quien == _AQuien.exceptoAlgunos && uids.isNotEmpty
          ? uids : null;

      if (!_esSerie) {
        await notifier.crear(
          grupoId: widget.grupoId,
          titulo: titulo,
          monto: monto,
          vencimiento: _vencimiento,
          miembrosUids: miembrosUids,
          excluidosUids: excluidosUids,
        );
      } else {
        final frecuencia = switch (_rec) {
          _Recurrencia.trimestral  => FrecuenciaCuota.trimestral,
          _Recurrencia.anual       => FrecuenciaCuota.anual,
          _                        => FrecuenciaCuota.mensual,
        };
        await notifier.crearSerie(
          grupoId: widget.grupoId,
          titulo: titulo,
          monto: monto,
          primerVencimiento: _vencimiento,
          frecuencia: frecuencia,
          totalCuotas: _cantidad,
          miembrosUids: miembrosUids,
          excluidosUids: excluidosUids,
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
      return;
    }
    // Fuera del try: un fallo al navegar no debe reportarse como fallo al emitir.
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_esSerie
          ? '$_cantidad cuotas emitidas ✓'
          : 'Cuota emitida ✓')),
    );
    context.popOr('/cuotas');
  }

  Future<bool> _confirmarSerie() async {
    final fechas = _vencimientosSerie();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Emitir $_cantidad cuotas'),
        content: Text(
          'Se van a crear $_cantidad cuotas ${_rec == _Recurrencia.anual ? 'anuales' : _rec == _Recurrencia.trimestral ? 'trimestrales' : 'mensuales'}, '
          'la primera vence el ${_fecha(fechas.first)} y la última el ${_fecha(fechas.last)}.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Emitir')),
        ],
      ),
    );
    return ok == true;
  }

  String _fecha(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final gc = ref.watch(grupoColorProvider(widget.grupoId));
    final loading = _editMode ? _saving : ref.watch(crearCuotaProvider).isLoading;
    final miembros = ref.watch(miembrosProvider(widget.grupoId)).valueOrNull ?? [];
    final miembrosTotales = miembros.isEmpty ? 0 : miembros.length;
    // Con separador de miles ("8.500") `int.tryParse` devolvía null y el total
    // estimado quedaba en $0.
    final monto = _parseMonto()?.round() ?? 0;
    final monthsShort = ['ENE','FEB','MAR','ABR','MAY','JUN','JUL','AGO','SEP','OCT','NOV','DIC'];
    final efectivos = _quien == _AQuien.algunos
        ? _seleccionados.length
        : _quien == _AQuien.exceptoAlgunos
            ? (miembrosTotales - _seleccionados.length).clamp(0, miembrosTotales)
            : miembrosTotales;
    final total = monto * efectivos * _cuotasAEmitir;

    final isDesktop = MediaQuery.sizeOf(context).width >= AppTheme.kResponsiveBreakpoint;
    return Scaffold(
      appBar: isDesktop ? null : AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, size: 22),
          onPressed: () => context.popOr(),
        ),
        title: Text(_editMode ? 'Editar cuota' : 'Nueva cuota'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SGPillButton(
              label: _editMode ? 'Guardar' : 'Emitir', size: SGSize.sm,
              onPressed: loading ? null : _emitir,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SGChip(
              icon: _editMode ? Icons.edit_outlined : Icons.account_balance_outlined,
              label: _editMode ? 'Editar cuota' : 'Emitir cuota',
              tone: SGChipTone.good, filled: true,
            ),

            // Amount hero (dark card)
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.text,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MONTO POR MIEMBRO',
                      style: GoogleFonts.dmSans(
                        color: Colors.white70, fontSize: 11,
                        fontWeight: FontWeight.w700, letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('\$',
                        style: GoogleFonts.bricolageGrotesque(
                            color: Colors.white70, fontSize: 22)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextField(
                        controller: _montoCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        onChanged: (_) => setState(() {}),
                        style: GoogleFonts.bricolageGrotesque(
                            color: Colors.white, fontWeight: FontWeight.w700,
                            fontSize: 48, letterSpacing: -2, height: 1),
                        decoration: const InputDecoration(
                          isDense: true, contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none, filled: false,
                          hintText: '0',
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  RichText(text: TextSpan(
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                    children: [
                      const TextSpan(text: 'Si todos pagan: '),
                      TextSpan(
                        text: '\$ ${_fmt(total)}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: ' · $efectivos miembros'),
                      if (_cuotasAEmitir > 1)
                        TextSpan(text: ' · $_cuotasAEmitir cuotas'),
                    ],
                  )),
                ],
              ),
            ),

            // Concepto
            const SGEyebrow('Concepto'),
            TextField(
              controller: _conceptoCtrl,
              decoration: const InputDecoration(),
            ),

            // Vencimiento
            SGEyebrow(_esSerie ? 'Vence la primera cuota' : 'Vencimiento'),
            SGCard(
              padding: const EdgeInsets.all(12),
              onTap: _pickFecha,
              child: Row(children: [
                Container(
                  width: 60,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(children: [
                    Text('VENCE',
                        style: GoogleFonts.bricolageGrotesque(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: AppTheme.dangerInk, letterSpacing: 1)),
                    Text('${_vencimiento.day}',
                        style: GoogleFonts.bricolageGrotesque(
                            fontSize: 24, fontWeight: FontWeight.w700,
                            color: AppTheme.dangerInk, height: 1)),
                    Text(monthsShort[_vencimiento.month - 1],
                        style: GoogleFonts.bricolageGrotesque(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: AppTheme.dangerInk, letterSpacing: 1)),
                  ]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_vencimiento.day} de ${_monthName(_vencimiento.month)} de ${_vencimiento.year}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text('${_diffDays(_vencimiento)} · tocá para cambiar',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
                const Icon(Icons.edit_calendar_outlined,
                    color: AppTheme.textMuted),
              ]),
            ),

            // Atajos de fecha — el vencimiento es el dato que más se toca y
            // antes había que abrir el calendario para cualquier cambio.
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final atajo in _atajosVencimiento())
                _PillChip(
                  label: atajo.$1,
                  selected: _mismaFecha(_vencimiento, atajo.$2),
                  onTap: () => _setVencimiento(atajo.$2),
                ),
            ]),

            // Recurrencia — oculta en modo edición
            if (!_editMode) const SGEyebrow('Repetición'),
            if (!_editMode)
            Wrap(spacing: 6, runSpacing: 6, children: [
              _PillChip(label: 'Una vez',     selected: _rec == _Recurrencia.unaVez,     onTap: () => _setRecurrencia(_Recurrencia.unaVez)),
              _PillChip(label: 'Mensual',     selected: _rec == _Recurrencia.mensual,    onTap: () => _setRecurrencia(_Recurrencia.mensual)),
              _PillChip(label: 'Trimestral',  selected: _rec == _Recurrencia.trimestral, onTap: () => _setRecurrencia(_Recurrencia.trimestral)),
              _PillChip(label: 'Anual',       selected: _rec == _Recurrencia.anual,      onTap: () => _setRecurrencia(_Recurrencia.anual)),
            ]),
            // Cuántas cuotas genera la serie: antes era un número fijo oculto
            // (3, o 12 para "anual") y el admin no sabía cuántas emitía.
            if (_esSerie) ...[
              const SizedBox(height: 10),
              SGCard(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  Row(children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cantidad de cuotas',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                          Text(
                            'Se emiten todas ahora, con vencimientos escalonados',
                            style: TextStyle(
                                fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    _StepperBtn(
                      icon: Icons.remove_rounded,
                      onTap: _cantidad > 2
                          ? () => setState(() => _cantidad--)
                          : null,
                    ),
                    SizedBox(
                      width: 36,
                      child: Text('$_cantidad',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.bricolageGrotesque(
                              fontSize: 20, fontWeight: FontWeight.w700)),
                    ),
                    _StepperBtn(
                      icon: Icons.add_rounded,
                      onTap: _cantidad < 24
                          ? () => setState(() => _cantidad++)
                          : null,
                    ),
                  ]),
                  const Divider(height: 20),
                  Row(children: [
                    const Icon(Icons.event_repeat_outlined,
                        size: 16, color: AppTheme.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Vencen del ${_fecha(_vencimientosSerie().first)} '
                        'al ${_fecha(_vencimientosSerie().last)}',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ),
                  ]),
                ]),
              ),
            ],

            // A quien — oculta en modo edición
            if (!_editMode) const SGEyebrow('A quién se le cobra'),
            if (!_editMode)
            SGCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                _RadioRow(
                  icon: Icons.groups_outlined,
                  label: 'Todos los miembros',
                  sub: '$miembrosTotales personas',
                  selected: _quien == _AQuien.todos,
                  gc: gc,
                  onTap: () => setState(() => _quien = _AQuien.todos),
                ),
                const Divider(height: 1),
                _RadioRow(
                  icon: Icons.rule_outlined,
                  label: 'Algunos miembros',
                  sub: 'elegí a quién',
                  selected: _quien == _AQuien.algunos,
                  gc: gc,
                  onTap: () => setState(() => _quien = _AQuien.algunos),
                ),
                const Divider(height: 1),
                _RadioRow(
                  icon: Icons.block_outlined,
                  label: 'Excepto algunos',
                  sub: 'excluí a personas (becados, staff)',
                  selected: _quien == _AQuien.exceptoAlgunos,
                  gc: gc,
                  onTap: () => setState(() => _quien = _AQuien.exceptoAlgunos),
                ),
              ]),
            ),

            // Member picker (shown when not "todos" and not editing)
            if (!_editMode && _quien != _AQuien.todos) ...[
              const SizedBox(height: 10),
              SGEyebrow(_quien == _AQuien.algunos
                  ? 'Elegí a quién cobrarle'
                  : 'Excluí a quiénes no cobrar'),
              const SizedBox(height: 6),
              Consumer(
                builder: (context, ref, _) {
                  final miembrosAsync =
                      ref.watch(miembrosProvider(widget.grupoId));
                  final uid =
                      ref.watch(authStateProvider).valueOrNull?.uid ?? '';
                  return miembrosAsync.when(
                    loading: () => const SizedBox(
                      height: 40,
                      child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (miembros) {
                      final otros =
                          miembros.where((m) => m.uid != uid).toList();
                      if (otros.isEmpty) return const SizedBox.shrink();
                      return Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: otros.map((m) {
                          final sel =
                              _seleccionados.containsKey(m.uid);
                          return FilterChip(
                            avatar:
                                SGAvatar(name: m.nombreCompleto, size: 18),
                            label: Text(m.nombreCompleto,
                                style: const TextStyle(fontSize: 12)),
                            selected: sel,
                            selectedColor: gc.withValues(alpha: 0.15),
                            checkmarkColor: gc,
                            onSelected: (v) => setState(() {
                              if (v) {
                                _seleccionados[m.uid] =
                                    m.nombreCompleto;
                              } else {
                                _seleccionados.remove(m.uid);
                              }
                            }),
                          );
                        }).toList(),
                      );
                    },
                  );
                },
              ),
              if (_seleccionados.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _quien == _AQuien.algunos
                        ? '${_seleccionados.length} seleccionado${_seleccionados.length == 1 ? '' : 's'}'
                        : '${_seleccionados.length} excluido${_seleccionados.length == 1 ? '' : 's'}',
                    style: TextStyle(
                        fontSize: 12,
                        color: gc,
                        fontWeight: FontWeight.w600),
                  ),
                ),
            ],

            // "Opciones" tenía tres switches (pago parcial, avisar al emitir,
            // recordatorio) que no se guardaban ni hacían nada. Se retiraron
            // hasta que exista la funcionalidad detrás; en su lugar va el
            // resumen real de lo que se va a emitir.
            if (!_editMode) ...[
              const SGEyebrow('Resumen'),
              SGCard(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  _ResumenRow(
                    icon: Icons.receipt_long_outlined,
                    label: _cuotasAEmitir == 1
                        ? '1 cuota'
                        : '$_cuotasAEmitir cuotas',
                    value: '\$ ${_fmt(monto)} c/u',
                  ),
                  const SizedBox(height: 8),
                  _ResumenRow(
                    icon: Icons.groups_outlined,
                    label: _quien == _AQuien.todos
                        ? 'Todo el grupo'
                        : _quien == _AQuien.algunos
                            ? 'Miembros elegidos'
                            : 'Todos menos los excluidos',
                    value: '$efectivos ${efectivos == 1 ? 'miembro' : 'miembros'}',
                  ),
                  const SizedBox(height: 8),
                  _ResumenRow(
                    icon: Icons.event_outlined,
                    label: _esSerie ? 'Primer vencimiento' : 'Vencimiento',
                    value: _fecha(_vencimiento),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              const Row(children: [
                Icon(Icons.notifications_none_rounded,
                    size: 15, color: AppTheme.textMuted),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Al emitir, la cuota aparece en la novedades del grupo y en '
                    '"Mis cuotas" de cada miembro alcanzado.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: SGPillButton(
            icon: _editMode ? Icons.save_rounded : Icons.send_rounded,
            label: _editMode
                ? 'Guardar cambios'
                : _esSerie
                    ? 'Emitir $_cuotasAEmitir cuotas a $efectivos ${efectivos == 1 ? 'miembro' : 'miembros'}'
                    : 'Emitir cuota a $efectivos ${efectivos == 1 ? 'miembro' : 'miembros'}',
            expand: true, size: SGSize.lg,
            onPressed: loading ? null : _emitir,
          ),
        ),
      ),
    );
  }

  void _setRecurrencia(_Recurrencia r) {
    setState(() {
      _rec = r;
      // Un default por frecuencia: 12 anuales eran 12 años de cuotas.
      _cantidad = switch (r) {
        _Recurrencia.mensual => 6,
        _Recurrencia.trimestral => 4,
        _Recurrencia.anual => 2,
        _Recurrencia.unaVez => 1,
      };
    });
  }

  /// (etiqueta, fecha) — atajos habituales de vencimiento.
  List<(String, DateTime)> _atajosVencimiento() {
    final hoy = DateTime.now();
    return [
      ('Fin de mes', DateTime(hoy.year, hoy.month + 1, 0)),
      ('10 del próximo', DateTime(hoy.year, hoy.month + 1, 10)),
      ('Fin del próximo', DateTime(hoy.year, hoy.month + 2, 0)),
      ('En 7 días', DateTime(hoy.year, hoy.month, hoy.day + 7)),
    ];
  }

  bool _mismaFecha(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Días calendario, no diferencia de instantes: con el vencimiento a fin del
  /// día, `difference().inDays` decía "en 1 día" para algo que vence hoy.
  String _diffDays(DateTime d) {
    final hoy = DateTime.now();
    final diff = DateTime(d.year, d.month, d.day)
        .difference(DateTime(hoy.year, hoy.month, hoy.day))
        .inDays;
    if (diff < 0) return 'venció hace ${-diff} ${-diff == 1 ? 'día' : 'días'}';
    if (diff == 0) return 'vence hoy';
    if (diff == 1) return 'vence mañana';
    return 'en $diff días';
  }

  String _monthName(int m) => _monthNameOf(m);

  String _fmt(int n) =>
      n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
}

String _monthNameOf(int m) => const [
      'enero','febrero','marzo','abril','mayo','junio',
      'julio','agosto','septiembre','octubre','noviembre','diciembre',
    ][m - 1];

// ─────────────────────────────────────────────────────────────────────────────
class _StepperBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _StepperBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
              color: enabled ? AppTheme.borderStrong : AppTheme.border),
        ),
        child: Icon(icon,
            size: 18,
            color: enabled ? AppTheme.text : AppTheme.border),
      ),
    );
  }
}

class _ResumenRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ResumenRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 16, color: AppTheme.textMuted),
      const SizedBox(width: 10),
      Expanded(
        child: Text(label,
            style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
      ),
      Text(value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _PillChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PillChip({required this.label,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.text : AppTheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: selected ? AppTheme.text : AppTheme.border),
        ),
        child: Text(label, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppTheme.text)),
      ),
    );
  }
}

class _RadioRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;
  final Color gc;
  const _RadioRow({required this.icon, required this.label, required this.sub,
      required this.selected, required this.onTap, required this.gc});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(children: [
          Icon(icon, size: 22,
              color: selected ? gc : AppTheme.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
                Text(sub, style: const TextStyle(
                    fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
          ),
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: selected ? gc : AppTheme.borderStrong,
                  width: 2),
            ),
            child: selected
                ? Center(
                    child: Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle, color: gc,
                      ),
                    ),
                  )
                : null,
          ),
        ]),
      ),
    );
  }
}
