import 'dart:developer';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import '../datasources/cuota_datasource.dart';
import '../models/cuota_model.dart';
import '../models/pago_model.dart';
import '../models/enums.dart';
import '../models/actividad_model.dart';
import '../models/notificacion_rol_model.dart';
import 'notificacion_repository.dart';

class CuotaRepository {
  final CuotaDatasource _ds;
  final _uuid = const Uuid();
  CuotaRepository([CuotaDatasource? ds]) : _ds = ds ?? CuotaDatasource();

  // ── Cuotas ──────────────────────────────────────────────────────────────────

  Stream<List<CuotaModel>> getCuotas(String grupoId) =>
      _ds.getCuotas(grupoId);

  Future<String> createCuota({
    required String grupoId,
    required String titulo,
    String? descripcion,
    required double monto,
    required DateTime vencimiento,
    List<String>? miembrosUids,
    List<String>? excluidosUids,
  }) async {
    final id = await _ds.createCuotaDoc(
      grupoId: grupoId,
      titulo: titulo,
      descripcion: descripcion,
      monto: monto,
      vencimiento: vencimiento,
      miembrosUids: miembrosUids,
      excluidosUids: excluidosUids,
    );

    try {
      final fmt = '\$${monto.round()}';
      await NotificacionRepository().writeActividad(
        grupoId,
        ActividadModel(
          id: '',
          tipo: 'nueva_cuota',
          titulo: 'Nueva cuota: $titulo',
          mensaje: 'Monto: $fmt',
          actorNombre: '',
          grupoId: grupoId,
          grupoNombre: '',
          referenciaId: id,
          createdAt: DateTime.now(),
        ),
      );
    } catch (e) {
      log('[Actividad] $e');
    }

    return id;
  }

  Future<String> createCuotasSerie({
    required String grupoId,
    required String titulo,
    String? descripcion,
    required double monto,
    required DateTime primerVencimiento,
    required FrecuenciaCuota frecuencia,
    required int totalCuotas,
    List<String>? miembrosUids,
    List<String>? excluidosUids,
  }) async {
    final serieId = await _ds.createCuotasSerie(
      grupoId: grupoId,
      serieId: _uuid.v4(),
      titulo: titulo,
      descripcion: descripcion,
      monto: monto,
      primerVencimiento: primerVencimiento,
      frecuencia: frecuencia,
      totalCuotas: totalCuotas,
      miembrosUids: miembrosUids,
      excluidosUids: excluidosUids,
    );

    // Las series no publicaban actividad: el grupo se enteraba de una cuota
    // suelta pero no de una serie de 12.
    try {
      await NotificacionRepository().writeActividad(
        grupoId,
        ActividadModel(
          id: '',
          tipo: 'nueva_cuota',
          titulo: 'Nuevas cuotas: $titulo',
          mensaje:
              '$totalCuotas cuotas de \$${monto.round()} (${frecuencia.label.toLowerCase()})',
          actorNombre: '',
          grupoId: grupoId,
          grupoNombre: '',
          referenciaId: serieId,
          createdAt: DateTime.now(),
        ),
      );
    } catch (e) {
      log('[Actividad] $e');
    }

    return serieId;
  }

  Future<CuotaModel?> getCuota(String grupoId, String cuotaId) =>
      _ds.getCuota(grupoId, cuotaId);

  Stream<List<PagoModel>> getPagosDeCuota(String grupoId, String cuotaId) =>
      _ds.getPagosDeCuota(grupoId, cuotaId);

  Stream<PagoModel?> getMiPago(String grupoId, String cuotaId, String uid) =>
      _ds.getMiPago(grupoId, cuotaId, uid);

  Future<void> deleteCuota(String grupoId, String cuotaId) =>
      _ds.deleteCuota(grupoId, cuotaId);

  Future<void> updateCuota(
    String grupoId,
    String cuotaId, {
    required String titulo,
    String? descripcion,
    required double monto,
    required DateTime vencimiento,
  }) =>
      _ds.updateCuotaDoc(grupoId, cuotaId,
          titulo: titulo,
          descripcion: descripcion,
          monto: monto,
          vencimiento: vencimiento);

  Future<void> deleteSerie(String grupoId, String serieId) =>
      _ds.deleteSerie(grupoId, serieId);

  Stream<List<PagoModel>> getPagosDeGrupo(String grupoId) =>
      _ds.getPagosDeGrupo(grupoId);

  Stream<List<PagoModel>> getMisPagosGrupo(String grupoId, String uid) =>
      _ds.getMisPagosGrupo(grupoId, uid);

  Future<void> deletePago(String pagoId) => _ds.deletePago(pagoId);

  Future<void> updatePagoEstado(String pagoId, EstadoPago nuevoEstado) =>
      _ds.updatePagoEstadoDoc(pagoId, nuevoEstado);

  Stream<List<PagoModel>> getMisPagosAprobados(String grupoId, String uid) =>
      _ds.getMisPagosAprobados(grupoId, uid);

  Future<String> registrarPagoEfectivo({
    required String grupoId,
    required String cuotaId,
    required String usuarioUid,
    required String usuarioNombre,
    required double monto,
    String? nota,
  }) async {
    final pagoId = await _ds.createPagoEfectivoDoc(
      grupoId: grupoId,
      cuotaId: cuotaId,
      usuarioUid: usuarioUid,
      usuarioNombre: usuarioNombre,
      monto: monto,
      nota: nota,
    );

    try {
      final adminUids = await _ds.getAdminsTesoreros(grupoId, usuarioUid);
      final notifRepo = NotificacionRepository();
      for (final uid in adminUids) {
        await notifRepo.writeNotificacionRol(
          uid,
          NotificacionRolModel(
            id: '',
            tipo: 'pago_efectivo_registrado',
            titulo: 'Nuevo pago en efectivo',
            mensaje: '$usuarioNombre registró un pago de \$${monto.round()} (cuota)',
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

    return pagoId;
  }

  Future<void> confirmarPago({
    required String pagoId,
    required EstadoPago nuevoEstado,
    required String miembroUid,
    required String grupoId,
    required double monto,
  }) async {
    await _ds.updatePagoEstadoDoc(pagoId, nuevoEstado);

    try {
      final aprobado = nuevoEstado == EstadoPago.aprobado;
      await NotificacionRepository().writeNotificacionRol(
        miembroUid,
        NotificacionRolModel(
          id: '',
          tipo: aprobado ? 'pago_aprobado' : 'pago_rechazado',
          titulo: aprobado ? '¡Pago aprobado!' : 'Pago rechazado',
          mensaje: aprobado
              ? 'Tu pago de \$${monto.round()} fue confirmado por el administrador.'
              : 'Tu pago de \$${monto.round()} fue rechazado. Contactá al administrador.',
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

  Future<String> initPagoManual({
    required String grupoId,
    required String cuotaId,
    required String usuarioUid,
    required String usuarioNombre,
    required double monto,
  }) =>
      _ds.initPagoManual(
        grupoId: grupoId,
        cuotaId: cuotaId,
        usuarioUid: usuarioUid,
        usuarioNombre: usuarioNombre,
        monto: monto,
      );

  Future<void> uploadComprobante({
    required String pagoId,
    required String grupoId,
    required Uint8List bytes,
    String? bancoOrigen,
    String? nroOperacion,
    String? mensajeAlTesorero,
  }) =>
      _ds.uploadComprobante(
        pagoId: pagoId,
        grupoId: grupoId,
        bytes: bytes,
        bancoOrigen: bancoOrigen,
        nroOperacion: nroOperacion,
        mensajeAlTesorero: mensajeAlTesorero,
      );
}
