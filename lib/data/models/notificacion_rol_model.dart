import 'package:cloud_firestore/cloud_firestore.dart';

/// A role-specific notification stored at usuarios/{uid}/notificaciones/{id}.
class NotificacionRolModel {
  final String id;

  /// 'admin' | 'moderador' | 'tesorero' | 'delegado'
  final String tipo;
  final String titulo;
  final String mensaje;
  final String grupoId;
  final String grupoNombre;
  final DateTime createdAt;
  final bool leida;

  const NotificacionRolModel({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.mensaje,
    required this.grupoId,
    required this.grupoNombre,
    required this.createdAt,
    this.leida = false,
  });

  factory NotificacionRolModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return NotificacionRolModel(
      id: doc.id,
      tipo: d['tipo'] as String? ?? '',
      titulo: d['titulo'] as String? ?? '',
      mensaje: d['mensaje'] as String? ?? '',
      grupoId: d['grupoId'] as String? ?? '',
      grupoNombre: d['grupoNombre'] as String? ?? '',
      leida: d['leida'] as bool? ?? false,
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'tipo': tipo,
        'titulo': titulo,
        'mensaje': mensaje,
        'grupoId': grupoId,
        'grupoNombre': grupoNombre,
        'createdAt': Timestamp.fromDate(createdAt),
        'leida': leida,
      };
}
