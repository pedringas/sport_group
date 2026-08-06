import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/grupo_model.dart';
import '../data/models/noticia_model.dart';
import '../data/models/enums.dart';
import 'cuota_provider.dart';
import 'grupo_provider.dart';
import 'noticia_provider.dart';

// ── Feed item ─────────────────────────────────────────────────────────────────

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

// ── Cross-group noticias feed ─────────────────────────────────────────────────
//
// Ordering:
//   1. Noticias from private groups (privado) the user belongs to
//   2. Noticias from public groups marked as favourite by the user
//   3. Noticias from other public groups the user belongs to
//   Within each bucket: sorted by createdAt descending (newest first).

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
      if (n.caducada) continue;
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
