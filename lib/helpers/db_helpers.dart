// lib/helpers/db_helpers.dart
import 'dart:io';
import 'package:fouad_stock/enum/filter_enums.dart';
import 'package:fouad_stock/model/product_model.dart';
import 'package:fouad_stock/model/invoice_model.dart';
import 'package:fouad_stock/model/invoice_item_model.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';

class DatabaseHelper {
  static const _databaseName = "MedicalStore.db";
  // --- MODIFIED: Incremented database version for migration ---
  static const _databaseVersion = 6; 

  static const columnId = 'id';
  static const tableProducts = 'products';
  static const columnName = 'name';
  static const columnProductCode = 'productCode';
  static const columnCategory = 'category';
  static const columnDescription = 'description';
  static const columnPurchasePrice = 'purchasePrice';
  static const columnSellingPrice = 'sellingPrice';
  static const columnQuantity = 'quantity';
  static const columnUnitOfMeasure = 'unitOfMeasure';
  static const columnExpiryDate = 'expiryDate';
  static const columnLowStockThreshold = 'lowStockThreshold';
  static const columnBarcode = 'barcode';
  static const columnAddedDate = 'addedDate';
  static const columnLastUpdated = 'lastUpdated';

  static const tableInvoices = 'invoices';
  static const columnInvoiceIdDb = 'id';
  static const columnInvoiceNumber = 'invoiceNumber';
  static const columnInvoiceDate = 'date';
  static const columnClientName = 'clientName';
  static const columnSubtotal = 'subtotal';
  static const columnTaxRatePercentage = 'taxRatePercentage';
  static const columnTaxAmount = 'taxAmount';
  static const columnDiscountAmount = 'discountAmount';
  static const columnGrandTotal = 'grandTotal';
  static const columnInvoiceType = 'type';
  static const columnInvoiceNotes = 'notes';
  static const columnPaymentStatus = 'paymentStatus';
  static const columnAmountPaid = 'amountPaid';
  static const columnInvoiceLastUpdated = 'lastUpdated';

  static const tableInvoiceItems = 'invoice_items';
  static const columnInvoiceItemIdDb = 'id';
  static const columnInvoiceIdFk = 'invoiceId';
  static const columnIIProductId = 'productId';
  static const columnIIProductName = 'productName';
  static const columnIIQuantity = 'quantity';
  static const columnIIUnitPrice = 'unitPrice'; // This is the selling price for the item
  // --- NEW COLUMN for profit calculation ---
  static const columnIIPurchasePrice = 'purchasePrice'; // The cost of the item at the time of sale
  static const columnIIItemTotal = 'itemTotal';

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static Database? _database;

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory directory = Platform.isWindows || Platform.isLinux || Platform.isMacOS 
        ? await getApplicationSupportDirectory() 
        : await getApplicationDocumentsDirectory();

