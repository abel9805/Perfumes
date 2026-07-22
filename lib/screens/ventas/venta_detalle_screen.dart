import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/venta_credito.dart';
import '../../models/detalle_venta.dart';
import '../../models/pago_venta.dart';
import '../../widgets/admin_back_handler.dart';
import '../home_screen.dart';

bool _isPaymentCutoffDate(DateTime date) {
  final lastDay = DateTime(date.year, date.month + 1, 0).day;
  return date.day == 15 || date.day == lastDay;
}

DateTime _nextPaymentCutoffOnOrAfter(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  final lastDay = DateTime(d.year, d.month + 1, 0).day;
  if (d.day <= 15) return DateTime(d.year, d.month, 15);
  if (d.day <= lastDay) return DateTime(d.year, d.month, lastDay);
  return DateTime(d.year, d.month + 1, 15);
}

DateTime _nextPaymentCutoffAfter(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  final lastDay = DateTime(d.year, d.month + 1, 0).day;
  if (d.day < 15) return DateTime(d.year, d.month, 15);
  if (d.day < lastDay) return DateTime(d.year, d.month, lastDay);
  return DateTime(d.year, d.month + 1, 15);
}

List<DateTime> _buildPaymentCutoffSchedule(DateTime start, int count) {
  if (count <= 0) return const [];
  final result = <DateTime>[];
  var current = _nextPaymentCutoffOnOrAfter(start);
  for (var i = 0; i < count; i++) {
    result.add(current);
    current = _nextPaymentCutoffAfter(current);
  }
  return result;
}

class VentaDetalleScreen extends StatefulWidget {
  final VentaCredito venta;
  const VentaDetalleScreen({super.key, required this.venta});

  @override
  State<VentaDetalleScreen> createState() => _VentaDetalleScreenState();
}

class _VentaDetalleScreenState extends State<VentaDetalleScreen> {
  List<DetalleVenta> _detalles = [];
  List<PagoVenta> _pagos = [];
  late VentaCredito _venta;
  bool _loading = true;

  DateTime _fechaBasePrimerPago() {
    final primerPago = DateTime.tryParse(_venta.fechaPrimerPago ?? '');
    if (primerPago != null && _isPaymentCutoffDate(primerPago)) {
      return primerPago;
    }

    final venta = DateTime.tryParse(_venta.fecha) ?? DateTime.now();
    return _nextPaymentCutoffOnOrAfter(venta);
  }

  List<DateTime> _fechasSugeridasQuincenales() {
    return _buildPaymentCutoffSchedule(
      _fechaBasePrimerPago(),
      _venta.cantidadPagos,
    );
  }

  DateTime? _proximaFechaPago() {
    if (_venta.saldoPendiente <= 0) return null;
    final cuota = _montoCuotaBase();
    if (cuota <= 0) return _fechaBasePrimerPago();
    final cuotasCubiertas = (_venta.montoPagado / cuota).floor();
    final idx = cuotasCubiertas.clamp(0, _venta.cantidadPagos - 1);
    final fechas = _fechasSugeridasQuincenales();
    return fechas.isEmpty ? _fechaBasePrimerPago() : fechas[idx];
  }

  int get _totalUnidadesVendidas =>
      _detalles.fold<int>(0, (s, d) => s + d.cantidad);

  double get _totalComisiones =>
      _pagos.fold<double>(0, (s, p) => s + p.comisionTotal);

  bool get _adminPuedeRegistrarPago => _venta.vendedorId == null;

  double _montoCuotaBase() {
    if (_venta.cantidadPagos <= 0) return _venta.montoTotal;
    return _venta.montoTotal / _venta.cantidadPagos;
  }

