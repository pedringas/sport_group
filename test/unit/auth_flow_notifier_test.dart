// TEST-01: AuthFlowNotifier state machine — login, registro, OTP, Google
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sports_groups_app/data/repositories/auth_repository.dart';
import 'package:sports_groups_app/providers/auth_provider.dart';

class MockAuthRepository extends Mock implements AuthRepository {}
class MockUserCredential extends Mock implements UserCredential {}

ProviderContainer _container(AuthRepository repo) => ProviderContainer(
      overrides: [authRepositoryProvider.overrideWith((ref) => repo)],
    );

void main() {
  late MockAuthRepository repo;
  late MockUserCredential cred;

  setUp(() {
    repo = MockAuthRepository();
    cred = MockUserCredential();
  });

  // ── signInWithEmail ──────────────────────────────────────────────────────────

  group('AuthFlowNotifier.signInWithEmail', () {
    test('success: ends in AuthDone', () async {
      when(() => repo.signInWithEmail(any(), any()))
          .thenAnswer((_) async => cred);

      final c = _container(repo);
      addTearDown(c.dispose);
      await c.read(authFlowProvider.notifier).signInWithEmail('a@b.com', 'pass');

      expect(c.read(authFlowProvider), isA<AuthDone>());
    });

    test('user-not-found → AuthError with Spanish message', () async {
      when(() => repo.signInWithEmail(any(), any()))
          .thenThrow(FirebaseAuthException(code: 'user-not-found'));

      final c = _container(repo);
      addTearDown(c.dispose);
      await c.read(authFlowProvider.notifier).signInWithEmail('a@b.com', 'pass');

      final state = c.read(authFlowProvider);
      expect(state, isA<AuthError>());
      expect((state as AuthError).message, 'No existe una cuenta con ese email');
    });

    test('invalid-credential → AuthError with correct message', () async {
      when(() => repo.signInWithEmail(any(), any()))
          .thenThrow(FirebaseAuthException(code: 'invalid-credential'));

      final c = _container(repo);
      addTearDown(c.dispose);
      await c.read(authFlowProvider.notifier).signInWithEmail('a@b.com', 'bad');

      final state = c.read(authFlowProvider);
      expect((state as AuthError).message, 'Email o contraseña incorrectos');
    });

    test('unknown code → generic fallback message', () async {
      when(() => repo.signInWithEmail(any(), any()))
          .thenThrow(FirebaseAuthException(code: 'unknown-xyz'));

      final c = _container(repo);
      addTearDown(c.dispose);
      await c.read(authFlowProvider.notifier).signInWithEmail('a@b.com', 'pass');

      expect((c.read(authFlowProvider) as AuthError).message,
          'Error de autenticación. Intentá de nuevo');
    });
  });

  // ── signUpWithEmail ──────────────────────────────────────────────────────────

  group('AuthFlowNotifier.signUpWithEmail', () {
    test('success: ends in AuthDone', () async {
      when(() => repo.signUpWithEmail(
            email: any(named: 'email'),
            password: any(named: 'password'),
            nombre: any(named: 'nombre'),
            apellido: any(named: 'apellido'),
          )).thenAnswer((_) async => cred);

      final c = _container(repo);
      addTearDown(c.dispose);
      await c.read(authFlowProvider.notifier).signUpWithEmail(
            email: 'new@b.com',
            password: 'pass123',
            nombre: 'Ana',
            apellido: 'García',
          );

      expect(c.read(authFlowProvider), isA<AuthDone>());
    });

    test('email-already-in-use → AuthError with correct message', () async {
      when(() => repo.signUpWithEmail(
            email: any(named: 'email'),
            password: any(named: 'password'),
            nombre: any(named: 'nombre'),
            apellido: any(named: 'apellido'),
          )).thenThrow(FirebaseAuthException(code: 'email-already-in-use'));

      final c = _container(repo);
      addTearDown(c.dispose);
      await c.read(authFlowProvider.notifier).signUpWithEmail(
            email: 'dup@b.com',
            password: 'pass123',
            nombre: 'Pedro',
            apellido: 'García',
          );

      expect((c.read(authFlowProvider) as AuthError).message,
          'Ese email ya está registrado');
    });
  });

  // ── sendOtp / OTP flow ───────────────────────────────────────────────────────

  group('AuthFlowNotifier.sendOtp', () {
    test('onCodeSent callback → AuthOtpSent with verificationId and token',
        () async {
      when(() => repo.sendOtp(
            phone: any(named: 'phone'),
            onAutoVerified: any(named: 'onAutoVerified'),
            onCodeSent: any(named: 'onCodeSent'),
            onError: any(named: 'onError'),
          )).thenAnswer((inv) async {
        final cb = inv.namedArguments[#onCodeSent] as Function(String, int?);
        cb('vid-123', 7);
      });

      final c = _container(repo);
      addTearDown(c.dispose);
      await c.read(authFlowProvider.notifier).sendOtp('+5491100000000');

      final state = c.read(authFlowProvider);
      expect(state, isA<AuthOtpSent>());
      expect((state as AuthOtpSent).verificationId, 'vid-123');
      expect(state.forceResendToken, 7);
    });

    test('onError callback → AuthError with mapped message', () async {
      when(() => repo.sendOtp(
            phone: any(named: 'phone'),
            onAutoVerified: any(named: 'onAutoVerified'),
            onCodeSent: any(named: 'onCodeSent'),
            onError: any(named: 'onError'),
          )).thenAnswer((inv) async {
        final cb = inv.namedArguments[#onError]
            as Function(FirebaseAuthException);
        cb(FirebaseAuthException(code: 'invalid-phone-number'));
      });

      final c = _container(repo);
      addTearDown(c.dispose);
      await c.read(authFlowProvider.notifier).sendOtp('abc');

      expect((c.read(authFlowProvider) as AuthError).message,
          'Número de teléfono inválido');
    });
  });

  // ── verifyOtp ───────────────────────────────────────────────────────────────

  group('AuthFlowNotifier.verifyOtp', () {
    test('success: ends in AuthDone', () async {
      when(() => repo.verifyOtp(any(), any())).thenAnswer((_) async => cred);

      final c = _container(repo);
      addTearDown(c.dispose);
      await c.read(authFlowProvider.notifier).verifyOtp('vid-123', '123456');

      expect(c.read(authFlowProvider), isA<AuthDone>());
    });

    test('invalid-verification-code → AuthError', () async {
      when(() => repo.verifyOtp(any(), any()))
          .thenThrow(FirebaseAuthException(code: 'invalid-verification-code'));

      final c = _container(repo);
      addTearDown(c.dispose);
      await c.read(authFlowProvider.notifier).verifyOtp('vid-123', 'wrong');

      expect((c.read(authFlowProvider) as AuthError).message,
          'Código incorrecto');
    });
  });

  // ── signInWithGoogle ─────────────────────────────────────────────────────────

  group('AuthFlowNotifier.signInWithGoogle', () {
    test('success: ends in AuthDone', () async {
      when(() => repo.signInWithGoogle()).thenAnswer((_) async => cred);

      final c = _container(repo);
      addTearDown(c.dispose);
      await c.read(authFlowProvider.notifier).signInWithGoogle();

      expect(c.read(authFlowProvider), isA<AuthDone>());
    });

    test('throws: ends in AuthError', () async {
      when(() => repo.signInWithGoogle())
          .thenThrow(Exception('Google sign-in cancelled'));

      final c = _container(repo);
      addTearDown(c.dispose);
      await c.read(authFlowProvider.notifier).signInWithGoogle();

      final state = c.read(authFlowProvider);
      expect(state, isA<AuthError>());
      expect((state as AuthError).message,
          contains('Error al iniciar sesión con Google'));
    });
  });

  // ── signOut / reset ──────────────────────────────────────────────────────────

  group('AuthFlowNotifier lifecycle', () {
    test('signOut returns to AuthIdle', () async {
      when(() => repo.signInWithEmail(any(), any()))
          .thenAnswer((_) async => cred);
      when(() => repo.signOut()).thenAnswer((_) async {});

      final c = _container(repo);
      addTearDown(c.dispose);
      await c.read(authFlowProvider.notifier).signInWithEmail('a@b.com', 'pw');
      expect(c.read(authFlowProvider), isA<AuthDone>());

      await c.read(authFlowProvider.notifier).signOut();
      expect(c.read(authFlowProvider), isA<AuthIdle>());
    });

    test('reset() from AuthError returns to AuthIdle', () async {
      when(() => repo.signInWithEmail(any(), any()))
          .thenThrow(FirebaseAuthException(code: 'user-not-found'));

      final c = _container(repo);
      addTearDown(c.dispose);
      await c.read(authFlowProvider.notifier).signInWithEmail('a@b.com', 'pw');
      expect(c.read(authFlowProvider), isA<AuthError>());

      c.read(authFlowProvider.notifier).reset();
      expect(c.read(authFlowProvider), isA<AuthIdle>());
    });
  });
}
