// lib/models/product_model.dart
import 'package:fouad_stock/model/product_variant_model.dart';

class Product {
  int? id;
  String name;
  String? productCode;
  String category;
  String? description;
  String unitOfMeasure;
  int? lowStockThreshold;
  DateTime? addedDate;
  DateTime? lastUpdated;

  List<ProductVariant> variants;

  Product({
    this.id,
    required this.name,
    this.productCode,
    required this.category,
    this.description,
    required this.unitOfMeasure,
    this.lowStockThreshold,
    this.addedDate,
    this.lastUpdated,
    this.variants = const [],
  });
  
  bool get hasVariants => variants.length > 1 || (variants.isNotEmpty && variants.first.hasAttributes);

  int get totalQuantity {
    if (variants.isEmpty) return 0;
    return variants.fold(0, (sum, variant) => sum + variant.quantity);
  }
  
  double get totalStockValueByPurchasePrice {
    if (variants.isEmpty) return 0.0;
    return variants.fold(0.0, (sum, variant) => sum + (variant.quantity * variant.purchasePrice));
  }

  String get priceRange {
    if (variants.isEmpty) return "N/A";
    if (variants.length == 1) return variants.first.sellingPrice.toStringAsFixed(2);
    
    double minPrice = variants.first.sellingPrice;
    double maxPrice = variants.first.sellingPrice;
    
    for (var variant in variants) {
      if (variant.sellingPrice < minPrice) minPrice = variant.sellingPrice;
      if (variant.sellingPrice > maxPrice) maxPrice = variant.sellingPrice;
    }
    
    if (minPrice == maxPrice) return minPrice.toStringAsFixed(2);
    return '${minPrice.toStringAsFixed(2)} - ${maxPrice.toStringAsFixed(2)}';
  }

  bool get isOutOfStock => totalQuantity <= 0;
  bool get isLowStock => !isOutOfStock && lowStockThreshold != null && totalQuantity <= lowStockThreshold!;

  DateTime? get earliestExpiryDate {
    if (variants.where((v) => v.expiryDate != null).isEmpty) return null;
    return variants.where((v) => v.expiryDate != null).map((v) => v.expiryDate!).reduce((a, b) => a.isBefore(b) ? a : b);
  }

  bool get isExpired {
    final earliest = earliestExpiryDate;
    if (earliest == null) return false;
    return earliest.isBefore(DateTime.now());
  }

  bool get isNearingExpiry {
    final earliest = earliestExpiryDate;
    if (earliest == null) return false;
    return earliest.isBefore(DateTime.now().add(const Duration(days: 30))) && !isExpired;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'productCode': productCode,
      'category': category,
      'description': description,
      'unitOfMeasure': unitOfMeasure,
      'lowStockThreshold': lowStockThreshold,
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
      unitOfMeasure: map['unitOfMeasure'] as String,
      lowStockThreshold: map['lowStockThreshold'] as int?,
      addedDate: map['addedDate'] == null ? null : DateTime.parse(map['addedDate'] as String),
      lastUpdated: map['lastUpdated'] == null ? null : DateTime.parse(map['lastUpdated'] as String),
      variants: [],
    );
  }

  Product copyWith({
    int? id,
    String? name,
    String? productCode,
    String? category,
    String? description,
    String? unitOfMeasure,
    int? lowStockThreshold,
    DateTime? addedDate,
    DateTime? lastUpdated,
    List<ProductVariant>? variants,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      productCode: productCode ?? this.productCode,
      category: category ?? this.category,
      description: description ?? this.description,
      unitOfMeasure: unitOfMeasure ?? this.unitOfMeasure,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      addedDate: addedDate ?? this.addedDate,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      variants: variants ?? this.variants,
    );
  }
}






