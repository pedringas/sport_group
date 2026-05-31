import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/recurso_model.dart';

class RecursoRepository {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  Stream<List<RecursoModel>> getRecursos(String grupoId) {
    return _db
        .collection('grupos')
        .doc(grupoId)
        .collection('recursos')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(RecursoModel.fromFirestore).toList());
  }

  Future<String> uploadArchivo(
      String grupoId, String nombre, Uint8List bytes) async {
    final ext = nombre.contains('.') ? nombre.split('.').last : 'bin';
    final ref = _storage
        .ref('grupos/$grupoId/recursos/${DateTime.now().millisecondsSinceEpoch}.$ext');
    await ref.putData(bytes);
    return ref.getDownloadURL();
  }

  Future<void> createRecurso({
    required String grupoId,
    required String autorUid,
    required String autorNombre,
    required String titulo,
    required TipoRecurso tipo,
    required String url,
    String? descripcion,
    String? nombreArchivo,
  }) async {
    await _db
        .collection('grupos')
        .doc(grupoId)
        .collection('recursos')
        .add({
      'grupoId': grupoId,
      'autorUid': autorUid,
      'autorNombre': autorNombre,
      'titulo': titulo,
      'tipo': tipo.name,
      'url': url,
      'descripcion': descripcion,
      'nombreArchivo': nombreArchivo,
      'createdAt': Timestamp.now(),
    });
  }

  Future<void> deleteRecurso(String grupoId, String recursoId) async {
    await _db
        .collection('grupos')
        .doc(grupoId)
        .collection('recursos')
        .doc(recursoId)
        .delete();
  }
}
