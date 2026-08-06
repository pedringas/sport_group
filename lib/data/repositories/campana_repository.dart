import 'dart:developer';
import '../datasources/campana_datasource.dart';
import '../models/campana_model.dart';
import '../models/enums.dart';
import '../models/notificacion_rol_model.dart';
import 'notificacion_repository.dart';

class CampanaRepository {
  final CampanaDatasource _ds;
  CampanaRepository([CampanaDatasource? ds]) : _ds = ds ?? CampanaDatasource();

  // ── Campañas ──────────────────────────────────────────────────────────────

  Stream<List<CampanaModel>> getCampanas(String grupoId) =>
      _ds.getCampanas(grupoId);

  Future<CampanaModel?> getCampana(String grupoId, String campanaId) =>
      _ds.getCampana(grupoId, campanaId);

  Stream<CampanaModel?> watchCampana(String grupoId, String campanaId) =>
      _ds.watchCampana(grupoId, campanaId);

  Future<String> createCampana({
    required String grupoId,
    required String titulo,
    String? descripcion,
    required double objetivo,
    DateTime? fechaLimite,
    String? imagenUrl,
    required String creadoPor,
  }) =>
      _ds.createCampana(
        grupoId: grupoId,
        titulo: titulo,
        descripcion: descripcion,
        objetivo: objetivo,
        fechaLimite: fechaLimite,
        imagenUrl: imagenUrl,
        creadoPor: creadoPor,
      );

  Future<void> updateEstado(
          String grupoId, String campanaId, EstadoCampana estado) =>
      _ds.updateEstado(grupoId, campanaId, estado);

  // ── Aportes ───────────────────────────────────────────────────────────────

  Stream<List<AporteModel>> getAportes(String grupoId, String campanaId) =>
      _ds.getAportes(grupoId, campanaId);

  Stream<List<AporteModel>> getMisAportesGrupo(String grupoId, String uid) =>
      _ds.getMisAportesGrupo(grupoId, uid);

  Future<String> addAporte({
    required String grupoId,
    required String campanaId,
    required String usuarioUid,
    required String usuarioNombre,
    required double monto,
    String? mensaje,
  }) =>
      _ds.addAporte(
        grupoId: grupoId,
        campanaId: campanaId,
        usuarioUid: usuarioUid,
        usuarioNombre: usuarioNombre,
        monto: monto,
        mensaje: mensaje,
      );

  Future<String> addAportePendiente({
    required String grupoId,
    required String campanaId,
    required String usuarioUid,
    required String usuarioNombre,
    required double monto,
    String? mensaje,
    String metodo = 'efectivo',
  }) async {
    final aporteId = await _ds.addAportePendienteDoc(
      grupoId: grupoId,
      campanaId: campanaId,
      usuarioUid: usuarioUid,
      usuarioNombre: usuarioNombre,
      monto: monto,
      mensaje: mensaje,
      metodo: metodo,
    );

    try {
      final adminUids = await _ds.getAdminsTesoreros(grupoId, usuarioUid);
      final notifRepo = NotificacionRepository();
      for (final uid in adminUids) {
        await notifRepo.writeNotificacionRol(
          uid,
          NotificacionRolModel(
            id: '',
            tipo: 'aporte_pendiente',
            titulo: 'Nuevo aporte pendiente',
            mensaje:
                '$usuarioNombre registró un aporte de \$${monto.round()} '
                '(${metodo == 'efectivo' ? 'efectivo' : 'transferencia'})',
            grupoId: grupoId,
            grupoNombre: '',
            leida: false,
            createdAt: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      log('[Actividad] $e');
    }

    return aporteId;
  }

  Future<void> aprobarAporte({
    required String grupoId,
    required String campanaId,
    required String aporteId,
    required String miembroUid,
    required double monto,
  }) async {
    await _ds.aprobarAporteDoc(
      grupoId: grupoId,
      campanaId: campanaId,
      aporteId: aporteId,
      monto: monto,
    );

    try {
      await NotificacionRepository().writeNotificacionRol(
        miembroUid,
        NotificacionRolModel(
          id: '',
          tipo: 'aporte_aprobado',
          titulo: '¡Aporte confirmado!',
          mensaje:
              'Tu aporte de \$${monto.round()} fue confirmado. ¡Gracias por contribuir!',
          grupoId: grupoId,
          grupoNombre: '',
          leida: false,
          createdAt: DateTime.now(),
        ),
      );
    } catch (e) {
      log('[Actividad] $e');
    }
  }

  Future<void> rechazarAporte({
    required String grupoId,
    required String campanaId,
    required String aporteId,
    required String miembroUid,
    required double monto,
  }) async {
    await _ds.rechazarAporteDoc(grupoId, campanaId, aporteId);

    try {
      await NotificacionRepository().writeNotificacionRol(
        miembroUid,
        NotificacionRolModel(
          id: '',
          tipo: 'aporte_rechazado',
          titulo: 'Aporte no confirmado',
          mensaje:
              'Tu aporte de \$${monto.round()} no fue confirmado. Contactá al tesorero.',
          grupoId: grupoId,
          grupoNombre: '',
          leida: false,
          createdAt: DateTime.now(),
        ),
      );
    } catch (e) {
      log('[Actividad] $e');
    }
  }

  Future<void> deleteAporte({
    required String grupoId,
    required String campanaId,
    required String aporteId,
    required double monto,
  }) =>
      _ds.deleteAporte(
        grupoId: grupoId,
        campanaId: campanaId,
        aporteId: aporteId,
        monto: monto,
      );
}
