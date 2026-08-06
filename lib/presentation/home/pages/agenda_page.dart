import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/noticia_model.dart';
import '../../../data/models/grupo_model.dart';
import '../../../data/models/enums.dart';
import '../../../providers/grupo_provider.dart';
import '../../../providers/noticia_provider.dart';
import '../../../providers/auth_provider.dart';

// ── Aggregated event item ─────────────────────────────────────────────────────

class _AgendaItem {
  final NoticiaModel noticia;
  final GrupoModel grupo;
  final DateTime eventDate;
  _AgendaItem(this.noticia, this.grupo, this.eventDate);
}

// ── Page ──────────────────────────────────────────────────────────────────────

class AgendaPage extends ConsumerStatefulWidget {
  const AgendaPage({super.key});

  @override
  ConsumerState<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends ConsumerState<AgendaPage> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDay = DateTime(
      DateTime.now().year, DateTime.now().month, DateTime.now().day);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final grupos = ref.watch(userGruposProvider).valueOrNull ?? [];
    final favoritosIds = ref.watch(gruposFavoritosProvider).valueOrNull ?? {};

    final targetGrupos = grupos
        .where((g) =>
            g.tipo == TipoGrupo.privado || favoritosIds.contains(g.id))
        .toList();

    final allEvents = <_AgendaItem>[];
    for (final grupo in targetGrupos) {
      final noticias =
          ref.watch(noticiasProvider(grupo.id)).valueOrNull ?? [];
      for (final n in noticias.where((n) => n.tieneListado)) {
        final eventDate = n.fechaEvento ?? n.fechaCaducidad;
        if (eventDate == null) continue;
        allEvents.add(_AgendaItem(n, grupo, eventDate));
      }
    }

    allEvents.sort((a, b) => a.eventDate.compareTo(b.eventDate));

    final monthEvents = allEvents
        .where((e) =>
            e.eventDate.year == _selectedMonth.year &&
            e.eventDate.month == _selectedMonth.month)
        .toList();

    final dayEvents = allEvents
        .where((e) => _isSameDay(e.eventDate, _selectedDay))
        .toList();

    // Build map: day → list of group colors (for dots)
    final Map<int, List<Color>> dotsByDay = {};
    for (final e in monthEvents) {
      final day = e.eventDate.day;
      dotsByDay.putIfAbsent(day, () => []).add(e.grupo.primaryColor);
    }

    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppTheme.kResponsiveBreakpoint;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                if (!isDesktop)
                  Expanded(
                    child: Text(
                      'Agenda',
                      style: GoogleFonts.bricolageGrotesque(
                        fontWeight: FontWeight.w700,
                        fontSize: 24,
                        letterSpacing: -0.4,
                        color: AppTheme.text,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                IconButton(
                  icon: const Icon(Icons.view_column_outlined, size: 20),
                  color: AppTheme.textMuted,
                  tooltip: 'Vista compacta',
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.add_rounded, size: 22),
                  color: AppTheme.text,
                  tooltip: 'Crear evento',
                  onPressed: () {},
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Calendar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _CalendarWidget(
              month: _selectedMonth,
              dotsByDay: dotsByDay,
              selectedDay: _selectedDay,
              onMonthChanged: (m) => setState(() {
                _selectedMonth = m;
                _selectedDay =
                    DateTime(m.year, m.month, DateTime.now().day.clamp(1,
                        DateTime(m.year, m.month + 1, 0).day));
              }),
              onDaySelected: (d) => setState(() => _selectedDay = d),
            ),
          ),

          const SizedBox(height: 16),

          // ── Day label
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Text(
                  _dayLabel(_selectedDay),
                  style: GoogleFonts.bricolageGrotesque(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppTheme.text,
                    letterSpacing: -0.2,
                  ),
                ),
                if (dayEvents.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${dayEvents.length} evento${dayEvents.length != 1 ? 's' : ''}'
                    ' en ${_gruposCount(dayEvents)} grupo${_gruposCount(dayEvents) != 1 ? 's' : ''}',
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textMuted),
                  ),
                ],
              ],
            ),
          ),

          // ── Event list
          Expanded(
            child: dayEvents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.event_available_rounded,
                            size: 40, color: AppTheme.border),
                        const SizedBox(height: 12),
                        Text(
                          'Sin eventos este día',
                          style: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        16, 0, 16, AppTheme.kBottomNavPadding),
                    itemCount: dayEvents.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _EventCard(
                      item: dayEvents[i],
                      uid: ref.watch(authStateProvider).valueOrNull?.uid ?? '',
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final isToday =
        d.year == now.year && d.month == now.month && d.day == now.day;
    final name = isToday
        ? 'Hoy'
        : DateFormat('EEEE', 'es_AR').format(d);
    final num = d.day;
    return '${name[0].toUpperCase()}${name.substring(1)} $num';
  }

  int _gruposCount(List<_AgendaItem> events) =>
      events.map((e) => e.grupo.id).toSet().length;
}

// ── Calendar widget ───────────────────────────────────────────────────────────

