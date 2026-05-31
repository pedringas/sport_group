import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/gasto_repository.dart';
import '../data/models/gasto_model.dart';
import '../data/models/grupo_gasto_model.dart';
import 'auth_provider.dart';

final gastoRepositoryProvider =
    Provider<GastoRepository>((ref) => GastoRepository());

// ── Grupos de gastos ──────────────────────────────────────────────────────────

final gruposGastoProvider =
    StreamProvider.family<List<GrupoGastoModel>, String>((ref, grupoId) {
  return ref.watch(gastoRepositoryProvider).getGruposGasto(grupoId);
});

// ── All gastos stream ─────────────────────────────────────────────────────────

final todosGastosProvider =
    StreamProvider.family<List<GastoModel>, String>((ref, grupoId) {
  return ref.watch(gastoRepositoryProvider).getGastos(grupoId);
});

// ── Liquidaciones stream ──────────────────────────────────────────────────────

final liquidacionesProvider =
    StreamProvider.family<List<LiquidacionModel>, String>((ref, grupoId) {
  return ref.watch(gastoRepositoryProvider).getLiquidaciones(grupoId);
});

// ── Balances for current user (all gastos, no group filter) ──────────────────

final balancesProvider =
    Provider.family<List<BalanceConMiembro>, String>((ref, grupoId) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
  final gastos = ref.watch(todosGastosProvider(grupoId)).valueOrNull ?? [];
  final liquidaciones =
      ref.watch(liquidacionesProvider(grupoId)).valueOrNull ?? [];
  return GastoRepository.computeBalances(
    currentUid: uid,
    gastos: gastos,
    liquidaciones: liquidaciones,
  );
});

// ── Balances per grupo de gasto ───────────────────────────────────────────────

typedef GrupoGastoKey = ({String grupoId, String? grupoGastoId});

final balancesGrupoGastoProvider =
    Provider.family<List<BalanceConMiembro>, GrupoGastoKey>((ref, key) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
  final allGastos =
      ref.watch(todosGastosProvider(key.grupoId)).valueOrNull ?? [];
  final allLiquidaciones =
      ref.watch(liquidacionesProvider(key.grupoId)).valueOrNull ?? [];

  // Filter to this specific grupo de gasto
  final gastos = allGastos
      .where((g) => g.grupoGastoId == key.grupoGastoId)
      .toList();
  final liquidaciones = allLiquidaciones
      .where((l) => l.grupoGastoId == key.grupoGastoId)
      .toList();

  return GastoRepository.computeBalances(
    currentUid: uid,
    gastos: gastos,
    liquidaciones: liquidaciones,
  );
});

// ── Create/edit gasto notifier ────────────────────────────────────────────────

class CrearGastoNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> crear({
    required String grupoId,
    required String titulo,
    String? descripcion,
    required double monto,
    required String pagadorUid,
    required String pagadorNombre,
    required List<ParticipanteGasto> participantes,
    required CategoriaGasto categoria,
    TipoMovimiento tipo = TipoMovimiento.gasto,
    String? grupoGastoId,
    DateTime? fecha,
  }) async {
    state = const AsyncLoading();
    try {
      await ref.read(gastoRepositoryProvider).createGasto(
            grupoId: grupoId,
            pagadorUid: pagadorUid,
            pagadorNombre: pagadorNombre,
            titulo: titulo,
            descripcion: descripcion,
            monto: monto,
            participantes: participantes,
            categoria: categoria,
            tipo: tipo,
            grupoGastoId: grupoGastoId,
            fecha: fecha,
          );
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> editar({
    required String grupoId,
    required String gastoId,
    required String titulo,
    String? descripcion,
    required double monto,
    required List<ParticipanteGasto> participantes,
    required CategoriaGasto categoria,
    TipoMovimiento tipo = TipoMovimiento.gasto,
    String? grupoGastoId,
    DateTime? fecha,
  }) async {
    state = const AsyncLoading();
    try {
      await ref.read(gastoRepositoryProvider).updateGasto(
            grupoId: grupoId,
            gastoId: gastoId,
            titulo: titulo,
            descripcion: descripcion,
            monto: monto,
            participantes: participantes,
            categoria: categoria,
            tipo: tipo,
            grupoGastoId: grupoGastoId,
            fecha: fecha,
          );
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> eliminar({
    required String grupoId,
    required String gastoId,
  }) async {
    state = const AsyncLoading();
    try {
      await ref.read(gastoRepositoryProvider).deleteGasto(grupoId, gastoId);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final crearGastoProvider =
    AsyncNotifierProvider<CrearGastoNotifier, void>(CrearGastoNotifier.new);

// ── GrupoGasto notifier ───────────────────────────────────────────────────────

class GrupoGastoNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String> crear({
    required String grupoId,
    required String nombre,
    String? descripcion,
  }) async {
    state = const AsyncLoading();
    try {
      final user = ref.read(authStateProvider).valueOrNull!;
      final userData =
          await ref.read(authRepositoryProvider).getUser(user.uid);
      final id = await ref.read(gastoRepositoryProvider).createGrupoGasto(
            grupoId: grupoId,
            nombre: nombre,
            descripcion: descripcion,
            creadoPorUid: user.uid,
            creadoPorNombre:
                userData?.nombreCompleto ?? user.displayName ?? '',
          );
      state = const AsyncData(null);
      return id;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> cerrar(String grupoId, String grupoGastoId) async {
    await ref
        .read(gastoRepositoryProvider)
        .cerrarGrupoGasto(grupoId, grupoGastoId);
  }

  Future<void> reabrir(String grupoId, String grupoGastoId) async {
    await ref
        .read(gastoRepositoryProvider)
        .reabrirGrupoGasto(grupoId, grupoGastoId);
  }

  Future<void> eliminar(String grupoId, String grupoGastoId) async {
    await ref
        .read(gastoRepositoryProvider)
        .deleteGrupoGasto(grupoId, grupoGastoId);
  }
}

final grupoGastoNotifierProvider =
    AsyncNotifierProvider<GrupoGastoNotifier, void>(GrupoGastoNotifier.new);

// ── Liquidar deuda notifier ───────────────────────────────────────────────────

class LiquidarNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> liquidar({
    required String grupoId,
    required String deudorUid,
    required String deudorNombre,
    required String acreedorUid,
    required String acreedorNombre,
    required double monto,
    String? grupoGastoId,
  }) async {
    state = const AsyncLoading();
    try {
      await ref.read(gastoRepositoryProvider).createLiquidacion(
            grupoId: grupoId,
            deudorUid: deudorUid,
            deudorNombre: deudorNombre,
            acreedorUid: acreedorUid,
            acreedorNombre: acreedorNombre,
            monto: monto,
            grupoGastoId: grupoGastoId,
          );
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final liquidarProvider =
    AsyncNotifierProvider<LiquidarNotifier, void>(LiquidarNotifier.new);
