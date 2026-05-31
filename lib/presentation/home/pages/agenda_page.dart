import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../data/models/noticia_model.dart';
import '../../../data/models/grupo_model.dart';
import '../../../data/models/enums.dart';
import '../../../providers/grupo_provider.dart';
import '../../../providers/noticia_provider.dart';

// ── Aggregated event item ─────────────────────────────────────────────────────

class _AgendaItem {
  final NoticiaModel noticia;
  final GrupoModel grupo;
  final DateTime eventDate; // fechaEvento ?? fechaCaducidad
  _AgendaItem(this.noticia, this.grupo, this.eventDate);
}

// ── View mode ─────────────────────────────────────────────────────────────────

enum _ViewMode { lista, calendario }

// ── Page ──────────────────────────────────────────────────────────────────────

class AgendaPage extends ConsumerStatefulWidget {
  const AgendaPage({super.key});

  @override
  ConsumerState<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends ConsumerState<AgendaPage> {
  _ViewMode _view = _ViewMode.lista;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final grupos = ref.watch(userGruposProvider).valueOrNull ?? [];
    final favoritosIds = ref.watch(gruposFavoritosProvider).valueOrNull ?? {};

    final targetGrupos = grupos
        .where((g) =>
            g.tipo == TipoGrupo.privado || favoritosIds.contains(g.id))
        .toList();

    final allEvents = <_AgendaItem>[];
    final now = DateTime.now();
    for (final grupo in targetGrupos) {
      final noticias =
          ref.watch(noticiasProvider(grupo.id)).valueOrNull ?? [];
      for (final n in noticias.where((n) => n.tieneListado)) {
        // Only show events that have an event date set
        final eventDate = n.fechaEvento ?? n.fechaCaducidad;
        if (eventDate == null) continue;
        allEvents.add(_AgendaItem(n, grupo, eventDate));
      }
    }

    // Sort by event date ascending (soonest first); past events go to the end
    allEvents.sort((a, b) {
      final aFuture = !a.eventDate.isBefore(now);
      final bFuture = !b.eventDate.isBefore(now);
      if (aFuture && !bFuture) return -1;
      if (!aFuture && bFuture) return 1;
      return a.eventDate.compareTo(b.eventDate);
    });

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Agenda',
                        style: GoogleFonts.bricolageGrotesque(
                          fontWeight: FontWeight.w700,
                          fontSize: 24,
                          letterSpacing: -0.4,
                          color: AppTheme.text,
                        ),
                      ),
                      const Text(
                        'Eventos de tus grupos privados y favoritos',
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                // Toggle buttons
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Row(
                    children: [
                      _ViewToggleBtn(
                        icon: Icons.view_list_rounded,
                        selected: _view == _ViewMode.lista,
                        onTap: () => setState(() {
                          _view = _ViewMode.lista;
                        }),
                      ),
                      _ViewToggleBtn(
                        icon: Icons.calendar_month_rounded,
                        selected: _view == _ViewMode.calendario,
                        onTap: () => setState(() {
                          _view = _ViewMode.calendario;
                          _selectedMonth = DateTime(
                              DateTime.now().year, DateTime.now().month);
                          _selectedDay = null;
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Content ───────────────────────────────────────────────
          Expanded(
            child: _view == _ViewMode.lista
                ? _ListView(events: allEvents)
                : _CalendarView(
                    events: allEvents,
                    selectedMonth: _selectedMonth,
                    selectedDay: _selectedDay,
                    onMonthChanged: (m) =>
                        setState(() => _selectedMonth = m),
                    onDaySelected: (d) => setState(() =>
                        _selectedDay =
                            _selectedDay != null && _isSameDay(_selectedDay!, d)
                                ? null
                                : d),
                  ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ── Toggle button ─────────────────────────────────────────────────────────────

class _ViewToggleBtn extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ViewToggleBtn(
      {required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1))
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 20,
          color: selected ? AppTheme.primary : AppTheme.textMuted,
        ),
      ),
    );
  }
}

// ── List view ─────────────────────────────────────────────────────────────────

class _ListView extends StatelessWidget {
  final List<_AgendaItem> events;
  const _ListView({required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return _EmptyState();
    }

    // Group events by event date
    final Map<String, List<_AgendaItem>> byDay = {};
    for (final e in events) {
      final key = _dayKey(e.eventDate);
      byDay.putIfAbsent(key, () => []).add(e);
    }

    final days = byDay.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: days.length,
      itemBuilder: (_, i) {
        final day = days[i];
        final dayEvents = byDay[day]!;
        final date = dayEvents.first.eventDate;
        final isToday = _isToday(date);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isToday
                          ? AppTheme.primary
                          : AppTheme.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isToday
                          ? 'Hoy · ${DateFormat('d MMM', 'es_AR').format(date)}'
                          : DateFormat('EEEE d MMM', 'es_AR')
                              .format(date)
                              .replaceFirst(
                                  date.day.toString(),
                                  date.day.toString()),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color:
                            isToday ? Colors.white : AppTheme.textMuted,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...dayEvents.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _EventCard(item: item),
                )),
          ],
        );
      },
    );
  }

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }
}

