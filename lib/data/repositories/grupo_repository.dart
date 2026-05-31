import 'dart:math';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/grupo_model.dart';
import '../models/miembro_model.dart';
import '../models/solicitud_union_model.dart';
import '../models/enums.dart';
import '../models/actividad_model.dart';
import '../models/notificacion_rol_model.dart';
import 'notificacion_repository.dart';

class GrupoRepository {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  static String _generarCodigo() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I to avoid confusion
    final rng = Random.secure();
    return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  Map<String, dynamic> _miembroData({
    required String grupoId,
    required String uid,
    required String nombreCompleto,
    String? avatarUrl,
    required RolMiembro rol,
    required EstadoMiembro estado,
  }) =>
      {
        'uid': uid,
        'grupoId': grupoId,
        'nombreCompleto': nombreCompleto,
        'avatarUrl': avatarUrl,
        'rol': rol.name,
        'estado': estado.name,
        'joinedAt': Timestamp.now(),
      };

  Future<String> createGrupo(
    GrupoModel grupo, {
    required String adminNombreCompleto,
    String? adminAvatarUrl,
  }) async {
    final ref = _db.collection('grupos').doc();
    final model = GrupoModel(
      id: ref.id,
      nombre: grupo.nombre,
      descripcion: grupo.descripcion,
      logoUrl: grupo.logoUrl,
      tipo: grupo.tipo,
      adminUid: grupo.adminUid,
      miembrosCount: 1,
      createdAt: DateTime.now(),
      codigoAcceso: _generarCodigo(),
    );
    final batch = _db.batch();
    batch.set(ref, model.toMap());
    batch.set(
      ref.collection('miembros').doc(grupo.adminUid),
      _miembroData(
        grupoId: ref.id,
        uid: grupo.adminUid,
        nombreCompleto: adminNombreCompleto,
        avatarUrl: adminAvatarUrl,
        rol: RolMiembro.administrador,
        estado: EstadoMiembro.activo,
      ),
    );
    await batch.commit();
    return ref.id;
  }

