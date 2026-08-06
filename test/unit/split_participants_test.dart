// TEST-11: CrearGastoPage.splitParticipants — equal-split calculation
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_groups_app/data/models/enums.dart';
import 'package:sports_groups_app/data/models/miembro_model.dart';
import 'package:sports_groups_app/presentation/gasto/pages/crear_gasto_page.dart';

MiembroModel _m(String uid, String nombre) => MiembroModel(
      uid: uid,
      grupoId: 'grp',
      nombreCompleto: nombre,
      rol: RolMiembro.miembro,
      estado: EstadoMiembro.activo,
      joinedAt: DateTime(2025),
    );

void main() {
  final ana  = _m('A', 'Ana');
  final beto = _m('B', 'Beto');
  final carl = _m('C', 'Carlos');

  group('CrearGastoPage.splitParticipants — selectedUids null (all members)', () {
    test('two members: each pays half', () {
      final parts = CrearGastoPage.splitParticipants(
        allMiembros: [ana, beto],
        selectedUids: null,
        pagadorUid: 'A',
        monto: 100,
      );
      expect(parts.length, 2);
      expect(parts.every((p) => (p.monto - 50).abs() < 0.01), isTrue);
    });

    test('three members: each pays a third', () {
      final parts = CrearGastoPage.splitParticipants(
        allMiembros: [ana, beto, carl],
        selectedUids: null,
        pagadorUid: 'A',
        monto: 90,
      );
      expect(parts.length, 3);
      expect(parts.every((p) => (p.monto - 30).abs() < 0.01), isTrue);
    });
  });

  group('CrearGastoPage.splitParticipants — selectedUids subset', () {
    test('only selected members participate', () {
      final parts = CrearGastoPage.splitParticipants(
        allMiembros: [ana, beto, carl],
        selectedUids: {'A', 'B'},
        pagadorUid: 'A',
        monto: 80,
      );
      expect(parts.length, 2);
      final uids = parts.map((p) => p.uid).toSet();
      expect(uids, {'A', 'B'});
      expect(uids.contains('C'), isFalse);
    });

    test('split is equal among selected members', () {
      final parts = CrearGastoPage.splitParticipants(
        allMiembros: [ana, beto, carl],
        selectedUids: {'A', 'B'},
        pagadorUid: 'A',
        monto: 60,
      );
      expect(parts.every((p) => (p.monto - 30).abs() < 0.01), isTrue);
    });
  });

  group('CrearGastoPage.splitParticipants — payer always included', () {
    test('payer added if not in selectedUids', () {
      final parts = CrearGastoPage.splitParticipants(
        allMiembros: [ana, beto, carl],
        selectedUids: {'B', 'C'},  // payer A not selected
        pagadorUid: 'A',
        monto: 90,
      );
      final uids = parts.map((p) => p.uid).toSet();
      expect(uids.contains('A'), isTrue,
          reason: 'payer must always be a participant');
      expect(parts.length, 3);
    });

    test('payer not duplicated when already in selectedUids', () {
      final parts = CrearGastoPage.splitParticipants(
        allMiembros: [ana, beto],
        selectedUids: {'A', 'B'},
        pagadorUid: 'A',
        monto: 60,
      );
      expect(parts.length, 2);
      expect(parts.where((p) => p.uid == 'A').length, 1,
          reason: 'payer should not appear twice');
    });
  });

  group('CrearGastoPage.splitParticipants — participant metadata', () {
    test('participant names match member names', () {
      final parts = CrearGastoPage.splitParticipants(
        allMiembros: [ana, beto],
        selectedUids: null,
        pagadorUid: 'A',
        monto: 100,
      );
      final betoPart = parts.firstWhere((p) => p.uid == 'B');
      expect(betoPart.nombre, 'Beto');
    });

    test('monto per participant sums to total', () {
      final parts = CrearGastoPage.splitParticipants(
        allMiembros: [ana, beto, carl],
        selectedUids: null,
        pagadorUid: 'A',
        monto: 90,
      );
      final total = parts.fold<double>(0, (s, p) => s + p.monto);
      expect(total, closeTo(90, 0.01));
    });
  });
}
