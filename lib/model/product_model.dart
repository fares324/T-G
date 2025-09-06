// lib/models/product_model.dart

class Product {
  int? id;
  String name;
  String? productCode; // SKU
  String category;
  String? description;
  double purchasePrice;
  double sellingPrice;
  int quantity;
  String unitOfMeasure; // e.g., Pcs, Box
  DateTime expiryDate;
  int? lowStockThreshold;

  String? barcode;
  DateTime? addedDate;
  DateTime? lastUpdated;

  Product({
    this.id,
    required this.name,
    this.productCode,
    required this.category,
    this.description,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.quantity,
    required this.unitOfMeasure,
    required this.expiryDate,
    this.lowStockThreshold = 10, // Default value
    this.barcode,
    this.addedDate,
    this.lastUpdated,
  });

  bool get isLowStock {
    final threshold = lowStockThreshold ?? 10; // Use default if null
    return quantity > 0 && quantity <= threshold;
  }

  bool get isOutOfStock => quantity <= 0;
  bool get isExpired {
    // Compare only the date part to avoid issues with time
    final today = DateTime.now();
    final expiry = expiryDate;
    return expiry.year < today.year ||
           (expiry.year == today.year && expiry.month < today.month) ||
           (expiry.year == today.year && expiry.month == today.month && expiry.day < today.day);
  }

  bool get isNearingExpiry {
    if (isExpired) return false;
    // Compare only the date part
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final futureDate = today.add(const Duration(days: 30)); // Example: 30 days
    final expiry = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    return !expiry.isBefore(today) && expiry.isBefore(futureDate);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'productCode': productCode,
      'category': category,
      'description': description,
      'purchasePrice': purchasePrice,
      'sellingPrice': sellingPrice,
      'quantity': quantity,
      'unitOfMeasure': unitOfMeasure,
      'expiryDate': expiryDate.toIso8601String(), // Store as ISO8601 string
      'lowStockThreshold': lowStockThreshold,
      'barcode': barcode,
      'addedDate': addedDate?.toIso8601String(),
      'lastUpdated': lastUpdated?.toIso8601String(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      name: map['name'] as String,
      productCode: map['productCode'] as String?,
      category: map['category'] as String,
      description: map['description'] as String?,
      purchasePrice: (map['purchasePrice'] as num).toDouble(), // Ensure conversion from num if necessary
      sellingPrice: (map['sellingPrice'] as num).toDouble(), // Ensure conversion from num
      quantity: map['quantity'] as int,
      unitOfMeasure: map['unitOfMeasure'] as String,
      expiryDate: DateTime.parse(map['expiryDate'] as String),
      lowStockThreshold: map['lowStockThreshold'] as int? ?? 10, // Provide default if null
      barcode: map['barcode'] as String?,
      addedDate: map['addedDate'] == null ? null : DateTime.parse(map['addedDate'] as String),
      lastUpdated: map['lastUpdated'] == null ? null : DateTime.parse(map['lastUpdated'] as String),
    );
  }

  // --- NEW: copyWith method ---
  Product copyWith({
    int? id,
    String? name,
    String? productCode,
    String? category,
    String? description,
    double? purchasePrice,
    double? sellingPrice,
    int? quantity,
    String? unitOfMeasure,
    DateTime? expiryDate,
    int? lowStockThreshold,
    String? barcode,
    DateTime? addedDate,
    DateTime? lastUpdated,
    bool allowNullProductCode = false, // Special flag for productCode
    bool allowNullDescription = false, // Special flag for description
    bool allowNullBarcode = false,     // Special flag for barcode
    bool allowNullAddedDate = false,   // Special flag for addedDate
    bool allowNullLastUpdated = false, // Special flag for lastUpdated
    bool allowNullLowStockThreshold = false, // Special flag for lowStockThreshold
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      productCode: allowNullProductCode ? productCode : (productCode ?? this.productCode),
      category: category ?? this.category,
      description: allowNullDescription ? description : (description ?? this.description),
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      quantity: quantity ?? this.quantity,
      unitOfMeasure: unitOfMeasure ?? this.unitOfMeasure,
      expiryDate: expiryDate ?? this.expiryDate,
      lowStockThreshold: allowNullLowStockThreshold ? lowStockThreshold : (lowStockThreshold ?? this.lowStockThreshold),
      barcode: allowNullBarcode ? barcode : (barcode ?? this.barcode),
      addedDate: allowNullAddedDate ? addedDate : (addedDate ?? this.addedDate),
      lastUpdated: allowNullLastUpdated ? lastUpdated : (lastUpdated ?? this.lastUpdated),
    );
  }
  // --- END NEW: copyWith method ---

  @override
  String toString() {
    return 'Product{id: $id, name: $name, quantity: $quantity, expiryDate: $expiryDate, lowStockThreshold: $lowStockThreshold, barcode: $barcode, addedDate: $addedDate, lastUpdated: $lastUpdated}';
  }
}


























// class Product {
//   int? id;
//   String name;
//   String? productCode; // SKU
//   String category;
//   String? description;
//   double purchasePrice;
//   double sellingPrice;
//   int quantity;
//   String unitOfMeasure; // e.g., Pcs, Box
//   DateTime expiryDate;
//   int? lowStockThreshold;

//   Product({
//     this.id,
//     required this.name,
//     this.productCode,
//     required this.category,
//     this.description,
//     required this.purchasePrice,
//     required this.sellingPrice,
//     required this.quantity,
//     required this.unitOfMeasure,
//     required this.expiryDate,
//     this.lowStockThreshold = 10, // Default low stock threshold
//   });

//   // Convert a Product object into a Map object
//   Map<String, dynamic> toMap() {
//     return {
//       'id': id,
//       'name': name,
//       'productCode': productCode,
//       'category': category,
//       'description': description,
//       'purchasePrice': purchasePrice,
//       'sellingPrice': sellingPrice,
//       'quantity': quantity,
//       'unitOfMeasure': unitOfMeasure,
//       'expiryDate': expiryDate.toIso8601String(), // Store dates as ISO8601 strings
//       'lowStockThreshold': lowStockThreshold,
//     };
//   }

//   // Extract a Product object from a Map object
//   factory Product.fromMap(Map<String, dynamic> map) {
//     return Product(
//       id: map['id'],
//       name: map['name'],
//       productCode: map['productCode'],
//       category: map['category'],
//       description: map['description'],
//       purchasePrice: map['purchasePrice'],
//       sellingPrice: map['sellingPrice'],
//       quantity: map['quantity'],
//       unitOfMeasure: map['unitOfMeasure'],
//       expiryDate: DateTime.parse(map['expiryDate']),
//       lowStockThreshold: map['lowStockThreshold'],
//     );
//   }

//   // Helper to display product for debugging or simple lists
//   @override
//   String toString() {
//     return 'Product{id: $id, name: $name, quantity: $quantity, expiryDate: $expiryDate}';
//   }
// }