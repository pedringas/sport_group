import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/cuota_model.dart';
import '../models/pago_model.dart';
import '../models/enums.dart';
import '../models/actividad_model.dart';
import '../models/notificacion_rol_model.dart';
import 'notificacion_repository.dart';

class CuotaRepository {
  final _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  Stream<List<CuotaModel>> getCuotas(String grupoId) {
    return _db
        .collection('grupos')
        .doc(grupoId)
        .collection('cuotas')
        .orderBy('vencimiento', descending: false)
        .snapshots()
        .map((s) => s.docs.map(CuotaModel.fromFirestore).toList());
  }

  /// Creates a single cuota (non-recurring).
  Future<String> createCuota({
    required String grupoId,
    required String titulo,
    String? descripcion,
    required double monto,
    required DateTime vencimiento,
    List<String>? miembrosUids,
    List<String>? excluidosUids,
  }) async {
    final ref = _db.collection('grupos').doc(grupoId).collection('cuotas').doc();
    await ref.set({
      'grupoId': grupoId,
      'titulo': titulo,
      'descripcion': descripcion,
      'monto': monto,
      'vencimiento': Timestamp.fromDate(vencimiento),
      'activa': true,
      'esRecurrente': false,
      'createdAt': Timestamp.now(),
      if (miembrosUids != null && miembrosUids.isNotEmpty)
        'miembrosUids': miembrosUids,
      if (excluidosUids != null && excluidosUids.isNotEmpty)
        'excluidosUids': excluidosUids,
    });

    // Write group activity (fire-and-forget)
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
          referenciaId: ref.id,
          createdAt: DateTime.now(),
        ),
      );
    } catch (_) {}

    return ref.id;
  }

  /// Creates N cuotas in a batch (recurring series).
  /// Returns the serieId shared by all generated cuotas.
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
    final serieId = _uuid.v4();
    final batch = _db.batch();
    final colRef = _db.collection('grupos').doc(grupoId).collection('cuotas');

    for (int i = 0; i < totalCuotas; i++) {
      final venc = _addPeriods(primerVencimiento, frecuencia, i);
      final ref = colRef.doc();
      batch.set(ref, {
        'grupoId': grupoId,
        'titulo': titulo,
        'descripcion': descripcion,
        'monto': monto,
        'vencimiento': Timestamp.fromDate(venc),
        'activa': true,
        'esRecurrente': true,
        'frecuencia': frecuencia.name,
        'totalCuotas': totalCuotas,
        'numeroCuota': i + 1,
        'serieId': serieId,
        'createdAt': Timestamp.now(),
        if (miembrosUids != null && miembrosUids.isNotEmpty)
          'miembrosUids': miembrosUids,
        if (excluidosUids != null && excluidosUids.isNotEmpty)
          'excluidosUids': excluidosUids,
      });
    }

    await batch.commit();
    return serieId;
  }

  DateTime _addPeriods(DateTime base, FrecuenciaCuota freq, int n) {
    switch (freq) {
      case FrecuenciaCuota.mensual:
        return DateTime(base.year, base.month + n, base.day);
      case FrecuenciaCuota.bimestral:
        return DateTime(base.year, base.month + (n * 2), base.day);
      case FrecuenciaCuota.trimestral:
        return DateTime(base.year, base.month + (n * 3), base.day);
      case FrecuenciaCuota.anual:
        return DateTime(base.year + n, base.month, base.day);
      default:
        // semanal / quincenal — add days
        return base.add(Duration(days: freq.dias * n));
    }
  }

  Future<CuotaModel?> getCuota(String grupoId, String cuotaId) async {
    final doc = await _db
        .collection('grupos')
        .doc(grupoId)
        .collection('cuotas')
        .doc(cuotaId)
        .get();
    if (!doc.exists) return null;
    return CuotaModel.fromFirestore(doc);
  }

  Stream<List<PagoModel>> getPagosDeCuota(String grupoId, String cuotaId) {
    return _db
        .collection('pagos')
        .where('grupoId', isEqualTo: grupoId)
        .where('cuotaId', isEqualTo: cuotaId)
        .snapshots()
        .map((s) => s.docs.map(PagoModel.fromFirestore).toList());
  }

  Stream<PagoModel?> getMiPago(String grupoId, String cuotaId, String uid) {
    return _db
        .collection('pagos')
        .where('grupoId', isEqualTo: grupoId)
        .where('cuotaId', isEqualTo: cuotaId)
        .where('usuarioUid', isEqualTo: uid)
        .limit(1)
        .snapshots()
        .map((s) => s.docs.isEmpty ? null : PagoModel.fromFirestore(s.docs.first));
  }

  Future<void> deleteCuota(String grupoId, String cuotaId) async {
    await _db
        .collection('grupos')
        .doc(grupoId)
        .collection('cuotas')
        .doc(cuotaId)
        .delete();
  }

  /// Deletes every cuota in a series (same serieId) using batched writes.
  Future<void> deleteSerie(String grupoId, String serieId) async {
    final snap = await _db
        .collection('grupos')
        .doc(grupoId)
        .collection('cuotas')
        .where('serieId', isEqualTo: serieId)
        .get();

    // Firestore batch limit = 500 ops
    const batchSize = 400;
    for (int i = 0; i < snap.docs.length; i += batchSize) {
      final batch = _db.batch();
      final chunk = snap.docs.sublist(
          i, (i + batchSize).clamp(0, snap.docs.length));
      for (final d in chunk) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
  }

  /// Admin: all pagos for a group (to build completion matrix).
  Stream<List<PagoModel>> getPagosDeGrupo(String grupoId) {
    return _db
        .collection('pagos')
        .where('grupoId', isEqualTo: grupoId)
        .snapshots()
        .map((s) => s.docs.map(PagoModel.fromFirestore).toList());
  }

  /// Current user's own pagos for a group — safe for members.
  /// Only queries documents where usuarioUid == uid, so the Firestore rule
  /// `resource.data.usuarioUid == request.auth.uid` is satisfied without
  /// any get() calls (avoids the 10-get() limit on list evaluations).
  Stream<List<PagoModel>> getMisPagosGrupo(String grupoId, String uid) {
    return _db
        .collection('pagos')
        .where('grupoId', isEqualTo: grupoId)
        .where('usuarioUid', isEqualTo: uid)
        .snapshots()
        .map((s) => s.docs.map(PagoModel.fromFirestore).toList());
  }

  /// Delete a pago document (e.g. member cancels a pending cash payment).
  Future<void> deletePago(String pagoId) async {
    await _db.collection('pagos').doc(pagoId).delete();
  }

  /// Admin: approve or reject a payment.
  Future<void> updatePagoEstado(String pagoId, EstadoPago nuevoEstado) async {
    await _db.collection('pagos').doc(pagoId).update({
      'estado': nuevoEstado.name,
      'updatedAt': Timestamp.now(),
    });
  }

  /// Stream of approved payments for a specific user in a group (for Caja).
  Stream<List<PagoModel>> getMisPagosAprobados(String grupoId, String uid) {
    return _db
        .collection('pagos')
        .where('grupoId', isEqualTo: grupoId)
        .where('usuarioUid', isEqualTo: uid)
        .where('estado', isEqualTo: EstadoPago.aprobado.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(PagoModel.fromFirestore).toList());
  }

  /// Registra un pago en efectivo y notifica a tesoros + admins del grupo.
  Future<String> registrarPagoEfectivo({
    required String grupoId,
    required String cuotaId,
    required String usuarioUid,
    required String usuarioNombre,
    required double monto,
    String? nota,
  }) async {
    final ref = _db.collection('pagos').doc();
    final data = {
      'grupoId': grupoId,
      'cuotaId': cuotaId,
      'usuarioUid': usuarioUid,
      'usuarioNombre': usuarioNombre,
      'montoEsperado': monto,
      'estado': EstadoPago.pendiente.name,
      'metodo': MetodoPago.efectivo.name,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    };
    if (nota != null && nota.trim().isNotEmpty) data['nota'] = nota.trim();
    await ref.set(data);

    // Notify all tesoros and admins of the group
    try {
      final snap = await _db
          .collection('grupos')
          .doc(grupoId)
          .collection('miembros')
          .where('rol', whereIn: [
            RolMiembro.tesorero.name,
            RolMiembro.administrador.name,
          ])
          .get();

      final notifRepo = NotificacionRepository();
      for (final doc in snap.docs) {
        if (doc.id == usuarioUid) continue; // no notificar a uno mismo
        await notifRepo.writeNotificacionRol(
          doc.id,
          NotificacionRolModel(
            id: '',
            tipo: 'pago_efectivo_registrado',
            titulo: 'Nuevo pago en efectivo',
            mensaje:
                '$usuarioNombre registró un pago de \$${monto.round()} (cuota)',
            grupoId: grupoId,
            grupoNombre: '',
            leida: false,
            createdAt: DateTime.now(),
          ),
        );
      }
    } catch (_) {}

    return ref.id;
  }

  /// Aprueba o rechaza un pago y notifica al miembro.
  Future<void> confirmarPago({
    required String pagoId,
    required EstadoPago nuevoEstado,
    required String miembroUid,
    required String grupoId,
    required double monto,
  }) async {
    await _db.collection('pagos').doc(pagoId).update({
      'estado': nuevoEstado.name,
      'updatedAt': Timestamp.now(),
    });

    // Notify the member
    try {
      final aprobado = nuevoEstado == EstadoPago.aprobado;
      await NotificacionRepository().writeNotificacionRol(
        miembroUid,
        NotificacionRolModel(
          id: '',
          tipo: aprobado ? 'pago_aprobado' : 'pago_rechazado',
          titulo: aprobado ? '¡Pago aprobado!' : 'Pago rechazado',
          mensaje: aprobado
              ? 'Tu pago de \$${monto.round()} fue confirmado por el tesorero.'
              : 'Tu pago de \$${monto.round()} fue rechazado. Contactá al tesorero.',
          grupoId: grupoId,
          grupoNombre: '',
          leida: false,
          createdAt: DateTime.now(),
        ),
      );
    } catch (_) {}
  }

  Future<String> initPagoManual({
    required String grupoId,
    required String cuotaId,
    required String usuarioUid,
    required String usuarioNombre,
    required double monto,
  }) async {
    final ref = _db.collection('pagos').doc();
    await ref.set({
      'grupoId': grupoId,
      'cuotaId': cuotaId,
      'usuarioUid': usuarioUid,
      'usuarioNombre': usuarioNombre,
      'montoEsperado': monto,
      'estado': EstadoPago.pendiente.name,
      'metodo': MetodoPago.transferencia.name,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });
    return ref.id;
  }
}
