import 'package:mongo_dart/mongo_dart.dart';
import 'package:mongo_dart/mongo_dart.dart' as m;
import 'package:mongo_dart/mongo_dart.dart' show ObjectId, where;
import 'package:gestion_inventario/models/producto.dart';

class MongoService {
  static final MongoService _instance = MongoService._internal();
  factory MongoService() => _instance;
  MongoService._internal();

  late Db _db;
  bool _isConnected = false;

  // 👇 Getters de colecciones (DENTRO de la clase)
  DbCollection get _colProducto => _db.collection('producto');
  DbCollection get _colVentas => _db.collection('ventas');
  DbCollection get _colMarcas => _db.collection('marcas');

  Future<void> connect() async {
    if (!_isConnected) {
      String uri =
          "mongodb+srv://serviceIA:mRsPYsAS7tb5xn6r@cluster0.sartini.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0";

      _db = await Db.create(uri);
      await _db.open();
      _isConnected = true;
      print("✅ Conexión exitosa a MongoDB");
    }
  }

  Future<void> _ensureConnected() async {
    if (!_isConnected || _db.state != State.OPEN) {
      print("⏳ Esperando conexión a MongoDB...");
      await connect();
    }
  }

  Future<void> closeConnection() async {
    if (_isConnected && _db.state == State.OPEN) {
      await _db.close();
      _isConnected = false;
      print('🔌 Conexión Mongo cerrada');
    }
  }

  Future<List<Map<String, dynamic>>> getData() async {
    await _ensureConnected();
    return _colProducto.find().toList();
  }

  // Versión tipada: obtiene todos los productos como modelos Producto
  Future<List<Producto>> getProductos() async {
    final docs = await getData();
    return docs.map((e) => Producto.fromJson(e)).toList();
  }

  Future<void> saveProduct(Map<String, dynamic> doc) async {
    await _ensureConnected();
    doc.putIfAbsent('estado', () => 'disponible'); // default
    await _colProducto.insert(doc);
  }

  // Versión tipada: guardar un Producto usando su toJson
  Future<void> saveProductoModel(Producto producto) async {
    await saveProduct(producto.toJson());
  }

  Future<List<Map<String, dynamic>>> getApartados() async {
    await _ensureConnected();
    var collection = _db.collection('apartados');
    var data = await collection.find().toList();
    return data;
  }

  Future<void> saveVenta(Map<String, dynamic> venta) async {
    await _ensureConnected();
    var collection = _db.collection('ventas');
    await collection.insert(venta);
  }

  /// Marca una talla específica de un producto como vendida.
  ///
  /// - Quita la talla de la lista `tallas` (disponibles).
  /// - La agrega a `tallasVendidas`.
  /// - Actualiza el campo legado `talla` (texto con comas).
  /// - Si ya no quedan tallas disponibles, marca `estado = 'vendido'`.
  Future<void> marcarTallaVendida(
    dynamic productoId,
    String tallaVendida,
  ) async {
    await _ensureConnected();

    if (tallaVendida.trim().isEmpty) return;
    final String talla = tallaVendida.trim();

    // Selector robusto por _id (ObjectId o String)
    m.SelectorBuilder selector;
    if (productoId is ObjectId) {
      selector = m.where.id(productoId);
    } else {
      final String idStr = productoId.toString();
      try {
        selector = m.where.id(m.ObjectId.parse(idStr));
      } catch (_) {
        selector = m.where.eq('_id', idStr);
      }
    }

    // Obtenemos el documento actual del producto
    final Map<String, dynamic>? doc = await _colProducto.findOne(selector.map);
    if (doc == null) return;

    // Construimos listas de tallas disponibles y vendidas actuales
    final List<String> tallasDisponibles = <String>[];
    final List<String> tallasVendidas = <String>[];

    final dynamic tallasRaw = doc['tallas'];
    if (tallasRaw is List) {
      for (final t in tallasRaw) {
        final s = t.toString().trim();
        if (s.isNotEmpty) tallasDisponibles.add(s);
      }
    } else {
      final String textoTalla = (doc['talla'] ?? '').toString();
      if (textoTalla.isNotEmpty) {
        for (final t in textoTalla.split(',')) {
          final s = t.trim();
          if (s.isNotEmpty) tallasDisponibles.add(s);
        }
      }
    }

    final dynamic tallasVendidasRaw = doc['tallasVendidas'];
    if (tallasVendidasRaw is List) {
      for (final t in tallasVendidasRaw) {
        final s = t.toString().trim();
        if (s.isNotEmpty && !tallasVendidas.contains(s)) {
          tallasVendidas.add(s);
        }
      }
    }

    // Quitamos la talla vendida de disponibles y la agregamos a vendidas
    tallasDisponibles.removeWhere(
      (t) => t.toLowerCase() == talla.toLowerCase(),
    );
    if (!tallasVendidas.contains(talla)) {
      tallasVendidas.add(talla);
    }

    final Map<String, dynamic> toSet = <String, dynamic>{
      'tallas': tallasDisponibles,
      'talla': tallasDisponibles.join(', '),
      'tallasVendidas': tallasVendidas,
    };

    if (tallasDisponibles.isEmpty) {
      toSet['estado'] = 'vendido';
    }

    var mb = m.modify;
    toSet.forEach((k, v) => mb = mb.set(k, v));

    try {
      await _colProducto.updateOne(selector, mb);
    } catch (e) {
      // Fallback para versiones antiguas de mongo_dart
      await _colProducto.update(selector.map, {r'$set': toSet});
    }
  }

