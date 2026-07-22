import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/admin_scope.dart';
import '../../database/database_helper.dart';
import '../../models/venta_credito.dart';
import '../../models/detalle_venta.dart';
import '../../models/pago_venta.dart';
import '../../models/perfume.dart';
import '../../models/cliente.dart';
import '../../models/vendedor.dart';
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

class VentaForm extends StatefulWidget {
  final Cliente? clientePreseleccionado;
  final int? vendedorFijoId;
  final bool esContado;
  const VentaForm(
      {super.key,
      this.clientePreseleccionado,
      this.vendedorFijoId,
      this.esContado = false});

  @override
  State<VentaForm> createState() => _VentaFormState();
}

class _VentaFormState extends State<VentaForm> {
  final _formKey = GlobalKey<FormState>();
  List<Cliente> _clientes = [];
  List<Perfume> _perfumes = [];
  Cliente? _clienteSel;
  DateTime _fecha = DateTime.now();
  DateTime _fechaPrimerPago = _nextPaymentCutoffOnOrAfter(DateTime.now());
  int _cantidadPagos = 1;
  final _notas = TextEditingController();
  final List<_ItemVenta> _items = [];
  Vendedor? _vendedorActual;
  bool _guardando = false;
  bool _loading = true;

  int? get _vendedorRestringidoId =>
      AdminScope.vendedorId ?? widget.vendedorFijoId;

  int? get _vendedorEfectivoId => _vendedorRestringidoId;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final db = DatabaseHelper();
    final clientesRaw =
        await db.getClientes(vendedorId: _vendedorRestringidoId);
    final p = _vendedorRestringidoId != null
        ? await db.getPerfumesDisponiblesParaVendedor(_vendedorRestringidoId!)
        : await db.getPerfumes();
    final clientes = _vendedorRestringidoId != null
        ? clientesRaw
        : clientesRaw.where((c) => c.vendedorId == null).toList();
    Vendedor? vendedorActual;
    if (_vendedorRestringidoId != null) {
      final vendedores = await db.getVendedores();
      final idx = vendedores.indexWhere((v) =>
          (v.id == _vendedorRestringidoId) ||
          (v.apiId == _vendedorRestringidoId));
      if (idx >= 0) {
        vendedorActual = vendedores[idx];
      }
    }

    Cliente? clienteInicial;
    if (widget.clientePreseleccionado != null) {
      final pre = widget.clientePreseleccionado!;
      final idx = clientes.indexWhere((x) => x.id == pre.id);
      if (idx >= 0) {
        clienteInicial = clientes[idx];
      }
    }
    clienteInicial ??= clientes.isNotEmpty ? clientes.first : null;

