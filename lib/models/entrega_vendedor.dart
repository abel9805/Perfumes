class EntregaVendedor {
  int? id;
  int? apiId;
  int vendedorId;
  int perfumeId;
  int cantidad;
  double precioUnitario;
  String fecha;
  String tipo;
  // 'pendiente_confirmacion' = asignada, 'confirmado' = aceptada por vendedor
  String estado;

  // Campos extra para joins (no se guardan en la BD)
  String? nombreVendedor;
  String? nombrePerfume;

  EntregaVendedor({
    this.id,
    this.apiId,
    required this.vendedorId,
    required this.perfumeId,
    required this.cantidad,
    required this.precioUnitario,
    required this.fecha,
    this.tipo = 'entrega',
    this.estado = 'pendiente_confirmacion',
    this.nombreVendedor,
    this.nombrePerfume,
  });

  double get total => cantidad * precioUnitario;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'api_id': apiId,
      'vendedor_id': vendedorId,
      'perfume_id': perfumeId,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
      'fecha': fecha,
      'tipo': tipo,
      'estado': estado,
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

  factory EntregaVendedor.fromMap(Map<String, dynamic> map) {
    return EntregaVendedor(
      id: _asInt(map['id']) == 0 ? null : _asInt(map['id']),
      apiId: _asInt(map['api_id']) == 0 ? null : _asInt(map['api_id']),
      vendedorId: _asInt(map['vendedor_id']),
      perfumeId: _asInt(map['perfume_id']),
      cantidad: _asInt(map['cantidad']),
      precioUnitario: _asDouble(map['precio_unitario']),
      fecha: map['fecha']?.toString() ?? '',
      tipo: map['tipo']?.toString() ?? 'entrega',
      estado: map['estado'] ?? 'pendiente_confirmacion',
      nombreVendedor: map['nombre_vendedor'],
      nombrePerfume: map['nombre_perfume'],
    );
  }
}