  Future<List<Map<String, dynamic>>> getProductosByNombre(String query) async {
    await _ensureConnected();
    final filtro = (query.trim().isEmpty)
        ? <String, dynamic>{}
        : {
            'nombre': {r'$regex': query, r'$options': 'i'},
          };

    List<Map<String, dynamic>> docs = await _colProducto.find(filtro).toList();

    docs.sort(
      (a, b) => (a['nombre'] ?? '').toString().toLowerCase().compareTo(
        (b['nombre'] ?? '').toString().toLowerCase(),
      ),
    );

    if (docs.length > 20) docs = docs.sublist(0, 20);

    return docs.map((d) {
      final pv = d['precioVenta'];
      final precio = pv is num ? pv.toDouble() : double.tryParse('$pv') ?? 0.0;
      return {...d, 'precioVenta': precio};
    }).toList();
  }

  Future<void> saveApartado(Map<String, dynamic> apartado) async {
    await _ensureConnected();
    final collection = _db.collection('apartados');
    try {
      // Si tu versión de mongo_dart soporta insertOne:
      // final res = await collection.insertOne(apartado);
      // if (!res.isSuccess) throw Exception(res.errmsg);
      await collection.insert(apartado); // fallback compatible
      print("✅ Apartado guardado en 'apartados'");
    } catch (e) {
      print("❌ Error guardando apartado: $e");
      rethrow;
    }
  }

  // Dentro de MongoService
  Future<void> eliminarPrestamo(String prestamoId) async {
    final db = await MongoService()._db;
    final prestamosCollection = db.collection('prestamos');
    await prestamosCollection.deleteOne(
      where.eq('_id', ObjectId.fromHexString(prestamoId)),
    );
  }

  Future<void> actualizarApartado(
    String idHex, {
    double? valorAbono,
    double? valorFalta,
    String? estado,
  }) async {
    await _ensureConnected();
    final col = _db.collection('apartados'); // 👈 usa _db, NO db

    // Solo seteamos lo que venga
    final Map<String, dynamic> toSet = {};
    if (valorAbono != null) toSet['valorAbono'] = valorAbono;
    if (valorFalta != null) toSet['valorFalta'] = valorFalta;
    if (estado != null && estado.trim().isNotEmpty) {
      toSet['estado'] = estado.trim();
    }
    toSet['updatedAt'] = DateTime.now().toIso8601String();

    if (toSet.isEmpty) return;

    // Selector por _id robusto (ObjectId o String)
    m.SelectorBuilder selector;
    try {
      selector = m.where.id(m.ObjectId.parse(idHex));
    } catch (_) {
      selector = m.where.eq('_id', idHex);
    }

    // ModifierBuilder: set campo por campo (no existe setAll)
    var mb = m.modify;
    toSet.forEach((k, v) => mb = mb.set(k, v));

    try {
      // En versiones nuevas devuelve WriteResult; en otras puede lanzar si no soporta updateOne
      await col.updateOne(selector, mb);

      // Si quieres, podrías inspeccionar (cuando exista):
      // final res = await col.updateOne(selector, mb);
      // final ok = (res.isSuccess == true) || (res.nModified ?? 0) > 0;
      // if (!ok) { /* opcional: log */ }
    } catch (e) {
      // Fallback para versiones antiguas: update “crudo”
      final rawSelector = selector.map; // mapa del where
      await col.update(rawSelector, {r'$set': toSet});
    }
  }

