import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Standardized base for all AsyncNotifier<void> in the app.
///
/// Provides [run] (void action) and [runR] (action returning a value),
/// both of which set AsyncLoading → AsyncData/AsyncError and rethrow on failure.
abstract class BaseAsyncNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> run(Future<void> Function() action) async {
    state = const AsyncLoading();
    try {
      await action();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<R> runR<R>(Future<R> Function() action) async {
    state = const AsyncLoading();
    try {
      final result = await action();
      state = const AsyncData(null);
      return result;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
