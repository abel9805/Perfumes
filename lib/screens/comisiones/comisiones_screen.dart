import 'package:flutter/material.dart';

import '../../database/database_helper.dart';
import '../../widgets/admin_back_handler.dart';
import '../../widgets/app_drawer.dart';
import '../home_screen.dart';

class ComisionesScreen extends StatefulWidget {
  const ComisionesScreen({super.key});

  @override
  State<ComisionesScreen> createState() => _ComisionesScreenState();
}

class _ComisionesScreenState extends State<ComisionesScreen> {
  final _db = DatabaseHelper();
  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];
  String _filtroEstado = 'todas';

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatDate(String? value) {
    if (value == null || value.trim().isEmpty) return '-';
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yyyy = date.year.toString();
    return '$dd/$mm/$yyyy';
  }

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (mounted) setState(() => _loading = true);
    final data = await _db.getComisionesPerfumesVendidos();
    if (mounted) {
      setState(() {
        _rows = data;
        _loading = false;
      });
    }
  }

  Map<String, List<Map<String, dynamic>>> get _agrupadoPorVendedor {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final row in _rowsFiltradas) {
      final vendedor = row['nombre_vendedor']?.toString() ?? 'Sin vendedor';
      map.putIfAbsent(vendedor, () => <Map<String, dynamic>>[]).add(row);
    }
    return map;
  }

  List<Map<String, dynamic>> get _rowsFiltradas {
    if (_filtroEstado == 'todas') return _rows;
    return _rows.where((row) {
      final disponible = _toDouble(row['comision_disponible']);
      final cobrada = _toDouble(row['comision_cobrada']);
      if (_filtroEstado == 'por_pagar') {
        return disponible > 0;
      }
      return cobrada > 0 && disponible <= 0;
    }).toList();
  }

  String _estadoPagoLabel(String estado) {
    switch (estado) {
      case 'por_confirmar':
        return 'Pendiente por confirmar';
      case 'cobrado':
        return 'Pagado';
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

  Future<void> _pagarComision(Map<String, dynamic> row) async {
    final vendedorId = _toInt(row['vendedor_id']);
    final perfumeId = _toInt(row['perfume_id']);
    final disponible = _toDouble(row['comision_disponible']);
    if (vendedorId <= 0 || perfumeId <= 0 || disponible <= 0) return;

    final ctrl = TextEditingController(text: disponible.toStringAsFixed(2));
    final monto = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pago parcial de comision'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Disponible: \$${disponible.toStringAsFixed(2)}'),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Monto a pagar'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(ctrl.text.trim()) ?? 0;
              if (value <= 0 || value > disponible) {
                return;
              }
              Navigator.pop(ctx, value);
            },
            child: const Text('Pagar'),
          ),
        ],
      ),
    );

    if (monto == null) {
      return;
    }

    try {
      await _db.pagarComisionPerfume(
        vendedorId: vendedorId,
        perfumeId: perfumeId,
        monto: monto,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pago parcial registrado, pendiente por confirmar'),
        ),
      );
      _cargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  double _comisionEstimadaRow(Map<String, dynamic> row) {
    final cantidadVendida = _toInt(row['cantidad_habilitada_comision']);
    final comisionHabilitada = _toDouble(row['comision_habilitada']);
    if (comisionHabilitada > 0) {
      return comisionHabilitada;
    }
    final valor = _toDouble(row['comision_valor']);
    return cantidadVendida * valor;
  }

  Widget _buildPerfumeRow(Map<String, dynamic> row) {
    final cantidadVendida = _toInt(row['cantidad_vendida']);
    final montoVendido = _toDouble(row['monto_vendido']);
    final proximaFechaComision = row['proxima_fecha_comision']?.toString();
    final tipo = row['comision_tipo']?.toString() ?? 'rango_precio';
    final valor = _toDouble(row['comision_valor']);
    final precioLista = _toDouble(row['precio_lista']);
    final comisionHabilitada = _toDouble(row['comision_habilitada']);
    final comisionEstimada =
        comisionHabilitada > 0 ? comisionHabilitada : _comisionEstimadaRow(row);
    final comisionPorConfirmar = _toDouble(row['comision_por_confirmar']);
    final comisionCobrada = _toDouble(row['comision_cobrada']);
    final comisionDisponible = _toDouble(row['comision_disponible']);
    final estadoPago = row['estado_pago']?.toString() ?? 'por_pagar';
    final pendientePorFecha =
        comisionEstimada <= 0 && (proximaFechaComision ?? '').trim().isNotEmpty;
    final comisionTxt = tipo == 'rango_precio'
      ? '\$${valor.toStringAsFixed(2)} por perfume (segun precio de lista)'
      : '\$${valor.toStringAsFixed(2)} por perfume';
    final puedePagar = comisionDisponible > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.local_florist)),
        title: Text(row['nombre_perfume']?.toString() ?? 'Perfume'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pendientePorFecha)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            Text('Vendidos: $cantidadVendida unidades'),
            Text('Precio de lista: \$${precioLista.toStringAsFixed(2)}'),
            Text('Monto vendido: \$${montoVendido.toStringAsFixed(2)}'),
            if ((proximaFechaComision ?? '').trim().isNotEmpty)
              Text(
                'Proxima fecha de pago de comision: ${_formatDate(proximaFechaComision)}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            Text(
              comisionTxt,
              style: TextStyle(
                fontSize: 12,
                color: Colors.indigo.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
               'Comision habilitada: \$${comisionEstimada.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.indigo.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Por confirmar: \$${comisionPorConfirmar.toStringAsFixed(2)} · Cobrada: \$${comisionCobrada.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            Text(
              'Disponible para pagar: \$${comisionDisponible.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.indigo.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _estadoPagoColor(estadoPago).withOpacity(0.12),
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
        trailing: SizedBox(
          width: 104,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Auto',
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
              if (puedePagar) ...[
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _pagarComision(row),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade700,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(88, 34),
                    ),
                    child: const Text('Pagar'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grupos = _agrupadoPorVendedor;
    return AdminBackHandler(
      dashboardBuilder: (_) => const HomeScreen(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Comisiones'),
          backgroundColor: Colors.indigo.shade700,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        drawer: const AppDrawer(),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _rows.isEmpty
                ? const Center(
                    child: Text('No hay perfumes vendidos por vendedores'),
                  )
                : RefreshIndicator(
                    onRefresh: _cargar,
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
                                onSelected: (_) =>
                                    setState(() => _filtroEstado = 'todas'),
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text('Por pagar'),
                                selected: _filtroEstado == 'por_pagar',
                                onSelected: (_) =>
                                    setState(() => _filtroEstado = 'por_pagar'),
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text('Pagadas'),
                                selected: _filtroEstado == 'pagadas',
                                onSelected: (_) =>
                                    setState(() => _filtroEstado = 'pagadas'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (grupos.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 80),
                            child: Center(
                              child: Text('No hay comisiones para ese filtro'),
                            ),
                          )
                        else
                          ...grupos.entries.map((entry) {
                            final totalEstimado = entry.value.fold<double>(
                              0,
                              (sum, row) => sum + _comisionEstimadaRow(row),
                            );
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ExpansionTile(
                                initiallyExpanded: true,
                                leading: const Icon(Icons.person),
                                title: Text(
                                  entry.key,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  '${entry.value.length} perfume(s) vendido(s) • A pagar hoy: \$${totalEstimado.toStringAsFixed(2)}',
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        10, 0, 10, 10),
                                    child: Column(
                                      children: entry.value
                                          .map((row) => _buildPerfumeRow(row))
                                          .toList(),
                                    ),
                                  ),
                                ],
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