// ── Calendar view ─────────────────────────────────────────────────────────────

class _CalendarView extends StatelessWidget {
  final List<_AgendaItem> events;
  final DateTime selectedMonth;
  final DateTime? selectedDay;
  final void Function(DateTime) onMonthChanged;
  final void Function(DateTime) onDaySelected;

  const _CalendarView({
    required this.events,
    required this.selectedMonth,
    required this.selectedDay,
    required this.onMonthChanged,
    required this.onDaySelected,
  });

  // Returns event items that fall on a specific day (by event date)
  List<_AgendaItem> _eventsForDay(DateTime day) {
    return events.where((e) {
      final d = e.eventDate;
      return d.year == day.year && d.month == day.month && d.day == day.day;
    }).toList();
  }

  // Set of days in selectedMonth that have events
  Set<int> _daysWithEvents() {
    return events
        .where((e) =>
            e.eventDate.year == selectedMonth.year &&
            e.eventDate.month == selectedMonth.month)
        .map((e) => e.eventDate.day)
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    final daysWithEvents = _daysWithEvents();

    // Events to show: selected day or all in month
    final visibleEvents = selectedDay != null
        ? _eventsForDay(selectedDay!)
        : events
            .where((e) =>
                e.eventDate.year == selectedMonth.year &&
                e.eventDate.month == selectedMonth.month)
            .toList();

    return Column(
      children: [
        // ── Calendar widget
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                // Month nav
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => onMonthChanged(DateTime(
                          selectedMonth.year, selectedMonth.month - 1)),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.chevron_left_rounded,
                            size: 20, color: AppTheme.text),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        DateFormat('MMMM yyyy', 'es_AR')
                            .format(selectedMonth)
                            .toUpperCase()
                            .split(' ')
                            .map((w) =>
                                w[0].toUpperCase() + w.substring(1))
                            .join(' '),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.bricolageGrotesque(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppTheme.text,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => onMonthChanged(DateTime(
                          selectedMonth.year, selectedMonth.month + 1)),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.chevron_right_rounded,
                            size: 20, color: AppTheme.text),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Day of week headers
                Row(
                  children: ['L', 'M', 'M', 'J', 'V', 'S', 'D']
                      .map((d) => Expanded(
                            child: Center(
                              child: Text(
                                d,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textMuted,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),

                const SizedBox(height: 8),

                // Days grid
                _CalendarGrid(
                  month: selectedMonth,
                  daysWithEvents: daysWithEvents,
                  selectedDay: selectedDay,
                  onDayTap: onDaySelected,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ── Events list below calendar
        Expanded(
          child: visibleEvents.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_busy_rounded,
                            size: 40, color: AppTheme.border),
                        const SizedBox(height: 12),
                        Text(
                          selectedDay != null
                              ? 'Sin eventos este día'
                              : 'Sin eventos este mes',
                          style: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: visibleEvents.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) =>
                      _EventCard(item: visibleEvents[i]),
                ),
        ),
      ],
    );
  }
}

// ── Calendar grid ─────────────────────────────────────────────────────────────

class _CalendarGrid extends StatelessWidget {
  final DateTime month;
  final Set<int> daysWithEvents;
  final DateTime? selectedDay;
  final void Function(DateTime) onDayTap;

  const _CalendarGrid({
    required this.month,
    required this.daysWithEvents,
    required this.selectedDay,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth =
        DateTime(month.year, month.month + 1, 0).day;

    // Monday = 1, Sunday = 7 → offset 0-6
    // DateTime.monday = 1, so offset = weekday - 1
    final startOffset = (firstDay.weekday - 1) % 7;

    final totalCells = startOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Column(
      children: List.generate(rows, (row) {
        return Row(
          children: List.generate(7, (col) {
            final cellIndex = row * 7 + col;
            final dayNum = cellIndex - startOffset + 1;

            if (dayNum < 1 || dayNum > daysInMonth) {
              return const Expanded(child: SizedBox(height: 44));
            }

            final date = DateTime(month.year, month.month, dayNum);
            final isToday = date.year == today.year &&
                date.month == today.month &&
                date.day == today.day;
            final isSelected = selectedDay != null &&
                selectedDay!.year == date.year &&
                selectedDay!.month == date.month &&
                selectedDay!.day == date.day;
            final hasEvent = daysWithEvents.contains(dayNum);

            return Expanded(
              child: GestureDetector(
                onTap: () => onDayTap(date),
                child: Container(
                  height: 44,
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primary
                        : isToday
                            ? AppTheme.primarySoft
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: isToday && !isSelected
                        ? Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.4),
                            width: 1.5)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayNum',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isToday || isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : isToday
                                  ? AppTheme.primary
                                  : AppTheme.text,
                        ),
                      ),
                      if (hasEvent)
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.8)
                                : AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                        )
                      else
                        const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      }),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month_rounded,
                size: 64, color: AppTheme.border),
            const SizedBox(height: 16),
            Text(
              'Sin eventos próximos',
              style: GoogleFonts.bricolageGrotesque(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppTheme.text,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Los eventos aparecen cuando alguien\npublica una noticia con lista de asistencia.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Event card ────────────────────────────────────────────────────────────────

class _EventCard extends StatelessWidget {
  final _AgendaItem item;
  const _EventCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final n = item.noticia;
    final g = item.grupo;
    final date = item.eventDate;
    final now = DateTime.now();
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    final isPast = date.isBefore(DateTime(now.year, now.month, now.day));

    final dateColor = isPast
        ? AppTheme.textMuted
        : isToday
            ? AppTheme.primary
            : AppTheme.primaryInk;
    final dateBg = isPast
        ? AppTheme.surfaceAlt
        : isToday
            ? AppTheme.primary
            : AppTheme.primarySoft;

    return GestureDetector(
      onTap: () => context.push('/group/${g.id}/noticias'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isPast
              ? AppTheme.surfaceAlt
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isToday
                  ? AppTheme.primary.withValues(alpha: 0.35)
                  : AppTheme.border),
        ),
        child: Row(
          children: [
            // Date block
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: dateBg,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    date.day.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: isToday ? Colors.white : dateColor,
                      height: 1,
                    ),
                  ),
                  Text(
                    DateFormat('MMM', 'es_AR').format(date).toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 9,
                      color: isToday ? Colors.white70 : dateColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    if (isPast)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Pasado',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textMuted)),
                      ),
                    Expanded(
                      child: Text(
                        n.titulo,
                        style: GoogleFonts.bricolageGrotesque(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: -0.2,
                          color: isPast ? AppTheme.textMuted : AppTheme.text,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      SGAvatar(
                        name: g.nombre,
                        imageUrl: g.logoUrl,
                        size: 14,
                        background: AppTheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          g.nombre,
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}
