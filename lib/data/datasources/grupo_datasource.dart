import 'dart:math';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/grupo_model.dart';
import '../models/miembro_model.dart';
import '../models/solicitud_union_model.dart';
import '../models/enums.dart';

class GrupoDatasource {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  GrupoDatasource([FirebaseFirestore? db, FirebaseStorage? storage])
      : _db = db ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  static String _generarCodigo() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
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

  /// App de grupo único: garantiza que el grupo [grupoId] exista y que [uid]
  /// sea miembro. Si el grupo no existe, lo crea y deja a [uid] como
  /// administrador (primer usuario = admin). Si existe y el usuario no es
  /// miembro, lo agrega como miembro (auto-ingreso). Idempotente.
  ///
  /// Nota sobre las reglas de Firestore: SEC-01 obliga `rol == 'miembro'` al
  /// auto-crear la membresía (anti-escalada), así que el creador se crea primero
  /// como miembro y luego se auto-promueve a administrador vía update (permitido
  /// por `isSelf`). No requiere cambios en `firestore.rules`.
  Future<void> ensureMembership(
    String grupoId, {
    required String uid,
    required String nombreCompleto,
    String? avatarUrl,
    required String grupoNombre,
  }) async {
    final grupoRef = _db.collection('grupos').doc(grupoId);
    final miembroRef = grupoRef.collection('miembros').doc(uid);

    final grupoSnap = await grupoRef.get();
    if (!grupoSnap.exists) {
      // Primer usuario: crea el grupo y queda como administrador.
      final model = GrupoModel(
        id: grupoId,
        nombre: grupoNombre,
        tipo: TipoGrupo.privado,
        adminUid: uid,
        miembrosCount: 1,
        createdAt: DateTime.now(),
        codigoAcceso: _generarCodigo(),
      );
      await grupoRef.set(model.toMap());
      await miembroRef.set(_miembroData(
        grupoId: grupoId,
        uid: uid,
        nombreCompleto: nombreCompleto,
        avatarUrl: avatarUrl,
        rol: RolMiembro.miembro,
        estado: EstadoMiembro.activo,
      ));
      await miembroRef.update({'rol': RolMiembro.administrador.name});
      return;
    }

    final miembroSnap = await miembroRef.get();
    if (!miembroSnap.exists) {
      // Auto-ingreso: se suma como miembro.
      await miembroRef.set(_miembroData(
        grupoId: grupoId,
        uid: uid,
        nombreCompleto: nombreCompleto,
        avatarUrl: avatarUrl,
        rol: RolMiembro.miembro,
        estado: EstadoMiembro.activo,
      ));
      await grupoRef.update({'miembrosCount': FieldValue.increment(1)});
    }
  }

  Future<String?> uploadLogo(String grupoId, Uint8List bytes) async {
    final ref = _storage.ref('grupos/$grupoId/logo.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  Future<String?> uploadPortada(String grupoId, Uint8List bytes) async {
    final ref = _storage.ref('grupos/$grupoId/portada.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  Future<void> updateGrupo(String grupoId, Map<String, dynamic> data) =>
      _db.collection('grupos').doc(grupoId).update(data);

  Stream<List<GrupoModel>> getUserGrupos(String uid) =>
      _db.collectionGroup('miembros')
          .where('uid', isEqualTo: uid)
          .where('estado', isEqualTo: EstadoMiembro.activo.name)
          .snapshots()
          .asyncMap((snap) async {
        final grupoIds =
            snap.docs.map((d) => d.data()['grupoId'] as String).toList();
        if (grupoIds.isEmpty) return [];
        final docs = await Future.wait(
            grupoIds.map((id) => _db.collection('grupos').doc(id).get()));
        return docs.where((d) => d.exists).map(GrupoModel.fromFirestore).toList();
      });

  Future<List<GrupoModel>> searchGrupos(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    const endChar = '';
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
    return [...results[0], ...results[1]].where((g) => seen.add(g.id)).toList();
  }

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

  Stream<GrupoModel?> getGrupoStream(String grupoId) =>
      _db.collection('grupos').doc(grupoId).snapshots().map(
          (doc) => doc.exists ? GrupoModel.fromFirestore(doc) : null);

  Stream<MiembroModel?> getMiembroStream(String grupoId, String uid) =>
      _db.collection('grupos').doc(grupoId).collection('miembros')
          .doc(uid)
          .snapshots()
          .map((doc) => doc.exists ? MiembroModel.fromFirestore(doc) : null);

  Future<void> joinGrupo(String grupoId, String uid, String nombreCompleto,
      String? avatarUrl) async {
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
  }

  Future<void> requestJoinGrupo(String grupoId, String uid,
      String nombreCompleto, String? avatarUrl) =>
      _db.collection('grupos').doc(grupoId).collection('solicitudes')
          .doc(uid)
          .set({
        'grupoId': grupoId,
        'usuarioUid': uid,
        'usuarioNombre': nombreCompleto,
        'usuarioAvatar': avatarUrl,
        'estado': EstadoSolicitud.pendiente.name,
        'createdAt': Timestamp.now(),
      });

  Future<void> responderSolicitudDoc(String grupoId, String uid, bool aprobar,
      String nombreCompleto, String? avatarUrl) async {
    final batch = _db.batch();
    final solicitudRef = _db.collection('grupos').doc(grupoId)
        .collection('solicitudes').doc(uid);
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
  }

  Stream<List<MiembroModel>> getMiembros(String grupoId) =>
      _db.collection('grupos').doc(grupoId).collection('miembros')
          .where('estado', isEqualTo: EstadoMiembro.activo.name)
          .snapshots()
          .map((s) => s.docs.map(MiembroModel.fromFirestore).toList());

  Future<MiembroModel?> getMiembro(String grupoId, String uid) async {
    final doc = await _db.collection('grupos').doc(grupoId)
        .collection('miembros').doc(uid).get();
    if (!doc.exists) return null;
    return MiembroModel.fromFirestore(doc);
  }

  Future<void> updateRolDoc(String grupoId, String uid, RolMiembro rol) =>
      _db.collection('grupos').doc(grupoId).collection('miembros')
          .doc(uid).update({'rol': rol.name});

  Future<void> setFavorito(String grupoId, String uid, bool value) =>
      _db.collection('grupos').doc(grupoId).collection('miembros')
          .doc(uid).update({'esFavorito': value});

  Future<void> leaveGrupo(String grupoId, String uid) async {
    final batch = _db.batch();
    batch.delete(_db.collection('grupos').doc(grupoId)
        .collection('miembros').doc(uid));
    batch.update(_db.collection('grupos').doc(grupoId), {
      'miembrosCount': FieldValue.increment(-1),
    });
    await batch.commit();
  }

  Future<void> deleteGrupo(String grupoId) async {
    final miembrosSnap = await _db.collection('grupos').doc(grupoId)
        .collection('miembros').get();
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
    await _db.collection('grupos').doc(grupoId).delete();
  }

  Future<SolicitudUnionModel?> getMiSolicitud(
      String grupoId, String uid) async {
    final doc = await _db.collection('grupos').doc(grupoId)
        .collection('solicitudes').doc(uid).get();
    if (!doc.exists) return null;
    return SolicitudUnionModel.fromFirestore(doc);
  }

  Stream<List<SolicitudUnionModel>> getSolicitudesPendientes(String grupoId) =>
      _db.collection('grupos').doc(grupoId).collection('solicitudes')
          .where('estado', isEqualTo: EstadoSolicitud.pendiente.name)
          .snapshots()
          .map((s) => s.docs.map(SolicitudUnionModel.fromFirestore).toList());
}
