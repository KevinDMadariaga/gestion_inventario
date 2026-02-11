import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gestion_inventario/ViewModel/venta_viewmodel.dart';
import 'package:gestion_inventario/services/mongo_service.dart';
import 'package:gestion_inventario/theme/app_colors.dart';
import 'package:intl/intl.dart';

class VentaView extends StatefulWidget {
  const VentaView({super.key});

  @override
  State<VentaView> createState() => _VentaViewState();
}

class _VentaViewState extends State<VentaView> {
  late VentaViewModel _viewModel;
  final _buscarCtrl = TextEditingController();

  List<Map<String, dynamic>> _resultadosBusqueda = [];
  List<Map<String, dynamic>> _productosAgregados = [];
  Timer? _debounce;

  final _mon = NumberFormat('\$#,##0', 'es_CO');

  @override
  void initState() {
    super.initState();
    _viewModel = VentaViewModel();
    _viewModel.addListener(_onViewModelChanged);
    _buscarCtrl.addListener(_onBuscarChanged);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    _buscarCtrl.removeListener(_onBuscarChanged);
    _debounce?.cancel();
    _buscarCtrl.dispose();

    super.dispose();
  }

  void _onViewModelChanged() {
    setState(() {});
  }

  void _onBuscarChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      await _buscarProductos(_buscarCtrl.text.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Permitimos que el Scaffold se ajuste cuando aparece el teclado
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: AppColors.successLight,
        title: const Text(
          'Nueva Venta',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: Container(
          color: AppColors.background,
          child: Column(
            children: [
              if (_productosAgregados.isEmpty) ...[
                const Spacer(),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: _buildBotonAgregarProducto(),
                  ),
                ),
                const Spacer(),
              ],
              if (_productosAgregados.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: _buildListaProductosAgregados(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: _buildBotonAgregarProducto(),
                ),
                Expanded(child: _buildResumenVentaFijo()),
              ],
              if (_productosAgregados.isEmpty) _buildResumenVentaFijo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListaProductosAgregados() {
    return Container(
      height: 350,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent, width: 2),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Productos agregados',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: _productosAgregados.length,
              itemBuilder: (context, index) =>
                  _buildProductoAgregadoItem(index),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductoAgregadoItem(int index) {
    final producto = _productosAgregados[index];
    final double precioActual = _asDouble(producto['precioVenta']);
    final double precioOriginal = _asDouble(
      producto['precioVentaOriginal'] ?? producto['precioVenta'],
    );
    final double descuento = (precioOriginal - precioActual) > 0
        ? (precioOriginal - precioActual)
        : 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _mostrarDialogoDescuentoProducto(index),
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildProductImage(producto, w: 60, h: 60),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto['nombre']?.toString() ?? 'Sin nombre',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((producto['tallaSeleccionada'] ?? '')
                      .toString()
                      .isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Talla: ${producto['tallaSeleccionada']}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _mon.format(precioActual),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                        ),
                      ),
                      if (descuento > 0) ...[
                        const SizedBox(width: 6),
                        Text(
                          '- ${_mon.format(descuento)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red, size: 20),
              onPressed: () {
                setState(() {
                  _productosAgregados.removeAt(index);
                });
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotonAgregarProducto() {
    return GestureDetector(
      onTap: _mostrarModalBusqueda,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border, width: 2),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_shopping_cart_outlined,
              color: AppColors.accent,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              _productosAgregados.isEmpty
                  ? 'Agregar producto'
                  : 'Agregar otro producto',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarModalBusqueda() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> buscarYMostrar() async {
              // Oculta el teclado antes de ejecutar la búsqueda
              FocusScope.of(context).unfocus();
              await _buscarProductos(_buscarCtrl.text.trim());
              if (mounted) setModalState(() {});
            }

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.85,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              builder: (context, scrollController) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 40),
                        Text(
                          'Buscar producto',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _buscarCtrl,
                            decoration: InputDecoration(
                              labelText: 'Buscar producto',
                              hintText: 'Escribe el nombre del producto...',
                              prefixIcon: const Icon(
                                Icons.search,
                                color: AppColors.accent,
                              ),
                              suffixIcon: _buscarCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _buscarCtrl.clear();
                                        setModalState(() {
                                          _resultadosBusqueda = [];
                                        });
                                      },
                                    )
                                  : null,
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
                            onSubmitted: (_) => buscarYMostrar(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(
                            Icons.search,
                            color: AppColors.accent,
                          ),
                          onPressed: buscarYMostrar,
                          tooltip: 'Buscar',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _resultadosBusqueda.isEmpty
                        ? Center(
                            child: Text(
                              _buscarCtrl.text.isEmpty
                                  ? 'Escribe y presiona buscar'
                                  : 'No hay productos',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: _resultadosBusqueda.length,
                            itemBuilder: (context, index) {
                              final producto = _resultadosBusqueda[index];
                              return ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: _buildProductImage(
                                    producto,
                                    w: 50,
                                    h: 50,
                                  ),
                                ),
                                title: Text(
                                  producto['nombre']?.toString() ??
                                      'Sin nombre',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  _mon.format(
                                    _asDouble(producto['precioVenta']),
                                  ),
                                  style: const TextStyle(
                                    color: AppColors.accent,
                                  ),
                                ),
                                onTap: () {
                                  _mostrarDetallesProducto(producto);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildResumenVentaFijo() {
    double totalProductos = _productosAgregados.fold(0, (sum, producto) {
      return sum + _asDouble(producto['precioVenta']);
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Resumen de venta',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          _buildResumenFila('Valor productos:', _mon.format(totalProductos)),
          const SizedBox(height: 6),
          Divider(color: AppColors.divider, thickness: 2),
          const SizedBox(height: 10),
          _buildResumenFila(
            'Total:',
            _mon.format(totalProductos),
            isBold: true,
            fontSize: 22,
            color: AppColors.accent,
          ),
          const SizedBox(height: 10),
          _buildBotonGuardar(),
        ],
      ),
    );
  }

  Widget _buildResumenFila(
    String label,
    String valor, {
    bool isBold = false,
    double fontSize = 16,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
          Text(
            valor,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonGuardar() {
    final bool habilitado = _productosAgregados.isNotEmpty;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: habilitado ? _guardarVenta : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.textTertiary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: habilitado ? 4 : 0,
        ),
        child: const Text(
          'Guardar Venta',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0.0;
  }

  void _mostrarDialogoDescuentoProducto(int index) {
    final producto = _productosAgregados[index];
    final double precioOriginal = _asDouble(
      producto['precioVentaOriginal'] ?? producto['precioVenta'],
    );
    final double precioActual = _asDouble(producto['precioVenta']);

    final double descuentoInicial = (precioOriginal - precioActual) > 0
        ? (precioOriginal - precioActual)
        : 0;

    final TextEditingController descuentoCtrl = TextEditingController(
      text: descuentoInicial > 0 ? descuentoInicial.toStringAsFixed(0) : '',
    );

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final double descuentoIngresado = _asDouble(
              descuentoCtrl.text.replaceAll(',', '.'),
            );
            final double descuentoAplicado = descuentoIngresado.clamp(
              0.0,
              precioOriginal,
            );
            final double nuevoPrecio = (precioOriginal - descuentoAplicado)
                .clamp(0.0, double.infinity);

            final nombre = (producto['nombre']?.toString() ?? 'Sin nombre')
                .toUpperCase();

            final viewInsets = MediaQuery.of(context).viewInsets;
            final bottomInset = viewInsets.bottom;

            final size = MediaQuery.of(context).size;

            return AlertDialog(
              insetPadding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: bottomInset > 0 ? 8 : 24,
              ),
              content: SizedBox(
                width: size.width * 0.7,
                height: size.width * 0.7,
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: bottomInset > 0 ? 12 : 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _buildProductImage(producto, w: 120, h: 120),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        nombre,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'PRECIO ACTUAL',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _mon.format(nuevoPrecio),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'PRECIO ORIGINAL: ${_mon.format(precioOriginal)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text(
                            'Descuento',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.accent.withOpacity(0.3),
                                ),
                              ),
                              child: TextField(
                                controller: descuentoCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  hintText: '',
                                  border: InputBorder.none,
                                ),
                                onChanged: (_) => setStateDialog(() {}),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final double dIngresado = _asDouble(
                      descuentoCtrl.text.replaceAll(',', '.'),
                    );
                    final double dAplicado = dIngresado.clamp(
                      0.0,
                      precioOriginal,
                    );
                    final double precioFinal = (precioOriginal - dAplicado)
                        .clamp(0.0, double.infinity);

                    setState(() {
                      _productosAgregados[index]['precioVenta'] = precioFinal;
                    });

                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Aplicar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildProductImage(
    Map<String, dynamic> doc, {
    double w = 44,
    double h = 44,
  }) {
    final String b64 = (doc['fotoBase64'] ?? '') as String;
    final String pathOrUrl = (doc['foto'] ?? '') as String;

    if (b64.isNotEmpty) {
      try {
        final bytes = base64Decode(b64);
        return Image.memory(bytes, width: w, height: h, fit: BoxFit.cover);
      } catch (_) {}
    }
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return Image.network(
        pathOrUrl,
        width: w,
        height: h,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _imgPlaceholder(w, h, broken: true),
      );
    }
    if (pathOrUrl.isNotEmpty) {
      final f = File(pathOrUrl);
      if (f.existsSync()) {
        return Image.file(f, width: w, height: h, fit: BoxFit.cover);
      }
    }
    return _imgPlaceholder(w, h);
  }

  Widget _imgPlaceholder(double w, double h, {bool broken = false}) {
    return Container(
      width: w,
      height: h,
      color: Colors.grey[300],
      child: Icon(broken ? Icons.broken_image : Icons.photo, size: w * 0.5),
    );
  }

  Future<void> _buscarProductos(String q) async {
    if (q.isEmpty) {
      setState(() => _resultadosBusqueda = []);
      return;
    }
    try {
      List<Map<String, dynamic>> r = [];
      try {
        r = await MongoService().getProductosByNombre(q);
      } catch (_) {
        final all = await MongoService().getData();
        r = all.where((p) {
          final n = (p['nombre'] ?? '').toString().toLowerCase();
          return n.contains(q.toLowerCase());
        }).toList();
      }

      r = r.where((e) {
        final estado = (e['estado'] ?? 'disponible')
            .toString()
            .toLowerCase()
            .trim();
        return estado == 'disponible';
      }).toList();

      setState(() => _resultadosBusqueda = r);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al buscar productos: $e')),
        );
      }
    }
  }

  void _mostrarDetallesProducto(Map<String, dynamic> producto) {
    showDialog(
      context: context,
      builder: (context) {
        final size = MediaQuery.of(context).size;
        bool mostrarMinimo = false;
        String? tallaSeleccionada;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            // Construimos lista de tallas del producto para poder seleccionar
            final List<String> tallas = [];
            final dynamic tallasRaw = producto['tallas'];
            if (tallasRaw is List) {
              for (final t in tallasRaw) {
                final s = t.toString().trim();
                if (s.isNotEmpty) tallas.add(s);
              }
            } else {
              final textoTalla = (producto['talla'] ?? '').toString();
              if (textoTalla.isNotEmpty) {
                for (final t in textoTalla.split(',')) {
                  final s = t.trim();
                  if (s.isNotEmpty) tallas.add(s);
                }
              }
            }

            final String precioMinimoTexto = mostrarMinimo
                ? _mon.format(_asDouble(producto['precioMinimo']))
                : '********';

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 15,
              ),
              actionsAlignment: MainAxisAlignment.center,
              title: Center(
                child: Text(
                  (producto['nombre']?.toString() ?? 'Sin nombre')
                      .toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              content: SizedBox(
                width: size.width * 0.7,
                height: size.width * 0.7,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 10),
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _buildProductImage(producto, w: 220, h: 220),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Center(
                        child: Text(
                          'Precio venta: ' +
                              _mon.format(_asDouble(producto['precioVenta'])),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (mostrarMinimo) ...[
                            Text(
                              'Precio mínimo: $precioMinimoTexto',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(width: 5),
                          ],
                          IconButton(
                            icon: Icon(
                              mostrarMinimo
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: AppColors.accent,
                            ),
                            iconSize: 30,
                            onPressed: () {
                              setStateDialog(() {
                                mostrarMinimo = !mostrarMinimo;
                              });
                            },
                          ),
                        ],
                      ),
                      if (tallas.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Selecciona talla',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: tallas.map((t) {
                            final bool selected = tallaSeleccionada == t;
                            return ChoiceChip(
                              label: Text(t),
                              selected: selected,
                              selectedColor: AppColors.accent.withOpacity(0.2),
                              onSelected: (value) {
                                setStateDialog(() {
                                  tallaSeleccionada = value ? t : null;
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Si hay tallas y no se seleccionó ninguna, avisamos
                    if (tallas.isNotEmpty && tallaSeleccionada == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Selecciona una talla para vender'),
                        ),
                      );
                      return;
                    }
                    _seleccionarProducto(
                      producto,
                      tallaSeleccionada: tallaSeleccionada,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Aceptar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _seleccionarProducto(
    Map<String, dynamic> producto, {
    String? tallaSeleccionada,
  }) async {
    setState(() {
      final Map<String, dynamic> copia = Map<String, dynamic>.from(producto);
      // Guardamos el precio original para poder calcular/deshacer descuentos
      copia['precioVentaOriginal'] = _asDouble(copia['precioVenta']);
      if (tallaSeleccionada != null && tallaSeleccionada.isNotEmpty) {
        copia['tallaSeleccionada'] = tallaSeleccionada;
      }
      _productosAgregados.add(copia);
      _resultadosBusqueda = [];
      _buscarCtrl.clear();
    });
    // Cerramos primero el diálogo de detalle y luego el modal de búsqueda
    Navigator.pop(context); // Cierra el AlertDialog de tallas
    Navigator.pop(context); // Cierra el BottomSheet de búsqueda
    FocusScope.of(context).unfocus();
  }

  Future<void> _guardarVenta() async {
    if (_productosAgregados.isEmpty) return;
    FocusScope.of(context).unfocus();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      for (var producto in _productosAgregados) {
        final precioVenta = _asDouble(producto['precioVenta']);
        final precioCompra = _asDouble(producto['precioCompra']);
        final precioOriginal = _asDouble(
          producto['precioVentaOriginal'] ?? producto['precioVenta'],
        );
        final double descuentoProducto = (precioOriginal - precioVenta) > 0
            ? (precioOriginal - precioVenta)
            : 0.0;
        final dynamic rawId = producto['_id'];
        final String productoIdStr = rawId?.toString() ?? '';
        final String? talla =
            (producto['tallaSeleccionada'] ?? '').toString().trim().isEmpty
            ? null
            : (producto['tallaSeleccionada'] ?? '').toString().trim();

        _viewModel.agregarItem(
          productoId: productoIdStr,
          nombre: producto['nombre']?.toString() ?? 'Sin nombre',
          precioUnitario: precioVenta,
          costoUnitario: precioCompra,
          talla: talla,
          descuentoProducto: descuentoProducto,
        );

        // Actualizamos inventario por talla vendida si aplica
        if (talla != null && rawId != null) {
          await MongoService().marcarTallaVendida(rawId, talla);
        }
      }

      final exito = await _viewModel.guardarVenta();
      if (!mounted) return;
      Navigator.pop(context);

      if (exito) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Venta registrada exitosamente'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );

        setState(() {
          _productosAgregados = [];
          _buscarCtrl.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al registrar la venta'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    }
  }
}
