class VentaCredito {
  int? id;
  int clienteId;
  int? vendedorId;
  String fecha;
  String? fechaPrimerPago;
  double montoTotal;
  double montoPagado;
  // 'pendiente' | 'parcial' | 'pagado'
  String estado;
  String notas;
  int cantidadPagos;
  String frecuenciaPago;

  // Campos extra para joins
  String? nombreCliente;
  String? nombreVendedor;

  VentaCredito({
    this.id,
    required this.clienteId,
    this.vendedorId,
    required this.fecha,
    this.fechaPrimerPago,
    required this.montoTotal,
    this.montoPagado = 0,
    this.estado = 'pendiente',
    this.notas = '',
    this.cantidadPagos = 1,
    this.frecuenciaPago = 'quincenal',
    this.nombreCliente,
    this.nombreVendedor,
  });

  double get saldoPendiente => montoTotal - montoPagado;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cliente_id': clienteId,
      'vendedor_id': vendedorId,
      'fecha': fecha,
      'fecha_primer_pago': fechaPrimerPago,
      'monto_total': montoTotal,
      'monto_pagado': montoPagado,
      'estado': estado,
      'notas': notas,
      'cantidad_pagos': cantidadPagos,
      'frecuencia_pago': frecuenciaPago,
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

  factory VentaCredito.fromMap(Map<String, dynamic> map) {
    return VentaCredito(
      id: _asInt(map['id']) == 0 ? null : _asInt(map['id']),
      clienteId: _asInt(map['cliente_id']),
      vendedorId:
          map['vendedor_id'] == null ? null : _asInt(map['vendedor_id']),
      fecha: map['fecha']?.toString() ?? '',
      fechaPrimerPago: map['fecha_primer_pago']?.toString(),
      montoTotal: _asDouble(map['monto_total']),
      montoPagado: _asDouble(map['monto_pagado']),
      estado: map['estado'] ?? 'pendiente',
      notas: map['notas'] ?? '',
      cantidadPagos: _asInt(map['cantidad_pagos']) <= 0
          ? 1
          : _asInt(map['cantidad_pagos']),
      frecuenciaPago: map['frecuencia_pago']?.toString().isNotEmpty == true
          ? map['frecuencia_pago'].toString()
          : 'quincenal',
      nombreCliente: map['nombre_cliente'],
      nombreVendedor: map['nombre_vendedor'],
    );
  }
}
