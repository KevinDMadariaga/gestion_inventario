import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gestion_inventario/services/mongo_service.dart';
import 'package:intl/intl.dart';

class BuscarInventarioPage extends StatefulWidget {
  const BuscarInventarioPage({super.key});

  @override
  State<BuscarInventarioPage> createState() => _BuscarInventarioPageState();
}

class _BuscarInventarioPageState extends State<BuscarInventarioPage> {
  final _busquedaController = TextEditingController();

  final FocusNode _searchFocus = FocusNode();
  void _dismissKeyboard() => FocusScope.of(context).unfocus(); // 👈 nuevo
  List<Map<String, dynamic>> _resultados = [];

  // moneda simple
  final NumberFormat _mon = NumberFormat.currency(
    symbol: r'$',
    decimalDigits: 0,
  );

  // Token para invalidar resultados de búsquedas antiguas
  int _searchToken = 0;

  // Filtro por estado (UI)
  String _estadoFiltro = 'todos'; // todos | disponible | vendido | apartado

  // Colores de marca
  static const brandA = Color(0xFFFF7A18);
  static const brandB = Color(0xFFFFC837);

  @override
  void dispose() {
    _busquedaController.dispose();
    _searchFocus.dispose();
    _searchToken++;
    super.dispose();
  }

  Future<void> _buscarProducto() async {
    final q = _busquedaController.text.trim().toLowerCase();
    final int token = ++_searchToken;

    try {
      // 1) Trae base según si hay texto o no
      List<Map<String, dynamic>> base;
      if (q.isEmpty) {
        // sin texto -> traemos TODO para que los chips funcionen solos
        base = await MongoService().getData();
      } else {
        // con texto -> búsqueda por nombre (con fallback)
        try {
          base = await MongoService().getProductosByNombre(q);
        } catch (_) {
          final todos = await MongoService().getData();
          base = todos.where((p) {
            final n = (p['nombre'] ?? '').toString().toLowerCase();
            return n.contains(q);
          }).toList();
        }
      }

      // 2) Aplica el filtro del chip (todos/disponible/apartado/vendido)
      var filtrados = _aplicarFiltroEstado(base);

      // 3) Ordena por nombre
      filtrados.sort(
        (a, b) => (a['nombre'] ?? '').toString().toLowerCase().compareTo(
          (b['nombre'] ?? '').toString().toLowerCase(),
        ),
      );

      // 4) Publica resultados si sigue vigente el token
      if (!mounted || token != _searchToken) return;
      setState(() => _resultados = filtrados);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al buscar productos: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> _aplicarFiltroEstado(
    List<Map<String, dynamic>> lista,
  ) {
    if (_estadoFiltro == 'todos') return lista;

    return lista.where((p) {
      final estado = (p['estado'] ?? 'disponible')
          .toString()
          .toLowerCase()
          .trim();
      switch (_estadoFiltro) {
        case 'vendido':
          return estado == 'vendido';
        case 'apartado':
          return estado == 'apartado' || estado == 'aparto';
        case 'disponible':
          // tratamos cualquier cosa distinta a vendido/apartado como disponible
          return estado != 'vendido' &&
              estado != 'apartado' &&
              estado != 'aparto';
        default:
          return true;
      }
    }).toList();
  }

  static const List<double> _greyMatrix = <double>[
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];

  Widget _buildProductoImage(
    Map<String, dynamic> p, {
    double w = 64,
    double h = 64,
    double radius = 12,
  }) {
    final String b64 = (p['fotoBase64'] ?? '') as String;
    final String f = (p['foto'] ?? '') as String;

    final estado = (p['estado'] ?? '').toString().toLowerCase().trim();
    final bool isSold = estado == 'vendido';
    final bool isOnHold = estado == 'apartado' || estado == 'aparto';
    final bool greyItOut = isSold || isOnHold;

    Widget img;
    if (b64.isNotEmpty) {
      try {
        final bytes = base64Decode(b64);
        img = Image.memory(bytes, width: w, height: h, fit: BoxFit.cover);
      } catch (_) {
        img = _placeholder(w, h);
      }
    } else if (f.startsWith('http://') || f.startsWith('https://')) {
      img = Image.network(
        f,
        width: w,
        height: h,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(w, h, broken: true),
      );
    } else if (f.isNotEmpty) {
      final file = File(f);
      if (file.existsSync()) {
        img = Image.file(file, width: w, height: h, fit: BoxFit.cover);
      } else {
        try {
          final bytes = base64Decode(f);
          img = Image.memory(bytes, width: w, height: h, fit: BoxFit.cover);
        } catch (_) {
          img = _placeholder(w, h);
        }
      }
    } else {
      img = _placeholder(w, h);
    }

    img = ClipRRect(borderRadius: BorderRadius.circular(radius), child: img);

    if (greyItOut) {
      img = ColorFiltered(
        colorFilter: const ColorFilter.matrix(_greyMatrix),
        child: img,
      );
    }
    return img;
  }

  Widget _placeholder(double w, double h, {bool broken = false}) {
    return Container(
      width: w,
      height: h,
      color: Colors.grey[300],
      child: Icon(broken ? Icons.broken_image : Icons.photo, size: w * 0.6),
    );
  }

  Chip _estadoChip(String estado) {
    final e = estado.toLowerCase().trim();
    late Color bg;
    late String label;
    late IconData icon;

    if (e == 'vendido') {
      bg = Colors.red;
      label = 'VENDIDO';
      icon = Icons.block;
    } else if (e == 'apartado' || e == 'aparto') {
      bg = Colors.orange;
      label = 'APARTADO';
      icon = Icons.pause_circle_filled_rounded;
    } else if (e == 'prestado') {
      bg = Colors.indigo; // color para prestado
      label = 'PRESTADO';
      icon = Icons.assignment_returned_outlined;
    } else {
      bg = Colors.green;
      label = 'DISPONIBLE';
      icon = Icons.check_circle;
    }

    return Chip(
      avatar: Icon(icon, color: Colors.white, size: 16),
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      backgroundColor: bg,
      side: BorderSide.none,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  void _mostrarDetalle(Map<String, dynamic> p) {
    if (!mounted) return;

    final num pvRaw = (p['precioVenta'] is num)
        ? p['precioVenta'] as num
        : num.tryParse('${p['precioVenta']}') ?? 0;
    final double precioVenta = pvRaw.toDouble();

    final num pdRaw = (p['precioDescuento'] is num)
        ? p['precioDescuento'] as num
        : num.tryParse('${p['precioDescuento']}') ?? 0;
    final double precioDescuento = pdRaw.toDouble();

    final num pmRaw = (p['precioMinimo'] is num)
        ? p['precioMinimo'] as num
        : num.tryParse('${p['precioMinimo']}') ?? 0;
    final double precioMinimo = pmRaw.toDouble();

    final estado = (p['estado'] ?? '').toString().toLowerCase().trim();
    final bool isSold = estado == 'vendido';
    final bool isHold = estado == 'apartado' || estado == 'aparto';
    final String? badgeText = isSold ? 'VENDIDO' : (isHold ? 'APARTADO' : null);
    final Color badgeColor = isSold ? Colors.redAccent : Colors.orangeAccent;

    showDialog(
      context: context,
      builder: (_) {
        bool mostrarMinimo = false;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 30,
              vertical: 40,
            ),
            title: Center(
              child: Text(
                (p['nombre'] ?? '').toString().toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Imagen con gris + cinta diagonal si aplica
                  SizedBox(
                    width: 260,
                    height: 260,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: (isSold || isHold)
                              ? ColorFiltered(
                                  colorFilter: const ColorFilter.matrix(
                                    _greyMatrix,
                                  ),
                                  child: _buildProductoImage(
                                    p,
                                    w: 260,
                                    h: 260,
                                    radius: 12,
                                  ),
                                )
                              : _buildProductoImage(
                                  p,
                                  w: 260,
                                  h: 260,
                                  radius: 12,
                                ),
                        ),
                        if (badgeText != null)
                          Center(
                            child: Transform.rotate(
                              angle: -0.785398, // -45°
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeColor.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  badgeText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _estadoChip(estado),
                  const SizedBox(height: 14),
                  Text(
                    'Valor: ${_mon.format(precioVenta)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (precioMinimo > 0) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () =>
                          setState(() => mostrarMinimo = !mostrarMinimo),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            mostrarMinimo
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            mostrarMinimo ? 'Ocultar mínimo' : 'Mostrar mínimo',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (mostrarMinimo)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Mínimo: ${_mon.format(precioMinimo)}',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 8),
                  if ((p['talla'] ?? '').toString().isNotEmpty)
                    Text('Talla: ${p['talla']}'),
                  if ((p['categoria'] ?? '').toString().isNotEmpty)
                    Text('Categoría: ${p['categoria']}'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.search, size: 22),
            SizedBox(width: 8),
            Text(
              'Buscar inventario',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),

        elevation: 0,
        foregroundColor: Colors.white,
        backgroundColor: const Color.fromRGBO(244, 143, 177, 1),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Column(
            children: [
              // Search card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: cs.surface,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _busquedaController,
                        focusNode: _searchFocus,
                        autofocus: false,
                        textInputAction: TextInputAction.search,
                        onTapOutside: (_) => _dismissKeyboard(),
                        onEditingComplete: _dismissKeyboard,
                        onFieldSubmitted: (_) {
                          _dismissKeyboard();
                          _buscarProducto();
                        },
                        onChanged: (_) => _buscarProducto(),
                        decoration: InputDecoration(
                          labelText: 'Buscar producto',
                          hintText:
                              'Ej: Jean, Blusa, all, vendidos, apartados…',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: (_busquedaController.text.isNotEmpty)
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _busquedaController.clear();
                                    setState(() => _resultados = []);
                                    _dismissKeyboard();
                                  },
                                )
                              : null,
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
                        ),
                      ),

                      const SizedBox(height: 10),
                      // Filtros por estado
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _filtroChip('Todos', 'todos'),
                            _filtroChip('Disponibles', 'disponible'),
                            _filtroChip('Apartados', 'apartado'),
                            _filtroChip('Vendidos', 'vendido'),
                            _filtroChip('Prestados', 'prestado'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Conteo
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 6),
                  child: Text(
                    'Resultados: ${_resultados.length}',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // Resultados
              Expanded(
                child: _resultados.isEmpty
                    ? const Center(
                        child: Text(
                          'No hay resultados',
                          style: TextStyle(color: Colors.black54),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _resultados.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _productoCard(_resultados[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Widgets auxiliares ----------

  Widget _filtroChip(String label, String value) {
    final selected = _estadoFiltro == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (v) async {
        _dismissKeyboard();
        setState(() => _estadoFiltro = value);
        await _buscarProducto();
        FocusScope.of(context).unfocus(); // opcional: cierra teclado
        await _buscarProducto(); // <-- recarga y aplica el filtro elegido
      },
      selectedColor: brandA.withOpacity(0.15),
      labelStyle: TextStyle(
        color: selected ? brandA : null,
        fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
      ),
      side: BorderSide(color: selected ? brandA : Colors.grey.shade300),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _productoCard(Map<String, dynamic> p) {
    final num precioRaw = (p['precioVenta'] is num)
        ? p['precioVenta'] as num
        : num.tryParse('${p['precioVenta']}') ?? 0;
    final double precio = precioRaw.toDouble();

    final estado = (p['estado'] ?? 'disponible')
        .toString()
        .toLowerCase()
        .trim();

    return Card(
      elevation: 0.8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          _dismissKeyboard(); // 👈 cierra teclado al seleccionar
          _mostrarDetalle(p);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
          child: Row(
            children: [
              // Imagen
              _buildProductoImage(p, w: 76, h: 76, radius: 12),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (p['nombre'] ?? '').toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if ((p['talla'] ?? '').toString().isNotEmpty)
                          Chip(
                            label: Text('Talla: ${p['talla']}'),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        if ((p['categoria'] ?? '').toString().isNotEmpty)
                          Chip(
                            label: Text('${p['categoria']}'),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Precio + estado
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _mon.format(precio),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _estadoChip(estado),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
