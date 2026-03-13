// lib/models/producto_model.dart
//
// Representa un documento de la colección 'productos' en Firestore.

import 'package:cloud_firestore/cloud_firestore.dart';

class ProductoModel {
  final String  id;
  final String  nombre;
  final double  precio;
  final String  categoria;
  final String  subtexto;
  final String  imagen;
  final int     stock;
  final bool    activo;
  final String  idAdmin;
  final Timestamp? creadoEn;

  const ProductoModel({
    required this.id,
    required this.nombre,
    required this.precio,
    required this.categoria,
    required this.subtexto,
    required this.imagen,
    required this.stock,
    required this.activo,
    required this.idAdmin,
    this.creadoEn,
  });

  /// Crea un ProductoModel desde un documento de Firestore.
  factory ProductoModel.fromFirestore(
      Map<String, dynamic> data, String docId) {
    return ProductoModel(
      id:        docId,
      nombre:    data['nombre']?.toString()    ?? 'Sin nombre',
      precio:    (data['precio'] as num?)?.toDouble() ?? 0.0,
      categoria: data['categoria']?.toString() ?? '',
      subtexto:  data['subtexto']?.toString()  ?? '',
      imagen:    data['imagen']?.toString()     ?? '',
      stock:     (data['stock'] as num?)?.toInt() ?? 0,
      activo:    data['activo'] as bool? ?? false,
      idAdmin:   data['idAdmin']?.toString()   ?? '',
      creadoEn:  data['creadoEn'] is Timestamp
                     ? data['creadoEn'] as Timestamp
                     : null,
    );
  }

  /// Convierte a Map para guardar en Firestore
  Map<String, dynamic> toMap() => {
        'nombre'    : nombre,
        'precio'    : precio,
        'categoria' : categoria,
        'subtexto'  : subtexto,
        'imagen'    : imagen,
        'stock'     : stock,
        'activo'    : activo,
        'idAdmin'   : idAdmin,
        if (creadoEn != null) 'creadoEn': creadoEn,
      };

  /// Copia con campos modificados
  ProductoModel copyWith({
    String? nombre,
    double? precio,
    String? categoria,
    String? subtexto,
    String? imagen,
    int?    stock,
    bool?   activo,
  }) =>
      ProductoModel(
        id:        id,
        nombre:    nombre    ?? this.nombre,
        precio:    precio    ?? this.precio,
        categoria: categoria ?? this.categoria,
        subtexto:  subtexto  ?? this.subtexto,
        imagen:    imagen    ?? this.imagen,
        stock:     stock     ?? this.stock,
        activo:    activo    ?? this.activo,
        idAdmin:   idAdmin,
        creadoEn:  creadoEn,
      );

  /// Convierte a Map<String, dynamic> para compatibilidad con
  /// los widgets existentes que reciben Map en lugar del modelo.
  Map<String, dynamic> toDisplayMap() => {
        'id'        : id,
        'nombre'    : nombre,
        'precio'    : precio,
        'categoria' : categoria,
        'subtexto'  : subtexto,
        'imagen'    : imagen,
        'stock'     : stock,
        'activo'    : activo,
        'idAdmin'   : idAdmin,
      };
}