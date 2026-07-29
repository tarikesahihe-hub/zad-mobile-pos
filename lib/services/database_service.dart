import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/customer.dart';
import '../models/supplier.dart';
import '../models/user.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'zad_pos.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Products table
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        barcode TEXT,
        qr_code TEXT,
        purchase_price REAL NOT NULL DEFAULT 0,
        sale_price REAL NOT NULL DEFAULT 0,
        quantity INTEGER NOT NULL DEFAULT 0,
        category TEXT,
        supplier TEXT,
        min_stock INTEGER DEFAULT 0,
        expiry_date TEXT,
        batch_number TEXT,
        image_path TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Sales table
    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT NOT NULL UNIQUE,
        date TEXT NOT NULL,
        subtotal REAL NOT NULL DEFAULT 0,
        discount REAL NOT NULL DEFAULT 0,
        tax REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL DEFAULT 0,
        payment_method TEXT DEFAULT 'cash',
        customer_id INTEGER,
        customer_name TEXT,
        notes TEXT,
        status TEXT DEFAULT 'completed',
        device_id TEXT,
        synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // Sale items table
    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        unit_price REAL NOT NULL DEFAULT 0,
        quantity INTEGER NOT NULL DEFAULT 0,
        discount REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE
      )
    ''');

    // Customers table
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        balance REAL NOT NULL DEFAULT 0,
        loyalty_points INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // Suppliers table
    await db.execute('''
      CREATE TABLE suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        balance REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // Users table
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        full_name TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'seller',
        pin TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    // Permissions table
    await db.execute('''
      CREATE TABLE permissions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        role TEXT NOT NULL,
        permission TEXT NOT NULL,
        granted INTEGER DEFAULT 1,
        UNIQUE(role, permission)
      )
    ''');

    // Inventory movements
    await db.execute('''
      CREATE TABLE inventory_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        reason TEXT,
        date TEXT NOT NULL,
        user_id INTEGER,
        notes TEXT
      )
    ''');

    // Purchase orders
    await db.execute('''
      CREATE TABLE purchase_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_id INTEGER,
        supplier_name TEXT,
        date TEXT NOT NULL,
        total REAL NOT NULL DEFAULT 0,
        status TEXT DEFAULT 'pending',
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Purchase order items
    await db.execute('''
      CREATE TABLE purchase_order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        product_id INTEGER,
        product_name TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 0,
        unit_price REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (order_id) REFERENCES purchase_orders (id) ON DELETE CASCADE
      )
    ''');

    // Settings
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    // License
    await db.execute('''
      CREATE TABLE license (
        id INTEGER PRIMARY KEY,
        license_key TEXT NOT NULL,
        store_name TEXT,
        store_id TEXT NOT NULL,
        activated_at TEXT,
        expires_at TEXT,
        max_devices INTEGER DEFAULT 1,
        is_active INTEGER DEFAULT 1
      )
    ''');

    // Devices
    await db.execute('''
      CREATE TABLE devices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id TEXT NOT NULL UNIQUE,
        device_name TEXT,
        last_sync TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    // Sync log
    await db.execute('''
      CREATE TABLE sync_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_id INTEGER NOT NULL,
        action TEXT NOT NULL,
        device_id TEXT,
        synced_at TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Insert default admin user
    await db.insert('users', {
      'username': 'admin',
      'full_name': 'مدير النظام',
      'role': 'admin',
      'pin': '1234',
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });

    // Insert default permissions
    await _insertDefaultPermissions(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE sales ADD COLUMN device_id TEXT');
      await db.execute('ALTER TABLE sales ADD COLUMN synced INTEGER DEFAULT 0');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS permissions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          role TEXT NOT NULL,
          permission TEXT NOT NULL,
          granted INTEGER DEFAULT 1,
          UNIQUE(role, permission)
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS license (
          id INTEGER PRIMARY KEY,
          license_key TEXT NOT NULL,
          store_name TEXT,
          store_id TEXT NOT NULL,
          activated_at TEXT,
          expires_at TEXT,
          max_devices INTEGER DEFAULT 1,
          is_active INTEGER DEFAULT 1
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS devices (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          device_id TEXT NOT NULL UNIQUE,
          device_name TEXT,
          last_sync TEXT,
          is_active INTEGER DEFAULT 1,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_log (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          table_name TEXT NOT NULL,
          record_id INTEGER NOT NULL,
          action TEXT NOT NULL,
          device_id TEXT,
          synced_at TEXT,
          created_at TEXT NOT NULL
        )
      ''');
      await _insertDefaultPermissions(db);
    }
  }

  Future<void> _insertDefaultPermissions(Database db) async {
    final permissions = {
      'admin': [
        'view_dashboard', 'view_sales', 'create_sale', 'edit_sale', 'delete_sale',
        'view_products', 'add_product', 'edit_product', 'delete_product',
        'view_inventory', 'edit_stock', 'stock_transfer', 'stock_count',
        'view_customers', 'add_customer', 'edit_customer', 'delete_customer',
        'view_suppliers', 'add_supplier', 'edit_supplier', 'delete_supplier',
        'view_reports', 'export_reports', 'view_profit',
        'view_users', 'add_user', 'edit_user', 'delete_user', 'manage_permissions',
        'view_settings', 'edit_settings', 'manage_printer', 'manage_backup',
        'view_license', 'manage_license', 'sync_data', 'cloud_sync',
      ],
      'manager': [
        'view_dashboard', 'view_sales', 'create_sale', 'edit_sale',
        'view_products', 'add_product', 'edit_product',
        'view_inventory', 'edit_stock', 'stock_transfer', 'stock_count',
        'view_customers', 'add_customer', 'edit_customer',
        'view_suppliers', 'add_supplier', 'edit_supplier',
        'view_reports', 'export_reports', 'view_profit',
        'view_users', 'add_user', 'edit_user',
        'view_settings', 'edit_settings', 'manage_printer', 'manage_backup',
        'sync_data',
      ],
      'seller': [
        'view_dashboard', 'view_sales', 'create_sale',
        'view_products',
        'view_customers', 'add_customer',
        'view_settings',
      ],
      'accountant': [
        'view_dashboard', 'view_sales', 'view_reports', 'export_reports', 'view_profit',
        'view_customers', 'view_suppliers',
        'view_products',
        'view_settings',
      ],
      'stock': [
        'view_inventory', 'edit_stock', 'stock_transfer', 'stock_count',
        'view_products', 'add_product', 'edit_product',
        'view_suppliers',
        'view_settings',
      ],
    };

    for (final entry in permissions.entries) {
      for (final perm in entry.value) {
        await db.insert('permissions', {
          'role': entry.key,
          'permission': perm,
          'granted': 1,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
  }

  // ========== PERMISSIONS ==========
  Future<List<String>> getRolePermissions(String role) async {
    final db = await database;
    final maps = await db.query(
      'permissions',
      columns: ['permission'],
      where: 'role = ? AND granted = 1',
      whereArgs: [role],
    );
    return maps.map((m) => m['permission'] as String).toList();
  }

  Future<void> updateRolePermission(String role, String permission, bool granted) async {
    final db = await database;
    await db.insert(
      'permissions',
      {'role': role, 'permission': permission, 'granted': granted ? 1 : 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, List<String>>> getAllPermissions() async {
    final db = await database;
    final maps = await db.query('permissions', where: 'granted = 1');
    final result = <String, List<String>>{};
    for (final map in maps) {
      final role = map['role'] as String;
      final perm = map['permission'] as String;
      result.putIfAbsent(role, () => []).add(perm);
    }
    return result;
  }

  // ========== PRODUCTS ==========
  Future<int> insertProduct(Product product) async {
    final db = await database;
    return await db.insert('products', product.toMap());
  }

  Future<int> updateProduct(Product product) async {
    final db = await database;
    return await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Product>> getAllProducts() async {
    final db = await database;
    final maps = await db.query('products', orderBy: 'name ASC');
    return maps.map((m) => Product.fromMap(m)).toList();
  }

  Future<Product?> getProductById(int id) async {
    final db = await database;
    final maps = await db.query('products', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return Product.fromMap(maps.first);
    return null;
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await database;
    final maps = await db.query('products', where: 'barcode = ?', whereArgs: [barcode]);
    if (maps.isNotEmpty) return Product.fromMap(maps.first);
    return null;
  }

  Future<List<Product>> searchProducts(String query) async {
    final db = await database;
    final maps = await db.query(
      'products',
      where: 'name LIKE ? OR barcode LIKE ? OR category LIKE ? OR supplier LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%', '%$query%'],
      orderBy: 'name ASC',
    );
    return maps.map((m) => Product.fromMap(m)).toList();
  }

  Future<List<Product>> getLowStockProducts() async {
    final db = await database;
    final maps = await db.query(
      'products',
      where: 'quantity <= min_stock AND min_stock > 0',
    );
    return maps.map((m) => Product.fromMap(m)).toList();
  }

  // ========== SALES ==========
  Future<int> insertSale(Sale sale) async {
    final db = await database;
    return await db.insert('sales', sale.toMap());
  }

  Future<int> insertSaleItem(SaleItem item) async {
    final db = await database;
    return await db.insert('sale_items', item.toMap());
  }

  Future<List<Sale>> getAllSales({String? startDate, String? endDate}) async {
    final db = await database;
    String? where;
    List<dynamic>? whereArgs;
    if (startDate != null && endDate != null) {
      where = 'date BETWEEN ? AND ?';
      whereArgs = [startDate, endDate];
    }
    final maps = await db.query('sales', where: where, whereArgs: whereArgs, orderBy: 'date DESC');
    return maps.map((m) => Sale.fromMap(m)).toList();
  }

  Future<List<Sale>> getUnsyncedSales() async {
    final db = await database;
    final maps = await db.query('sales', where: 'synced = 0 OR synced IS NULL', orderBy: 'date DESC');
    return maps.map((m) => Sale.fromMap(m)).toList();
  }

  Future<void> markSaleSynced(int saleId) async {
    final db = await database;
    await db.update('sales', {'synced': 1}, where: 'id = ?', whereArgs: [saleId]);
  }

  Future<List<SaleItem>> getSaleItems(int saleId) async {
    final db = await database;
    final maps = await db.query('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
    return maps.map((m) => SaleItem.fromMap(m)).toList();
  }

  Future<Sale?> getSaleById(int id) async {
    final db = await database;
    final maps = await db.query('sales', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      final sale = Sale.fromMap(maps.first);
      final items = await getSaleItems(sale.id!);
      return Sale(
        id: sale.id,
        invoiceNumber: sale.invoiceNumber,
        date: sale.date,
        subtotal: sale.subtotal,
        discount: sale.discount,
        tax: sale.tax,
        total: sale.total,
        paymentMethod: sale.paymentMethod,
        customerId: sale.customerId,
        customerName: sale.customerName,
        notes: sale.notes,
        status: sale.status,
        items: items,
        createdAt: sale.createdAt,
      );
    }
    return null;
  }

  Future<void> cancelSale(int saleId) async {
    final db = await database;
    await db.update('sales', {'status': 'cancelled'}, where: 'id = ?', whereArgs: [saleId]);
  }

  // ========== CUSTOMERS ==========
  Future<int> insertCustomer(Customer customer) async {
    final db = await database;
    return await db.insert('customers', customer.toMap());
  }

  Future<int> updateCustomer(Customer customer) async {
    final db = await database;
    return await db.update('customers', customer.toMap(), where: 'id = ?', whereArgs: [customer.id]);
  }

  Future<int> deleteCustomer(int id) async {
    final db = await database;
    return await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Customer>> getAllCustomers() async {
    final db = await database;
    final maps = await db.query('customers', orderBy: 'name ASC');
    return maps.map((m) => Customer.fromMap(m)).toList();
  }

  Future<Customer?> getCustomerById(int id) async {
    final db = await database;
    final maps = await db.query('customers', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return Customer.fromMap(maps.first);
    return null;
  }

  // ========== SUPPLIERS ==========
  Future<int> insertSupplier(Supplier supplier) async {
    final db = await database;
    return await db.insert('suppliers', supplier.toMap());
  }

  Future<int> updateSupplier(Supplier supplier) async {
    final db = await database;
    return await db.update('suppliers', supplier.toMap(), where: 'id = ?', whereArgs: [supplier.id]);
  }

  Future<int> deleteSupplier(int id) async {
    final db = await database;
    return await db.delete('suppliers', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Supplier>> getAllSuppliers() async {
    final db = await database;
    final maps = await db.query('suppliers', orderBy: 'name ASC');
    return maps.map((m) => Supplier.fromMap(m)).toList();
  }

  // ========== USERS ==========
  Future<int> insertUser(User user) async {
    final db = await database;
    return await db.insert('users', user.toMap());
  }

  Future<int> updateUser(User user) async {
    final db = await database;
    return await db.update('users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);
  }

  Future<int> deleteUser(int id) async {
    final db = await database;
    return await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<User>> getAllUsers() async {
    final db = await database;
    final maps = await db.query('users', orderBy: 'full_name ASC');
    return maps.map((m) => User.fromMap(m)).toList();
  }

  Future<User?> getUserByUsername(String username) async {
    final db = await database;
    final maps = await db.query('users', where: 'username = ?', whereArgs: [username]);
    if (maps.isNotEmpty) return User.fromMap(maps.first);
    return null;
  }

  // ========== LICENSE ==========
  Future<Map<String, dynamic>?> getLicense() async {
    final db = await database;
    final maps = await db.query('license', limit: 1);
    if (maps.isNotEmpty) return maps.first;
    return null;
  }

  Future<void> saveLicense(Map<String, dynamic> license) async {
    final db = await database;
    await db.delete('license');
    await db.insert('license', license);
  }

  Future<bool> isLicenseValid() async {
    final license = await getLicense();
    if (license == null) return false;
    if (license['is_active'] != 1) return false;
    if (license['expires_at'] != null) {
      final expires = DateTime.parse(license['expires_at'] as String);
      if (expires.isBefore(DateTime.now())) return false;
    }
    return true;
  }

  // ========== DEVICES ==========
  Future<int> insertDevice(Map<String, dynamic> device) async {
    final db = await database;
    return await db.insert('devices', device, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getAllDevices() async {
    final db = await database;
    return await db.query('devices', orderBy: 'created_at DESC');
  }

  Future<int> getDeviceCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM devices WHERE is_active = 1');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ========== SYNC LOG ==========
  Future<void> addSyncLog(String table, int recordId, String action, {String? deviceId}) async {
    final db = await database;
    await db.insert('sync_log', {
      'table_name': table,
      'record_id': recordId,
      'action': action,
      'device_id': deviceId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getSyncLog() async {
    final db = await database;
    return await db.query('sync_log', orderBy: 'created_at DESC', limit: 100);
  }

  // ========== SETTINGS ==========
  Future<String?> getSetting(String key) async {
    final db = await database;
    final maps = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (maps.isNotEmpty) return maps.first['value'] as String?;
    return null;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ========== STATS ==========
  Future<List<Map<String, dynamic>>> getStockOutForecast({int days = 30}) async {
    final db = await database;
    final start = DateTime.now().subtract(Duration(days: days)).toIso8601String();

    final soldRows = await db.rawQuery('''
      SELECT si.product_id, SUM(si.quantity) as sold_qty
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      WHERE s.date >= ? AND s.status = 'completed'
      GROUP BY si.product_id
      HAVING sold_qty > 0
    ''', [start]);

    if (soldRows.isEmpty) return [];

    final results = <Map<String, dynamic>>[];
    for (final row in soldRows) {
      final productId = row['product_id'] as int;
      final soldQty = (row['sold_qty'] as num).toDouble();
      final product = await getProductById(productId);
      if (product == null || product.quantity <= 0) continue;

      final dailyRate = soldQty / days;
      if (dailyRate <= 0) continue;
      final daysRemaining = product.quantity / dailyRate;

      results.add({
        'name': product.name,
        'quantity': product.quantity,
        'daysRemaining': daysRemaining,
      });
    }

    results.sort((a, b) => (a['daysRemaining'] as double).compareTo(b['daysRemaining'] as double));
    return results;
  }

  Future<Map<String, dynamic>> getTodayStats() async {
    final db = await database;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59).toIso8601String();

    final saleResult = await db.rawQuery('''
      SELECT COUNT(*) as count, COALESCE(SUM(total), 0) as total 
      FROM sales 
      WHERE date BETWEEN ? AND ? AND status = 'completed'
    ''', [startOfDay, endOfDay]);

    final profitResult = await db.rawQuery('''
      SELECT COALESCE(SUM((si.unit_price - p.purchase_price) * si.quantity - si.discount), 0) as profit
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      JOIN products p ON si.product_id = p.id
      WHERE s.date BETWEEN ? AND ? AND s.status = 'completed'
    ''', [startOfDay, endOfDay]);

    return {
      'salesCount': saleResult.first['count'] ?? 0,
      'salesTotal': (saleResult.first['total'] as num?)?.toDouble() ?? 0.0,
      'profit': (profitResult.first['profit'] as num?)?.toDouble() ?? 0.0,
    };
  }

  Future<Map<String, dynamic>> getDashboardStats() async {
    final db = await database;
    final productCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM products'),
    ) ?? 0;
    final customerCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM customers'),
    ) ?? 0;
    final lowStockCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM products WHERE quantity <= min_stock AND min_stock > 0'),
    ) ?? 0;

    final todayStats = await getTodayStats();

    return {
      'productCount': productCount,
      'customerCount': customerCount,
      'lowStockCount': lowStockCount,
      ...todayStats,
    };
  }

  Future<Map<String, dynamic>> getDetailedReport(String period) async {
    final db = await database;
    DateTime start;
    DateTime end = DateTime.now();

    switch (period) {
      case 'today':
        start = DateTime(end.year, end.month, end.day);
        end = DateTime(end.year, end.month, end.day, 23, 59, 59);
        break;
      case 'week':
        start = end.subtract(Duration(days: end.weekday % 7));
        break;
      case 'month':
        start = DateTime(end.year, end.month, 1);
        break;
      case 'year':
        start = DateTime(end.year, 1, 1);
        break;
      default:
        start = DateTime(end.year, end.month, end.day);
    }

    final salesResult = await db.rawQuery('''
      SELECT COUNT(*) as count, COALESCE(SUM(total), 0) as total,
             COALESCE(SUM(discount), 0) as discount,
             COALESCE(SUM(tax), 0) as tax
      FROM sales 
      WHERE date BETWEEN ? AND ? AND status = 'completed'
    ''', [start.toIso8601String(), end.toIso8601String()]);

    final profitResult = await db.rawQuery('''
      SELECT COALESCE(SUM((si.unit_price - p.purchase_price) * si.quantity - si.discount), 0) as profit
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      JOIN products p ON si.product_id = p.id
      WHERE s.date BETWEEN ? AND ? AND s.status = 'completed'
    ''', [start.toIso8601String(), end.toIso8601String()]);

    final topProducts = await db.rawQuery('''
      SELECT si.product_name, SUM(si.quantity) as qty, SUM(si.total) as revenue
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      WHERE s.date BETWEEN ? AND ? AND s.status = 'completed'
      GROUP BY si.product_id, si.product_name
      ORDER BY qty DESC
      LIMIT 10
    ''', [start.toIso8601String(), end.toIso8601String()]);

    final paymentMethods = await db.rawQuery('''
      SELECT payment_method, COUNT(*) as count, SUM(total) as total
      FROM sales
      WHERE date BETWEEN ? AND ? AND status = 'completed'
      GROUP BY payment_method
    ''', [start.toIso8601String(), end.toIso8601String()]);

    return {
      'period': period,
      'salesCount': salesResult.first['count'] ?? 0,
      'salesTotal': (salesResult.first['total'] as num?)?.toDouble() ?? 0.0,
      'discountTotal': (salesResult.first['discount'] as num?)?.toDouble() ?? 0.0,
      'taxTotal': (salesResult.first['tax'] as num?)?.toDouble() ?? 0.0,
      'profit': (profitResult.first['profit'] as num?)?.toDouble() ?? 0.0,
      'topProducts': topProducts,
      'paymentMethods': paymentMethods,
    };
  }

  // ========== BACKUP / EXPORT ==========
  Future<Map<String, List<Map<String, dynamic>>>> exportAllData() async {
    final db = await database;
    return {
      'products': await db.query('products'),
      'sales': await db.query('sales'),
      'sale_items': await db.query('sale_items'),
      'customers': await db.query('customers'),
      'suppliers': await db.query('suppliers'),
      'users': await db.query('users'),
      'settings': await db.query('settings'),
      'license': await db.query('license'),
    };
  }

  Future<void> importData(Map<String, List<Map<String, dynamic>>> data) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final entry in data.entries) {
        final table = entry.key;
        final records = entry.value;
        if (records.isEmpty) continue;

        // Clear existing data except users and license
        if (table != 'users' && table != 'license') {
          await txn.delete(table);
        }

        for (final record in records) {
          await txn.insert(table, record, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }

  // ========== CLOSE ==========
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
