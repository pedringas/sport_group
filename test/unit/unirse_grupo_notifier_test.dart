// TEST-09: UnirseGrupoNotifier — nombre fallback chain and state transitions
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sports_groups_app/data/models/usuario_model.dart';
import 'package:sports_groups_app/data/repositories/grupo_repository.dart';
import 'package:sports_groups_app/providers/auth_provider.dart';
import 'package:sports_groups_app/providers/grupo_provider.dart';

class MockUser extends Mock implements User {}
class MockGrupoRepository extends Mock implements GrupoRepository {}

UsuarioModel _user({String nombre = '', String apellido = ''}) => UsuarioModel(
      uid: 'u1',
      nombre: nombre,
      apellido: apellido,
      telefono: '',
      createdAt: DateTime(2025),
    );

void main() {
  late MockUser firebaseUser;
  late MockGrupoRepository repo;

  setUp(() {
    firebaseUser = MockUser();
    repo = MockGrupoRepository();
    when(() => firebaseUser.uid).thenReturn('u1');
    when(() => firebaseUser.photoURL).thenReturn(null);
    when(() => repo.joinGrupo(any(), any(), any(), any()))
        .thenAnswer((_) async {});
  });

  ProviderContainer _container({
    required UsuarioModel? userData,
    required String? displayName,
  }) {
    when(() => firebaseUser.displayName).thenReturn(displayName);
    return ProviderContainer(overrides: [
      // Use a sync StreamController so the first event is available immediately on listen.
      authStateProvider.overrideWith((ref) {
        final ctrl = StreamController<User?>(sync: true);
        ctrl.add(firebaseUser);
        return ctrl.stream;
      }),
      currentUserProvider.overrideWith((ref) => Future.value(userData)),
      grupoRepositoryProvider.overrideWith((ref) => repo),
    ]);
  }

  /// Settle the authStateProvider stream before calling notifier methods.
  Future<void> _settle(ProviderContainer c) =>
      c.read(authStateProvider.future);

  // ── Nombre fallback chain ────────────────────────────────────────────────────

  group('UnirseGrupoNotifier.unirse — nombre fallback chain', () {
    test('userData.nombreCompleto is used when document exists with full name',
        () async {
      final c = _container(
        userData: _user(nombre: 'Ana', apellido: 'García'),
        displayName: 'IgnoredDisplayName',
      );
      addTearDown(c.dispose);
      await _settle(c);

      await c.read(unirseGrupoProvider.notifier).unirse('g1');

      verify(() => repo.joinGrupo('g1', 'u1', 'Ana García', null)).called(1);
    });

    test('falls back to user.displayName when userData is null', () async {
      final c = _container(userData: null, displayName: 'Pepito Grillo');
      addTearDown(c.dispose);
      await _settle(c);

      await c.read(unirseGrupoProvider.notifier).unirse('g1');

      verify(() => repo.joinGrupo('g1', 'u1', 'Pepito Grillo', null)).called(1);
    });

    test('uses empty string when userData is null and displayName is null',
        () async {
      final c = _container(userData: null, displayName: null);
      addTearDown(c.dispose);
      await _settle(c);

      await c.read(unirseGrupoProvider.notifier).unirse('g1');

      verify(() => repo.joinGrupo('g1', 'u1', '', null)).called(1);
    });

    test(
        'userData with empty nombre+apellido passes space — displayName is not used',
        () async {
      // nombreCompleto = '$nombre $apellido' = ' ' (non-null) so ?? does not fall through.
      // This documents existing behavior; a future fix could trim before the ?? check.
      final c = _container(
        userData: _user(nombre: '', apellido: ''),
        displayName: 'ShouldBeIgnored',
      );
      addTearDown(c.dispose);
      await _settle(c);

      await c.read(unirseGrupoProvider.notifier).unirse('g1');

      verify(() => repo.joinGrupo('g1', 'u1', ' ', null)).called(1);
    });
  });

  // ── Avatar fallback chain ────────────────────────────────────────────────────

  group('UnirseGrupoNotifier.unirse — avatar fallback chain', () {
    test('uses userData.avatarUrl when present', () async {
      final userWithAvatar = _user(nombre: 'Ana', apellido: 'G').copyWith(
        avatarUrl: 'https://cdn.example.com/avatar.jpg',
      );
      final c = _container(userData: userWithAvatar, displayName: null);
      addTearDown(c.dispose);
      await _settle(c);

      await c.read(unirseGrupoProvider.notifier).unirse('g1');

      verify(() => repo.joinGrupo(
            'g1', 'u1', 'Ana G', 'https://cdn.example.com/avatar.jpg')).called(1);
    });

    test('falls back to user.photoURL when userData.avatarUrl is null',
        () async {
      when(() => firebaseUser.photoURL).thenReturn('https://google.com/photo.jpg');
      final c = _container(
          userData: _user(nombre: 'Beto', apellido: 'X'), displayName: null);
      addTearDown(c.dispose);
      await _settle(c);

      await c.read(unirseGrupoProvider.notifier).unirse('g1');

      verify(() => repo.joinGrupo(
            'g1', 'u1', 'Beto X', 'https://google.com/photo.jpg')).called(1);
    });
  });

  // ── State transitions ────────────────────────────────────────────────────────

  group('UnirseGrupoNotifier.unirse — state transitions', () {
    test('state is AsyncData<void> after success', () async {
      final c = _container(
          userData: _user(nombre: 'Ana', apellido: 'G'), displayName: null);
      addTearDown(c.dispose);
      await _settle(c);

      await c.read(unirseGrupoProvider.notifier).unirse('g1');

      expect(c.read(unirseGrupoProvider), isA<AsyncData<void>>());
    });

    test('state is AsyncError and rethrows when joinGrupo throws', () async {
      when(() => repo.joinGrupo(any(), any(), any(), any()))
          .thenThrow(Exception('Network error'));

      final c = _container(userData: null, displayName: null);
      addTearDown(c.dispose);
      await _settle(c);

      await expectLater(
        c.read(unirseGrupoProvider.notifier).unirse('g1'),
        throwsA(isA<Exception>()),
      );

      expect(c.read(unirseGrupoProvider), isA<AsyncError<void>>());
    });
  });
}
