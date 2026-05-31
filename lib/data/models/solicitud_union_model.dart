import 'package:cloud_firestore/cloud_firestore.dart';
import 'enums.dart';

class SolicitudUnionModel {
  final String id;
  final String grupoId;
  final String usuarioUid;
  final String usuarioNombre;
  final String? usuarioAvatar;
  final EstadoSolicitud estado;
  final DateTime createdAt;

  const SolicitudUnionModel({
    required this.id,
    required this.grupoId,
    required this.usuarioUid,
    required this.usuarioNombre,
    this.usuarioAvatar,
    required this.estado,
    required this.createdAt,
  });

  factory SolicitudUnionModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SolicitudUnionModel(
      id: doc.id,
      grupoId: d['grupoId'] ?? '',
      usuarioUid: d['usuarioUid'] ?? '',
      usuarioNombre: d['usuarioNombre'] ?? '',
      usuarioAvatar: d['usuarioAvatar'],
      estado: EstadoSolicitud.values.byName(d['estado'] ?? 'pendiente'),
      createdAt: (d['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'grupoId': grupoId,
        'usuarioUid': usuarioUid,
        'usuarioNombre': usuarioNombre,
        'usuarioAvatar': usuarioAvatar,
        'estado': estado.name,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