  Future<List<dynamic>> getMarcas() async {
    await _ensureConnected();

    // 1) Intentar leer de `marcas`
    try {
      final docs = await _colMarcas.find().toList();
      if (docs.isNotEmpty)
        return docs; // p.ej. [{_id:..., nombre: 'Nike'}, ...]
    } catch (_) {
      // continúa con fallback
    }

    // 2) Fallback con aggregate sobre `producto.marca`
    //    OJO: tipos con Object? para permitir null en $nin
    final List<Map<String, Object?>> pipeline = [
      {
        r'$match': <String, Object?>{
          'marca': <String, Object?>{
            r'$nin': <Object?>[null, ''],
          },
        },
      },
      {
        r'$group': <String, Object?>{'_id': r'$marca'},
      },
      {
        r'$project': <String, Object?>{'_id': 0, 'nombre': r'$_id'},
      },
      {
        r'$sort': <String, Object?>{'nombre': 1},
      },
    ];

    final list = await _colProducto
        .aggregateToStream(pipeline.cast<Map<String, Object>>())
        .toList();

    // Devuelve objetos tipo {nombre: 'X'}
    return list;
  }

  Future<int> addMarcas(List<String> marcas) async {
    await _ensureConnected();

    final ahora = DateTime.now().toIso8601String();

    // Normalización: trim + dedup
    final set = <String>{};
    for (final m in marcas) {
      final n = m.trim();
      if (n.isNotEmpty) set.add(n);
    }
    if (set.isEmpty) return 0;

    var afectados = 0;

    // 👇 ¡sin `async` en el header del for!
    for (final nombreMarca in set) {
      final lower = nombreMarca.toLowerCase();

      final existing = await _colMarcas.findOne({'nombreLower': lower});

      if (existing == null) {
        await _colMarcas.insert({
          'nombre': nombreMarca,
          'nombreLower': lower,
          'createdAt': ahora,
          'updatedAt': ahora,
        });
        afectados++;
      } else {
        await _colMarcas.update(
          {'_id': existing['_id']},
          {
            r'$set': {
              'nombre': nombreMarca,
              'nombreLower': lower,
              'updatedAt': ahora,
            },
          },
        );
        afectados++;
      }
    }

    return afectados;
  }

  Future<bool> addMarca(String nombre) async {
    final n = nombre.trim();
    if (n.isEmpty) return false;
    return (await addMarcas([n])) > 0;
  }

  Future<void> marcarProductosVendidos(List<String> ids) async {
    await _ensureConnected();
    if (ids.isEmpty) return;

    final coll = _db.collection('producto');

    final objectIds = <ObjectId>[];
    for (final id in ids) {
      // Normalizamos el id por si viene como 'ObjectId("...")' u otros formatos
      final hex = _hexFromAnyId(id);

      if (_isValidHex(hex)) {
        // Es un ObjectId válido -> lo usamos para actualizar por ObjectId
        objectIds.add(ObjectId.fromHexString(hex));
      } else {
        // _id guardado como String simple -> actualizamos por igualdad de string
        await coll.update(
          where.eq('_id', id),
          modify
              .set('estado', 'vendido')
              .set('fechaVenta', DateTime.now().toIso8601String()),
        );
      }
    }

    if (objectIds.isNotEmpty) {
      await coll.update(
        where.oneFrom('_id', objectIds),
        modify
            .set('estado', 'vendido')
            .set('fechaVenta', DateTime.now().toIso8601String()),
        multiUpdate: true,
      );
    }
  }

  Future<void> marcarProductosApartados(List<String> ids) async {
    await _ensureConnected();
    final valid = ids.where((e) => e.trim().isNotEmpty).toList();
    if (valid.isEmpty) return;

    final coll = _colProducto;
    final objectIds = <ObjectId>[];

    for (final id in valid) {
      try {
        objectIds.add(ObjectId.parse(id));
      } catch (_) {
        // _id no es ObjectId -> update por string
        await coll.update(
          where.eq('_id', id),
          modify
              .set('estado', 'apartado')
              .set('fechaApartado', DateTime.now().toIso8601String()),
        );
      }
    }

    if (objectIds.isNotEmpty) {
      await coll.update(
        where.oneFrom('_id', objectIds),
        modify
            .set('estado', 'apartado')
            .set('fechaApartado', DateTime.now().toIso8601String()),
        multiUpdate: true,
      );
    }
  }

