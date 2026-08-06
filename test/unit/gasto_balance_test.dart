// TEST-05: computeBalances, computeNetBalances, computeSettlements
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_groups_app/data/models/gasto_model.dart';
import 'package:sports_groups_app/data/repositories/gasto_repository.dart';

GastoModel _g({
  required String pagadorUid,
  required String pagadorNombre,
  required List<ParticipanteGasto> participantes,
  double monto = 100,
  TipoMovimiento tipo = TipoMovimiento.gasto,
}) =>
    GastoModel(
      id: 'g',
      grupoId: 'grp',
      pagadorUid: pagadorUid,
      pagadorNombre: pagadorNombre,
      titulo: 'Test',
      monto: monto,
      participantes: participantes,
      categoria: CategoriaGasto.otro,
      tipo: tipo,
      createdAt: DateTime(2025),
    );

LiquidacionModel _l({
  required String deudorUid,
  required String deudorNombre,
  required String acreedorUid,
  required String acreedorNombre,
  required double monto,
}) =>
    LiquidacionModel(
      id: 'l',
      grupoId: 'grp',
      deudorUid: deudorUid,
      deudorNombre: deudorNombre,
      acreedorUid: acreedorUid,
      acreedorNombre: acreedorNombre,
      monto: monto,
      createdAt: DateTime(2025),
    );

