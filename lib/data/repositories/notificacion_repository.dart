import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/actividad_model.dart';
import '../models/notificacion_rol_model.dart';

class NotificacionRepository {
  final _db = FirebaseFirestore.instance;

  // ── Write helpers ─────────────────────────────────────────────────────────

  Future<void> writeActividad(String grupoId, ActividadModel a) async {
    await _db
        .collection('grupos')
        .doc(grupoId)
        .collection('actividad')
        .add(a.toMap());
  }

  Future<void> writeNotificacionRol(
      String uid, NotificacionRolModel n) async {
    await _db
        .collection('usuarios')
        .doc(uid)
        .collection('notificaciones')
        .add(n.toMap());
  }

  Future<void> marcarLeida(String uid, String notifId) async {
    await _db
        .collection('usuarios')
        .doc(uid)
        .collection('notificaciones')
        .doc(notifId)
        .update({'leida': true});
  }

  Future<void> marcarTodasLeidas(String uid) async {
    final snap = await _db
        .collection('usuarios')
        .doc(uid)
        .collection('notificaciones')
        .where('leida', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'leida': true});
    }
    await batch.commit();
  }

  // ── Read streams ──────────────────────────────────────────────────────────

  /// Recent actividad for a single group, newest first.
  Stream<List<ActividadModel>> getActividad(String grupoId) {
    return _db
        .collection('grupos')
        .doc(grupoId)
        .collection('actividad')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map(ActividadModel.fromFirestore).toList());
  }

  /// One-shot fetch of actividad (used for multi-group merge).
  Future<List<ActividadModel>> getActividadOnce(String grupoId) async {
    final snap = await _db
        .collection('grupos')
        .doc(grupoId)
        .collection('actividad')
        .orderBy('createdAt', descending: true)
        .limit(30)
        .get();
    return snap.docs.map(ActividadModel.fromFirestore).toList();
  }

  /// Rol notifications for a user.
  Stream<List<NotificacionRolModel>> getNotificacionesRol(String uid) {
    return _db
        .collection('usuarios')
        .doc(uid)
        .collection('notificaciones')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((s) =>
            s.docs.map(NotificacionRolModel.fromFirestore).toList());
  }

  /// Unread rol notifications count.
  Stream<int> getUnreadCount(String uid) {
    return _db
        .collection('usuarios')
        .doc(uid)
        .collection('notificaciones')
        .where('leida', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }
}
