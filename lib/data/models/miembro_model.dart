import 'package:cloud_firestore/cloud_firestore.dart';
import 'enums.dart';

class MiembroModel {
  final String uid;
  final String grupoId;
  final String nombreCompleto;
  final String? avatarUrl;
  final RolMiembro rol;
  final EstadoMiembro estado;
  final DateTime joinedAt;
  /// True when the user has marked this group as favourite / priority.
  /// Used to surface content from this group in the home feed carousel.
  final bool esFavorito;

  const MiembroModel({
    required this.uid,
    required this.grupoId,
    required this.nombreCompleto,
    this.avatarUrl,
    required this.rol,
    required this.estado,
    required this.joinedAt,
    this.esFavorito = false,
  });

  factory MiembroModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MiembroModel(
      uid: doc.id,
      grupoId: d['grupoId'] ?? '',
      nombreCompleto: d['nombreCompleto'] ?? '',
      avatarUrl: d['avatarUrl'],
      rol: RolMiembro.values.byName(d['rol'] ?? 'miembro'),
      estado: EstadoMiembro.values.byName(d['estado'] ?? 'activo'),
      joinedAt: (d['joinedAt'] as Timestamp).toDate(),
      esFavorito: d['esFavorito'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'grupoId': grupoId,
        'nombreCompleto': nombreCompleto,
        'avatarUrl': avatarUrl,
        'rol': rol.name,
        'estado': estado.name,
        'joinedAt': Timestamp.fromDate(joinedAt),
        'esFavorito': esFavorito,
      };
}
