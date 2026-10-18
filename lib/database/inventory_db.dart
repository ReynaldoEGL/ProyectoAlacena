import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class InventoryDB {
  InventoryDB._();
  static final InventoryDB instance = InventoryDB._();

  static const int _version = 1;
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final base = await getDatabasesPath();
    final dbPath = p.join(base, 'alacena_local.db');
    _db = await openDatabase(
      dbPath,
      version: _version,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL COLLATE NOCASE UNIQUE,
            icon TEXT NOT NULL DEFAULT 'category'
          )
        ''');
        await db.execute('''
          CREATE TABLE stores (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL COLLATE NOCASE UNIQUE,
            address TEXT NOT NULL DEFAULT '',
            phone TEXT NOT NULL DEFAULT ''
          )
        ''');
        await db.execute('''
          CREATE TABLE products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL COLLATE NOCASE,
            brand TEXT NOT NULL DEFAULT '',
            category_id INTEGER NOT NULL,
            unit TEXT NOT NULL DEFAULT 'pieza',
            min_stock REAL NOT NULL DEFAULT 1 CHECK(min_stock >= 0),
            expiry_alert_days INTEGER NOT NULL DEFAULT 5 CHECK(expiry_alert_days >= 0),
            image_path TEXT NOT NULL DEFAULT '',
            ultima_tienda_id INTEGER,
            is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0,1)),
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(category_id) REFERENCES categories(id) ON UPDATE CASCADE ON DELETE RESTRICT,
            FOREIGN KEY(ultima_tienda_id) REFERENCES stores(id) ON UPDATE CASCADE ON DELETE SET NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE lots (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            product_id INTEGER NOT NULL,
            quantity_initial REAL NOT NULL CHECK(quantity_initial >= 0),
            quantity_current REAL NOT NULL CHECK(quantity_current >= 0),
            expiration_date TEXT NOT NULL,
            purchase_date TEXT NOT NULL,
            store_id INTEGER NOT NULL,
            unit_cost REAL NOT NULL DEFAULT 0 CHECK(unit_cost >= 0),
            notification_id INTEGER,
            notification_scheduled INTEGER NOT NULL DEFAULT 0 CHECK(notification_scheduled IN (0,1)),
            FOREIGN KEY(product_id) REFERENCES products(id) ON UPDATE CASCADE ON DELETE CASCADE,
            FOREIGN KEY(store_id) REFERENCES stores(id) ON UPDATE CASCADE ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE purchase_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            product_id INTEGER NOT NULL,
            store_id INTEGER NOT NULL,
            lot_id INTEGER,
            quantity REAL NOT NULL CHECK(quantity > 0),
            unit_cost REAL NOT NULL CHECK(unit_cost >= 0),
            purchased_at TEXT NOT NULL,
            FOREIGN KEY(product_id) REFERENCES products(id) ON UPDATE CASCADE ON DELETE RESTRICT,
            FOREIGN KEY(store_id) REFERENCES stores(id) ON UPDATE CASCADE ON DELETE RESTRICT,
            FOREIGN KEY(lot_id) REFERENCES lots(id) ON UPDATE CASCADE ON DELETE SET NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE consumption_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            product_id INTEGER NOT NULL,
            lot_id INTEGER,
            quantity REAL NOT NULL CHECK(quantity > 0),
            consumed_at TEXT NOT NULL,
            FOREIGN KEY(product_id) REFERENCES products(id) ON UPDATE CASCADE ON DELETE RESTRICT,
            FOREIGN KEY(lot_id) REFERENCES lots(id) ON UPDATE CASCADE ON DELETE SET NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE cart (
            product_id INTEGER PRIMARY KEY,
            quantity REAL NOT NULL CHECK(quantity > 0),
            FOREIGN KEY(product_id) REFERENCES products(id) ON UPDATE CASCADE ON DELETE CASCADE
          )
        ''');
        await db.execute('CREATE INDEX idx_lots_product_expiry ON lots(product_id, expiration_date)');
        await db.execute('CREATE INDEX idx_lots_expiry ON lots(expiration_date)');
        await db.execute('CREATE INDEX idx_purchases_product ON purchase_history(product_id)');

        final categories = <Map<String, Object>>[
          {'name': 'Frutas y verduras', 'icon': 'eco'},
          {'name': 'Lácteos', 'icon': 'egg_alt'},
          {'name': 'Despensa', 'icon': 'inventory_2'},
          {'name': 'Carnes', 'icon': 'lunch_dining'},
          {'name': 'Bebidas', 'icon': 'local_cafe'},
          {'name': 'Congelados', 'icon': 'ac_unit'},
          {'name': 'Limpieza', 'icon': 'cleaning_services'},
          {'name': 'Otros', 'icon': 'category'},
        ];
        for (final row in categories) {
          await db.insert('categories', row);
        }
        await db.insert('stores', {'name': 'Supermercado', 'address': '', 'phone': ''});
        await db.insert('stores', {'name': 'Mercado local', 'address': '', 'phone': ''});
      },
    );
    return _db!;
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await database;
    return db.query('categories', orderBy: 'name COLLATE NOCASE');
  }

  Future<List<Map<String, dynamic>>> getStores() async {
    final db = await database;
    return db.query('stores', orderBy: 'name COLLATE NOCASE');
  }

  Future<int> saveCategory({int? id, required String name, String icon = 'category'}) async {
    final db = await database;
    final data = {'name': name.trim(), 'icon': icon};
    if (id == null) return db.insert('categories', data);
    return db.update('categories', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> saveStore({int? id, required String name, String address = '', String phone = ''}) async {
    final db = await database;
    final data = {'name': name.trim(), 'address': address.trim(), 'phone': phone.trim()};
    if (id == null) return db.insert('stores', data);
    return db.update('stores', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteStore(int id) async {
    final db = await database;
    return db.delete('stores', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> saveProduct(Map<String, dynamic> values, {int? id}) async {
    final db = await database;
    final data = <String, Object?>{
      'name': (values['name'] as String).trim(),
      'brand': (values['brand'] as String? ?? '').trim(),
      'category_id': values['category_id'],
      'unit': values['unit'],
      'min_stock': values['min_stock'],
      'expiry_alert_days': values['expiry_alert_days'],
      'image_path': values['image_path'] ?? '',
    };
    if (id == null) return db.insert('products', data);
    return db.update('products', data, where: 'id = ? AND is_active = 1', whereArgs: [id]);
  }

  Future<void> archiveProduct(int id) async {
    final db = await database;
    await db.update('products', {'is_active': 0}, where: 'id = ?', whereArgs: [id]);
    await db.delete('cart', where: 'product_id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>?> getProduct(int id) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT p.*, c.name AS category_name, s.name AS last_store_name
      FROM products p
      JOIN categories c ON c.id = p.category_id
      LEFT JOIN stores s ON s.id = p.ultima_tienda_id
      WHERE p.id = ?
    ''', [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> getInventory({bool activeOnly = true}) async {
    final db = await database;
    final active = activeOnly ? 'WHERE p.is_active = 1' : '';
    return db.rawQuery('''
      SELECT p.*, c.name AS category_name, s.name AS last_store_name,
        COALESCE(SUM(CASE WHEN l.quantity_current > 0 THEN l.quantity_current ELSE 0 END), 0) AS stock_total,
        COALESCE(SUM(CASE WHEN l.quantity_current > 0 AND date(l.expiration_date) < date('now','localtime') THEN l.quantity_current ELSE 0 END), 0) AS expired_stock,
        MIN(CASE WHEN l.quantity_current > 0 AND date(l.expiration_date) >= date('now','localtime') THEN l.expiration_date END) AS next_expiry
      FROM products p
      JOIN categories c ON c.id = p.category_id
      LEFT JOIN stores s ON s.id = p.ultima_tienda_id
      LEFT JOIN lots l ON l.product_id = p.id
      $active
      GROUP BY p.id
      ORDER BY p.name COLLATE NOCASE
    ''');
  }

  Future<List<Map<String, dynamic>>> getLots(int productId) async {
    final db = await database;
    return db.rawQuery('''
      SELECT l.*, s.name AS store_name
      FROM lots l JOIN stores s ON s.id = l.store_id
      WHERE l.product_id = ?
      ORDER BY CASE WHEN date(l.expiration_date) < date('now','localtime') THEN 0 ELSE 1 END,
        l.expiration_date ASC, l.id ASC
    ''', [productId]);
  }

  Future<Map<String, dynamic>?> getLot(int lotId) async {
    final db = await database;
    final rows = await db.query('lots', where: 'id = ?', whereArgs: [lotId], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  /// Un lote nuevo se registra como compra y actualiza la última tienda en una transacción.
  /// Una edición modifica el lote, pero no reescribe el historial de compra original.
  Future<int> saveLot({
    int? lotId,
    required int productId,
    required double quantity,
    required String expiryDate,
    required String purchaseDate,
    required int storeId,
    required double unitCost,
  }) async {
    if (quantity < 0 || unitCost < 0) throw ArgumentError('Cantidad y costo no pueden ser negativos.');
    final db = await database;
    return db.transaction<int>((txn) async {
      if (lotId == null) {
        final insertedLot = await txn.insert('lots', {
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
          'lot_id': insertedLot,
          'quantity': quantity,
          'unit_cost': unitCost,
          'purchased_at': purchaseDate,
        });
        await txn.update('products', {'ultima_tienda_id': storeId}, where: 'id = ?', whereArgs: [productId]);
        return insertedLot;
      }
      await txn.update('lots', {
        'quantity_current': quantity,
        'expiration_date': expiryDate,
        'unit_cost': unitCost,
      }, where: 'id = ? AND product_id = ?', whereArgs: [lotId, productId]);
      return lotId;
    });
  }

  Future<void> setLotNotification(int lotId, {required int notificationId, required bool scheduled}) async {
    final db = await database;
    await db.update('lots', {
      'notification_id': notificationId,
      'notification_scheduled': scheduled ? 1 : 0,
    }, where: 'id = ?', whereArgs: [lotId]);
  }

  Future<int> deleteLot(int id) async {
    final db = await database;
    // El historial conserva la compra; lot_id se vuelve NULL por la FK ON DELETE SET NULL.
    return db.delete('lots', where: 'id = ?', whereArgs: [id]);
  }

  /// Descuenta únicamente lotes no vencidos y por fecha FEFO (la caducidad más cercana primero).
  /// Todo ocurre dentro de una transacción para no dejar cantidades parcialmente modificadas.
  Future<void> consumeFefo(int productId, double requested) async {
    if (requested <= 0) throw ArgumentError('La cantidad debe ser mayor que cero.');
    final db = await database;
    await db.transaction((txn) async {
      final today = DateTime.now();
      final todayIso = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final lots = await txn.query('lots',
        where: 'product_id = ? AND quantity_current > 0 AND expiration_date >= ?',
        whereArgs: [productId, todayIso],
        orderBy: 'expiration_date ASC, id ASC');
      final available = lots.fold<double>(0, (sum, lot) => sum + ((lot['quantity_current'] as num).toDouble()));
      if (available + 0.000001 < requested) {
        throw StateError('Existencias vigentes insuficientes. Disponibles: ${available.toStringAsFixed(2)}');
      }
      var remaining = requested;
      final nowIso = DateTime.now().toIso8601String();
      for (final lot in lots) {
        if (remaining <= 0.000001) break;
        final current = (lot['quantity_current'] as num).toDouble();
        final used = current < remaining ? current : remaining;
        await txn.update('lots', {'quantity_current': current - used}, where: 'id = ?', whereArgs: [lot['id']]);
        await txn.insert('consumption_history', {
          'product_id': productId,
          'lot_id': lot['id'],
          'quantity': used,
          'consumed_at': nowIso,
        });
        remaining -= used;
      }
    });
  }

  Future<List<Map<String, dynamic>>> getStoresForProduct(int productId) async {
    final db = await database;
    return db.rawQuery('''
      SELECT DISTINCT s.id, s.name, s.address, MAX(h.purchased_at) AS last_purchase
      FROM purchase_history h JOIN stores s ON s.id = h.store_id
      WHERE h.product_id = ?
      GROUP BY s.id, s.name, s.address
      ORDER BY last_purchase DESC
    ''', [productId]);
  }

  Future<List<Map<String, dynamic>>> getPurchaseHistory({int? productId}) async {
    final db = await database;
    if (productId != null) {
      return db.rawQuery('''
        SELECT h.*, s.name AS store_name FROM purchase_history h
        JOIN stores s ON s.id = h.store_id WHERE h.product_id = ?
        ORDER BY h.purchased_at DESC
      ''', [productId]);
    }
    return db.rawQuery('''
      SELECT h.*, s.name AS store_name, p.name AS product_name FROM purchase_history h
      JOIN stores s ON s.id = h.store_id JOIN products p ON p.id = h.product_id
      ORDER BY h.purchased_at DESC
    ''');
  }

  Future<int> addToCart(int productId, {double quantity = 1}) async {
    final db = await database;
    // Se evita depender del UPSERT de SQLite 3.24+, para funcionar también
    // en dispositivos Android cuya versión nativa de SQLite sea más antigua.
    await db.transaction((txn) async {
      final current = await txn.query(
        'cart',
        columns: ['quantity'],
        where: 'product_id = ?',
        whereArgs: [productId],
        limit: 1,
      );
      if (current.isEmpty) {
        await txn.insert('cart', {'product_id': productId, 'quantity': quantity});
      } else {
        final oldQuantity = (current.first['quantity'] as num).toDouble();
        await txn.update(
          'cart',
          {'quantity': oldQuantity + quantity},
          where: 'product_id = ?',
          whereArgs: [productId],
        );
      }
    });
    return getCartCount();
  }

  Future<void> updateCartQuantity(int productId, double quantity) async {
    final db = await database;
    if (quantity <= 0) {
      await db.delete('cart', where: 'product_id = ?', whereArgs: [productId]);
    } else {
      await db.update('cart', {'quantity': quantity}, where: 'product_id = ?', whereArgs: [productId]);
    }
  }

  Future<int> getCartCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) AS count FROM cart');
    return (result.first['count'] as num).toInt();
  }

  Future<List<Map<String, dynamic>>> getCartItems() async {
    final db = await database;
    return db.rawQuery('''
      SELECT c.product_id, c.quantity, p.name, p.brand, p.unit, p.image_path,
        COALESCE((SELECT SUM(l.quantity_current) FROM lots l WHERE l.product_id = p.id AND l.quantity_current > 0),0) AS stock_total
      FROM cart c JOIN products p ON p.id = c.product_id
      WHERE p.is_active = 1 ORDER BY p.name COLLATE NOCASE
    ''');
  }

  Future<void> clearCart() async {
    final db = await database;
    await db.delete('cart');
  }

  /// Regresa eventos agrupados por fecha y por producto: un producto produce un marcador por día,
  /// aunque tenga varios lotes que caduquen en esa misma fecha.
  Future<Map<String, List<Map<String, dynamic>>>> getCalendarEvents() async {
    final inventory = await getInventory();
    final lots = await (await database).rawQuery('''
      SELECT l.id AS lot_id, l.product_id, l.quantity_current, l.expiration_date, s.name AS store_name,
        p.name, p.brand, p.unit, p.image_path, p.min_stock, p.expiry_alert_days,
        c.name AS category_name
      FROM lots l JOIN products p ON p.id = l.product_id
      JOIN categories c ON c.id = p.category_id
      JOIN stores s ON s.id = l.store_id
      WHERE p.is_active = 1 AND l.quantity_current > 0
      ORDER BY l.expiration_date, p.name
    ''');
    final grouped = <String, Map<int, Map<String, dynamic>>>{};
    for (final lot in lots) {
      final day = lot['expiration_date'].toString();
      final productId = (lot['product_id'] as num).toInt();
      grouped.putIfAbsent(day, () => <int, Map<String, dynamic>>{});
      final existing = grouped[day]![productId];
      if (existing == null) {
        grouped[day]![productId] = {...lot, 'event_type': 'Caducidad'};
      } else {
        existing['lot_count'] = ((existing['lot_count'] as int?) ?? 1) + 1;
      }
    }
    final now = DateTime.now();
    final today = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    for (final product in inventory) {
      final stock = (product['stock_total'] as num).toDouble();
      final expired = (product['expired_stock'] as num).toDouble();
      final minimum = (product['min_stock'] as num).toDouble();
      final hasLowStock = stock <= minimum;
      if (stock <= 0 || hasLowStock || expired > 0) {
        grouped.putIfAbsent(today, () => <int, Map<String, dynamic>>{});
        final id = (product['id'] as num).toInt();
        final existing = grouped[today]![id];
        final type = stock <= 0 ? 'Sin existencia' : (expired > 0 ? 'Caducado' : 'Por agotarse');
        if (existing == null) {
          grouped[today]![id] = {...product, 'event_type': type};
        } else {
          existing['event_type'] = '${existing['event_type']} · $type';
        }
      }
    }
    return grouped.map((key, value) => MapEntry(key, value.values.toList()));
  }

  Future<List<Map<String, dynamic>>> getSpendingByStore() async {
    final db = await database;
    return db.rawQuery('''
      SELECT s.name, COALESCE(SUM(h.quantity * h.unit_cost),0) AS total
      FROM purchase_history h JOIN stores s ON s.id = h.store_id
      GROUP BY s.id, s.name ORDER BY total DESC
    ''');
  }

  Future<int> countProducts() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) AS count FROM products WHERE is_active = 1');
    return (result.first['count'] as num).toInt();
  }
}
