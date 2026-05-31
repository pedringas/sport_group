import 'package:cloud_firestore/cloud_firestore.dart';

class UsuarioModel {
  final String uid;
  final String nombre;
  final String apellido;
  final String telefono;
  final String? email;
  final String? avatarUrl;
  final String? alias;
  final String? fcmToken;
  final DateTime createdAt;
  // Extended profile fields
  final String? bio;
  final String? fechaNacimiento;
  final bool apareceEnBusqueda;
  final bool mostrarTelefono;
  final String? colorHex; // avatar background color, e.g. 'FF5722'

  const UsuarioModel({
    required this.uid,
    required this.nombre,
    required this.apellido,
    required this.telefono,
    this.email,
    this.avatarUrl,
    this.alias,
    this.fcmToken,
    required this.createdAt,
    this.bio,
    this.fechaNacimiento,
    this.apareceEnBusqueda = true,
    this.mostrarTelefono = false,
    this.colorHex,
  });

  String get nombreCompleto => '$nombre $apellido';

  factory UsuarioModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UsuarioModel(
      uid: doc.id,
      nombre: d['nombre'] ?? '',
      apellido: d['apellido'] ?? '',
      telefono: d['telefono'] ?? '',
      email: d['email'],
      avatarUrl: d['avatarUrl'],
      alias: d['alias'],
      fcmToken: d['fcmToken'],
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      bio: d['bio'] as String?,
      fechaNacimiento: d['fechaNacimiento'] as String?,
      apareceEnBusqueda: d['apareceEnBusqueda'] as bool? ?? true,
      mostrarTelefono: d['mostrarTelefono'] as bool? ?? false,
      colorHex: d['colorHex'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'apellido': apellido,
        'telefono': telefono,
        'email': email,
        'avatarUrl': avatarUrl,
        if (alias != null) 'alias': alias,
        'fcmToken': fcmToken,
        'createdAt': Timestamp.fromDate(createdAt),
        if (bio != null) 'bio': bio,
        if (fechaNacimiento != null) 'fechaNacimiento': fechaNacimiento,
        'apareceEnBusqueda': apareceEnBusqueda,
        'mostrarTelefono': mostrarTelefono,
        if (colorHex != null) 'colorHex': colorHex,
      };

  UsuarioModel copyWith({
    String? nombre,
    String? apellido,
    String? telefono,
    String? email,
    String? avatarUrl,
    String? alias,
    String? fcmToken,
    String? bio,
    String? fechaNacimiento,
    bool? apareceEnBusqueda,
    bool? mostrarTelefono,
    String? colorHex,
  }) =>
      UsuarioModel(
        uid: uid,
        nombre: nombre ?? this.nombre,
        apellido: apellido ?? this.apellido,
        telefono: telefono ?? this.telefono,
        email: email ?? this.email,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        alias: alias ?? this.alias,
        fcmToken: fcmToken ?? this.fcmToken,
        createdAt: createdAt,
        bio: bio ?? this.bio,
        fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
        apareceEnBusqueda: apareceEnBusqueda ?? this.apareceEnBusqueda,
        mostrarTelefono: mostrarTelefono ?? this.mostrarTelefono,
        colorHex: colorHex ?? this.colorHex,
      );
}
