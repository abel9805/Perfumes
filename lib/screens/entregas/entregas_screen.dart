import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/entrega_vendedor.dart';
import '../../models/vendedor.dart';
import '../../widgets/admin_back_handler.dart';
import '../../widgets/app_drawer.dart';
import '../home_screen.dart';
import 'entrega_form.dart';
import 'pedido_detalle_screen.dart';

class EntregasScreen extends StatefulWidget {
  final Vendedor? vendedorFiltro;
  final bool modoPedidos;
  final String tipoFiltro;
  const EntregasScreen({
    super.key,
    this.vendedorFiltro,
    this.modoPedidos = false,
    this.tipoFiltro = 'todos',
  });

  @override
  State<EntregasScreen> createState() => _EntregasScreenState();
}

class _EntregasScreenState extends State<EntregasScreen> {
  List<EntregaVendedor> _entregas = [];
  bool _loading = true;
  String _filtroEstado = 'todos';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    List<EntregaVendedor> data;
    if (widget.modoPedidos) {
      if (widget.vendedorFiltro != null) {
        data = await DatabaseHelper().getPedidosByVendedor(
          widget.vendedorFiltro!.id!,
          tipo: widget.tipoFiltro,
        );
      } else {
        data = await DatabaseHelper().getPedidos(tipo: widget.tipoFiltro);
      }
    } else if (widget.vendedorFiltro != null) {
      data = await DatabaseHelper().getEntregasByVendedor(
        widget.vendedorFiltro!.id!,
        tipo: widget.tipoFiltro,
      );
    } else {
      data = await DatabaseHelper().getEntregas(tipo: widget.tipoFiltro);
    }
    if (mounted)
      setState(() {
        _entregas = data;
        _loading = false;
      });
  }

  List<EntregaVendedor> get _filtradas {
    if (_filtroEstado == 'todos') return _entregas;
    if (widget.modoPedidos) {
      if (_filtroEstado == 'por_surtir') {
        return _entregas.where((e) => e.estado == 'solicitado').toList();
      }
      if (_filtroEstado == 'surtido') {
        return _entregas.where((e) => e.estado != 'solicitado').toList();
      }
    }
    return _entregas.where((e) => e.estado == _filtroEstado).toList();
  }

  Map<String, List<EntregaVendedor>> get _agrupadasPorVendedor {
    if (widget.modoPedidos) {
      final ordenadas = [..._filtradas]..sort((a, b) {
          final vendedorA = (a.nombreVendedor ?? 'Sin vendedor').toLowerCase();
          final vendedorB = (b.nombreVendedor ?? 'Sin vendedor').toLowerCase();
          final byNombre = vendedorA.compareTo(vendedorB);
          if (byNombre != 0) return byNombre;

          final fechaA = DateTime.tryParse(a.fecha);
          final fechaB = DateTime.tryParse(b.fecha);
          if (fechaA != null && fechaB != null) {
            return fechaB.compareTo(fechaA);
          }
          return 0;
        });

      final grupos = <String, List<EntregaVendedor>>{};
      for (final entrega in ordenadas) {
        final key =
            '${entrega.nombreVendedor ?? 'Sin vendedor'}|${entrega.fecha}';
        grupos.putIfAbsent(key, () => []).add(entrega);
      }
      return grupos;
    }

    final ordenadas = [..._filtradas]..sort((a, b) {
        final vendedorA = (a.nombreVendedor ?? 'Sin vendedor').toLowerCase();
        final vendedorB = (b.nombreVendedor ?? 'Sin vendedor').toLowerCase();
        final byNombre = vendedorA.compareTo(vendedorB);
        if (byNombre != 0) return byNombre;

        final fechaA = DateTime.tryParse(a.fecha);
        final fechaB = DateTime.tryParse(b.fecha);
        if (fechaA != null && fechaB != null) {
          return fechaB.compareTo(fechaA);
        }
        return 0;
      });

    final grupos = <String, List<EntregaVendedor>>{};
    for (final entrega in ordenadas) {
      final key = (entrega.nombreVendedor == null ||
              entrega.nombreVendedor!.trim().isEmpty)
          ? 'Sin vendedor'
          : entrega.nombreVendedor!;
      grupos.putIfAbsent(key, () => []).add(entrega);
    }
    return grupos;
  }

  String _pedidoTitulo(String key, List<EntregaVendedor> items) {
    final partes = key.split('|');
    final vendedor = partes.isNotEmpty ? partes.first : 'Sin vendedor';
    final fecha = items.isNotEmpty ? items.first.fecha : '';
    final fechaFmt = fecha.isNotEmpty
        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(fecha))
        : '-';
    return '$vendedor · $fechaFmt';
  }

  Future<void> _abrirPedidoGrupo(
      String key, List<EntregaVendedor> items, DateFormat fmt) async {
    final puedeSurtir = items.any((i) => i.estado == 'solicitado');
    if (!puedeSurtir) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este pedido ya fue surtido')),
      );
      return;
    }

    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PedidoDetalleScreen(
          titulo: _pedidoTitulo(key, items),
          items: items,
          actionLabel: 'Surtir pedido (total o parcial)',
          onAction: (rows) async {
            for (final surtido in rows) {
              final row = surtido.item;
              final cantidadSurtida = surtido.cantidadSurtida;
              if (row.id == null || cantidadSurtida <= 0) continue;

              if (cantidadSurtida >= row.cantidad) {
                await DatabaseHelper()
                    .updateEntregaEstado(row.id!, 'pendiente_confirmacion');
                continue;
              }

              final restante = row.cantidad - cantidadSurtida;

              await DatabaseHelper().updateEntrega(
                row.id!,
                estado: 'solicitado',
                cantidad: restante,
              );

              await DatabaseHelper().insertEntrega(
                EntregaVendedor(
                  vendedorId: row.vendedorId,
                  perfumeId: row.perfumeId,
                  cantidad: cantidadSurtida,
                  precioUnitario: row.precioUnitario,
                  fecha: row.fecha,
                  tipo: row.tipo,
                  estado: 'pendiente_confirmacion',
                ),
              );
            }
          },
        ),
      ),
    );
    if (changed == true) {
      _cargar();
    }
  }

  Widget _buildPedidoGroupCard(
      String key, List<EntregaVendedor> items, DateFormat fmt) {
    final first = items.first;
    final puedeSurtir = items.any((i) => i.estado == 'solicitado');
    final estado = first.estado;
    final label = estado == 'solicitado'
        ? 'Por surtir'
        : estado == 'pendiente_confirmacion'
            ? 'Surtido - pendiente de aceptar'
            : estado == 'confirmado'
                ? 'Aceptado'
                : estado;
    final totalUnidades =
        items.fold<int>(0, (sum, item) => sum + item.cantidad);
    final totalImporte = items.fold<double>(0, (sum, item) => sum + item.total);

    final imagenUrl = first.imagenUrl?.trim() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: puedeSurtir ? () => _abrirPedidoGrupo(key, items, fmt) : null,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 48,
            height: 48,
            color: Colors.blue.shade50,
            child: imagenUrl.isNotEmpty
                ? Image.network(
                    imagenUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.local_shipping,
                      color: Colors.blue.shade700,
                    ),
                  )
                : Icon(Icons.local_shipping, color: Colors.blue.shade700),
          ),
        ),
        title: Text(
          _pedidoTitulo(key, items),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Articulos: ${items.length} · Unidades: $totalUnidades'),
            Text('Total: \$${totalImporte.toStringAsFixed(2)}'),
            Text('Estado: $label'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Chip(
              label: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
              backgroundColor: estado == 'solicitado'
                  ? Colors.orange
                  : estado == 'pendiente_confirmacion'
                      ? Colors.blue
                      : Colors.green,
            ),
            const SizedBox(height: 6),
            Icon(
              puedeSurtir ? Icons.chevron_right : Icons.lock_outline,
              color: puedeSurtir ? null : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cambiarEstado(EntregaVendedor e) async {
    if (!widget.modoPedidos) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('La confirmacion de entrega solo la realiza el vendedor'),
        ),
      );
      return;
    }

    final estadoActual = e.estado;
    final nuevoEstado =
        estadoActual == 'solicitado' ? 'pendiente_confirmacion' : 'confirmado';
    await DatabaseHelper().updateEntregaEstado(e.id!, nuevoEstado);
    _cargar();
  }

  Future<void> _delete(EntregaVendedor e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar'),
        content: Text(
          e.estado == 'pagado'
              ? '¿Eliminar esta entrega ya confirmada/pagada? Se quitará del registro y se revertirá la cantidad.'
              : '¿Eliminar esta entrega? El stock será revertido.',
        ),
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
        await DatabaseHelper().deleteEntrega(e.id!, e.perfumeId, e.cantidad);
        _cargar();
      } catch (err) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(err.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'confirmado':
      case 'pagado':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  void _mostrarImagenGrande(String title, String imageUrl) {
    if (imageUrl.trim().isEmpty) return;

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    padding: const EdgeInsets.all(24),
                    color: Colors.indigo.shade50,
                    child: Icon(
                      Icons.broken_image,
                      size: 72,
                      color: Colors.indigo.shade700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildEntregaCard(EntregaVendedor e, DateFormat fmt) {
    final esPedido = widget.modoPedidos;
    final esInicial = e.tipo == 'inicial';
    final estadoLabel = esPedido
        ? (e.estado == 'solicitado'
            ? 'Por surtir'
            : e.estado == 'pendiente_confirmacion'
                ? 'Surtido - pendiente de aceptar'
                : e.estado == 'confirmado'
                    ? 'Aceptado'
                    : e.estado)
        : (e.estado == 'pendiente_confirmacion'
            ? 'Pendiente'
            : e.estado == 'confirmado'
                ? 'Confirmado'
                : e.estado);
    final imagenUrl = e.imagenUrl?.trim() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _mostrarImagenGrande(e.nombrePerfume ?? 'Perfume', imagenUrl),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 52,
                  height: 52,
                  color: Colors.indigo.shade50,
                  child: imagenUrl.isNotEmpty
                      ? Image.network(
                          imagenUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            esInicial ? Icons.inventory_2 : Icons.delivery_dining,
                            color: Colors.indigo.shade700,
                          ),
                        )
                      : Icon(
                          esInicial ? Icons.inventory_2 : Icons.delivery_dining,
                          color: Colors.indigo.shade700,
                        ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.nombrePerfume ?? 'Perfume',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (widget.vendedorFiltro != null)
                    Text('Vendedor: ${e.nombreVendedor ?? '-'}',
                        style: const TextStyle(fontSize: 13)),
                  if (esInicial)
                    const Text('Origen: entrega inicial',
                        style: TextStyle(fontSize: 13)),
                  Text(
                    'Estado: $estadoLabel',
                    style: const TextStyle(fontSize: 13),
                  ),
                  Text(
                      'Cantidad: ${e.cantidad}  |  \$${e.precioUnitario.toStringAsFixed(2)} c/u',
                      style: const TextStyle(fontSize: 13)),
                  Text(
                      'Total: \$${e.total.toStringAsFixed(2)}  |  ${fmt.format(DateTime.parse(e.fecha))}',
                      style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
            Column(
              children: [
                GestureDetector(
                  onTap: (widget.modoPedidos && e.estado == 'solicitado')
                      ? () => _cambiarEstado(e)
                      : null,
                  child: Chip(
                    label: Text(estadoLabel,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 11)),
                    backgroundColor: _colorEstado(e.estado),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                if (!widget.modoPedidos)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: () => _delete(e),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
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
          title: Text(widget.modoPedidos
              ? (widget.vendedorFiltro != null
                  ? 'Pedidos - ${widget.vendedorFiltro!.nombre}'
                  : 'Pedidos de Vendedores')
              : (widget.tipoFiltro == 'inicial'
                  ? (widget.vendedorFiltro != null
                      ? 'Stock inicial - ${widget.vendedorFiltro!.nombre}'
                      : 'Stock inicial')
                  : (widget.vendedorFiltro != null
                      ? 'Entregas - ${widget.vendedorFiltro!.nombre}'
                      : 'Entregas a Vendedores'))),
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: (widget.modoPedidos
                          ? ['todos', 'por_surtir', 'surtido']
                          : ['todos', 'pendiente_confirmacion', 'confirmado'])
                      .map((estado) {
                    final sel = _filtroEstado == estado;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          estado == 'todos'
                              ? 'Todos'
                              : estado == 'por_surtir'
                                  ? 'Por surtir'
                                  : estado == 'surtido'
                                      ? 'Surtido'
                                      : estado == 'pendiente_confirmacion'
                                          ? 'Pendiente confirmación'
                                          : 'Confirmado',
                        ),
                        selected: sel,
                        onSelected: (_) =>
                            setState(() => _filtroEstado = estado),
                        selectedColor: Colors.white,
                        backgroundColor: Colors.green.shade600,
                        labelStyle: TextStyle(
                          color: sel ? Colors.green.shade800 : Colors.white,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
        drawer: const AppDrawer(),
        floatingActionButton: widget.modoPedidos
            ? null
            : FloatingActionButton.extended(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EntregaForm(
                        vendedorPreseleccionado: widget.vendedorFiltro,
                        modoPedidos: widget.modoPedidos,
                      ),
                    ),
                  );
                  _cargar();
                },
                icon: const Icon(Icons.add),
                label:
                    Text(widget.modoPedidos ? 'Nuevo pedido' : 'Nueva entrega'),
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _filtradas.isEmpty
                ? const Center(child: Text('Sin entregas registradas'))
                : widget.vendedorFiltro != null
                    ? (widget.modoPedidos
                        ? ListView(
                            padding: const EdgeInsets.all(12),
                            children: _agrupadasPorVendedor.entries
                                .map((entry) => _buildPedidoGroupCard(
                                    entry.key, entry.value, fmt))
                                .toList(),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _filtradas.length,
                            itemBuilder: (_, i) =>
                                _buildEntregaCard(_filtradas[i], fmt),
                          ))
                    : ListView(
                        padding: const EdgeInsets.all(12),
                        children: widget.modoPedidos
                            ? _agrupadasPorVendedor.entries
                                .map((entry) => _buildPedidoGroupCard(
                                    entry.key, entry.value, fmt))
                                .toList()
                            : _agrupadasPorVendedor.entries.expand((entry) {
                                return [
                                  Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(4, 6, 4, 8),
                                    child: Row(
                                      children: [
                                        Icon(Icons.person,
                                            size: 18,
                                            color: Colors.green.shade800),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            entry.key,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green.shade800,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '${entry.value.length}',
                                            style: TextStyle(
                                              color: Colors.green.shade800,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ...entry.value
                                      .map((e) => _buildEntregaCard(e, fmt)),
                                ];
                              }).toList(),
                      ),
      ),
    );
  }
}
