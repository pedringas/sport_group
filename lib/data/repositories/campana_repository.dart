import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/campana_model.dart';
import '../models/enums.dart';
import '../models/notificacion_rol_model.dart';
import 'notificacion_repository.dart';

class CampanaRepository {
  final _db = FirebaseFirestore.instance;

  // ── Campañas ──────────────────────────────────────────────────────────────

  Stream<List<CampanaModel>> getCampanas(String grupoId) {
    return _db
        .collection('grupos')
        .doc(grupoId)
        .collection('campanas')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(CampanaModel.fromFirestore).toList());
  }

  Future<CampanaModel?> getCampana(String grupoId, String campanaId) async {
    final doc = await _db
        .collection('grupos')
        .doc(grupoId)
        .collection('campanas')
        .doc(campanaId)
        .get();
    if (!doc.exists) return null;
    return CampanaModel.fromFirestore(doc);
  }

  Stream<CampanaModel?> watchCampana(String grupoId, String campanaId) {
    return _db
        .collection('grupos')
        .doc(grupoId)
        .collection('campanas')
        .doc(campanaId)
        .snapshots()
        .map((doc) => doc.exists ? CampanaModel.fromFirestore(doc) : null);
  }

  Future<String> createCampana({
    required String grupoId,
    required String titulo,
    String? descripcion,
    required double objetivo,
    DateTime? fechaLimite,
    String? imagenUrl,
    required String creadoPor,
  }) async {
    final ref = _db
        .collection('grupos')
        .doc(grupoId)
        .collection('campanas')
        .doc();
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

  Future<void> updateEstado(String grupoId, String campanaId, EstadoCampana estado) async {
    await _db
        .collection('grupos')
        .doc(grupoId)
        .collection('campanas')
        .doc(campanaId)
        .update({'estado': estado.name});
  }

  // ── Aportes ───────────────────────────────────────────────────────────────

  Stream<List<AporteModel>> getAportes(String grupoId, String campanaId) {
    return _db
        .collection('grupos')
        .doc(grupoId)
        .collection('campanas')
        .doc(campanaId)
        .collection('aportes')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(AporteModel.fromFirestore).toList());
  }

  /// All aportes by a user in a group, across all campañas (for Caja — egresos).
  /// Uses a collection group query on 'aportes' filtered by grupoId + uid.
  Stream<List<AporteModel>> getMisAportesGrupo(String grupoId, String uid) {
    return _db
        .collectionGroup('aportes')
        .where('grupoId', isEqualTo: grupoId)
        .where('usuarioUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(AporteModel.fromFirestore).toList());
  }

  /// Adds an aporte and atomically updates montoActual on the campaign.
  Future<String> addAporte({
    required String grupoId,
    required String campanaId,
    required String usuarioUid,
    required String usuarioNombre,
    required double monto,
    String? mensaje,
  }) async {
    final campanaRef = _db
        .collection('grupos')
        .doc(grupoId)
        .collection('campanas')
        .doc(campanaId);

    final aporteRef = campanaRef.collection('aportes').doc();

    await _db.runTransaction((tx) async {
      final snap = await tx.get(campanaRef);
      if (!snap.exists) throw Exception('Campaña no encontrada');

      final actual = (snap.data()!['montoActual'] as num? ?? 0).toDouble();
      final objetivo = (snap.data()!['objetivo'] as num).toDouble();
      final nuevo = actual + monto;

      tx.set(aporteRef, {
        'campanaId': campanaId,
        'grupoId': grupoId,
        'usuarioUid': usuarioUid,
        'usuarioNombre': usuarioNombre,
        'monto': monto,
        'mensaje': mensaje,
        'comprobanteUrl': null,
        'estado': EstadoAporte.aprobado.name, // auto-approved
        'createdAt': Timestamp.now(),
      });

      tx.update(campanaRef, {
        'montoActual': nuevo,
        if (nuevo >= objetivo) 'estado': EstadoCampana.completada.name,
      });
    });

    return aporteRef.id;
  }

  /// Creates an aporte as [pendiente] without updating montoActual.
  /// Used for efectivo (cash) contributions that need tesorero/admin confirmation.
  Future<String> addAportePendiente({
    required String grupoId,
    required String campanaId,
    required String usuarioUid,
    required String usuarioNombre,
    required double monto,
    String? mensaje,
    String metodo = 'efectivo',
  }) async {
    final campanaRef = _db
        .collection('grupos')
        .doc(grupoId)
        .collection('campanas')
        .doc(campanaId);
    final aporteRef = campanaRef.collection('aportes').doc();

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

    // Notify admins and tesoros
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
        if (doc.id == usuarioUid) continue;
        await notifRepo.writeNotificacionRol(
          doc.id,
          NotificacionRolModel(
            id: '',
            tipo: 'aporte_pendiente',
            titulo: 'Nuevo aporte pendiente',
            mensaje:
                '$usuarioNombre registró un aporte de \$${monto.round()} (${metodo == 'efectivo' ? 'efectivo' : 'transferencia'})',
            grupoId: grupoId,
            grupoNombre: '',
            leida: false,
            createdAt: DateTime.now(),
          ),
        );
      }
    } catch (_) {}

    return aporteRef.id;
  }

  /// Approves a pending aporte and atomically updates montoActual.
  Future<void> aprobarAporte({
    required String grupoId,
    required String campanaId,
    required String aporteId,
    required String miembroUid,
    required double monto,
  }) async {
    final campanaRef = _db
        .collection('grupos')
        .doc(grupoId)
        .collection('campanas')
        .doc(campanaId);
    final aporteRef = campanaRef.collection('aportes').doc(aporteId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(campanaRef);
      if (!snap.exists) throw Exception('Campaña no encontrada');
      final actual = (snap.data()!['montoActual'] as num? ?? 0).toDouble();
      final objetivo = (snap.data()!['objetivo'] as num).toDouble();
      final nuevo = actual + monto;

      tx.update(aporteRef, {'estado': EstadoAporte.aprobado.name});
      tx.update(campanaRef, {
        'montoActual': nuevo,
        if (nuevo >= objetivo) 'estado': EstadoCampana.completada.name,
      });
    });

    // Notify member
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
    } catch (_) {}
  }

  /// Rejects a pending aporte (does not update montoActual).
  Future<void> rechazarAporte({
    required String grupoId,
    required String campanaId,
    required String aporteId,
    required String miembroUid,
    required double monto,
  }) async {
    final aporteRef = _db
        .collection('grupos')
        .doc(grupoId)
        .collection('campanas')
        .doc(campanaId)
        .collection('aportes')
        .doc(aporteId);
    await aporteRef.update({'estado': EstadoAporte.rechazado.name});

    // Notify member
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
    } catch (_) {}
  }

  Future<void> deleteAporte({
    required String grupoId,
    required String campanaId,
    required String aporteId,
    required double monto,
  }) async {
    final campanaRef = _db
        .collection('grupos')
        .doc(grupoId)
        .collection('campanas')
        .doc(campanaId);
    final aporteRef = campanaRef.collection('aportes').doc(aporteId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(campanaRef);
      final actual = (snap.data()!['montoActual'] as num? ?? 0).toDouble();
      tx.delete(aporteRef);
      tx.update(campanaRef, {
        'montoActual': (actual - monto).clamp(0.0, double.infinity),
        'estado': EstadoCampana.activa.name,
      });
    });
  }
}
