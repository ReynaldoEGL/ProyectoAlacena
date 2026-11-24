import 'package:sqflite/sqflite.dart';

import 'inventory_db.dart';

/// Datos de muestra para visualizar las listas Sliver del inventario.
/// Se insertan una sola vez en cada base de datos, sin borrar registros reales.
class DemoSeeder {
  DemoSeeder._();

  static const _seedKey = 'demo_10_productos_sliver_v1';

  static const _products = <_DemoProduct>[
    _DemoProduct(
      name: 'Leche entera', brand: 'Granja Fresca',
      category: 'Lácteos', unit: 'L', quantity: 2,
      minStock: 2, expiryDays: 2, unitCost: 29,
      store: 'Supermercado', extraQuantity: 1,
      extraExpiryDays: 8,
    ),
    _DemoProduct(
      name: 'Yogur natural', brand: 'Valle Verde',
      category: 'Lácteos', unit: 'pieza', quantity: 4,
      minStock: 3, expiryDays: 3, unitCost: 16,
      store: 'Mercado local', extraQuantity: 2,
      extraExpiryDays: 3,
    ),
    _DemoProduct(
      name: 'Queso panela', brand: 'El Rancho',
      category: 'Lácteos', unit: 'paquete', quantity: 1,
      minStock: 2, expiryDays: 1, unitCost: 68,
      store: 'Supermercado',
    ),
    _DemoProduct(
      name: 'Manzana roja',
      category: 'Frutas y verduras', unit: 'kg', quantity: 1.5,
      minStock: 1, expiryDays: 4, unitCost: 42,
      store: 'Mercado local',
    ),
    _DemoProduct(
      name: 'Pechuga de pollo',
      category: 'Carnes', unit: 'kg', quantity: 1.2,
      minStock: 0.5, expiryDays: -1, unitCost: 115,
      store: 'Supermercado',
    ),
    _DemoProduct(
      name: 'Huevos blancos',
      category: 'Despensa', unit: 'pieza', quantity: 4,
      minStock: 6, expiryDays: 25, unitCost: 4,
      store: 'Mercado local',
    ),
    _DemoProduct(
      name: 'Arroz blanco', brand: 'La Cocina',
      category: 'Despensa', unit: 'kg', quantity: 1,
      minStock: 2, expiryDays: 180, unitCost: 34,
      store: 'Supermercado',
    ),
    _DemoProduct(
      name: 'Café molido', brand: 'Sierra Alta',
      category: 'Bebidas', unit: 'paquete', quantity: 0,
      minStock: 1, expiryDays: 140, unitCost: 95,
      store: 'Supermercado',
    ),
    _DemoProduct(
      name: 'Agua embotellada',
      category: 'Bebidas', unit: 'L', quantity: 3,
      minStock: 6, expiryDays: 200, unitCost: 12,
      store: 'Supermercado',
    ),
    _DemoProduct(
      name: 'Detergente líquido', brand: 'Limpio',
      category: 'Limpieza', unit: 'L', quantity: 3,
      minStock: 1, expiryDays: 365, unitCost: 58,
      store: 'Supermercado',
    ),
  ];

