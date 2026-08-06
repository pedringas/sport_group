// TEST-03: extractMonto regex parsing (pure — no Vision API calls)
import { parseMontoFromText } from '../ocr';

describe('parseMontoFromText', () => {
  describe('$ prefix with dot-thousand and comma-decimal (AR format)', () => {
    test('$ 1.234,56 → 1234.56', () => {
      expect(parseMontoFromText('Total $ 1.234,56')).toBeCloseTo(1234.56);
    });

    test('$500,00 → 500', () => {
      expect(parseMontoFromText('Monto $500,00')).toBeCloseTo(500);
    });

    test('$ 12.000 (no decimals) → 12000 via dot-thousands pattern', () => {
      expect(parseMontoFromText('Importe $ 12.000')).toBeCloseTo(12000);
    });
  });

  describe('$ prefix simple integer', () => {
    test('$1500 → 1500', () => {
      expect(parseMontoFromText('Pagaste $1500')).toBeCloseTo(1500);
    });

    test('$75,50 → 75.5', () => {
      expect(parseMontoFromText('Saldo: $75,50')).toBeCloseTo(75.5);
    });
  });

  describe('no $ prefix — dot-thousand format', () => {
    test('2.500,00 → 2500', () => {
      expect(parseMontoFromText('Transferencia: 2.500,00 ARS')).toBeCloseTo(2500);
    });
  });

  describe('no $ prefix — trailing two decimals', () => {
    test('300,00 → 300', () => {
      expect(parseMontoFromText('Débito 300,00')).toBeCloseTo(300);
    });

    test('1000,50 → 1000.5 (comma as decimal separator)', () => {
      expect(parseMontoFromText('Crédito 1000,50')).toBeCloseTo(1000.5);
    });
  });

  describe('picks the largest amount', () => {
    test('returns max when multiple amounts present', () => {
      expect(parseMontoFromText('Comisión $50,00 Total $3.000,00')).toBeCloseTo(3000);
    });
  });

  describe('edge cases', () => {
    test('empty string → null', () => {
      expect(parseMontoFromText('')).toBeNull();
    });

    test('no numeric data → null', () => {
      expect(parseMontoFromText('Sin información de monto')).toBeNull();
    });

    test('zero values are ignored', () => {
      expect(parseMontoFromText('$0,00 descuento $200,00 total')).toBeCloseTo(200);
    });
  });
});
