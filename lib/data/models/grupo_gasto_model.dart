import 'package:cloud_firestore/cloud_firestore.dart';

class GrupoGastoModel {
  final String id;
  final String grupoId;
  final String nombre;
  final String? descripcion;
  final bool cerrado;
  final String creadoPorUid;
  final String creadoPorNombre;
  final DateTime createdAt;
  final DateTime? cerradoAt;

  const GrupoGastoModel({
    required this.id,
    required this.grupoId,
    required this.nombre,
    this.descripcion,
    this.cerrado = false,
    required this.creadoPorUid,
    required this.creadoPorNombre,
    required this.createdAt,
    this.cerradoAt,
  });

  factory GrupoGastoModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return GrupoGastoModel(
      id: doc.id,
      grupoId: d['grupoId'] as String? ?? '',
      nombre: d['nombre'] as String? ?? '',
      descripcion: d['descripcion'] as String?,
      cerrado: d['cerrado'] as bool? ?? false,
      creadoPorUid: d['creadoPorUid'] as String? ?? '',
      creadoPorNombre: d['creadoPorNombre'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      cerradoAt: d['cerradoAt'] != null
          ? (d['cerradoAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'grupoId': grupoId,
        'nombre': nombre,
        'descripcion': descripcion,
        'cerrado': cerrado,
        'creadoPorUid': creadoPorUid,
        'creadoPorNombre': creadoPorNombre,
        'createdAt': Timestamp.fromDate(createdAt),
        if (cerradoAt != null) 'cerradoAt': Timestamp.fromDate(cerradoAt!),
      };
}
