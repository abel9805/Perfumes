import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const VendedoresApp());
}

class VendedoresApp extends StatelessWidget {
  const VendedoresApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OVORA EMBAJADOR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.purple,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(elevation: 2),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.ovora.lat/api',
  );
}

class ApiService {
  static const Duration _requestTimeout = Duration(seconds: 20);

  String _extractErrorMessage(http.Response res, String fallback) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['message'] != null) {
        return body['message'].toString();
      }
    } catch (_) {
      // Mantener fallback.
    }
    return fallback;
  }

  Future<Map<String, dynamic>> login({
    required String usuario,
    required String password,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/vendedor/login');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'usuario': usuario, 'password': password}),
        )
        .timeout(_requestTimeout);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    }

    throw Exception('Login invalido');
  }

  Future<List<Map<String, dynamic>>> getPendientes(
    int vendedorId, {
    String? tipo,
  }) async {
    final params = <String, String>{};
    if (tipo != null && tipo.isNotEmpty) params['tipo'] = tipo;
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/vendedor/$vendedorId/pendientes',
    ).replace(queryParameters: params.isEmpty ? null : params);
    final res = await http.get(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as List<dynamic>;
      return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    throw Exception('Error cargando pendientes');
  }

  Future<List<Map<String, dynamic>>> getPedidos(int vendedorId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/vendedor/$vendedorId/pedidos');
    final res = await http.get(uri).timeout(_requestTimeout);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as List<dynamic>;
      return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    throw Exception('Error cargando pedidos');
  }

  Future<void> confirmarEntrega(int entregaId) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/vendedor/entregas/$entregaId/confirmar',
    );
    final res = await http.post(uri);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('No se pudo confirmar');
    }
  }

  Future<List<Map<String, dynamic>>> getStock(
    int vendedorId, {
    String tipo = 'todos',
  }) async {
    final params = <String, String>{};
    if (tipo.isNotEmpty) params['tipo'] = tipo;
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/vendedor/$vendedorId/stock',
    ).replace(queryParameters: params.isEmpty ? null : params);
    final res = await http.get(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as List<dynamic>;
      return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    throw Exception('Error cargando stock');
  }

  Future<List<Map<String, dynamic>>> getPerfumesDisponibles(
    int vendedorId,
  ) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/vendedor/$vendedorId/perfumes-disponibles',
    );
    final res = await http.get(uri).timeout(_requestTimeout);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as List<dynamic>;
      return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    throw Exception(
      _extractErrorMessage(res, 'Error cargando perfumes disponibles'),
    );
  }

  Future<List<Map<String, dynamic>>> getCatalogoPedidos(int vendedorId) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/vendedor/$vendedorId/pedidos/perfumes',
    );
    final res = await http.get(uri).timeout(_requestTimeout);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as List<dynamic>;
      return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    throw Exception(_extractErrorMessage(res, 'Error cargando catalogo'));
  }

  Future<List<Map<String, dynamic>>> getClientes(int vendedorId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/vendedor/$vendedorId/clientes');
    final res = await http.get(uri).timeout(_requestTimeout);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as List<dynamic>;
      return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    throw Exception(_extractErrorMessage(res, 'Error cargando clientes'));
  }

  Future<void> crearCliente({
    required int vendedorId,
    required String nombre,
    required String telefono,
    required String email,
    required String direccion,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/vendedor/$vendedorId/clientes');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nombre': nombre,
        'telefono': telefono,
        'email': email,
        'direccion': direccion,
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('No se pudo crear el cliente');
    }
  }

  Future<void> actualizarCliente({
    required int vendedorId,
    required int clienteId,
    required String nombre,
    required String telefono,
    required String email,
    required String direccion,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/vendedor/$vendedorId/clientes/$clienteId',
    );
    final res = await http
        .put(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'nombre': nombre,
            'telefono': telefono,
            'email': email,
            'direccion': direccion,
          }),
        )
        .timeout(_requestTimeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        _extractErrorMessage(res, 'No se pudo actualizar el cliente'),
      );
    }
  }

  Future<void> eliminarCliente({
    required int vendedorId,
    required int clienteId,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/vendedor/$vendedorId/clientes/$clienteId',
    );
    final res = await http.delete(uri).timeout(_requestTimeout);
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    throw Exception(
      _extractErrorMessage(res, 'No se pudo eliminar el cliente'),
    );
  }

  Future<List<Map<String, dynamic>>> getVentas(int vendedorId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/vendedor/$vendedorId/ventas');
    final res = await http.get(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as List<dynamic>;
      return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    throw Exception('Error cargando ventas');
  }

  Future<Map<String, dynamic>> getInformacionVendedor(int vendedorId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/vendedor/$vendedorId/informacion');
    final res = await http.get(uri).timeout(_requestTimeout);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    }
    throw Exception(_extractErrorMessage(res, 'Error cargando informacion'));
  }

  Future<Map<String, dynamic>> getComisiones(int vendedorId) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/vendedor/$vendedorId/comisiones',
    );
    final res = await http.get(uri).timeout(_requestTimeout);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    }
    throw Exception(_extractErrorMessage(res, 'Error cargando comisiones'));
  }

  Future<List<Map<String, dynamic>>> getSaldoPorPagar(int vendedorId) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/vendedor/$vendedorId/saldo-por-pagar',
    );
    final res = await http.get(uri).timeout(_requestTimeout);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as List<dynamic>;
      return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    throw Exception(_extractErrorMessage(res, 'Error cargando saldo por pagar'));
  }

  Future<void> pagarSaldoPorVenta({
    required int vendedorId,
    required int ventaId,
    required double monto,
    String? fecha,
    String? nota,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/vendedor/$vendedorId/saldo-por-pagar/$ventaId/pagar',
    );
    final payload = <String, dynamic>{'monto': monto};
    if (fecha != null && fecha.isNotEmpty) payload['fecha'] = fecha;
    if (nota != null && nota.isNotEmpty) payload['nota'] = nota;

    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(_requestTimeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        _extractErrorMessage(
          res,
          'No se pudo enviar el pago a confirmacion',
        ),
      );
    }
  }

  Future<void> cobrarComision({
    required int vendedorId,
    required int perfumeId,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/vendedor/$vendedorId/comisiones/cobrar',
    );
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'perfume_id': perfumeId}),
        )
        .timeout(_requestTimeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        _extractErrorMessage(res, 'No se pudo marcar la comision como cobrada'),
      );
    }
  }

  Future<List<Map<String, dynamic>>> getDetallesVenta({
    required int vendedorId,
    required int ventaId,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/vendedor/$vendedorId/ventas/$ventaId/detalles',
    );
    final res = await http.get(uri).timeout(_requestTimeout);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as List<dynamic>;
      return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    throw Exception(
      _extractErrorMessage(res, 'Error cargando detalles de venta'),
    );
  }

  Future<List<Map<String, dynamic>>> getPagosVenta({
    required int vendedorId,
    required int ventaId,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/vendedor/$vendedorId/ventas/$ventaId/pagos',
    );
    final res = await http.get(uri).timeout(_requestTimeout);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as List<dynamic>;
      return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    throw Exception(_extractErrorMessage(res, 'Error cargando pagos'));
  }

  Future<void> registrarPagoVenta({
    required int vendedorId,
    required int ventaId,
    required double monto,
    required String fecha,
    String? notas,
    String? comisionTipo,
    double? comisionValor,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/vendedor/$vendedorId/ventas/$ventaId/pagos',
    );
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'monto': monto,
            'fecha': fecha,
            'notas': notas,
            if (comisionTipo != null && comisionTipo.isNotEmpty)
              'comision_tipo': comisionTipo,
            if (comisionValor != null && comisionValor > 0)
              'comision_valor': comisionValor,
          }),
        )
        .timeout(_requestTimeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        _extractErrorMessage(res, 'No se pudo registrar el pago'),
      );
    }
  }

  Future<int> crearVenta({
    required int vendedorId,
    required int clienteId,
    String? tipoVenta,
    required String fecha,
    String? fechaPrimerPago,
    int? cantidadPagos,
    String? frecuenciaPago,
    required String notas,
    required List<Map<String, dynamic>> items,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/vendedor/$vendedorId/ventas');
    final payload = <String, dynamic>{
      'cliente_id': clienteId,
      if (tipoVenta != null && tipoVenta.isNotEmpty) 'tipo_venta': tipoVenta,
      'fecha': fecha,
      'notas': notas,
      'items': items,
    };
    if (fechaPrimerPago != null && fechaPrimerPago.isNotEmpty) {
      payload['fecha_primer_pago'] = fechaPrimerPago;
    }
    if (cantidadPagos != null) {
      payload['cantidad_pagos'] = cantidadPagos;
    }
    if (frecuenciaPago != null && frecuenciaPago.isNotEmpty) {
      payload['frecuencia_pago'] = frecuenciaPago;
    }

    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(_requestTimeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        _extractErrorMessage(res, 'No se pudo registrar la venta'),
      );
    }

    final body = jsonDecode(res.body);
    if (body is Map && body['id'] != null) {
      return (body['id'] as num).toInt();
    }

    throw Exception('La API no devolvio el id de la venta');
  }

  Future<void> solicitarPedidos({
    required int vendedorId,
    required String fecha,
    required List<Map<String, dynamic>> items,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/vendedor/$vendedorId/pedidos');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'fecha': fecha, 'items': items}),
        )
        .timeout(_requestTimeout);

    if (res.statusCode >= 200 && res.statusCode < 300) return;

    throw Exception(
      _extractErrorMessage(res, 'No se pudo solicitar el pedido'),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usuarioCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _api = ApiService();
  bool _loading = false;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final vendedor = await _api.login(
        usuario: _usuarioCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeVendedorScreen(vendedor: vendedor),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Credenciales invalidas o sin conexion API'),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ingreso vendedor'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _usuarioCtrl,
                decoration: const InputDecoration(labelText: 'Usuario'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa un usuario valido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordCtrl,
                decoration: const InputDecoration(labelText: 'Contraseña'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Requerido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Entrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeVendedorScreen extends StatefulWidget {
  final Map<String, dynamic> vendedor;

  const HomeVendedorScreen({super.key, required this.vendedor});

  @override
  State<HomeVendedorScreen> createState() => _HomeVendedorScreenState();
}

class _HomeVendedorScreenState extends State<HomeVendedorScreen> {
  int _index = 0;
  int _reloadToken = 0;

  static const List<String> _titles = [
    'Entregas pendientes',
    'Stock disponible',
    'Pedidos',
    'Clientes',
    'Ventas',
    'Saldo por pagar',
    'Comisiones',
    'Informacion',
  ];

  Color _sectionColor() {
    switch (_index) {
      case 0:
        return Colors.green.shade700;
      case 1:
        return Colors.teal.shade700;
      case 2:
        return Colors.blue.shade700;
      case 3:
        return Colors.teal.shade700;
      case 4:
        return Colors.orange.shade700;
      case 5:
        return Colors.deepOrange.shade700;
      case 6:
        return Colors.indigo.shade700;
      case 7:
        return Colors.brown.shade700;
      default:
        return Colors.indigo.shade700;
    }
  }

  void _refreshAll() {
    setState(() => _reloadToken++);
  }

  void _goToSection(int index) {
    Navigator.pop(context);
    if (_index == index) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final vendedorId = widget.vendedor['id'] as int;
    final vendedorNombre = widget.vendedor['nombre']?.toString() ?? 'Vendedor';
    final vendedorUsuario = widget.vendedor['usuario']?.toString() ?? '';
    double asDouble(dynamic value) {
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    final nivelEmbajador = widget.vendedor['nivel_embajador']?.toString() ?? '-';
    final descuentoCredito = asDouble(widget.vendedor['descuento_credito']);
    final descuentoContado = asDouble(widget.vendedor['descuento_contado']);
    final totalMensual = asDouble(widget.vendedor['total_ventas_mensual']);
    final totalAnual = asDouble(widget.vendedor['total_ventas_anual']);
    final partesNombre = vendedorNombre
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
    final iniciales = partesNombre.isEmpty
      ? 'V'
      : partesNombre
        .take(2)
        .map((p) => p.substring(0, 1).toUpperCase())
        .join();
    final screens = [
      PendientesScreen(
        vendedorId: vendedorId,
        reloadToken: _reloadToken,
        onChanged: _refreshAll,
        tipoFiltro: 'todos',
        titulo: 'Entregas pendientes',
      ),
      StockScreen(
        vendedorId: vendedorId,
        reloadToken: _reloadToken,
        tipoFiltro: 'todos',
        titulo: 'Stock disponible',
      ),
      PedidosScreen(
        vendedorId: vendedorId,
        reloadToken: _reloadToken,
        onChanged: _refreshAll,
      ),
      ClientesScreen(
        vendedorId: vendedorId,
        reloadToken: _reloadToken,
        onChanged: _refreshAll,
      ),
      VentasScreen(
        vendedorId: vendedorId,
        vendedor: widget.vendedor,
        reloadToken: _reloadToken,
        onChanged: _refreshAll,
      ),
      SaldoPorPagarScreen(
        vendedorId: vendedorId,
        reloadToken: _reloadToken,
        onChanged: _refreshAll,
      ),
      ComisionesScreen(vendedorId: vendedorId, reloadToken: _reloadToken),
      InformacionScreen(
        vendedorId: vendedorId,
        vendedor: widget.vendedor,
        reloadToken: _reloadToken,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('${_titles[_index]} · ${widget.vendedor['nombre']}'),
        backgroundColor: _sectionColor(),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListTileTheme(
          selectedColor: _sectionColor(),
          selectedTileColor: _sectionColor().withValues(alpha: 0.12),
          iconColor: Colors.black87,
          textColor: Colors.black87,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_sectionColor(), _sectionColor().withValues(alpha: 0.75)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white,
                      foregroundColor: _sectionColor(),
                      child: Text(
                        iniciales,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      vendedorNombre,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (vendedorUsuario.trim().isNotEmpty)
                      Text(
                        '@$vendedorUsuario',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Nivel: $nivelEmbajador',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Desc: Cred ${descuentoCredito.toStringAsFixed(0)}% · Cont ${descuentoContado.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ventas: Mes \$${totalMensual.toStringAsFixed(0)} · Año \$${totalAnual.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.pending_actions),
                title: const Text('Pendientes'),
                selected: _index == 0,
                onTap: () => _goToSection(0),
              ),
              ListTile(
                leading: const Icon(Icons.inventory_2),
                title: const Text('Stock'),
                selected: _index == 1,
                onTap: () => _goToSection(1),
              ),
              ListTile(
                leading: const Icon(Icons.local_shipping),
                title: const Text('Pedidos'),
                selected: _index == 2,
                onTap: () => _goToSection(2),
              ),
              ListTile(
                leading: const Icon(Icons.people_alt),
                title: const Text('Clientes'),
                selected: _index == 3,
                onTap: () => _goToSection(3),
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long),
                title: const Text('Ventas'),
                selected: _index == 4,
                onTap: () => _goToSection(4),
              ),
              ListTile(
                leading: const Icon(Icons.price_check),
                title: const Text('Saldo por pagar'),
                selected: _index == 5,
                onTap: () => _goToSection(5),
              ),
              ListTile(
                leading: const Icon(Icons.percent),
                title: const Text('Comisiones'),
                selected: _index == 6,
                onTap: () => _goToSection(6),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Informacion'),
                selected: _index == 7,
                onTap: () => _goToSection(7),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Cerrar sesión'),
                onTap: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
      body: screens[_index],
    );
  }
}

class SaldoPorPagarScreen extends StatefulWidget {
  final int vendedorId;
  final int reloadToken;
  final VoidCallback? onChanged;

  const SaldoPorPagarScreen({
    super.key,
    required this.vendedorId,
    required this.reloadToken,
    this.onChanged,
  });

  @override
  State<SaldoPorPagarScreen> createState() => _SaldoPorPagarScreenState();
}

class _SaldoPorPagarScreenState extends State<SaldoPorPagarScreen> {
  final _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatDate(String? value) {
    final dt = DateTime.tryParse((value ?? '').trim());
    if (dt == null) return value ?? '-';
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yy = dt.year.toString();
    return '$dd/$mm/$yy';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SaldoPorPagarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getSaldoPorPagar(widget.vendedorId);
      if (!mounted) return;
      setState(() {
        _items = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _pagar(Map<String, dynamic> item) async {
    final ventaId = _toInt(item['venta_id']);
    if (ventaId <= 0) return;

    final montoDisponible = _toDouble(item['monto_disponible_pagar']);
        if (montoDisponible <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta venta ya tiene pagos pendientes por confirmar'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar solicitud de pago'),
            content: Text(
              'Se enviara a admin la solicitud por \$${montoDisponible.toStringAsFixed(2)} para confirmar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Pagar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _api.pagarSaldoPorVenta(
        vendedorId: widget.vendedorId,
        ventaId: ventaId,
        monto: montoDisponible,
      );
      if (!mounted) return;
      widget.onChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pago enviado. Estado: pendiente de confirmacion'),
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final grupos = <String, List<Map<String, dynamic>>>{};
    for (final item in _items) {
      final key = (item['fecha'] ?? '').toString();
      grupos.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(item);
    }

    final entries = grupos.entries.toList()
      ..sort((a, b) {
        final ad = DateTime.tryParse(a.key) ?? DateTime(1900);
        final bd = DateTime.tryParse(b.key) ?? DateTime(1900);
        return bd.compareTo(ad);
      });

    final totalSaldo = _items.fold<double>(
      0,
      (sum, item) => sum + _toDouble(item['saldo_pendiente']),
    );
    final totalPendienteConfirmar = _items.fold<double>(
      0,
      (sum, item) => sum + _toDouble(item['monto_pendiente_confirmar']),
    );

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Saldo por pagar',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text('Saldo total: \$${totalSaldo.toStringAsFixed(2)}'),
                  Text(
                    'Pendiente confirmar: \$${totalPendienteConfirmar.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.deepOrange.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(
                child: Text('No hay ventas con saldo pendiente.'),
              ),
            )
          else
            ...entries.map((group) {
              final subtotal = group.value.fold<double>(
                0,
                (sum, item) => sum + _toDouble(item['saldo_pendiente']),
              );

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fecha: ${_formatDate(group.key)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Subtotal saldo: \$${subtotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.deepOrange.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...group.value.map((item) {
                        final ventaId = _toInt(item['venta_id']);
                        final nombreCliente =
                            (item['nombre_cliente'] ?? 'Cliente').toString();
                        final saldo = _toDouble(item['saldo_pendiente']);
                        final montoPendiente =
                            _toDouble(item['monto_pendiente_confirmar']);
                        final montoDisponible =
                            _toDouble(item['monto_disponible_pagar']);
                        final fechaPrimerPago =
                          _formatDate(item['fecha_primer_pago']?.toString());
                        final montoCorrespondiente =
                          _toDouble(item['monto_pago_correspondiente']);
                        final montoAbonos =
                          _toDouble(item['monto_abonos_ventas']);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Venta #$ventaId · $nombreCliente',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text('Saldo de la venta: \$${saldo.toStringAsFixed(2)}'),
                              Text('Primer pago: $fechaPrimerPago'),
                              Text(
                                'Pago correspondiente (fecha): \$${montoCorrespondiente.toStringAsFixed(2)}',
                              ),
                              Text(
                                'Abonos registrados: \$${montoAbonos.toStringAsFixed(2)}',
                              ),
                              Text(
                                'Pendiente confirmar: \$${montoPendiente.toStringAsFixed(2)}',
                              ),
                              Text(
                                'Disponible para pagar: \$${montoDisponible.toStringAsFixed(2)}',
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton.icon(
                                  onPressed: montoDisponible > 0
                                      ? () => _pagar(item)
                                      : null,
                                  icon: const Icon(Icons.payments, size: 18),
                                  label: Text(
                                    montoDisponible > 0
                                        ? 'Pagar'
                                        : 'Pendiente confirmacion',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class ComisionesScreen extends StatefulWidget {
  final int vendedorId;
  final int reloadToken;

  const ComisionesScreen({
    super.key,
    required this.vendedorId,
    required this.reloadToken,
  });

  @override
  State<ComisionesScreen> createState() => _ComisionesScreenState();
}

class _ComisionesScreenState extends State<ComisionesScreen> {
  final _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];
  double _totalComisiones = 0;
  String _filtroEstado = 'todas';

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _estadoPagoLabel(String estado) {
    switch (estado) {
      case 'por_confirmar':
        return 'Pendiente por confirmar';
      case 'cobrado':
        return 'Cobrado';
      default:
        return 'Por pagar';
    }
  }

  Color _estadoPagoColor(String estado) {
    switch (estado) {
      case 'por_confirmar':
        return Colors.orange.shade700;
      case 'cobrado':
        return Colors.green.shade700;
      default:
        return Colors.blue.shade700;
    }
  }

  Future<void> _cobrar(Map<String, dynamic> item) async {
    final perfumeId = _toInt(item['perfume_id']);
    if (perfumeId <= 0) return;

    try {
      await _api.cobrarComision(
        vendedorId: widget.vendedorId,
        perfumeId: perfumeId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comision cobrada correctamente')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ComisionesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getComisiones(widget.vendedorId);
      final itemsRaw = data['items'];
      final items = itemsRaw is List<dynamic>
          ? itemsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() {
        _items = items;
        _totalComisiones = _toDouble(data['total_comisiones']);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final itemsFiltrados = _items.where((item) {
      final recibida = _toDouble(item['comision_recibida']);
      final estadoPago = item['estado_pago']?.toString() ?? 'por_pagar';
      if (_filtroEstado == 'por_pagar') {
        return recibida > 0 && estadoPago == 'por_confirmar';
      }
      if (_filtroEstado == 'pagadas') return estadoPago == 'cobrado';
      return true;
    }).toList();

    final totalFiltrado = itemsFiltrados.fold<double>(
      0,
      (sum, item) => sum + _toDouble(item['comision_recibida']),
    );

    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 180),
            Center(child: Text('Aun no tienes perfumes vendidos con comision')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Todas'),
                  selected: _filtroEstado == 'todas',
                  onSelected: (_) => setState(() => _filtroEstado = 'todas'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Por cobrar'),
                  selected: _filtroEstado == 'por_pagar',
                  onSelected: (_) =>
                      setState(() => _filtroEstado = 'por_pagar'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Pagadas'),
                  selected: _filtroEstado == 'pagadas',
                  onSelected: (_) => setState(() => _filtroEstado = 'pagadas'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (itemsFiltrados.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: Text('No hay comisiones para ese filtro')),
            )
          else
            ...itemsFiltrados.map((item) {
              final cantidad = _toInt(item['cantidad_vendida']);
              final monto = _toDouble(item['monto_vendido']);
              final proximaFechaComision = item['proxima_fecha_comision']
                  ?.toString();
              final tipo = item['comision_tipo']?.toString();
              final valor = _toDouble(item['comision_valor']);
                final precioLista = _toDouble(item['precio_lista']);
              final recibida = _toDouble(item['comision_recibida']);
              final estadoPago = item['estado_pago']?.toString() ?? 'por_pagar';
              final puedeCobrar = estadoPago == 'por_confirmar' && recibida > 0;
              final pendientePorFecha =
                  recibida <= 0 &&
                  (proximaFechaComision ?? '').trim().isNotEmpty;

              final regla = (tipo == null || tipo.isEmpty)
                  ? 'Comision automatica por rango de precio'
                  : '\$${valor.toStringAsFixed(2)} por perfume (segun precio de lista)';

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.local_florist)),
                  title: Text(item['nombre_perfume']?.toString() ?? 'Perfume'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (pendientePorFecha)
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Pendiente hasta ${_formatDate(proximaFechaComision)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      else
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Habilitada hoy',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green.shade900,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      Text('Vendidos: $cantidad unidades'),
                      Text('Precio de lista: \$${precioLista.toStringAsFixed(2)}'),
                      Text('Monto vendido: \$${monto.toStringAsFixed(2)}'),
                      if ((proximaFechaComision ?? '').trim().isNotEmpty)
                        Text(
                          'Proxima fecha de cobro de comision: ${_formatDate(proximaFechaComision)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      Text(
                        regla,
                        style: TextStyle(
                          fontSize: 12,
                          color: tipo == null
                              ? Colors.black54
                              : Colors.indigo.shade700,
                          fontWeight: tipo == null
                              ? FontWeight.normal
                              : FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Comision a cobrar hoy: \$${recibida.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _estadoPagoColor(
                            estadoPago,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _estadoPagoLabel(estadoPago),
                          style: TextStyle(
                            fontSize: 11,
                            color: _estadoPagoColor(estadoPago),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  trailing: puedeCobrar
                      ? ElevatedButton(
                          onPressed: () => _cobrar(item),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo.shade700,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Cobrar'),
                        )
                      : null,
                ),
              );
            }),
          Card(
            color: Colors.indigo.shade50,
            child: ListTile(
              leading: const Icon(Icons.summarize),
              title: const Text(
                'Total de comisiones a cobrar hoy',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: Text(
                '\$${(_filtroEstado == 'todas' ? _totalComisiones : totalFiltrado).toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PendientesScreen extends StatefulWidget {
  final int vendedorId;
  final int reloadToken;
  final VoidCallback onChanged;
  final String tipoFiltro;
  final String titulo;

  const PendientesScreen({
    super.key,
    required this.vendedorId,
    required this.reloadToken,
    required this.onChanged,
    required this.tipoFiltro,
    required this.titulo,
  });

  @override
  State<PendientesScreen> createState() => _PendientesScreenState();
}

class InformacionScreen extends StatefulWidget {
  final int vendedorId;
  final Map<String, dynamic> vendedor;
  final int reloadToken;

  const InformacionScreen({
    super.key,
    required this.vendedorId,
    required this.vendedor,
    required this.reloadToken,
  });

  @override
  State<InformacionScreen> createState() => _InformacionScreenState();
}

class _InformacionScreenState extends State<InformacionScreen> {
  final _api = ApiService();
  bool _loading = true;
  Map<String, dynamic> _info = {};

  @override
  void initState() {
    super.initState();
    _info = Map<String, dynamic>.from(widget.vendedor);
    _load();
  }

  @override
  void didUpdateWidget(covariant InformacionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getInformacionVendedor(widget.vendedorId);
      if (!mounted) return;
      setState(() {
        _info = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _formatDate(String? value) {
    final dt = DateTime.tryParse((value ?? '').trim());
    if (dt == null) return value ?? '-';
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yy = dt.year.toString();
    return '$dd/$mm/$yy';
  }

  double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final nombre = _info['nombre']?.toString() ?? 'Embajador';
    final fechaAlta = _formatDate(_info['fecha_registro']?.toString());
    final nivel = _info['nivel_embajador']?.toString() ?? '-';
    final descuentoCredito = _toDouble(_info['descuento_credito']);
    final descuentoContado = _toDouble(_info['descuento_contado']);
    final totalMensual = _toDouble(_info['total_ventas_mensual']);
    final totalAnual = _toDouble(_info['total_ventas_anual']);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Informacion del embajador',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text('Nombre: $nombre'),
                  const SizedBox(height: 6),
                  Text('Fecha de alta: $fechaAlta'),
                  const SizedBox(height: 6),
                  Text('Nivel del embajador: $nivel'),
                  const SizedBox(height: 6),
                  Text(
                    'Descuento disponible: Crédito ${descuentoCredito.toStringAsFixed(0)}% · Contado ${descuentoContado.toStringAsFixed(0)}%',
                  ),
                  const SizedBox(height: 6),
                  Text('Total de ventas mensual: \$${totalMensual.toStringAsFixed(2)}'),
                  const SizedBox(height: 6),
                  Text('Total de ventas anual: \$${totalAnual.toStringAsFixed(2)}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendientesScreenState extends State<PendientesScreen> {
  final _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PendientesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getPendientes(
        widget.vendedorId,
        tipo: widget.tipoFiltro,
      );
      if (mounted) {
        setState(() {
          _rows = data;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmar(int entregaId) async {
    await _api.confirmarEntrega(entregaId);
    widget.onChanged();
    _load();
  }

  void _mostrarImagenGrande(String title, String imageUrl) {
    if (imageUrl.trim().isEmpty) return;

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    padding: const EdgeInsets.all(24),
                    color: Colors.indigo.shade50,
                    child: Icon(
                      Icons.broken_image,
                      size: 72,
                      color: Colors.indigo.shade700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_rows.isEmpty) {
      return Center(child: Text('No hay entregas pendientes'));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: _rows.length,
        itemBuilder: (_, index) {
          final item = _rows[index];
          final tipo = item['tipo']?.toString() ?? '';
          final esInicial = tipo == 'inicial';
          final esPedido = tipo == 'pedido';
          final imagenUrl = item['imagen_url']?.toString() ?? '';
          final nombre = item['nombre_perfume']?.toString() ?? 'Perfume';

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              leading: GestureDetector(
                onTap: () => _mostrarImagenGrande(nombre, imagenUrl),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: imagenUrl.isNotEmpty
                        ? Image.network(
                            imagenUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.indigo.shade50,
                              child: Icon(
                                esInicial
                                    ? Icons.inventory_2
                                    : esPedido
                                    ? Icons.local_shipping
                                    : Icons.delivery_dining,
                                color: Colors.indigo.shade700,
                              ),
                            ),
                          )
                        : Container(
                            color: Colors.indigo.shade50,
                            child: Icon(
                              esInicial
                                  ? Icons.inventory_2
                                  : esPedido
                                  ? Icons.local_shipping
                                  : Icons.delivery_dining,
                              color: Colors.indigo.shade700,
                            ),
                          ),
                  ),
                ),
              ),
              title: Text(nombre),
              subtitle: Text(
                '${esInicial
                    ? 'Entrega inicial por confirmar'
                    : esPedido
                    ? 'Pedido surtido por confirmar'
                    : 'Entrega por confirmar'} | Cantidad: ${item['cantidad']} | Fecha: ${_formatDate(item['fecha']?.toString())}',
              ),
              trailing: ElevatedButton(
                onPressed: () => _confirmar(item['id'] as int),
                child: const Text('Confirmar'),
              ),
            ),
          );
        },
      ),
    );
  }
}

class PedidosScreen extends StatefulWidget {
  final int vendedorId;
  final int reloadToken;
  final VoidCallback onChanged;

  const PedidosScreen({
    super.key,
    required this.vendedorId,
    required this.reloadToken,
    required this.onChanged,
  });

  @override
  State<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends State<PedidosScreen> {
  final _api = ApiService();
  final Map<int, Map<String, dynamic>> _seleccionados = {};
  bool _loading = true;
  List<Map<String, dynamic>> _catalogo = [];
  List<Map<String, dynamic>> _pedidos = [];
  String _filtroEstado = 'todos';
  String _busqueda = '';

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PedidosScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await Future.wait<dynamic>([
        _api.getCatalogoPedidos(widget.vendedorId),
        _api.getPedidos(widget.vendedorId),
      ]);

      if (!mounted) return;
      setState(() {
        _catalogo = List<Map<String, dynamic>>.from(data[0] as List);
        _pedidos = List<Map<String, dynamic>>.from(data[1] as List);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _pedidosFiltrados {
    if (_filtroEstado == 'todos') return _pedidos;
    if (_filtroEstado == 'por_surtir') {
      return _pedidos
          .where((p) => p['estado']?.toString() == 'solicitado')
          .toList();
    }
    return _pedidos
        .where((p) => p['estado']?.toString() != 'solicitado')
        .toList();
  }

  List<Map<String, dynamic>> get _catalogoFiltrado {
    final query = _busqueda.trim().toLowerCase();
    if (query.isEmpty) return _catalogo;

    return _catalogo.where((perfume) {
      final nombre = perfume['nombre_perfume']?.toString() ?? '';
      final marca = perfume['marca_perfume']?.toString() ?? '';
      final texto = '$nombre $marca'.toLowerCase();
      return texto.contains(query);
    }).toList();
  }

  Future<void> _elegirCantidad(Map<String, dynamic> perfume) async {
    final controller = TextEditingController(text: '1');
    final cantidad = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(perfume['nombre_perfume']?.toString() ?? 'Perfume'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Cantidad a solicitar'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              if (parsed == null || parsed <= 0) return;
              Navigator.pop(ctx, parsed);
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );

    if (cantidad == null) return;
    final perfumeId = _toInt(perfume['perfume_id']);
    if (perfumeId <= 0) return;

    setState(() {
      final actual = _seleccionados[perfumeId]?['cantidad'] as int? ?? 0;
      _seleccionados[perfumeId] = {...perfume, 'cantidad': actual + cantidad};
    });
  }

  void _quitarSeleccion(int perfumeId) {
    setState(() {
      _seleccionados.remove(perfumeId);
    });
  }

  Future<void> _solicitar() async {
    if (_seleccionados.isEmpty) return;

    final items = _seleccionados.values
        .map((item) {
          return {
            'perfume_id': _toInt(item['perfume_id']),
            'cantidad': _toInt(item['cantidad']),
            'precio_unitario': _toDouble(item['precio_venta']),
          };
        })
        .where((item) => (item['perfume_id'] as int) > 0)
        .toList();

    if (items.isEmpty) return;

    setState(() => _loading = true);
    try {
      await _api.solicitarPedidos(
        vendedorId: widget.vendedorId,
        fecha: DateTime.now().toIso8601String().split('T').first,
        items: items,
      );
      if (!mounted) return;
      setState(() => _seleccionados.clear());
      widget.onChanged();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pedido enviado correctamente')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      setState(() => _loading = false);
    }
  }

  void _mostrarImagenGrande(String title, String imageUrl) {
    if (imageUrl.trim().isEmpty) return;

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    padding: const EdgeInsets.all(24),
                    color: Colors.indigo.shade50,
                    child: Icon(
                      Icons.broken_image,
                      size: 72,
                      color: Colors.indigo.shade700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildPedidoCard(Map<String, dynamic> pedido) {
    final estado = pedido['estado']?.toString() ?? 'solicitado';
    final label = estado == 'solicitado'
        ? 'Por surtir'
        : estado == 'pendiente_confirmacion'
        ? 'Surtido - pendiente de aceptar'
        : estado == 'confirmado'
        ? 'Aceptado'
        : estado;
    final imagenUrl = pedido['imagen_url']?.toString() ?? '';
    final nombre = pedido['nombre_perfume']?.toString() ?? 'Perfume';

    final color = estado == 'solicitado'
        ? Colors.orange.shade700
        : estado == 'pendiente_confirmacion'
        ? Colors.blue.shade700
        : Colors.green.shade700;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: GestureDetector(
          onTap: () => _mostrarImagenGrande(nombre, imagenUrl),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 48,
              height: 48,
              color: Colors.indigo.shade50,
              child: imagenUrl.isNotEmpty
                  ? Image.network(
                      imagenUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.local_shipping,
                        color: color,
                      ),
                    )
                  : Icon(Icons.local_shipping, color: color),
            ),
          ),
        ),
        title: Text(nombre),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cantidad: ${pedido['cantidad']}'),
            Text('Estado: $label'),
          ],
        ),
        trailing: Text(
          estado.toUpperCase(),
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }

  Widget _buildCatalogoCard(Map<String, dynamic> perfume) {
    final perfumeId = _toInt(perfume['perfume_id']);
    final stock = _toInt(perfume['stock']);
    final seleccion = _seleccionados[perfumeId];
    final cantidad = _toInt(seleccion?['cantidad']);
    final imagenUrl = perfume['imagen_url']?.toString() ?? '';
    final nombre = perfume['nombre_perfume']?.toString() ?? 'Perfume';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: GestureDetector(
          onTap: () => _mostrarImagenGrande(nombre, imagenUrl),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 48,
              height: 48,
              child: imagenUrl.isNotEmpty
                  ? Image.network(
                      imagenUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.purple.shade100,
                        child: Icon(
                          Icons.spa,
                          color: Colors.purple.shade700,
                        ),
                      ),
                    )
                  : Container(
                      color: Colors.purple.shade100,
                      child: Icon(
                        Icons.spa,
                        color: Colors.purple.shade700,
                      ),
                    ),
            ),
          ),
        ),
        title: Text(nombre),
        subtitle: Text(
          'Marca: ${perfume['marca_perfume']?.toString() ?? '-'} · Stock: $stock · \$${_toDouble(perfume['precio_venta']).toStringAsFixed(2)}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (cantidad > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('x$cantidad'),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: cantidad > 0
                      ? () => _quitarSeleccion(perfumeId)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _elegirCantidad(perfume),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final seleccionados = _seleccionados.values.toList();
    final totalItems = seleccionados.fold<int>(0, (sum, item) {
      return sum + _toInt(item['cantidad']);
    });

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pedidos'),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Solicitar', icon: Icon(Icons.add_shopping_cart)),
              Tab(text: 'Mis pedidos', icon: Icon(Icons.pending_actions)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(12),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar perfume o marca',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onChanged: (value) => setState(() => _busqueda = value),
                  ),
                  const SizedBox(height: 12),
                  if (_catalogoFiltrado.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(
                        child: Text('No hay perfumes que coincidan con tu busqueda'),
                      ),
                    )
                  else
                    ..._catalogoFiltrado.map(_buildCatalogoCard),
                  const SizedBox(height: 8),
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.shopping_cart),
                              const SizedBox(width: 8),
                              Text(
                                'Seleccionados: ${seleccionados.length} perfumes',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Text('Unidades: $totalItems'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (seleccionados.isEmpty)
                            const Text('Agrega perfumes a tu solicitud.'),
                          if (seleccionados.isNotEmpty)
                            ...seleccionados.map((item) {
                              final perfumeId = _toInt(item['perfume_id']);
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  item['nombre_perfume']?.toString() ??
                                      'Perfume',
                                ),
                                subtitle: Text('Cantidad: ${item['cantidad']}'),
                                trailing: IconButton(
                                  onPressed: () => _quitarSeleccion(perfumeId),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              );
                            }),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: seleccionados.isEmpty
                                  ? null
                                  : _solicitar,
                              icon: const Icon(Icons.send),
                              label: const Text('Solicitar'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(12),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Todos'),
                          selected: _filtroEstado == 'todos',
                          onSelected: (_) =>
                              setState(() => _filtroEstado = 'todos'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Surtido'),
                          selected: _filtroEstado == 'surtido',
                          onSelected: (_) =>
                              setState(() => _filtroEstado = 'surtido'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Por surtir'),
                          selected: _filtroEstado == 'por_surtir',
                          onSelected: (_) =>
                              setState(() => _filtroEstado = 'por_surtir'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_pedidosFiltrados.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(
                        child: Text('No hay pedidos para ese filtro'),
                      ),
                    )
                  else
                    ..._pedidosFiltrados.map(_buildPedidoCard),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StockScreen extends StatefulWidget {
  final int vendedorId;
  final int reloadToken;
  final String tipoFiltro;
  final String titulo;

  const StockScreen({
    super.key,
    required this.vendedorId,
    required this.reloadToken,
    required this.tipoFiltro,
    required this.titulo,
  });

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant StockScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getStock(
        widget.vendedorId,
        tipo: widget.tipoFiltro,
      );
      if (mounted) {
        setState(() {
          _rows = data;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _origenLabel(Map<String, dynamic> item) {
    final raw = item['tipos_origen'];
    final tipos = <String>[];

    if (raw is List) {
      for (final entry in raw) {
        final value = entry?.toString().trim().toLowerCase() ?? '';
        if (value.isNotEmpty) tipos.add(value);
      }
    } else {
      final single = raw?.toString().trim().toLowerCase() ?? '';
      if (single.isNotEmpty) tipos.add(single);
    }

    if (tipos.isEmpty) return 'Origen: no especificado';

    final labels = tipos.toSet().map((tipo) {
      switch (tipo) {
        case 'inicial':
          return 'Inicial';
        case 'entrega':
          return 'Entrega';
        case 'pedido':
          return 'Pedido';
        default:
          return tipo[0].toUpperCase() + tipo.substring(1);
      }
    }).toList();

    return 'Origen: ${labels.join(', ')}';
  }

  Future<void> _verDetallePerfume(Map<String, dynamic> item) async {
    final imagenUrl = item['imagen_url']?.toString() ?? '';
    final nombre = item['nombre_perfume']?.toString() ?? 'Perfume';
    final marca = item['marca_perfume']?.toString() ?? '-';
    final descripcion = item['descripcion_perfume']?.toString() ?? '';
    final venta = _toDouble(item['precio_venta']);
    final cantidad = _toInt(item['cantidad']);
    final origen = _origenLabel(item);

    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
                child: SizedBox(
                  height: 240,
                  width: double.infinity,
                  child: imagenUrl.isNotEmpty
                      ? Image.network(
                          imagenUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, error, stackTrace) => Container(
                            color: Colors.indigo.shade100,
                            child: Icon(
                              Icons.local_florist,
                              size: 72,
                              color: Colors.indigo.shade700,
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.indigo.shade100,
                          child: Icon(
                            Icons.local_florist,
                            size: 72,
                            color: Colors.indigo.shade700,
                          ),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('Marca: $marca'),
                    const SizedBox(height: 6),
                    Text(
                      origen,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (descripcion.trim().isNotEmpty) ...[
                      const Text(
                        'Descripcion',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(descripcion),
                      const SizedBox(height: 12),
                    ],
                    _infoBox('Precio venta', '\$${venta.toStringAsFixed(2)}'),
                    const SizedBox(height: 10),
                    _infoBox('Cantidad disponible', '$cantidad'),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo.shade700,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Cerrar'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.titulo,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_rows.isEmpty)
                    const Text(
                      'Todavia no hay stock confirmado para este vendedor.',
                      style: TextStyle(color: Colors.black54),
                    )
                  else
                    ..._rows.map((item) {
                      final nombre =
                          item['nombre_perfume']?.toString() ?? 'Perfume';
                      final marca = item['marca_perfume']?.toString() ?? '';
                      final cantidad = _toInt(item['cantidad']);
                      final imagenUrl = item['imagen_url']?.toString() ?? '';
                      final origen = _origenLabel(item);
                      return ListTile(
                        onTap: () => _verDetallePerfume(item),
                        contentPadding: EdgeInsets.zero,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 52,
                            height: 52,
                            child: imagenUrl.isNotEmpty
                                ? Image.network(
                                    imagenUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, error, stackTrace) =>
                                        Container(
                                          color: Colors.indigo.shade100,
                                          child: Icon(
                                            Icons.local_florist,
                                            color: Colors.indigo.shade700,
                                          ),
                                        ),
                                  )
                                : Container(
                                    color: Colors.indigo.shade100,
                                    child: Icon(
                                      Icons.local_florist,
                                      color: Colors.indigo.shade700,
                                    ),
                                  ),
                          ),
                        ),
                        title: Text(nombre),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              marca.isNotEmpty
                                  ? '$marca · \$${_toDouble(item['precio_venta']).toStringAsFixed(2)}'
                                  : '\$${_toDouble(item['precio_venta']).toStringAsFixed(2)}',
                            ),
                            const SizedBox(height: 2),
                            Text(
                              origen,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                        trailing: Text(
                          '$cantidad',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ClientesScreen extends StatefulWidget {
  final int vendedorId;
  final int reloadToken;
  final VoidCallback onChanged;

  const ClientesScreen({
    super.key,
    required this.vendedorId,
    required this.reloadToken,
    required this.onChanged,
  });

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  final _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ClientesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getClientes(widget.vendedorId);
      if (mounted) {
        setState(() {
          _rows = data;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _nuevoCliente() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ClienteFormScreen(vendedorId: widget.vendedorId),
      ),
    );
    if (created == true) {
      widget.onChanged();
      _load();
    }
  }

  Future<void> _editarCliente(Map<String, dynamic> cliente) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ClienteFormScreen(vendedorId: widget.vendedorId, cliente: cliente),
      ),
    );
    if (changed == true) {
      widget.onChanged();
      _load();
    }
  }

  Future<void> _eliminarCliente(Map<String, dynamic> cliente) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar'),
        content: Text(
          '¿Eliminar al cliente "${cliente['nombre']?.toString() ?? 'Cliente'}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _api.eliminarCliente(
        vendedorId: widget.vendedorId,
        clienteId: _toInt(cliente['id']),
      );
      if (!mounted) return;
      widget.onChanged();
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      body: _rows.isEmpty
          ? const Center(child: Text('Sin clientes registrados'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                itemCount: _rows.length,
                itemBuilder: (_, index) {
                  final item = _rows[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.teal.shade100,
                        child: Text(
                          (item['nombre']?.toString() ?? 'C')
                              .substring(0, 1)
                              .toUpperCase(),
                          style: TextStyle(
                            color: Colors.teal.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(item['nombre']?.toString() ?? 'Cliente'),
                      subtitle: Text(_clienteSubtitle(item)),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') _editarCliente(item);
                          if (value == 'delete') _eliminarCliente(item);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 18),
                                SizedBox(width: 8),
                                Text('Editar'),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 18, color: Colors.red),
                                SizedBox(width: 8),
                                Text(
                                  'Eliminar',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevoCliente,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo cliente'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class ClienteFormScreen extends StatefulWidget {
  final int vendedorId;
  final Map<String, dynamic>? cliente;

  const ClienteFormScreen({super.key, required this.vendedorId, this.cliente});

  @override
  State<ClienteFormScreen> createState() => _ClienteFormScreenState();
}

class _ClienteFormScreenState extends State<ClienteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _api = ApiService();
  bool _saving = false;

  bool get _isEdit => widget.cliente != null;

  @override
  void initState() {
    super.initState();
    final cliente = widget.cliente;
    if (cliente != null) {
      _nombreCtrl.text = cliente['nombre']?.toString() ?? '';
      _telefonoCtrl.text = cliente['telefono']?.toString() ?? '';
      _emailCtrl.text = cliente['email']?.toString() ?? '';
      _direccionCtrl.text = cliente['direccion']?.toString() ?? '';
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await _api.actualizarCliente(
          vendedorId: widget.vendedorId,
          clienteId: _toInt(widget.cliente?['id']),
          nombre: _nombreCtrl.text.trim(),
          telefono: _telefonoCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          direccion: _direccionCtrl.text.trim(),
        );
      } else {
        await _api.crearCliente(
          vendedorId: widget.vendedorId,
          nombre: _nombreCtrl.text.trim(),
          telefono: _telefonoCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          direccion: _direccionCtrl.text.trim(),
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Editar cliente' : 'Nuevo cliente'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _telefonoCtrl,
                decoration: const InputDecoration(labelText: 'Telefono'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _direccionCtrl,
                decoration: const InputDecoration(labelText: 'Direccion'),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _guardar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: _saving
                      ? const CircularProgressIndicator()
                      : Text(_isEdit ? 'Actualizar' : 'Guardar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VentasScreen extends StatefulWidget {
  final int vendedorId;
  final Map<String, dynamic> vendedor;
  final int reloadToken;
  final VoidCallback onChanged;

  const VentasScreen({
    super.key,
    required this.vendedorId,
    required this.vendedor,
    required this.reloadToken,
    required this.onChanged,
  });

  @override
  State<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen> {
  final _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];
  String _estadoFiltro = 'todos';

  List<Map<String, dynamic>> get _filtradas {
    if (_estadoFiltro == 'todos') {
      return _rows;
    }
    return _rows
        .where(
          (item) =>
              (item['estado']?.toString().toLowerCase().trim() ?? '') ==
              _estadoFiltro,
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant VentasScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getVentas(widget.vendedorId);
      if (mounted) {
        setState(() {
          _rows = data;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool?> _preguntarTipoVenta() {
    return showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Tipo de venta',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('Selecciona como deseas registrar la venta'),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long, color: Colors.orange),
              title: const Text('Venta a credito'),
              onTap: () => Navigator.pop(ctx, false),
            ),
            ListTile(
              leading: const Icon(Icons.payments, color: Colors.green),
              title: const Text('Venta de contado'),
              onTap: () => Navigator.pop(ctx, true),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _nuevaVenta() async {
    final esContado = await _preguntarTipoVenta();
    if (esContado == null) return;
    if (!mounted) return;

    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => VentaFormScreen(
          vendedorId: widget.vendedorId,
          vendedor: widget.vendedor,
          esContado: esContado,
        ),
      ),
    );
    if (created == true) {
      widget.onChanged();
      _load();
    }
  }

  Color _estadoColor(String estado) {
    switch (estado) {
      case 'pagado':
        return Colors.green;
      case 'parcial':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  String _estadoLabel(String estado) {
    if (estado.isEmpty) return 'Pendiente';
    return estado[0].toUpperCase() + estado.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      body: _rows.isEmpty
          ? const Center(child: Text('Sin ventas registradas'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['todos', 'pendiente', 'parcial', 'pagado'].map(
                        (estado) {
                          final sel = _estadoFiltro == estado;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                estado == 'todos'
                                    ? 'Todos'
                                    : _estadoLabel(estado),
                              ),
                              selected: sel,
                              onSelected: (_) =>
                                  setState(() => _estadoFiltro = estado),
                              selectedColor: Colors.orange.shade100,
                              backgroundColor: Colors.grey.shade100,
                              labelStyle: TextStyle(
                                color: sel
                                    ? Colors.orange.shade800
                                    : Colors.black87,
                              ),
                            ),
                          );
                        },
                      ).toList(),
                    ),
                  ),
                ),
                Expanded(
                  child: _filtradas.isEmpty
                      ? RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            children: const [
                              SizedBox(height: 160),
                              Center(
                                child: Text('No hay ventas con ese estado'),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            itemCount: _filtradas.length,
                            itemBuilder: (_, index) {
                              final item = _filtradas[index];
                              final estado =
                                  item['estado']
                                      ?.toString()
                                      .toLowerCase()
                                      .trim() ??
                                  'pendiente';
                              final pendiente = _toDouble(
                                item['saldo_pendiente'],
                              );
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                child: ListTile(
                                  onTap: () async {
                                    final changed = await Navigator.push<bool>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => VentaDetalleScreen(
                                          vendedorId: widget.vendedorId,
                                          venta: item,
                                        ),
                                      ),
                                    );
                                    if (changed == true) {
                                      widget.onChanged();
                                      _load();
                                    }
                                  },
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item['nombre_cliente']?.toString() ??
                                              'Cliente',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Chip(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        label: Text(
                                          _estadoLabel(estado),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                        backgroundColor: _estadoColor(estado),
                                      ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    'Fecha: ${_formatDate(item['fecha']?.toString())} | Estado: ${item['estado']}',
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '\$${_toDouble(item['monto_total']).toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Pend: \$${pendiente.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: pendiente > 0
                                              ? Colors.red
                                              : Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevaVenta,
        icon: const Icon(Icons.add),
        label: const Text('Nueva venta'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class VentaFormScreen extends StatefulWidget {
  final int vendedorId;
  final Map<String, dynamic> vendedor;
  final bool esContado;

  const VentaFormScreen({
    super.key,
    required this.vendedorId,
    required this.vendedor,
    required this.esContado,
  });

  @override
  State<VentaFormScreen> createState() => _VentaFormScreenState();
}

class _VentaFormScreenState extends State<VentaFormScreen> {
  final _api = ApiService();
  final _notasCtrl = TextEditingController();
  final List<_VentaItem> _items = [];
  List<Map<String, dynamic>> _clientes = [];
  List<Map<String, dynamic>> _perfumes = [];
  Map<String, dynamic>? _clienteSel;
  DateTime _fecha = DateTime.now();
  DateTime _fechaPrimerPago = _nextPaymentCutoffOnOrAfter(DateTime.now());
  int _cantidadPagos = 1;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  DateTime? get _fechaRegistroVendedor {
    final fechaRegistro =
        widget.vendedor['fecha_registro']?.toString() ??
        widget.vendedor['created_at']?.toString();
    if (fechaRegistro == null || fechaRegistro.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(fechaRegistro);
  }

  int? get _mesesAntiguedadVendedor {
    final fechaReg = _fechaRegistroVendedor;
    if (fechaReg == null) return null;
    var meses = (_fecha.year - fechaReg.year) * 12 + (_fecha.month - fechaReg.month);
    if (_fecha.day < fechaReg.day) {
      meses -= 1;
    }
    if (meses < 0) return 0;
    return meses;
  }

  bool get _aplicaDescuentoEmbajador => _mesesAntiguedadVendedor != null;

  String get _nivelEmbajador {
    final meses = _mesesAntiguedadVendedor;
    if (meses == null) return 'No definido';
    if (meses <= 5) return 'Embajador Nuevo';
    if (meses <= 12) return 'Embajador Intermedio';
    return 'Embajador Consolidado';
  }

  double get _descuentoActual {
    final meses = _mesesAntiguedadVendedor;
    if (meses == null) return 0;
    if (meses <= 5) return widget.esContado ? 25 : 20;
    if (meses <= 12) return widget.esContado ? 20 : 15;
    return widget.esContado ? 10 : 5;
  }

  double _precioUnitarioSegunRegla(Map<String, dynamic> perfume) {
    final base = _toDouble(perfume['precio_venta']);
    if (!_aplicaDescuentoEmbajador) return base;
    final factor = (100 - _descuentoActual) / 100;
    return base * factor;
  }

  void _recalcularPreciosSegunRegla() {
    if (!_aplicaDescuentoEmbajador) return;
    for (final item in _items) {
      item.precio = _precioUnitarioSegunRegla(item.perfume);
    }
  }

  List<DateTime> _fechasSugeridasQuincenales() {
    return _buildPaymentCutoffSchedule(_fechaPrimerPago, _cantidadPagos);
  }

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }

    try {
      final clientes = await _api.getClientes(widget.vendedorId);
      final perfumes = await _api.getPerfumesDisponibles(widget.vendedorId);
      if (mounted) {
        setState(() {
          _clientes = clientes;
          _perfumes = perfumes;
          _clienteSel = clientes.isNotEmpty ? clientes.first : null;
          _loading = false;
          _loadError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _agregarItem() {
    if (_perfumes.isEmpty) return;
    setState(() {
      _items.add(
        _VentaItem.fromPerfume(
          _perfumes.first,
          precioInicial: _precioUnitarioSegunRegla(_perfumes.first),
        ),
      );
    });
  }

  Map<String, dynamic>? _buscarClienteContado(
    List<Map<String, dynamic>> clientes,
  ) {
    for (final c in clientes) {
      final nombre = (c['nombre']?.toString() ?? '').trim().toLowerCase();
      if (nombre == 'cliente contado' || nombre == 'consumidor final') {
        return c;
      }
    }
    return null;
  }

  Future<int?> _resolverClienteId() async {
    if (_clienteSel != null && _clienteSel!['id'] != null) {
      final id = _asInt(_clienteSel!['id']);
      return id > 0 ? id : null;
    }

    if (!widget.esContado) return null;

    final existente = _buscarClienteContado(_clientes);
    if (existente != null && existente['id'] != null) {
      final id = _asInt(existente['id']);
      return id > 0 ? id : null;
    }

    await _api.crearCliente(
      vendedorId: widget.vendedorId,
      nombre: 'Cliente contado',
      telefono: '',
      email: '',
      direccion: '',
    );

    final clientesActualizados = await _api.getClientes(widget.vendedorId);
    final nuevo = _buscarClienteContado(clientesActualizados);
    if (mounted) {
      setState(() {
        _clientes = clientesActualizados;
        _clienteSel =
            nuevo ??
            (clientesActualizados.isNotEmpty
                ? clientesActualizados.first
                : null);
      });
    }
    if (nuevo != null && nuevo['id'] != null) {
      final id = _asInt(nuevo['id']);
      return id > 0 ? id : null;
    }
    return null;
  }

  Future<void> _guardar() async {
    final messenger = ScaffoldMessenger.of(context);
    final clienteId = await _resolverClienteId();
    if (clienteId == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Selecciona o crea un cliente para registrar la venta'),
        ),
      );
      return;
    }
    if (_items.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Agrega al menos un producto')),
      );
      return;
    }
    if (_fechaPrimerPago.isBefore(
      DateTime(_fecha.year, _fecha.month, _fecha.day),
    )) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'La fecha del primer pago no puede ser anterior a la fecha de venta',
          ),
        ),
      );
      return;
    }
    for (final item in _items) {
      final disponible = _asInt(item.perfume['cantidad']);
      if (item.cantidad <= 0 || item.cantidad > disponible) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Cantidad no valida para ${item.perfume['nombre_perfume']}',
            ),
          ),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final ventaId = await _api.crearVenta(
        vendedorId: widget.vendedorId,
        clienteId: clienteId,
        tipoVenta: widget.esContado ? 'contado' : 'credito',
        fecha: _fecha.toIso8601String().split('T').first,
        fechaPrimerPago: widget.esContado
            ? _fecha.toIso8601String().split('T').first
            : _fechaPrimerPago.toIso8601String().split('T').first,
        cantidadPagos: widget.esContado ? 1 : _cantidadPagos,
        frecuenciaPago: 'quincenal',
        notas: _notasCtrl.text.trim(),
        items: _items
            .map(
              (item) => {
                'perfume_id': _asInt(item.perfume['perfume_id']),
                'cantidad': item.cantidad,
                'precio_unitario': item.precio,
              },
            )
            .toList(),
      );

      if (widget.esContado) {
        final total = _items.fold<double>(
          0,
          (sum, item) => sum + item.subtotal,
        );
        await _api.registrarPagoVenta(
          vendedorId: widget.vendedorId,
          ventaId: ventaId,
          monto: total,
          fecha: _fecha.toIso8601String().split('T').first,
          notas: 'Pago de contado automatico',
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.esContado ? 'Nueva venta de contado' : 'Nueva venta a credito',
        ),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 36,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No se pudieron cargar clientes o perfumes',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(_loadError!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _cargarDatos,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<Map<String, dynamic>>(
                    initialValue: _clienteSel,
                    items: _clientes
                        .map(
                          (cliente) => DropdownMenuItem(
                            value: cliente,
                            child: Text(
                              cliente['nombre']?.toString() ?? 'Cliente',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _clienteSel = value),
                    decoration: InputDecoration(
                      labelText: widget.esContado
                          ? 'Cliente (opcional)'
                          : 'Cliente',
                    ),
                  ),
                  if (_clientes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        widget.esContado
                            ? 'No hay clientes. Se creara automaticamente "Cliente contado" al registrar.'
                            : 'No hay clientes registrados para este vendedor.',
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Fecha: ${_formatDate(_fecha.toIso8601String())}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _fecha,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        setState(() {
                          _fecha = date;
                          _fechaPrimerPago = _nextPaymentCutoffOnOrAfter(date);
                          _recalcularPreciosSegunRegla();
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  if (!widget.esContado) ...[
                    DropdownButtonFormField<int>(
                      initialValue: _cantidadPagos,
                      items: List.generate(24, (i) => i + 1)
                          .map(
                            (n) => DropdownMenuItem(
                              value: n,
                              child: Text(
                                '$n pago${n > 1 ? 's' : ''} (15 y fin de mes)',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _cantidadPagos = value);
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Plan de pagos',
                        prefixIcon: Icon(Icons.event_repeat),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _cantidadPagos > 1
                          ? 'Cuota estimada: \$${(_items.fold<double>(0, (sum, item) => sum + item.subtotal) / _cantidadPagos).toStringAsFixed(2)} en cada corte (15 y fin de mes)'
                          : 'Pago unico: \$${_items.fold<double>(0, (sum, item) => sum + item.subtotal).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 0,
                      color: Colors.orange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Fechas de pago (15 y fin de mes)',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            ..._fechasSugeridasQuincenales()
                                .take(6)
                                .toList()
                                .asMap()
                                .entries
                                .map((entry) {
                                  final idx = entry.key + 1;
                                  final fecha = entry.value;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Text(
                                      'Cuota $idx: ${_formatDate(fecha.toIso8601String())}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  );
                                }),
                            if (_cantidadPagos > 6)
                              Text(
                                '... y ${_cantidadPagos - 6} fecha(s) mas',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Primer pago: ${_formatDate(_fechaPrimerPago.toIso8601String())}',
                      ),
                      trailing: const Icon(Icons.edit_calendar),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _fechaPrimerPago,
                          firstDate: _fecha,
                          lastDate: DateTime(2100),
                        );
                        if (date != null) {
                          setState(() {
                            _fechaPrimerPago = _nextPaymentCutoffOnOrAfter(
                              date,
                            );
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                  TextField(
                    controller: _notasCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Notas'),
                  ),
                  const SizedBox(height: 16),
                  if (_aplicaDescuentoEmbajador) ...[
                    Card(
                      elevation: 0,
                      color: Colors.green.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.green.shade100),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _nivelEmbajador,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.green.shade900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Descuento ${widget.esContado ? 'de contado' : 'a credito'}: ${_descuentoActual.toStringAsFixed(0)}%',
                              style: TextStyle(color: Colors.green.shade900),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Productos',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      ElevatedButton.icon(
                        onPressed: _agregarItem,
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('Agrega productos a la venta')),
                    ),
                  ..._items.asMap().entries.map((entry) {
                    return _VentaItemCard(
                      key: ValueKey(entry.key),
                      item: entry.value,
                      perfumes: _perfumes,
                      precioEditable: !_aplicaDescuentoEmbajador,
                      precioSugeridoBuilder: _precioUnitarioSegunRegla,
                      onRemove: () =>
                          setState(() => _items.removeAt(entry.key)),
                      onChanged: () => setState(() {}),
                    );
                  }),
                  const SizedBox(height: 16),
                  Text(
                    '${widget.esContado ? 'Total de contado' : 'Total a credito'}: \$${_items.fold<double>(0, (sum, item) => sum + item.subtotal).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _guardar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                      ),
                      child: _saving
                          ? const CircularProgressIndicator()
                          : const Text('Registrar venta'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class VentaDetalleScreen extends StatefulWidget {
  final int vendedorId;
  final Map<String, dynamic> venta;

  const VentaDetalleScreen({
    super.key,
    required this.vendedorId,
    required this.venta,
  });

  @override
  State<VentaDetalleScreen> createState() => _VentaDetalleScreenState();
}

class _VentaDetalleScreenState extends State<VentaDetalleScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _detalles = [];
  List<Map<String, dynamic>> _pagos = [];
  late Map<String, dynamic> _venta;
  bool _loading = true;

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _venta = Map<String, dynamic>.from(widget.venta);
    _cargar();
  }

  int get _ventaId => _asInt(_venta['id']);

  double get _montoTotal => _toDouble(_venta['monto_total']);

  double get _montoPagado => _toDouble(_venta['monto_pagado']);

  double get _saldoPendiente => _montoTotal - _montoPagado;

  int get _cantidadPagos {
    final n = _asInt(_venta['cantidad_pagos']);
    return n > 0 ? n : 1;
  }

  DateTime _fechaBasePrimerPago() {
    final primerPago = DateTime.tryParse(
      _venta['fecha_primer_pago']?.toString() ?? '',
    );
    if (primerPago != null && _isPaymentCutoffDate(primerPago)) {
      return primerPago;
    }
    final fechaVenta = DateTime.tryParse(_venta['fecha']?.toString() ?? '');
    return _nextPaymentCutoffOnOrAfter(fechaVenta ?? DateTime.now());
  }

  List<DateTime> _fechasSugeridasQuincenales() {
    final base = _fechaBasePrimerPago();
    return _buildPaymentCutoffSchedule(base, _cantidadPagos);
  }

  double _montoCuotaBase() {
    if (_cantidadPagos <= 0) return _montoTotal;
    return _montoTotal / _cantidadPagos;
  }

  DateTime? _proximaFechaPago() {
    if (_saldoPendiente <= 0) return null;
    final cuota = _montoCuotaBase();
    if (cuota <= 0) return _fechaBasePrimerPago();
    final cuotasCubiertas = (_montoPagado / cuota).floor();
    final idx = cuotasCubiertas.clamp(0, _cantidadPagos - 1);
    final fechas = _fechasSugeridasQuincenales();
    return fechas.isEmpty ? _fechaBasePrimerPago() : fechas[idx];
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.getDetallesVenta(vendedorId: widget.vendedorId, ventaId: _ventaId),
        _api.getPagosVenta(vendedorId: widget.vendedorId, ventaId: _ventaId),
        _api.getVentas(widget.vendedorId),
      ]);

      final detalles = results[0];
      final pagos = results[1];
      final ventas = results[2];
      final actualizada = ventas.where((v) => _asInt(v['id']) == _ventaId);

      if (!mounted) return;
      setState(() {
        _detalles = detalles;
        _pagos = pagos;
        if (actualizada.isNotEmpty) {
          _venta = Map<String, dynamic>.from(actualizada.first);
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'pagado':
        return Colors.green;
      case 'parcial':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  Future<void> _registrarPago() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_saldoPendiente <= 0) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Esta venta ya esta completamente pagada'),
        ),
      );
      return;
    }

    final montoCtrl = TextEditingController(
      text: _saldoPendiente.toStringAsFixed(2),
    );
    final notasCtrl = TextEditingController();
    DateTime fecha = _nextPaymentCutoffOnOrAfter(DateTime.now());

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Registrar pago'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Saldo pendiente: \$${_saldoPendiente.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: montoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Monto a pagar',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text('Fecha: ${_formatDate(fecha.toIso8601String())}'),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: fecha,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) {
                      setDialogState(() {
                        fecha = _nextPaymentCutoffOnOrAfter(d);
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notasCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                    prefixIcon: Icon(Icons.notes),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final monto = double.tryParse(montoCtrl.text.trim());
                if (monto == null || monto <= 0) {
                  return;
                }
                if (monto > _saldoPendiente) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('El monto excede el saldo pendiente'),
                    ),
                  );
                  return;
                }

                try {
                  await _api.registrarPagoVenta(
                    vendedorId: widget.vendedorId,
                    ventaId: _ventaId,
                    monto: monto,
                    fecha: fecha.toIso8601String().split('T').first,
                    notas: notasCtrl.text.trim(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _cargar();
                  if (mounted) Navigator.pop(context, true);
                } catch (e) {
                  final message = e.toString().replaceFirst('Exception: ', '');
                  messenger.showSnackBar(SnackBar(content: Text(message)));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarioPagos() {
    final fechas = _fechasSugeridasQuincenales();
    final cuota = _montoCuotaBase();
    final cuotasCompletas = cuota > 0 ? (_montoPagado / cuota).floor() : 0;
    final cuotaParcial =
        cuota > 0 &&
        cuotasCompletas < _cantidadPagos &&
        (_montoPagado - (cuotasCompletas * cuota)) > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Calendario sugerido de pagos (15 y fin de mes)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...List.generate(fechas.length, (i) {
              final idx = i + 1;
              final cubierta = idx <= cuotasCompletas;
              final parcial =
                  !cubierta && cuotaParcial && idx == (cuotasCompletas + 1);
              final montoCuota = idx == _cantidadPagos
                  ? (_montoTotal - (cuota * (_cantidadPagos - 1)))
                  : cuota;

              final color = cubierta
                  ? Colors.green
                  : parcial
                  ? Colors.blue
                  : Colors.orange;
              final estado = cubierta
                  ? 'Cubierta'
                  : parcial
                  ? 'Parcial'
                  : 'Pendiente';

              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Text(
                    '$idx',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                title: Text(
                  'Cuota $idx - ${_formatDate(fechas[i].toIso8601String())}',
                ),
                subtitle: Text(
                  'Monto sugerido: \$${montoCuota.toStringAsFixed(2)}',
                ),
                trailing: Text(
                  estado,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _montoBox(String label, double monto, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black45),
        ),
        Text(
          '\$${monto.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final estado = _venta['estado']?.toString() ?? 'pendiente';
    return Scaffold(
      appBar: AppBar(
        title: Text(_venta['nombre_cliente']?.toString() ?? 'Venta'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _registrarPago,
            icon: const Icon(Icons.payment),
            tooltip: 'Registrar pago',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _venta['nombre_cliente']?.toString() ??
                                    'Cliente',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Chip(
                                label: Text(
                                  estado[0].toUpperCase() + estado.substring(1),
                                  style: const TextStyle(color: Colors.white),
                                ),
                                backgroundColor: _colorEstado(estado),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Fecha: ${_formatDate(_venta['fecha']?.toString())}',
                            style: const TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Plan: $_cantidadPagos pago${_cantidadPagos > 1 ? 's' : ''} ${(_venta['frecuencia_pago']?.toString().trim().isNotEmpty ?? false) ? _venta['frecuencia_pago'] : 'quincenal'}',
                            style: const TextStyle(color: Colors.black54),
                          ),
                          if (_proximaFechaPago() != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.orange.shade200,
                                  ),
                                ),
                                child: Text(
                                  'Proxima fecha de pago: ${_formatDate(_proximaFechaPago()!.toIso8601String())}',
                                  style: TextStyle(
                                    color: Colors.orange.shade800,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          if ((_venta['notas']?.toString() ?? '')
                              .trim()
                              .isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Nota: ${_venta['notas']}',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _montoBox('Total', _montoTotal, Colors.black87),
                              _montoBox(
                                'Pagado',
                                _montoPagado,
                                Colors.green.shade700,
                              ),
                              _montoBox(
                                'Pendiente',
                                _saldoPendiente,
                                _saldoPendiente > 0
                                    ? Colors.red.shade700
                                    : Colors.green.shade700,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildCalendarioPagos(),
                  const SizedBox(height: 16),
                  const Text(
                    'Productos',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ..._detalles.map(
                    (detalle) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(
                          Icons.local_florist,
                          color: Colors.purple,
                        ),
                        title: Text(
                          detalle['nombre_perfume']?.toString() ?? 'Perfume',
                        ),
                        subtitle: Text(
                          '${_asInt(detalle['cantidad'])} x \$${_toDouble(detalle['precio_unitario']).toStringAsFixed(2)}',
                        ),
                        trailing: Text(
                          '\$${(_asInt(detalle['cantidad']) * _toDouble(detalle['precio_unitario'])).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Historial de pagos',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _registrarPago,
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar pago'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_pagos.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: Text(
                          'Sin pagos registrados',
                          style: TextStyle(color: Colors.black45),
                        ),
                      ),
                    ),
                  ..._pagos.map(
                    (pago) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE8F5E9),
                          child: Icon(Icons.payments, color: Colors.green),
                        ),
                        title: Text(
                          '\$${_toDouble(pago['monto']).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_formatDate(pago['fecha']?.toString())),
                            if (_toDouble(pago['comision_total']) > 0)
                              Text(
                                'Comisión: \$${_toDouble(pago['comision_total']).toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: Colors.indigo.shade700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                        trailing: (pago['notas']?.toString() ?? '').isNotEmpty
                            ? Tooltip(
                                message: pago['notas'].toString(),
                                child: const Icon(Icons.info_outline, size: 18),
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: _saldoPendiente > 0
          ? FloatingActionButton.extended(
              onPressed: _registrarPago,
              icon: const Icon(Icons.payment),
              label: const Text('Registrar pago'),
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }
}

class _VentaItem {
  Map<String, dynamic> perfume;
  int cantidad;
  double precio;

  _VentaItem({
    required this.perfume,
    required this.cantidad,
    required this.precio,
  });

  factory _VentaItem.fromPerfume(
    Map<String, dynamic> perfume, {
    double? precioInicial,
  }) {
    return _VentaItem(
      perfume: perfume,
      cantidad: 1,
      precio: precioInicial ?? _toDouble(perfume['precio_venta']),
    );
  }

  double get subtotal => cantidad * precio;
}

class _VentaItemCard extends StatefulWidget {
  final _VentaItem item;
  final List<Map<String, dynamic>> perfumes;
  final bool precioEditable;
  final double Function(Map<String, dynamic> perfume) precioSugeridoBuilder;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _VentaItemCard({
    super.key,
    required this.item,
    required this.perfumes,
    required this.precioEditable,
    required this.precioSugeridoBuilder,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_VentaItemCard> createState() => _VentaItemCardState();
}

class _VentaItemCardState extends State<_VentaItemCard> {
  late final TextEditingController _cantidadCtrl;
  late final TextEditingController _precioCtrl;

  @override
  void initState() {
    super.initState();
    _cantidadCtrl = TextEditingController(
      text: widget.item.cantidad.toString(),
    );
    _precioCtrl = TextEditingController(
      text: widget.item.precio.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _cantidadCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _VentaItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nuevaCantidad = widget.item.cantidad.toString();
    final nuevoPrecio = widget.item.precio.toStringAsFixed(2);
    if (_cantidadCtrl.text != nuevaCantidad) {
      _cantidadCtrl.text = nuevaCantidad;
    }
    if (_precioCtrl.text != nuevoPrecio) {
      _precioCtrl.text = nuevoPrecio;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<Map<String, dynamic>>(
                    initialValue: widget.item.perfume,
                    items: widget.perfumes
                        .map(
                          (perfume) => DropdownMenuItem(
                            value: perfume,
                            child: Text(
                              '${perfume['nombre_perfume']} (${perfume['cantidad']})',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      widget.item.perfume = value;
                      widget.item.precio =
                          widget.precioSugeridoBuilder(value);
                      _precioCtrl.text = widget.item.precio.toStringAsFixed(2);
                      widget.onChanged();
                    },
                    decoration: const InputDecoration(labelText: 'Perfume'),
                  ),
                ),
                IconButton(
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.delete, color: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cantidadCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Cantidad'),
                    onChanged: (value) {
                      widget.item.cantidad = int.tryParse(value) ?? 1;
                      widget.onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _precioCtrl,
                    enabled: widget.precioEditable,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Precio'),
                    onChanged: (value) {
                      widget.item.precio = double.tryParse(value) ?? 0;
                      widget.onChanged();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Subtotal: \$${widget.item.subtotal.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _clienteSubtitle(Map<String, dynamic> item) {
  final parts = <String>[];
  final telefono = item['telefono']?.toString() ?? '';
  final email = item['email']?.toString() ?? '';
  final direccion = item['direccion']?.toString() ?? '';
  if (telefono.isNotEmpty) parts.add(telefono);
  if (email.isNotEmpty) parts.add(email);
  if (direccion.isNotEmpty) parts.add(direccion);
  return parts.isEmpty ? 'Sin datos adicionales' : parts.join(' | ');
}

int _lastDayOfMonth(DateTime date) {
  return DateTime(date.year, date.month + 1, 0).day;
}

bool _isPaymentCutoffDate(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  final lastDay = _lastDayOfMonth(normalized);
  return normalized.day == 15 || normalized.day == lastDay;
}

DateTime _nextPaymentCutoffOnOrAfter(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  final lastDay = _lastDayOfMonth(normalized);
  if (normalized.day <= 15) {
    return DateTime(normalized.year, normalized.month, 15);
  }
  return DateTime(normalized.year, normalized.month, lastDay);
}

DateTime _nextPaymentCutoffAfter(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  final lastDay = _lastDayOfMonth(normalized);

  if (normalized.day < 15) {
    return DateTime(normalized.year, normalized.month, 15);
  }
  if (normalized.day < lastDay) {
    return DateTime(normalized.year, normalized.month, lastDay);
  }
  return DateTime(normalized.year, normalized.month + 1, 15);
}

List<DateTime> _buildPaymentCutoffSchedule(DateTime firstDate, int count) {
  if (count <= 0) return const [];
  final dates = <DateTime>[];
  var current = _nextPaymentCutoffOnOrAfter(firstDate);
  for (var i = 0; i < count; i++) {
    dates.add(current);
    current = _nextPaymentCutoffAfter(current);
  }
  return dates;
}

String _formatDate(String? value) {
  if (value == null || value.isEmpty) return '-';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final day = parsed.day.toString().padLeft(2, '0');
  final month = parsed.month.toString().padLeft(2, '0');
  final year = parsed.year.toString();
  return '$day/$month/$year';
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
