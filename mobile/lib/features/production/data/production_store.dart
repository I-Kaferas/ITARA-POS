import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/terminal_config_repository.dart';
import '../../../data/local/local_database.dart';
import '../../../sync/offline_store.dart';

class ProductionStore {
  ProductionStore._();

  static final ProductionStore instance = ProductionStore._();

  Future<Database> get _db => LocalDatabase.instance.database;

  Future<Map<String, dynamic>> snapshot() async {
    await _seed();
    final db = await _db;
    final docs = await db.query(
      'hospitality_docs',
      where: "kind IN ('recipe', 'production_run')",
      orderBy: 'updated_at DESC',
    );
    final products = await _products();
    final recipes = <Map<String, dynamic>>[
      ...docs.where((row) => row['kind'] == 'recipe').map(_decode),
      ..._catalogRecipes(products),
    ];
    final seen = <String>{};
    final unique = <Map<String, dynamic>>[];
    for (final recipe in recipes) {
      final key = recipe['finished_product_id']?.toString() ?? recipe['id'].toString();
      if (!seen.add(key)) continue;
      unique.add(_withStock(recipe, products));
    }
    return {
      'recipes': unique,
      'runs': docs.where((row) => row['kind'] == 'production_run').map(_decode).take(12).toList(),
      'products': products.values
          .map((item) => {
                'id': item['product_id'],
                'name': item['name'],
                'quantity_on_hand': item['quantity_on_hand'],
              })
          .toList(),
    };
  }

