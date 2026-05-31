import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/grupo_repository.dart';
import '../data/models/grupo_model.dart';
import '../data/models/miembro_model.dart';
import '../data/models/solicitud_union_model.dart';
import '../data/models/enums.dart';
import '../core/theme/app_theme.dart';
import 'auth_provider.dart';

final grupoRepositoryProvider = Provider<GrupoRepository>((ref) => GrupoRepository());

final userGruposProvider = StreamProvider<List<GrupoModel>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const Stream.empty();
  return ref.watch(grupoRepositoryProvider).getUserGrupos(user.uid);
});

/// IDs of groups the current user marked as favourite.
final gruposFavoritosProvider = StreamProvider<Set<String>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const Stream.empty();
  return FirebaseFirestore.instance
      .collectionGroup('miembros')
      .where('uid', isEqualTo: user.uid)
      .where('esFavorito', isEqualTo: true)
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => d.data()['grupoId'] as String).toSet());
});

/// Toggle favourite status for a group membership.
final toggleFavoritoProvider =
    Provider.family<Future<void> Function(bool), String>((ref, grupoId) {
  return (bool value) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    await ref.read(grupoRepositoryProvider).setFavorito(grupoId, uid, value);
  };
});

/// Live stream — auto-updates when Firestore document changes.
/// Fixes grey screen after group creation (no more null-on-race-condition).
final grupoProvider = StreamProvider.family<GrupoModel?, String>(
    (ref, grupoId) =>
        ref.watch(grupoRepositoryProvider).getGrupoStream(grupoId));

/// Returns the group's configured primary colour (falls back to app coral).
/// Use this in every group-scoped page instead of [AppTheme.primary].
final grupoColorProvider = Provider.family<Color, String>((ref, grupoId) =>
    ref.watch(grupoProvider(grupoId)).valueOrNull?.primaryColor ??
    AppTheme.primary);

final miembrosProvider = StreamProvider.family<List<MiembroModel>, String>(
    (ref, grupoId) => ref.watch(grupoRepositoryProvider).getMiembros(grupoId));

/// Live stream of the current user's member record.
final miembroActualProvider =
    StreamProvider.family<MiembroModel?, String>((ref, grupoId) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const Stream.empty();
  return ref
      .watch(grupoRepositoryProvider)
      .getMiembroStream(grupoId, user.uid);
});

final solicitudesPendientesProvider =
    StreamProvider.family<List<SolicitudUnionModel>, String>((ref, grupoId) =>
        ref.watch(grupoRepositoryProvider).getSolicitudesPendientes(grupoId));

/// Current user's join solicitud for a group (null = none sent).
final miSolicitudProvider =
    FutureProvider.family<SolicitudUnionModel?, String>((ref, grupoId) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return null;
  return ref.watch(grupoRepositoryProvider).getMiSolicitud(grupoId, uid);
});

// ── Unirse / Solicitar unirse ────────────────────────────────────────────────

class UnirseGrupoNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> unirse(String grupoId) async {
    state = const AsyncLoading();
    try {
      final user = ref.read(authStateProvider).valueOrNull!;
      final userData = await ref.read(authRepositoryProvider).getUser(user.uid);
      await ref.read(grupoRepositoryProvider).joinGrupo(
            grupoId,
            user.uid,
            userData?.nombreCompleto ?? user.displayName ?? '',
            userData?.avatarUrl ?? user.photoURL,
          );
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> solicitar(String grupoId) async {
    state = const AsyncLoading();
    try {
      final user = ref.read(authStateProvider).valueOrNull!;
      final userData = await ref.read(authRepositoryProvider).getUser(user.uid);
      await ref.read(grupoRepositoryProvider).requestJoinGrupo(
            grupoId,
            user.uid,
            userData?.nombreCompleto ?? user.displayName ?? '',
            userData?.avatarUrl ?? user.photoURL,
          );
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final unirseGrupoProvider =
    AsyncNotifierProvider<UnirseGrupoNotifier, void>(UnirseGrupoNotifier.new);

// ── Abandonar grupo ──────────────────────────────────────────────────────────

class AbandonarGrupoNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> abandonar(String grupoId) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    state = const AsyncLoading();
    try {
      await ref.read(grupoRepositoryProvider).leaveGrupo(grupoId, uid);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final abandonarGrupoProvider =
    AsyncNotifierProvider<AbandonarGrupoNotifier, void>(
        AbandonarGrupoNotifier.new);

// ── Eliminar grupo ───────────────────────────────────────────────────────────

class EliminarGrupoNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> eliminar(String grupoId) async {
    state = const AsyncLoading();
    try {
      await ref.read(grupoRepositoryProvider).deleteGrupo(grupoId);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final eliminarGrupoProvider =
    AsyncNotifierProvider<EliminarGrupoNotifier, void>(
        EliminarGrupoNotifier.new);

// ── CrearGrupo notifier ───────────────────────────────────────────────────────

class CrearGrupoNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String> crearGrupo({
    required String nombre,
    String? descripcion,
    required TipoGrupo tipo,
    Uint8List? logoBytes,
    Uint8List? portadaBytes,
  }) async {
    state = const AsyncLoading();
    try {
      final user = ref.read(authStateProvider).valueOrNull!;
      final repo = ref.read(grupoRepositoryProvider);
      final userData = await ref.read(authRepositoryProvider).getUser(user.uid);

      final adminNombre =
          userData?.nombreCompleto.isNotEmpty == true
              ? userData!.nombreCompleto
              : (user.displayName ?? '');
      final adminAvatar = userData?.avatarUrl ?? user.photoURL;

      final grupo = GrupoModel(
        id: '',
        nombre: nombre,
        descripcion: descripcion,
        tipo: tipo,
        adminUid: user.uid,
        miembrosCount: 0,
        createdAt: DateTime.now(),
        codigoAcceso: '', // generated by createGrupo in repository
      );
      final grupoId = await repo.createGrupo(
        grupo,
        adminNombreCompleto: adminNombre,
        adminAvatarUrl: adminAvatar,
      );

      // Upload logo if provided
      if (logoBytes != null) {
        final logoUrl = await repo.uploadLogo(grupoId, logoBytes);
        await repo.updateGrupo(grupoId, {'logoUrl': logoUrl});
      }

      // Upload portada if provided
      if (portadaBytes != null) {
        final portadaUrl = await repo.uploadPortada(grupoId, portadaBytes);
        await repo.updateGrupo(grupoId, {'portadaUrl': portadaUrl});
      }

      state = const AsyncData(null);
      return grupoId;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final crearGrupoProvider =
    AsyncNotifierProvider<CrearGrupoNotifier, void>(CrearGrupoNotifier.new);