void main() {
  group('GastoRepository.computeBalances', () {
    test('payer sees positive balances for all co-participants', () {
      final g = _g(
        pagadorUid: 'A',
        pagadorNombre: 'Ana',
        monto: 90,
        participantes: [
          const ParticipanteGasto(uid: 'A', nombre: 'Ana', monto: 30),
          const ParticipanteGasto(uid: 'B', nombre: 'Beto', monto: 30),
          const ParticipanteGasto(uid: 'C', nombre: 'Carlos', monto: 30),
        ],
      );
      final balances = GastoRepository.computeBalances(
        currentUid: 'A',
        gastos: [g],
        liquidaciones: [],
      );
      expect(balances.length, 2);
      expect(balances.firstWhere((b) => b.uid == 'B').monto, closeTo(30, 0.01));
      expect(balances.firstWhere((b) => b.uid == 'C').monto, closeTo(30, 0.01));
    });

    test('debtor sees negative balance toward payer', () {
      final g = _g(
        pagadorUid: 'B',
        pagadorNombre: 'Beto',
        monto: 60,
        participantes: [
          const ParticipanteGasto(uid: 'A', nombre: 'Ana', monto: 30),
          const ParticipanteGasto(uid: 'B', nombre: 'Beto', monto: 30),
        ],
      );
      final balances = GastoRepository.computeBalances(
        currentUid: 'A',
        gastos: [g],
        liquidaciones: [],
      );
      expect(balances.length, 1);
      expect(balances.first.uid, 'B');
      expect(balances.first.monto, closeTo(-30, 0.01));
    });

    test('liquidacion reduces outstanding debt', () {
      final g = _g(
        pagadorUid: 'A',
        pagadorNombre: 'Ana',
        monto: 60,
        participantes: [
          const ParticipanteGasto(uid: 'A', nombre: 'Ana', monto: 30),
          const ParticipanteGasto(uid: 'B', nombre: 'Beto', monto: 30),
        ],
      );
      final liq = _l(
        deudorUid: 'B', deudorNombre: 'Beto',
        acreedorUid: 'A', acreedorNombre: 'Ana',
        monto: 20,
      );
      final balances = GastoRepository.computeBalances(
        currentUid: 'A',
        gastos: [g],
        liquidaciones: [liq],
      );
      // 30 original - 20 already paid = 10 still owed
      expect(balances.first.monto, closeTo(10, 0.01));
    });

    test('ingreso type does not generate debts', () {
      final g = _g(
        pagadorUid: 'A',
        pagadorNombre: 'Ana',
        monto: 100,
        tipo: TipoMovimiento.ingreso,
        participantes: [
          const ParticipanteGasto(uid: 'B', nombre: 'Beto', monto: 100),
        ],
      );
      final balances = GastoRepository.computeBalances(
        currentUid: 'A',
        gastos: [g],
        liquidaciones: [],
      );
      expect(balances, isEmpty);
    });

    test('empty inputs return empty list', () {
      expect(
        GastoRepository.computeBalances(
          currentUid: 'A',
          gastos: [],
          liquidaciones: [],
        ),
        isEmpty,
      );
    });

    test('fully settled group returns no balances above threshold', () {
      final g = _g(
        pagadorUid: 'A',
        pagadorNombre: 'Ana',
        monto: 60,
        participantes: [
          const ParticipanteGasto(uid: 'A', nombre: 'Ana', monto: 30),
          const ParticipanteGasto(uid: 'B', nombre: 'Beto', monto: 30),
        ],
      );
      final liq = _l(
        deudorUid: 'B', deudorNombre: 'Beto',
        acreedorUid: 'A', acreedorNombre: 'Ana',
        monto: 30,
      );
      final balances = GastoRepository.computeBalances(
        currentUid: 'A',
        gastos: [g],
        liquidaciones: [liq],
      );
      expect(balances, isEmpty);
    });
  });

  group('GastoRepository.computeNetBalances', () {
    test('three-way split: payer net positive, others net negative', () {
      final g = _g(
        pagadorUid: 'A',
        pagadorNombre: 'Ana',
        monto: 90,
        participantes: [
          const ParticipanteGasto(uid: 'A', nombre: 'Ana', monto: 30),
          const ParticipanteGasto(uid: 'B', nombre: 'Beto', monto: 30),
          const ParticipanteGasto(uid: 'C', nombre: 'Carlos', monto: 30),
        ],
      );
      final net = GastoRepository.computeNetBalances(
        gastos: [g],
        liquidaciones: [],
      );
      expect(net['A']!.saldo, closeTo(60, 0.01));
      expect(net['B']!.saldo, closeTo(-30, 0.01));
      expect(net['C']!.saldo, closeTo(-30, 0.01));
    });

    test('liquidacion zeroes out the debt', () {
      final g = _g(
        pagadorUid: 'A',
        pagadorNombre: 'Ana',
        monto: 60,
        participantes: [
          const ParticipanteGasto(uid: 'A', nombre: 'Ana', monto: 30),
          const ParticipanteGasto(uid: 'B', nombre: 'Beto', monto: 30),
        ],
      );
      final liq = _l(
        deudorUid: 'B', deudorNombre: 'Beto',
        acreedorUid: 'A', acreedorNombre: 'Ana',
        monto: 30,
      );
      final net = GastoRepository.computeNetBalances(
        gastos: [g],
        liquidaciones: [liq],
      );
      expect(net['A']!.saldo.abs(), lessThan(0.01));
      expect(net['B']!.saldo.abs(), lessThan(0.01));
    });
  });

  group('GastoRepository.computeSettlements', () {
    test('two-person debt: one payment', () {
      final net = {
        'A': (nombre: 'Ana', saldo: 30.0),
        'B': (nombre: 'Beto', saldo: -30.0),
      };
      final s = GastoRepository.computeSettlements(net);
      expect(s.length, 1);
      expect(s.first.fromUid, 'B');
      expect(s.first.toUid, 'A');
      expect(s.first.monto, closeTo(30, 0.01));
    });

    test('three-way: debts are minimized', () {
      final net = {
        'A': (nombre: 'Ana', saldo: 50.0),
        'B': (nombre: 'Beto', saldo: -30.0),
        'C': (nombre: 'Carlos', saldo: -20.0),
      };
      final s = GastoRepository.computeSettlements(net);
      final total = s.fold<double>(0, (acc, p) => acc + p.monto);
      expect(total, closeTo(50, 0.01));
      expect(s.length, lessThanOrEqualTo(2));
    });

    test('empty balances: no settlements', () {
      expect(
        GastoRepository.computeSettlements({}),
        isEmpty,
      );
    });

    test('all balanced: no settlements generated', () {
      final net = {
        'A': (nombre: 'Ana', saldo: 0.0),
        'B': (nombre: 'Beto', saldo: 0.3), // below 0.5 threshold
      };
      expect(GastoRepository.computeSettlements(net), isEmpty);
    });
  });

  group('GastoRepository.totalDebenA / totalDebeA', () {
    test('sums correctly with mixed signs', () {
      final balances = [
        const BalanceConMiembro(uid: 'B', nombre: 'B', monto: 50),
        const BalanceConMiembro(uid: 'C', nombre: 'C', monto: -20),
        const BalanceConMiembro(uid: 'D', nombre: 'D', monto: 30),
      ];
      expect(GastoRepository.totalDebenA(balances), closeTo(80, 0.01));
      expect(GastoRepository.totalDebeA(balances), closeTo(20, 0.01));
    });

    test('all positive: totalDebeA is zero', () {
      final balances = [
        const BalanceConMiembro(uid: 'B', nombre: 'B', monto: 40),
      ];
      expect(GastoRepository.totalDebeA(balances), 0.0);
    });
  });
}
