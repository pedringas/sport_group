import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/noticia_model.dart';
import '../models/enums.dart';

class NoticiaDatasource {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  CollectionReference _noticias(String grupoId) =>
      _db.collection('grupos').doc(grupoId).collection('noticias');

  Stream<List<NoticiaModel>> getNoticias(String grupoId) =>
      _noticias(grupoId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((s) => s.docs.map(NoticiaModel.fromFirestore).toList());

  /// Creates the noticia doc (with optional image upload). Returns the new id.
  Future<String> createNoticiaDoc({
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
    final ref = _noticias(grupoId).doc();
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
      'fechaCaducidad':
          fechaCaducidad != null ? Timestamp.fromDate(fechaCaducidad) : null,
      'fechaEvento':
          fechaEvento != null ? Timestamp.fromDate(fechaEvento) : null,
      'createdAt': Timestamp.now(),
    });
    return ref.id;
  }

  Future<void> updateNoticiaDoc({
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
    await _noticias(grupoId).doc(noticiaId).update({
      'titulo': titulo,
      'contenido': contenido,
      'imagenUrl': imagenUrl,
      'tieneListado': tieneListado,
      'categoria': categoria.name,
      'mencionados': mencionados.map((m) => m.toMap()).toList(),
      'fechaCaducidad':
          fechaCaducidad != null ? Timestamp.fromDate(fechaCaducidad) : null,
      'fechaEvento':
          fechaEvento != null ? Timestamp.fromDate(fechaEvento) : null,
    });
  }

  Future<void> toggleLike(String grupoId, String noticiaId, String uid) async {
    final ref = _noticias(grupoId).doc(noticiaId);
    final doc = await ref.get();
    final likes = List<String>.from(
        (doc.data() as Map<String, dynamic>?)?['likes'] ?? []);
    if (likes.contains(uid)) {
      likes.remove(uid);
    } else {
      likes.add(uid);
    }
    await ref.update({'likes': likes});
  }

  Future<void> toggleFijada(String grupoId, String noticiaId, bool fijada) =>
      _noticias(grupoId).doc(noticiaId).update({'fijada': fijada});

  Future<void> updateCategoria(
          String grupoId, String noticiaId, NoticiaCategoria categoria) =>
      _noticias(grupoId)
          .doc(noticiaId)
          .update({'categoria': categoria.name});

  Future<void> deleteNoticia(String grupoId, String noticiaId) =>
      _noticias(grupoId).doc(noticiaId).delete();

  // ── Lecturas ─────────────────────────────────────────────────────────────────

  Future<void> markAsRead({
    required String grupoId,
    required String noticiaId,
    required String uid,
    required String nombre,
  }) =>
      _noticias(grupoId).doc(noticiaId).collection('lecturas').doc(uid).set({
        'nombre': nombre,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Stream<List<LecturaItem>> getLecturas(String grupoId, String noticiaId) =>
      _noticias(grupoId)
          .doc(noticiaId)
          .collection('lecturas')
          .orderBy('timestamp')
          .snapshots()
          .map((s) => s.docs.map(LecturaItem.fromFirestore).toList());

  // ── Asistencia ───────────────────────────────────────────────────────────────

  Stream<AsistenciaItem?> getMiAsistencia(
          String grupoId, String noticiaId, String uid) =>
      _noticias(grupoId)
          .doc(noticiaId)
          .collection('asistencia')
          .doc(uid)
          .snapshots()
          .map((doc) => doc.exists ? AsistenciaItem.fromFirestore(doc) : null);

  Stream<List<AsistenciaItem>> getAsistencia(
          String grupoId, String noticiaId) =>
      _noticias(grupoId)
          .doc(noticiaId)
          .collection('asistencia')
          .orderBy('timestamp')
          .snapshots()
          .map((s) => s.docs.map(AsistenciaItem.fromFirestore).toList());

  Future<void> setAsistencia({
    required String grupoId,
    required String noticiaId,
    required String uid,
    required String nombre,
    String? avatarUrl,
    required String estado,
  }) =>
      _noticias(grupoId).doc(noticiaId).collection('asistencia').doc(uid).set({
        'nombre': nombre,
        'avatarUrl': avatarUrl,
        'estado': estado,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: false));

  Future<void> removeAsistencia(
          String grupoId, String noticiaId, String uid) =>
      _noticias(grupoId)
          .doc(noticiaId)
          .collection('asistencia')
          .doc(uid)
          .delete();

  // ── Comentarios ──────────────────────────────────────────────────────────────

  Stream<List<ComentarioModel>> getComentarios(
          String grupoId, String noticiaId) =>
      _noticias(grupoId)
          .doc(noticiaId)
          .collection('comentarios')
          .orderBy('createdAt')
          .snapshots()
          .map((s) => s.docs.map(ComentarioModel.fromFirestore).toList());

  Future<void> addComentario({
    required String grupoId,
    required String noticiaId,
    required String uid,
    required String nombre,
    String? avatarUrl,
    required String texto,
  }) =>
      _noticias(grupoId).doc(noticiaId).collection('comentarios').add({
        'uid': uid,
        'nombre': nombre,
        'avatarUrl': avatarUrl,
        'texto': texto,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> deleteComentario(
          String grupoId, String noticiaId, String comentarioId) =>
      _noticias(grupoId)
          .doc(noticiaId)
          .collection('comentarios')
          .doc(comentarioId)
          .delete();
}