  // ====== PRESTAMOS ======

  Future<String> savePrestamo(Map<String, dynamic> doc) async {
    await _ensureConnected();
    final col = _db.collection('prestamos');
    // por compatibilidad con versiones de mongo_dart:
    await col.insert(doc);
    // intenta extraer el id insertado
    final id = doc['_id'];
    if (id is ObjectId) return id.toHexString();
    if (id is Map && id[r'$oid'] is String) return id[r'$oid'] as String;
    return id?.toString() ?? '';
  }

  Future<List<Map<String, dynamic>>> getPrestamos({String? estado}) async {
    await _ensureConnected();
    final col = _db.collection('prestamos');
    final filtro = (estado == null || estado.trim().isEmpty)
        ? <String, dynamic>{}
        : {'estado': estado};
    final datos = await col.find(filtro).toList();

    // Orden: más recientes primero
    datos.sort((a, b) {
      final sa = (a['fechaPrestamo'] ?? '') as String;
      final sb = (b['fechaPrestamo'] ?? '') as String;
      DateTime da, db;
      try {
        da = DateTime.parse(sa);
      } catch (_) {
        da = DateTime.fromMillisecondsSinceEpoch(0);
      }
      try {
        db = DateTime.parse(sb);
      } catch (_) {
        db = DateTime.fromMillisecondsSinceEpoch(0);
      }
      return db.compareTo(da);
    });
    return datos;
  }

  /// Actualiza campos del préstamo. Pasa solo lo que necesites.
  Future<void> actualizarPrestamo(
    String idHex, {
    List<Map<String, dynamic>>? prendas,
    String? estado,
    Map<String, dynamic>? extra, // por si quieres setear cosas arbitrarias
  }) async {
    await _ensureConnected();
    final col = _db.collection('prestamos');

    final Map<String, dynamic> toSet = {
      'updatedAt': DateTime.now().toIso8601String(),
    };
    if (prendas != null) toSet['prendas'] = prendas;
    if (estado != null && estado.trim().isNotEmpty)
      toSet['estado'] = estado.trim();
    if (extra != null && extra.isNotEmpty) toSet.addAll(extra);

    if (toSet.isEmpty) return;

    // selector robusto
    m.SelectorBuilder selector;
    try {
      selector = m.where.id(m.ObjectId.parse(idHex));
    } catch (_) {
      selector = m.where.eq('_id', idHex);
    }

    var mb = m.modify;
    toSet.forEach((k, v) => mb = mb.set(k, v));

    try {
      await col.updateOne(selector, mb);
    } catch (e) {
      final rawSelector = selector.map;
      await col.update(rawSelector, {r'$set': toSet});
    }
  }

  // ====== ESTADOS DE PRODUCTO ======

