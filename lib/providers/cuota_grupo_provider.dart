import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/cuota_grupo_repository.dart';
import '../data/models/cuota_grupo_model.dart';

final cuotaGrupoRepositoryProvider = Provider<CuotaGrupoRepository>(
    (ref) => CuotaGrupoRepository(FirebaseFirestore.instance));

final cuotaGruposProvider =
    StreamProvider.family<List<CuotaGrupoModel>, String>((ref, grupoId) =>
        ref.watch(cuotaGrupoRepositoryProvider).watchCuotaGrupos(grupoId));
