import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiConfig {
  // Puedes sobreescribirlo con:
  // flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8000/api
  static const String baseUrl = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'http://10.0.2.2:8000/api');
}

class VendedoresApiService {
  static String get _baseUrl => ApiConfig.baseUrl;

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  String _extractApiError(http.Response res, String fallback) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map<String, dynamic>) {
        final message = body['message']?.toString().trim();
        if (message != null && message.isNotEmpty) return message;

        final errors = body['errors'];
        if (errors is Map) {
          for (final value in errors.values) {
            if (value is List && value.isNotEmpty) {
              final msg = value.first?.toString().trim();
              if (msg != null && msg.isNotEmpty) return msg;
            }
            final msg = value?.toString().trim();
            if (msg != null && msg.isNotEmpty) return msg;
          }
        }
      }
    } catch (_) {
      // Si no es JSON, se usa fallback.
    }
    return fallback;
  }

  Future<List<Map<String, dynamic>>> obtenerPerfumes() async {
    final uri = Uri.parse('$_baseUrl/admin/perfumes');
    final res = await http.get(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as List<dynamic>;
      return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>?> crearPerfume({
    required String nombre,
    required String marca,
    required String descripcion,
    required double precioCosto,
    required double precioVenta,
    required int stock,
    String? imagePath,
  }) async {
    final uri = Uri.parse('$_baseUrl/admin/perfumes');
    final req = http.MultipartRequest('POST', uri)
      ..fields['nombre'] = nombre
      ..fields['marca'] = marca
      ..fields['descripcion'] = descripcion
      ..fields['precio_costo'] = precioCosto.toString()
      ..fields['precio_venta'] = precioVenta.toString()
      ..fields['stock'] = stock.toString();

    if (imagePath != null && imagePath.isNotEmpty) {
      req.files.add(await http.MultipartFile.fromPath('imagen', imagePath));
    }

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    }
    throw Exception(_extractApiError(res, 'No se pudo crear el perfume en la API'));
  }

  Future<Map<String, dynamic>?> actualizarPerfume({
    required int id,
    required String nombre,
    required String marca,
    required String descripcion,
    required double precioCosto,
    required double precioVenta,
    required int stock,
    String? imagePath,
  }) async {
    final uri = Uri.parse('$_baseUrl/admin/perfumes/$id');
    final req = http.MultipartRequest('POST', uri)
      ..fields['_method'] = 'PUT'
      ..fields['nombre'] = nombre
      ..fields['marca'] = marca
      ..fields['descripcion'] = descripcion
      ..fields['precio_costo'] = precioCosto.toString()
      ..fields['precio_venta'] = precioVenta.toString()
      ..fields['stock'] = stock.toString();

    if (imagePath != null && imagePath.isNotEmpty) {
      req.files.add(await http.MultipartFile.fromPath('imagen', imagePath));
    }

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    }
    throw Exception(_extractApiError(res, 'No se pudo actualizar el perfume en la API'));
  }

  Future<void> eliminarPerfume(int id) async {
    final uri = Uri.parse('$_baseUrl/admin/perfumes/$id');
    final res = await http.delete(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return;
    }

    String message = 'No se pudo eliminar el perfume';
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['message'] != null) {
        message = body['message'].toString();
      }
    } catch (_) {}
    throw Exception(message);
  }

  Future<List<Map<String, dynamic>>> obtenerVendedores() async {
    final uri = Uri.parse('$_baseUrl/admin/vendedores');
    final res = await http.get(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as List<dynamic>;
      return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>?> crearVendedor({
    required String nombre,
    required String telefono,
    required String email,
    required String direccion,
    required String usuario,
    required String password,
    List<Map<String, dynamic>>? initialEntregas,
  }) async {
    final uri = Uri.parse('$_baseUrl/admin/vendedores');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nombre': nombre,
        'telefono': telefono,
        'email': email,
        'direccion': direccion,
        'usuario': usuario,
        'password': password,
        if (initialEntregas != null && initialEntregas.isNotEmpty)
          'initial_entregas': initialEntregas,
      }),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    }
    return null;
  }

  Future<Map<String, dynamic>?> actualizarVendedor({
    required int apiId,
    required String nombre,
    required String telefono,
    required String email,
    required String direccion,
    required String usuario,
    String? password,
  }) async {
    final uri = Uri.parse('$_baseUrl/admin/vendedores/$apiId');
    final body = {
      'nombre': nombre,
      'telefono': telefono,
      'email': email,
      'direccion': direccion,
      'usuario': usuario,
      if (password != null && password.isNotEmpty) 'password': password,
    };
    final res = await http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    }
    return null;
  }

  Future<void> eliminarVendedor(int apiId) async {
    final uri = Uri.parse('$_baseUrl/admin/vendedores/$apiId');
    final res = await http.delete(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return;
    }

    String message = 'No se pudo eliminar el vendedor';
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['message'] != null) {
        message = body['message'].toString();
      }
    } catch (_) {
      // Mantener mensaje por defecto.
    }

    throw Exception(message);
  }

  Future<List<Map<String, dynamic>>> obtenerClientes({int? vendedorId}) async {
    final uri = vendedorId != null
        ? Uri.parse('$_baseUrl/admin/clientes?vendedor_id=$vendedorId')
        : Uri.parse('$_baseUrl/admin/clientes');
    final res = await http.get(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as List<dynamic>;
      return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>?> crearCliente({
    int? vendedorId,
    required String nombre,
    required String telefono,
    required String email,
    required String direccion,
  }) async {
    final uri = Uri.parse('$_baseUrl/admin/clientes');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'vendedor_id': vendedorId,
        'nombre': nombre,
        'telefono': telefono,
        'email': email,
        'direccion': direccion,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    }
    return null;
  }

  Future<Map<String, dynamic>?> actualizarCliente({
    required int id,
    int? vendedorId,
    required String nombre,
    required String telefono,
    required String email,
    required String direccion,
  }) async {
    final uri = Uri.parse('$_baseUrl/admin/clientes/$id');
    final res = await http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'vendedor_id': vendedorId,
        'nombre': nombre,
        'telefono': telefono,
        'email': email,
        'direccion': direccion,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    }
    return null;
  }

  Future<void> eliminarCliente(int id) async {
    final uri = Uri.parse('$_baseUrl/admin/clientes/$id');
    final res = await http.delete(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) return;

    String message = 'No se pudo eliminar el cliente';
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['message'] != null) {
        message = body['message'].toString();
      }
    } catch (_) {}
    throw Exception(message);
  }

  Future<List<Map<String, dynamic>>> obtenerEntregas({
    int? vendedorId,
    String? tipo,
  }) async {
    final params = <String, String>{};
    if (vendedorId != null) params['vendedor_id'] = vendedorId.toString();
    if (tipo != null && tipo.isNotEmpty) params['tipo'] = tipo;
    final uri = Uri.parse('$_baseUrl/admin/entregas')
        .replace(queryParameters: params.isEmpty ? null : params);
    final res = await http.get(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as List<dynamic>;
      return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> obtenerPedidos({
    int? vendedorId,
    String? tipo,
  }) async {
    final params = <String, String>{};
    if (vendedorId != null) params['vendedor_id'] = vendedorId.toString();
    if (tipo != null && tipo.isNotEmpty) params['tipo'] = tipo;
    final uri = Uri.parse('$_baseUrl/admin/pedidos')
        .replace(queryParameters: params.isEmpty ? null : params);
    final res = await http.get(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as List<dynamic>;
      return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<void> actualizarEstadoEntrega({
    required int id,
    required String estado,
    int? cantidad,
  }) async {
    final uri = Uri.parse('$_baseUrl/admin/entregas/$id/estado');
    final payload = <String, dynamic>{'estado': estado};
    if (cantidad != null) payload['cantidad'] = cantidad;
    final res = await http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    throw Exception('No se pudo actualizar el estado de entrega');
  }

  Future<void> eliminarEntrega(int id) async {
    final uri = Uri.parse('$_baseUrl/admin/entregas/$id');
    final res = await http.delete(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) return;

    String message = 'No se pudo eliminar la entrega';
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['message'] != null) {
        message = body['message'].toString();
      }
    } catch (_) {}

    throw Exception(message);
  }

  Future<List<Map<String, dynamic>>> obtenerVentas({
    int? vendedorId,
    int? clienteId,
  }) async {
    final params = <String, String>{};
    if (vendedorId != null) params['vendedor_id'] = vendedorId.toString();
    if (clienteId != null) params['cliente_id'] = clienteId.toString();
    final uri = Uri.parse('$_baseUrl/admin/ventas')
        .replace(queryParameters: params.isEmpty ? null : params);
    final res = await http.get(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as List<dynamic>;
      return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<int?> crearVenta({
    required int clienteId,
    int? vendedorId,
    String? tipoVenta,
    required String fecha,
    String? fechaPrimerPago,
    required String notas,
    int cantidadPagos = 1,
    String frecuenciaPago = 'quincenal',
    required List<Map<String, dynamic>> items,
  }) async {
    final uri = Uri.parse('$_baseUrl/admin/ventas');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'cliente_id': clienteId,
        'vendedor_id': vendedorId,
        if (tipoVenta != null && tipoVenta.isNotEmpty) 'tipo_venta': tipoVenta,
        'fecha': fecha,
        'fecha_primer_pago': fechaPrimerPago,
        'notas': notas,
        'cantidad_pagos': cantidadPagos,
        'frecuencia_pago': frecuenciaPago,
        'items': items,
      }),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
      return _toInt(body['id']);
    }

    String message = 'No se pudo registrar la venta';
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['message'] != null) {
        message = body['message'].toString();
      }
    } catch (_) {}
    throw Exception(message);
  }

  Future<List<Map<String, dynamic>>> obtenerDetallesVenta(int ventaId) async {
    final uri = Uri.parse('$_baseUrl/admin/ventas/$ventaId/detalles');
    final res = await http.get(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as List<dynamic>;
      return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> obtenerPagosVenta(int ventaId) async {
    final uri = Uri.parse('$_baseUrl/admin/ventas/$ventaId/pagos');
    final res = await http.get(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as List<dynamic>;
      return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<void> registrarPagoVenta({
    required int ventaId,
    required double monto,
    required String fecha,
    required String notas,
    String? comisionTipo,
    double? comisionValor,
  }) async {
    final uri = Uri.parse('$_baseUrl/admin/ventas/$ventaId/pagos');
    final payload = <String, dynamic>{
      'monto': monto,
      'fecha': fecha,
      'notas': notas,
    };
    if (comisionTipo != null && comisionTipo.isNotEmpty) {
      payload['comision_tipo'] = comisionTipo;
      payload['comision_valor'] = comisionValor ?? 0;
    }

    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) return;

    String message = 'No se pudo registrar el pago';
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['message'] != null) {
        message = body['message'].toString();
      }
    } catch (_) {}
    throw Exception(message);
  }

  Future<Map<String, dynamic>> obtenerResumen() async {
    final uri = Uri.parse('$_baseUrl/admin/resumen');
    final res = await http.get(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    }
    return {
      'totalPerfumes': 0,
      'totalVendedores': 0,
      'totalClientes': 0,
      'ventasPendientes': 0,
      'saldoPendiente': 0,
      'entregasPendientes': 0,
    };
  }

  Future<List<Map<String, dynamic>>> obtenerVentasPorVendedor() async {
    final uri = Uri.parse('$_baseUrl/admin/ventas-por-vendedor');
    final res = await http.get(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as List<dynamic>;
      return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> obtenerSaldoVendedor({
    int? vendedorId,
  }) async {
    final params = <String, String>{};
    if (vendedorId != null) params['vendedor_id'] = vendedorId.toString();
    final uri = Uri.parse('$_baseUrl/admin/saldo-vendedor')
        .replace(queryParameters: params.isEmpty ? null : params);
    final res = await http.get(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as List<dynamic>;
      return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> obtenerPagosVendedorPorConfirmar({
    int? vendedorId,
  }) async {
    final params = <String, String>{};
    if (vendedorId != null) params['vendedor_id'] = vendedorId.toString();
    final uri = Uri.parse('$_baseUrl/admin/saldo-vendedor/pagos-por-confirmar')
        .replace(queryParameters: params.isEmpty ? null : params);
    final res = await http.get(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as List<dynamic>;
      return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<void> confirmarPagoVendedor(int pagoId) async {
    final uri =
        Uri.parse('$_baseUrl/admin/saldo-vendedor/pagos/$pagoId/confirmar');
    final res = await http.post(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) return;

    String message = 'No se pudo confirmar el pago';
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['message'] != null) {
        message = body['message'].toString();
      }
    } catch (_) {}
    throw Exception(message);
  }

  Future<List<Map<String, dynamic>>> obtenerComisionesPerfumesVendidos() async {
    final uri = Uri.parse('$_baseUrl/admin/comisiones/perfumes-vendidos');
    final res = await http.get(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as List<dynamic>;
      return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<void> guardarComisionPerfume({
    required int vendedorId,
    required int perfumeId,
    required String comisionTipo,
    required double comisionValor,
  }) async {
    final uri = Uri.parse('$_baseUrl/admin/comisiones');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'vendedor_id': vendedorId,
        'perfume_id': perfumeId,
        'comision_tipo': comisionTipo,
        'comision_valor': comisionValor,
      }),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) return;

    String message = 'No se pudo guardar la comisión';
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['message'] != null) {
        message = body['message'].toString();
      }
    } catch (_) {}
    throw Exception(message);
  }

  Future<void> pagarComisionPerfume({
    required int vendedorId,
    required int perfumeId,
    required double monto,
  }) async {
    final uri = Uri.parse('$_baseUrl/admin/comisiones/pagar');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'vendedor_id': vendedorId,
        'perfume_id': perfumeId,
        'monto': monto,
      }),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) return;

    String message = 'No se pudo marcar la comision como pagada';
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['message'] != null) {
        message = body['message'].toString();
      }
    } catch (_) {}
    throw Exception(message);
  }

  Future<int?> crearEntrega({
    required int vendedorId,
    required int perfumeId,
    String tipo = 'entrega',
    required int cantidad,
    required double precioUnitario,
    required String fecha,
    String estado = 'pendiente_confirmacion',
  }) async {
    final uri = Uri.parse('$_baseUrl/admin/entregas');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'vendedor_id': vendedorId,
        'perfume_id': perfumeId,
        'tipo': tipo,
        'cantidad': cantidad,
        'precio_unitario': precioUnitario,
        'fecha': fecha,
        'estado': estado,
      }),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['id'] as int?;
    }

    return null;
  }

  Future<void> solicitarPedidos({
    required int vendedorId,
    required List<Map<String, dynamic>> items,
    required String fecha,
  }) async {
    final uri = Uri.parse('$_baseUrl/vendedor/$vendedorId/pedidos');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'fecha': fecha,
        'items': items,
      }),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) return;

    String message = 'No se pudo solicitar el pedido';
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['message'] != null) {
        message = body['message'].toString();
      }
    } catch (_) {}
    throw Exception(message);
  }

  Future<List<Map<String, dynamic>>> obtenerPedidosVendedor(int vendedorId,
      {String? tipo}) async {
    final params = <String, String>{};
    if (tipo != null && tipo.isNotEmpty) params['tipo'] = tipo;
    final uri = Uri.parse('$_baseUrl/vendedor/$vendedorId/pedidos')
        .replace(queryParameters: params.isEmpty ? null : params);
    final res = await http.get(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as List<dynamic>;
      return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> obtenerCatalogoPedidosVendedor(
      int vendedorId,
      {String? tipo}) async {
    final params = <String, String>{};
    if (tipo != null && tipo.isNotEmpty) params['tipo'] = tipo;
    final uri = Uri.parse('$_baseUrl/vendedor/$vendedorId/pedidos/perfumes')
        .replace(queryParameters: params.isEmpty ? null : params);
    final res = await http.get(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as List<dynamic>;
      return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<String?> obtenerEstadoEntrega(int apiEntregaId) async {
    final uri = Uri.parse('$_baseUrl/admin/entregas/$apiEntregaId');
    final res = await http.get(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['estado']?.toString();
    }
    return null;
  }

  Future<bool> confirmarEntrega(int apiEntregaId) async {
    final uri =
        Uri.parse('$_baseUrl/vendedor/entregas/$apiEntregaId/confirmar');
    final res = await http.post(uri);
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  Future<List<Map<String, dynamic>>> obtenerStockVendedor(
      int vendedorId) async {
    final uri = Uri.parse('$_baseUrl/vendedor/$vendedorId/stock');
    final res = await http.get(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as List<dynamic>;
      return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> obtenerPerfumesDisponiblesVendedor(
      int vendedorId) async {
    final uri =
        Uri.parse('$_baseUrl/vendedor/$vendedorId/perfumes-disponibles');
    final res = await http.get(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as List<dynamic>;
      return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }
}
