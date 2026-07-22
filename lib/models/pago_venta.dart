class PagoVenta {
  int? id;
  int ventaId;
  double monto;
  String fecha;
  String notas;
  String? comisionTipo;
  double comisionValor;
  double comisionTotal;

  PagoVenta({
    this.id,
    required this.ventaId,
    required this.monto,
    required this.fecha,
    this.notas = '',
    this.comisionTipo,
    this.comisionValor = 0,
    this.comisionTotal = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'venta_id': ventaId,
      'monto': monto,
      'fecha': fecha,
      'notas': notas,
      'comision_tipo': comisionTipo,
      'comision_valor': comisionValor,
      'comision_total': comisionTotal,
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

  factory PagoVenta.fromMap(Map<String, dynamic> map) {
    return PagoVenta(
      id: _asInt(map['id']) == 0 ? null : _asInt(map['id']),
      ventaId: _asInt(map['venta_id']),
      monto: _asDouble(map['monto']),
      fecha: map['fecha']?.toString() ?? '',
      notas: map['notas'] ?? '',
      comisionTipo: map['comision_tipo']?.toString(),
      comisionValor: _asDouble(map['comision_valor']),
      comisionTotal: _asDouble(map['comision_total']),
    );
  }
}
