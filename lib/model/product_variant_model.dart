// lib/models/product_variant_model.dart
import 'package:flutter/foundation.dart';

class ProductVariant {
  int? id;
  int productId;
  Map<String, String> attributes;
  double purchasePrice;
  double sellingPrice;
  int quantity;
  String? sku;
  String? barcode;
  DateTime? expiryDate;

  ProductVariant({
    this.id,
    required this.productId,
    required this.attributes,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.quantity,
    this.sku,
    this.barcode,
    this.expiryDate,
  });

  // Helper to get a display-friendly name from attributes
  String get displayName {
    if (attributes.isEmpty) return '';
    return attributes.values.join(' / ');
  }

  // Helper to check if the variant has any attributes
  bool get hasAttributes => attributes.isNotEmpty;

  // Static helper to generate a display name from a map
  static String generateDisplayName(Map<String, String> attributes) {
    if (attributes.isEmpty) return '';
    return attributes.values.join(' / ');
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'name': attributes.keys.isNotEmpty ? attributes.keys.first : '', // Storing first option name
      'value': attributes.values.isNotEmpty ? attributes.values.first : '', // Storing first option value
      'purchasePrice': purchasePrice,
      'sellingPrice': sellingPrice,
      'quantity': quantity,
      'sku': sku,
      'barcode': barcode,
    };
  }

  factory ProductVariant.fromMap(Map<String, dynamic> map) {
    return ProductVariant(
      id: map['id'] as int?,
      productId: map['productId'] as int,
      attributes: {
        (map['name'] as String): (map['value'] as String)
      }, // Reconstruct attributes from name/value
      purchasePrice: map['purchasePrice'] as double,
      sellingPrice: map['sellingPrice'] as double,
      quantity: map['quantity'] as int,
      sku: map['sku'] as String?,
      barcode: map['barcode'] as String?,
    );
  }

  ProductVariant copyWith({
    int? id,
    int? productId,
    Map<String, String>? attributes,
    double? purchasePrice,
    double? sellingPrice,
    int? quantity,
    String? sku,
    String? barcode,
    DateTime? expiryDate,
  }) {
    return ProductVariant(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      attributes: attributes ?? this.attributes,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      quantity: quantity ?? this.quantity,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      expiryDate: expiryDate ?? this.expiryDate,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is ProductVariant &&
      other.id == id &&
      other.productId == productId &&
      mapEquals(other.attributes, attributes);
  }

  @override
  int get hashCode => id.hashCode ^ productId.hashCode ^ attributes.hashCode;
}