class _CalendarWidget extends StatelessWidget {
  final DateTime month;
  final Map<int, List<Color>> dotsByDay;
  final DateTime selectedDay;
  final void Function(DateTime) onMonthChanged;
  final void Function(DateTime) onDaySelected;

  const _CalendarWidget({
    required this.month,
    required this.dotsByDay,
    required this.selectedDay,
    required this.onMonthChanged,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Month nav
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => onMonthChanged(
                  DateTime(month.year, month.month - 1)),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.chevron_left_rounded,
                    size: 20, color: AppTheme.textMuted),
              ),
            ),
            Text(
              _monthLabel(month),
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.text,
              ),
            ),
            GestureDetector(
              onTap: () => onMonthChanged(
                  DateTime(month.year, month.month + 1)),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.chevron_right_rounded,
                    size: 20, color: AppTheme.textMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Day headers
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
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),
        // Days grid
        _DaysGrid(
          month: month,
          dotsByDay: dotsByDay,
          selectedDay: selectedDay,
          onDayTap: onDaySelected,
        ),
      ],
    );
  }

  String _monthLabel(DateTime d) {
    final raw = DateFormat('MMMM yyyy', 'es_AR').format(d);
    return raw[0].toUpperCase() + raw.substring(1);
  }
}

// ── Days grid ─────────────────────────────────────────────────────────────────

class _DaysGrid extends StatelessWidget {
  final DateTime month;
  final Map<int, List<Color>> dotsByDay;
  final DateTime selectedDay;
  final void Function(DateTime) onDayTap;

  const _DaysGrid({
    required this.month,
    required this.dotsByDay,
    required this.selectedDay,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
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
              return const Expanded(child: SizedBox(height: 46));
            }

            final date = DateTime(month.year, month.month, dayNum);
            final isToday = date.year == today.year &&
                date.month == today.month &&
                date.day == today.day;
            final isSelected = date.year == selectedDay.year &&
                date.month == selectedDay.month &&
                date.day == selectedDay.day;
            final dots = dotsByDay[dayNum] ?? [];

            return Expanded(
              child: GestureDetector(
                onTap: () => onDayTap(date),
                child: Container(
                  height: 46,
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.text
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: isToday && !isSelected
                        ? Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.6),
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
                      const SizedBox(height: 2),
                      if (dots.isNotEmpty)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: dots
                              .take(3)
                              .map((c) => Container(
                                    width: 4,
                                    height: 4,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 1),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.white.withValues(alpha: 0.8)
                                          : c,
                                      shape: BoxShape.circle,
                                    ),
                                  ))
                              .toList(),
                        )
                      else
                        const SizedBox(height: 4),
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

// ── Event card ────────────────────────────────────────────────────────────────

class _EventCard extends ConsumerWidget {
  final _AgendaItem item;
  final String uid;
  const _EventCard({required this.item, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = item.noticia;
    final g = item.grupo;
    final date = item.eventDate;
    final groupColor = g.primaryColor;

    final asistenciaAsync = ref.watch(asistenciaProvider(
        (grupoId: g.id, noticiaId: n.id)));
    final lista = asistenciaAsync.valueOrNull ?? [];
    final confirmados = lista.where((a) => a.va).length;
    final yaVas = lista.any((a) => a.uid == uid && a.va);

    return GestureDetector(
      onTap: () => context.push(
        '/group/${g.id}/noticias/${n.id}/comentarios'
        '?titulo=${Uri.encodeComponent(n.titulo)}',
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(0, 14, 14, 14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time column
            SizedBox(
              width: 64,
              child: Column(
                children: [
                  Text(
                    DateFormat('HH:mm').format(date),
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.text,
                    ),
                  ),
                ],
              ),
            ),
            // Colored vertical bar
            Container(
              width: 3,
              height: 80,
              decoration: BoxDecoration(
                color: groupColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Group name
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: groupColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          g.nombre,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: groupColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Event title
                  Text(
                    n.titulo,
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.text,
                      letterSpacing: -0.2,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Footer row: confirmados + Vas button
                  Row(
                    children: [
                      if (confirmados > 0)
                        Text(
                          '$confirmados confirmados',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textMuted),
                        ),
                      const Spacer(),
                      _VasChip(
                        active: yaVas,
                        onTap: () => _toggleAsistencia(context, ref, yaVas),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleAsistencia(
      BuildContext context, WidgetRef ref, bool yaVas) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    try {
      final repo = ref.read(noticiaRepositoryProvider);
      if (yaVas) {
        await repo.removeAsistencia(item.grupo.id, item.noticia.id, user.uid);
      } else {
        await repo.setAsistencia(
          grupoId: item.grupo.id,
          noticiaId: item.noticia.id,
          uid: user.uid,
          nombre: user.displayName ?? '',
          avatarUrl: user.photoURL,
          estado: 'va',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

class _VasChip extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _VasChip({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppTheme.good : AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(999),
          border: active
              ? null
              : Border.all(color: AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (active)
              const Icon(Icons.check_rounded,
                  size: 13, color: Colors.white),
            if (active) const SizedBox(width: 4),
            Text(
              'Vas',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
