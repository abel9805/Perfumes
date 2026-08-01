import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/perfume.dart';
import '../../models/vendedor.dart';
import '../../widgets/admin_back_handler.dart';
import '../home_screen.dart';

class VendedorForm extends StatefulWidget {
  final Vendedor? vendedor;
  const VendedorForm({super.key, this.vendedor});

  @override
  State<VendedorForm> createState() => _VendedorFormState();
}

class _VendedorFormState extends State<VendedorForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombre;
  late TextEditingController _telefono;
  late TextEditingController _email;
  late TextEditingController _direccion;
  late TextEditingController _usuario;
  late TextEditingController _password;
  String _tipoUsuario = 'vendedor';
  List<Perfume> _perfumes = [];
  final List<_StockInicialItem> _stockInicial = [];
  bool _loadingPerfumes = false;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final v = widget.vendedor;
    _nombre = TextEditingController(text: v?.nombre ?? '');
    _telefono = TextEditingController(text: v?.telefono ?? '');
    _email = TextEditingController(text: v?.email ?? '');
    _direccion = TextEditingController(text: v?.direccion ?? '');
    _usuario = TextEditingController(text: v?.usuario ?? '');
    _password = TextEditingController(text: v?.password ?? '');
    _tipoUsuario = v?.tipoUsuario == 'colega' ? 'colega' : 'vendedor';
    if (widget.vendedor == null) {
      _cargarPerfumes();
    }
  }

  Future<void> _cargarPerfumes() async {
    setState(() => _loadingPerfumes = true);
    final data = await DatabaseHelper().getPerfumes();
    if (!mounted) return;
    setState(() {
      _perfumes = data.where((p) => p.id != null).toList();
      _loadingPerfumes = false;
    });
  }

  void _agregarStockInicial() {
    if (_perfumes.isEmpty) return;
    setState(() {
      _stockInicial.add(_StockInicialItem(
        perfume: _perfumes.first,
        cantidad: 1,
        precioUnitario: _perfumes.first.precioVenta,
      ));
    });
  }

  String _hoyYmd() => DateTime.now().toIso8601String().split('T').first;

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    _email.dispose();
    _direccion.dispose();
    _usuario.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final isEdit = widget.vendedor != null;
    if (!isEdit) {
      final usados = <int>{};
      for (final item in _stockInicial) {
        final perfumeId = item.perfume.id;
        if (perfumeId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Perfume sin identificador válido')),
          );
          return;
        }
        if (!usados.add(perfumeId)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Perfume repetido en stock inicial: ${item.perfume.nombre}')),
          );
          return;
        }
        if (item.cantidad <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Cantidad inválida para ${item.perfume.nombre}')),
          );
          return;
        }
        if (item.cantidad > item.perfume.stock) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Stock inicial excede disponible para ${item.perfume.nombre}. Disponible: ${item.perfume.stock}'),
            ),
          );
          return;
        }
      }
    }

    setState(() => _guardando = true);
    final v = Vendedor(
      id: widget.vendedor?.id,
      apiId: widget.vendedor?.apiId,
      nombre: _nombre.text.trim(),
      telefono: _telefono.text.trim(),
      email: _email.text.trim(),
      direccion: _direccion.text.trim(),
      usuario: _usuario.text.trim(),
      password: _password.text.trim(),
      tipoUsuario: _tipoUsuario,
    );
    final db = DatabaseHelper();
    try {
      if (v.id == null) {
        final initialEntregas = _stockInicial
            .map((item) => {
                  'perfume_id': item.perfume.id,
                  'cantidad': item.cantidad,
                  'precio_unitario': item.precioUnitario,
                  'fecha': _hoyYmd(),
                })
            .toList();
        await db.insertVendedor(v, initialEntregas: initialEntregas);
      } else {
        await db.updateVendedor(v);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el vendedor: $e')),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.vendedor != null;
    return AdminBackHandler(
      dashboardBuilder: (_) => const HomeScreen(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEdit ? 'Editar vendedor' : 'Nuevo vendedor'),
          backgroundColor: Colors.indigo.shade700,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _field(_nombre, 'Nombre completo', Icons.person,
                    required: true),
                const SizedBox(height: 14),
                _field(_telefono, 'Teléfono', Icons.phone),
                const SizedBox(height: 14),
                _field(_email, 'Email', Icons.email,
                    type: TextInputType.emailAddress),
                const SizedBox(height: 14),
                _field(_direccion, 'Dirección', Icons.location_on, maxLines: 2),
                const SizedBox(height: 14),
                _field(_usuario, 'Usuario', Icons.account_circle,
                    required: true),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _tipoUsuario,
                  decoration: InputDecoration(
                    labelText: 'Tipo de usuario',
                    prefixIcon: const Icon(Icons.badge),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'vendedor',
                      child: Text('Vendedor'),
                    ),
                    DropdownMenuItem(
                      value: 'colega',
                      child: Text('Colega'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _tipoUsuario = value);
                  },
                ),
                const SizedBox(height: 14),
                _field(_password, 'Contraseña', Icons.lock, required: !isEdit),
                if (!isEdit) ...[
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Stock inicial (pendiente de aceptación del vendedor)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_loadingPerfumes)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(),
                    )
                  else if (_perfumes.isEmpty)
                    const Text(
                      'No hay perfumes disponibles para asignar stock inicial.',
                      style: TextStyle(color: Colors.black54),
                    )
                  else ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _agregarStockInicial,
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar perfume'),
                      ),
                    ),
                    if (_stockInicial.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 6),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Opcional: puedes dejarlo vacío y cargar entregas después.',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ),
                      ),
                    ..._stockInicial.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      return _StockInicialCard(
                        key: ValueKey(idx),
                        item: item,
                        perfumes: _perfumes,
                        onChanged: () => setState(() {}),
                        onRemove: () =>
                            setState(() => _stockInicial.removeAt(idx)),
                      );
                    }),
                  ],
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _guardando ? null : _guardar,
                    icon: const Icon(Icons.save),
                    label: Text(isEdit ? 'Actualizar' : 'Guardar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
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

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {bool required = false,
      TextInputType type = TextInputType.text,
      int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      validator: (v) {
        if (required && (v == null || v.trim().isEmpty))
          return 'Campo requerido';
        return null;
      },
    );
  }
}