    if (mounted) {
      setState(() {
        _clientes = clientes;
        _perfumes = p;
        _clienteSel = clienteInicial;
        _vendedorActual = vendedorActual;
        _loading = false;
      });
      _recalcularPreciosSegunRegla();
    }
  }

  double get _total => _items.fold(0, (s, i) => s + i.subtotal);

  DateTime? get _fechaRegistroVendedor {
    final raw = _vendedorActual?.fechaRegistro;
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  int? get _mesesAntiguedadVendedor {
    final fechaReg = _fechaRegistroVendedor;
    if (fechaReg == null) return null;
    var meses =
        (_fecha.year - fechaReg.year) * 12 + (_fecha.month - fechaReg.month);
    if (_fecha.day < fechaReg.day) {
      meses -= 1;
    }
    return meses < 0 ? 0 : meses;
  }

  bool get _aplicaDescuentoEmbajador =>
      _vendedorEfectivoId != null && _mesesAntiguedadVendedor != null;

  String get _nivelEmbajador {
    final meses = _mesesAntiguedadVendedor;
    if (meses == null) return 'No definido';
    if (meses <= 5) return 'Embajador Nuevo';
    if (meses <= 12) return 'Embajador Intermedio';
    return 'Embajador Consolidado';
  }

  double _descuentoPorAntiguedad(bool esContado) {
    final meses = _mesesAntiguedadVendedor;
    if (meses == null) return 0;
    if (meses <= 5) return esContado ? 25 : 20;
    if (meses <= 12) return esContado ? 20 : 15;
    return esContado ? 10 : 5;
  }

  double get _descuentoActual => _descuentoPorAntiguedad(widget.esContado);

  double _precioUnitarioSegunRegla(Perfume perfume) {
    if (!_aplicaDescuentoEmbajador) return perfume.precioVenta;
    final factor = (100 - _descuentoActual) / 100;
    final precio = perfume.precioVenta * factor;
    return precio < 0 ? 0 : precio;
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

  Cliente? _buscarClienteContado(List<Cliente> clientes) {
    for (final c in clientes) {
      final nombre = c.nombre.trim().toLowerCase();
      if (nombre == 'cliente contado' || nombre == 'consumidor final') {
        return c;
      }
    }
    return null;
  }

  Future<int?> _resolverClienteId() async {
    if (_clienteSel?.id != null) return _clienteSel!.id;
    if (!widget.esContado) return null;

    final existente = _buscarClienteContado(_clientes);
    if (existente?.id != null) {
      _clienteSel = existente;
      return existente!.id;
    }

    final nuevo = Cliente(
      vendedorId: _vendedorRestringidoId,
      nombre: 'Cliente contado',
      telefono: '',
      email: '',
      direccion: '',
    );
    final id = await DatabaseHelper().insertCliente(nuevo);
    final recargados =
        await DatabaseHelper().getClientes(vendedorId: _vendedorRestringidoId);
    final filtrados = _vendedorRestringidoId != null
        ? recargados
        : recargados.where((c) => c.vendedorId == null).toList();
    final creado = filtrados
        .where((c) => c.id == id)
        .cast<Cliente?>()
        .firstWhere((c) => c != null, orElse: () => null);

    if (mounted) {
      setState(() {
        _clientes = filtrados;
        _clienteSel = creado ?? _buscarClienteContado(filtrados);
      });
    }
    return _clienteSel?.id;
  }

  void _agregarItem() {
    if (_perfumes.isEmpty) return;
    setState(() {
      _items.add(_ItemVenta(
        perfume: _perfumes.first,
        cantidad: 1,
        precio: _precioUnitarioSegunRegla(_perfumes.first),
      ));
    });
  }

  void _quitarItem(int idx) => setState(() => _items.removeAt(idx));

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final clienteId = await _resolverClienteId();
    if (clienteId == null) {
      messenger
          .showSnackBar(const SnackBar(content: Text('Selecciona un cliente')));
      return;
    }
    if (_items.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Agrega al menos un producto')));
      return;
    }
    if (_fechaPrimerPago
        .isBefore(DateTime(_fecha.year, _fecha.month, _fecha.day))) {
      messenger.showSnackBar(const SnackBar(
          content: Text(
              'La fecha del primer pago no puede ser anterior a la fecha de venta')));
      return;
    }
    // Validar stock
    for (final item in _items) {
      final disponible = _vendedorRestringidoId != null
          ? await DatabaseHelper().getStockDisponibleVendedorPerfume(
              _vendedorRestringidoId!, item.perfume.id!)
          : item.perfume.stock;
      if (item.cantidad > disponible) {
        messenger.showSnackBar(SnackBar(
            content: Text(
                'Stock insuficiente para "${item.perfume.nombre}". Disponible: $disponible')));
        return;
      }
    }
    setState(() => _guardando = true);
    final venta = VentaCredito(
      clienteId: clienteId,
      vendedorId: _vendedorEfectivoId,
      fecha: DateFormat('yyyy-MM-dd').format(_fecha),
      fechaPrimerPago: DateFormat('yyyy-MM-dd')
          .format(widget.esContado ? _fecha : _fechaPrimerPago),
      montoTotal: _total,
      notas: _notas.text.trim(),
      cantidadPagos: widget.esContado ? 1 : _cantidadPagos,
      frecuenciaPago: 'quincenal',
    );
    final detalles = _items
        .map((i) => DetalleVenta(
              ventaId: 0,
              perfumeId: i.perfume.id!,
              cantidad: i.cantidad,
              precioUnitario: i.precio,
            ))
        .toList();
    final ventaId = await DatabaseHelper().insertVenta(
      venta,
      detalles,
      tipoVenta: widget.esContado ? 'contado' : 'credito',
    );
    if (widget.esContado) {
      final pago = PagoVenta(
        ventaId: ventaId,
        monto: _total,
        fecha: DateFormat('yyyy-MM-dd').format(_fecha),
        notas: 'Pago de contado automatico',
      );
      await DatabaseHelper().registrarPago(pago);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AdminBackHandler(
      dashboardBuilder: (_) => const HomeScreen(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.esContado
              ? 'Nueva venta de contado'
              : 'Nueva venta a crédito'),
          backgroundColor: Colors.orange.shade700,
          foregroundColor: Colors.white,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Cliente
                            const Text('Cliente',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<Cliente>(
                              initialValue: _clienteSel,
                              items: _clientes
                                  .map((c) => DropdownMenuItem(
                                      value: c, child: Text(c.nombre)))
                                  .toList(),
                              onChanged: (c) => setState(() => _clienteSel = c),
                              decoration: InputDecoration(
                                labelText: widget.esContado
                                    ? 'Cliente (opcional)'
                                    : 'Cliente',
                                prefixIcon: const Icon(Icons.person),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              validator: (v) {
                                if (widget.esContado) return null;
                                return v == null ? 'Requerido' : null;
                              },
                            ),
                            if (_clientes.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  widget.esContado
                                      ? 'No hay clientes. Se creará automaticamente "Cliente contado" al registrar.'
                                      : 'No hay clientes registrados para este módulo.',
                                  style: TextStyle(
                                    color: Colors.orange.shade800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 14),
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
                                        'Descuento ${widget.esContado ? 'de contado' : 'a crédito'}: ${_descuentoActual.toStringAsFixed(0)}%',
                                        style: TextStyle(color: Colors.green.shade900),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                            if (!widget.esContado) ...[
                              const Text('Plan de pagos',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<int>(
                                initialValue: _cantidadPagos,
                                items: List.generate(
                                  24,
                                  (i) => i + 1,
                                )
                                    .map((n) => DropdownMenuItem(
                                          value: n,
                                          child: Text(
                                              '$n pago${n > 1 ? 's' : ''} (15 y fin de mes)'),
                                        ))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() => _cantidadPagos = v);
                                  }
                                },
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.event_repeat),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _cantidadPagos > 1
                                    ? 'Cuota estimada: \$${(_total / _cantidadPagos).toStringAsFixed(2)} en cada corte (15 y fin de mes)'
                                    : 'Pago unico: \$${_total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black54),
                              ),
                              const SizedBox(height: 8),
                              Card(
                                elevation: 0,
                                color: Colors.orange.shade50,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side:
                                      BorderSide(color: Colors.orange.shade100),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Fechas de pago (15 y fin de mes)',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600),
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
                                          padding:
                                              const EdgeInsets.only(bottom: 2),
                                          child: Text(
                                            'Cuota $idx: ${DateFormat('dd/MM/yyyy').format(fecha)}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black87),
                                          ),
                                        );
                                      }),
                                      if (_cantidadPagos > 6)
                                        Text(
                                          '... y ${_cantidadPagos - 6} fecha(s) más',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.event_available),
                                title: Text(
                                    'Primer pago: ${DateFormat('dd/MM/yyyy').format(_fechaPrimerPago)}'),
                                trailing: const Icon(Icons.edit_calendar),
                                shape: RoundedRectangleBorder(
                                    side:
                                        const BorderSide(color: Colors.black26),
                                    borderRadius: BorderRadius.circular(10)),
                                onTap: () async {
                                  final d = await showDatePicker(
                                    context: context,
                                    initialDate: _fechaPrimerPago,
                                    firstDate: _fecha,
                                    lastDate: DateTime(2100),
                                  );
                                  if (d != null) {
                                    setState(() => _fechaPrimerPago =
                                        _nextPaymentCutoffOnOrAfter(d));
                                  }
                                },
                              ),
                              const SizedBox(height: 14),
                            ],
                            // Fecha
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.calendar_today),
                              title: Text(
                                  'Fecha: ${DateFormat('dd/MM/yyyy').format(_fecha)}'),
                              trailing: const Icon(Icons.edit_calendar),
                              shape: RoundedRectangleBorder(
                                  side: const BorderSide(color: Colors.black26),
                                  borderRadius: BorderRadius.circular(10)),
                              onTap: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: _fecha,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                );
                                if (d != null) {
                                  setState(() {
                                    _fecha = d;
                                    if (_fechaPrimerPago.isBefore(d)) {
                                      _fechaPrimerPago =
                                          _nextPaymentCutoffOnOrAfter(d);
                                    }
                                      _recalcularPreciosSegunRegla();
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 14),
                            // Notas
                            TextFormField(
                              controller: _notas,
                              maxLines: 2,
                              decoration: InputDecoration(
                                labelText: 'Notas (opcional)',
                                prefixIcon: const Icon(Icons.notes),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Productos
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Productos',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                ElevatedButton.icon(
                                  onPressed: _agregarItem,
                                  icon: const Icon(Icons.add, size: 18),
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
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                    child: Text('Agrega productos a la venta',
                                        style:
                                            TextStyle(color: Colors.black45))),
                              ),
                            ..._items.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final item = entry.value;
                              return _ItemCard(
                                item: item,
                                perfumes: _perfumes,
                                precioEditable: !_aplicaDescuentoEmbajador,
                                precioSugeridoBuilder: _precioUnitarioSegunRegla,
                                onRemove: () => _quitarItem(idx),
                                onChanged: () => setState(() {}),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                    // Totales y guardar
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                              blurRadius: 8,
                              color: Colors.black12,
                              offset: Offset(0, -2))
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Total a crédito',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.black54)),
                                const SizedBox(height: 2),
                                Text(
                                    widget.esContado
                                        ? 'Venta de contado'
                                        : 'Venta a crédito',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.black45)),
                                Text('\$${_total.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange)),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _guardando ? null : _guardar,
                            icon: _guardando
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.save),
                            label: const Text('Registrar venta'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
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

  @override
  void dispose() {
    _notas.dispose();
    super.dispose();
  }
}

class _ItemVenta {
  Perfume perfume;
  int cantidad;
  double precio;
  _ItemVenta(
      {required this.perfume, required this.cantidad, required this.precio});
  double get subtotal => cantidad * precio;
}

class _ItemCard extends StatefulWidget {
  final _ItemVenta item;
  final List<Perfume> perfumes;
  final bool precioEditable;
  final double Function(Perfume perfume) precioSugeridoBuilder;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  const _ItemCard({
    required this.item,
    required this.perfumes,
    required this.precioEditable,
    required this.precioSugeridoBuilder,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  late TextEditingController _cantCtrl;
  late TextEditingController _precioCtrl;

  @override
  void initState() {
    super.initState();
    _cantCtrl = TextEditingController(text: widget.item.cantidad.toString());
    _precioCtrl = TextEditingController(text: widget.item.precio.toString());
  }

  @override
  void dispose() {
    _cantCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nuevaCantidad = widget.item.cantidad.toString();
    final nuevoPrecio = widget.item.precio.toStringAsFixed(2);
    if (_cantCtrl.text != nuevaCantidad) {
      _cantCtrl.text = nuevaCantidad;
    }
    if (_precioCtrl.text != nuevoPrecio) {
      _precioCtrl.text = nuevoPrecio;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<Perfume>(
                    initialValue: widget.item.perfume,
                    isExpanded: true,
                    items: widget.perfumes
                        .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text('${p.nombre} (${p.stock})',
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (p) {
                      if (p != null) {
                        widget.item.perfume = p;
                        final sugerido = widget.precioSugeridoBuilder(p);
                        widget.item.precio = sugerido;
                        _precioCtrl.text = sugerido.toStringAsFixed(2);
                        widget.onChanged();
                      }
                    },
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                  onPressed: widget.onRemove,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cantCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Cant.',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      widget.item.cantidad = int.tryParse(v) ?? 1;
                      widget.onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _precioCtrl,
                    enabled: widget.precioEditable,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Precio',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      widget.item.precio = double.tryParse(v) ?? 0;
                      widget.onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Text('\$${widget.item.subtotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
