import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../database/database_helper.dart';
import '../../models/entrega_vendedor.dart';
import '../../models/vendedor.dart';
import '../../widgets/admin_back_handler.dart';
import '../home_screen.dart';

class VendedorStockScreen extends StatefulWidget {
  final Vendedor vendedor;

  const VendedorStockScreen({super.key, required this.vendedor});

  @override
  State<VendedorStockScreen> createState() => _VendedorStockScreenState();
}

class _VendedorStockScreenState extends State<VendedorStockScreen> {
  bool _loading = true;
  List<EntregaVendedor> _pendientes = [];
  List<Map<String, dynamic>> _stock = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final db = DatabaseHelper();
    final pendientes =
        await db.getEntregasPendientesPorVendedor(widget.vendedor.id!);
    final stock = await db.getStockVendedor(widget.vendedor.id!);
    if (mounted) {
      setState(() {
        _pendientes = pendientes;
        _stock = stock;
        _loading = false;
      });
    }
  }

  Future<void> _confirmar(EntregaVendedor entrega) async {
    await DatabaseHelper().confirmarEntrega(entrega.id!);
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    return AdminBackHandler(
      dashboardBuilder: (_) => const HomeScreen(),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Vista vendedor - ${widget.vendedor.nombre}'),
          backgroundColor: Colors.indigo.shade700,
          foregroundColor: Colors.white,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _cargar,
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
                            const Text(
                              'Stock confirmado',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            if (_stock.isEmpty)
                              const Text(
                                'Todavía no hay stock confirmado para este vendedor.',
                                style: TextStyle(color: Colors.black54),
                              )
                            else
                              ..._stock.map((row) {
                                final nombre =
                                    row['nombre_perfume']?.toString() ??
                                        'Perfume';
                                final marca =
                                    row['marca_perfume']?.toString() ?? '';
                                final cantidad = _toInt(row['cantidad']);
                                final imagenUrl =
                                    row['imagen_url']?.toString() ?? '';
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      color: Colors.indigo.shade50,
                                      child: imagenUrl.isNotEmpty
                                          ? Image.network(
                                              imagenUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  Icon(Icons.local_florist,
                                                      color: Colors
                                                          .indigo.shade300),
                                            )
                                          : Icon(Icons.local_florist,
                                              color: Colors.indigo.shade300),
                                    ),
                                  ),
                                  title: Text(nombre),
                                  subtitle:
                                      marca.isNotEmpty ? Text(marca) : null,
                                  trailing: Text(
                                    '$cantidad',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pendientes de confirmación',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            if (_pendientes.isEmpty)
                              const Text(
                                'No hay entregas pendientes.',
                                style: TextStyle(color: Colors.black54),
                              )
                            else
                              ..._pendientes.map((entrega) {
                                return Card(
                                  color: Colors.orange.shade50,
                                  child: ListTile(
                                    leading: const Icon(Icons.pending_actions,
                                        color: Colors.orange),
                                    title: Text(
                                        entrega.nombrePerfume ?? 'Perfume'),
                                    subtitle: Text(
                                      'Cantidad: ${entrega.cantidad} · ${fmt.format(DateTime.parse(entrega.fecha))}',
                                    ),
                                    trailing: ElevatedButton(
                                      onPressed: () => _confirmar(entrega),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.indigo.shade700,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Confirmar'),
                                    ),
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    ),
                  ],
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
}
