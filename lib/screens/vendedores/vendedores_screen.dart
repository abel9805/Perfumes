import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/vendedor.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/admin_back_handler.dart';
import 'vendedor_form.dart';
import '../entregas/entregas_screen.dart';
import '../ventas/ventas_screen.dart';
import '../home_screen.dart';

class VendedoresScreen extends StatefulWidget {
  const VendedoresScreen({super.key});

  @override
  State<VendedoresScreen> createState() => _VendedoresScreenState();
}

class _VendedoresScreenState extends State<VendedoresScreen> {
  List<Vendedor> _vendedores = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final data = await DatabaseHelper().getVendedores();
    if (mounted) {
      setState(() {
        _vendedores = data;
        _loading = false;
      });
    }
  }

  Future<void> _delete(Vendedor v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar'),
        content: Text('¿Eliminar al vendedor "${v.nombre}"?'),
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
        await DatabaseHelper().deleteVendedor(v.id!);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vendedor eliminado')),
        );
        _cargar();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo eliminar: $e')),
        );
      }
    }
  }

  Future<void> _abrirForm([Vendedor? v]) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => VendedorForm(vendedor: v)));
    _cargar();
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '-';
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd/$mm/$yy';
  }

  @override
  Widget build(BuildContext context) {
    return AdminBackHandler(
      dashboardBuilder: (_) => const HomeScreen(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Vendedores'),
          backgroundColor: Colors.indigo.shade700,
          foregroundColor: Colors.white,
        ),
        drawer: const AppDrawer(),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _abrirForm(),
          icon: const Icon(Icons.add),
          label: const Text('Nuevo'),
          backgroundColor: Colors.indigo.shade700,
          foregroundColor: Colors.white,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _vendedores.isEmpty
                ? const Center(child: Text('Sin vendedores registrados'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _vendedores.length,
                    itemBuilder: (_, i) {
                      final v = _vendedores[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.indigo.shade100,
                            child: Text(v.nombre[0].toUpperCase(),
                                style: TextStyle(
                                    color: Colors.indigo.shade800,
                                    fontWeight: FontWeight.bold)),
                          ),
                          title: Text(v.nombre,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (v.telefono.isNotEmpty)
                                Text('Tel: ${v.telefono}'),
                              if (v.email.isNotEmpty) Text(v.email),
                              Text(
                                'Tipo usuario: ${v.tipoUsuario == 'colega' ? 'Colega' : 'Vendedor'}',
                              ),
                              const SizedBox(height: 4),
                              Text(
                                  'Fecha alta: ${_formatDate(v.fechaRegistro)}'),
                              Text(
                                  'Nivel: ${v.nivelEmbajador.isEmpty ? '-' : v.nivelEmbajador}'),
                              Text(
                                'Descuento disponible: Crédito ${v.descuentoCredito.toStringAsFixed(0)}% · Contado ${v.descuentoContado.toStringAsFixed(0)}%',
                              ),
                              Text(
                                'Ventas mensual/anual: \$${v.totalVentasMensual.toStringAsFixed(2)} / \$${v.totalVentasAnual.toStringAsFixed(2)}',
                              ),
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
                                  value: 'entregas',
                                  child: Row(children: [
                                    Icon(Icons.delivery_dining, size: 18),
                                    SizedBox(width: 8),
                                    Text('Ver entregas')
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
                              if (val == 'edit') _abrirForm(v);
                              if (val == 'delete') _delete(v);
                              if (val == 'ventas') {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => VentasScreen(
                                            vendedorFiltroId: v.id)));
                              }
                              if (val == 'entregas') {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            EntregasScreen(vendedorFiltro: v)));
                              }
                            },
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