  Widget _buildCalendarioPagos(DateFormat fmt) {
    final fechas = _fechasSugeridasQuincenales();
    final cuota = _montoCuotaBase();
    final montoPagado = _venta.montoPagado;
    final cuotasCompletas = cuota > 0 ? (montoPagado / cuota).floor() : 0;
    final cuotaParcial = cuota > 0 &&
        cuotasCompletas < _venta.cantidadPagos &&
        (montoPagado - (cuotasCompletas * cuota)) > 0;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Calendario sugerido de pagos (quincenal)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...List.generate(fechas.length, (i) {
              final idx = i + 1;
              final cubierta = idx <= cuotasCompletas;
              final parcial =
                  !cubierta && cuotaParcial && idx == (cuotasCompletas + 1);
              final montoCuota = idx == _venta.cantidadPagos
                  ? (_venta.montoTotal - (cuota * (_venta.cantidadPagos - 1)))
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
                title: Text('Cuota $idx - ${fmt.format(fechas[i])}'),
                subtitle:
                    Text('Monto sugerido: \$${montoCuota.toStringAsFixed(2)}'),
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

  @override
  void initState() {
    super.initState();
    _venta = widget.venta;
    _cargar();
  }

  Future<void> _cargar() async {
    final db = DatabaseHelper();
    final d = await db.getDetallesVenta(_venta.id!);
    final p = await db.getPagosByVenta(_venta.id!);
    // Recargar venta actualizada
    final ventas = _venta.vendedorId != null
        ? await db.getVentasByVendedor(_venta.vendedorId!)
        : await db.getVentasByCliente(_venta.clienteId);
    final ventaActualizada =
        ventas.firstWhere((v) => v.id == _venta.id, orElse: () => _venta);
    if (mounted) {
      setState(() {
        _detalles = d;
        _pagos = p;
        _venta = ventaActualizada;
        _loading = false;
      });
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
    if (!_adminPuedeRegistrarPago) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El admin no puede registrar pagos de ventas de vendedores.',
          ),
        ),
      );
      return;
    }

    if (_venta.saldoPendiente <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Esta venta ya está completamente pagada')));
      return;
    }
    final montoCtrl =
        TextEditingController(text: _venta.saldoPendiente.toStringAsFixed(2));
    final notasCtrl = TextEditingController();
    final comisionValorCtrl = TextEditingController();
    String comisionModo = 'sin_comision';
    DateTime fecha = _nextPaymentCutoffOnOrAfter(DateTime.now());

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Registrar pago'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    'Saldo pendiente: \$${_venta.saldoPendiente.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                TextFormField(
                  controller: montoCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Monto a pagar',
                    prefixIcon: Icon(Icons.attach_money),
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_venta.vendedorId != null) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: comisionModo,
                    items: const [
                      DropdownMenuItem(
                          value: 'sin_comision', child: Text('Sin comisión')),
                      DropdownMenuItem(
                          value: 'monto',
                          child: Text('Monto por perfume vendido')),
                      DropdownMenuItem(
                          value: 'porcentaje',
                          child: Text('Porcentaje del precio vendido')),
                    ],
                    onChanged: (v) {
                      setS(() {
                        comisionModo = v ?? 'sin_comision';
                        if (comisionModo == 'sin_comision') {
                          comisionValorCtrl.clear();
                        }
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Tipo de comisión para el vendedor',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (comisionModo != 'sin_comision') ...[
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: comisionValorCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setS(() {}),
                      decoration: InputDecoration(
                        labelText: comisionModo == 'monto'
                            ? 'Monto por perfume'
                            : 'Porcentaje (%)',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Builder(builder: (_) {
                      final valor =
                          double.tryParse(comisionValorCtrl.text) ?? 0;
                      final estimada = comisionModo == 'monto'
                          ? valor * _totalUnidadesVendidas
                          : (_venta.montoTotal * valor / 100);
                      return Text(
                        'Comisión estimada del pago: \$${estimada.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54),
                      );
                    }),
                  ],
                ],
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title:
                      Text('Fecha: ${DateFormat('dd/MM/yyyy').format(fecha)}'),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: fecha,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) {
                      setS(() => fecha = _nextPaymentCutoffOnOrAfter(d));
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: notasCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                    prefixIcon: Icon(Icons.notes),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                final monto = double.tryParse(montoCtrl.text);
                if (monto == null || monto <= 0) return;
                if (monto > _venta.saldoPendiente) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('El monto excede el saldo pendiente')));
                  return;
                }

                final valorComision =
                    double.tryParse(comisionValorCtrl.text) ?? 0;
                if (comisionModo != 'sin_comision' && valorComision <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Ingresa un valor de comisión válido')));
                  return;
                }
                final pago = PagoVenta(
                  ventaId: _venta.id!,
                  monto: monto,
                  fecha: DateFormat('yyyy-MM-dd').format(fecha),
                  notas: notasCtrl.text.trim(),
                  comisionTipo:
                      comisionModo == 'sin_comision' ? null : comisionModo,
                  comisionValor:
                      comisionModo == 'sin_comision' ? 0 : valorComision,
                );
                await DatabaseHelper().registrarPago(pago);
                if (ctx.mounted) Navigator.pop(ctx);
                _cargar();
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white),
              child: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    return AdminBackHandler(
      dashboardBuilder: (_) => const HomeScreen(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(_venta.nombreCliente ?? 'Venta'),
          backgroundColor: Colors.orange.shade700,
          foregroundColor: Colors.white,
          actions: [
            if (_adminPuedeRegistrarPago)
              IconButton(
                icon: const Icon(Icons.payment),
                tooltip: 'Registrar pago',
                onPressed: _registrarPago,
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Resumen venta
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_venta.nombreCliente ?? 'Cliente',
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                                Chip(
                                  label: Text(
                                      _venta.estado[0].toUpperCase() +
                                          _venta.estado.substring(1),
                                      style:
                                          const TextStyle(color: Colors.white)),
                                  backgroundColor: _colorEstado(_venta.estado),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                                'Fecha: ${fmt.format(DateTime.parse(_venta.fecha))}',
                                style: const TextStyle(color: Colors.black54)),
                            const SizedBox(height: 2),
                            Text(
                              'Plan: ${_venta.cantidadPagos} pago${_venta.cantidadPagos > 1 ? 's' : ''} ${_venta.frecuenciaPago}',
                              style: const TextStyle(color: Colors.black54),
                            ),
                            if (_proximaFechaPago() != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors.orange.shade200),
                                  ),
                                  child: Text(
                                    'Proxima fecha de pago: ${fmt.format(_proximaFechaPago()!)}',
                                    style: TextStyle(
                                      color: Colors.orange.shade800,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            if (_venta.notas.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('Nota: ${_venta.notas}',
                                    style: const TextStyle(
                                        color: Colors.black54,
                                        fontStyle: FontStyle.italic)),
                              ),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _montoBox(
                                    'Total', _venta.montoTotal, Colors.black87),
                                _montoBox('Pagado', _venta.montoPagado,
                                    Colors.green.shade700),
                                _montoBox(
                                    'Pendiente',
                                    _venta.saldoPendiente,
                                    _venta.saldoPendiente > 0
                                        ? Colors.red.shade700
                                        : Colors.green.shade700),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (_venta.vendedorId != null)
                              Text(
                                'Comisión acumulada vendedor: \$${_totalComisiones.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.indigo.shade700,
                                ),
                              ),
                            if (!_adminPuedeRegistrarPago)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Los pagos de esta venta deben ser registrados por el vendedor.',
                                  style: TextStyle(
                                    color: Colors.orange.shade800,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCalendarioPagos(fmt),
                    const SizedBox(height: 16),
                    // Productos
                    const Text('Productos',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ..._detalles.map((d) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                            leading: const Icon(Icons.local_florist,
                                color: Colors.purple),
                            title: Text(d.nombrePerfume ?? 'Perfume'),
                            subtitle: Text(
                                '${d.cantidad} x \$${d.precioUnitario.toStringAsFixed(2)}'),
                            trailing: Text('\$${d.subtotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                        )),
                    const SizedBox(height: 16),
                    // Pagos
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Historial de pagos',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        if (_adminPuedeRegistrarPago)
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
                            child: Text('Sin pagos registrados',
                                style: TextStyle(color: Colors.black45))),
                      ),
                    ..._pagos.map((p) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFE8F5E9),
                              child: Icon(Icons.payments, color: Colors.green),
                            ),
                            title: Text('\$${p.monto.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(fmt.format(DateTime.parse(p.fecha))),
                                if (p.comisionTotal > 0)
                                  Text(
                                    'Comisión: \$${p.comisionTotal.toStringAsFixed(2)}'
                                    '${p.comisionTipo == 'porcentaje' ? ' (${p.comisionValor.toStringAsFixed(2)}%)' : (p.comisionTipo == 'monto' ? ' (\$${p.comisionValor.toStringAsFixed(2)} por perfume)' : '')}',
                                    style: TextStyle(
                                      color: Colors.indigo.shade700,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: p.notas.isNotEmpty
                                ? Tooltip(
                                    message: p.notas,
                                    child: const Icon(Icons.info_outline,
                                        size: 18))
                                : null,
                          ),
                        )),
                  ],
                ),
              ),
        floatingActionButton:
            _adminPuedeRegistrarPago && _venta.saldoPendiente > 0
                ? FloatingActionButton.extended(
                    onPressed: _registrarPago,
                    icon: const Icon(Icons.payment),
                    label: const Text('Registrar pago'),
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                  )
                : null,
      ),
    );
  }

  Widget _montoBox(String label, double monto, Color color) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.black45)),
        Text('\$${monto.toStringAsFixed(2)}',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
