import 'package:flutter/material.dart';
import '../../config/admin_scope.dart';
import '../../database/database_helper.dart';
import '../../models/cliente.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/admin_back_handler.dart';
import 'cliente_form.dart';
import '../ventas/ventas_screen.dart';
import '../home_screen.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  List<Cliente> _clientes = [];
  bool _loading = true;

  int? get _vendedorRestringidoId => AdminScope.vendedorId;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final data =
        await DatabaseHelper().getClientes(vendedorId: _vendedorRestringidoId);
    final filtrados = _vendedorRestringidoId != null
        ? data
        : data.where((c) => c.vendedorId == null).toList();
    if (mounted)
      setState(() {
        _clientes = filtrados;
        _loading = false;
      });
  }

  Future<void> _delete(Cliente c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar'),
        content: Text('¿Eliminar al cliente "${c.nombre}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      try {
        await DatabaseHelper().deleteCliente(c.id!);
        _cargar();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _abrirForm([Cliente? c]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClienteForm(
          cliente: c,
          vendedorIdFijo: _vendedorRestringidoId,
        ),
      ),
    );
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return AdminBackHandler(
      dashboardBuilder: (_) => const HomeScreen(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Clientes'),
          backgroundColor: Colors.teal.shade700,
          foregroundColor: Colors.white,
        ),
        drawer: const AppDrawer(),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _abrirForm(),
          icon: const Icon(Icons.add),
          label: const Text('Nuevo'),
          backgroundColor: Colors.teal.shade700,
          foregroundColor: Colors.white,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _clientes.isEmpty
                ? const Center(child: Text('Sin clientes registrados'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _clientes.length,
                    itemBuilder: (_, i) {
                      final c = _clientes[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.teal.shade100,
                            child: Text(c.nombre[0].toUpperCase(),
                                style: TextStyle(
                                    color: Colors.teal.shade800,
                                    fontWeight: FontWeight.bold)),
                          ),
                          title: Text(c.nombre,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (c.telefono.isNotEmpty)
                                Text('Tel: ${c.telefono}'),
                              if (c.email.isNotEmpty) Text(c.email),
                            ],
                          ),
                          trailing: PopupMenuButton(
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                  value: 'ventas',
                                  child: Row(children: [
                                    Icon(Icons.receipt_long, size: 18),
                                    SizedBox(width: 8),
                                    Text('Ver ventas')
                                  ])),
                              const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(children: [
                                    Icon(Icons.edit, size: 18),
                                    SizedBox(width: 8),
                                    Text('Editar')
                                  ])),
                              const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(children: [
                                    Icon(Icons.delete,
                                        size: 18, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Eliminar',
                                        style: TextStyle(color: Colors.red))
                                  ])),
                            ],
                            onSelected: (val) {
                              if (val == 'edit') _abrirForm(c);
                              if (val == 'delete') _delete(c);
                              if (val == 'ventas') {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            VentasScreen(clienteFiltro: c)));
                              }
                            },
                          ),
                          isThreeLine:
                              c.telefono.isNotEmpty && c.email.isNotEmpty,
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
