import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/campana_model.dart';
import '../models/enums.dart';

class CampanaDatasource {
  final _db = FirebaseFirestore.instance;

  CollectionReference _campanas(String grupoId) =>
      _db.collection('grupos').doc(grupoId).collection('campanas');

  // ── Campañas ──────────────────────────────────────────────────────────────

  Stream<List<CampanaModel>> getCampanas(String grupoId) =>
      _campanas(grupoId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((s) => s.docs.map(CampanaModel.fromFirestore).toList());

  Future<CampanaModel?> getCampana(String grupoId, String campanaId) async {
    final doc = await _campanas(grupoId).doc(campanaId).get();
    if (!doc.exists) return null;
    return CampanaModel.fromFirestore(doc);
  }

  Stream<CampanaModel?> watchCampana(String grupoId, String campanaId) =>
      _campanas(grupoId).doc(campanaId).snapshots().map(
          (doc) => doc.exists ? CampanaModel.fromFirestore(doc) : null);

  Future<String> createCampana({
    required String grupoId,
    required String titulo,
    String? descripcion,
    required double objetivo,
    DateTime? fechaLimite,
    String? imagenUrl,
    required String creadoPor,
  }) async {
    final ref = _campanas(grupoId).doc();
    await ref.set({
      'grupoId': grupoId,
      'titulo': titulo,
      'descripcion': descripcion,
      'objetivo': objetivo,
      'montoActual': 0.0,
      'estado': EstadoCampana.activa.name,
      if (fechaLimite != null) 'fechaLimite': Timestamp.fromDate(fechaLimite),
      'imagenUrl': imagenUrl,
      'creadoPor': creadoPor,
      'createdAt': Timestamp.now(),
    });
    return ref.id;
  }

  Future<void> updateEstado(
          String grupoId, String campanaId, EstadoCampana estado) =>
      _campanas(grupoId)
          .doc(campanaId)
          .update({'estado': estado.name});

  // ── Aportes ───────────────────────────────────────────────────────────────

  Stream<List<AporteModel>> getAportes(String grupoId, String campanaId) =>
      _campanas(grupoId)
          .doc(campanaId)
          .collection('aportes')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((s) => s.docs.map(AporteModel.fromFirestore).toList());

  Stream<List<AporteModel>> getMisAportesGrupo(String grupoId, String uid) =>
      _db
          .collectionGroup('aportes')
          .where('grupoId', isEqualTo: grupoId)
          .where('usuarioUid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((s) => s.docs.map(AporteModel.fromFirestore).toList());

  /// Adds an approved aporte and atomically updates montoActual.
  Future<String> addAporte({
    required String grupoId,
    required String campanaId,
    required String usuarioUid,
    required String usuarioNombre,
    required double monto,
    String? mensaje,
  }) async {
    final campanaRef = _campanas(grupoId).doc(campanaId);
    final aporteRef = campanaRef.collection('aportes').doc();

    await _db.runTransaction((tx) async {
      final snap = await tx.get(campanaRef);
      if (!snap.exists) throw Exception('Campaña no encontrada');
      final actual = (snap.data()! as Map)['montoActual'] as num? ?? 0;
      final objetivo = (snap.data()! as Map)['objetivo'] as num;
      final nuevo = actual + monto;

      tx.set(aporteRef, {
        'campanaId': campanaId,
        'grupoId': grupoId,
        'usuarioUid': usuarioUid,
        'usuarioNombre': usuarioNombre,
        'monto': monto,
        'mensaje': mensaje,
        'comprobanteUrl': null,
        'estado': EstadoAporte.aprobado.name,
        'createdAt': Timestamp.now(),
      });
      tx.update(campanaRef, {
        'montoActual': nuevo,
        if (nuevo >= objetivo) 'estado': EstadoCampana.completada.name,
      });
    });

    return aporteRef.id;
  }

  /// Creates a pending aporte without updating montoActual.
  /// Returns the new aporteId; the caller handles notifications.
  Future<String> addAportePendienteDoc({
    required String grupoId,
    required String campanaId,
    required String usuarioUid,
    required String usuarioNombre,
    required double monto,
    String? mensaje,
    String metodo = 'efectivo',
  }) async {
    final aporteRef =
        _campanas(grupoId).doc(campanaId).collection('aportes').doc();
    await aporteRef.set({
      'campanaId': campanaId,
      'grupoId': grupoId,
      'usuarioUid': usuarioUid,
      'usuarioNombre': usuarioNombre,
      'monto': monto,
      'montoDeclarado': monto,
      'mensaje': mensaje,
      'comprobanteUrl': null,
      'estado': EstadoAporte.pendiente.name,
      'metodo': metodo,
      'createdAt': Timestamp.now(),
    });
    return aporteRef.id;
  }

  /// Returns UIDs of admins and tesoreros (excluding [excludeUid]).
  Future<List<String>> getAdminsTesoreros(
      String grupoId, String excludeUid) async {
    final snap = await _db
        .collection('grupos')
        .doc(grupoId)
        .collection('miembros')
        .where('rol', whereIn: [
          RolMiembro.tesorero.name,
          RolMiembro.administrador.name,
        ])
        .get();
    return snap.docs
        .map((d) => d.id)
        .where((id) => id != excludeUid)
        .toList();
  }

  /// Approves a pending aporte and atomically updates montoActual.
  Future<void> aprobarAporteDoc({
    required String grupoId,
    required String campanaId,
    required String aporteId,
    required double monto,
  }) async {
    final campanaRef = _campanas(grupoId).doc(campanaId);
    final aporteRef = campanaRef.collection('aportes').doc(aporteId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(campanaRef);
      if (!snap.exists) throw Exception('Campaña no encontrada');
      final actual = (snap.data()! as Map)['montoActual'] as num? ?? 0;
      final objetivo = (snap.data()! as Map)['objetivo'] as num;
      final nuevo = actual + monto;

      tx.update(aporteRef, {'estado': EstadoAporte.aprobado.name});
      tx.update(campanaRef, {
        'montoActual': nuevo,
        if (nuevo >= objetivo) 'estado': EstadoCampana.completada.name,
      });
    });
  }

  /// Marks a pending aporte as rejected.
  Future<void> rechazarAporteDoc(
          String grupoId, String campanaId, String aporteId) =>
      _campanas(grupoId)
          .doc(campanaId)
          .collection('aportes')
          .doc(aporteId)
          .update({'estado': EstadoAporte.rechazado.name});

  Future<void> deleteAporte({
    required String grupoId,
    required String campanaId,
    required String aporteId,
    required double monto,
  }) async {
    final campanaRef = _campanas(grupoId).doc(campanaId);
    final aporteRef = campanaRef.collection('aportes').doc(aporteId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(campanaRef);
      final actual = (snap.data()! as Map)['montoActual'] as num? ?? 0;
      tx.delete(aporteRef);
      tx.update(campanaRef, {
        'montoActual': ((actual - monto).toDouble()).clamp(0.0, double.infinity),
        'estado': EstadoCampana.activa.name,
      });
    });
  }
}
