import 'dart:developer' as dev;
import 'dart:typed_data';
import '../datasources/grupo_datasource.dart';
import '../models/grupo_model.dart';
import '../models/miembro_model.dart';
import '../models/solicitud_union_model.dart';
import '../models/enums.dart';
import '../models/actividad_model.dart';
import '../models/notificacion_rol_model.dart';
import 'notificacion_repository.dart';

class GrupoRepository {
  final GrupoDatasource _ds;
  GrupoRepository([GrupoDatasource? ds]) : _ds = ds ?? GrupoDatasource();

  Future<String> createGrupo(
    GrupoModel grupo, {
    required String adminNombreCompleto,
    String? adminAvatarUrl,
  }) =>
      _ds.createGrupo(
        grupo,
        adminNombreCompleto: adminNombreCompleto,
        adminAvatarUrl: adminAvatarUrl,
      );

  /// Garantiza que el grupo exista y que el usuario sea miembro (auto-ingreso).
  /// Ver [GrupoDatasource.ensureMembership].
  Future<void> ensureMembership(
    String grupoId, {
    required String uid,
    required String nombreCompleto,
    String? avatarUrl,
    required String grupoNombre,
  }) =>
      _ds.ensureMembership(
        grupoId,
        uid: uid,
        nombreCompleto: nombreCompleto,
        avatarUrl: avatarUrl,
        grupoNombre: grupoNombre,
      );

  Future<String?> uploadLogo(String grupoId, Uint8List bytes) =>
      _ds.uploadLogo(grupoId, bytes);

  Future<String?> uploadPortada(String grupoId, Uint8List bytes) =>
      _ds.uploadPortada(grupoId, bytes);

  Future<void> updateGrupo(String grupoId, Map<String, dynamic> data) =>
      _ds.updateGrupo(grupoId, data);

  Stream<List<GrupoModel>> getUserGrupos(String uid) =>
      _ds.getUserGrupos(uid);

  Future<List<GrupoModel>> searchGrupos(String query) =>
      _ds.searchGrupos(query);

  Future<List<GrupoModel>> searchPublicGrupos(String query) =>
      _ds.searchGrupos(query);

  Future<GrupoModel?> searchGrupoByCodigo(String codigo) =>
      _ds.searchGrupoByCodigo(codigo);

  Future<GrupoModel?> getGrupo(String grupoId) => _ds.getGrupo(grupoId);

  Stream<GrupoModel?> getGrupoStream(String grupoId) =>
      _ds.getGrupoStream(grupoId);

  Stream<MiembroModel?> getMiembroStream(String grupoId, String uid) =>
      _ds.getMiembroStream(grupoId, uid);

  Future<void> joinGrupo(String grupoId, String uid, String nombreCompleto,
      String? avatarUrl) async {
    await _ds.joinGrupo(grupoId, uid, nombreCompleto, avatarUrl);

    try {
      await NotificacionRepository().writeActividad(
        grupoId,
        ActividadModel(
          id: '',
          tipo: 'nuevo_miembro',
          titulo: 'Nuevo miembro',
          mensaje: '$nombreCompleto se unió al grupo',
          actorNombre: nombreCompleto,
          actorAvatarUrl: avatarUrl,
          grupoId: grupoId,
          grupoNombre: '',
          createdAt: DateTime.now(),
        ),
      );
    } catch (e) {
      dev.log('[Actividad] $e');
    }
  }

  Future<void> requestJoinGrupo(String grupoId, String uid,
          String nombreCompleto, String? avatarUrl) =>
      _ds.requestJoinGrupo(grupoId, uid, nombreCompleto, avatarUrl);

  Future<void> responderSolicitud(String grupoId, String uid, bool aprobar,
      String nombreCompleto, String? avatarUrl) async {
    await _ds.responderSolicitudDoc(
        grupoId, uid, aprobar, nombreCompleto, avatarUrl);

    if (aprobar) {
      try {
        await NotificacionRepository().writeActividad(
          grupoId,
          ActividadModel(
            id: '',
            tipo: 'nuevo_miembro',
            titulo: 'Nuevo miembro',
            mensaje: '$nombreCompleto se unió al grupo',
            actorNombre: nombreCompleto,
            actorAvatarUrl: avatarUrl,
            grupoId: grupoId,
            grupoNombre: '',
            createdAt: DateTime.now(),
          ),
        );
      } catch (e) {
        dev.log('[Actividad] $e');
      }
    }
  }

  Stream<List<MiembroModel>> getMiembros(String grupoId) =>
      _ds.getMiembros(grupoId);

  Future<MiembroModel?> getMiembro(String grupoId, String uid) =>
      _ds.getMiembro(grupoId, uid);

  Future<void> updateRolMiembro(
    String grupoId,
    String uid,
    RolMiembro rol, {
    String nombreMiembro = '',
    String grupoNombre = '',
  }) async {
    await _ds.updateRolDoc(grupoId, uid, rol);

    if (rol != RolMiembro.miembro && nombreMiembro.isNotEmpty) {
      final tipoNotif = _rolToTipoNotif(rol);
      if (tipoNotif != null) {
        try {
          await NotificacionRepository().writeNotificacionRol(
            uid,
            NotificacionRolModel(
              id: '',
              tipo: tipoNotif,
              titulo: 'Nuevo rol asignado: ${_rolLabel(rol)}',
              mensaje: grupoNombre.isNotEmpty
                  ? 'Fuiste designado $tipoNotif en "$grupoNombre"'
                  : 'Fuiste designado $tipoNotif en el grupo',
              grupoId: grupoId,
              grupoNombre: grupoNombre,
              createdAt: DateTime.now(),
            ),
          );
        } catch (e) {
          dev.log('[Actividad] $e');
        }
      }
    }
  }

  static String? _rolToTipoNotif(RolMiembro rol) {
    switch (rol) {
      case RolMiembro.administrador:
        return 'admin';
      case RolMiembro.moderador:
        return 'moderador';
      case RolMiembro.tesorero:
        return 'tesorero';
      case RolMiembro.delegado:
        return 'delegado';
      default:
        return null;
    }
  }

  static String _rolLabel(RolMiembro rol) {
    switch (rol) {
      case RolMiembro.administrador:
        return 'Administrador';
      case RolMiembro.moderador:
        return 'Moderador';
      case RolMiembro.tesorero:
        return 'Tesorero';
      case RolMiembro.delegado:
        return 'Delegado';
      default:
        return 'Miembro';
    }
  }

  Future<void> setFavorito(String grupoId, String uid, bool value) =>
      _ds.setFavorito(grupoId, uid, value);

  Future<void> leaveGrupo(String grupoId, String uid) =>
      _ds.leaveGrupo(grupoId, uid);

  Future<void> deleteGrupo(String grupoId) => _ds.deleteGrupo(grupoId);

  Future<SolicitudUnionModel?> getMiSolicitud(String grupoId, String uid) =>
      _ds.getMiSolicitud(grupoId, uid);

  Stream<List<SolicitudUnionModel>> getSolicitudesPendientes(String grupoId) =>
      _ds.getSolicitudesPendientes(grupoId);
}
