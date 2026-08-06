import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../providers/gasto_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/grupo_provider.dart';
import '../../../data/models/gasto_model.dart';
import '../../../data/models/miembro_model.dart';

final _crearGastoProvider =
    AsyncNotifierProvider<CrearGastoNotifier, void>(CrearGastoNotifier.new);

class CrearGastoPage extends ConsumerStatefulWidget {
  final String grupoId;
  final String? grupoGastoId;
  final String? grupoGastoNombre;

  /// When non-null, the page enters edit mode pre-filled with this gasto.
  final GastoModel? gastoExistente;

  const CrearGastoPage({
    super.key,
    required this.grupoId,
    this.grupoGastoId,
    this.grupoGastoNombre,
    this.gastoExistente,
  });

  @override
  ConsumerState<CrearGastoPage> createState() => _CrearGastoPageState();

  @visibleForTesting
  static List<ParticipanteGasto> splitParticipants({
    required List<MiembroModel> allMiembros,
    required Set<String>? selectedUids,
    required String pagadorUid,
    required double monto,
  }) {
    final efectivos = selectedUids == null
        ? List<MiembroModel>.from(allMiembros)
        : allMiembros.where((m) => selectedUids.contains(m.uid)).toList();

    if (!efectivos.any((m) => m.uid == pagadorUid)) {
      final payer = allMiembros.where((m) => m.uid == pagadorUid).firstOrNull;
      if (payer != null) efectivos.add(payer);
    }

    final sharePerPerson = efectivos.isEmpty ? monto : monto / efectivos.length;

    return efectivos
        .map((m) => ParticipanteGasto(uid: m.uid, nombre: m.nombreCompleto, monto: sharePerPerson))
        .toList();
  }
}

class _CrearGastoPageState extends ConsumerState<CrearGastoPage> {
  final _tituloCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();
  String? _pagadorUid;
  String _pagadorNombre = '';
  int _catIdx = 0;
  DateTime _fecha = DateTime.now();

  // Participant selection: null = all members selected (default)
  Set<String>? _selectedUids;

