import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class InventoryDB {
  InventoryDB._();
  static final InventoryDB instance = InventoryDB._();

  // V2 agrega una bitácora de ajustes sin borrar los datos creados con V1.
  static const int _version = 2;
  Database? _db;
  Future<Database>? _opening;

  Future<Database> get database async {
    if (_db != null) return _db!;
    if (_opening != null) return _opening!;
    final future = _open();
    _opening = future;
    try {
      final db = await future;
      _db = db;
      return db;
    } finally {
      _opening = null;
    }
  }

  Future<Database> _open() async {
    final base = await getDatabasesPath();
    return openDatabase(
      p.join(base, 'alacena_local.db'),
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
        await _createAdjustmentTable(db);
        await db.execute(
            'CREATE INDEX idx_lots_product_expiry ON lots(product_id, expiration_date)');
        await db
            .execute('CREATE INDEX idx_lots_expiry ON lots(expiration_date)');
        await db.execute(
            'CREATE INDEX idx_purchases_product ON purchase_history(product_id)');

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
        await db.insert(
            'stores', {'name': 'Supermercado', 'address': '', 'phone': ''});
        await db.insert(
            'stores', {'name': 'Mercado local', 'address': '', 'phone': ''});
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createAdjustmentTable(db);
      },
    );
  }

  static Future<void> _createAdjustmentTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE stock_adjustments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        lot_id INTEGER,
        quantity_before REAL NOT NULL,
        quantity_after REAL NOT NULL,
        reason TEXT NOT NULL,
        adjusted_at TEXT NOT NULL,
        FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE RESTRICT,
        FOREIGN KEY(lot_id) REFERENCES lots(id) ON DELETE SET NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_adjustments_product ON stock_adjustments(product_id)');
  }

  bool _validNumber(double value, {bool positive = false}) =>
      value.isFinite && (positive ? value > 0 : value >= 0);

  void _requiredName(String name) {
    if (name.trim().isEmpty) throw ArgumentError('El nombre es obligatorio.');
  }

  Future<List<Map<String, dynamic>>> getCategories() async =>
      (await database).query('categories', orderBy: 'name COLLATE NOCASE');

  Future<List<Map<String, dynamic>>> getStores() async =>
      (await database).query('stores', orderBy: 'name COLLATE NOCASE');

  Future<int> saveCategory(
      {int? id, required String name, String icon = 'category'}) async {
    _requiredName(name);
    final db = await database;
    final data = {'name': name.trim(), 'icon': icon};
    return id == null
        ? db.insert('categories', data)
        : db.update('categories', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> saveStore(
      {int? id,
      required String name,
      String address = '',
      String phone = ''}) async {
    _requiredName(name);
    final db = await database;
    final data = {
      'name': name.trim(),
      'address': address.trim(),
      'phone': phone.trim()
    };
    return id == null
        ? db.insert('stores', data)
        : db.update('stores', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteCategory(int id) async =>
      (await database).delete('categories', where: 'id = ?', whereArgs: [id]);

  Future<int> deleteStore(int id) async =>
      (await database).delete('stores', where: 'id = ?', whereArgs: [id]);

  Future<int> saveProduct(Map<String, dynamic> values, {int? id}) async {
    final name = (values['name'] as String).trim();
    _requiredName(name);
    final minimum = (values['min_stock'] as num).toDouble();
    final days = (values['expiry_alert_days'] as num).toInt();
    if (!_validNumber(minimum) || days < 0 || days > 365) {
      throw ArgumentError('Revisa el stock mínimo y el plazo de aviso.');
    }
    final db = await database;
    final data = <String, Object?>{
      'name': name,
      'brand': (values['brand'] as String? ?? '').trim(),
      'category_id': values['category_id'],
      'unit': values['unit'],
      'min_stock': minimum,
      'expiry_alert_days': days,
      'image_path': values['image_path'] ?? '',
    };
    return id == null
        ? db.insert('products', data)
        : db.update('products', data,
            where: 'id = ? AND is_active = 1', whereArgs: [id]);
  }

  Future<void> archiveProduct(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('products', {'is_active': 0},
          where: 'id = ?', whereArgs: [id]);
      await txn.delete('cart', where: 'product_id = ?', whereArgs: [id]);
    });
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

  Future<List<Map<String, dynamic>>> getInventory(
      {bool activeOnly = true}) async {
    final db = await database;
    final active = activeOnly ? 'WHERE p.is_active = 1' : '';
    return db.rawQuery('''
      SELECT p.*, c.name AS category_name, s.name AS last_store_name,
        COALESCE(SUM(CASE WHEN l.quantity_current > 0 THEN l.quantity_current ELSE 0 END), 0) AS stock_total,
        COALESCE(SUM(CASE WHEN l.quantity_current > 0 AND date(l.expiration_date) >= date('now','localtime')
          THEN l.quantity_current ELSE 0 END), 0) AS stock_available,
        COALESCE(SUM(CASE WHEN l.quantity_current > 0 AND date(l.expiration_date) < date('now','localtime')
          THEN l.quantity_current ELSE 0 END), 0) AS expired_stock,
        MIN(CASE WHEN l.quantity_current > 0 AND date(l.expiration_date) >= date('now','localtime')
          THEN l.expiration_date END) AS next_expiry
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
      ORDER BY l.expiration_date ASC, l.id ASC
    ''', [productId]);
  }

  Future<Map<String, dynamic>?> getLot(int lotId) async {
    final rows = await (await database)
        .query('lots', where: 'id = ?', whereArgs: [lotId], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> saveLot({
    int? lotId,
    required int productId,
    required double quantity,
    required String expiryDate,
    required String purchaseDate,
    required int storeId,
    required double unitCost,
  }) async {
    if (!_validNumber(quantity) || !_validNumber(unitCost)) {
      throw ArgumentError(
          'Cantidad y costo deben ser números finitos no negativos.');
    }
    if (lotId == null && quantity <= 0) {
      throw ArgumentError('Una compra debe tener cantidad positiva.');
    }
    if (DateTime.tryParse(expiryDate) == null ||
        DateTime.tryParse(purchaseDate) == null) {
      throw ArgumentError('Las fechas son inválidas.');
    }
    final db = await database;
    return db.transaction<int>((txn) async {
      if (lotId == null) {
        final id = await txn.insert('lots', {
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
          'lot_id': id,
          'quantity': quantity,
          'unit_cost': unitCost,
          'purchased_at': purchaseDate,
        });
        await txn.update('products', {'ultima_tienda_id': storeId},
            where: 'id = ?', whereArgs: [productId]);
        return id;
      }
      final old = await txn.query('lots',
          where: 'id = ? AND product_id = ?',
          whereArgs: [lotId, productId],
          limit: 1);
      if (old.isEmpty) throw StateError('El lote ya no existe.');
      final previous = (old.first['quantity_current'] as num).toDouble();
      await txn.update(
          'lots',
          {
            'quantity_current': quantity,
            'expiration_date': expiryDate,
          },
          where: 'id = ? AND product_id = ?',
          whereArgs: [lotId, productId]);
      if ((previous - quantity).abs() > 0.000001) {
        await txn.insert('stock_adjustments', {
          'product_id': productId,
          'lot_id': lotId,
          'quantity_before': previous,
          'quantity_after': quantity,
          'reason': 'Corrección manual de existencias',
          'adjusted_at': DateTime.now().toIso8601String(),
        });
      }
      return lotId;
    });
  }

  Future<List<Map<String, dynamic>>> getStockAdjustments(int productId) async =>
      (await database).query('stock_adjustments',
          where: 'product_id = ?',
          whereArgs: [productId],
          orderBy: 'adjusted_at DESC');

  Future<void> setLotNotification(int lotId,
      {required int notificationId, required bool scheduled}) async {
    await (await database).update(
        'lots',
        {
          'notification_id': notificationId,
          'notification_scheduled': scheduled ? 1 : 0,
        },
        where: 'id = ?',
        whereArgs: [lotId]);
  }

  Future<int> deleteLot(int id) async =>
      (await database).delete('lots', where: 'id = ?', whereArgs: [id]);

  // Solo consume lotes vigentes; todo el descuento y su historial son atómicos.
  Future<List<int>> consumeFefo(int productId, double requested) async {
    if (!_validNumber(requested, positive: true)) {
      throw ArgumentError(
          'La cantidad debe ser un número finito mayor que cero.');
    }
    final db = await database;
    return db.transaction<List<int>>((txn) async {
      final today = DateTime.now();
      final todayIso =
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final lots = await txn.query('lots',
          where:
              'product_id = ? AND quantity_current > 0 AND expiration_date >= ?',
          whereArgs: [productId, todayIso],
          orderBy: 'expiration_date ASC, id ASC');
      final available = lots.fold<double>(
          0, (sum, lot) => sum + (lot['quantity_current'] as num).toDouble());
      if (available + 0.000001 < requested) {
        throw StateError(
            'Existencias vigentes insuficientes. Disponibles: ${available.toStringAsFixed(2)}');
      }
      var remaining = requested;
      final depleted = <int>[];
      final nowIso = DateTime.now().toIso8601String();
      for (final lot in lots) {
        if (remaining <= 0.000001) break;
        final current = (lot['quantity_current'] as num).toDouble();
        final used = current < remaining ? current : remaining;
        final id = (lot['id'] as num).toInt();
        final next = current - used;
        final exhausted = next <= 0.000001;
        await txn.update('lots', {'quantity_current': exhausted ? 0.0 : next},
            where: 'id = ?', whereArgs: [id]);
        await txn.insert('consumption_history', {
          'product_id': productId,
          'lot_id': id,
          'quantity': used,
          'consumed_at': nowIso,
        });
        if (exhausted) depleted.add(id);
        remaining -= used;
      }
      return depleted;
    });
  }

  Future<List<Map<String, dynamic>>> getStoresForProduct(int productId) async =>
      (await database).rawQuery('''
        SELECT s.id, s.name, s.address, MAX(h.purchased_at) AS last_purchase
        FROM purchase_history h JOIN stores s ON s.id = h.store_id
        WHERE h.product_id = ?
        GROUP BY s.id, s.name, s.address
        ORDER BY last_purchase DESC
      ''', [productId]);

  Future<List<Map<String, dynamic>>> getPurchaseHistory(
      {int? productId}) async {
    final db = await database;
    if (productId != null) {
      return db.rawQuery('''
        SELECT h.*, s.name AS store_name FROM purchase_history h
        JOIN stores s ON s.id = h.store_id WHERE h.product_id = ?
        ORDER BY h.purchased_at DESC, h.id DESC
      ''', [productId]);
    }
    return db.rawQuery('''
      SELECT h.*, s.name AS store_name, p.name AS product_name FROM purchase_history h
      JOIN stores s ON s.id = h.store_id JOIN products p ON p.id = h.product_id
      ORDER BY h.purchased_at DESC, h.id DESC
    ''');
  }

  Future<int> addToCart(int productId, {double quantity = 1}) async {
    if (!_validNumber(quantity, positive: true)) {
      throw ArgumentError('La cantidad del carrito debe ser positiva.');
    }
    final db = await database;
    await db.transaction((txn) async {
      final active = await txn.query('products',
          columns: ['id'],
          where: 'id = ? AND is_active = 1',
          whereArgs: [productId],
          limit: 1);
      if (active.isEmpty) throw StateError('Este artículo ya no está activo.');
      final current = await txn.query('cart',
          columns: ['quantity'],
          where: 'product_id = ?',
          whereArgs: [productId],
          limit: 1);
      if (current.isEmpty) {
        await txn
            .insert('cart', {'product_id': productId, 'quantity': quantity});
      } else {
        final oldQuantity = (current.first['quantity'] as num).toDouble();
        await txn.update('cart', {'quantity': oldQuantity + quantity},
            where: 'product_id = ?', whereArgs: [productId]);
      }
    });
    return getCartCount();
  }

  Future<void> updateCartQuantity(int productId, double quantity) async {
    if (!quantity.isFinite) throw ArgumentError('Cantidad inválida.');
    final db = await database;
    if (quantity <= 0) {
      await db.delete('cart', where: 'product_id = ?', whereArgs: [productId]);
    } else {
      await db.update('cart', {'quantity': quantity},
          where: 'product_id = ?', whereArgs: [productId]);
    }
  }

  // El badge indica productos distintos (número de filas), no unidades.
  Future<int> getCartCount() async {
    final result =
        await (await database).rawQuery('SELECT COUNT(*) AS count FROM cart');
    return (result.first['count'] as num).toInt();
  }

  Future<List<Map<String, dynamic>>> getCartItems() async =>
      (await database).rawQuery('''
        SELECT c.product_id, c.quantity, p.name, p.brand, p.unit, p.image_path,
          COALESCE((SELECT SUM(l.quantity_current) FROM lots l WHERE l.product_id = p.id AND l.quantity_current > 0),0) AS stock_total,
          COALESCE((SELECT SUM(l.quantity_current) FROM lots l WHERE l.product_id = p.id AND l.quantity_current > 0
            AND date(l.expiration_date) >= date('now','localtime')),0) AS stock_available
        FROM cart c JOIN products p ON p.id = c.product_id
        WHERE p.is_active = 1 ORDER BY p.name COLLATE NOCASE
      ''');

  Future<void> clearCart() async {
    await (await database).delete('cart');
  }

  // Un marcador por producto/fecha: los lotes de la misma fecha suman cantidad.
  Future<Map<String, List<Map<String, dynamic>>>> getCalendarEvents() async {
    final inventory = await getInventory();
    final lots = await (await database).rawQuery('''
      SELECT l.id AS lot_id, l.product_id, l.quantity_current, l.expiration_date,
        s.name AS store_name, p.name, p.brand, p.unit, p.image_path,
        p.min_stock, p.expiry_alert_days, c.name AS category_name
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
      final quantity = (lot['quantity_current'] as num).toDouble();
      final events =
          grouped.putIfAbsent(day, () => <int, Map<String, dynamic>>{});
      final existing = events[productId];
      if (existing == null) {
        events[productId] = {
          ...lot,
          'event_type': 'Caducidad',
          'lot_count': 1,
          'quantity_alert_total': quantity,
        };
      } else {
        existing['lot_count'] = (existing['lot_count'] as int) + 1;
        existing['quantity_alert_total'] =
            (existing['quantity_alert_total'] as num).toDouble() + quantity;
        if (existing['store_name'] != lot['store_name']) {
          existing['store_name'] = 'Varias tiendas';
        }
      }
    }
    final now = DateTime.now();
    final today =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    for (final product in inventory) {
      final stock = (product['stock_total'] as num).toDouble();
      final expired = (product['expired_stock'] as num).toDouble();
      final minimum = (product['min_stock'] as num).toDouble();
      final alertDays = (product['expiry_alert_days'] as num).toInt();
      final nextExpiry =
          DateTime.tryParse(product['next_expiry']?.toString() ?? '');
      final days = nextExpiry == null
          ? null
          : DateTime(nextExpiry.year, nextExpiry.month, nextExpiry.day)
              .difference(DateTime(now.year, now.month, now.day))
              .inDays;
      final type = expired > 0
          ? 'Caducado'
          : stock <= 0
              ? 'Sin existencia'
              : days != null && days >= 0 && days <= alertDays
                  ? 'Por caducar'
                  : stock <= minimum
                      ? 'Por agotarse'
                      : null;
      if (type == null) continue;
      final todayEvents =
          grouped.putIfAbsent(today, () => <int, Map<String, dynamic>>{});
      final id = (product['id'] as num).toInt();
      final existing = todayEvents[id];
      if (existing == null) {
        todayEvents[id] = {...product, 'event_type': type};
      } else if (type != 'Por caducar') {
        existing['event_type'] = '${existing['event_type']} · $type';
      }
    }
    return grouped.map((key, value) => MapEntry(key, value.values.toList()));
  }

  Future<List<Map<String, dynamic>>> getSpendingByStore() async =>
      (await database).rawQuery('''
        SELECT s.name, COALESCE(SUM(h.quantity * h.unit_cost),0) AS total
        FROM purchase_history h JOIN stores s ON s.id = h.store_id
        GROUP BY s.id, s.name ORDER BY total DESC
      ''');

  Future<int> countProducts() async {
    final result = await (await database)
        .rawQuery('SELECT COUNT(*) AS count FROM products WHERE is_active = 1');
    return (result.first['count'] as num).toInt();
  }
}
