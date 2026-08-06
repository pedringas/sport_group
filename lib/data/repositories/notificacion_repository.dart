import '../datasources/notificacion_datasource.dart';
import '../models/actividad_model.dart';
import '../models/notificacion_rol_model.dart';

class NotificacionRepository {
  final NotificacionDatasource _ds;
  NotificacionRepository([NotificacionDatasource? ds])
      : _ds = ds ?? NotificacionDatasource();

  Future<void> writeActividad(String grupoId, ActividadModel a) =>
      _ds.writeActividad(grupoId, a);

  Future<void> writeNotificacionRol(String uid, NotificacionRolModel n) =>
      _ds.writeNotificacionRol(uid, n);

  Future<void> marcarLeida(String uid, String notifId) =>
      _ds.marcarLeida(uid, notifId);

  Future<void> marcarTodasLeidas(String uid) => _ds.marcarTodasLeidas(uid);

  Stream<List<ActividadModel>> getActividad(String grupoId) =>
      _ds.getActividad(grupoId);

  Future<List<ActividadModel>> getActividadOnce(String grupoId) =>
      _ds.getActividadOnce(grupoId);

  Stream<List<NotificacionRolModel>> getNotificacionesRol(String uid) =>
      _ds.getNotificacionesRol(uid);

  Stream<int> getUnreadCount(String uid) => _ds.getUnreadCount(uid);
}
