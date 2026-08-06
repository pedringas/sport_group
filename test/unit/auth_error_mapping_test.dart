// TEST-02: Firebase Auth error code → Spanish message mapping
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_groups_app/providers/auth_provider.dart';

void main() {
  group('AuthFlowNotifier.mapEmailError', () {
    test('all known email-auth codes map to non-empty Spanish messages', () {
      final cases = {
        'user-not-found': 'No existe una cuenta con ese email',
        'wrong-password': 'Contraseña incorrecta',
        'invalid-credential': 'Email o contraseña incorrectos',
        'email-already-in-use': 'Ese email ya está registrado',
        'weak-password': 'La contraseña debe tener al menos 6 caracteres',
        'invalid-email': 'Email inválido',
        'too-many-requests': 'Demasiados intentos. Esperá un momento',
        'user-disabled': 'Esta cuenta fue deshabilitada',
      };
      for (final entry in cases.entries) {
        expect(
          AuthFlowNotifier.mapEmailError(entry.key),
          entry.value,
          reason: 'code: ${entry.key}',
        );
      }
    });

    test('unknown code returns generic fallback', () {
      expect(
        AuthFlowNotifier.mapEmailError('some-unknown-error'),
        'Error de autenticación. Intentá de nuevo',
      );
    });

    test('empty string returns fallback', () {
      expect(
        AuthFlowNotifier.mapEmailError(''),
        'Error de autenticación. Intentá de nuevo',
      );
    });
  });

  group('AuthFlowNotifier.mapError (SMS / phone)', () {
    test('all known SMS error codes map to Spanish messages', () {
      final cases = {
        'invalid-phone-number': 'Número de teléfono inválido',
        'too-many-requests': 'Demasiados intentos. Esperá unos minutos',
        'invalid-verification-code': 'Código incorrecto',
        'session-expired': 'El código expiró. Solicitá uno nuevo',
        'quota-exceeded': 'Límite de SMS alcanzado. Intentá más tarde',
      };
      for (final entry in cases.entries) {
        expect(
          AuthFlowNotifier.mapError(entry.key),
          entry.value,
          reason: 'code: ${entry.key}',
        );
      }
    });

    test('unknown SMS error code returns generic fallback', () {
      expect(
        AuthFlowNotifier.mapError('network-request-failed'),
        'Error de autenticación. Intentá de nuevo',
      );
    });

    test('note: too-many-requests has different wording in email vs SMS', () {
      // email version mentions "Esperá un momento", SMS version "Esperá unos minutos"
      expect(
        AuthFlowNotifier.mapEmailError('too-many-requests'),
        contains('un momento'),
      );
      expect(
        AuthFlowNotifier.mapError('too-many-requests'),
        contains('unos minutos'),
      );
    });
  });
}
