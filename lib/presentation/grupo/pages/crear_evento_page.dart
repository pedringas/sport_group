import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../data/models/enums.dart';
import '../../../providers/grupo_provider.dart';
import '../../../providers/noticia_provider.dart';

/// Crear evento (delegado/admin). Guarda como noticia con tieneListado=true.
class CrearEventoPage extends ConsumerStatefulWidget {
  final String grupoId;
  const CrearEventoPage({super.key, required this.grupoId});

  @override
  ConsumerState<CrearEventoPage> createState() => _CrearEventoPageState();
}

enum _EventType { partido, entrenamiento, asado, social, otro }

class _CrearEventoPageState extends ConsumerState<CrearEventoPage> {
  _EventType _tipo = _EventType.partido;
  final _tituloCtrl = TextEditingController();
  final _lugarCtrl  = TextEditingController();
  final _notasCtrl  = TextEditingController();

  DateTime _fecha = DateTime.now().add(const Duration(days: 4));
  TimeOfDay _hora = const TimeOfDay(hour: 16, minute: 0);
  TimeOfDay _horaFin = const TimeOfDay(hour: 18, minute: 0);

  bool _listaAsistencia = true;
  bool _cierreAsistencia = true;
  bool _recordatorio = true;
  bool _notifWhatsapp = false;
  bool _fijarEnNoticias = false;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _lugarCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFecha() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _fecha = d);
  }

  Future<void> _pickHora() async {
    final t = await showTimePicker(context: context, initialTime: _hora);
    if (t != null) setState(() => _hora = t);
  }

  Future<void> _pickHoraFin() async {
    final t = await showTimePicker(context: context, initialTime: _horaFin);
    if (t != null) setState(() => _horaFin = t);
  }

  NoticiaCategoria get _categoriaNoticia {
    switch (_tipo) {
      case _EventType.partido:
        return NoticiaCategoria.partido;
      case _EventType.entrenamiento:
        return NoticiaCategoria.entrenamiento;
      default:
        return NoticiaCategoria.evento;
    }
  }

  Future<void> _publicar() async {
    final titulo = _tituloCtrl.text.trim();
    if (titulo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresá un título para el evento')),
      );
      return;
    }

    // Build the event datetime from date + start time
    final fechaEvento = DateTime(
      _fecha.year, _fecha.month, _fecha.day,
      _hora.hour, _hora.minute,
    );
    // The event "expires" (caducidad) at its start time so it leaves the feed
    final fechaCaducidad = fechaEvento;

    // Combine lugar and notas into the contenido field
    final lugar = _lugarCtrl.text.trim();
    final notas = _notasCtrl.text.trim();
    final horaLabel =
        '${_hora.format(context)} – ${_horaFin.format(context)}';
    final contenido = [
      if (lugar.isNotEmpty) '📍 $lugar · $horaLabel',
      if (notas.isNotEmpty) notas,
    ].join('\n');

    try {
      await ref.read(crearNoticiaProvider.notifier).crear(
            grupoId: widget.grupoId,
            titulo: titulo,
            contenido: contenido,
            tieneListado: _listaAsistencia,
            categoria: _categoriaNoticia,
            fechaEvento: fechaEvento,
            fechaCaducidad: fechaCaducidad,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Evento publicado y notificado al grupo ✓'),
            backgroundColor: AppTheme.good,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al publicar: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gc = ref.watch(grupoColorProvider(widget.grupoId));
    final monthsShort = ['ENE','FEB','MAR','ABR','MAY','JUN','JUL','AGO','SEP','OCT','NOV','DIC'];
    final weekdayShort = ['LUN','MAR','MIÉ','JUE','VIE','SÁB','DOM'];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, size: 22),
          onPressed: () => context.pop(),
        ),
        title: const Text('Nuevo evento'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SGPillButton(
              label: 'Publicar', size: SGSize.sm, onPressed: _publicar,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author chip
            const Row(children: [
              SGAvatar(name: 'Yo', size: 36),
              SizedBox(width: 10),
              Expanded(child: Wrap(
                spacing: 6,
                children: [
                  SGChip(icon: Icons.assignment_outlined,
                      label: 'Delegado', tone: SGChipTone.accent),
                ],
              )),
            ]),

            const SGEyebrow('Tipo'),
            Wrap(spacing: 6, runSpacing: 6, children: [
              _TipoChip(label: 'Partido', icon: Icons.sports_soccer,
                  selected: _tipo == _EventType.partido, gc: gc,
                  onTap: () => setState(() => _tipo = _EventType.partido)),
              _TipoChip(label: 'Entrenamiento', icon: Icons.fitness_center,
                  selected: _tipo == _EventType.entrenamiento, gc: gc,
                  onTap: () => setState(() => _tipo = _EventType.entrenamiento)),
              _TipoChip(label: 'Asado', icon: Icons.outdoor_grill,
                  selected: _tipo == _EventType.asado, gc: gc,
                  onTap: () => setState(() => _tipo = _EventType.asado)),
              _TipoChip(label: 'Social', icon: Icons.celebration,
                  selected: _tipo == _EventType.social, gc: gc,
                  onTap: () => setState(() => _tipo = _EventType.social)),
              _TipoChip(label: 'Otro', icon: Icons.more_horiz,
                  selected: _tipo == _EventType.otro, gc: gc,
                  onTap: () => setState(() => _tipo = _EventType.otro)),
            ]),

            // Title
            const SizedBox(height: 18),
            TextField(
              controller: _tituloCtrl,
              style: GoogleFonts.bricolageGrotesque(
                fontWeight: FontWeight.w700, fontSize: 24, letterSpacing: -0.4),
              decoration: const InputDecoration(
                hintText: 'Título del evento',
                border: InputBorder.none, enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none, filled: false,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),

            // Date + times card
            const SizedBox(height: 8),
            SGCard(
              padding: const EdgeInsets.all(12),
              onTap: _pickFecha,
              child: Row(
                children: [
                  Container(
                    width: 60,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    decoration: BoxDecoration(
                      color: gc.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(children: [
                      Text(weekdayShort[_fecha.weekday - 1],
                          style: GoogleFonts.bricolageGrotesque(
                              fontSize: 10, fontWeight: FontWeight.w700,
                              color: gc, letterSpacing: 1)),
                      Text('${_fecha.day}',
                          style: GoogleFonts.bricolageGrotesque(
                              fontSize: 24, fontWeight: FontWeight.w700,
                              color: gc, height: 1)),
                      Text(monthsShort[_fecha.month - 1],
                          style: GoogleFonts.bricolageGrotesque(
                              fontSize: 10, fontWeight: FontWeight.w700,
                              color: gc, letterSpacing: 1)),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${weekdayShort[_fecha.weekday - 1].toLowerCase()} ${_fecha.day} de ${_monthName(_fecha.month)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, children: [
                          InkWell(
                            onTap: _pickHora,
                            child: _TimeChip(
                                label: _hora.format(context)),
                          ),
                          const Text('—',
                              style: TextStyle(color: AppTheme.textMuted)),
                          InkWell(
                            onTap: _pickHoraFin,
                            child: _TimeChip(
                                label: _horaFin.format(context)),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit_calendar_outlined,
                      color: AppTheme.textMuted),
                ],
              ),
            ),

            // Lugar
            const SizedBox(height: 10),
            SGCard(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Icon(Icons.place_outlined, color: gc),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _lugarCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Lugar', isDense: true,
                      border: InputBorder.none, enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none, filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const Icon(Icons.map_outlined, color: AppTheme.textMuted),
              ]),
            ),

            // Notas
            const SizedBox(height: 10),
            TextField(
              controller: _notasCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Notas para el grupo (qué llevar, vestimenta, etc.)',
              ),
            ),

            // Opciones
            const SGEyebrow('Opciones'),
            SGCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                _ToggleRow(
                  icon: Icons.checklist_rounded, iconColor: AppTheme.accent,
                  title: 'Lista de asistencia',
                  subtitle: 'Tri-estado: Voy · Tal vez · No voy',
                  value: _listaAsistencia, gc: gc,
                  onChanged: (v) => setState(() => _listaAsistencia = v),
                ),
                if (_listaAsistencia)
                  _ToggleRow(
                    icon: Icons.lock_clock_outlined,
                    iconColor: gc,
                    title: 'Cierre de asistencia',
                    subtitle: 'Sábado 12:00',
                    value: _cierreAsistencia, gc: gc,
                    onChanged: (v) => setState(() => _cierreAsistencia = v),
                  ),
                _ToggleRow(
                  icon: Icons.notifications_active_outlined,
                  iconColor: AppTheme.good,
                  title: 'Recordatorio automático',
                  subtitle: 'Mandar push 24hs antes',
                  value: _recordatorio, gc: gc,
                  onChanged: (v) => setState(() => _recordatorio = v),
                ),
                _ToggleRow(
                  icon: Icons.chat_bubble_outline, iconColor: const Color(0xFF25D366),
                  title: 'Notificar por WhatsApp',
                  subtitle: 'Compartí el evento al publicar',
                  value: _notifWhatsapp, gc: gc,
                  onChanged: (v) => setState(() => _notifWhatsapp = v),
                ),
                _ToggleRow(
                  icon: Icons.push_pin_outlined, iconColor: AppTheme.accent,
                  title: 'Fijar en noticias',
                  subtitle: 'Aparece arriba del feed',
                  value: _fijarEnNoticias, gc: gc,
                  onChanged: (v) => setState(() => _fijarEnNoticias = v),
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
            icon: Icons.event_available_rounded,
            label: 'Crear y avisar al grupo',
            expand: true, size: SGSize.lg,
            onPressed: _publicar,
          ),
        ),
      ),
    );
  }

  String _monthName(int m) => const [
        'enero','febrero','marzo','abril','mayo','junio',
        'julio','agosto','septiembre','octubre','noviembre','diciembre',
      ][m - 1];
}

// ─────────────────────────────────────────────────────────────────────────────
class _TipoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color gc;
  const _TipoChip({required this.label, required this.icon,
      required this.selected, required this.onTap, required this.gc});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? gc : AppTheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: selected ? gc : AppTheme.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16,
              color: selected ? Colors.white : AppTheme.textMuted),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppTheme.text)),
        ]),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String label;
  const _TimeChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.schedule_outlined, size: 14, color: AppTheme.text),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color gc;

  const _ToggleRow({required this.icon, required this.iconColor,
      required this.title, required this.subtitle,
      required this.value, required this.onChanged, required this.gc});

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      activeThumbColor: gc,
      secondary: Icon(icon, color: iconColor),
      title: Text(title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
      value: value,
      onChanged: onChanged,
    );
  }
}