  /// Devuelve el número de artículos nuevos. Una vez aplicada la carga,
  /// devuelve cero incluso después de reiniciar la aplicación.
  static Future<int> insertOnce() async {
    final db = await InventoryDB.instance.database;
    final today = DateTime.now();
    final midnight = DateTime(today.year, today.month, today.day);
    final purchaseDate = _isoDate(midnight.subtract(const Duration(days: 10)));

    return db.transaction<int>((txn) async {
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS demo_seed_meta (
          key TEXT PRIMARY KEY,
          created_at TEXT NOT NULL
        )
      ''');
      final alreadyInserted = await txn.query(
        'demo_seed_meta',
        columns: ['key'],
        where: 'key = ?',
        whereArgs: [_seedKey],
        limit: 1,
      );
      if (alreadyInserted.isNotEmpty) return 0;

      final categories = <String, int>{};
      final stores = <String, int>{};
      var inserted = 0;

      for (final sample in _products) {
        final categoryId = categories[sample.category] ??=
            await _getOrCreateCategory(txn, sample.category);
        final storeId = stores[sample.store] ??=
            await _getOrCreateStore(txn, sample.store);

        // Si ya existe el mismo artículo con la misma marca, respetarlo.
        final duplicate = await txn.query(
          'products',
          columns: ['id'],
          where: 'name = ? COLLATE NOCASE AND brand = ? COLLATE NOCASE',
          whereArgs: [sample.name, sample.brand],
          limit: 1,
        );
        if (duplicate.isNotEmpty) continue;

        final productId = await txn.insert('products', {
          'name': sample.name,
          'brand': sample.brand,
          'category_id': categoryId,
          'unit': sample.unit,
          'min_stock': sample.minStock,
          'expiry_alert_days': 5,
          'image_path': '',
          'ultima_tienda_id': sample.quantity > 0 ? storeId : null,
          'is_active': 1,
        });
        inserted++;

        if (sample.quantity > 0) {
          await _insertExampleLot(
            txn,
            productId: productId,
            storeId: storeId,
            quantity: sample.quantity,
            expiryDate: _isoDate(midnight.add(Duration(days: sample.expiryDays))),
            purchaseDate: purchaseDate,
            unitCost: sample.unitCost,
          );
        }
        if (sample.extraQuantity > 0) {
          await _insertExampleLot(
            txn,
            productId: productId,
            storeId: storeId,
            quantity: sample.extraQuantity,
            expiryDate: _isoDate(midnight.add(Duration(days: sample.extraExpiryDays))),
            purchaseDate: purchaseDate,
            unitCost: sample.unitCost,
          );
        }
      }

      // Esta fila y los datos anteriores se confirman en la misma transacción.
      await txn.insert('demo_seed_meta', {
        'key': _seedKey,
        'created_at': today.toIso8601String(),
      });
      return inserted;
    });
  }

  static Future<int> _getOrCreateCategory(
    Transaction txn,
    String name,
  ) async {
    final existing = await txn.query(
      'categories', columns: ['id'],
      where: 'name = ? COLLATE NOCASE', whereArgs: [name], limit: 1,
    );
    if (existing.isNotEmpty) return (existing.first['id'] as num).toInt();
    return txn.insert('categories', {'name': name, 'icon': 'category'});
  }

  static Future<int> _getOrCreateStore(Transaction txn, String name) async {
    final existing = await txn.query(
      'stores', columns: ['id'],
      where: 'name = ? COLLATE NOCASE', whereArgs: [name], limit: 1,
    );
    if (existing.isNotEmpty) return (existing.first['id'] as num).toInt();
    return txn.insert('stores', {
      'name': name,
      'address': '',
      'phone': '',
    });
  }

  static Future<void> _insertExampleLot(
    Transaction txn, {
    required int productId,
    required int storeId,
    required double quantity,
    required String expiryDate,
    required String purchaseDate,
    required double unitCost,
  }) async {
    final lotId = await txn.insert('lots', {
      'product_id': productId,
      'quantity_initial': quantity,
      'quantity_current': quantity,
      'expiration_date': expiryDate,
      'purchase_date': purchaseDate,
      'store_id': storeId,
      'unit_cost': unitCost,
      'notification_id': null,
      'notification_scheduled': 0,
    });
    await txn.insert('purchase_history', {
      'product_id': productId,
      'store_id': storeId,
      'lot_id': lotId,
      'quantity': quantity,
      'unit_cost': unitCost,
      'purchased_at': purchaseDate,
    });
  }

  static String _isoDate(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}

class _DemoProduct {
  const _DemoProduct({
    required this.name,
    required this.category,
    required this.unit,
    required this.quantity,
    required this.minStock,
    required this.expiryDays,
    required this.unitCost,
    required this.store,
    this.brand = '',
    this.extraQuantity = 0,
    this.extraExpiryDays = 0,
  });

  final String name;
  final String brand;
  final String category;
  final String unit;
  final double quantity;
  final double minStock;
  final int expiryDays;
  final double unitCost;
  final String store;
  final double extraQuantity;
  final int extraExpiryDays;
}
