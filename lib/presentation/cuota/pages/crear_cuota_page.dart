import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../data/models/enums.dart';
import '../../../providers/cuota_provider.dart';
import '../../../providers/grupo_provider.dart';
import '../../../providers/auth_provider.dart';

/// Crear/emitir cuota (vista tesorero/admin).
/// La lógica de persistencia se conecta a tu `cuotaRepositoryProvider`.
class CrearCuotaPage extends ConsumerStatefulWidget {
  final String grupoId;
  const CrearCuotaPage({super.key, required this.grupoId});

  @override
  ConsumerState<CrearCuotaPage> createState() => _CrearCuotaPageState();
}

enum _Recurrencia { unaVez, mensual, trimestral, anual, custom }
enum _AQuien { todos, algunos, exceptoAlgunos }

class _CrearCuotaPageState extends ConsumerState<CrearCuotaPage> {
  final _conceptoCtrl = TextEditingController(text: 'Suscripción mensual — Mayo 2026');
  final _montoCtrl = TextEditingController(text: '8500');
  DateTime _vencimiento = DateTime.now().add(const Duration(days: 1));
  _Recurrencia _rec = _Recurrencia.mensual;
  _AQuien _quien = _AQuien.todos;
  bool _pagoParcial = true;
  bool _avisarAlEmitir = true;
  bool _recordatorio = true;
  // Member targeting: uid → nombreCompleto
  final Map<String, String> _seleccionados = {};

  @override
  void dispose() {
    _conceptoCtrl.dispose();
    _montoCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFecha() async {
    final d = await showDatePicker(
      context: context, initialDate: _vencimiento,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _vencimiento = d);
  }

  Future<void> _emitir() async {
    final titulo = _conceptoCtrl.text.trim();
    final monto = double.tryParse(_montoCtrl.text.replaceAll('.', '').replaceAll(',', '.'));
    if (titulo.isEmpty || monto == null || monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completá el concepto y el monto')),
      );
      return;
    }

    try {
      final notifier = ref.read(crearCuotaProvider.notifier);
      final uids = _seleccionados.keys.toList();
      final miembrosUids = _quien == _AQuien.algunos && uids.isNotEmpty
          ? uids : null;
      final excluidosUids = _quien == _AQuien.exceptoAlgunos && uids.isNotEmpty
          ? uids : null;

      if (_rec == _Recurrencia.unaVez || _rec == _Recurrencia.custom) {
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
          _Recurrencia.mensual     => FrecuenciaCuota.mensual,
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
          totalCuotas: _rec == _Recurrencia.anual ? 12 : 3,
          miembrosUids: miembrosUids,
          excluidosUids: excluidosUids,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Suscripción emitida ✓')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gc = ref.watch(grupoColorProvider(widget.grupoId));
    final miembros = ref.watch(miembrosProvider(widget.grupoId)).valueOrNull ?? [];
    final miembrosTotales = miembros.isEmpty ? 0 : miembros.length;
    final monto = int.tryParse(_montoCtrl.text) ?? 0;
    final monthsShort = ['ENE','FEB','MAR','ABR','MAY','JUN','JUL','AGO','SEP','OCT','NOV','DIC'];
    final efectivos = _quien == _AQuien.algunos
        ? _seleccionados.length
        : _quien == _AQuien.exceptoAlgunos
            ? (miembrosTotales - _seleccionados.length).clamp(0, miembrosTotales)
            : miembrosTotales;
    final total = monto * efectivos;

    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      appBar: isDesktop ? null : AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, size: 22),
          onPressed: () => context.pop(),
        ),
        title: const Text('Nueva suscripción'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SGPillButton(
              label: 'Emitir', size: SGSize.sm, onPressed: _emitir,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SGChip(
              icon: Icons.account_balance_outlined,
              label: 'Panel tesorero',
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
            const SGEyebrow('Vencimiento'),
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
                      Text(_diffDays(_vencimiento),
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
                const Icon(Icons.edit_calendar_outlined,
                    color: AppTheme.textMuted),
              ]),
            ),

            // Recurrencia
            const SGEyebrow('Repetición'),
            Wrap(spacing: 6, runSpacing: 6, children: [
              _PillChip(label: 'Una vez',     selected: _rec == _Recurrencia.unaVez,     onTap: () => setState(() => _rec = _Recurrencia.unaVez)),
              _PillChip(label: 'Mensual',     selected: _rec == _Recurrencia.mensual,    onTap: () => setState(() => _rec = _Recurrencia.mensual)),
              _PillChip(label: 'Trimestral',  selected: _rec == _Recurrencia.trimestral, onTap: () => setState(() => _rec = _Recurrencia.trimestral)),
              _PillChip(label: 'Anual',       selected: _rec == _Recurrencia.anual,      onTap: () => setState(() => _rec = _Recurrencia.anual)),
              _PillChip(label: 'Personalizado',selected: _rec == _Recurrencia.custom,    onTap: () => setState(() => _rec = _Recurrencia.custom)),
            ]),
            if (_rec == _Recurrencia.mensual)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: gc.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    Icon(Icons.info_outline, size: 18,
                        color: gc),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Se emite automáticamente cada mes el día 5, con vencimiento el día 20.',
                        style: TextStyle(fontSize: 12,
                            color: gc, height: 1.4),
                      ),
                    ),
                  ]),
                ),
              ),

            // A quien
            const SGEyebrow('A quién se le cobra'),
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

            // Member picker (shown when not "todos")
            if (_quien != _AQuien.todos) ...[
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

            // Opciones
            const SGEyebrow('Opciones'),
            SGCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  activeThumbColor: gc,
                  secondary: const Icon(Icons.splitscreen_outlined,
                      color: AppTheme.good),
                  title: const Text('Permitir pago parcial',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Los miembros pueden mandar varios comprobantes',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  value: _pagoParcial,
                  onChanged: (v) => setState(() => _pagoParcial = v),
                ),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  activeThumbColor: gc,
                  secondary: Icon(Icons.campaign_outlined,
                      color: gc),
                  title: const Text('Avisar al emitir',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Notificación push a todos los miembros',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  value: _avisarAlEmitir,
                  onChanged: (v) => setState(() => _avisarAlEmitir = v),
                ),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  activeThumbColor: gc,
                  secondary: const Icon(Icons.warning_amber_outlined,
                      color: AppTheme.danger),
                  title: const Text('Recordatorio si está por vencer',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text('48hs antes y el día del vencimiento',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  value: _recordatorio,
                  onChanged: (v) => setState(() => _recordatorio = v),
                ),
              ]),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: SGPillButton(
            icon: Icons.send_rounded,
            label: 'Emitir suscripción a $efectivos miembros',
            expand: true, size: SGSize.lg,
            onPressed: _emitir,
          ),
        ),
      ),
    );
  }

  String _diffDays(DateTime d) {
    final diff = d.difference(DateTime.now()).inDays;
    if (diff <= 0) return 'hoy';
    if (diff == 1) return 'en 1 día';
    return 'en $diff días';
  }

  String _monthName(int m) => const [
        'enero','febrero','marzo','abril','mayo','junio',
        'julio','agosto','septiembre','octubre','noviembre','diciembre',
      ][m - 1];

  String _fmt(int n) =>
      n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
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
