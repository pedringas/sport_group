import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/app_config.dart';
import '../data/models/noticia_model.dart';
import 'cuota_provider.dart';
import 'noticia_provider.dart';

// ── Feed item ─────────────────────────────────────────────────────────────────
//
// App de grupo único: el item ya no lleva el grupo ni si es favorito.

class FeedNoticiaItem {
  final NoticiaModel noticia;

  FeedNoticiaItem({required this.noticia});
}

// ── Noticias del grupo, más recientes primero ─────────────────────────────────

final feedNoticiasProvider = Provider<List<FeedNoticiaItem>>((ref) {
  final noticias = ref.watch(noticiasProvider(kGrupoId)).valueOrNull ?? [];

  final items = noticias
      .where((n) => !n.caducada)
      .map((n) => FeedNoticiaItem(noticia: n))
      .toList()
    ..sort((a, b) => b.noticia.createdAt.compareTo(a.noticia.createdAt));

  return items;
});

// ── Destacadas: noticias fijadas ──────────────────────────────────────────────
//
// Antes exigía además que el grupo estuviera marcado como favorito, condición
// imposible con un solo grupo: la sección nunca se mostraba.

final feedDestacadasProvider = Provider<List<FeedNoticiaItem>>((ref) {
  return ref
      .watch(feedNoticiasProvider)
      .where((i) => i.noticia.fijada)
      .toList();
});

// ── Novedades (legacy — kept for compatibility) ───────────────────────────────

class NovedadFeed {
  final String titulo;
  final String subtitulo;
  final DateTime fecha;
  final NovedadTipo tipo;

  NovedadFeed({
    required this.titulo,
    required this.subtitulo,
    required this.fecha,
    required this.tipo,
  });
}

enum NovedadTipo { cuota, tarea, noticia, campana }

final novedadesFeedProvider = Provider<List<NovedadFeed>>((ref) {
  final items = <NovedadFeed>[];

  final noticias = ref.watch(noticiasProvider(kGrupoId)).valueOrNull ?? [];
  for (final n in noticias.take(3)) {
    items.add(NovedadFeed(
      titulo: n.autorNombre,
      subtitulo: n.titulo,
      fecha: n.createdAt,
      tipo: NovedadTipo.noticia,
    ));
  }

  final cuotas = ref.watch(cuotasProvider(kGrupoId)).valueOrNull ?? [];
  for (final c in cuotas.take(1)) {
    if (c.activa) {
      items.add(NovedadFeed(
        titulo: 'Suscripción pendiente',
        subtitulo: '${c.titulo} · vence ${_formatDate(c.vencimiento)}',
        fecha: c.createdAt,
        tipo: NovedadTipo.cuota,
      ));
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
