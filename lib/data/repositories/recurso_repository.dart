import 'dart:typed_data';
import '../datasources/recurso_datasource.dart';
import '../models/recurso_model.dart';

class RecursoRepository {
  final RecursoDatasource _ds;
  RecursoRepository([RecursoDatasource? ds]) : _ds = ds ?? RecursoDatasource();

  Stream<List<RecursoModel>> getRecursos(String grupoId) =>
      _ds.getRecursos(grupoId);

  Future<String> uploadArchivo(
          String grupoId, String nombre, Uint8List bytes) =>
      _ds.uploadArchivo(grupoId, nombre, bytes);

  Future<void> createRecurso({
    required String grupoId,
    required String autorUid,
    required String autorNombre,
    required String titulo,
    required TipoRecurso tipo,
    required String url,
    String? descripcion,
    String? nombreArchivo,
  }) =>
      _ds.createRecurso(
        grupoId: grupoId,
        autorUid: autorUid,
        autorNombre: autorNombre,
        titulo: titulo,
        tipo: tipo,
        url: url,
        descripcion: descripcion,
        nombreArchivo: nombreArchivo,
      );

  Future<void> deleteRecurso(String grupoId, String recursoId) =>
      _ds.deleteRecurso(grupoId, recursoId);
}
