import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gestion_inventario/ViewModel/producto_viewmodel.dart';
import 'package:gestion_inventario/theme/app_colors.dart';
import 'package:image_picker/image_picker.dart';

class ProductoView extends StatefulWidget {
  const ProductoView({super.key});

  @override
  State<ProductoView> createState() => _ProductoViewState();
}

class _ProductoViewState extends State<ProductoView> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _tallaCtrl = TextEditingController();
  final _marcaCtrl = TextEditingController();
  final _precioCompraCtrl = TextEditingController();
  final _precioVentaCtrl = TextEditingController();
  final _precioMinimoCtrl = TextEditingController();

  late ProductoViewModel _viewModel;
  File? _imagenSeleccionada;
  String? _imagenBase64;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _viewModel = ProductoViewModel();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _nombreCtrl.dispose();
    _tallaCtrl.dispose();
    _marcaCtrl.dispose();
    _precioCompraCtrl.dispose();
    _precioVentaCtrl.dispose();
    _precioMinimoCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarImagen(ImageSource source) async {
    try {
      final XFile? imagen = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (imagen != null) {
        final File file = File(imagen.path);
        final bytes = await file.readAsBytes();
        setState(() {
          _imagenSeleccionada = file;
          _imagenBase64 = base64Encode(bytes);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar imagen: $e')),
        );
      }
    }
  }

  void _mostrarOpcionesImagen() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.accent),
                title: const Text('Tomar foto'),
                onTap: () {
                  Navigator.pop(context);
                  _seleccionarImagen(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: AppColors.accent,
                ),
                title: const Text('Seleccionar de galería'),
                onTap: () {
                  Navigator.pop(context);
                  _seleccionarImagen(ImageSource.gallery);
                },
              ),
              if (_imagenSeleccionada != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Eliminar foto'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _imagenSeleccionada = null;
                      _imagenBase64 = null;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _guardarProducto() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Quitar el foco de los campos para evitar que se abra el teclado
    FocusScope.of(context).unfocus();

    // Actualizar el ViewModel con los datos del formulario
    _viewModel.setNombre(_nombreCtrl.text);
    _viewModel.setTalla(_tallaCtrl.text);
    _viewModel.setMarca(_marcaCtrl.text);
    _viewModel.setPrecioCompra(
      double.parse(_precioCompraCtrl.text.replaceAll(',', '.')),
    );
    _viewModel.setPrecioVenta(
      double.parse(_precioVentaCtrl.text.replaceAll(',', '.')),
    );
    _viewModel.setPrecioMinimo(
      double.parse(_precioMinimoCtrl.text.replaceAll(',', '.')),
    );

    // Guardar la foto en el ViewModel
    if (_imagenSeleccionada != null && _imagenBase64 != null) {
      _viewModel.setFoto(_imagenBase64, _imagenSeleccionada!.path);
    } else {
      _viewModel.setFoto(null, null);
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final exito = await _viewModel.guardarProducto();

      if (!mounted) return;
      Navigator.pop(context); // Cerrar loading

      if (exito) {
        // Limpiar formulario
        _formKey.currentState!.reset();
        setState(() {
          _imagenSeleccionada = null;
          _imagenBase64 = null;
          _nombreCtrl.clear();
          _tallaCtrl.clear();
          _marcaCtrl.clear();
          _precioCompraCtrl.clear();
          _precioVentaCtrl.clear();
          _precioMinimoCtrl.clear();
        });
        // No mostrar ningún cuadro de texto ni abrir el teclado
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Cerrar loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.pink[200],
        title: const Text(
          'Agregar Producto',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
            color: Colors.white,
          ),
        ),
      ),
      body: Container(
        color: AppColors.background,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Foto del producto
              Center(
                child: GestureDetector(
                  onTap: _mostrarOpcionesImagen,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.accent, width: 2),
                    ),
                    child: _imagenSeleccionada != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              _imagenSeleccionada!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo,
                                size: 50,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Agregar foto',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // Nombre del producto
              TextFormField(
                controller: _nombreCtrl,
                decoration: InputDecoration(
                  labelText: 'Nombre del producto',
                  hintText: 'Ej: Camiseta deportiva',
                  prefixIcon: const Icon(Icons.shopping_bag),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.accent,
                      width: 2,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El nombre es obligatorio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Talla
              TextFormField(
                controller: _tallaCtrl,
                decoration: InputDecoration(
                  labelText: 'Talla',
                  hintText: 'Ej: M, L, XL',
                  prefixIcon: const Icon(Icons.straighten),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.accent,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Marca
              TextFormField(
                controller: _marcaCtrl,
                decoration: InputDecoration(
                  labelText: 'Marca',
                  hintText: 'Ej: Nike, Adidas',
                  prefixIcon: const Icon(Icons.label),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.accent,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Precio de compra
              TextFormField(
                controller: _precioCompraCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Precio de compra',
                  hintText: '0',
                  prefixIcon: const Icon(Icons.attach_money),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.accent,
                      width: 2,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El precio de compra es obligatorio';
                  }
                  if (double.tryParse(value.replaceAll(',', '.')) == null) {
                    return 'Ingrese un número válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Precio de venta
              TextFormField(
                controller: _precioVentaCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Precio de venta',
                  hintText: '0',
                  prefixIcon: const Icon(Icons.sell),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.accent,
                      width: 2,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El precio de venta es obligatorio';
                  }
                  if (double.tryParse(value.replaceAll(',', '.')) == null) {
                    return 'Ingrese un número válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Precio mínimo
              TextFormField(
                controller: _precioMinimoCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Precio mínimo',
                  hintText: '0',
                  prefixIcon: const Icon(Icons.price_check),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.accent,
                      width: 2,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El precio mínimo es obligatorio';
                  }
                  if (double.tryParse(value.replaceAll(',', '.')) == null) {
                    return 'Ingrese un número válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),

              // Botón guardar
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _guardarProducto,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: const Text(
                    'Guardar Producto',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
