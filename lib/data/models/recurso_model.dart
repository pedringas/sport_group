import 'package:cloud_firestore/cloud_firestore.dart';

enum TipoRecurso { archivo, link }

extension TipoRecursoX on TipoRecurso {
  String get label => switch (this) {
        TipoRecurso.archivo => 'Archivo',
        TipoRecurso.link => 'Enlace',
      };
}

class RecursoModel {
  final String id;
  final String grupoId;
  final String autorUid;
  final String autorNombre;
  final String titulo;
  final TipoRecurso tipo;
  final String url;
  final String? descripcion;
  final String? nombreArchivo; // original filename for files
  final DateTime createdAt;

  const RecursoModel({
    required this.id,
    required this.grupoId,
    required this.autorUid,
    required this.autorNombre,
    required this.titulo,
    required this.tipo,
    required this.url,
    this.descripcion,
    this.nombreArchivo,
    required this.createdAt,
  });

  factory RecursoModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return RecursoModel(
      id: doc.id,
      grupoId: d['grupoId'] ?? '',
      autorUid: d['autorUid'] ?? '',
      autorNombre: d['autorNombre'] ?? '',
      titulo: d['titulo'] ?? '',
      tipo: TipoRecurso.values.byName(d['tipo'] ?? 'link'),
      url: d['url'] ?? '',
      descripcion: d['descripcion'],
      nombreArchivo: d['nombreArchivo'],
      createdAt: (d['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'grupoId': grupoId,
        'autorUid': autorUid,
        'autorNombre': autorNombre,
        'titulo': titulo,
        'tipo': tipo.name,
        'url': url,
        'descripcion': descripcion,
        'nombreArchivo': nombreArchivo,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
