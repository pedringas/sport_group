// TEST-08: createGrupo batch — both documents created atomically
// TEST-12: deleteGrupo cascade — miembros subcollection deleted before grupo
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sports_groups_app/data/datasources/grupo_datasource.dart';
import 'package:sports_groups_app/data/models/enums.dart';
import 'package:sports_groups_app/data/models/grupo_model.dart';

class MockFirebaseStorage extends Mock implements FirebaseStorage {}

/// Returns a [GrupoDatasource] backed by the fake Firestore.
/// Storage is mocked because these tests don't exercise upload methods.
GrupoDatasource _ds(FakeFirebaseFirestore db) =>
    GrupoDatasource(db, MockFirebaseStorage());

GrupoModel _grupoTemplate({String adminUid = 'admin-uid'}) => GrupoModel(
      id: '',
      nombre: 'Los Amigos FC',
      descripcion: 'Grupo de futbol',
      tipo: TipoGrupo.publico,
      adminUid: adminUid,
      miembrosCount: 0,
      createdAt: DateTime(2025),
      codigoAcceso: '',
    );

void main() {
  // ── TEST-08: createGrupo batch atomicity ─────────────────────────────────────

  group('GrupoDatasource.createGrupo — batch write', () {
    test('creates grupo document with correct fields', () async {
      final db = FakeFirebaseFirestore();
      final ds = _ds(db);

      final grupoId = await ds.createGrupo(
        _grupoTemplate(adminUid: 'u1'),
        adminNombreCompleto: 'Ana García',
        adminAvatarUrl: 'https://example.com/avatar.jpg',
      );

      final doc = await db.collection('grupos').doc(grupoId).get();
      expect(doc.exists, isTrue, reason: 'grupo document must exist after create');
      expect(doc.data()!['nombre'], 'Los Amigos FC');
      expect(doc.data()!['adminUid'], 'u1');
      expect(doc.data()!['miembrosCount'], 1);
      expect(doc.data()!['tipo'], 'publico');
    });

    test('creates admin miembro in subcollection atomically', () async {
      final db = FakeFirebaseFirestore();
      final ds = _ds(db);

      final grupoId = await ds.createGrupo(
        _grupoTemplate(adminUid: 'u1'),
        adminNombreCompleto: 'Ana García',
        adminAvatarUrl: null,
      );

      final miembroDoc = await db
          .collection('grupos')
          .doc(grupoId)
          .collection('miembros')
          .doc('u1')
          .get();

      expect(miembroDoc.exists, isTrue, reason: 'admin miembro must exist');
      expect(miembroDoc.data()!['rol'], RolMiembro.administrador.name);
      expect(miembroDoc.data()!['estado'], EstadoMiembro.activo.name);
      expect(miembroDoc.data()!['nombreCompleto'], 'Ana García');
      expect(miembroDoc.data()!['uid'], 'u1');
    });

    test('miembro grupoId matches returned grupo id', () async {
      final db = FakeFirebaseFirestore();
      final ds = _ds(db);

      final grupoId = await ds.createGrupo(
        _grupoTemplate(adminUid: 'u1'),
        adminNombreCompleto: 'Beto',
        adminAvatarUrl: null,
      );

      final miembroDoc = await db
          .collection('grupos')
          .doc(grupoId)
          .collection('miembros')
          .doc('u1')
          .get();

      expect(miembroDoc.data()!['grupoId'], grupoId);
    });

    test('codigoAcceso is 8 characters of uppercase letters/digits', () async {
      final db = FakeFirebaseFirestore();
      final ds = _ds(db);

      final grupoId = await ds.createGrupo(
        _grupoTemplate(),
        adminNombreCompleto: 'Admin',
        adminAvatarUrl: null,
      );

      final doc = await db.collection('grupos').doc(grupoId).get();
      final codigo = doc.data()!['codigoAcceso'] as String;
      expect(codigo.length, 8);
      expect(RegExp(r'^[A-Z0-9]+$').hasMatch(codigo), isTrue);
    });

    test('two groups get different codigoAcceso values', () async {
      final db = FakeFirebaseFirestore();
      final ds = _ds(db);

      final g1 = await ds.createGrupo(
        _grupoTemplate(),
        adminNombreCompleto: 'Admin1',
        adminAvatarUrl: null,
      );
      final g2 = await ds.createGrupo(
        _grupoTemplate(),
        adminNombreCompleto: 'Admin2',
        adminAvatarUrl: null,
      );

      final c1 = (await db.collection('grupos').doc(g1).get()).data()!['codigoAcceso'];
      final c2 = (await db.collection('grupos').doc(g2).get()).data()!['codigoAcceso'];
      expect(c1, isNot(equals(c2)), reason: 'access codes must be unique');
    });
  });

  // ── TEST-12: deleteGrupo cascade ─────────────────────────────────────────────

  group('GrupoDatasource.deleteGrupo — cascade delete', () {
    Future<String> _seedGrupoWithMiembros(
      FakeFirebaseFirestore db, {
      required int miembroCount,
    }) async {
      final ds = _ds(db);
      final grupoId = await ds.createGrupo(
        _grupoTemplate(adminUid: 'u0'),
        adminNombreCompleto: 'Admin',
        adminAvatarUrl: null,
      );
      // Add extra miembros directly
      for (var i = 1; i < miembroCount; i++) {
        await db
            .collection('grupos')
            .doc(grupoId)
            .collection('miembros')
            .doc('u$i')
            .set({'uid': 'u$i', 'grupoId': grupoId});
      }
      return grupoId;
    }

    test('grupo document is deleted', () async {
      final db = FakeFirebaseFirestore();
      final ds = _ds(db);
      final grupoId = await _seedGrupoWithMiembros(db, miembroCount: 1);

      await ds.deleteGrupo(grupoId);

      final doc = await db.collection('grupos').doc(grupoId).get();
      expect(doc.exists, isFalse, reason: 'grupo must not exist after delete');
    });

    test('all miembros in subcollection are deleted', () async {
      final db = FakeFirebaseFirestore();
      final ds = _ds(db);
      final grupoId = await _seedGrupoWithMiembros(db, miembroCount: 5);

      // Verify miembros exist before delete
      final before = await db
          .collection('grupos').doc(grupoId).collection('miembros').get();
      expect(before.docs.length, 5);

      await ds.deleteGrupo(grupoId);

      final after = await db
          .collection('grupos').doc(grupoId).collection('miembros').get();
      expect(after.docs.length, 0, reason: 'all miembros must be deleted');
    });

    test('deletes large group (400+ miembros) in batches without error',
        () async {
      final db = FakeFirebaseFirestore();
      final ds = _ds(db);
      final grupoId = await _seedGrupoWithMiembros(db, miembroCount: 450);

      await expectLater(ds.deleteGrupo(grupoId), completes);

      final after = await db
          .collection('grupos').doc(grupoId).collection('miembros').get();
      expect(after.docs.length, 0);
    });

    test('deleting a group does not affect other groups', () async {
      final db = FakeFirebaseFirestore();
      final ds = _ds(db);

      final g1 = await _seedGrupoWithMiembros(db, miembroCount: 3);
      final g2 = await _seedGrupoWithMiembros(db, miembroCount: 2);

      await ds.deleteGrupo(g1);

      final g2doc = await db.collection('grupos').doc(g2).get();
      expect(g2doc.exists, isTrue, reason: 'other grupo must be unaffected');
      final g2miembros = await db
          .collection('grupos').doc(g2).collection('miembros').get();
      expect(g2miembros.docs.length, 2);
    });
  });

  // ── App de grupo único: ensureMembership ─────────────────────────────────────

  group('GrupoDatasource.ensureMembership — grupo único (Tacheros)', () {
    test('primer usuario: crea el grupo y queda administrador', () async {
      final db = FakeFirebaseFirestore();
      final ds = _ds(db);

      await ds.ensureMembership(
        'tacheros',
        uid: 'u1',
        nombreCompleto: 'Pedro',
        avatarUrl: null,
        grupoNombre: 'Tacheros',
      );

      final grupo = await db.collection('grupos').doc('tacheros').get();
      expect(grupo.exists, isTrue, reason: 'el grupo debe crearse');
      expect(grupo.data()!['nombre'], 'Tacheros');
      expect(grupo.data()!['adminUid'], 'u1');
      expect(grupo.data()!['miembrosCount'], 1);

      final miembro = await db
          .collection('grupos').doc('tacheros')
          .collection('miembros').doc('u1').get();
      expect(miembro.exists, isTrue);
      expect(miembro.data()!['rol'], RolMiembro.administrador.name,
          reason: 'el creador debe quedar administrador');
      expect(miembro.data()!['estado'], EstadoMiembro.activo.name);
    });

    test('segundo usuario: se suma como miembro e incrementa el contador',
        () async {
      final db = FakeFirebaseFirestore();
      final ds = _ds(db);

      // Primer usuario crea el grupo.
      await ds.ensureMembership('tacheros',
          uid: 'u1', nombreCompleto: 'Pedro', grupoNombre: 'Tacheros');
      // Segundo usuario.
      await ds.ensureMembership('tacheros',
          uid: 'u2', nombreCompleto: 'Juan', grupoNombre: 'Tacheros');

      final miembro = await db
          .collection('grupos').doc('tacheros')
          .collection('miembros').doc('u2').get();
      expect(miembro.exists, isTrue);
      expect(miembro.data()!['rol'], RolMiembro.miembro.name,
          reason: 'los que se suman después son miembros, no admin');

      final grupo = await db.collection('grupos').doc('tacheros').get();
      expect(grupo.data()!['miembrosCount'], 2);
    });

    test('idempotente: llamar de nuevo para un miembro existente no duplica',
        () async {
      final db = FakeFirebaseFirestore();
      final ds = _ds(db);

      await ds.ensureMembership('tacheros',
          uid: 'u1', nombreCompleto: 'Pedro', grupoNombre: 'Tacheros');
      // Segunda llamada del mismo usuario (p. ej. otro arranque de la app).
      await ds.ensureMembership('tacheros',
          uid: 'u1', nombreCompleto: 'Pedro', grupoNombre: 'Tacheros');

      final grupo = await db.collection('grupos').doc('tacheros').get();
      expect(grupo.data()!['miembrosCount'], 1,
          reason: 'no debe volver a incrementar el contador');
      final miembro = await db
          .collection('grupos').doc('tacheros')
          .collection('miembros').doc('u1').get();
      expect(miembro.data()!['rol'], RolMiembro.administrador.name,
          reason: 'sigue siendo admin tras la segunda llamada');
    });
  });
}
