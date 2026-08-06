import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cuota_grupo_model.dart';

class CuotaGrupoRepository {
  final FirebaseFirestore _db;
  CuotaGrupoRepository(this._db);

  CollectionReference<Map<String, dynamic>> _col(String grupoId) =>
      _db.collection('grupos').doc(grupoId).collection('cuotaGrupos');

  Stream<List<CuotaGrupoModel>> watchCuotaGrupos(String grupoId) =>
      _col(grupoId)
          .orderBy('createdAt', descending: false)
          .snapshots()
          .map((s) => s.docs.map(CuotaGrupoModel.fromFirestore).toList());

  Future<CuotaGrupoModel?> getCuotaGrupo(String grupoId, String id) async {
    final doc = await _col(grupoId).doc(id).get();
    if (!doc.exists) return null;
    return CuotaGrupoModel.fromFirestore(doc);
  }

  Future<String> createCuotaGrupo(
      String grupoId, CuotaGrupoModel model) async {
    final ref = await _col(grupoId).add(model.toMap());
    return ref.id;
  }

  Future<void> updateCuotaGrupo(
      String grupoId, CuotaGrupoModel model) async {
    await _col(grupoId).doc(model.id).update(model.toMap());
  }

  Future<void> deleteCuotaGrupo(String grupoId, String id) async {
    await _col(grupoId).doc(id).delete();
  }

  Future<void> addMiembro(
      String grupoId, String cuotaGrupoId, String uid) async {
    await _col(grupoId).doc(cuotaGrupoId).update({
      'miembrosUids': FieldValue.arrayUnion([uid]),
    });
  }

  Future<void> removeMiembro(
      String grupoId, String cuotaGrupoId, String uid) async {
    await _col(grupoId).doc(cuotaGrupoId).update({
      'miembrosUids': FieldValue.arrayRemove([uid]),
    });
  }
}
