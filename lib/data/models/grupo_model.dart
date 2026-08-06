import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'enums.dart';

class GrupoModel {
  final String id;
  final String nombre;
  final String? descripcion;
  final String? logoUrl;
  final String? portadaUrl; // full-width cover/banner image
  final String? colorPrimario; // hex e.g. '#E2693F'
  final TipoGrupo tipo;
  final String adminUid;
  final int miembrosCount;
  final DateTime createdAt;
  final String codigoAcceso; // invite code for private groups

  const GrupoModel({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.logoUrl,
    this.portadaUrl,
    this.colorPrimario,
    required this.tipo,
    required this.adminUid,
    required this.miembrosCount,
    required this.createdAt,
    required this.codigoAcceso,
  }) : assert(nombre.length > 0, 'GrupoModel.nombre no puede estar vacío');

  factory GrupoModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return GrupoModel(
      id: doc.id,
      nombre: d['nombre'] ?? '',
      descripcion: d['descripcion'],
      logoUrl: d['logoUrl'],
      portadaUrl: d['portadaUrl'],
      colorPrimario: d['colorPrimario'],
      tipo: TipoGrupo.values.byName(d['tipo'] ?? 'publico'),
      adminUid: d['adminUid'] ?? '',
      miembrosCount: d['miembrosCount'] ?? 0,
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      codigoAcceso: d['codigoAcceso'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'descripcion': descripcion,
        'logoUrl': logoUrl,
        'portadaUrl': portadaUrl,
        if (colorPrimario != null) 'colorPrimario': colorPrimario,
        'tipo': tipo.name,
        'adminUid': adminUid,
        'miembrosCount': miembrosCount,
        'createdAt': Timestamp.fromDate(createdAt),
        'codigoAcceso': codigoAcceso,
      };

  /// Parses [colorPrimario] hex string to a Flutter [Color].
  /// Falls back to the app's default coral primary if not set or invalid.
  Color get primaryColor {
    if (colorPrimario == null) return const Color(0xFFE2693F);
    try {
      return Color(int.parse('FF${colorPrimario!.substring(1)}', radix: 16));
    } catch (_) {
      return const Color(0xFFE2693F);
    }
  }

  GrupoModel copyWith({
    String? nombre,
    String? descripcion,
    String? logoUrl,
    String? portadaUrl,
    String? colorPrimario,
    TipoGrupo? tipo,
    int? miembrosCount,
  }) =>
      GrupoModel(
        id: id,
        nombre: nombre ?? this.nombre,
        descripcion: descripcion ?? this.descripcion,
        logoUrl: logoUrl ?? this.logoUrl,
        portadaUrl: portadaUrl ?? this.portadaUrl,
        colorPrimario: colorPrimario ?? this.colorPrimario,
        tipo: tipo ?? this.tipo,
        adminUid: adminUid,
        miembrosCount: miembrosCount ?? this.miembrosCount,
        createdAt: createdAt,
        codigoAcceso: codigoAcceso,
      );
}
