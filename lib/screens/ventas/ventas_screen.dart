import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/admin_scope.dart';
import '../../database/database_helper.dart';
import '../../models/venta_credito.dart';
import '../../models/cliente.dart';
import '../../widgets/admin_back_handler.dart';
import '../../widgets/app_drawer.dart';
import '../home_screen.dart';
import 'venta_form.dart';
import 'venta_detalle_screen.dart';

class VentasScreen extends StatefulWidget {
  final Cliente? clienteFiltro;
  final int? vendedorFiltroId;
  const VentasScreen({super.key, this.clienteFiltro, this.vendedorFiltroId});

  @override
  State<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen> {
  List<VentaCredito> _ventas = [];
  bool _loading = true;
  String _filtroEstado = 'todos';

  int? get _vendedorRestringidoId => AdminScope.vendedorId;
  int? get _vendedorConsultaId =>
      widget.vendedorFiltroId ?? _vendedorRestringidoId;

  @override
  void initState() {
    super.initState();
    _cargar();
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
              title: const Text('Venta a crédito'),
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
    if (esContado == null || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VentaForm(
          clientePreseleccionado: widget.clienteFiltro,
          vendedorFijoId: _vendedorConsultaId,
          esContado: esContado,
        ),
      ),
    );
    _cargar();
  }

  Future<void> _cargar() async {
    List<VentaCredito> data;
    if (_vendedorConsultaId != null) {
      data = await DatabaseHelper().getVentasByVendedor(_vendedorConsultaId!);
      if (widget.clienteFiltro != null) {
        data =
            data.where((v) => v.clienteId == widget.clienteFiltro!.id).toList();
      }
    } else if (widget.clienteFiltro != null) {
      data =
          await DatabaseHelper().getVentasByCliente(widget.clienteFiltro!.id!);
    } else {
      data = await DatabaseHelper().getVentas();
      data = data.where((v) => v.vendedorId == null).toList();
    }
    if (mounted)
      setState(() {
        _ventas = data;
        _loading = false;
      });
  }

  List<VentaCredito> get _filtradas {
    if (_filtroEstado == 'todos') return _ventas;
    return _ventas.where((v) => v.estado == _filtroEstado).toList();
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

  String _labelEstado(String estado) {
    switch (estado) {
      case 'pagado':
        return 'Pagado';
      case 'parcial':
        return 'Parcial';
      default:
        return 'Pendiente';
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    return AdminBackHandler(
      dashboardBuilder: (_) => const HomeScreen(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.clienteFiltro != null
              ? 'Ventas - ${widget.clienteFiltro!.nombre}'
              : 'Ventas'),
          backgroundColor: Colors.orange.shade700,
          foregroundColor: Colors.white,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children:
                      ['todos', 'pendiente', 'parcial', 'pagado'].map((estado) {
                    final sel = _filtroEstado == estado;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                            estado == 'todos' ? 'Todos' : _labelEstado(estado)),
                        selected: sel,
                        onSelected: (_) =>
                            setState(() => _filtroEstado = estado),
                        selectedColor: Colors.white,
                        backgroundColor: Colors.orange.shade600,
                        labelStyle: TextStyle(
                            color: sel ? Colors.orange.shade800 : Colors.white),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
        drawer: const AppDrawer(),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _nuevaVenta,
          icon: const Icon(Icons.add),
          label: const Text('Nueva venta'),
          backgroundColor: Colors.orange.shade700,
          foregroundColor: Colors.white,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _filtradas.isEmpty
                ? const Center(child: Text('Sin ventas registradas'))
                : ListView(
                    padding: const EdgeInsets.only(bottom: 12),
                    children: [
                      ..._filtradas.map((v) {
                        return Card(
                          margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          VentaDetalleScreen(venta: v)));
                              _cargar();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                            v.nombreCliente ?? 'Cliente',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16)),
                                      ),
                                      Chip(
                                        label: Text(_labelEstado(v.estado),
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12)),
                                        backgroundColor: _colorEstado(v.estado),
                                        padding: EdgeInsets.zero,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today,
                                          size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(fmt.format(DateTime.parse(v.fecha)),
                                          style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 13)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Plan: ${v.cantidadPagos} pago${v.cantidadPagos > 1 ? 's' : ''} ${v.frecuenciaPago}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.black54),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text('Total',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black45)),
                                          Text(
                                              '\$${v.montoTotal.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text('Pagado',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black45)),
                                          Text(
                                              '\$${v.montoPagado.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      Colors.green.shade700)),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text('Pendiente',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black45)),
                                          Text(
                                              '\$${v.saldoPendiente.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: v.saldoPendiente > 0
                                                      ? Colors.red.shade700
                                                      : Colors.green.shade700)),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (v.notas.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(v.notas,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                            fontStyle: FontStyle.italic)),
                                  ],
                                  const SizedBox(height: 4),
                                  const Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                        'Toca para ver detalles y pagos',
                                        style: TextStyle(
                                            fontSize: 11, color: Colors.blue)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
      ),
    );
  }
}
