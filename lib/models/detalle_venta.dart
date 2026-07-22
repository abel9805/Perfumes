class DetalleVenta {
  int? id;
  int ventaId;
  int perfumeId;
  int cantidad;
  double precioUnitario;

  // Campos extra para joins
  String? nombrePerfume;

  DetalleVenta({
    this.id,
    required this.ventaId,
    required this.perfumeId,
    required this.cantidad,
    required this.precioUnitario,
    this.nombrePerfume,
  });

  double get subtotal => cantidad * precioUnitario;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'venta_id': ventaId,
      'perfume_id': perfumeId,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
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

  factory DetalleVenta.fromMap(Map<String, dynamic> map) {
    return DetalleVenta(
      id: _asInt(map['id']) == 0 ? null : _asInt(map['id']),
      ventaId: _asInt(map['venta_id']),
      perfumeId: _asInt(map['perfume_id']),
      cantidad: _asInt(map['cantidad']),
      precioUnitario: _asDouble(map['precio_unitario']),
      nombrePerfume: map['nombre_perfume'],
    );
  }
}
