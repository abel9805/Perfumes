import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/cliente.dart';
import '../../widgets/admin_back_handler.dart';
import '../home_screen.dart';

class ClienteForm extends StatefulWidget {
  final Cliente? cliente;
  final int? vendedorIdFijo;
  const ClienteForm({super.key, this.cliente, this.vendedorIdFijo});

  @override
  State<ClienteForm> createState() => _ClienteFormState();
}

class _ClienteFormState extends State<ClienteForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombre;
  late TextEditingController _telefono;
  late TextEditingController _email;
  late TextEditingController _direccion;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final c = widget.cliente;
    _nombre = TextEditingController(text: c?.nombre ?? '');
    _telefono = TextEditingController(text: c?.telefono ?? '');
    _email = TextEditingController(text: c?.email ?? '');
    _direccion = TextEditingController(text: c?.direccion ?? '');
  }

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    _email.dispose();
    _direccion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    final c = Cliente(
      id: widget.cliente?.id,
      vendedorId: widget.vendedorIdFijo ?? widget.cliente?.vendedorId,
      nombre: _nombre.text.trim(),
      telefono: _telefono.text.trim(),
      email: _email.text.trim(),
      direccion: _direccion.text.trim(),
    );
    final db = DatabaseHelper();
    if (c.id == null) {
      await db.insertCliente(c);
    } else {
      await db.updateCliente(c);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.cliente != null;
    return AdminBackHandler(
      dashboardBuilder: (_) => const HomeScreen(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEdit ? 'Editar cliente' : 'Nuevo cliente'),
          backgroundColor: Colors.teal.shade700,
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
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _guardando ? null : _guardar,
                    icon: const Icon(Icons.save),
                    label: Text(isEdit ? 'Actualizar' : 'Guardar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
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
