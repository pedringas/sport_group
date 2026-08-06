// TEST-06: cuota series date generation
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_groups_app/data/datasources/cuota_datasource.dart';
import 'package:sports_groups_app/data/models/enums.dart';

void main() {
  final base = DateTime(2025, 1, 15); // Jan 15

  group('CuotaDatasource.addPeriods — mensual', () {
    test('n=0 returns base date', () {
      expect(CuotaDatasource.addPeriods(base, FrecuenciaCuota.mensual, 0), base);
    });

    test('n=1 adds one month', () {
      final result = CuotaDatasource.addPeriods(base, FrecuenciaCuota.mensual, 1);
      expect(result, DateTime(2025, 2, 15));
    });

    test('n=11 ends on Dec 15 same year', () {
      final result = CuotaDatasource.addPeriods(base, FrecuenciaCuota.mensual, 11);
      expect(result, DateTime(2025, 12, 15));
    });

    test('n=12 rolls over to next year Jan 15', () {
      final result = CuotaDatasource.addPeriods(base, FrecuenciaCuota.mensual, 12);
      expect(result, DateTime(2026, 1, 15));
    });
  });

  group('CuotaDatasource.addPeriods — bimestral', () {
    test('n=1 adds 2 months', () {
      final result = CuotaDatasource.addPeriods(base, FrecuenciaCuota.bimestral, 1);
      expect(result, DateTime(2025, 3, 15));
    });

    test('n=3 adds 6 months', () {
      final result = CuotaDatasource.addPeriods(base, FrecuenciaCuota.bimestral, 3);
      expect(result, DateTime(2025, 7, 15));
    });
  });

  group('CuotaDatasource.addPeriods — trimestral', () {
    test('n=1 adds 3 months', () {
      final result = CuotaDatasource.addPeriods(base, FrecuenciaCuota.trimestral, 1);
      expect(result, DateTime(2025, 4, 15));
    });

    test('n=4 adds one year', () {
      final result = CuotaDatasource.addPeriods(base, FrecuenciaCuota.trimestral, 4);
      expect(result, DateTime(2026, 1, 15));
    });
  });

  group('CuotaDatasource.addPeriods — anual', () {
    test('n=1 adds one year', () {
      final result = CuotaDatasource.addPeriods(base, FrecuenciaCuota.anual, 1);
      expect(result, DateTime(2026, 1, 15));
    });

    test('n=5 adds five years', () {
      final result = CuotaDatasource.addPeriods(base, FrecuenciaCuota.anual, 5);
      expect(result, DateTime(2030, 1, 15));
    });
  });

  group('CuotaDatasource.addPeriods — semanal (days-based)', () {
    test('n=1 adds 7 days', () {
      final result = CuotaDatasource.addPeriods(base, FrecuenciaCuota.semanal, 1);
      expect(result, DateTime(2025, 1, 22));
    });

    test('n=4 adds 28 days', () {
      final result = CuotaDatasource.addPeriods(base, FrecuenciaCuota.semanal, 4);
      expect(result, DateTime(2025, 2, 12));
    });
  });

  group('CuotaDatasource.addPeriods — generated series produces no duplicates', () {
    test('12 monthly cuotas have 12 distinct dates', () {
      final dates = List.generate(
        12,
        (i) => CuotaDatasource.addPeriods(base, FrecuenciaCuota.mensual, i),
      );
      expect(dates.toSet().length, 12);
    });

    test('dates are strictly ascending', () {
      final dates = List.generate(
        6,
        (i) => CuotaDatasource.addPeriods(base, FrecuenciaCuota.bimestral, i),
      );
      for (int i = 1; i < dates.length; i++) {
        expect(dates[i].isAfter(dates[i - 1]), isTrue,
            reason: 'date[$i] should be after date[${i - 1}]');
      }
    });
  });
}
