import 'package:flutter/material.dart';

import '../config/admin_scope.dart';
import '../database/database_helper.dart';
import '../models/cliente.dart';
import '../models/venta_credito.dart';
import '../widgets/admin_back_handler.dart';
import '../widgets/app_drawer.dart';
import 'clientes/clientes_screen.dart';
import 'entregas/entregas_screen.dart';
import 'perfumes/perfumes_screen.dart';
import 'vendedores/vendedores_screen.dart';
import 'ventas/saldo_por_cobrar_screen.dart';
import 'ventas/ventas_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic> _resumen = {};
  List<Map<String, dynamic>> _ventasPorVendedor = [];
  bool _loading = true;
  String? _error;

  int? get _vendedorRestringidoId => AdminScope.vendedorId;

  @override
  void initState() {
    super.initState();
    _cargarResumen();
  }

  Future<void> _cargarResumen() async {
    final db = DatabaseHelper();
    try {
      final data = await Future.wait<dynamic>([
        db.getResumen(),
        db.getVentasPorVendedor(),
        db.getVentas(),
        db.getClientes(vendedorId: _vendedorRestringidoId),
        db.getPedidos(tipo: 'pedido'),
      ]);

      final resumen = Map<String, dynamic>.from(data[0] as Map);
      final ventas = List<VentaCredito>.from(data[2] as List);
      final clientes = List<Cliente>.from(data[3] as List);
      final pedidos = data[4] as List<dynamic>;

      final ventasPropias = _vendedorRestringidoId != null
          ? ventas.where((v) => v.vendedorId == _vendedorRestringidoId).toList()
          : ventas.where((v) => v.vendedorId == null).toList();
      final ventasVendedores =
          ventas.where((v) => v.vendedorId != null).toList();
      final clientesPropios = _vendedorRestringidoId != null
          ? clientes
              .where((c) => c.vendedorId == _vendedorRestringidoId)
              .toList()
          : clientes.where((c) => c.vendedorId == null).toList();

      resumen['ventasPendientes'] =
          ventasPropias.where((v) => v.estado != 'pagado').length;
      resumen['totalClientes'] = clientesPropios.length;
      resumen['pedidosPorSurtir'] = pedidos
          .where(
              (p) => (p.estado.toString().toLowerCase().trim() == 'solicitado'))
          .length;
      resumen['saldoPendiente'] = ventasVendedores.fold<double>(
        0,
        (sum, v) => sum + (v.montoTotal - v.montoPagado),
      );

      if (!mounted) return;
      setState(() {
        _resumen = resumen;
        _ventasPorVendedor = List<Map<String, dynamic>>.from(data[1] as List);
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _resumen = {
          'totalPerfumes': 0,
          'totalVendedores': 0,
          'totalClientes': 0,
          'ventasPendientes': 0,
          'saldoPendiente': 0,
          'entregasPendientes': 0,
          'pedidosPorSurtir': 0,
        };
        _ventasPorVendedor = [];
        _error =
            'No se pudo cargar el dashboard. Verifica API_BASE_URL y que la API de Laravel este corriendo.';
      });
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminBackHandler(
      isDashboard: true,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard'),
          backgroundColor: Colors.purple.shade700,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() => _loading = true);
                _cargarResumen();
              },
            ),
          ],
        ),
        drawer: const AppDrawer(),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _cargarResumen,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error != null)
                        Card(
                          color: Colors.red.shade50,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.red.shade200),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(Icons.wifi_off,
                                    color: Colors.red.shade700),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style:
                                        TextStyle(color: Colors.red.shade700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_error != null) const SizedBox(height: 12),
                      Text(
                        'Resumen general',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),

                      // 1) Ventas por vendedor
                      Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.bar_chart,
                                      color: Colors.purple.shade700),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Ventas por vendedor',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (_ventasPorVendedor.isEmpty)
                                const Text(
                                  'Aún no hay ventas registradas.',
                                  style: TextStyle(color: Colors.black54),
                                )
                              else
                                ..._ventasPorVendedor.map((row) {
                                  final nombre =
                                      row['nombre_vendedor']?.toString() ??
                                          'Sin vendedor';
                                  final totalVentas =
                                      _toInt(row['total_ventas']);
                                  final saldoPendiente =
                                      _toDouble(row['saldo_pendiente']);
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.purple.shade100,
                                      child: Text(totalVentas.toString()),
                                    ),
                                    title: Text(nombre),
                                    subtitle: Text('$totalVentas ventas'),
                                    trailing: Text(
                                      '\$${saldoPendiente.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: saldoPendiente > 0
                                            ? Colors.red.shade700
                                            : Colors.green.shade700,
                                      ),
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 2) Saldo pendiente por cobrar
                      _buildWideCard(
                        context,
                        icon: Icons.attach_money,
                        label: 'Saldo pendiente por cobrar',
                        value:
                            '\$${_toDouble(_resumen['saldoPendiente']).toStringAsFixed(2)}',
                        color: Colors.red.shade700,
                        onTap: () =>
                            _navigateTo(context, const SaldoPorCobrarScreen()),
                      ),
                      const SizedBox(height: 12),

                      // 3) Entregas por liquidar
                      _buildWideCard(
                        context,
                        icon: Icons.delivery_dining,
                        label: 'Entregas pendientes de liquidar',
                        value: '${_resumen['entregasPendientes']}',
                        color: Colors.green.shade700,
                        onTap: () => _navigateTo(
                          context,
                          const EntregasScreen(tipoFiltro: 'todos'),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 4) Pedidos por surtir
                      _buildWideCard(
                        context,
                        icon: Icons.local_shipping,
                        label: 'Pedidos por surtir',
                        value: '${_resumen['pedidosPorSurtir']}',
                        color: Colors.blue.shade700,
                        onTap: () => _navigateTo(
                          context,
                          const EntregasScreen(modoPedidos: true),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 5) Cuadros finales
                      GridView.count(
                        crossAxisCount: 2,
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.3,
                        children: [
                          _buildCard(
                            context,
                            icon: Icons.local_florist,
                            label: 'Perfumes',
                            value: '${_resumen['totalPerfumes']}',
                            color: Colors.purple,
                            onTap: () =>
                                _navigateTo(context, const PerfumesScreen()),
                          ),
                          _buildCard(
                            context,
                            icon: Icons.people_alt,
                            label: 'Vendedores',
                            value: '${_resumen['totalVendedores']}',
                            color: Colors.indigo,
                            onTap: () =>
                                _navigateTo(context, const VendedoresScreen()),
                          ),
                          _buildCard(
                            context,
                            icon: Icons.person,
                            label: 'Clientes',
                            value: '${_resumen['totalClientes']}',
                            color: Colors.teal,
                            onTap: () =>
                                _navigateTo(context, const ClientesScreen()),
                          ),
                          _buildCard(
                            context,
                            icon: Icons.receipt_long,
                            label: 'Ventas pendientes',
                            value: '${_resumen['ventasPendientes']}',
                            color: Colors.orange,
                            onTap: () =>
                                _navigateTo(context, const VentasScreen()),
                          ),
                          _buildCard(
                            context,
                            icon: Icons.delivery_dining,
                            label: 'Entregas pendientes',
                            value: '${_resumen['entregasPendientes']}',
                            color: Colors.green,
                            onTap: () =>
                                _navigateTo(context, const EntregasScreen()),
                          ),
                          _buildCard(
                            context,
                            icon: Icons.local_shipping,
                            label: 'Pedidos por surtir',
                            value: '${_resumen['pedidosPorSurtir']}',
                            color: Colors.blue,
                            onTap: () => _navigateTo(
                              context,
                              const EntregasScreen(modoPedidos: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Widget _buildCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWideCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: color, size: 36),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style:
                          const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}
