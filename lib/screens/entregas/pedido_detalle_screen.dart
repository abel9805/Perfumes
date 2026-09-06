import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/entrega_vendedor.dart';
import '../../widgets/admin_back_handler.dart';
import '../home_screen.dart';

class PedidoSurtidoItem {
  final EntregaVendedor item;
  final int cantidadSurtida;

  const PedidoSurtidoItem({
    required this.item,
    required this.cantidadSurtida,
  });
}

class PedidoDetalleScreen extends StatefulWidget {
  final String titulo;
  final List<EntregaVendedor> items;
  final String actionLabel;
  final Future<void> Function(List<PedidoSurtidoItem> items) onAction;

  const PedidoDetalleScreen({
    super.key,
    required this.titulo,
    required this.items,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  State<PedidoDetalleScreen> createState() => _PedidoDetalleScreenState();
}

class _PedidoDetalleScreenState extends State<PedidoDetalleScreen> {
  bool _saving = false;
  final Map<int, int> _cantidadesSurtidas = {};

  int _itemKey(EntregaVendedor item, int index) {
    return item.id ?? ((item.apiId ?? 0) * 100000) + index;
  }

  double get _total => widget.items.fold<double>(
        0,
        (sum, item) => sum + item.total,
      );

  String _estadoLabel(String estado) {
    switch (estado) {
      case 'solicitado':
        return 'Por surtir';
      case 'pendiente_confirmacion':
        return 'Surtido - pendiente de aceptar';
      case 'confirmado':
        return 'Aceptado';
      case 'pagado':
        return 'Pagado';
      default:
        return estado;
    }
  }

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.items.length; i++) {
      final item = widget.items[i];
      _cantidadesSurtidas[_itemKey(item, i)] = item.cantidad;
    }
  }

  Future<void> _accion() async {
    final seleccion = <PedidoSurtidoItem>[];
    for (var i = 0; i < widget.items.length; i++) {
      final item = widget.items[i];
      final key = _itemKey(item, i);
      final cantidad = _cantidadesSurtidas[key] ?? 0;
      if (cantidad > 0) {
        seleccion.add(PedidoSurtidoItem(item: item, cantidadSurtida: cantidad));
      }
    }

    if (seleccion.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa al menos una cantidad a surtir')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.onAction(seleccion);
      if (!mounted) return;
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    final first = widget.items.isNotEmpty ? widget.items.first : null;
    final estado = first?.estado ?? 'solicitado';

    return AdminBackHandler(
      dashboardBuilder: (_) => const HomeScreen(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.titulo),
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.local_shipping)),
                title: Text(first?.nombreVendedor ?? 'Sin vendedor'),
                subtitle: Text(
                  first == null
                      ? ''
                      : 'Fecha: ${fmt.format(DateTime.parse(first.fecha))}\nEstado: ${_estadoLabel(estado)}',
                ),
                isThreeLine: first != null,
              ),
            ),
            const SizedBox(height: 12),
            ...widget.items.asMap().entries.map(
              (entry) {
                final index = entry.key;
                final item = entry.value;
                final key = _itemKey(item, index);
                final actual = _cantidadesSurtidas[key] ?? item.cantidad;
                final imagenUrl = item.imagenUrl?.trim() ?? '';
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 48,
                        height: 48,
                        color: Colors.green.shade50,
                        child: imagenUrl.isNotEmpty
                            ? Image.network(
                                imagenUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.local_florist,
                                  color: Colors.green.shade700,
                                ),
                              )
                            : Icon(Icons.local_florist,
                                color: Colors.green.shade700),
                      ),
                    ),
                    title: Text(item.nombrePerfume ?? 'Perfume'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pedido: ${item.cantidad}  ·  \$${item.precioUnitario.toStringAsFixed(2)} c/u',
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('Surtir: '),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 90,
                              child: TextFormField(
                                initialValue: actual.toString(),
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                ),
                                onChanged: (value) {
                                  final parsed =
                                      int.tryParse(value.trim()) ?? 0;
                                  final clamped = parsed < 0
                                      ? 0
                                      : (parsed > item.cantidad
                                          ? item.cantidad
                                          : parsed);
                                  setState(() {
                                    _cantidadesSurtidas[key] = clamped;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Pendiente: ${item.cantidad - actual}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Text(
                      '\$${(actual * item.precioUnitario).toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
            ),
            Card(
              color: Colors.green.shade50,
              child: ListTile(
                leading: const Icon(Icons.summarize),
                title: const Text(
                  'Total del pedido',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: Text(
                  '\$${_total.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _accion,
                icon: const Icon(Icons.local_shipping),
                label: Text(widget.actionLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
