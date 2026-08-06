import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tarea_model.dart';
import '../models/enums.dart';

class TareaDatasource {
  final _db = FirebaseFirestore.instance;

  CollectionReference _col(String grupoId) =>
      _db.collection('grupos').doc(grupoId).collection('tareas');

  Stream<List<TareaModel>> getTareas(String grupoId) {
    return _col(grupoId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(TareaModel.fromFirestore).toList());
  }

  Future<String> createTarea({
    required String grupoId,
    required String titulo,
    String? descripcion,
    required String creadoPorUid,
    required String creadoPorNombre,
    List<AsignadoTarea> asignadosA = const [],
    DateTime? fechaVencimiento,
  }) async {
    final ref = _col(grupoId).doc();
    await ref.set({
      'grupoId': grupoId,
      'titulo': titulo,
      'descripcion': descripcion,
      'creadoPorUid': creadoPorUid,
      'creadoPorNombre': creadoPorNombre,
      'asignadosA': asignadosA.map((a) => a.toMap()).toList(),
      'estado': TareaEstado.pendiente.name,
      if (fechaVencimiento != null)
        'fechaVencimiento': Timestamp.fromDate(fechaVencimiento),
      'createdAt': Timestamp.now(),
    });
    return ref.id;
  }

  Future<void> updateEstado(
      String grupoId, String tareaId, TareaEstado estado) {
    return _col(grupoId).doc(tareaId).update({'estado': estado.name});
  }

  Future<void> updateAsignados(String grupoId, String tareaId,
      List<AsignadoTarea> asignadosA) {
    return _col(grupoId)
        .doc(tareaId)
        .update({'asignadosA': asignadosA.map((a) => a.toMap()).toList()});
  }

  Future<void> updateTarea({
    required String grupoId,
    required String tareaId,
    required String titulo,
    String? descripcion,
    required List<AsignadoTarea> asignadosA,
    required TareaEstado estado,
    DateTime? fechaVencimiento,
  }) {
    return _col(grupoId).doc(tareaId).update({
      'titulo': titulo,
      'descripcion': descripcion,
      'asignadosA': asignadosA.map((a) => a.toMap()).toList(),
      'estado': estado.name,
      'fechaVencimiento':
          fechaVencimiento != null ? Timestamp.fromDate(fechaVencimiento) : null,
    });
  }

  Future<void> deleteTarea(String grupoId, String tareaId) {
    return _col(grupoId).doc(tareaId).delete();
  }
}