  Future<Map<String, dynamic>> produce(Map<String, dynamic> action) async {
    final batches = (action['batches'] as num?)?.toInt() ?? 1;
    if (batches <= 0) throw Exception('Quantité de production invalide');
    final recipe = await _recipe(action['recipe_id'].toString());
    final finishedId = recipe['finished_product_id']?.toString() ?? '';
    final yieldQty = (recipe['yield_quantity'] as num?)?.toInt() ?? 1;
    final ingredients = (recipe['lines'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((line) {
          final perBatch = (line['quantity'] as num?)?.toDouble() ?? 0;
          final quantity = (perBatch * batches).round();
          return {
            'product_id': line['product_id'],
            'name': line['name'],
            'quantity': quantity < 1 && perBatch > 0 ? 1 : quantity,
          };
        })
        .where((line) => (line['quantity'] as int) > 0)
        .toList();
    final productionId = const Uuid().v4();
    final stock = await OfflineStore.instance.applyProduction(
      productionId: productionId,
      finishedProductId: finishedId,
      finishedQuantity: yieldQty * batches,
      ingredients: ingredients,
    );
    await _save('production_run', productionId, {
      'recipe_id': recipe['id'],
      'recipe_name': recipe['name'],
      'batches': batches,
      'finished_quantity': yieldQty * batches,
      'ingredients': ingredients,
      'produced_at': DateTime.now().toIso8601String(),
    }, status: 'done');
    final snap = await snapshot();
    snap['stock'] = stock;
    return snap;
  }

  Future<void> _seed() async {
    final db = await _db;
    final existing = await db.query('hospitality_docs', where: "kind = 'recipe'", limit: 1);
    if (existing.isNotEmpty) return;
    final products = await _products();
    final finished = await _ensureProduct(products, 'Pizza', sku: 'PIZZA', stock: 0);
    final lines = <Map<String, dynamic>>[];
    for (final name in ['Farine', 'Fromage', 'Sauce', 'Viande']) {
      final product = await _ensureProduct(products, name, sku: name.toUpperCase(), stock: 20);
      lines.add({'product_id': product['product_id'], 'name': name, 'quantity': 1});
    }
    await _save('recipe', 'recipe-pizza', {
      'name': 'Pizza',
      'finished_product_id': finished['product_id'],
      'finished_name': 'Pizza',
      'yield_quantity': 1,
      'lines': lines,
    }, status: 'active');
  }

  Future<Map<String, dynamic>> _recipe(String id) async {
    if (id.startsWith('catalog-')) {
      final productId = id.substring('catalog-'.length);
      final products = await _products();
      final product = products[productId];
      if (product == null) throw Exception('Recette introuvable');
      return _catalogRecipe(product, products);
    }
    final db = await _db;
    final rows = await db.query('hospitality_docs', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) throw Exception('Recette introuvable');
    return _decode(rows.first);
  }

  List<Map<String, dynamic>> _catalogRecipes(Map<String, Map<String, dynamic>> products) {
    return products.values
        .where((product) => (product['bundle_items'] as List?)?.isNotEmpty == true)
        .map((product) => _catalogRecipe(product, products))
        .toList();
  }

  Map<String, dynamic> _catalogRecipe(
    Map<String, dynamic> product,
    Map<String, Map<String, dynamic>> products,
  ) {
    final lines = (product['bundle_items'] as List<dynamic>? ?? []).whereType<Map>().map((item) {
      final componentId = item['component_product_id']?.toString() ?? '';
      return {
        'product_id': componentId,
        'name': products[componentId]?['name'] ?? componentId,
        'quantity': item['quantity'] ?? 1,
      };
    }).toList();
    return {
      'id': 'catalog-${product['product_id']}',
      'name': product['name'],
      'finished_product_id': product['product_id'],
      'finished_name': product['name'],
      'yield_quantity': 1,
      'lines': lines,
      'source': 'catalog',
    };
  }

  Map<String, dynamic> _withStock(Map<String, dynamic> recipe, Map<String, Map<String, dynamic>> products) {
    final lines = (recipe['lines'] as List<dynamic>? ?? []).whereType<Map>().map((line) {
      final product = products[line['product_id']?.toString()];
      return {
        ...Map<String, dynamic>.from(line),
        'name': line['name'] ?? product?['name'],
        'quantity_on_hand': product?['quantity_on_hand'],
      };
    }).toList();
    final finished = products[recipe['finished_product_id']?.toString()];
    return {
      ...recipe,
      'lines': lines,
      'finished_name': recipe['finished_name'] ?? finished?['name'] ?? recipe['name'],
      'finished_on_hand': finished?['quantity_on_hand'],
    };
  }

  Future<Map<String, dynamic>> _ensureProduct(
    Map<String, Map<String, dynamic>> products,
    String name, {
    required String sku,
    required int stock,
  }) async {
    final wanted = name.toLowerCase();
    for (final item in products.values) {
      if (item['name']?.toString().toLowerCase() == wanted) return item;
    }
    final storeId = TerminalConfigRepository.instance.config.storeId;
    final id = 'prod-${sku.toLowerCase()}';
    final json = {
      'product_id': id,
      'store_product_id': id,
      'sku': sku,
      'name': name,
      'price': 0,
      'quantity_on_hand': stock,
      'stock_version': 1,
      'local_production': true,
      'product_type': 'simple',
      'is_available': true,
    };
    final db = await _db;
    await db.insert(
      'products',
      {
        'product_id': id,
        'store_id': storeId.isEmpty ? 'local' : storeId,
        'sku': sku,
        'name': name,
        'price': 0,
        'json': jsonEncode(json),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    products[id] = json;
    return json;
  }

  Future<Map<String, Map<String, dynamic>>> _products() async {
    final db = await _db;
    final storeId = TerminalConfigRepository.instance.config.storeId;
    final rows = storeId.isEmpty
        ? await db.query('products')
        : await db.query('products', where: 'store_id = ? OR store_id = ?', whereArgs: [storeId, 'local']);
    final products = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final json = jsonDecode(row['json'] as String) as Map<String, dynamic>;
      json['product_id'] = row['product_id'];
      json['name'] = json['name'] ?? row['name'];
      products[row['product_id'] as String] = json;
    }
    return products;
  }

  Map<String, dynamic> _decode(Map<String, Object?> row) {
    final json = jsonDecode(row['json'] as String) as Map<String, dynamic>;
    return {...json, 'id': row['id'], 'kind': row['kind']};
  }

  Future<void> _save(String kind, String id, Map<String, dynamic> json, {String? status}) async {
    final db = await _db;
    json['id'] = id;
    await db.insert(
      'hospitality_docs',
      {
        'id': id,
        'kind': kind,
        'parent_id': json['recipe_id'],
        'status': status,
        'json': jsonEncode(json),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
