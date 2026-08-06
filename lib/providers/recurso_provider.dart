import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/recurso_repository.dart';
import '../data/models/recurso_model.dart';
import 'auth_provider.dart';

final recursoRepositoryProvider =
    Provider<RecursoRepository>((ref) => RecursoRepository());

final recursosProvider =
    StreamProvider.family<List<RecursoModel>, String>((ref, grupoId) {
  return ref.watch(recursoRepositoryProvider).getRecursos(grupoId);
});

class CrearRecursoNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> crearLink({
    required String grupoId,
    required String titulo,
    required String url,
    String? descripcion,
  }) async {
    state = const AsyncLoading();
    try {
      final user = ref.read(authStateProvider).valueOrNull!;
      final userData = await ref.read(currentUserProvider.future);
      await ref.read(recursoRepositoryProvider).createRecurso(
            grupoId: grupoId,
            autorUid: user.uid,
            autorNombre: userData?.nombreCompleto ?? user.displayName ?? '',
            titulo: titulo,
            tipo: TipoRecurso.link,
            url: url,
            descripcion: descripcion,
          );
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> crearArchivo({
    required String grupoId,
    required String titulo,
    required String nombreArchivo,
    required Uint8List bytes,
    String? descripcion,
  }) async {
    state = const AsyncLoading();
    try {
      final user = ref.read(authStateProvider).valueOrNull!;
      final userData = await ref.read(currentUserProvider.future);
      final repo = ref.read(recursoRepositoryProvider);
      final url = await repo.uploadArchivo(grupoId, nombreArchivo, bytes);
      await repo.createRecurso(
        grupoId: grupoId,
        autorUid: user.uid,
        autorNombre: userData?.nombreCompleto ?? user.displayName ?? '',
        titulo: titulo,
        tipo: TipoRecurso.archivo,
        url: url,
        descripcion: descripcion,
        nombreArchivo: nombreArchivo,
      );
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final crearRecursoProvider =
    AsyncNotifierProvider<CrearRecursoNotifier, void>(CrearRecursoNotifier.new);
