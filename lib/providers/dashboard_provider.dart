import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/grupo_model.dart';
import '../data/models/cuota_model.dart';
import '../data/models/tarea_model.dart';
import '../data/models/campana_model.dart';
import '../data/models/noticia_model.dart';
import 'grupo_provider.dart';
import 'cuota_provider.dart';
import 'noticia_provider.dart';
import 'auth_provider.dart';

// ── Dashboard item types ──────────────────────────────────────────────────────

sealed class DashboardItem {}

class CuotaItem extends DashboardItem {
  final CuotaModel cuota;
  final GrupoModel grupo;
  CuotaItem({required this.cuota, required this.grupo});
}

class TareaItem extends DashboardItem {
  final TareaModel tarea;
  final GrupoModel grupo;
  TareaItem({required this.tarea, required this.grupo});
}

class CampanaItem extends DashboardItem {
  final CampanaModel campana;
  final GrupoModel grupo;
  CampanaItem({required this.campana, required this.grupo});
}

class EventoItem extends DashboardItem {
  final NoticiaModel noticia;
  final GrupoModel grupo;
  EventoItem({required this.noticia, required this.grupo});
}

// ── Priority carousel — tareas asignadas al user de grupos favoritos ───────────

// NOTE: Módulo "Tareas" en pausa — no se muestran tareas prioritarias en el
// feed de inicio. Para reactivar, restaurar el cuerpo original de este provider.
final tareasPrioritariasProvider = Provider<List<TareaItem>>((ref) {
  return const <TareaItem>[];
});

// ── Próximos eventos confirmados ──────────────────────────────────────────────
//
// Shows noticias where:
//   • tieneListado == true (event with attendance list)
//   • !caducada (fechaCaducidad in the future, or no expiry)
//   • current user confirmed attendance (estado == 'va')
// Sorted by fechaEvento (if set) else fechaCaducidad ascending (soonest first).

final feedProximosEventosProvider = Provider<List<EventoItem>>((ref) {
  final grupos = ref.watch(userGruposProvider).valueOrNull ?? [];
  final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
  if (uid.isEmpty) return [];

  final items = <EventoItem>[];

  final now = DateTime.now();
  for (final grupo in grupos) {
    final noticias = ref.watch(noticiasProvider(grupo.id)).valueOrNull ?? [];
    for (final n in noticias) {
      if (!n.tieneListado || n.caducada) continue;
      // Skip events whose date has already passed
      final eventDate = n.fechaEvento ?? n.fechaCaducidad;
      if (eventDate != null && eventDate.isBefore(now)) continue;
      final asistencia = ref
          .watch(miAsistenciaProvider(
              (grupoId: grupo.id, noticiaId: n.id, uid: uid)))
          .valueOrNull;
      if (asistencia != null && asistencia.estado == 'va') {
        items.add(EventoItem(noticia: n, grupo: grupo));
      }
    }
  }

  items.sort((a, b) {
    // Prefer fechaEvento (actual event date) over fechaCaducidad for sorting
    final af = a.noticia.fechaEvento ?? a.noticia.fechaCaducidad;
    final bf = b.noticia.fechaEvento ?? b.noticia.fechaCaducidad;
    if (af != null && bf != null) return af.compareTo(bf);
    if (af != null) return -1;
    if (bf != null) return 1;
    return 0;
  });

  return items;
});

// ── Featured event ────────────────────────────────────────────────────────────

final featuredEventProvider = Provider<EventoItem?>((ref) {
  final grupos = ref.watch(userGruposProvider).valueOrNull ?? [];
  final now = DateTime.now();
  // Collect all upcoming events across groups, then return the soonest one
  EventoItem? soonest;
  DateTime? soonestDate;
  for (final grupo in grupos) {
    final noticias = ref.watch(noticiasProvider(grupo.id)).valueOrNull ?? [];
    for (final n in noticias) {
      if (!n.tieneListado || n.caducada) continue;
      final eventDate = n.fechaEvento ?? n.fechaCaducidad;
      if (eventDate == null || eventDate.isBefore(now)) continue;
      if (soonestDate == null || eventDate.isBefore(soonestDate)) {
        soonest = EventoItem(noticia: n, grupo: grupo);
        soonestDate = eventDate;
      }
    }
  }
  return soonest;
});

// ── Esta semana items (cuotas/suscripciones, tareas, campañas) ────────────────

final thisWeekItemsProvider = Provider<List<DashboardItem>>((ref) {
  final grupos = ref.watch(userGruposProvider).valueOrNull ?? [];
  final now = DateTime.now();
  final nextWeek = now.add(const Duration(days: 7));

  final items = <DashboardItem>[];

  // Módulos "Tareas" y "Campañas" en pausa — sólo se muestran cuotas en el feed.
  for (final grupo in grupos) {
    final cuotas = ref.watch(cuotasProvider(grupo.id)).valueOrNull ?? [];
    for (final c in cuotas) {
      if (c.activa && c.vencimiento.isBefore(nextWeek)) {
        items.add(CuotaItem(cuota: c, grupo: grupo));
        break;
      }
    }
  }

  final cuotaItems = items.whereType<CuotaItem>().toList();

  return [
    ...cuotaItems.take(4),
  ];
});
