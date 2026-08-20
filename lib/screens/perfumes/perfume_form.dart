import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../database/database_helper.dart';
import '../../models/perfume.dart';
import '../../widgets/admin_back_handler.dart';
import '../home_screen.dart';

class PerfumeForm extends StatefulWidget {
  final Perfume? perfume;
  const PerfumeForm({super.key, this.perfume});

  @override
  State<PerfumeForm> createState() => _PerfumeFormState();
}

class _PerfumeFormState extends State<PerfumeForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombre;
  late TextEditingController _marca;
  late TextEditingController _mililitros;
  late TextEditingController _concentracion;
  late TextEditingController _descripcion;
  late TextEditingController _precioCosto;
  late TextEditingController _precioVenta;
  late TextEditingController _stock;
  final ImagePicker _picker = ImagePicker();
  String? _imagenPath;

  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final p = widget.perfume;
    _nombre = TextEditingController(text: p?.nombre ?? '');
    _marca = TextEditingController(text: p?.marca ?? '');
    _mililitros =
      TextEditingController(text: p?.mililitros != null ? p!.mililitros.toString() : '');
    _concentracion = TextEditingController(text: p?.concentracion ?? '');
    _descripcion = TextEditingController(text: p?.descripcion ?? '');
    _precioCosto =
        TextEditingController(text: p != null ? p.precioCosto.toString() : '');
    _precioVenta =
        TextEditingController(text: p != null ? p.precioVenta.toString() : '');
    _stock = TextEditingController(text: p != null ? p.stock.toString() : '0');
  }

  @override
  void dispose() {
    _nombre.dispose();
    _marca.dispose();
    _mililitros.dispose();
    _concentracion.dispose();
    _descripcion.dispose();
    _precioCosto.dispose();
    _precioVenta.dispose();
    _stock.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final perfume = Perfume(
        id: widget.perfume?.id,
        apiId: widget.perfume?.apiId,
        nombre: _nombre.text.trim(),
        marca: _marca.text.trim(),
        mililitros: _mililitros.text.trim().isEmpty
          ? null
          : int.tryParse(_mililitros.text.trim()),
        concentracion: _concentracion.text.trim().isEmpty
          ? null
          : _concentracion.text.trim(),
        descripcion: _descripcion.text.trim(),
        precioCosto: double.parse(_precioCosto.text),
        precioVenta: double.parse(_precioVenta.text),
        stock: int.parse(_stock.text),
        imagenUrl: widget.perfume?.imagenUrl,
      );
      final db = DatabaseHelper();
      if (perfume.id == null) {
        await db.insertPerfume(perfume, imagePath: _imagenPath);
      } else {
        await db.updatePerfume(perfume, imagePath: _imagenPath);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el perfume: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  Future<void> _tomarFoto() async {
    final img = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (img == null) return;
    setState(() => _imagenPath = img.path);
  }

  Future<void> _elegirGaleria() async {
    final img = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (img == null) return;
    setState(() => _imagenPath = img.path);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.perfume != null;
    return AdminBackHandler(
      dashboardBuilder: (_) => const HomeScreen(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEdit ? 'Editar perfume' : 'Nuevo perfume'),
          backgroundColor: Colors.purple.shade700,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _field(_nombre, 'Nombre del perfume', Icons.local_florist,
                    required: true),
                const SizedBox(height: 14),
                _field(_marca, 'Marca', Icons.branding_watermark,
                    required: true),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _field(
                          _mililitros, 'Mililitros (ml)', Icons.straighten,
                          numeric: true, isInt: true),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _field(_concentracion, 'Concentración',
                          Icons.opacity),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _field(_descripcion, 'Descripción (opcional)', Icons.notes,
                    maxLines: 3),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Foto del perfume',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    color: Colors.purple.shade50,
                    child: _imagenPath != null
                        ? Image.file(File(_imagenPath!), fit: BoxFit.cover)
                        : (widget.perfume?.imagenUrl != null &&
                                widget.perfume!.imagenUrl!.isNotEmpty
                            ? Image.network(
                                widget.perfume!.imagenUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.local_florist,
                                  size: 72,
                                  color: Colors.purple.shade300,
                                ),
                              )
                            : Icon(
                                Icons.local_florist,
                                size: 72,
                                color: Colors.purple.shade300,
                              )),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _tomarFoto,
                        icon: const Icon(Icons.photo_camera),
                        label: const Text('Tomar foto'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _elegirGaleria,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Galería'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _field(
                          _precioCosto, 'Precio costo', Icons.money_off,
                          required: true, numeric: true),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _field(
                          _precioVenta, 'Precio venta', Icons.attach_money,
                          required: true, numeric: true),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _field(_stock, 'Stock actual', Icons.inventory_2,
                    required: true, numeric: true, isInt: true),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _guardando ? null : _guardar,
                    icon: _guardando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save),
                    label: Text(isEdit ? 'Actualizar' : 'Guardar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade700,
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

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool required = false,
    bool numeric = false,
    bool isInt = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: numeric
          ? (isInt
              ? TextInputType.number
              : const TextInputType.numberWithOptions(decimal: true))
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      validator: (v) {
        if (required && (v == null || v.trim().isEmpty)) {
          return 'Campo requerido';
        }
        if (numeric && v != null && v.isNotEmpty) {
          final val = double.tryParse(v);
          if (val == null || val < 0) return 'Número inválido';
        }
        return null;
      },
    );
  }
}
