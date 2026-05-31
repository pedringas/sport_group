import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/campana_repository.dart';
import '../data/models/campana_model.dart';
import '../data/models/enums.dart';
import 'auth_provider.dart';

final campanaRepositoryProvider =
    Provider<CampanaRepository>((ref) => CampanaRepository());

final campanasProvider =
    StreamProvider.family<List<CampanaModel>, String>((ref, grupoId) {
  return ref.watch(campanaRepositoryProvider).getCampanas(grupoId);
});

final campanaProvider =
    StreamProvider.family<CampanaModel?, ({String grupoId, String campanaId})>(
        (ref, args) => ref
            .watch(campanaRepositoryProvider)
            .watchCampana(args.grupoId, args.campanaId));

final aportesProvider =
    StreamProvider.family<List<AporteModel>, ({String grupoId, String campanaId})>(
        (ref, args) => ref
            .watch(campanaRepositoryProvider)
            .getAportes(args.grupoId, args.campanaId));

/// Mis aportes en todas las campañas de un grupo (para Caja — egresos).
final misAportesGrupoProvider =
    StreamProvider.family<List<AporteModel>, ({String grupoId, String uid})>(
        (ref, args) => ref
            .watch(campanaRepositoryProvider)
            .getMisAportesGrupo(args.grupoId, args.uid));

// ── CrearCampaña ──────────────────────────────────────────────────────────────

class CrearCampanaNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> crear({
    required String grupoId,
    required String titulo,
    String? descripcion,
    required double objetivo,
    DateTime? fechaLimite,
    String? imagenUrl,
  }) async {
    state = const AsyncLoading();
    try {
      final uid = ref.read(authStateProvider).valueOrNull?.uid;
      if (uid == null) throw Exception('No autenticado');
      await ref.read(campanaRepositoryProvider).createCampana(
            grupoId: grupoId,
            titulo: titulo,
            descripcion: descripcion,
            objetivo: objetivo,
            fechaLimite: fechaLimite,
            imagenUrl: imagenUrl,
            creadoPor: uid,
          );
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final crearCampanaProvider =
    AsyncNotifierProvider<CrearCampanaNotifier, void>(CrearCampanaNotifier.new);

// ── Aportar ───────────────────────────────────────────────────────────────────

class AportarNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> aportar({
    required String grupoId,
    required String campanaId,
    required double monto,
    String? mensaje,
  }) async {
    state = const AsyncLoading();
    try {
      // Get authenticated user
      final user = ref.read(authStateProvider).valueOrNull;
      if (user == null) throw Exception('No autenticado');

      // Get display name from Firestore user profile (already cached via currentUserProvider)
      final perfil = await ref.read(currentUserProvider.future);
      final nombre = perfil?.nombreCompleto ?? user.displayName ?? 'Usuario';

      await ref.read(campanaRepositoryProvider).addAporte(
            grupoId: grupoId,
            campanaId: campanaId,
            usuarioUid: user.uid,
            usuarioNombre: nombre,
            monto: monto,
            mensaje: mensaje,
          );
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final aportarProvider =
    AsyncNotifierProvider<AportarNotifier, void>(AportarNotifier.new);

// ── Cambiar estado campaña ────────────────────────────────────────────────────

class EstadoCampanaNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> cambiar(
      String grupoId, String campanaId, EstadoCampana estado) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(campanaRepositoryProvider)
          .updateEstado(grupoId, campanaId, estado);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final estadoCampanaProvider =
    AsyncNotifierProvider<EstadoCampanaNotifier, void>(EstadoCampanaNotifier.new);
