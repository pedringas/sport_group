import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/tarea_repository.dart';
import '../data/models/tarea_model.dart';
import '../data/models/enums.dart';
import 'auth_provider.dart';

final tareaRepositoryProvider =
    Provider<TareaRepository>((ref) => TareaRepository());

final tareasProvider =
    StreamProvider.family<List<TareaModel>, String>((ref, grupoId) {
  return ref.watch(tareaRepositoryProvider).getTareas(grupoId);
});

class TareaNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String> crear({
    required String grupoId,
    required String titulo,
    String? descripcion,
    List<AsignadoTarea> asignadosA = const [],
    DateTime? fechaVencimiento,
  }) async {
    state = const AsyncLoading();
    try {
      final user = ref.read(authStateProvider).valueOrNull!;
      final userData = await ref.read(currentUserProvider.future);
      final id = await ref.read(tareaRepositoryProvider).createTarea(
            grupoId: grupoId,
            titulo: titulo,
            descripcion: descripcion,
            creadoPorUid: user.uid,
            creadoPorNombre:
                userData?.nombreCompleto ?? user.displayName ?? '',
            asignadosA: asignadosA,
            fechaVencimiento: fechaVencimiento,
          );
      state = const AsyncData(null);
      return id;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> updateEstado(
      String grupoId, String tareaId, TareaEstado estado) async {
    try {
      await ref
          .read(tareaRepositoryProvider)
          .updateEstado(grupoId, tareaId, estado);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> updateAsignados(String grupoId, String tareaId,
      List<AsignadoTarea> asignadosA) async {
    try {
      await ref
          .read(tareaRepositoryProvider)
          .updateAsignados(grupoId, tareaId, asignadosA);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> updateTarea({
    required String grupoId,
    required String tareaId,
    required String titulo,
    String? descripcion,
    required List<AsignadoTarea> asignadosA,
    required TareaEstado estado,
    DateTime? fechaVencimiento,
  }) async {
    state = const AsyncLoading();
    try {
      await ref.read(tareaRepositoryProvider).updateTarea(
            grupoId: grupoId,
            tareaId: tareaId,
            titulo: titulo,
            descripcion: descripcion,
            asignadosA: asignadosA,
            estado: estado,
            fechaVencimiento: fechaVencimiento,
          );
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> eliminar(String grupoId, String tareaId) async {
    state = const AsyncLoading();
    try {
      await ref.read(tareaRepositoryProvider).deleteTarea(grupoId, tareaId);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final tareaNotifierProvider =
    AsyncNotifierProvider<TareaNotifier, void>(TareaNotifier.new);