class _StockInicialItem {
  Perfume perfume;
  int cantidad;
  double precioUnitario;

  _StockInicialItem({
    required this.perfume,
    required this.cantidad,
    required this.precioUnitario,
  });
}

class _StockInicialCard extends StatefulWidget {
  final _StockInicialItem item;
  final List<Perfume> perfumes;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _StockInicialCard({
    super.key,
    required this.item,
    required this.perfumes,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_StockInicialCard> createState() => _StockInicialCardState();
}

class _StockInicialCardState extends State<_StockInicialCard> {
  late final TextEditingController _cantidadCtrl;
  late final TextEditingController _precioCtrl;

  @override
  void initState() {
    super.initState();
    _cantidadCtrl =
        TextEditingController(text: widget.item.cantidad.toString());
    _precioCtrl = TextEditingController(
        text: widget.item.precioUnitario.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _cantidadCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
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
                  child: DropdownButtonFormField<Perfume>(
                    initialValue: widget.item.perfume,
                    items: widget.perfumes
                        .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text('${p.nombre} (Stock: ${p.stock})'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      widget.item.perfume = value;
                      if (widget.item.precioUnitario <= 0) {
                        widget.item.precioUnitario = value.precioVenta;
                        _precioCtrl.text =
                            widget.item.precioUnitario.toStringAsFixed(2);
                      }
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
                      widget.item.cantidad = int.tryParse(value) ?? 0;
                      widget.onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _precioCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Precio unitario'),
                    onChanged: (value) {
                      widget.item.precioUnitario = double.tryParse(value) ?? 0;
                      widget.onChanged();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