  Future<void> marcarProductosPrestados(List<String> ids) async {
    await _ensureConnected();
    final coll = _colProducto;
    final objectIds = <ObjectId>[];
    for (final id in ids) {
      try {
        objectIds.add(ObjectId.parse(id));
      } catch (_) {
        await coll.update(
          where.eq('_id', id),
          modify
              .set('estado', 'prestado')
              .set('fechaPrestamo', DateTime.now().toIso8601String()),
        );
      }
    }
    if (objectIds.isNotEmpty) {
      await coll.update(
        where.oneFrom('_id', objectIds),
        modify
            .set('estado', 'prestado')
            .set('fechaPrestamo', DateTime.now().toIso8601String()),
        multiUpdate: true,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getVentas({DateTime? fecha}) async {
    await _ensureConnected();
    if (fecha == null) return _colVentas.find().toList();

    final inicio = DateTime(fecha.year, fecha.month, fecha.day);
    final fin = inicio.add(const Duration(days: 1));
    return _colVentas.find({
      'fechaVenta': {
        r'$gte': inicio.toIso8601String(),
        r'$lt': fin.toIso8601String(),
      },
    }).toList();
  }

  DbCollection _ventasCol() => _db.collection('ventas');
  DbCollection _productosCol() => _db.collection('producto'); // ← alineado

  String _hexFromAnyId(dynamic raw) {
    if (raw == null) return '';
    if (raw is ObjectId) return raw.toHexString();
    if (raw is Map && raw[r'$oid'] is String) return raw[r'$oid'] as String;
    final s = raw.toString();
    final m = RegExp(r'([0-9a-fA-F]{24})').firstMatch(s);
    return m?.group(1) ?? s;
  }

  ObjectId _objectIdFromHex(String hex) {
    try {
      return ObjectId.fromHexString(hex);
    } catch (_) {
      // fallback para evitar crasheo; crea un ObjectId random si el hex no es válido
      return ObjectId();
    }
  }

  Future<void> reemplazarProductoEnVenta(
    String ventaIdHex,
    String productoIdAnteriorHex,
    Map<String, dynamic> nuevoRenglon,
    Map<String, dynamic> registroCambio,
  ) async {
    // ignore: unnecessary_null_comparison
    if (_db == null) {
      throw StateError('MongoService no conectado');
    }
    final ventas = _ventasCol();
    final oid = _objectIdFromHex(ventaIdHex);

    // 1) Leer la venta actual
    final venta = await ventas.findOne(where.id(oid));
    if (venta == null) {
      throw StateError('Venta no encontrada: $ventaIdHex');
    }

    final List productos = (venta['productos'] ?? []) as List;
    if (productos.isEmpty) {
      throw StateError('La venta no contiene productos');
    }

    // 2) Buscar el índice del item a reemplazar (acepta productoId guardado como String u ObjectId)
    int index = -1;
    for (int i = 0; i < productos.length; i++) {
      final p = (productos[i] as Map).cast<String, dynamic>();
      final hex = _hexFromAnyId(p['productoId']);
      if (hex == productoIdAnteriorHex) {
        index = i;
        break;
      }
    }

    if (index < 0) {
      throw StateError('Producto a reemplazar no está en la venta');
    }

    // 3) Normaliza el nuevo renglón: guarda productoId como String HEX
    final nuevo = Map<String, dynamic>.from(nuevoRenglon);
    nuevo['productoId'] = '${nuevo['productoId']}'; // asegúrate que sea String
    nuevo['precioVendido'] = (nuevo['precioVendido'] is num)
        ? (nuevo['precioVendido'] as num).toDouble()
        : double.tryParse('${nuevo['precioVendido']}') ?? 0.0;

    // 4) Construye el nuevo array en memoria (evita arrayFilters)
    final List nuevosProductos = List.of(productos);
    nuevosProductos[index] = nuevo;

    // 5) Actualiza la venta: set productos + push cambios + marca updatedAt
    await ventas.updateOne(
      _toQuery(where.id(oid)), // 👈 compat seguro
      {
        r'$set': {
          'productos': nuevosProductos,
          'updatedAt': DateTime.now().toIso8601String(),
        },
        r'$push': {'cambios': registroCambio},
      },
    );
  }

  Future<void> marcarProductosDisponibles(List<String> ids) async {
    await _ensureConnected();
    if (ids.isEmpty) return;

    final coll = _colProducto; // ✅ usa SIEMPRE 'producto' (singular)

    final objectIds = <ObjectId>[];

    for (final id in ids) {
      try {
        // Si es un ObjectId válido, lo acumulamos para un update masivo
        objectIds.add(ObjectId.parse(id));
      } catch (_) {
        // Si el _id está guardado como String, actualizamos por igualdad de string
        await coll.update(
          where.eq('_id', id),
          modify
              .set('estado', 'disponible')
              .unset('fechaVenta') // opcional, limpia marcas previas
              .unset('fechaApartado') // opcional
              .set('updatedAt', DateTime.now().toIso8601String()),
        );
      }
    }

    if (objectIds.isNotEmpty) {
      await coll.update(
        where.oneFrom('_id', objectIds),
        modify
            .set('estado', 'disponible')
            .unset('fechaVenta') // opcional
            .unset('fechaApartado') // opcional
            .set('updatedAt', DateTime.now().toIso8601String()),
        multiUpdate: true,
      );
    }
  }

  bool _isValidHex(String s) => RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(s);

  Map<String, dynamic> _toQuery(SelectorBuilder sb) {
    // Para compatibilidad con versiones de mongo_dart:
    final map = sb.map;
    if (map.containsKey(r'$query') && map[r'$query'] is Map) {
      return (map[r'$query'] as Map).cast<String, dynamic>();
    }
    return map.cast<String, dynamic>();
  }
}
