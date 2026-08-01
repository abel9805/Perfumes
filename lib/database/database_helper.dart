import '../models/cliente.dart';
import '../models/detalle_venta.dart';
import '../models/entrega_vendedor.dart';
import '../models/pago_venta.dart';
import '../models/perfume.dart';
import '../models/vendedor.dart';
import '../models/venta_credito.dart';
import '../services/vendedores_api_service.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  final VendedoresApiService _apiService = VendedoresApiService();

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  Map<String, dynamic> _normPerfume(Map<String, dynamic> m) {
    final id = _toInt(m['id']);
    return {
      'id': id,
      'api_id': id,
      'nombre': m['nombre'] ?? '',
      'marca': m['marca'] ?? '',
      'mililitros': _toInt(m['mililitros']),
      'concentracion': m['concentracion'],
      'descripcion': m['descripcion'] ?? '',
      'precio_costo': _toDouble(m['precio_costo']),
      'precio_venta': _toDouble(m['precio_venta']),
      'stock': _toInt(m['stock']) ?? 0,
      'imagen_url': m['imagen_url'] ?? m['imagen'],
    };
  }

  Map<String, dynamic> _normVendedor(Map<String, dynamic> m) {
    final id = _toInt(m['id']);
    return {
      'id': id,
      'api_id': id,
      'nombre': m['nombre'] ?? '',
      'telefono': m['telefono'] ?? '',
      'email': m['email'] ?? '',
      'direccion': m['direccion'] ?? '',
      'usuario': m['usuario'] ?? '',
      'password': m['password'] ?? '',
      'tipo_usuario': m['tipo_usuario'] ?? 'vendedor',
      'fecha_registro': m['fecha_registro'] ?? m['created_at'],
      'nivel_embajador': m['nivel_embajador'] ?? '',
      'descuento_credito': _toDouble(m['descuento_credito']),
      'descuento_contado': _toDouble(m['descuento_contado']),
      'total_ventas_mensual': _toDouble(m['total_ventas_mensual']),
      'total_ventas_anual': _toDouble(m['total_ventas_anual']),
    };
  }

  Map<String, dynamic> _normCliente(Map<String, dynamic> m) {
    return {
      'id': _toInt(m['id']),
      'vendedor_id': _toInt(m['vendedor_id']),
      'nombre': m['nombre'] ?? '',
      'telefono': m['telefono'] ?? '',
      'email': m['email'] ?? '',
      'direccion': m['direccion'] ?? '',
    };
  }

  Map<String, dynamic> _normEntrega(Map<String, dynamic> m) {
    return {
      'id': _toInt(m['id']),
      'api_id': _toInt(m['id']),
      'tipo': m['tipo'] ?? 'entrega',
      'vendedor_id': _toInt(m['vendedor_id']) ?? 0,
      'perfume_id': _toInt(m['perfume_id']) ?? 0,
      'cantidad': _toInt(m['cantidad']) ?? 0,
      'precio_unitario': _toDouble(m['precio_unitario']),
      'fecha': m['fecha'] ?? '',
      'estado': m['estado'] ?? 'pendiente_confirmacion',
      'nombre_vendedor': m['nombre_vendedor'],
      'nombre_perfume': m['nombre_perfume'],
    };
  }

  Map<String, dynamic> _normVenta(Map<String, dynamic> m) {
    return {
      'id': _toInt(m['id']),
      'cliente_id': _toInt(m['cliente_id']) ?? 0,
      'vendedor_id': _toInt(m['vendedor_id']),
      'fecha': m['fecha'] ?? '',
      'monto_total': _toDouble(m['monto_total']),
      'monto_pagado': _toDouble(m['monto_pagado']),
      'estado': m['estado'] ?? 'pendiente',
      'notas': m['notas'] ?? '',
      'nombre_cliente': m['nombre_cliente'],
      'nombre_vendedor': m['nombre_vendedor'],
    };
  }

  Map<String, dynamic> _normDetalle(Map<String, dynamic> m) {
    return {
      'id': _toInt(m['id']),
      'venta_id': _toInt(m['venta_id']) ?? 0,
      'perfume_id': _toInt(m['perfume_id']) ?? 0,
      'cantidad': _toInt(m['cantidad']) ?? 0,
      'precio_unitario': _toDouble(m['precio_unitario']),
      'nombre_perfume': m['nombre_perfume'],
    };
  }

  Map<String, dynamic> _normPago(Map<String, dynamic> m) {
    return {
      'id': _toInt(m['id']),
      'venta_id': _toInt(m['venta_id']) ?? 0,
      'monto': _toDouble(m['monto']),
      'fecha': m['fecha'] ?? '',
      'notas': m['notas'] ?? '',
      'comision_tipo': m['comision_tipo'],
      'comision_valor': _toDouble(m['comision_valor']),
      'comision_total': _toDouble(m['comision_total']),
    };
  }

  // PERFUMES
  Future<int> insertPerfume(Perfume perfume, {String? imagePath}) async {
    final remote = await _apiService.crearPerfume(
      nombre: perfume.nombre,
      marca: perfume.marca,
      mililitros: perfume.mililitros,
      concentracion: perfume.concentracion,
      descripcion: perfume.descripcion,
      precioCosto: perfume.precioCosto,
      precioVenta: perfume.precioVenta,
      stock: perfume.stock,
      imagePath: imagePath,
    );
    final id = remote != null ? _toInt(remote['id']) : null;
    if (id == null) {
      throw Exception(
          'La API devolvio una respuesta invalida al crear el perfume');
    }
    return id;
  }

  Future<List<Perfume>> getPerfumes() async {
    final remotos = await _apiService.obtenerPerfumes();
    return remotos.map((m) => Perfume.fromMap(_normPerfume(m))).toList();
  }

  Future<Perfume?> getPerfumeById(int id) async {
    final perfumes = await getPerfumes();
    for (final p in perfumes) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<int> updatePerfume(Perfume perfume, {String? imagePath}) async {
    final id = perfume.apiId ?? perfume.id;
    if (id == null) throw Exception('Perfume sin id API');

    final remote = await _apiService.actualizarPerfume(
      id: id,
      nombre: perfume.nombre,
      marca: perfume.marca,
      mililitros: perfume.mililitros,
      concentracion: perfume.concentracion,
      descripcion: perfume.descripcion,
      precioCosto: perfume.precioCosto,
      precioVenta: perfume.precioVenta,
      stock: perfume.stock,
      imagePath: imagePath,
    );

    if (remote == null) throw Exception('No se pudo actualizar el perfume');
    return _toInt(remote['id']) ?? id;
  }

  Future<int> deletePerfume(int id) async {
    await _apiService.eliminarPerfume(id);
    return 1;
  }

  Future<void> actualizarStockPerfume(int id, int delta) async {
    final perfume = await getPerfumeById(id);
    if (perfume == null) return;
    final nuevoStock = perfume.stock + delta;
    await _apiService.actualizarPerfume(
      id: perfume.id!,
      nombre: perfume.nombre,
      marca: perfume.marca,
      mililitros: perfume.mililitros,
      concentracion: perfume.concentracion,
      descripcion: perfume.descripcion,
      precioCosto: perfume.precioCosto,
      precioVenta: perfume.precioVenta,
      stock: nuevoStock < 0 ? 0 : nuevoStock,
    );
  }

  // VENDEDORES
  Future<int> insertVendedor(
    Vendedor vendedor, {
    List<Map<String, dynamic>> initialEntregas = const [],
  }) async {
    final remote = await _apiService.crearVendedor(
      nombre: vendedor.nombre,
      telefono: vendedor.telefono,
      email: vendedor.email,
      direccion: vendedor.direccion,
      usuario: vendedor.usuario,
      password: vendedor.password,
      tipoUsuario: vendedor.tipoUsuario,
      initialEntregas: initialEntregas,
    );
    final id = remote != null ? _toInt(remote['id']) : null;
    if (id == null) throw Exception('No se pudo crear el vendedor en la API');
    return id;
  }

  Future<List<Vendedor>> getVendedores() async {
    final remotos = await _apiService.obtenerVendedores();
    return remotos.map((m) => Vendedor.fromMap(_normVendedor(m))).toList();
  }

  Future<int> updateVendedor(Vendedor vendedor) async {
    final id = vendedor.apiId ?? vendedor.id;
    if (id == null) throw Exception('Vendedor sin id API');

    final remote = await _apiService.actualizarVendedor(
      apiId: id,
      nombre: vendedor.nombre,
      telefono: vendedor.telefono,
      email: vendedor.email,
      direccion: vendedor.direccion,
      usuario: vendedor.usuario,
      password: vendedor.password,
      tipoUsuario: vendedor.tipoUsuario,
    );

    if (remote == null) throw Exception('No se pudo actualizar el vendedor');
    return _toInt(remote['id']) ?? id;
  }

  Future<int> deleteVendedor(int id) async {
    await _apiService.eliminarVendedor(id);
    return 1;
  }

  // CLIENTES
  Future<int> insertCliente(Cliente cliente) async {
    final remote = await _apiService.crearCliente(
      vendedorId: cliente.vendedorId,
      nombre: cliente.nombre,
      telefono: cliente.telefono,
      email: cliente.email,
      direccion: cliente.direccion,
    );
    final id = remote != null ? _toInt(remote['id']) : null;
    if (id == null) throw Exception('No se pudo crear el cliente');
    return id;
  }

  Future<List<Cliente>> getClientes({int? vendedorId}) async {
    final remotos = await _apiService.obtenerClientes(vendedorId: vendedorId);
    return remotos.map((m) => Cliente.fromMap(_normCliente(m))).toList();
  }

  Future<int> updateCliente(Cliente cliente) async {
    final id = cliente.id;
    if (id == null) throw Exception('Cliente sin id');

    final remote = await _apiService.actualizarCliente(
      id: id,
      vendedorId: cliente.vendedorId,
      nombre: cliente.nombre,
      telefono: cliente.telefono,
      email: cliente.email,
      direccion: cliente.direccion,
    );

    if (remote == null) throw Exception('No se pudo actualizar el cliente');
    return _toInt(remote['id']) ?? id;
  }

  Future<int> deleteCliente(int id) async {
    await _apiService.eliminarCliente(id);
    return 1;
  }

  // ENTREGAS
  Future<int> insertEntrega(EntregaVendedor entrega) async {
    final id = await _apiService.crearEntrega(
      vendedorId: entrega.vendedorId,
      perfumeId: entrega.perfumeId,
      tipo: entrega.tipo,
      cantidad: entrega.cantidad,
      precioUnitario: entrega.precioUnitario,
      fecha: entrega.fecha,
      estado: entrega.estado,
    );
    if (id == null) throw Exception('No se pudo registrar la entrega');
    return id;
  }

  Future<List<EntregaVendedor>> getEntregas({String tipo = 'todos'}) async {
    final remotas = await _apiService.obtenerEntregas(tipo: tipo);
    return remotas
        .map((m) => EntregaVendedor.fromMap(_normEntrega(m)))
        .toList();
  }

  Future<List<EntregaVendedor>> getEntregasByVendedor(int vendedorId,
      {String tipo = 'todos'}) async {
    final remotas = await _apiService.obtenerEntregas(
      vendedorId: vendedorId,
      tipo: tipo,
    );
    return remotas
        .map((m) => EntregaVendedor.fromMap(_normEntrega(m)))
        .toList();
  }

  Future<List<EntregaVendedor>> getPedidos({String tipo = 'pedido'}) async {
    final remotas = await _apiService.obtenerPedidos(tipo: tipo);
    return remotas
        .map((m) => EntregaVendedor.fromMap(_normEntrega(m)))
        .toList();
  }

  Future<List<EntregaVendedor>> getPedidosByVendedor(int vendedorId,
      {String tipo = 'pedido'}) async {
    final remotas = await _apiService.obtenerPedidos(
      vendedorId: vendedorId,
      tipo: tipo,
    );
    return remotas
        .map((m) => EntregaVendedor.fromMap(_normEntrega(m)))
        .toList();
  }

  Future<List<EntregaVendedor>> getEntregasPendientesPorVendedor(
      int vendedorId) async {
    final remotas = await _apiService.obtenerEntregas(vendedorId: vendedorId);
    return remotas
        .map((m) => EntregaVendedor.fromMap(_normEntrega(m)))
        .where((e) => e.estado == 'pendiente_confirmacion')
        .toList();
  }

  Future<List<Map<String, dynamic>>> getStockVendedor(int vendedorId) async {
    return await _apiService.obtenerStockVendedor(vendedorId);
  }

  Future<int> getStockDisponibleVendedorPerfume(
      int vendedorId, int perfumeId) async {
    final rows =
        await _apiService.obtenerPerfumesDisponiblesVendedor(vendedorId);
    for (final row in rows) {
      if (_toInt(row['perfume_id']) == perfumeId) {
        final cantidad = _toInt(row['cantidad']) ?? 0;
        return cantidad < 0 ? 0 : cantidad;
      }
    }
    return 0;
  }

  Future<List<Perfume>> getPerfumesDisponiblesParaVendedor(
      int vendedorId) async {
    final rows =
        await _apiService.obtenerPerfumesDisponiblesVendedor(vendedorId);
    return rows
        .map((m) => Perfume.fromMap({
              'id': _toInt(m['perfume_id']),
              'api_id': _toInt(m['perfume_id']),
              'nombre': m['nombre_perfume'] ?? '',
              'marca': m['marca_perfume'] ?? '',
              'descripcion': '',
              'precio_costo': 0,
              'precio_venta': _toDouble(m['precio_venta']),
              'stock': _toInt(m['cantidad']) ?? 0,
            }))
        .where((p) => p.stock > 0)
        .toList();
  }

  Future<int> updateEntregaEstado(int id, String estado) async {
    await _apiService.actualizarEstadoEntrega(id: id, estado: estado);
    return 1;
  }

  Future<int> updateEntrega(int id,
      {required String estado, int? cantidad}) async {
    await _apiService.actualizarEstadoEntrega(
      id: id,
      estado: estado,
      cantidad: cantidad,
    );
    return 1;
  }

  Future<int> confirmarEntrega(int id) async {
    await _apiService.actualizarEstadoEntrega(id: id, estado: 'confirmado');
    return 1;
  }

  Future<int> deleteEntrega(int id, int perfumeId, int cantidad) async {
    await _apiService.eliminarEntrega(id);
    return 1;
  }

  // VENTAS
  Future<int> insertVenta(VentaCredito venta, List<DetalleVenta> detalles,
      {String? tipoVenta}) async {
    final items = detalles
        .map((d) => {
              'perfume_id': d.perfumeId,
              'cantidad': d.cantidad,
              'precio_unitario': d.precioUnitario,
            })
        .toList();

    final id = await _apiService.crearVenta(
      clienteId: venta.clienteId,
      vendedorId: venta.vendedorId,
      tipoVenta: tipoVenta,
      fecha: venta.fecha,
      fechaPrimerPago: venta.fechaPrimerPago,
      notas: venta.notas,
      cantidadPagos: venta.cantidadPagos,
      frecuenciaPago: venta.frecuenciaPago,
      items: items,
    );

    if (id == null) throw Exception('No se pudo registrar la venta');
    return id;
  }

  Future<List<VentaCredito>> getVentas() async {
    final remotas = await _apiService.obtenerVentas();
    return remotas.map((m) => VentaCredito.fromMap(_normVenta(m))).toList();
  }

  Future<List<VentaCredito>> getVentasByCliente(int clienteId) async {
    final remotas = await _apiService.obtenerVentas(clienteId: clienteId);
    return remotas.map((m) => VentaCredito.fromMap(_normVenta(m))).toList();
  }

  Future<List<VentaCredito>> getVentasByVendedor(int vendedorId) async {
    final remotas = await _apiService.obtenerVentas(vendedorId: vendedorId);
    return remotas.map((m) => VentaCredito.fromMap(_normVenta(m))).toList();
  }

  Future<List<DetalleVenta>> getDetallesVenta(int ventaId) async {
    final remotos = await _apiService.obtenerDetallesVenta(ventaId);
    return remotos.map((m) => DetalleVenta.fromMap(_normDetalle(m))).toList();
  }

  Future<void> registrarPago(PagoVenta pago) async {
    await _apiService.registrarPagoVenta(
      ventaId: pago.ventaId,
      monto: pago.monto,
      fecha: pago.fecha,
      notas: pago.notas,
      comisionTipo: pago.comisionTipo,
      comisionValor: pago.comisionValor,
    );
  }

  Future<List<PagoVenta>> getPagosByVenta(int ventaId) async {
    final remotos = await _apiService.obtenerPagosVenta(ventaId);
    return remotos.map((m) => PagoVenta.fromMap(_normPago(m))).toList();
  }

  // DASHBOARD
  Future<Map<String, dynamic>> getResumen() async {
    return await _apiService.obtenerResumen();
  }

  Future<Map<String, dynamic>> getResumenByVendedor(int vendedorId) async {
    final clientes = await getClientes(vendedorId: vendedorId);
    final ventas = await getVentasByVendedor(vendedorId);
    final perfumesDisponibles =
        await getPerfumesDisponiblesParaVendedor(vendedorId);
    final entregasPendientes =
        await getEntregasPendientesPorVendedor(vendedorId);

    final saldoPendiente = ventas.fold<double>(
      0,
      (sum, v) => sum + (v.montoTotal - v.montoPagado),
    );
    final ventasPendientes = ventas.where((v) => v.estado != 'pagado').length;

    return {
      'totalPerfumes': perfumesDisponibles.length,
      'totalVendedores': 1,
      'totalClientes': clientes.length,
      'ventasPendientes': ventasPendientes,
      'saldoPendiente': saldoPendiente,
      'entregasPendientes': entregasPendientes.length,
    };
  }

  Future<List<Map<String, dynamic>>> getVentasPorVendedor() async {
    return await _apiService.obtenerVentasPorVendedor();
  }

  Future<List<Map<String, dynamic>>> getSaldoVendedor({int? vendedorId}) async {
    return await _apiService.obtenerSaldoVendedor(vendedorId: vendedorId);
  }

  Future<List<Map<String, dynamic>>> getPagosVendedorPorConfirmar({
    int? vendedorId,
  }) async {
    return await _apiService.obtenerPagosVendedorPorConfirmar(
      vendedorId: vendedorId,
    );
  }

  Future<void> confirmarPagoVendedor(int pagoId) async {
    await _apiService.confirmarPagoVendedor(pagoId);
  }

  Future<List<Map<String, dynamic>>> getComisionesPerfumesVendidos() async {
    return await _apiService.obtenerComisionesPerfumesVendidos();
  }

  Future<void> guardarComisionPerfume({
    required int vendedorId,
    required int perfumeId,
    required String comisionTipo,
    required double comisionValor,
  }) async {
    await _apiService.guardarComisionPerfume(
      vendedorId: vendedorId,
      perfumeId: perfumeId,
      comisionTipo: comisionTipo,
      comisionValor: comisionValor,
    );
  }

  Future<void> pagarComisionPerfume({
    required int vendedorId,
    required int perfumeId,
    required double monto,
  }) async {
    await _apiService.pagarComisionPerfume(
      vendedorId: vendedorId,
      perfumeId: perfumeId,
      monto: monto,
    );
  }
}
