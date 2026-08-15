import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/app_config.dart';
import '../data/models/cuota_model.dart';
import '../data/models/enums.dart';
import '../data/models/pago_model.dart';
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

// ── Featured events — lo que se viene ─────────────────────────────────────────
//
// Devolvía UN solo evento (el de fecha más cercana), así que un segundo evento
// del mismo día no entraba al hero y quedaba sólo en la lista de Novedades,
// mezclado por fecha de publicación. El tipo de evento nunca influyó: partido,
// entrenamiento y asado pesan igual — la categoría es sólo una etiqueta.

/// Ventana del hero: más allá de esto un evento no es "lo que se viene".
const kHeroEventoDias = 14;

/// Tope de tarjetas del carrusel, para que no se vuelva infinito.
const kHeroEventoMax = 5;

/// Eventos con lista de asistencia que caen dentro de la ventana del hero,
/// ordenados por fecha. Todos los tipos pesan igual.
@visibleForTesting
List<NoticiaModel> seleccionarEventosHero(
  List<NoticiaModel> noticias,
  DateTime ahora,
) {
  final limite =
      DateTime(ahora.year, ahora.month, ahora.day + kHeroEventoDias, 23, 59, 59);

  final proximos = <({NoticiaModel noticia, DateTime fecha})>[];
  for (final n in noticias) {
    if (!n.tieneListado) continue;
    // `caducada` compara contra el reloj real; acá se usa `ahora` para que la
    // selección sea determinística y testeable.
    if (n.fechaCaducidad != null && n.fechaCaducidad!.isBefore(ahora)) continue;
    final fecha = n.fechaEvento ?? n.fechaCaducidad;
    if (fecha == null || fecha.isBefore(ahora) || fecha.isAfter(limite)) {
      continue;
    }
    proximos.add((noticia: n, fecha: fecha));
  }

  // Desempate estable por id: con dos eventos a la misma hora exacta el orden
  // dependía de cómo viniera el stream y podía cambiar entre reconstrucciones.
  proximos.sort((a, b) {
    final porFecha = a.fecha.compareTo(b.fecha);
    return porFecha != 0 ? porFecha : a.noticia.id.compareTo(b.noticia.id);
  });

  return proximos.take(kHeroEventoMax).map((e) => e.noticia).toList();
}

final featuredEventsProvider = Provider<List<EventoItem>>((ref) {
  final noticias = ref.watch(noticiasProvider(kGrupoId)).valueOrNull ?? [];
  return seleccionarEventosHero(noticias, DateTime.now())
      .map((n) => EventoItem(noticia: n))
      .toList();
});

// ── Esta semana (cuotas por vencer) ───────────────────────────────────────────

/// Cuotas que le urgen a quien mira el feed.
///
/// Antes tomaba cualquier cuota activa del grupo con vencimiento anterior a la
/// semana que viene: incluía las que el miembro ya había pagado, las que ni
/// siquiera le correspondían, y no distinguía "vence en 3 días" de "venció en
/// marzo". Ahora se filtra por alcance y por pago propio, y se ordena por
/// urgencia.
final thisWeekItemsProvider = Provider<List<DashboardItem>>((ref) {
  final now = DateTime.now();
  final limite = DateTime(now.year, now.month, now.day + 7);
  final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';

  // Módulos "Tareas" y "Campañas" en pausa — sólo se muestran cuotas en el feed.
  final cuotas = ref.watch(cuotasProvider(kGrupoId)).valueOrNull ?? [];
  final misPagos = uid.isEmpty
      ? const <PagoModel>[]
      : ref
              .watch(misPagosGrupoProvider((grupoId: kGrupoId, uid: uid)))
              .valueOrNull ??
          const <PagoModel>[];

  bool yaPagada(CuotaModel c) => misPagos
      .any((p) => p.cuotaId == c.id && p.estado == EstadoPago.aprobado);

  final pendientes = cuotas
      .where((c) =>
          c.activa &&
          c.aplicaA(uid) &&
          !yaPagada(c) &&
          !c.vencimiento.isAfter(limite))
      .toList()
    ..sort((a, b) => a.vencimiento.compareTo(b.vencimiento));

  return pendientes.take(4).map((c) => CuotaItem(cuota: c)).toList();
});
