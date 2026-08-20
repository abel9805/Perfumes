import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/app_mode.dart';
import '../../database/database_helper.dart';
import '../../models/entrega_vendedor.dart';
import '../../models/vendedor.dart';
import '../../models/perfume.dart';
import '../../widgets/admin_back_handler.dart';
import '../home_screen.dart';

class EntregaForm extends StatefulWidget {
  final Vendedor? vendedorPreseleccionado;
  final bool modoPedidos;
  const EntregaForm(
      {super.key, this.vendedorPreseleccionado, this.modoPedidos = false});

  @override
  State<EntregaForm> createState() => _EntregaFormState();
}

class _EntregaFormState extends State<EntregaForm> {
  final _formKey = GlobalKey<FormState>();
  List<Vendedor> _vendedores = [];
  List<Perfume> _perfumes = [];
  Vendedor? _vendedorSel;
  Perfume? _perfumeSel;
  final _cantidad = TextEditingController(text: '1');
  final _precio = TextEditingController();
  DateTime _fecha = DateTime.now();
  bool _guardando = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final db = DatabaseHelper();
    final v = (await db.getVendedores()).where((x) => x.apiId != null).toList();
    final p = (await db.getPerfumes()).where((x) => x.apiId != null).toList();
    if (mounted) {
      setState(() {
        _vendedores = v;
        _perfumes = p;
        _vendedorSel = widget.vendedorPreseleccionado != null && v.isNotEmpty
            ? v.firstWhere(
                (x) => x.id == widget.vendedorPreseleccionado!.id,
                orElse: () => v.first,
              )
            : (v.isNotEmpty ? v.first : null);
        _perfumeSel = p.isNotEmpty ? p.first : null;
        if (_perfumeSel != null) {
          _precio.text = _perfumeSel!.precioVenta.toString();
        }
        _loading = false;
      });
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_vendedorSel == null || _perfumeSel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona vendedor y perfume')));
      return;
    }
    final cant = int.parse(_cantidad.text);
    if (cant > _perfumeSel!.stock) {
      final msg = AppModeConfig.isColega
        ? 'Cantidad no disponible.'
        : 'Stock insuficiente. Disponible: ${_perfumeSel!.stock}';
      ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
      return;
    }
    setState(() => _guardando = true);
    final entrega = EntregaVendedor(
      vendedorId: _vendedorSel!.id!,
      perfumeId: _perfumeSel!.id!,
      cantidad: cant,
      precioUnitario: double.parse(_precio.text),
      fecha: DateFormat('yyyy-MM-dd').format(_fecha),
      estado: widget.modoPedidos ? 'solicitado' : 'pendiente_confirmacion',
    );
    try {
      await DatabaseHelper().insertEntrega(entrega);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo registrar la entrega: $e')),
      );
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isColega = AppModeConfig.isColega;
    return AdminBackHandler(
      dashboardBuilder: (_) => const HomeScreen(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
              widget.modoPedidos ? 'Nuevo pedido' : 'Nueva entrega a vendedor'),
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_vendedores.isEmpty || _perfumes.isEmpty)
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No hay vendedores o perfumes sincronizados con el servidor.\n'
                        'Verifica que la API Laravel este activa y vuelve a intentar.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Vendedor',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<Vendedor>(
                            initialValue: _vendedorSel,
                            items: _vendedores
                                .map((v) => DropdownMenuItem(
                                    value: v, child: Text(v.nombre)))
                                .toList(),
                            onChanged: (v) => setState(() => _vendedorSel = v),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.people_alt),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            validator: (v) =>
                                v == null ? 'Selecciona un vendedor' : null,
                          ),
                          const SizedBox(height: 16),
                          const Text('Perfume',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<Perfume>(
                            initialValue: _perfumeSel,
                            items: _perfumes
                                .map((p) => DropdownMenuItem(
                                      value: p,
                                  child: Text(isColega
                                    ? p.nombre
                                    : '${p.nombre} (Stock: ${p.stock})'),
                                    ))
                                .toList(),
                            onChanged: (p) {
                              setState(() {
                                _perfumeSel = p;
                                if (p != null) {
                                  _precio.text = p.precioVenta.toString();
                                }
                              });
                            },
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.local_florist),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            validator: (v) =>
                                v == null ? 'Selecciona un perfume' : null,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _cantidad,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Cantidad',
                                    prefixIcon: const Icon(Icons.numbers),
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return 'Requerido';
                                    }
                                    final n = int.tryParse(v);
                                    if (n == null || n <= 0) return 'Inválido';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _precio,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'Precio unitario',
                                    prefixIcon: const Icon(Icons.attach_money),
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return 'Requerido';
                                    }
                                    if (double.tryParse(v) == null) {
                                      return 'Inválido';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
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
                              if (d != null) setState(() => _fecha = d);
                            },
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _guardando ? null : _guardar,
                              icon: const Icon(Icons.save),
                              label: const Text('Registrar entrega'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  @override
  void dispose() {
    _cantidad.dispose();
    _precio.dispose();
    super.dispose();
  }
}
