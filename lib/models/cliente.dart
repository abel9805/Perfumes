class Cliente {
  int? id;
  int? vendedorId;
  String nombre;
  String telefono;
  String email;
  String direccion;

  Cliente({
    this.id,
    this.vendedorId,
    required this.nombre,
    this.telefono = '',
    this.email = '',
    this.direccion = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendedor_id': vendedorId,
      'nombre': nombre,
      'telefono': telefono,
      'email': email,
      'direccion': direccion,
    };
  }

  factory Cliente.fromMap(Map<String, dynamic> map) {
    return Cliente(
      id: map['id'],
      vendedorId: map['vendedor_id'],
      nombre: map['nombre'],
      telefono: map['telefono'] ?? '',
      email: map['email'] ?? '',
      direccion: map['direccion'] ?? '',
    );
  }
}
