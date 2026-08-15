// Temporalidad y alcance de una cuota.
//
// Regresiones de dos bugs reportados en producción:
//  · una cuota aparecía "vencida" durante su propio día de vencimiento;
//  · las cuotas de un cobro dirigido a algunos miembros se le mostraban (y se
//    le contaban) a todo el grupo.
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_groups_app/data/datasources/cuota_datasource.dart';
import 'package:sports_groups_app/data/models/cuota_model.dart';

CuotaModel _cuota({
  required DateTime vencimiento,
  List<String>? miembrosUids,
  List<String>? excluidosUids,
}) =>
    CuotaModel(
      id: 'c1',
      grupoId: 'g1',
      titulo: 'Cuota',
      monto: 8500,
      vencimiento: vencimiento,
      activa: true,
      createdAt: DateTime(2026, 8, 1),
      miembrosUids: miembrosUids,
      excluidosUids: excluidosUids,
    );

void main() {
  group('CuotaModel — vencimiento', () {
    final vence10 = _cuota(vencimiento: DateTime(2026, 9, 10));

    test('no está vencida a la mañana de su día de vencimiento', () {
      expect(vence10.estaVencidaAl(DateTime(2026, 9, 10, 9, 0)), isFalse);
    });

    test('no está vencida a las 23:58 de su día de vencimiento', () {
      expect(vence10.estaVencidaAl(DateTime(2026, 9, 10, 23, 58)), isFalse);
    });

    test('está vencida al día siguiente', () {
      expect(vence10.estaVencidaAl(DateTime(2026, 9, 11, 0, 1)), isTrue);
    });

    test('una cuota del mes que viene no está vencida', () {
      expect(vence10.estaVencidaAl(DateTime(2026, 8, 14, 22, 0)), isFalse);
    });

    test('tolera documentos viejos con vencimiento a las 00:00', () {
      final legacy = _cuota(vencimiento: DateTime(2026, 9, 10, 0, 0, 0));
      expect(legacy.estaVencidaAl(DateTime(2026, 9, 10, 15, 0)), isFalse);
    });
  });

  group('CuotaModel — días restantes (calendario, no instantes)', () {
    test('mañana a la noche de hoy da 1, no 0', () {
      final manana = _cuota(vencimiento: DateTime(2026, 8, 15));
      expect(manana.diasRestantesAl(DateTime(2026, 8, 14, 22, 30)), 1);
    });

    test('hoy da 0', () {
      final hoy = _cuota(vencimiento: DateTime(2026, 8, 14));
      expect(hoy.diasRestantesAl(DateTime(2026, 8, 14, 1, 0)), 0);
    });

    test('el mes que viene da días positivos', () {
      final proximo = _cuota(vencimiento: DateTime(2026, 9, 10));
      expect(proximo.diasRestantesAl(DateTime(2026, 8, 14, 22, 0)), 27);
    });

    test('una cuota pasada da negativo', () {
      final vieja = _cuota(vencimiento: DateTime(2026, 8, 10));
      expect(vieja.diasRestantesAl(DateTime(2026, 8, 14, 22, 0)), -4);
    });
  });

  group('CuotaModel — periodo (agrupación por mes)', () {
    test('es el primer día del mes de vencimiento', () {
      final c = _cuota(vencimiento: DateTime(2026, 9, 30, 23, 59, 59));
      expect(c.periodo, DateTime(2026, 9));
    });

    test('dos cuotas del mismo mes comparten periodo', () {
      final a = _cuota(vencimiento: DateTime(2026, 9, 5));
      final b = _cuota(vencimiento: DateTime(2026, 9, 25));
      expect(a.periodo, b.periodo);
    });

    test('cuotas de meses distintos no lo comparten', () {
      final a = _cuota(vencimiento: DateTime(2026, 9, 25));
      final b = _cuota(vencimiento: DateTime(2026, 10, 5));
      expect(a.periodo, isNot(b.periodo));
    });
  });

  group('CuotaModel — alcance', () {
    test('sin listas, la cuota es de todo el grupo', () {
      final c = _cuota(vencimiento: DateTime(2026, 9, 10));
      expect(c.aplicaA('cualquiera'), isTrue);
      expect(c.esSegmentada, isFalse);
    });

    test('con miembrosUids sólo aplica a los incluidos', () {
      final c = _cuota(
          vencimiento: DateTime(2026, 9, 10), miembrosUids: ['a', 'b']);
      expect(c.aplicaA('a'), isTrue);
      expect(c.aplicaA('c'), isFalse);
      expect(c.esSegmentada, isTrue);
    });

    test('una lista de incluidos vacía no excluye a nadie', () {
      final c = _cuota(vencimiento: DateTime(2026, 9, 10), miembrosUids: []);
      expect(c.aplicaA('a'), isTrue);
    });

    test('con excluidosUids aplica a todos menos a ésos', () {
      final c = _cuota(
          vencimiento: DateTime(2026, 9, 10), excluidosUids: ['becado']);
      expect(c.aplicaA('becado'), isFalse);
      expect(c.aplicaA('otro'), isTrue);
      expect(c.esSegmentada, isTrue);
    });

    test('si hay incluidos, los excluidos no se miran', () {
      final c = _cuota(
        vencimiento: DateTime(2026, 9, 10),
        miembrosUids: ['a'],
        excluidosUids: ['a'],
      );
      expect(c.aplicaA('a'), isTrue);
    });
  });

  group('CuotaDatasource.finDelDia', () {
    test('lleva la fecha elegida al último segundo del día', () {
      expect(CuotaDatasource.finDelDia(DateTime(2026, 9, 10)),
          DateTime(2026, 9, 10, 23, 59, 59));
    });

    test('no cambia el día aunque venga con hora', () {
      expect(CuotaDatasource.finDelDia(DateTime(2026, 9, 10, 14, 30)),
          DateTime(2026, 9, 10, 23, 59, 59));
    });

    test('una cuota guardada así no nace vencida ese mismo día', () {
      final guardada =
          _cuota(vencimiento: CuotaDatasource.finDelDia(DateTime(2026, 9, 10)));
      expect(guardada.estaVencidaAl(DateTime(2026, 9, 10, 20, 0)), isFalse);
    });
  });
}
