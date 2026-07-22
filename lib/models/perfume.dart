class Perfume {
  int? id;
  int? apiId;
  String nombre;
  String marca;
  String descripcion;
  double precioCosto;
  double precioVenta;
  int stock;
  String? imagenUrl;

  Perfume({
    this.id,
    this.apiId,
    required this.nombre,
    required this.marca,
    this.descripcion = '',
    required this.precioCosto,
    required this.precioVenta,
    this.stock = 0,
    this.imagenUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'api_id': apiId,
      'nombre': nombre,
      'marca': marca,
      'descripcion': descripcion,
      'precio_costo': precioCosto,
      'precio_venta': precioVenta,
      'stock': stock,
      'imagen_url': imagenUrl,
    };
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  factory Perfume.fromMap(Map<String, dynamic> map) {
    return Perfume(
      id: _asInt(map['id']) == 0 ? null : _asInt(map['id']),
      apiId: _asInt(map['api_id']) == 0 ? null : _asInt(map['api_id']),
      nombre: map['nombre']?.toString() ?? '',
      marca: map['marca']?.toString() ?? '',
      descripcion: map['descripcion'] ?? '',
      precioCosto: _asDouble(map['precio_costo']),
      precioVenta: _asDouble(map['precio_venta']),
      stock: _asInt(map['stock']),
      imagenUrl: map['imagen_url']?.toString().isNotEmpty == true
          ? map['imagen_url'].toString()
          : (map['imagen']?.toString().isNotEmpty == true
              ? map['imagen'].toString()
              : null),
    );
  }
}
