import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/grupo_model.dart';
import '../data/models/cuota_model.dart';
import '../data/models/tarea_model.dart';
import '../data/models/campana_model.dart';
import '../data/models/noticia_model.dart';
import '../data/models/enums.dart';
import 'grupo_provider.dart';
import 'cuota_provider.dart';
import 'tarea_provider.dart';
import 'campana_provider.dart';
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

final tareasPrioritariasProvider = Provider<List<TareaItem>>((ref) {
  final grupos = ref.watch(userGruposProvider).valueOrNull ?? [];
  final favoritosIds = ref.watch(gruposFavoritosProvider).valueOrNull ?? {};
  final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';

  // Prefer favourite groups, fall back to all groups if no favourites
  final targetGrupos = favoritosIds.isNotEmpty
      ? grupos.where((g) => favoritosIds.contains(g.id)).toList()
      : grupos;

  final items = <TareaItem>[];
  for (final grupo in targetGrupos) {
    final tareas = ref.watch(tareasProvider(grupo.id)).valueOrNull ?? [];
    final pendientes = tareas.where((t) =>
        t.asignadoA(uid) &&
        t.estado != TareaEstado.completada &&
        t.estado != TareaEstado.cancelada);
    for (final t in pendientes) {
      items.add(TareaItem(tarea: t, grupo: grupo));
    }
  }

  // Sort: vencidas first, then by fecha vencimiento asc, then by createdAt desc
  items.sort((a, b) {
    final aVenc = a.tarea.fechaVencimiento;
    final bVenc = b.tarea.fechaVencimiento;
    if (aVenc != null && bVenc != null) return aVenc.compareTo(bVenc);
    if (aVenc != null) return -1;
    if (bVenc != null) return 1;
    return b.tarea.createdAt.compareTo(a.tarea.createdAt);
  });

  return items.take(10).toList();
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
      if (soonestDate == null || eventDate.isBefore(soonestDate!)) {
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
  final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
  final now = DateTime.now();
  final nextWeek = now.add(const Duration(days: 7));

  final items = <DashboardItem>[];

  for (final grupo in grupos) {
    final cuotas = ref.watch(cuotasProvider(grupo.id)).valueOrNull ?? [];
    for (final c in cuotas) {
      if (c.activa && c.vencimiento.isBefore(nextWeek)) {
        items.add(CuotaItem(cuota: c, grupo: grupo));
        break;
      }
    }

    final tareas = ref.watch(tareasProvider(grupo.id)).valueOrNull ?? [];
    for (final t in tareas) {
      if (t.asignadoA(uid) &&
          t.estado != TareaEstado.completada &&
          t.estado != TareaEstado.cancelada) {
        items.add(TareaItem(tarea: t, grupo: grupo));
        break;
      }
    }

    final campanas = ref.watch(campanasProvider(grupo.id)).valueOrNull ?? [];
    for (final c in campanas) {
      if (c.estado == EstadoCampana.activa) {
        items.add(CampanaItem(campana: c, grupo: grupo));
        break;
      }
    }
  }

  final cuotaItems = items.whereType<CuotaItem>().toList();
  final tareaItems = items.whereType<TareaItem>().toList();
  final campanaItems = items.whereType<CampanaItem>().toList();

  return [
    ...cuotaItems.take(2),
    ...tareaItems.take(2),
    ...campanaItems.take(2),
  ];
});

// ── Cross-group noticias feed ─────────────────────────────────────────────────
//
// Ordering:
//   1. Noticias from private groups (privado) the user belongs to
//   2. Noticias from public groups marked as favourite by the user
//   3. Noticias from other public groups the user belongs to
//   Within each bucket: sorted by createdAt descending (newest first).

class FeedNoticiaItem {
  final NoticiaModel noticia;
  final GrupoModel grupo;
  final bool esFavoritoGrupo;

  FeedNoticiaItem({
    required this.noticia,
    required this.grupo,
    required this.esFavoritoGrupo,
  });
}

final feedNoticiasProvider = Provider<List<FeedNoticiaItem>>((ref) {
  final grupos = ref.watch(userGruposProvider).valueOrNull ?? [];
  final favoritosIds = ref.watch(gruposFavoritosProvider).valueOrNull ?? {};

  final privados = <FeedNoticiaItem>[];
  final publicosFav = <FeedNoticiaItem>[];
  final publicosOtros = <FeedNoticiaItem>[];

  for (final grupo in grupos) {
    final noticias = ref.watch(noticiasProvider(grupo.id)).valueOrNull ?? [];
    final esFav = favoritosIds.contains(grupo.id);

    for (final n in noticias) {
      if (n.caducada) continue; // don't show expired noticias in the feed
      final item = FeedNoticiaItem(noticia: n, grupo: grupo, esFavoritoGrupo: esFav);
      if (grupo.tipo == TipoGrupo.privado) {
        privados.add(item);
      } else if (esFav) {
        publicosFav.add(item);
      } else {
        publicosOtros.add(item);
      }
    }
  }

  // Sort each bucket newest-first
  int byDate(FeedNoticiaItem a, FeedNoticiaItem b) =>
      b.noticia.createdAt.compareTo(a.noticia.createdAt);

  privados.sort(byDate);
  publicosFav.sort(byDate);
  publicosOtros.sort(byDate);

  return [...privados, ...publicosFav, ...publicosOtros];
});

// ── Destacadas: fijadas from favourite groups ─────────────────────────────────

final feedDestacadasProvider = Provider<List<FeedNoticiaItem>>((ref) {
  final all = ref.watch(feedNoticiasProvider);
  return all.where((i) => i.noticia.fijada && i.esFavoritoGrupo).toList();
});

// ── Novedades (legacy — kept for compatibility) ───────────────────────────────

class NovedadFeed {
  final String titulo;
  final String subtitulo;
  final String grupoNombre;
  final DateTime fecha;
  final NovedadTipo tipo;

  NovedadFeed({
    required this.titulo,
    required this.subtitulo,
    required this.grupoNombre,
    required this.fecha,
    required this.tipo,
  });
}

enum NovedadTipo { cuota, tarea, noticia, campana }

final novedadesFeedProvider = Provider<List<NovedadFeed>>((ref) {
  final grupos = ref.watch(userGruposProvider).valueOrNull ?? [];
  final items = <NovedadFeed>[];

  for (final grupo in grupos) {
    final noticias = ref.watch(noticiasProvider(grupo.id)).valueOrNull ?? [];
    for (final n in noticias.take(3)) {
      items.add(NovedadFeed(
        titulo: n.autorNombre,
        subtitulo: n.titulo,
        grupoNombre: grupo.nombre,
        fecha: n.createdAt,
        tipo: NovedadTipo.noticia,
      ));
    }

    final cuotas = ref.watch(cuotasProvider(grupo.id)).valueOrNull ?? [];
    for (final c in cuotas.take(1)) {
      if (c.activa) {
        items.add(NovedadFeed(
          titulo: 'Suscripción pendiente',
          subtitulo: '${c.titulo} · vence ${_formatDate(c.vencimiento)}',
          grupoNombre: grupo.nombre,
          fecha: c.createdAt,
          tipo: NovedadTipo.cuota,
        ));
      }
    }
  }

  items.sort((a, b) => b.fecha.compareTo(a.fecha));
  return items.take(8).toList();
});

String _formatDate(DateTime d) {
  final diff = d.difference(DateTime.now()).inDays;
  if (diff == 0) return 'hoy';
  if (diff == 1) return 'mañana';
  if (diff < 0) return 'hace ${-diff} días';
  return 'en $diff días';
}
