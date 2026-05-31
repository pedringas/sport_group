import 'package:cloud_firestore/cloud_firestore.dart';

/// A group-level activity event stored at grupos/{grupoId}/actividad/{id}.
class ActividadModel {
  final String id;

  /// 'noticia' | 'nuevo_miembro' | 'nueva_cuota' | 'nueva_tarea' | 'gasto'
  final String tipo;
  final String titulo;
  final String mensaje;
  final String actorNombre;
  final String? actorAvatarUrl;
  final String grupoId;
  final String grupoNombre;

  /// Optional: points to the related document (noticiaId, cuotaId, etc.)
  final String? referenciaId;
  final DateTime createdAt;

  const ActividadModel({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.mensaje,
    required this.actorNombre,
    this.actorAvatarUrl,
    required this.grupoId,
    required this.grupoNombre,
    this.referenciaId,
    required this.createdAt,
  });

  factory ActividadModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ActividadModel(
      id: doc.id,
      tipo: d['tipo'] as String? ?? '',
      titulo: d['titulo'] as String? ?? '',
      mensaje: d['mensaje'] as String? ?? '',
      actorNombre: d['actorNombre'] as String? ?? '',
      actorAvatarUrl: d['actorAvatarUrl'] as String?,
      grupoId: d['grupoId'] as String? ?? '',
      grupoNombre: d['grupoNombre'] as String? ?? '',
      referenciaId: d['referenciaId'] as String?,
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'tipo': tipo,
        'titulo': titulo,
        'mensaje': mensaje,
        'actorNombre': actorNombre,
        if (actorAvatarUrl != null) 'actorAvatarUrl': actorAvatarUrl,
        'grupoId': grupoId,
        'grupoNombre': grupoNombre,
        if (referenciaId != null) 'referenciaId': referenciaId,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
