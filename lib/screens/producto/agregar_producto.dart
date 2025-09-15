import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gestion_inventario/services/mongo_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class AgregarProductoPage extends StatefulWidget {
  const AgregarProductoPage({super.key});

  @override
  State<AgregarProductoPage> createState() => _AgregarProductoPageState();
}

class _AgregarProductoPageState extends State<AgregarProductoPage> {
  final _formKey = GlobalKey<FormState>();

  // Campos del producto
  String? nombre, talla, categoria, marca;
  double? precioCompra, precioVenta, precioDescuento;
  DateTime fechaRegistro = DateTime.now();

  // Imagen
  File? _foto;
  final picker = ImagePicker();

  // Estado UI
  bool _guardando = false;
  final _fmtFecha = DateFormat('dd/MM/yyyy');

  // Marcas (desde colección "marcas")
  List<String> _marcas = [];
  bool _cargandoMarcas = false;

  // Categorías fijas
  static const List<String> _categorias = ['niño', 'niña', 'hombre', 'mujer'];

  // Colores de marca (degradado)
  static const brandA = Color(0xFFFF7A18);
  static const brandB = Color(0xFFFFC837);

  // Keys para anclar menús debajo de los campos
  final GlobalKey _catAnchorKey = GlobalKey();
  final GlobalKey _marcaAnchorKey = GlobalKey();

  // --- Helpers ---
  // Acepta "12.345,67" o "12345.67" o "12345"
  double? _toDouble(String? raw) {
    if (raw == null) return null;
    final s = raw.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(s);
  }

  InputDecoration _input(String label, {String? hint, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon) : null,
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Card _card({required Widget child, Color? color}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: color ?? Colors.grey[50],
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }

  Widget _sectionTitle(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[800]),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }

  // ---- Menú anclado que SIEMPRE se abre hacia abajo ----
  Future<T?> _showMenuBelow<T>(
    GlobalKey anchorKey,
    List<PopupMenuEntry<T>> items,
  ) async {
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final anchorBox = anchorKey.currentContext!.findRenderObject() as RenderBox;
    final offset = anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox);

    final rect = RelativeRect.fromLTRB(
      offset.dx,
      offset.dy + anchorBox.size.height, // 👈 debajo del campo
      overlayBox.size.width - offset.dx - anchorBox.size.width,
      overlayBox.size.height - offset.dy - anchorBox.size.height,
    );

