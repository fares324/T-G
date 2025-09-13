// lib/models/invoice_item_model.dart

class InvoiceItem {
  int? id;
  int invoiceId;
  int productId;
  String productName;
  // --- NEW: Added category field ---
  String category;
  int quantity;
  double unitPrice;
  double purchasePrice;
  double itemTotal;

  InvoiceItem({
    this.id,
    required this.invoiceId,
    required this.productId,
    required this.productName,
    required this.category, // Added to constructor
    required this.quantity,
    required this.unitPrice,
    required this.purchasePrice,
    required this.itemTotal,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceId': invoiceId,
      'productId': productId,
      'productName': productName,
      'category': category, // Added to map
      'quantity': quantity,
      'unitPrice': unitPrice,
      'purchasePrice': purchasePrice,
      'itemTotal': itemTotal,
    };
  }

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      id: map['id'],
      invoiceId: map['invoiceId'],
      productId: map['productId'],
      productName: map['productName'],
      // Handle legacy invoices that don't have a category
      category: map['category'] ?? '', // Added from map
      quantity: map['quantity'],
      unitPrice: map['unitPrice'],
      purchasePrice: (map['purchasePrice'] as num?)?.toDouble() ?? 0.0,
      itemTotal: map['itemTotal'],
    );
  }
}
