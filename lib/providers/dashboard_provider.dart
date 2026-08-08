import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/app_config.dart';
import '../data/models/cuota_model.dart';
import '../data/models/tarea_model.dart';
import '../data/models/campana_model.dart';
import '../data/models/noticia_model.dart';
import 'cuota_provider.dart';
import 'noticia_provider.dart';
import 'auth_provider.dart';

// ── Dashboard item types ──────────────────────────────────────────────────────
//
// App de grupo único: los items ya no llevan el grupo al que pertenecen.

sealed class DashboardItem {}

class CuotaItem extends DashboardItem {
  final CuotaModel cuota;
  CuotaItem({required this.cuota});
}

class TareaItem extends DashboardItem {
  final TareaModel tarea;
  TareaItem({required this.tarea});
}

class CampanaItem extends DashboardItem {
  final CampanaModel campana;
  CampanaItem({required this.campana});
}

class EventoItem extends DashboardItem {
  final NoticiaModel noticia;
  EventoItem({required this.noticia});
}

// ── Priority carousel — tareas asignadas al user ──────────────────────────────

// NOTE: Módulo "Tareas" en pausa — no se muestran tareas prioritarias en el
// feed de inicio. Para reactivar, restaurar el cuerpo original de este provider.
final tareasPrioritariasProvider = Provider<List<TareaItem>>((ref) {
  return const <TareaItem>[];
});

// ── Próximos eventos confirmados ──────────────────────────────────────────────
//
// Noticias donde:
//   • tieneListado == true (evento con lista de asistencia)
//   • !caducada y la fecha no pasó
//   • el usuario confirmó asistencia (estado == 'va')
// Ordenadas por fechaEvento (o fechaCaducidad) ascendente.

final feedProximosEventosProvider = Provider<List<EventoItem>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
  if (uid.isEmpty) return [];

  final noticias = ref.watch(noticiasProvider(kGrupoId)).valueOrNull ?? [];
  final now = DateTime.now();
  final items = <EventoItem>[];

  for (final n in noticias) {
    if (!n.tieneListado || n.caducada) continue;
    final eventDate = n.fechaEvento ?? n.fechaCaducidad;
    if (eventDate != null && eventDate.isBefore(now)) continue;
    final asistencia = ref
        .watch(miAsistenciaProvider(
            (grupoId: kGrupoId, noticiaId: n.id, uid: uid)))
        .valueOrNull;
    if (asistencia != null && asistencia.estado == 'va') {
      items.add(EventoItem(noticia: n));
    }
  }

  items.sort((a, b) {
    final af = a.noticia.fechaEvento ?? a.noticia.fechaCaducidad;
    final bf = b.noticia.fechaEvento ?? b.noticia.fechaCaducidad;
    if (af != null && bf != null) return af.compareTo(bf);
    if (af != null) return -1;
    if (bf != null) return 1;
    return 0;
  });

  return items;
});

// ── Featured event — el próximo evento más cercano ────────────────────────────

final featuredEventProvider = Provider<EventoItem?>((ref) {
  final noticias = ref.watch(noticiasProvider(kGrupoId)).valueOrNull ?? [];
  final now = DateTime.now();

  EventoItem? soonest;
  DateTime? soonestDate;
  for (final n in noticias) {
    if (!n.tieneListado || n.caducada) continue;
    final eventDate = n.fechaEvento ?? n.fechaCaducidad;
    if (eventDate == null || eventDate.isBefore(now)) continue;
    if (soonestDate == null || eventDate.isBefore(soonestDate)) {
      soonest = EventoItem(noticia: n);
      soonestDate = eventDate;
    }
  }
  return soonest;
});

// ── Esta semana (cuotas por vencer) ───────────────────────────────────────────

final thisWeekItemsProvider = Provider<List<DashboardItem>>((ref) {
  final now = DateTime.now();
  final nextWeek = now.add(const Duration(days: 7));

  // Módulos "Tareas" y "Campañas" en pausa — sólo se muestran cuotas en el feed.
  final cuotas = ref.watch(cuotasProvider(kGrupoId)).valueOrNull ?? [];
  final items = cuotas
      .where((c) => c.activa && c.vencimiento.isBefore(nextWeek))
      .map((c) => CuotaItem(cuota: c))
      .take(4)
      .toList();

  return items;
});
