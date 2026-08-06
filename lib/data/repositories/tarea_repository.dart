import '../datasources/tarea_datasource.dart';
import '../models/tarea_model.dart';
import '../models/enums.dart';

class TareaRepository {
  final TareaDatasource _ds;
  TareaRepository([TareaDatasource? ds]) : _ds = ds ?? TareaDatasource();

  Stream<List<TareaModel>> getTareas(String grupoId) =>
      _ds.getTareas(grupoId);

  Future<String> createTarea({
    required String grupoId,
    required String titulo,
    String? descripcion,
    required String creadoPorUid,
    required String creadoPorNombre,
    List<AsignadoTarea> asignadosA = const [],
    DateTime? fechaVencimiento,
  }) =>
      _ds.createTarea(
        grupoId: grupoId,
        titulo: titulo,
        descripcion: descripcion,
        creadoPorUid: creadoPorUid,
        creadoPorNombre: creadoPorNombre,
        asignadosA: asignadosA,
        fechaVencimiento: fechaVencimiento,
      );

  Future<void> updateEstado(
          String grupoId, String tareaId, TareaEstado estado) =>
      _ds.updateEstado(grupoId, tareaId, estado);

  Future<void> updateAsignados(String grupoId, String tareaId,
          List<AsignadoTarea> asignadosA) =>
      _ds.updateAsignados(grupoId, tareaId, asignadosA);

  Future<void> updateTarea({
    required String grupoId,
    required String tareaId,
    required String titulo,
    String? descripcion,
    required List<AsignadoTarea> asignadosA,
    required TareaEstado estado,
    DateTime? fechaVencimiento,
  }) =>
      _ds.updateTarea(
        grupoId: grupoId,
        tareaId: tareaId,
        titulo: titulo,
        descripcion: descripcion,
        asignadosA: asignadosA,
        estado: estado,
        fechaVencimiento: fechaVencimiento,
      );

  Future<void> deleteTarea(String grupoId, String tareaId) =>
      _ds.deleteTarea(grupoId, tareaId);
}
