import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/cuota_model.dart';
import '../models/pago_model.dart';
import '../models/enums.dart';

class CuotaDatasource {
  final _db = FirebaseFirestore.instance;

  // ── Cuotas ──────────────────────────────────────────────────────────────────

  Stream<List<CuotaModel>> getCuotas(String grupoId) =>
      _db.collection('grupos').doc(grupoId).collection('cuotas')
          .orderBy('vencimiento', descending: false)
          .snapshots()
          .map((s) => s.docs.map(CuotaModel.fromFirestore).toList());

  Future<String> createCuotaDoc({
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
      'vencimiento': Timestamp.fromDate(finDelDia(vencimiento)),
      'activa': true,
      'esRecurrente': false,
      'createdAt': Timestamp.now(),
      if (miembrosUids != null && miembrosUids.isNotEmpty)
        'miembrosUids': miembrosUids,
      if (excluidosUids != null && excluidosUids.isNotEmpty)
        'excluidosUids': excluidosUids,
    });
    return ref.id;
  }

  Future<String> createCuotasSerie({
    required String grupoId,
    required String serieId,
    required String titulo,
    String? descripcion,
    required double monto,
    required DateTime primerVencimiento,
    required FrecuenciaCuota frecuencia,
    required int totalCuotas,
    List<String>? miembrosUids,
    List<String>? excluidosUids,
  }) async {
    final batch = _db.batch();
    final colRef = _db.collection('grupos').doc(grupoId).collection('cuotas');

    for (int i = 0; i < totalCuotas; i++) {
      final venc = addPeriods(primerVencimiento, frecuencia, i);
      final ref = colRef.doc();
      batch.set(ref, {
        'grupoId': grupoId,
        'titulo': titulo,
        'descripcion': descripcion,
        'monto': monto,
        'vencimiento': Timestamp.fromDate(finDelDia(venc)),
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

  /// El vencimiento se guarda al final del día elegido: una cuota que vence el
  /// 10 se puede pagar todo el 10. Guardarlo a las 00:00 la dejaba vencida
  /// durante su propio día de vencimiento.
  @visibleForTesting
  static DateTime finDelDia(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59);

  @visibleForTesting
  static DateTime addPeriods(DateTime base, FrecuenciaCuota freq, int n) {
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
        return base.add(Duration(days: freq.dias * n));
    }
  }

  Future<CuotaModel?> getCuota(String grupoId, String cuotaId) async {
    final doc = await _db.collection('grupos').doc(grupoId)
        .collection('cuotas').doc(cuotaId).get();
    if (!doc.exists) return null;
    return CuotaModel.fromFirestore(doc);
  }

  Future<void> deleteCuota(String grupoId, String cuotaId) =>
      _db.collection('grupos').doc(grupoId).collection('cuotas')
          .doc(cuotaId).delete();

  Future<void> updateCuotaDoc(
    String grupoId,
    String cuotaId, {
    required String titulo,
    String? descripcion,
    required double monto,
    required DateTime vencimiento,
  }) =>
      _db.collection('grupos').doc(grupoId).collection('cuotas').doc(cuotaId).update({
        'titulo': titulo,
        'descripcion': descripcion,
        'monto': monto,
        'vencimiento': Timestamp.fromDate(finDelDia(vencimiento)),
        'updatedAt': Timestamp.now(),
      });

  Future<void> deleteSerie(String grupoId, String serieId) async {
    final snap = await _db.collection('grupos').doc(grupoId)
        .collection('cuotas').where('serieId', isEqualTo: serieId).get();
    const batchSize = 400;
    for (int i = 0; i < snap.docs.length; i += batchSize) {
      final batch = _db.batch();
      final chunk = snap.docs.sublist(i, (i + batchSize).clamp(0, snap.docs.length));
      for (final d in chunk) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
  }

  // ── Pagos ────────────────────────────────────────────────────────────────────

  Stream<List<PagoModel>> getPagosDeCuota(String grupoId, String cuotaId) =>
      _db.collection('pagos')
          .where('grupoId', isEqualTo: grupoId)
          .where('cuotaId', isEqualTo: cuotaId)
          .snapshots()
          .map((s) => s.docs.map(PagoModel.fromFirestore).toList());

  Stream<PagoModel?> getMiPago(String grupoId, String cuotaId, String uid) =>
      _db.collection('pagos')
          .where('grupoId', isEqualTo: grupoId)
          .where('cuotaId', isEqualTo: cuotaId)
          .where('usuarioUid', isEqualTo: uid)
          .limit(1)
          .snapshots()
          .map((s) => s.docs.isEmpty ? null : PagoModel.fromFirestore(s.docs.first));

  Stream<List<PagoModel>> getPagosDeGrupo(String grupoId) =>
      _db.collection('pagos').where('grupoId', isEqualTo: grupoId)
          .snapshots()
          .map((s) => s.docs.map(PagoModel.fromFirestore).toList());

  Stream<List<PagoModel>> getMisPagosGrupo(String grupoId, String uid) =>
      _db.collection('pagos')
          .where('grupoId', isEqualTo: grupoId)
          .where('usuarioUid', isEqualTo: uid)
          .snapshots()
          .map((s) => s.docs.map(PagoModel.fromFirestore).toList());

  Stream<List<PagoModel>> getMisPagosAprobados(String grupoId, String uid) =>
      _db.collection('pagos')
          .where('grupoId', isEqualTo: grupoId)
          .where('usuarioUid', isEqualTo: uid)
          .where('estado', isEqualTo: EstadoPago.aprobado.name)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((s) => s.docs.map(PagoModel.fromFirestore).toList());

  Future<void> deletePago(String pagoId) =>
      _db.collection('pagos').doc(pagoId).delete();

  Future<void> updatePagoEstadoDoc(String pagoId, EstadoPago estado) =>
      _db.collection('pagos').doc(pagoId).update({
        'estado': estado.name,
        'updatedAt': Timestamp.now(),
      });

  Future<String> createPagoEfectivoDoc({
    required String grupoId,
    required String cuotaId,
    required String usuarioUid,
    required String usuarioNombre,
    required double monto,
    String? nota,
  }) async {
    final ref = _db.collection('pagos').doc();
    final data = <String, dynamic>{
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
    return ref.id;
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

  Future<List<String>> getAdminsTesoreros(
      String grupoId, String excludeUid) async {
    final snap = await _db.collection('grupos').doc(grupoId)
        .collection('miembros')
        .where('rol', whereIn: [
          RolMiembro.tesorero.name,
          RolMiembro.administrador.name,
        ]).get();
    return snap.docs
        .map((d) => d.id)
        .where((id) => id != excludeUid)
        .toList();
  }

  Future<void> uploadComprobante({
    required String pagoId,
    required String grupoId,
    required Uint8List bytes,
    String? bancoOrigen,
    String? nroOperacion,
    String? mensajeAlTesorero,
  }) async {
    final storageRef = FirebaseStorage.instance
        .ref('grupos/$grupoId/comprobantes/$pagoId.jpg');
    await storageRef.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    final url = await storageRef.getDownloadURL();

    final extra = <String, dynamic>{
      'comprobanteUrl': url,
      'estado': EstadoPago.validando.name,
      'updatedAt': Timestamp.now(),
    };
    if (bancoOrigen != null && bancoOrigen.isNotEmpty) {
      extra['bancoOrigen'] = bancoOrigen;
    }
    if (nroOperacion != null && nroOperacion.isNotEmpty) {
      extra['nroOperacion'] = nroOperacion;
    }
    if (mensajeAlTesorero != null && mensajeAlTesorero.isNotEmpty) {
      extra['mensajeAlTesorero'] = mensajeAlTesorero;
    }
    await _db.collection('pagos').doc(pagoId).update(extra);
  }
}
