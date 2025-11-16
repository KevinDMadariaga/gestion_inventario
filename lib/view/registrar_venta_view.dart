import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:gestion_inventario/ViewModel/registrar_venta_viewmodel.dart';
import 'package:gestion_inventario/widgets/boton.dart';

class RegistrarVentaView extends StatefulWidget {
  const RegistrarVentaView({super.key});

  @override
  State<RegistrarVentaView> createState() => _RegistrarVentaViewState();
}

class _RegistrarVentaViewState extends State<RegistrarVentaView> {
  late final RegistrarVentaViewModel vm;
  final _mon = NumberFormat.currency(locale: 'es_CO', symbol: r'$');

  @override
  void initState() {
    super.initState();
    vm = RegistrarVentaViewModel();
    vm.init();
    vm.addListener(_vmListener);
  }

  void _vmListener() => setState(() {});

  @override
  void dispose() {
    vm.removeListener(_vmListener);
    vm.disposeViewModel();
    super.dispose();
  }

  Widget _buildProductImageFromDoc(
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
      child: Icon(broken ? Icons.broken_image : Icons.photo, size: w * 0.6),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: vm.formKey,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.point_of_sale, size: 24),
              SizedBox(width: 8),
              Text(
                'Registrar Ventas',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          foregroundColor: Colors.white,
          backgroundColor: const Color.fromRGBO(244, 143, 177, 1),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: ListView(
                padding: const EdgeInsets.all(19),
                children: [
                  // Datos del cliente
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    color: Colors.grey[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.person_outline),
                              SizedBox(width: 8),
                              Text(
                                'Datos del cliente',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: vm.nombreCtrl,
                            decoration: InputDecoration(
                              labelText: 'Nombre del cliente',
                              prefixIcon: const Icon(Icons.badge_outlined),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Ingrese el nombre del cliente'
                                : null,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: vm.telefonoCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            maxLength: 10,
                            decoration: InputDecoration(
                              labelText: 'Teléfono',
                              prefixIcon: const Icon(Icons.phone_outlined),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              counterText: '',
                            ),
                            validator: (v) {
                              final s = (v ?? '').trim();
                              if (s.isEmpty) return 'Ingrese el teléfono';
                              if (!RegExp(r'^\d+\$').hasMatch(s))
                                return 'Solo números';
                              if (s.length != 10)
                                return 'Debe tener 10 dígitos';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),

                  // Buscar producto
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    color: Colors.grey[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.search),
                              SizedBox(width: 8),
                              Text(
                                'Buscar producto',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: vm.buscarCtrl,
                            decoration: InputDecoration(
                              labelText:
                                  'Buscar por nombre (solo “disponibles”)',
                              hintText: 'Ej: Camiseta blanca',
                              prefixIcon: const Icon(Icons.search),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (vm.resultados.isNotEmpty)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: vm.resultados.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final p = vm.resultados[index];
                                  final precio = vm.asDouble(p['precioVenta']);
                                  return ListTile(
                                    leading: _buildProductImageFromDoc(
                                      p,
                                      w: 48,
                                      h: 48,
                                    ),
                                    title: Text(
                                      p['nombre'] ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(_mon.format(precio)),
                                        if ((p['descripcion'] ?? '')
                                            .toString()
                                            .isNotEmpty)
                                          Text(
                                            p['descripcion'],
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                    trailing: IconButton.filledTonal(
                                      icon: const Icon(Icons.add),
                                      onPressed: () => vm.agregarProducto(p),
                                      tooltip: 'Agregar a la venta',
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Productos seleccionados
                  if (vm.seleccionados.isNotEmpty)
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      color: Colors.grey[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.shopping_bag_outlined),
                                SizedBox(width: 8),
                                Text(
                                  'Productos seleccionados',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: vm.seleccionados.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final p = vm.seleccionados[index];
                                final precio = vm.asDouble(p['precioVenta']);
                                return ListTile(
                                  leading: Stack(
                                    alignment: Alignment.topRight,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: _buildProductImageFromDoc(
                                          p,
                                          w: 56,
                                          h: 56,
                                        ),
                                      ),
                                      Positioned(
                                        right: -6,
                                        top: -6,
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.close,
                                            size: 18,
                                          ),
                                          color: Colors.redAccent,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () =>
                                              vm.eliminarProducto(p),
                                          tooltip: 'Eliminar',
                                        ),
                                      ),
                                    ],
                                  ),
                                  title: Text(p['nombre'] ?? ''),
                                  subtitle: Text(_mon.format(precio)),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (vm.seleccionados.isNotEmpty) const SizedBox(height: 16),

                  // Resumen
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    color: Colors.green[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.receipt_long_outlined),
                              SizedBox(width: 8),
                              Text(
                                'Resumen de venta',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _rowResumen('Subtotal', _mon.format(vm.subtotal)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: vm.descuentoCtrl,
                            decoration: InputDecoration(
                              labelText: 'Descuento (monto)',
                              prefixIcon: const Icon(Icons.discount),
                              hintText: '0',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 8),
                          _rowResumen(
                            'Total',
                            _mon.format(vm.total),
                            isTotal: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Acciones
                  Row(
                    children: [
                      Expanded(
                        child: ActionButton(
                          label: 'Limpiar',
                          icon: Icons.cleaning_services_outlined,
                          variant: ActionButtonVariant.outline,
                          color: const Color.fromRGBO(244, 143, 177, 1),
                          onPressed: vm.guardando ? null : vm.limpiarFormulario,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ActionButton(
                          label: 'Registrar',
                          icon: Icons.save_outlined,
                          color: const Color.fromRGBO(244, 143, 177, 1),
                          onPressed: vm.guardando
                              ? null
                              : () async {
                                  try {
                                    await vm.guardarVenta();
                                    if (mounted)
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('✅ Venta registrada'),
                                        ),
                                      );
                                  } catch (e) {
                                    if (mounted)
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Error al guardar venta: $e',
                                          ),
                                        ),
                                      );
                                  }
                                },
                          loading: vm.guardando,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _rowResumen(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? Colors.green[800] : null,
          ),
        ),
      ],
    );
  }
}