  // Categories: Transporte / Comida / Bebida / Varios
  static const _categorias = [
    (cat: CategoriaGasto.transporte, icon: Icons.directions_car_rounded, label: 'Transporte'),
    (cat: CategoriaGasto.comida,     icon: Icons.restaurant_rounded,      label: 'Comida'),
    (cat: CategoriaGasto.bebida,     icon: Icons.local_bar_rounded,       label: 'Bebida'),
    (cat: CategoriaGasto.otro,       icon: Icons.category_rounded,        label: 'Varios'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.gastoExistente != null) {
        final g = widget.gastoExistente!;
        final catIdx = _categorias.indexWhere((c) => c.cat == g.categoria);
        setState(() {
          _pagadorUid = g.pagadorUid;
          _pagadorNombre = g.pagadorNombre;
          _tituloCtrl.text = g.titulo;
          _montoCtrl.text = g.monto.round().toString();
          _catIdx = catIdx >= 0 ? catIdx : 0;
          _fecha = g.fecha;
          _selectedUids = g.participantes.map((p) => p.uid).toSet();
        });
      } else {
        final uid = ref.read(authStateProvider).valueOrNull?.uid;
        final user = ref.read(currentUserProvider).valueOrNull;
        if (uid != null) {
          setState(() {
            _pagadorUid = uid;
            _pagadorNombre = user?.nombreCompleto ?? '';
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _montoCtrl.dispose();
    super.dispose();
  }

  // â”€â”€ Date picker â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _pickFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  // â”€â”€ Pagador picker â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _pickPagador(List<MiembroModel> miembros, Color gc) async {
    final selected = await showModalBottomSheet<MiembroModel>(
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
                '¿Quién pagó?',
                style: GoogleFonts.bricolageGrotesque(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
            ),
            ...miembros.map((m) => ListTile(
                  leading: SGAvatar(name: m.nombreCompleto, size: 36),
                  title: Text(m.nombreCompleto,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: m.uid == _pagadorUid
                      ? Icon(Icons.check_rounded, color: gc)
                      : null,
                  onTap: () => Navigator.pop(context, m),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null) {
      setState(() {
        _pagadorUid = selected.uid;
        _pagadorNombre = selected.nombreCompleto;
      });
    }
  }

  // â”€â”€ Save â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _guardar(List<MiembroModel> allMiembros) async {
    final titulo = _tituloCtrl.text.trim();
    final montoStr =
        _montoCtrl.text.replaceAll('.', '').replaceAll(',', '.');
    final monto = double.tryParse(montoStr) ?? 0;

    if (titulo.isEmpty || monto <= 0 || _pagadorUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completá el concepto y el monto')),
      );
      return;
    }

    final participantes = CrearGastoPage.splitParticipants(
      allMiembros: allMiembros,
      selectedUids: _selectedUids,
      pagadorUid: _pagadorUid!,
      monto: monto,
    );

    try {
      if (widget.gastoExistente != null) {
        await ref.read(_crearGastoProvider.notifier).editar(
              grupoId: widget.grupoId,
              gastoId: widget.gastoExistente!.id,
              titulo: titulo,
              monto: monto,
              participantes: participantes,
              categoria: _categorias[_catIdx].cat,
              tipo: TipoMovimiento.gasto,
              grupoGastoId: widget.grupoGastoId ??
                  widget.gastoExistente!.grupoGastoId,
              fecha: _fecha,
            );
      } else {
        await ref.read(_crearGastoProvider.notifier).crear(
              grupoId: widget.grupoId,
              titulo: titulo,
              monto: monto,
              pagadorUid: _pagadorUid!,
              pagadorNombre: _pagadorNombre,
              participantes: participantes,
              categoria: _categorias[_catIdx].cat,
              tipo: TipoMovimiento.gasto,
              grupoGastoId: widget.grupoGastoId,
              fecha: _fecha,
            );
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  // â”€â”€ Build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  Widget build(BuildContext context) {
    final gc = ref.watch(grupoColorProvider(widget.grupoId));
    final loading = ref.watch(_crearGastoProvider).isLoading;
    final miembrosAsync = ref.watch(miembrosProvider(widget.grupoId));
    final miembros = miembrosAsync.valueOrNull ?? [];

    // Effective selection
    final selectedUids = _selectedUids ?? miembros.map((m) => m.uid).toSet();
    final shareCount = selectedUids.isEmpty ? 1 : selectedUids.length;
    final montoNum = double.tryParse(
            _montoCtrl.text.replaceAll('.', '').replaceAll(',', '.')) ??
        0;
    final sharePerPerson = shareCount > 0 ? montoNum / shareCount : 0.0;

    String fechaLabel;
    try {
      fechaLabel = DateFormat('d \'de\' MMMM yyyy', 'es_AR').format(_fecha);
    } catch (_) {
      fechaLabel = DateFormat('d/MM/yyyy').format(_fecha);
    }
    // Capitalise first letter
    if (fechaLabel.isNotEmpty) {
      fechaLabel = fechaLabel[0].toUpperCase() + fechaLabel.substring(1);
    }

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        child: Column(
          children: [
            // â”€â”€ Top bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
                      widget.gastoExistente != null
                          ? 'Editar gasto'
                          : widget.grupoGastoNombre != null
                              ? widget.grupoGastoNombre!
                              : 'Nuevo gasto',
                      style: GoogleFonts.bricolageGrotesque(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: AppTheme.text,
                      ),
                    ),
                  ),
                  SGPillButton(
                    label: 'Guardar',
                    size: SGSize.sm,
                    onPressed: loading ? null : () => _guardar(miembros),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, AppTheme.kBottomNavPadding),
                children: [
                  // â”€â”€ Amount â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerSoft,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'MONTO',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: AppTheme.danger,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            const Text(
                              '− \$ ',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.danger,
                              ),
                            ),
                            Flexible(
                              child: TextField(
                                controller: _montoCtrl,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9.,]')),
                                ],
                                onChanged: (_) => setState(() {}),
                                style: GoogleFonts.bricolageGrotesque(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 50,
                                  letterSpacing: -2,
                                  color: AppTheme.danger,
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: '0',
                                  hintStyle: GoogleFonts.bricolageGrotesque(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 50,
                                    letterSpacing: -2,
                                    color: AppTheme.danger
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Per-person hint
                        if (shareCount > 1 && montoNum > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '\$ ${_fmtAmt(sharePerPerson)} por persona ($shareCount personas)',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.danger
                                    .withValues(alpha: 0.7),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // â”€â”€ Concepto â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  const SGEyebrow('Concepto'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: TextField(
                      controller: _tituloCtrl,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '¿En qué se gastó?',
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.text,
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // â”€â”€ Categoría â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  const SGEyebrow('Categoría'),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(_categorias.length, (i) {
                      final c = _categorias[i];
                      final sel = i == _catIdx;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: i < _categorias.length - 1 ? 8 : 0),
                          child: GestureDetector(
                            onTap: () => setState(() => _catIdx = i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10),
                              decoration: BoxDecoration(
                                color: sel
                                    ? gc
                                    : AppTheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: sel
                                    ? null
                                    : Border.all(color: AppTheme.border),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(c.icon,
                                      size: 20,
                                      color: sel
                                          ? Colors.white
                                          : AppTheme.textMuted),
                                  const SizedBox(height: 4),
                                  Text(
                                    c.label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: sel
                                          ? Colors.white
                                          : AppTheme.text,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 18),

                  // â”€â”€ Participantes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  if (miembros.isNotEmpty) ...[
                    Row(
                      children: [
                        const SGEyebrow('Participantes'),
                        const Spacer(),
                        if (_selectedUids != null)
                          GestureDetector(
                            onTap: () =>
                                setState(() => _selectedUids = null),
                            child: Text(
                              'Seleccionar todos',
                              style: TextStyle(
                                fontSize: 12,
                                color: gc,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        children: miembros.asMap().entries.map((entry) {
                          final i = entry.key;
                          final m = entry.value;
                          final checked = selectedUids.contains(m.uid);
                          final isLast = i == miembros.length - 1;
                          return Column(
                            children: [
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    if (_selectedUids == null) {
                                      _selectedUids = miembros
                                          .map((x) => x.uid)
                                          .toSet()
                                        ..remove(m.uid);
                                    } else {
                                      if (_selectedUids!.contains(m.uid)) {
                                        _selectedUids!.remove(m.uid);
                                      } else {
                                        _selectedUids!.add(m.uid);
                                      }
                                      if (_selectedUids!.length ==
                                          miembros.length) {
                                        _selectedUids = null;
                                      }
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.vertical(
                                  top: i == 0
                                      ? const Radius.circular(16)
                                      : Radius.zero,
                                  bottom: isLast
                                      ? const Radius.circular(16)
                                      : Radius.zero,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  child: Row(
                                    children: [
                                      SGAvatar(
                                          name: m.nombreCompleto,
                                          size: 32),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              m.uid == _pagadorUid
                                                  ? '${m.nombreCompleto.split(' ').first} (pagó)'
                                                  : m.nombreCompleto
                                                      .split(' ')
                                                      .first,
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight:
                                                      FontWeight.w600),
                                            ),
                                            if (checked && montoNum > 0)
                                              Text(
                                                '\$ ${_fmtAmt(sharePerPerson)}',
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        AppTheme.textMuted),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Checkbox(
                                        value: checked,
                                        onChanged: (_) {
                                          setState(() {
                                            if (_selectedUids == null) {
                                              _selectedUids = miembros
                                                  .map((x) => x.uid)
                                                  .toSet()
                                                ..remove(m.uid);
                                            } else {
                                              if (_selectedUids!
                                                  .contains(m.uid)) {
                                                _selectedUids!.remove(m.uid);
                                              } else {
                                                _selectedUids!.add(m.uid);
                                              }
                                              if (_selectedUids!.length ==
                                                  miembros.length) {
                                                _selectedUids = null;
                                              }
                                            }
                                          });
                                        },
                                        activeColor: gc,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(4)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (!isLast)
                                const Divider(
                                    height: 1, color: AppTheme.border),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // â”€â”€ Detalles â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  const SGEyebrow('Detalles'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      children: [
                        // Fecha ”” tappable
                        InkWell(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16)),
                          onTap: _pickFecha,
                          child: _DetailRow(
                            icon: Icons.calendar_month_rounded,
                            label: 'Fecha',
                            value: fechaLabel,
                            trailing: const Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: AppTheme.textMuted),
                          ),
                        ),
                        const Divider(height: 1, color: AppTheme.border),
                        // Pagado por ”” tappable
                        InkWell(
                          onTap: miembros.isEmpty
                              ? null
                              : () => _pickPagador(miembros, gc),
                          child: _DetailRow(
                            icon: Icons.person_rounded,
                            label: 'Pagado por',
                            value: _pagadorNombre.isEmpty
                                ? 'Seleccionar'
                                : _pagadorNombre,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_pagadorNombre.isNotEmpty)
                                  SGAvatar(name: _pagadorNombre, size: 24),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right_rounded,
                                    size: 18, color: AppTheme.textMuted),
                              ],
                            ),
                          ),
                        ),
                        if (widget.grupoGastoNombre != null ||
                            widget.gastoExistente?.grupoGastoId != null) ...[
                          const Divider(height: 1, color: AppTheme.border),
                          _DetailRow(
                            icon: Icons.folder_rounded,
                            label: 'Grupo',
                            value: widget.grupoGastoNombre ??
                                widget.gastoExistente?.grupoGastoId ??
                                'General',
                            last: true,
                          ),
                        ] else ...[
                          const Divider(height: 1, color: AppTheme.border),
                          const _DetailRow(
                            icon: Icons.folder_outlined,
                            label: 'Grupo',
                            value: 'General',
                            last: true,
                          ),
                        ],
                      ],
                    ),
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
            icon: Icons.check_rounded,
            label: widget.gastoExistente != null
                ? 'Guardar cambios'
                : 'Registrar gasto',
            expand: true,
            onPressed: loading ? null : () => _guardar(miembros),
          ),
        ),
      ),
    );
  }

  String _fmtAmt(double v) => v
      .round()
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
}

// â”€â”€ _DetailRow â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;
  final bool last;
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMuted)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
