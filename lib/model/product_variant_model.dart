// lib/models/product_variant_model.dart
import 'dart:convert';
import 'package:flutter/material.dart';


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

  String get displayName {
    if (attributes.isEmpty) return 'افتراضي';
    var sortedKeys = attributes.keys.toList()..sort();
    return sortedKeys.map((key) => attributes[key]!).join(' / ');
  }
  
  static String generateDisplayName(Map<String, String> attributes) {
   if (attributes.isEmpty) return 'افتراضي';
    var sortedKeys = attributes.keys.toList()..sort();
    return sortedKeys.map((key) => attributes[key]!).join(' / ');
  }

  bool get hasAttributes => attributes.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'attributes': jsonEncode(attributes),
      'purchasePrice': purchasePrice,
      'sellingPrice': sellingPrice,
      'quantity': quantity,
      'sku': sku,
      'barcode': barcode,
      // Note: expiryDate is not saved in this map, add if needed
    };
  }

  // <-- CHANGED: This function is now safer and handles null values
  factory ProductVariant.fromMap(Map<String, dynamic> map) {
    Map<String, String> attributesMap = {};
    // Check if 'attributes' from the DB is a valid String before decoding
    if (map['attributes'] is String) {
      attributesMap = Map<String, String>.from(jsonDecode(map['attributes']));
    }

    return ProductVariant(
      id: map['id'] as int?,
      productId: map['productId'] as int,
      attributes: attributesMap, // Use the safe map
      purchasePrice: map['purchasePrice'] as double,
      sellingPrice: map['sellingPrice'] as double,
      quantity: map['quantity'] as int,
      sku: map['sku'] as String?,
      barcode: map['barcode'] as String?,
      // Note: expiryDate is not loaded from map, add if needed
    );
  }

  ProductVariant copyWith({
    int? id,
    int? productId,
    Map<String, String>? attributes,
    double? purchasePrice,
    double? sellingPrice,
    int? quantity,
    // Allow null values to be passed to unset optional fields
    ValueGetter<String?>? sku,
    ValueGetter<String?>? barcode,
    ValueGetter<DateTime?>? expiryDate,
  }) {
    return ProductVariant(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      attributes: attributes ?? this.attributes,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      quantity: quantity ?? this.quantity,
      sku: sku != null ? sku() : this.sku,
      barcode: barcode != null ? barcode() : this.barcode,
      expiryDate: expiryDate != null ? expiryDate() : this.expiryDate,
    );
  }
}



