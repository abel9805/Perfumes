import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/perfume.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/admin_back_handler.dart';
import '../home_screen.dart';
import 'perfume_form.dart';

class PerfumesScreen extends StatefulWidget {
  const PerfumesScreen({super.key});

  @override
  State<PerfumesScreen> createState() => _PerfumesScreenState();
}

class _PerfumesScreenState extends State<PerfumesScreen> {
  List<Perfume> _perfumes = [];
  List<Perfume> _filtrados = [];
  bool _loading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargar();
    _searchController.addListener(_filtrar);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final data = await DatabaseHelper().getPerfumes();
    if (mounted) {
      setState(() {
        _perfumes = data;
        _filtrados = data;
        _loading = false;
      });
    }
  }

  void _filtrar() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtrados = _perfumes
          .where((p) =>
              p.nombre.toLowerCase().contains(q) ||
              p.marca.toLowerCase().contains(q))
          .toList();
    });
  }

  Future<void> _delete(Perfume p) async {
    final confirm = await _confirmar('¿Eliminar "${p.nombre}"?');
    if (confirm == true) {
      await DatabaseHelper().deletePerfume(p.id!);
      _cargar();
    }
  }

  Future<bool?> _confirmar(String msg) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirmar'),
          content: Text(msg),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Eliminar',
                    style: TextStyle(color: Colors.red))),
          ],
        ),
      );

  Future<void> _abrirFormulario([Perfume? perfume]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PerfumeForm(perfume: perfume)),
    );
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return AdminBackHandler(
      dashboardBuilder: (_) => const HomeScreen(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Perfumes'),
          backgroundColor: Colors.purple.shade700,
          foregroundColor: Colors.white,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre o marca...',
                  hintStyle: const TextStyle(color: Colors.white70),
                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                  filled: true,
                  fillColor: Colors.purple.shade600,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
        ),
        drawer: const AppDrawer(),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _abrirFormulario(),
          icon: const Icon(Icons.add),
          label: const Text('Nuevo'),
          backgroundColor: Colors.purple.shade700,
          foregroundColor: Colors.white,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _filtrados.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_florist,
                            size: 64, color: Colors.black26),
                        SizedBox(height: 12),
                        Text('Sin perfumes registrados',
                            style: TextStyle(color: Colors.black45)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _filtrados.length,
                    itemBuilder: (_, i) {
                      final p = _filtrados[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: SizedBox(
                          height: 132,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: 108,
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    bottomLeft: Radius.circular(12),
                                  ),
                                  child: p.imagenUrl != null &&
                                          p.imagenUrl!.isNotEmpty
                                      ? Image.network(
                                          p.imagenUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                            color: Colors.purple.shade100,
                                            child: Icon(Icons.local_florist,
                                                color: Colors.purple.shade700,
                                                size: 36),
                                          ),
                                        )
                                      : Container(
                                          color: Colors.purple.shade100,
                                          child: Icon(Icons.local_florist,
                                              color: Colors.purple.shade700,
                                              size: 36),
                                        ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(12, 10, 6, 10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.nombre,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text('Marca: ${p.marca}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      Text(
                                          'Costo: \$${p.precioCosto.toStringAsFixed(2)}'),
                                      Text(
                                          'Venta: \$${p.precioVenta.toStringAsFixed(2)}'),
                                      const Spacer(),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: p.stock > 5
                                                  ? Colors.green.shade100
                                                  : p.stock > 0
                                                      ? Colors.orange.shade100
                                                      : Colors.red.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              'Stock: ${p.stock}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: p.stock > 5
                                                    ? Colors.green.shade800
                                                    : p.stock > 0
                                                        ? Colors.orange.shade800
                                                        : Colors.red.shade800,
                                              ),
                                            ),
                                          ),
                                          const Spacer(),
                                          PopupMenuButton(
                                            itemBuilder: (_) => [
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
                                                        size: 18,
                                                        color: Colors.red),
                                                    SizedBox(width: 8),
                                                    Text('Eliminar',
                                                        style: TextStyle(
                                                            color: Colors.red))
                                                  ])),
                                            ],
                                            onSelected: (v) {
                                              if (v == 'edit')
                                                _abrirFormulario(p);
                                              if (v == 'delete') _delete(p);
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
