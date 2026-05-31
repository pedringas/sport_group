import 'dart:math';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/noticia_model.dart';
import '../models/enums.dart';
import '../models/actividad_model.dart';
import 'notificacion_repository.dart';

class NoticiaRepository {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  // ── Noticias ───────────────────────────────────────────────────────────────

  /// Returns noticias sorted: pinned first, then by createdAt descending.
  Stream<List<NoticiaModel>> getNoticias(String grupoId) {
    return _db
        .collection('grupos')
        .doc(grupoId)
        .collection('noticias')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) {
      final noticias = s.docs.map(NoticiaModel.fromFirestore).toList();
      noticias.sort((a, b) {
        if (a.fijada && !b.fijada) return -1;
        if (!a.fijada && b.fijada) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });
      return noticias;
    });
  }

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
    final ref =
        _db.collection('grupos').doc(grupoId).collection('noticias').doc();
    String? imagenUrl;
    if (imagenBytes != null) {
      final storageRef =
          _storage.ref('grupos/$grupoId/noticias/${ref.id}.jpg');
      await storageRef.putData(
          imagenBytes, SettableMetadata(contentType: 'image/jpeg'));
      imagenUrl = await storageRef.getDownloadURL();
    }
    await ref.set({
      'grupoId': grupoId,
      'autorUid': autorUid,
      'autorNombre': autorNombre,
      'titulo': titulo,
      'contenido': contenido,
      'imagenUrl': imagenUrl,
      'likes': [],
      'fijada': false,
      'tieneListado': tieneListado,
      'categoria': categoria.name,
      'mencionados': mencionados.map((m) => m.toMap()).toList(),
      'fechaCaducidad': fechaCaducidad != null
          ? Timestamp.fromDate(fechaCaducidad)
          : null,
      'fechaEvento': fechaEvento != null
          ? Timestamp.fromDate(fechaEvento)
          : null,
      'createdAt': Timestamp.now(),
    });

    // Write group activity (fire-and-forget)
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
          referenciaId: ref.id,
          createdAt: DateTime.now(),
        ),
      );
    } catch (_) {}
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
  }) async {
    String? imagenUrl = existingImagenUrl;
    if (imagenBytes != null) {
      final storageRef =
          _storage.ref('grupos/$grupoId/noticias/$noticiaId.jpg');
      await storageRef.putData(
          imagenBytes, SettableMetadata(contentType: 'image/jpeg'));
      imagenUrl = await storageRef.getDownloadURL();
    }
    await _db
        .collection('grupos')
        .doc(grupoId)
        .collection('noticias')
        .doc(noticiaId)
        .update({
      'titulo': titulo,
      'contenido': contenido,
      'imagenUrl': imagenUrl,
      'tieneListado': tieneListado,
      'categoria': categoria.name,
      'mencionados': mencionados.map((m) => m.toMap()).toList(),
      'fechaCaducidad': fechaCaducidad != null
          ? Timestamp.fromDate(fechaCaducidad)
          : null,
      'fechaEvento': fechaEvento != null
          ? Timestamp.fromDate(fechaEvento)
          : null,
    });
  }

  Future<void> toggleLike(
      String grupoId, String noticiaId, String uid) async {
    final ref = _db
        .collection('grupos')
        .doc(grupoId)
        .collection('noticias')
        .doc(noticiaId);
    final doc = await ref.get();
    final likes = List<String>.from(doc.data()?['likes'] ?? []);
    if (likes.contains(uid)) {
      likes.remove(uid);
    } else {
      likes.add(uid);
    }
    await ref.update({'likes': likes});
  }

  Future<void> toggleFijada(
      String grupoId, String noticiaId, bool fijada) async {
    await _db
        .collection('grupos')
        .doc(grupoId)
        .collection('noticias')
        .doc(noticiaId)
        .update({'fijada': fijada});
  }

  Future<void> updateCategoria(String grupoId, String noticiaId,
      NoticiaCategoria categoria) async {
    await _db
        .collection('grupos')
        .doc(grupoId)
        .collection('noticias')
        .doc(noticiaId)
        .update({'categoria': categoria.name});
  }

  Future<void> deleteNoticia(String grupoId, String noticiaId) async {
    await _db
        .collection('grupos')
        .doc(grupoId)
        .collection('noticias')
        .doc(noticiaId)
        .delete();
  }

  // ── Lecturas (read tracking) ───────────────────────────────────────────────

  /// Mark a noticia as read by the current user (idempotent).
  Future<void> markAsRead({
    required String grupoId,
    required String noticiaId,
    required String uid,
    required String nombre,
  }) async {
    await _db
        .collection('grupos')
        .doc(grupoId)
        .collection('noticias')
        .doc(noticiaId)
        .collection('lecturas')
        .doc(uid)
        .set({
      'nombre': nombre,
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Stream of who has read the noticia (admin view).
  Stream<List<LecturaItem>> getLecturas(String grupoId, String noticiaId) {
    return _db
        .collection('grupos')
        .doc(grupoId)
        .collection('noticias')
        .doc(noticiaId)
        .collection('lecturas')
        .orderBy('timestamp')
        .snapshots()
        .map((s) => s.docs.map(LecturaItem.fromFirestore).toList());
  }

  // ── Asistencia (attendance) ────────────────────────────────────────────────

  /// Stream of the current user's RSVP for a single event (efficient single-doc read).
  Stream<AsistenciaItem?> getMiAsistencia(
      String grupoId, String noticiaId, String uid) {
    return _db
        .collection('grupos')
        .doc(grupoId)
        .collection('noticias')
        .doc(noticiaId)
        .collection('asistencia')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? AsistenciaItem.fromFirestore(doc) : null);
  }

  Stream<List<AsistenciaItem>> getAsistencia(
      String grupoId, String noticiaId) {
    return _db
        .collection('grupos')
        .doc(grupoId)
        .collection('noticias')
        .doc(noticiaId)
        .collection('asistencia')
        .orderBy('timestamp')
        .snapshots()
        .map((s) => s.docs.map(AsistenciaItem.fromFirestore).toList());
  }

  Future<void> setAsistencia({
    required String grupoId,
    required String noticiaId,
    required String uid,
    required String nombre,
    String? avatarUrl,
    required String estado, // 'va' | 'no_va'
  }) async {
    await _db
        .collection('grupos')
        .doc(grupoId)
        .collection('noticias')
        .doc(noticiaId)
        .collection('asistencia')
        .doc(uid)
        .set({
      'nombre': nombre,
      'avatarUrl': avatarUrl,
      'estado': estado,
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: false));
  }

  Future<void> removeAsistencia(
      String grupoId, String noticiaId, String uid) async {
    await _db
        .collection('grupos')
        .doc(grupoId)
        .collection('noticias')
        .doc(noticiaId)
        .collection('asistencia')
        .doc(uid)
        .delete();
  }

  // ── Comentarios ────────────────────────────────────────────────────────────

  Stream<List<ComentarioModel>> getComentarios(
      String grupoId, String noticiaId) {
    return _db
        .collection('grupos')
        .doc(grupoId)
        .collection('noticias')
        .doc(noticiaId)
        .collection('comentarios')
        .orderBy('createdAt')
        .snapshots()
        .map((s) => s.docs.map(ComentarioModel.fromFirestore).toList());
  }

  Future<void> addComentario({
    required String grupoId,
    required String noticiaId,
    required String uid,
    required String nombre,
    String? avatarUrl,
    required String texto,
  }) async {
    await _db
        .collection('grupos')
        .doc(grupoId)
        .collection('noticias')
        .doc(noticiaId)
        .collection('comentarios')
        .add({
      'uid': uid,
      'nombre': nombre,
      'avatarUrl': avatarUrl,
      'texto': texto,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteComentario(
      String grupoId, String noticiaId, String comentarioId) async {
    await _db
        .collection('grupos')
        .doc(grupoId)
        .collection('noticias')
        .doc(noticiaId)
        .collection('comentarios')
        .doc(comentarioId)
        .delete();
  }
}
