import 'dart:developer' as dev;
import 'dart:math';
import 'dart:typed_data';
import '../datasources/noticia_datasource.dart';
import '../models/noticia_model.dart';
import '../models/enums.dart';
import '../models/actividad_model.dart';
import 'notificacion_repository.dart';

class NoticiaRepository {
  final NoticiaDatasource _ds;
  NoticiaRepository([NoticiaDatasource? ds])
      : _ds = ds ?? NoticiaDatasource();

  /// Returns noticias sorted: pinned first, then by createdAt descending.
  Stream<List<NoticiaModel>> getNoticias(String grupoId) =>
      _ds.getNoticias(grupoId).map((noticias) {
        noticias.sort((a, b) {
          if (a.fijada && !b.fijada) return -1;
          if (!a.fijada && b.fijada) return 1;
          return b.createdAt.compareTo(a.createdAt);
        });
        return noticias;
      });

  Future<void> createNoticia({
    required String grupoId,
    required String autorUid,
    required String autorNombre,
    required String titulo,
    required String contenido,
    Uint8List? imagenBytes,
    bool tieneListado = false,
    NoticiaCategoria categoria = NoticiaCategoria.general,
    List<MencionadoItem> mencionados = const [],
    DateTime? fechaCaducidad,
    DateTime? fechaEvento,
  }) async {
    final id = await _ds.createNoticiaDoc(
      grupoId: grupoId,
      autorUid: autorUid,
      autorNombre: autorNombre,
      titulo: titulo,
      contenido: contenido,
      imagenBytes: imagenBytes,
      tieneListado: tieneListado,
      categoria: categoria,
      mencionados: mencionados,
      fechaCaducidad: fechaCaducidad,
      fechaEvento: fechaEvento,
    );

    try {
      final snippet = contenido.substring(0, min(100, contenido.length));
      await NotificacionRepository().writeActividad(
        grupoId,
        ActividadModel(
          id: '',
          tipo: 'noticia',
          titulo: titulo,
          mensaje: snippet,
          actorNombre: autorNombre,
          grupoId: grupoId,
          grupoNombre: '',
          referenciaId: id,
          createdAt: DateTime.now(),
        ),
      );
    } catch (e) {
      dev.log('[Actividad] $e');
    }
  }

  Future<void> updateNoticia({
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
  }) =>
      _ds.updateNoticiaDoc(
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

  Future<void> toggleLike(String grupoId, String noticiaId, String uid) =>
      _ds.toggleLike(grupoId, noticiaId, uid);

  Future<void> toggleFijada(String grupoId, String noticiaId, bool fijada) =>
      _ds.toggleFijada(grupoId, noticiaId, fijada);

  Future<void> updateCategoria(String grupoId, String noticiaId,
          NoticiaCategoria categoria) =>
      _ds.updateCategoria(grupoId, noticiaId, categoria);

  Future<void> deleteNoticia(String grupoId, String noticiaId) =>
      _ds.deleteNoticia(grupoId, noticiaId);

  Future<void> markAsRead({
    required String grupoId,
    required String noticiaId,
    required String uid,
    required String nombre,
  }) =>
      _ds.markAsRead(
          grupoId: grupoId, noticiaId: noticiaId, uid: uid, nombre: nombre);

  Stream<List<LecturaItem>> getLecturas(String grupoId, String noticiaId) =>
      _ds.getLecturas(grupoId, noticiaId);

  Stream<AsistenciaItem?> getMiAsistencia(
          String grupoId, String noticiaId, String uid) =>
      _ds.getMiAsistencia(grupoId, noticiaId, uid);

  Stream<List<AsistenciaItem>> getAsistencia(
          String grupoId, String noticiaId) =>
      _ds.getAsistencia(grupoId, noticiaId);

  Future<void> setAsistencia({
    required String grupoId,
    required String noticiaId,
    required String uid,
    required String nombre,
    String? avatarUrl,
    required String estado,
  }) =>
      _ds.setAsistencia(
        grupoId: grupoId,
        noticiaId: noticiaId,
        uid: uid,
        nombre: nombre,
        avatarUrl: avatarUrl,
        estado: estado,
      );

  Future<void> removeAsistencia(
          String grupoId, String noticiaId, String uid) =>
      _ds.removeAsistencia(grupoId, noticiaId, uid);

  Stream<List<ComentarioModel>> getComentarios(
          String grupoId, String noticiaId) =>
      _ds.getComentarios(grupoId, noticiaId);

  Future<void> addComentario({
    required String grupoId,
    required String noticiaId,
    required String uid,
    required String nombre,
    String? avatarUrl,
    required String texto,
  }) =>
      _ds.addComentario(
        grupoId: grupoId,
        noticiaId: noticiaId,
        uid: uid,
        nombre: nombre,
        avatarUrl: avatarUrl,
        texto: texto,
      );

  Future<void> deleteComentario(
          String grupoId, String noticiaId, String comentarioId) =>
      _ds.deleteComentario(grupoId, noticiaId, comentarioId);
}
