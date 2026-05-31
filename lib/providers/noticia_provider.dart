import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/noticia_repository.dart';
import '../data/models/noticia_model.dart';
import '../data/models/enums.dart';
import 'auth_provider.dart';

final noticiaRepositoryProvider =
    Provider<NoticiaRepository>((ref) => NoticiaRepository());

final noticiasProvider =
    StreamProvider.family<List<NoticiaModel>, String>((ref, grupoId) {
  return ref.watch(noticiaRepositoryProvider).getNoticias(grupoId);
});

// ── Lecturas provider ─────────────────────────────────────────────────────────

typedef NoticiaKey = ({String grupoId, String noticiaId});

final lecturasProvider =
    StreamProvider.family<List<LecturaItem>, NoticiaKey>((ref, key) {
  return ref
      .watch(noticiaRepositoryProvider)
      .getLecturas(key.grupoId, key.noticiaId);
});

// ── Asistencia provider ───────────────────────────────────────────────────────

final asistenciaProvider =
    StreamProvider.family<List<AsistenciaItem>, NoticiaKey>((ref, key) {
  return ref
      .watch(noticiaRepositoryProvider)
      .getAsistencia(key.grupoId, key.noticiaId);
});

typedef AsistenciaUidKey = ({String grupoId, String noticiaId, String uid});

/// Single-doc stream of the current user's RSVP for a specific event.
final miAsistenciaProvider =
    StreamProvider.family<AsistenciaItem?, AsistenciaUidKey>((ref, key) {
  return ref
      .watch(noticiaRepositoryProvider)
      .getMiAsistencia(key.grupoId, key.noticiaId, key.uid);
});

// ── Comentarios provider ──────────────────────────────────────────────────────

final comentariosProvider =
    StreamProvider.family<List<ComentarioModel>, NoticiaKey>((ref, key) {
  return ref
      .watch(noticiaRepositoryProvider)
      .getComentarios(key.grupoId, key.noticiaId);
});

// ── Próximo evento del grupo ──────────────────────────────────────────────────
// Returns the soonest upcoming noticia with tieneListado=true whose event date
// (fechaEvento ?? fechaCaducidad) is in the future.  Returns null if none.

final proximoEventoGrupoProvider =
    Provider.family<NoticiaModel?, String>((ref, grupoId) {
  final noticias = ref.watch(noticiasProvider(grupoId)).valueOrNull ?? [];
  final now = DateTime.now();
  final futuros = noticias.where((n) {
    if (!n.tieneListado || n.caducada) return false;
    final eventDate = n.fechaEvento ?? n.fechaCaducidad;
    return eventDate != null && eventDate.isAfter(now);
  }).toList();
  if (futuros.isEmpty) return null;
  futuros.sort((a, b) {
    final af = a.fechaEvento ?? a.fechaCaducidad;
    final bf = b.fechaEvento ?? b.fechaCaducidad;
    if (af != null && bf != null) return af.compareTo(bf);
    if (af != null) return -1;
    if (bf != null) return 1;
    return 0;
  });
  return futuros.first;
});

// ── Main notifier ─────────────────────────────────────────────────────────────

class CrearNoticiaNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> crear({
    required String grupoId,
    required String titulo,
    required String contenido,
    Uint8List? imagenBytes,
    bool tieneListado = false,
    NoticiaCategoria categoria = NoticiaCategoria.general,
    List<MencionadoItem> mencionados = const [],
    DateTime? fechaCaducidad,
    DateTime? fechaEvento,
  }) async {
    state = const AsyncLoading();
    try {
      final user = ref.read(authStateProvider).valueOrNull!;
      final userData = await ref.read(authRepositoryProvider).getUser(user.uid);
      await ref.read(noticiaRepositoryProvider).createNoticia(
            grupoId: grupoId,
            autorUid: user.uid,
            autorNombre: userData?.nombreCompleto ?? user.displayName ?? '',
            titulo: titulo,
            contenido: contenido,
            imagenBytes: imagenBytes,
            tieneListado: tieneListado,
            categoria: categoria,
            mencionados: mencionados,
            fechaCaducidad: fechaCaducidad,
            fechaEvento: fechaEvento,
          );
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> editar({
    required String grupoId,
    required String noticiaId,
    required String titulo,
    required String contenido,
    Uint8List? imagenBytes,
    String? existingImagenUrl,
    bool tieneListado = false,
    NoticiaCategoria categoria = NoticiaCategoria.general,
    List<MencionadoItem> mencionados = const [],
    DateTime? fechaCaducidad,
    DateTime? fechaEvento,
  }) async {
    state = const AsyncLoading();
    try {
      await ref.read(noticiaRepositoryProvider).updateNoticia(
            grupoId: grupoId,
            noticiaId: noticiaId,
            titulo: titulo,
            contenido: contenido,
            imagenBytes: imagenBytes,
            existingImagenUrl: existingImagenUrl,
            tieneListado: tieneListado,
            categoria: categoria,
            mencionados: mencionados,
            fechaCaducidad: fechaCaducidad,
            fechaEvento: fechaEvento,
          );
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> eliminar(String grupoId, String noticiaId) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(noticiaRepositoryProvider)
          .deleteNoticia(grupoId, noticiaId);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> toggleLike(String grupoId, String noticiaId) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    await ref
        .read(noticiaRepositoryProvider)
        .toggleLike(grupoId, noticiaId, user.uid);
  }

  Future<void> toggleFijada(
      String grupoId, String noticiaId, bool fijada) async {
    await ref
        .read(noticiaRepositoryProvider)
        .toggleFijada(grupoId, noticiaId, fijada);
  }

  Future<void> markAsRead(String grupoId, String noticiaId) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    final userData = await ref.read(authRepositoryProvider).getUser(user.uid);
    final nombre = userData?.nombreCompleto ?? user.displayName ?? '';
    await ref.read(noticiaRepositoryProvider).markAsRead(
          grupoId: grupoId,
          noticiaId: noticiaId,
          uid: user.uid,
          nombre: nombre,
        );
  }

  Future<void> setAsistencia({
    required String grupoId,
    required String noticiaId,
    required String estado,
  }) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    final userData = await ref.read(authRepositoryProvider).getUser(user.uid);
    await ref.read(noticiaRepositoryProvider).setAsistencia(
          grupoId: grupoId,
          noticiaId: noticiaId,
          uid: user.uid,
          nombre: userData?.nombreCompleto ?? user.displayName ?? '',
          avatarUrl: userData?.avatarUrl ?? user.photoURL,
          estado: estado,
        );
  }

  Future<void> removeAsistencia(String grupoId, String noticiaId) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    await ref
        .read(noticiaRepositoryProvider)
        .removeAsistencia(grupoId, noticiaId, user.uid);
  }

  Future<void> addComentario({
    required String grupoId,
    required String noticiaId,
    required String texto,
  }) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    final userData = await ref.read(authRepositoryProvider).getUser(user.uid);
    await ref.read(noticiaRepositoryProvider).addComentario(
          grupoId: grupoId,
          noticiaId: noticiaId,
          uid: user.uid,
          nombre: userData?.nombreCompleto ?? user.displayName ?? '',
          avatarUrl: userData?.avatarUrl ?? user.photoURL,
          texto: texto,
        );
  }

  Future<void> deleteComentario(
      String grupoId, String noticiaId, String comentarioId) async {
    await ref
        .read(noticiaRepositoryProvider)
        .deleteComentario(grupoId, noticiaId, comentarioId);
  }
}

final crearNoticiaProvider =
    AsyncNotifierProvider<CrearNoticiaNotifier, void>(CrearNoticiaNotifier.new);
