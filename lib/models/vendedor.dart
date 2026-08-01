class Vendedor {
  int? id;
  int? apiId;
  String nombre;
  String telefono;
  String email;
  String direccion;
  String usuario;
  String password;
  String tipoUsuario;
  String? fechaRegistro;
  String nivelEmbajador;
  double descuentoCredito;
  double descuentoContado;
  double totalVentasMensual;
  double totalVentasAnual;

  Vendedor({
    this.id,
    this.apiId,
    required this.nombre,
    this.telefono = '',
    this.email = '',
    this.direccion = '',
    this.usuario = '',
    this.password = '',
    this.tipoUsuario = 'vendedor',
    this.fechaRegistro,
    this.nivelEmbajador = '',
    this.descuentoCredito = 0,
    this.descuentoContado = 0,
    this.totalVentasMensual = 0,
    this.totalVentasAnual = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'api_id': apiId,
      'nombre': nombre,
      'telefono': telefono,
      'email': email,
      'direccion': direccion,
      'usuario': usuario,
      'password': password,
      'tipo_usuario': tipoUsuario,
      'fecha_registro': fechaRegistro,
      'nivel_embajador': nivelEmbajador,
      'descuento_credito': descuentoCredito,
      'descuento_contado': descuentoContado,
      'total_ventas_mensual': totalVentasMensual,
      'total_ventas_anual': totalVentasAnual,
    };
  }

  static double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  factory Vendedor.fromMap(Map<String, dynamic> map) {
    return Vendedor(
      id: map['id'],
      apiId: map['api_id'],
      nombre: map['nombre'],
      telefono: map['telefono'] ?? '',
      email: map['email'] ?? '',
      direccion: map['direccion'] ?? '',
      usuario: map['usuario'] ?? '',
      password: map['password'] ?? '',
      tipoUsuario: map['tipo_usuario']?.toString().trim().isNotEmpty == true
          ? map['tipo_usuario'].toString()
          : 'vendedor',
      fechaRegistro:
          map['fecha_registro']?.toString() ?? map['created_at']?.toString(),
      nivelEmbajador: map['nivel_embajador']?.toString() ?? '',
      descuentoCredito: _asDouble(map['descuento_credito']),
      descuentoContado: _asDouble(map['descuento_contado']),
      totalVentasMensual: _asDouble(map['total_ventas_mensual']),
      totalVentasAnual: _asDouble(map['total_ventas_anual']),
    );
  }
}
