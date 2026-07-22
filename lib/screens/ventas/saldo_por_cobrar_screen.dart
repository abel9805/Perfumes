import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/admin_scope.dart';
import '../../database/database_helper.dart';
import '../../models/venta_credito.dart';
import '../../widgets/admin_back_handler.dart';
import '../../widgets/app_drawer.dart';
import '../home_screen.dart';

class SaldoPorCobrarScreen extends StatefulWidget {
  const SaldoPorCobrarScreen({super.key});

  @override
  State<SaldoPorCobrarScreen> createState() => _SaldoPorCobrarScreenState();
}

class _SaldoPorCobrarScreenState extends State<SaldoPorCobrarScreen> {
  final List<VentaCredito> _ventas = [];
  bool _loading = true;

  int? get _vendedorRestringidoId => AdminScope.vendedorId;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final data = _vendedorRestringidoId != null
        ? await DatabaseHelper().getVentasByVendedor(_vendedorRestringidoId!)
        : await DatabaseHelper().getVentas();

    if (!mounted) return;
    setState(() {
      _ventas
        ..clear()
        ..addAll(data.where((v) => v.vendedorId != null));
      _loading = false;
    });
  }

  int _lastDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0).day;
  }

  DateTime _nextCutoffOnOrAfter(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final lastDay = _lastDayOfMonth(d);
    if (d.day <= 15) return DateTime(d.year, d.month, 15);
    return DateTime(d.year, d.month, lastDay);
  }

  DateTime _nextCutoffAfter(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final lastDay = _lastDayOfMonth(d);
    if (d.day < 15) return DateTime(d.year, d.month, 15);
    if (d.day < lastDay) return DateTime(d.year, d.month, lastDay);
    return DateTime(d.year, d.month + 1, 15);
  }

  DateTime _fechaPrimerPagoNormalizada(VentaCredito v) {
    final base = DateTime.tryParse((v.fechaPrimerPago ?? '').trim()) ??
        DateTime.tryParse(v.fecha) ??
        DateTime.now();
    return _nextCutoffOnOrAfter(base);
  }

  int _cuotasVencidasHastaHoy(VentaCredito v) {
    final totalCuotas = v.cantidadPagos <= 0 ? 1 : v.cantidadPagos;
    final hoy = DateTime.now();
    var fechaCuota = _fechaPrimerPagoNormalizada(v);
    var vencidas = 0;

    for (var i = 0; i < totalCuotas; i++) {
      if (fechaCuota.isAfter(hoy)) break;
      vencidas++;
      fechaCuota = _nextCutoffAfter(fechaCuota);
    }
    return vencidas;
  }

  double _montoExigibleHoy(VentaCredito v) {
    final totalCuotas = v.cantidadPagos <= 0 ? 1 : v.cantidadPagos;
    final vencidas = _cuotasVencidasHastaHoy(v);
    if (vencidas <= 0) return 0;

    final exigible = (v.montoTotal * vencidas) / totalCuotas;
    if (exigible > v.montoTotal) return v.montoTotal;
    return exigible;
  }

  double _porCobrarHoy(VentaCredito v) {
    final exigible = _montoExigibleHoy(v);
    final pendiente = exigible - v.montoPagado;
    if (pendiente <= 0) return 0;
    if (pendiente > v.saldoPendiente) return v.saldoPendiente;
    return pendiente;
  }

  String _formatDateSafe(String? value) {
    final d = DateTime.tryParse(value?.trim() ?? '');
    if (d == null) return value?.toString() ?? '-';
    return DateFormat('dd/MM/yyyy').format(d);
  }

  Map<String, List<VentaCredito>> get _gruposPorVendedor {
    final map = <String, List<VentaCredito>>{};
    for (final v in _ventas) {
      final key = (v.nombreVendedor ?? '').trim().isNotEmpty
          ? v.nombreVendedor!.trim()
          : 'Vendedor #${v.vendedorId ?? 0}';
      map.putIfAbsent(key, () => <VentaCredito>[]).add(v);
    }
    return map;
  }

  Map<String, List<VentaCredito>> _agruparPorFecha(List<VentaCredito> ventas) {
    final map = <String, List<VentaCredito>>{};
    for (final v in ventas) {
      final key = v.fecha;
      map.putIfAbsent(key, () => <VentaCredito>[]).add(v);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final gruposVendedor = _gruposPorVendedor.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    final totalGeneral = gruposVendedor.fold<double>(0, (sum, g) {
      final subtotal = g.value.fold<double>(0, (s, v) => s + _porCobrarHoy(v));
      return sum + subtotal;
    });

    return AdminBackHandler(
      dashboardBuilder: (_) => const HomeScreen(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Saldo por cobrar'),
          backgroundColor: Colors.red.shade700,
          foregroundColor: Colors.white,
          actions: [
            IconButton(onPressed: _cargar, icon: const Icon(Icons.refresh)),
          ],
        ),
        drawer: const AppDrawer(),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _cargar,
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
                              'Ventas agrupadas por vendedor',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Total por cobrar hoy: \$${totalGeneral.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (gruposVendedor.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 60),
                        child: Center(
                          child:
                              Text('No hay ventas de vendedores para mostrar.'),
                        ),
                      )
                    else
                      ...gruposVendedor.map((vendedorEntry) {
                        final nombreVendedor = vendedorEntry.key;
                        final ventasVendedor = vendedorEntry.value;
                        final totalVendedor = ventasVendedor.fold<double>(
                            0, (s, v) => s + _porCobrarHoy(v));
                        final totalAbonosVendedor = ventasVendedor.fold<double>(
                            0, (s, v) => s + v.montoPagado);
                        final totalVentasVendedor = ventasVendedor.fold<double>(
                            0, (s, v) => s + v.montoTotal);

                        final gruposFecha =
                            _agruparPorFecha(ventasVendedor).entries.toList()
                              ..sort((a, b) {
                                final ad =
                                    DateTime.tryParse(a.key) ?? DateTime(1900);
                                final bd =
                                    DateTime.tryParse(b.key) ?? DateTime(1900);
                                return bd.compareTo(ad);
                              });

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nombreVendedor,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Total vendido: \$${totalVentasVendedor.toStringAsFixed(2)}',
                                ),
                                Text(
                                  'Abonos registrados: \$${totalAbonosVendedor.toStringAsFixed(2)}',
                                ),
                                Text(
                                  'Por cobrar segun fechas de pago: \$${totalVendedor.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...gruposFecha.map((fechaEntry) {
                                  final fechaVenta =
                                      _formatDateSafe(fechaEntry.key);
                                  final totalFecha =
                                      fechaEntry.value.fold<double>(
                                    0,
                                    (s, v) => s + _porCobrarHoy(v),
                                  );
                                  final totalVentasFecha =
                                      fechaEntry.value.fold<double>(
                                    0,
                                    (s, v) => s + v.montoTotal,
                                  );
                                  final totalAbonosFecha =
                                      fechaEntry.value.fold<double>(
                                    0,
                                    (s, v) => s + v.montoPagado,
                                  );

                                  return Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Fecha de venta: $fechaVenta',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Total vendido: \$${totalVentasFecha.toStringAsFixed(2)}',
                                        ),
                                        Text(
                                          'Abonos registrados: \$${totalAbonosFecha.toStringAsFixed(2)}',
                                        ),
                                        Text(
                                          'Por cobrar hoy: \$${totalFecha.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: Colors.red.shade700,
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
              ),
      ),
    );
  }
}