    String path = join(directory.path, _databaseName);
    print("[DatabaseHelper] DB path: $path");

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      databaseFactory = databaseFactoryFfi;
    }

    return await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  static Future<void> closeDatabaseInstance() async {
    if (DatabaseHelper._database != null && DatabaseHelper._database!.isOpen) {
      await DatabaseHelper._database!.close();
      DatabaseHelper._database = null;
    }
  }

  Future _onCreate(Database db, int version) async {
    print("[DatabaseHelper] _onCreate: Creating tables for version $version");
    await db.execute('''
      CREATE TABLE $tableProducts (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT, $columnName TEXT NOT NULL, $columnProductCode TEXT, 
        $columnCategory TEXT NOT NULL, $columnDescription TEXT, $columnPurchasePrice REAL NOT NULL, 
        $columnSellingPrice REAL NOT NULL, $columnQuantity INTEGER NOT NULL, 
        $columnUnitOfMeasure TEXT NOT NULL, $columnExpiryDate TEXT NOT NULL, 
        $columnLowStockThreshold INTEGER DEFAULT 10, $columnBarcode TEXT, 
        $columnAddedDate TEXT, $columnLastUpdated TEXT
      )''');
    await db.execute('''
      CREATE TABLE $tableInvoices (
        $columnInvoiceIdDb INTEGER PRIMARY KEY AUTOINCREMENT, $columnInvoiceNumber TEXT NOT NULL UNIQUE,
        $columnInvoiceDate TEXT NOT NULL, $columnClientName TEXT, $columnSubtotal REAL NOT NULL,
        $columnTaxRatePercentage REAL DEFAULT 0.0, $columnTaxAmount REAL DEFAULT 0.0,
        $columnDiscountAmount REAL DEFAULT 0.0, $columnGrandTotal REAL NOT NULL,
        $columnInvoiceType TEXT NOT NULL, $columnInvoiceNotes TEXT,
        $columnPaymentStatus TEXT NOT NULL DEFAULT '${PaymentStatus.unpaid.toString()}', 
        $columnAmountPaid REAL NOT NULL DEFAULT 0.0, $columnInvoiceLastUpdated TEXT
      )''');
    await db.execute('''
      CREATE TABLE $tableInvoiceItems (
        $columnInvoiceItemIdDb INTEGER PRIMARY KEY AUTOINCREMENT, $columnInvoiceIdFk INTEGER NOT NULL,
        $columnIIProductId INTEGER NOT NULL, $columnIIProductName TEXT NOT NULL,
        $columnIIQuantity INTEGER NOT NULL, $columnIIUnitPrice REAL NOT NULL, 
        $columnIIPurchasePrice REAL NOT NULL DEFAULT 0.0,
        $columnIIItemTotal REAL NOT NULL,
        FOREIGN KEY ($columnInvoiceIdFk) REFERENCES $tableInvoices ($columnInvoiceIdDb) ON DELETE CASCADE,
        FOREIGN KEY ($columnIIProductId) REFERENCES $tableProducts ($columnId) ON DELETE RESTRICT
      )''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print("[DatabaseHelper] _onUpgrade: Upgrading from $oldVersion to $newVersion");
    if (oldVersion < 2) await _createInvoiceTablesV2(db);
    if (oldVersion < 3) await _addPaymentFieldsToInvoicesV3(db);
    if (oldVersion < 4) await _addFieldsToProductsV4(db);
    if (oldVersion < 5) {
      try {
        await db.execute("ALTER TABLE $tableInvoices ADD COLUMN $columnInvoiceLastUpdated TEXT");
        print("[DatabaseHelper] V5 Upgrade: Added $columnInvoiceLastUpdated to $tableInvoices");
      } catch (e) { print("[DatabaseHelper] Error V5: $e"); }
    }
    if (oldVersion < 6) {
      try {
        await db.execute("ALTER TABLE $tableInvoiceItems ADD COLUMN $columnIIPurchasePrice REAL NOT NULL DEFAULT 0.0");
        print("[DatabaseHelper] V6 Upgrade: Added $columnIIPurchasePrice to $tableInvoiceItems");
      } catch (e) { print("[DatabaseHelper] Error V6: $e"); }
    }
  }

  Future<void> _createInvoiceTablesV2(Database db) async { print("[DBHelper] Running V2 Migrations (_createInvoiceTablesV2)"); }
  Future<void> _addPaymentFieldsToInvoicesV3(Database db) async { print("[DBHelper] Running V3 Migrations (_addPaymentFieldsToInvoicesV3)"); }
  Future<void> _addFieldsToProductsV4(Database db) async { print("[DBHelper] Running V4 Migrations (_addFieldsToProductsV4)"); }

  Future<int> insertProduct(Product product, {Transaction? txn}) async {
    final dbOrTxn = txn ?? await instance.database;
    return await dbOrTxn.insert(tableProducts, product.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Product?> getProductById(int id, {Transaction? txn}) async {
    final dbOrTxn = txn ?? await instance.database;
    final List<Map<String, dynamic>> maps = await dbOrTxn.query(tableProducts, where: '$columnId = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return Product.fromMap(maps.first);
    return null;
  }

  Future<int> updateProduct(Product product, {Transaction? txn}) async {
    final dbOrTxn = txn ?? await instance.database;
    return await dbOrTxn.update(tableProducts, product.toMap(), where: '$columnId = ?', whereArgs: [product.id]);
  }

  Future<int> deleteProduct(int id) async {
    final db = await instance.database;
    return await db.delete(tableProducts, where: '$columnId = ?', whereArgs: [id]);
  }

  Future<List<Product>> getAllProducts() async {
    return await getProductsFiltered(filter: ProductListFilter.none);
  }

  Future<List<Product>> getProductsFiltered({ProductListFilter? filter}) async {
    final db = await instance.database;
    String? whereClause;
    List<dynamic>? whereArgs;
    const int defaultLowStockVal = 10;
    switch (filter) {
      case ProductListFilter.lowStock:
        whereClause = '$columnQuantity <= COALESCE($columnLowStockThreshold, ?) AND $columnQuantity > 0'; whereArgs = [defaultLowStockVal]; break;
      case ProductListFilter.outOfStock:
        whereClause = '$columnQuantity <= 0'; break;
      case ProductListFilter.expired:
        final String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
        whereClause = "DATE($columnExpiryDate) < ?"; whereArgs = [todayDate]; break;
      case ProductListFilter.nearingExpiry:
        final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final String futureDate = DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 30)));
        whereClause = "DATE($columnExpiryDate) >= ? AND DATE($columnExpiryDate) < ?"; whereArgs = [today, futureDate]; break;
      case ProductListFilter.none: default: break;
    }
    final List<Map<String, dynamic>> maps = await db.query(tableProducts, where: whereClause, whereArgs: whereArgs, orderBy: '$columnName ASC');
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  Future<List<Product>> searchProducts(String keyword, {ProductListFilter? filter}) async {
    final db = await instance.database;
    List<String> whereClauses = [];
    List<dynamic> whereArgs = [];
    if (keyword.isNotEmpty) {
      String queryArg = '%${keyword.toLowerCase()}%';
      whereClauses.add('($columnName LIKE ? OR $columnCategory LIKE ? OR $columnProductCode LIKE ? OR $columnBarcode LIKE ?)');
      whereArgs.addAll([queryArg, queryArg, queryArg, queryArg]);
    }
    const int defaultLowStockVal = 10;
    switch (filter) {
      case ProductListFilter.lowStock:
        whereClauses.add('$columnQuantity <= COALESCE($columnLowStockThreshold, ?) AND $columnQuantity > 0'); whereArgs.add(defaultLowStockVal); break;
      case ProductListFilter.outOfStock: whereClauses.add('$columnQuantity <= 0'); break;
      case ProductListFilter.expired:
        final String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
        whereClauses.add("DATE($columnExpiryDate) < ?"); whereArgs.add(todayDate); break;
      case ProductListFilter.nearingExpiry:
        final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final String futureDate = DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 30)));
        whereClauses.add("DATE($columnExpiryDate) >= ? AND DATE($columnExpiryDate) < ?"); whereArgs.addAll([today, futureDate]); break;
      case ProductListFilter.none: default: break;
    }
    String? finalWhereClause = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;
    final List<Map<String, dynamic>> maps = await db.query(tableProducts, where: finalWhereClause, whereArgs: whereArgs.isNotEmpty ? whereArgs : null, orderBy: '$columnName ASC');
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  Future<int> insertInvoiceWithItems(Invoice invoice, List<InvoiceItem> items, {Transaction? txnPassed}) async {
    final dbForTransaction = txnPassed ?? await instance.database;
    Future<int> performInsert(Transaction txn) async {
      Map<String, dynamic> invoiceMap = invoice.toMap();
      invoiceMap.remove('id');
      invoiceMap[columnInvoiceLastUpdated] = DateTime.now().toIso8601String();
      int invoiceId = await txn.insert(tableInvoices, invoiceMap);
      for (var item in items) {
        item.invoiceId = invoiceId;
        Map<String, dynamic> itemMap = item.toMap();
        itemMap.remove('id');
        await txn.insert(tableInvoiceItems, itemMap);
      }
      return invoiceId;
    }

    if (txnPassed != null) {
      return await performInsert(txnPassed);
    } else {
      return await (dbForTransaction as Database).transaction((txn) async {
        return await performInsert(txn);
      });
    }
  }

  Future<List<InvoiceItem>> getInvoiceItems(int invoiceId) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(tableInvoiceItems, where: '$columnInvoiceIdFk = ?', whereArgs: [invoiceId]);
    return List.generate(maps.length, (i) => InvoiceItem.fromMap(maps[i]));
  }

  Future<List<Invoice>> getAllInvoices({InvoiceType? type, InvoiceListFilter? filter}) async {
    final db = await instance.database;
    String? whereClause;
    List<dynamic>? whereArgs;
    switch (filter) {
      case InvoiceListFilter.todaySales:
        final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        whereClause = '$columnInvoiceType = ? AND DATE($columnInvoiceDate) = ?'; whereArgs = [InvoiceType.sale.toString(), today]; break;
      case InvoiceListFilter.todayPurchases:
        final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        whereClause = '$columnInvoiceType = ? AND DATE($columnInvoiceDate) = ?'; whereArgs = [InvoiceType.purchase.toString(), today]; break;
      case InvoiceListFilter.unpaidSales:
        whereClause = '$columnInvoiceType = ? AND $columnPaymentStatus != ?'; whereArgs = [InvoiceType.sale.toString(), PaymentStatus.paid.toString()]; break;
      case InvoiceListFilter.none: default:
        if (type != null) { whereClause = '$columnInvoiceType = ?'; whereArgs = [type.toString()]; } break;
    }
    final List<Map<String, dynamic>> maps = await db.query(tableInvoices, where: whereClause, whereArgs: whereArgs, orderBy: '$columnInvoiceDate DESC');
    List<Invoice> invoices = [];
    for (var map in maps) {
      Invoice invoice = Invoice.fromMap(map);
      if (invoice.id != null) invoice.items = await getInvoiceItems(invoice.id!);
      invoices.add(invoice);
    }
    return invoices;
  }

  Future<Invoice?> getInvoiceById(int id, {Transaction? txn}) async {
    final dbOrTxn = txn ?? await instance.database;
    final List<Map<String, dynamic>> maps = await dbOrTxn.query(tableInvoices, where: '$columnInvoiceIdDb = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      Invoice invoice = Invoice.fromMap(maps.first);
      if (invoice.id != null) invoice.items = await getInvoiceItems(invoice.id!); 
      return invoice;
    }
    return null;
  }
  
  Future<void> deleteInvoiceAndItems(int invoiceId, {Transaction? txn}) async {
    final dbOrTxn = txn ?? await instance.database;
    await dbOrTxn.delete(
      tableInvoices,
      where: '$columnInvoiceIdDb = ?',
      whereArgs: [invoiceId],
    );
    print("[DatabaseHelper] Deleted invoice with ID: $invoiceId and its items (cascade).");
  }

  Future<int> updateInvoicePaymentDetails(int invoiceId, PaymentStatus status, double amountPaid, {Transaction? txn}) async {
    final dbOrTxn = txn ?? await instance.database;
    return await dbOrTxn.update(tableInvoices, {
        columnPaymentStatus: status.toString(), columnAmountPaid: amountPaid,
        columnInvoiceLastUpdated: DateTime.now().toIso8601String()
      }, where: '$columnInvoiceIdDb = ?', whereArgs: [invoiceId]);
  }
  
  Future<List<Invoice>> getTodaysSalesInvoices() async {
    return await getAllInvoices(filter: InvoiceListFilter.todaySales);
  }
  Future<List<Invoice>> getTodaysPurchasesInvoices() async {
    return await getAllInvoices(filter: InvoiceListFilter.todayPurchases);
  }
  Future<List<Invoice>> getUnpaidSalesInvoices() async {
    return await getAllInvoices(filter: InvoiceListFilter.unpaidSales);
  }

  Future<List<Invoice>> getInvoicesByDateRangeAndType(DateTime startDate, DateTime endDate, InvoiceType type) async {
    final db = await instance.database;
    final String startDateString = DateFormat('yyyy-MM-dd').format(startDate);
    final String endOfDayString = DateFormat('yyyy-MM-dd').format(endDate);
    final maps = await db.query(tableInvoices,
      where: '$columnInvoiceType = ? AND DATE($columnInvoiceDate) BETWEEN ? AND ?',
      whereArgs: [type.toString(), startDateString, endOfDayString],
      orderBy: '$columnInvoiceDate DESC');
    List<Invoice> invoices = [];
    for (var map in maps) {
      Invoice invoice = Invoice.fromMap(map);
      if (invoice.id != null) invoice.items = await getInvoiceItems(invoice.id!);
      invoices.add(invoice);
    }
    return invoices;
  }

  Future<String> getNextInvoiceNumber(InvoiceType type) async {
    final db = await instance.database;
    String prefix = type == InvoiceType.sale ? "SALE-" : "PUR-";
    final result = await db.rawQuery(
      "SELECT MAX(CAST(REPLACE($columnInvoiceNumber, ?, '') AS INTEGER)) as max_num FROM $tableInvoices WHERE $columnInvoiceNumber LIKE ?",
      [prefix, '$prefix%'],
    );
    int nextNum = 1;
    if (result.isNotEmpty && result.first['max_num'] != null) {
      nextNum = (result.first['max_num'] as int) + 1;
    }
    return "$prefix${nextNum.toString().padLeft(5, '0')}";
  }

  Future<int> updateInvoiceRecord(Invoice invoice, {Transaction? txn}) async {
    final dbOrTxn = txn ?? await instance.database;
    Map<String, dynamic> invoiceMap = invoice.toMap();
    invoiceMap[columnInvoiceLastUpdated] = DateTime.now().toIso8601String(); 
    return await dbOrTxn.update(tableInvoices, invoiceMap, where: '$columnInvoiceIdDb = ?', whereArgs: [invoice.id]);
  }
}



// // lib/helpers/db_helpers.dart
// import 'dart:io';
// import 'package:fouad_stock/enum/filter_enums.dart';
// import 'package:fouad_stock/model/product_model.dart';
// import 'package:fouad_stock/model/invoice_model.dart';
// import 'package:fouad_stock/model/invoice_item_model.dart';
// import 'package:path_provider/path_provider.dart';
// // Import the new package for desktop support
// import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// import 'package:path/path.dart';
// import 'package:intl/intl.dart';

// class DatabaseHelper {
//   static const _databaseName = "MedicalStore.db";
//   static const _databaseVersion = 5; 

//   static const columnId = 'id';
//   static const tableProducts = 'products';
//   static const columnName = 'name';
//   static const columnProductCode = 'productCode';
//   static const columnCategory = 'category';
//   static const columnDescription = 'description';
//   static const columnPurchasePrice = 'purchasePrice';
//   static const columnSellingPrice = 'sellingPrice';
//   static const columnQuantity = 'quantity';
//   static const columnUnitOfMeasure = 'unitOfMeasure';
//   static const columnExpiryDate = 'expiryDate';
//   static const columnLowStockThreshold = 'lowStockThreshold';
//   static const columnBarcode = 'barcode';
//   static const columnAddedDate = 'addedDate';
//   static const columnLastUpdated = 'lastUpdated';

//   static const tableInvoices = 'invoices';
//   static const columnInvoiceIdDb = 'id';
//   static const columnInvoiceNumber = 'invoiceNumber';
//   static const columnInvoiceDate = 'date';
//   static const columnClientName = 'clientName';
//   static const columnSubtotal = 'subtotal';
//   static const columnTaxRatePercentage = 'taxRatePercentage';
//   static const columnTaxAmount = 'taxAmount';
//   static const columnDiscountAmount = 'discountAmount';
//   static const columnGrandTotal = 'grandTotal';
//   static const columnInvoiceType = 'type';
//   static const columnInvoiceNotes = 'notes';
//   static const columnPaymentStatus = 'paymentStatus';
//   static const columnAmountPaid = 'amountPaid';
//   static const columnInvoiceLastUpdated = 'lastUpdated';

//   static const tableInvoiceItems = 'invoice_items';
//   static const columnInvoiceItemIdDb = 'id';
//   static const columnInvoiceIdFk = 'invoiceId';
//   static const columnIIProductId = 'productId';
//   static const columnIIProductName = 'productName';
//   static const columnIIQuantity = 'quantity';
//   static const columnIIUnitPrice = 'unitPrice';
//   static const columnIIItemTotal = 'itemTotal';

//   DatabaseHelper._privateConstructor();
//   static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
//   static Database? _database;

//   Future<Database> get database async {
//     if (_database != null && _database!.isOpen) return _database!;
//     _database = await _initDatabase();
//     return _database!;
//   }

//   // --- MODIFIED: _initDatabase with a more suitable directory for desktop ---
//   Future<Database> _initDatabase() async {
//     // Use getApplicationSupportDirectory for desktop, which is a safer app-specific location.
//     Directory directory = Platform.isWindows || Platform.isLinux || Platform.isMacOS 
//         ? await getApplicationSupportDirectory() 
//         : await getApplicationDocumentsDirectory();

//     String path = join(directory.path, _databaseName);
//     print("[DatabaseHelper] DB path: $path");

//     if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
//       databaseFactory = databaseFactoryFfi;
//     }

//     return await databaseFactory.openDatabase(
//       path,
//       options: OpenDatabaseOptions(
//         version: _databaseVersion,
//         onCreate: _onCreate,
//         onUpgrade: _onUpgrade,
//       ),
//     );
//   }

//   static Future<void> closeDatabaseInstance() async {
//     if (DatabaseHelper._database != null && DatabaseHelper._database!.isOpen) {
//       await DatabaseHelper._database!.close();
//       DatabaseHelper._database = null;
//     }
//   }

//   Future _onCreate(Database db, int version) async {
//     print("[DatabaseHelper] _onCreate: Creating tables for version $version");
//     await db.execute('''
//       CREATE TABLE $tableProducts (
//         $columnId INTEGER PRIMARY KEY AUTOINCREMENT, $columnName TEXT NOT NULL, $columnProductCode TEXT, 
//         $columnCategory TEXT NOT NULL, $columnDescription TEXT, $columnPurchasePrice REAL NOT NULL, 
//         $columnSellingPrice REAL NOT NULL, $columnQuantity INTEGER NOT NULL, 
//         $columnUnitOfMeasure TEXT NOT NULL, $columnExpiryDate TEXT NOT NULL, 
//         $columnLowStockThreshold INTEGER DEFAULT 10, $columnBarcode TEXT, 
//         $columnAddedDate TEXT, $columnLastUpdated TEXT
//       )''');
//     await db.execute('''
//       CREATE TABLE $tableInvoices (
//         $columnInvoiceIdDb INTEGER PRIMARY KEY AUTOINCREMENT, $columnInvoiceNumber TEXT NOT NULL UNIQUE,
//         $columnInvoiceDate TEXT NOT NULL, $columnClientName TEXT, $columnSubtotal REAL NOT NULL,
//         $columnTaxRatePercentage REAL DEFAULT 0.0, $columnTaxAmount REAL DEFAULT 0.0,
//         $columnDiscountAmount REAL DEFAULT 0.0, $columnGrandTotal REAL NOT NULL,
//         $columnInvoiceType TEXT NOT NULL, $columnInvoiceNotes TEXT,
//         $columnPaymentStatus TEXT NOT NULL DEFAULT '${PaymentStatus.unpaid.toString()}', 
//         $columnAmountPaid REAL NOT NULL DEFAULT 0.0, $columnInvoiceLastUpdated TEXT
//       )''');
//     await db.execute('''
//       CREATE TABLE $tableInvoiceItems (
//         $columnInvoiceItemIdDb INTEGER PRIMARY KEY AUTOINCREMENT, $columnInvoiceIdFk INTEGER NOT NULL,
//         $columnIIProductId INTEGER NOT NULL, $columnIIProductName TEXT NOT NULL,
//         $columnIIQuantity INTEGER NOT NULL, $columnIIUnitPrice REAL NOT NULL, $columnIIItemTotal REAL NOT NULL,
//         FOREIGN KEY ($columnInvoiceIdFk) REFERENCES $tableInvoices ($columnInvoiceIdDb) ON DELETE CASCADE,
//         FOREIGN KEY ($columnIIProductId) REFERENCES $tableProducts ($columnId) ON DELETE RESTRICT
//       )''');
//   }

//   Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
//     print("[DatabaseHelper] _onUpgrade: Upgrading from $oldVersion to $newVersion");
//     if (oldVersion < 2) await _createInvoiceTablesV2(db);
//     if (oldVersion < 3) await _addPaymentFieldsToInvoicesV3(db);
//     if (oldVersion < 4) await _addFieldsToProductsV4(db);
//     if (oldVersion < 5) {
//       try {
//         await db.execute("ALTER TABLE $tableInvoices ADD COLUMN $columnInvoiceLastUpdated TEXT");
//         print("[DatabaseHelper] V5 Upgrade: Added $columnInvoiceLastUpdated to $tableInvoices");
//       } catch (e) { print("[DatabaseHelper] Error V5: $e"); }
//     }
//   }

//   Future<void> _createInvoiceTablesV2(Database db) async { print("[DBHelper] Running V2 Migrations (_createInvoiceTablesV2)"); }
//   Future<void> _addPaymentFieldsToInvoicesV3(Database db) async { print("[DBHelper] Running V3 Migrations (_addPaymentFieldsToInvoicesV3)"); }
//   Future<void> _addFieldsToProductsV4(Database db) async { print("[DBHelper] Running V4 Migrations (_addFieldsToProductsV4)"); }

//   // --- Product Methods ---
//   Future<int> insertProduct(Product product, {Transaction? txn}) async {
//     final dbOrTxn = txn ?? await instance.database;
//     return await dbOrTxn.insert(tableProducts, product.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
//   }

//   Future<Product?> getProductById(int id, {Transaction? txn}) async {
//     final dbOrTxn = txn ?? await instance.database;
//     final List<Map<String, dynamic>> maps = await dbOrTxn.query(tableProducts, where: '$columnId = ?', whereArgs: [id]);
//     if (maps.isNotEmpty) return Product.fromMap(maps.first);
//     return null;
//   }

//   Future<int> updateProduct(Product product, {Transaction? txn}) async {
//     final dbOrTxn = txn ?? await instance.database;
//     return await dbOrTxn.update(tableProducts, product.toMap(), where: '$columnId = ?', whereArgs: [product.id]);
//   }

//   Future<int> deleteProduct(int id) async {
//     final db = await instance.database;
//     return await db.delete(tableProducts, where: '$columnId = ?', whereArgs: [id]);
//   }

//   Future<List<Product>> getAllProducts() async {
//     return await getProductsFiltered(filter: ProductListFilter.none);
//   }

//   Future<List<Product>> getProductsFiltered({ProductListFilter? filter}) async {
//     final db = await instance.database;
//     String? whereClause;
//     List<dynamic>? whereArgs;
//     const int defaultLowStockVal = 10;
//     switch (filter) {
//       case ProductListFilter.lowStock:
//         whereClause = '$columnQuantity <= COALESCE($columnLowStockThreshold, ?) AND $columnQuantity > 0'; whereArgs = [defaultLowStockVal]; break;
//       case ProductListFilter.outOfStock:
//         whereClause = '$columnQuantity <= 0'; break;
//       case ProductListFilter.expired:
//         final String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
//         whereClause = "DATE($columnExpiryDate) < ?"; whereArgs = [todayDate]; break;
//       case ProductListFilter.nearingExpiry:
//         final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
//         final String futureDate = DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 30)));
//         whereClause = "DATE($columnExpiryDate) >= ? AND DATE($columnExpiryDate) < ?"; whereArgs = [today, futureDate]; break;
//       case ProductListFilter.none: default: break;
//     }
//     final List<Map<String, dynamic>> maps = await db.query(tableProducts, where: whereClause, whereArgs: whereArgs, orderBy: '$columnName ASC');
//     return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
//   }

//   Future<List<Product>> searchProducts(String keyword, {ProductListFilter? filter}) async {
//     final db = await instance.database;
//     List<String> whereClauses = [];
//     List<dynamic> whereArgs = [];
//     if (keyword.isNotEmpty) {
//       String queryArg = '%${keyword.toLowerCase()}%';
//       whereClauses.add('($columnName LIKE ? OR $columnCategory LIKE ? OR $columnProductCode LIKE ? OR $columnBarcode LIKE ?)');
//       whereArgs.addAll([queryArg, queryArg, queryArg, queryArg]);
//     }
//     const int defaultLowStockVal = 10;
//     switch (filter) {
//       case ProductListFilter.lowStock:
//         whereClauses.add('$columnQuantity <= COALESCE($columnLowStockThreshold, ?) AND $columnQuantity > 0'); whereArgs.add(defaultLowStockVal); break;
//       case ProductListFilter.outOfStock: whereClauses.add('$columnQuantity <= 0'); break;
//       case ProductListFilter.expired:
//         final String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
//         whereClauses.add("DATE($columnExpiryDate) < ?"); whereArgs.add(todayDate); break;
//       case ProductListFilter.nearingExpiry:
//         final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
//         final String futureDate = DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 30)));
//         whereClauses.add("DATE($columnExpiryDate) >= ? AND DATE($columnExpiryDate) < ?"); whereArgs.addAll([today, futureDate]); break;
//       case ProductListFilter.none: default: break;
//     }
//     String? finalWhereClause = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;
//     final List<Map<String, dynamic>> maps = await db.query(tableProducts, where: finalWhereClause, whereArgs: whereArgs.isNotEmpty ? whereArgs : null, orderBy: '$columnName ASC');
//     return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
//   }

//   // --- Invoice Methods ---
//   Future<int> insertInvoiceWithItems(Invoice invoice, List<InvoiceItem> items, {Transaction? txnPassed}) async {
//     final dbForTransaction = txnPassed ?? await instance.database;
//     Future<int> performInsert(Transaction txn) async {
//       Map<String, dynamic> invoiceMap = invoice.toMap();
//       invoiceMap.remove('id');
//       invoiceMap[columnInvoiceLastUpdated] = DateTime.now().toIso8601String();
//       int invoiceId = await txn.insert(tableInvoices, invoiceMap);
//       for (var item in items) {
//         item.invoiceId = invoiceId;
//         Map<String, dynamic> itemMap = item.toMap();
//         itemMap.remove('id');
//         await txn.insert(tableInvoiceItems, itemMap);
//       }
//       return invoiceId;
//     }

//     if (txnPassed != null) {
//       return await performInsert(txnPassed);
//     } else {
//       return await (dbForTransaction as Database).transaction((txn) async {
//         return await performInsert(txn);
//       });
//     }
//   }

//   Future<List<InvoiceItem>> getInvoiceItems(int invoiceId) async {
//     final db = await instance.database;
//     final List<Map<String, dynamic>> maps = await db.query(tableInvoiceItems, where: '$columnInvoiceIdFk = ?', whereArgs: [invoiceId]);
//     return List.generate(maps.length, (i) => InvoiceItem.fromMap(maps[i]));
//   }

//   Future<List<Invoice>> getAllInvoices({InvoiceType? type, InvoiceListFilter? filter}) async {
//     final db = await instance.database;
//     String? whereClause;
//     List<dynamic>? whereArgs;
//     switch (filter) {
//       case InvoiceListFilter.todaySales:
//         final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
//         whereClause = '$columnInvoiceType = ? AND DATE($columnInvoiceDate) = ?'; whereArgs = [InvoiceType.sale.toString(), today]; break;
//       case InvoiceListFilter.todayPurchases:
//         final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
//         whereClause = '$columnInvoiceType = ? AND DATE($columnInvoiceDate) = ?'; whereArgs = [InvoiceType.purchase.toString(), today]; break;
//       case InvoiceListFilter.unpaidSales:
//         whereClause = '$columnInvoiceType = ? AND $columnPaymentStatus != ?'; whereArgs = [InvoiceType.sale.toString(), PaymentStatus.paid.toString()]; break;
//       case InvoiceListFilter.none: default:
//         if (type != null) { whereClause = '$columnInvoiceType = ?'; whereArgs = [type.toString()]; } break;
//     }
//     final List<Map<String, dynamic>> maps = await db.query(tableInvoices, where: whereClause, whereArgs: whereArgs, orderBy: '$columnInvoiceDate DESC');
//     List<Invoice> invoices = [];
//     for (var map in maps) {
//       Invoice invoice = Invoice.fromMap(map);
//       if (invoice.id != null) invoice.items = await getInvoiceItems(invoice.id!);
//       invoices.add(invoice);
//     }
//     return invoices;
//   }

//   Future<Invoice?> getInvoiceById(int id, {Transaction? txn}) async {
//     final dbOrTxn = txn ?? await instance.database;
//     final List<Map<String, dynamic>> maps = await dbOrTxn.query(tableInvoices, where: '$columnInvoiceIdDb = ?', whereArgs: [id]);
//     if (maps.isNotEmpty) {
//       Invoice invoice = Invoice.fromMap(maps.first);
//       if (invoice.id != null) invoice.items = await getInvoiceItems(invoice.id!); 
//       return invoice;
//     }
//     return null;
//   }
  
//   Future<void> deleteInvoiceAndItems(int invoiceId, {Transaction? txn}) async {
//     final dbOrTxn = txn ?? await instance.database;
//     await dbOrTxn.delete(
//       tableInvoices,
//       where: '$columnInvoiceIdDb = ?',
//       whereArgs: [invoiceId],
//     );
//     print("[DatabaseHelper] Deleted invoice with ID: $invoiceId and its items (cascade).");
//   }

//   Future<int> updateInvoicePaymentDetails(int invoiceId, PaymentStatus status, double amountPaid, {Transaction? txn}) async {
//     final dbOrTxn = txn ?? await instance.database;
//     return await dbOrTxn.update(tableInvoices, {
//         columnPaymentStatus: status.toString(), columnAmountPaid: amountPaid,
//         columnInvoiceLastUpdated: DateTime.now().toIso8601String()
//       }, where: '$columnInvoiceIdDb = ?', whereArgs: [invoiceId]);
//   }
  
//   Future<List<Invoice>> getTodaysSalesInvoices() async {
//     return await getAllInvoices(filter: InvoiceListFilter.todaySales);
//   }
//   Future<List<Invoice>> getTodaysPurchasesInvoices() async {
//     return await getAllInvoices(filter: InvoiceListFilter.todayPurchases);
//   }
//   Future<List<Invoice>> getUnpaidSalesInvoices() async {
//     return await getAllInvoices(filter: InvoiceListFilter.unpaidSales);
//   }

//   Future<List<Invoice>> getInvoicesByDateRangeAndType(DateTime startDate, DateTime endDate, InvoiceType type) async {
//     final db = await instance.database;
//     final String startDateString = DateFormat('yyyy-MM-dd').format(startDate);
//     final String endOfDayString = DateFormat('yyyy-MM-dd').format(endDate);
//     final maps = await db.query(tableInvoices,
//       where: '$columnInvoiceType = ? AND DATE($columnInvoiceDate) BETWEEN ? AND ?',
//       whereArgs: [type.toString(), startDateString, endOfDayString],
//       orderBy: '$columnInvoiceDate DESC');
//     List<Invoice> invoices = [];
//     for (var map in maps) {
//       Invoice invoice = Invoice.fromMap(map);
//       if (invoice.id != null) invoice.items = await getInvoiceItems(invoice.id!);
//       invoices.add(invoice);
//     }
//     return invoices;
//   }

//   Future<String> getNextInvoiceNumber(InvoiceType type) async {
//     final db = await instance.database;
//     String prefix = type == InvoiceType.sale ? "SALE-" : "PUR-";
//     final result = await db.rawQuery(
//       "SELECT MAX(CAST(REPLACE($columnInvoiceNumber, ?, '') AS INTEGER)) as max_num FROM $tableInvoices WHERE $columnInvoiceNumber LIKE ?",
//       [prefix, '$prefix%'],
//     );
//     int nextNum = 1;
//     if (result.isNotEmpty && result.first['max_num'] != null) {
//       nextNum = (result.first['max_num'] as int) + 1;
//     }
//     return "$prefix${nextNum.toString().padLeft(5, '0')}";
//   }

//   Future<int> updateInvoiceRecord(Invoice invoice, {Transaction? txn}) async {
//     final dbOrTxn = txn ?? await instance.database;
//     Map<String, dynamic> invoiceMap = invoice.toMap();
//     invoiceMap[columnInvoiceLastUpdated] = DateTime.now().toIso8601String(); 
//     return await dbOrTxn.update(tableInvoices, invoiceMap, where: '$columnInvoiceIdDb = ?', whereArgs: [invoice.id]);
//   }
// }