  /// Upload logo from bytes — works on both mobile and web.
  Future<String?> uploadLogo(String grupoId, Uint8List bytes) async {
    final ref = _storage.ref('grupos/$grupoId/logo.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  /// Upload full-width cover/banner image.
  Future<String?> uploadPortada(String grupoId, Uint8List bytes) async {
    final ref = _storage.ref('grupos/$grupoId/portada.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  Future<void> updateGrupo(String grupoId, Map<String, dynamic> data) async {
    await _db.collection('grupos').doc(grupoId).update(data);
  }

  Stream<List<GrupoModel>> getUserGrupos(String uid) {
    return _db
        .collectionGroup('miembros')
        .where('uid', isEqualTo: uid)
        .where('estado', isEqualTo: EstadoMiembro.activo.name)
        .snapshots()
        .asyncMap((snap) async {
      final grupoIds =
          snap.docs.map((d) => d.data()['grupoId'] as String).toList();
      if (grupoIds.isEmpty) return [];
      final futures =
          grupoIds.map((id) => _db.collection('grupos').doc(id).get());
      final docs = await Future.wait(futures);
      return docs.where((d) => d.exists).map(GrupoModel.fromFirestore).toList();
    });
  }

  /// Search only PUBLIC groups by name prefix, case-insensitive.
  /// Private groups are not discoverable by name — only by invite code.
  /// Requires composite index: tipo ASC + nombre ASC (add in Firebase Console).
  Future<List<GrupoModel>> searchGrupos(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    // Run two prefix queries: one lowercase, one title-case first letter.
    // Merge and deduplicate so both "futbol" and "Futbol" surface.
    const endChar = ''; // last Private Use Area char — safe suffix

    final lower = q.toLowerCase();
    final upper = q[0].toUpperCase() + (q.length > 1 ? q.substring(1) : '');

    Future<List<GrupoModel>> prefixQuery(String prefix) async {
      final snap = await _db
          .collection('grupos')
          .where('tipo', isEqualTo: 'publico')
          .orderBy('nombre')
          .startAt([prefix])
          .endAt(['$prefix$endChar'])
          .limit(20)
          .get();
      return snap.docs.map(GrupoModel.fromFirestore).toList();
    }

    final results = await Future.wait([prefixQuery(lower), prefixQuery(upper)]);
    final seen = <String>{};
    return [...results[0], ...results[1]]
        .where((g) => seen.add(g.id))
        .toList();
  }

  Future<List<GrupoModel>> searchPublicGrupos(String query) => searchGrupos(query);

  /// Find a group by its invite code. Works for both public and private groups.
  Future<GrupoModel?> searchGrupoByCodigo(String codigo) async {
    final snap = await _db
        .collection('grupos')
        .where('codigoAcceso', isEqualTo: codigo.trim().toUpperCase())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return GrupoModel.fromFirestore(snap.docs.first);
  }

  Future<GrupoModel?> getGrupo(String grupoId) async {
    final doc = await _db.collection('grupos').doc(grupoId).get();
    if (!doc.exists) return null;
    return GrupoModel.fromFirestore(doc);
  }

  /// Live stream of a single group document (auto-updates on changes).
  Stream<GrupoModel?> getGrupoStream(String grupoId) {
    return _db.collection('grupos').doc(grupoId).snapshots().map(
      (doc) => doc.exists ? GrupoModel.fromFirestore(doc) : null,
    );
  }

  /// Live stream of a single member (auto-updates on role/status changes).
  Stream<MiembroModel?> getMiembroStream(String grupoId, String uid) {
    return _db
        .collection('grupos')
        .doc(grupoId)
        .collection('miembros')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? MiembroModel.fromFirestore(doc) : null);
  }

  Future<void> joinGrupo(
      String grupoId, String uid, String nombreCompleto, String? avatarUrl) async {
    final batch = _db.batch();
    batch.set(
      _db.collection('grupos').doc(grupoId).collection('miembros').doc(uid),
      _miembroData(
        grupoId: grupoId,
        uid: uid,
        nombreCompleto: nombreCompleto,
        avatarUrl: avatarUrl,
        rol: RolMiembro.miembro,
        estado: EstadoMiembro.activo,
      ),
    );
    batch.update(_db.collection('grupos').doc(grupoId), {
      'miembrosCount': FieldValue.increment(1),
    });
    await batch.commit();

    // Fire-and-forget group activity
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
    } catch (_) {}
  }

  Future<void> requestJoinGrupo(
      String grupoId, String uid, String nombreCompleto, String? avatarUrl) async {
    await _db
        .collection('grupos')
        .doc(grupoId)
        .collection('solicitudes')
        .doc(uid)
        .set({
      'grupoId': grupoId,
      'usuarioUid': uid,
      'usuarioNombre': nombreCompleto,
      'usuarioAvatar': avatarUrl,
      'estado': EstadoSolicitud.pendiente.name,
      'createdAt': Timestamp.now(),
    });
  }

  Future<void> responderSolicitud(String grupoId, String uid, bool aprobar,
      String nombreCompleto, String? avatarUrl) async {
    final batch = _db.batch();
    final solicitudRef = _db
        .collection('grupos')
        .doc(grupoId)
        .collection('solicitudes')
        .doc(uid);
    batch.update(solicitudRef, {
      'estado': aprobar
          ? EstadoSolicitud.aprobado.name
          : EstadoSolicitud.rechazado.name,
    });
    if (aprobar) {
      batch.set(
        _db.collection('grupos').doc(grupoId).collection('miembros').doc(uid),
        _miembroData(
          grupoId: grupoId,
          uid: uid,
          nombreCompleto: nombreCompleto,
          avatarUrl: avatarUrl,
          rol: RolMiembro.miembro,
          estado: EstadoMiembro.activo,
        ),
      );
      batch.update(_db.collection('grupos').doc(grupoId), {
        'miembrosCount': FieldValue.increment(1),
      });
    }
    await batch.commit();

    // Fire-and-forget: write activity when member is approved
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
      } catch (_) {}
    }
  }

  Stream<List<MiembroModel>> getMiembros(String grupoId) {
    return _db
        .collection('grupos')
        .doc(grupoId)
        .collection('miembros')
        .where('estado', isEqualTo: EstadoMiembro.activo.name)
        .snapshots()
        .map((s) => s.docs.map(MiembroModel.fromFirestore).toList());
  }

  Future<MiembroModel?> getMiembro(String grupoId, String uid) async {
    final doc = await _db
        .collection('grupos')
        .doc(grupoId)
        .collection('miembros')
        .doc(uid)
        .get();
    if (!doc.exists) return null;
    return MiembroModel.fromFirestore(doc);
  }

  Future<void> updateRolMiembro(
    String grupoId,
    String uid,
    RolMiembro rol, {
    String nombreMiembro = '',
    String grupoNombre = '',
  }) async {
    await _db
        .collection('grupos')
        .doc(grupoId)
        .collection('miembros')
        .doc(uid)
        .update({'rol': rol.name});

    // Fire-and-forget: notify the member about their new role (if relevant)
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
        } catch (_) {}
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

  /// Toggle the esFavorito flag for the current user's membership in a group.
  Future<void> setFavorito(String grupoId, String uid, bool value) async {
    await _db
        .collection('grupos')
        .doc(grupoId)
        .collection('miembros')
        .doc(uid)
        .update({'esFavorito': value});
  }

  /// Current user leaves the group.
  Future<void> leaveGrupo(String grupoId, String uid) async {
    final batch = _db.batch();
    batch.delete(_db
        .collection('grupos')
        .doc(grupoId)
        .collection('miembros')
        .doc(uid));
    batch.update(_db.collection('grupos').doc(grupoId), {
      'miembrosCount': FieldValue.increment(-1),
    });
    await batch.commit();
  }

  /// Admin: deletes the group and its miembros sub-collection.
  Future<void> deleteGrupo(String grupoId) async {
    // 1. Delete all miembros (to revoke access immediately)
    final miembrosSnap = await _db
        .collection('grupos')
        .doc(grupoId)
        .collection('miembros')
        .get();
    const batchSize = 400;
    for (int i = 0; i < miembrosSnap.docs.length; i += batchSize) {
      final batch = _db.batch();
      final chunk = miembrosSnap.docs
          .sublist(i, (i + batchSize).clamp(0, miembrosSnap.docs.length));
      for (final d in chunk) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
    // 2. Delete the group document itself
    await _db.collection('grupos').doc(grupoId).delete();
  }

  /// Returns the current user's join request for a group (null if none).
  Future<SolicitudUnionModel?> getMiSolicitud(String grupoId, String uid) async {
    final doc = await _db
        .collection('grupos')
        .doc(grupoId)
        .collection('solicitudes')
        .doc(uid)
        .get();
    if (!doc.exists) return null;
    return SolicitudUnionModel.fromFirestore(doc);
  }

  Stream<List<SolicitudUnionModel>> getSolicitudesPendientes(String grupoId) {
    return _db
        .collection('grupos')
        .doc(grupoId)
        .collection('solicitudes')
        .where('estado', isEqualTo: EstadoSolicitud.pendiente.name)
        .snapshots()
        .map((s) => s.docs.map(SolicitudUnionModel.fromFirestore).toList());
  }
}