    return showMenu<T>(context: context, position: rect, items: items);
  }

  void _hideKeyboard() {
    FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  /// FormField con apariencia de TextField que abre un menú anclado debajo.
  Widget _dropdownMenuFormField({
    required GlobalKey anchorKey,
    required String label,
    IconData? icon,
    required List<String> options,
    String? value,
    required ValueChanged<String> onChanged,
    FormFieldValidator<String>? validator,
    FormFieldSetter<String>? onSaved,
  }) {
    return FormField<String>(
      validator: validator,
      onSaved: onSaved,
      initialValue: value,
      builder: (state) {
        return InkWell(
          onTap: () async {
            final sel = await _showMenuBelow<String>(
              anchorKey,
              options
                  .map((o) => PopupMenuItem<String>(value: o, child: Text(o)))
                  .toList(),
            );
            if (sel != null) {
              onChanged(sel);
              state.didChange(sel);
            }
          },
          child: InputDecorator(
            key: anchorKey,
            isEmpty: (state.value == null || state.value!.isEmpty),
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: icon != null ? Icon(icon) : null,
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              errorText: state.errorText,
              suffixIcon: const Icon(Icons.arrow_drop_down),
            ),
            child: Text(
              state.value ?? 'Selecciona…',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _cargarMarcas();
  }

  Future<void> _cargarMarcas() async {
    setState(() => _cargandoMarcas = true);
    try {
      final res = await MongoService().getMarcas();
      final nombres =
          (res)
              .map((e) {
                if (e is String) return e;
                if (e is Map) {
                  final n = (e['nombre'] ?? e['name'] ?? '').toString().trim();
                  return n;
                }
                return e.toString().trim();
              })
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      if (!mounted) return;
      setState(() => _marcas = nombres);
    } catch (_) {
      // si falla, queda fallback a texto
    } finally {
      if (mounted) setState(() => _cargandoMarcas = false);
    }
  }

  Future<void> _nuevaMarcaDialog() async {
    final ctrl = TextEditingController();
    final nombre = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva marca'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nombre de la marca',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => Navigator.of(ctx).pop(ctrl.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    final s = nombre?.trim() ?? '';
    if (s.isEmpty) return;

    if (_marcas.any((m) => m.toLowerCase() == s.toLowerCase())) {
      setState(
        () => marca = _marcas.firstWhere(
          (m) => m.toLowerCase() == s.toLowerCase(),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('La marca ya existe.')));
      return;
    }

    try {
      await MongoService().addMarca(s);
      await _cargarMarcas();
      setState(() {
        if (!_marcas.contains(s)) {
          _marcas.add(s);
          _marcas.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        }
        marca = s;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Marca creada.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo crear la marca: $e')));
    }
  }

  Future<void> _pickImage() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Selecciona origen'),
        content: const Text('¿Desde dónde quieres cargar la foto?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Text('Cámara'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Text('Galería'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (source != null) {
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1280,
      );
      if (pickedFile != null) {
        setState(() => _foto = File(pickedFile.path));
      }
    }
  }

  Future<void> _agregarProducto() async {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();
    setState(() => _guardando = true);

    try {
      String? fotoBase64;
      if (_foto != null && await _foto!.exists()) {
        final bytes = await _foto!.readAsBytes();
        fotoBase64 = base64Encode(bytes);
      }

      final producto = {
        'nombre': nombre?.trim(),
        'talla': talla?.trim(),
        'marca': marca?.trim(),
        'categoria': categoria?.trim(),
        'precioCompra': precioCompra,
        'precioVenta': precioVenta,
        'precioDescuento': precioDescuento ?? 0,
        'fechaRegistro': fechaRegistro.toIso8601String(),
        'foto': _foto?.path ?? '',
        'fotoBase64': fotoBase64 ?? '',
        'fotoMime': 'image/jpeg',
        'estado': 'disponible',
      };

      await MongoService().saveProduct(producto);

      if (!mounted) return;

      // Dialogo bonito de éxito con icono verde
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.check_circle_rounded, color: Colors.green, size: 56),
              SizedBox(height: 8),
              Text(
                '¡Producto agregado!',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          content: const Text(
            'El producto ha sido guardado correctamente.',
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );

      // Limpia el formulario y estado local
      setState(() {
        nombre = null;
        talla = null;
        categoria = null;
        marca = null;
        precioCompra = null;
        precioVenta = null;
        precioDescuento = null;
        fechaRegistro = DateTime.now();
        _foto = null;
        _formKey.currentState!.reset();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
     _hideKeyboard();
  }

  // Selector de marca con menú hacia abajo + acciones
  Widget _marcaField() {
    final refreshBtn = IconButton(
      tooltip: 'Recargar marcas',
      icon: const Icon(Icons.refresh),
      onPressed: _cargarMarcas,
    );
    final addBtn = IconButton(
      tooltip: 'Nueva marca',
      icon: const Icon(Icons.add),
      onPressed: _nuevaMarcaDialog,
    );

    if (_cargandoMarcas) {
      return Row(
        children: [
          Expanded(
            child: InputDecorator(
              decoration: _input('Marca', icon: Icons.local_offer_outlined),
              child: const SizedBox(
                height: 24,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
          ),
          refreshBtn,
          addBtn,
        ],
      );
    }

    if (_marcas.isEmpty) {
      // Fallback a texto cuando aún no hay marcas
      return Row(
        children: [
          Expanded(
            child: TextFormField(
              decoration: _input(
                'Marca (texto)',
                icon: Icons.local_offer_outlined,
              ),
              onSaved: (v) => marca = v?.trim(),
            ),
          ),
          refreshBtn,
          addBtn,
        ],
      );
    }

    // Menú anclado hacia abajo con lista de marcas
    return Row(
      children: [
        Expanded(
          child: _dropdownMenuFormField(
            anchorKey: _marcaAnchorKey,
            label: 'Marca',
            icon: Icons.local_offer_outlined,
            options: _marcas,
            value: (_marcas.contains(marca)) ? marca : null,
            onChanged: (v) => setState(() => marca = v),
            onSaved: (v) => marca = v,
          ),
        ),
        refreshBtn,
        addBtn,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Agregar producto',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [brandA, brandB],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey, // el Form envuelve TODO
          child: LayoutBuilder(
            builder: (context, c) {
              final bool wide = c.maxWidth >= 900;

              final content = [
                // DATOS GENERALES
                _card(
                  child: Column(
                    children: [
                      _sectionTitle(
                        Icons.inventory_2_outlined,
                        'Datos generales',
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        decoration: _input(
                          'Nombre',
                          icon: Icons.badge_outlined,
                        ),
                        onSaved: (v) => nombre = v,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Ingrese el nombre'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              decoration: _input(
                                'Talla',
                                icon: Icons.straighten_outlined,
                              ),
                              onSaved: (v) => talla = v,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _dropdownMenuFormField(
                              anchorKey: _catAnchorKey,
                              label: 'Categoría',
                              icon: Icons.category_outlined,
                              options: _categorias,
                              value: (_categorias.contains(categoria))
                                  ? categoria
                                  : null,
                              onChanged: (v) => setState(() => categoria = v),
                              onSaved: (v) => categoria = v,
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Seleccione la categoría'
                                  : null,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),
                      _marcaField(),
                      const SizedBox(height: 10),
                      ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        leading: const Icon(Icons.calendar_today),
                        title: Text(
                          'Fecha de registro: ${_fmtFecha.format(fechaRegistro)}',
                        ),
                        trailing: const Icon(Icons.edit_calendar),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: fechaRegistro,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => fechaRegistro = picked);
                          }
                        },
                      ),
                    ],
                  ),
                ),

                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(Icons.attach_money, 'Precios'),
                      const SizedBox(height: 10),

                      // Compra
                      TextFormField(
                        decoration: _input('Compra', icon: Icons.sell),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9\.,]'),
                          ),
                        ],
                        onSaved: (v) => precioCompra = _toDouble(v),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Ingrese compra'
                            : null,
                      ),

                      const SizedBox(height: 10),

                      // Venta
                      TextFormField(
                        decoration: _input('Venta', icon: Icons.point_of_sale),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9\.,]'),
                          ),
                        ],
                        onSaved: (v) => precioVenta = _toDouble(v),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Ingrese venta'
                            : null,
                      ),

                      const SizedBox(height: 10),

                      // Descuento
                      TextFormField(
                        decoration: _input(
                          'Descuento',
                          icon: Icons.discount_outlined,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9\.,]'),
                          ),
                        ],
                        onSaved: (v) => precioDescuento = _toDouble(v),
                      ),
                    ],
                  ),
                ),

                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(Icons.photo_library_outlined, 'Foto'),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 92,
                              height: 92,
                              color: Colors.grey[200],
                              child: _foto != null
                                  ? Image.file(
                                      _foto!,
                                      fit: BoxFit.cover,
                                      width: 92,
                                      height: 92,
                                    )
                                  : const Icon(
                                      Icons.photo,
                                      size: 40,
                                      color: Colors.black38,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: _guardando ? null : _pickImage,
                              icon: const Icon(Icons.add_a_photo),
                              label: const Text('Agregar foto'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // GUARDAR
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        backgroundColor: brandA,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _guardando ? null : _agregarProducto,
                      icon: _guardando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: const Text(
                        'Guardar producto',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ];

              if (wide) {
                // Dos columnas en pantallas anchas
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ListView(
                          children: [
                            content[0],
                            const SizedBox(height: 12),
                            content[1],
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ListView(
                          children: [
                            content[2],
                            const SizedBox(height: 12),
                            content[3],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Una columna en móviles
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ...content.take(3),
                  const SizedBox(height: 12),
                  content[3],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
