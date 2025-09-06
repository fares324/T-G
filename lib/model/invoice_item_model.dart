// lib/model/invoice_item_model.dart

class InvoiceItem {
  int? id;
  int invoiceId;
  int productId;
  String productName;
  int quantity;
  double unitPrice; // This is the selling price
  // --- NEW FIELD ---
  double purchasePrice; // This is the cost at the time of sale
  double itemTotal;

  InvoiceItem({
    this.id,
    required this.invoiceId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.purchasePrice, // Added to constructor
    required this.itemTotal,
  });

  // --- NEW GETTER for easy profit calculation ---
  double get totalProfit => (unitPrice - purchasePrice) * quantity;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceId': invoiceId,
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'purchasePrice': purchasePrice, // Added to map
      'itemTotal': itemTotal,
    };
  }

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      id: map['id'],
      invoiceId: map['invoiceId'],
      productId: map['productId'],
      productName: map['productName'],
      quantity: map['quantity'],
      unitPrice: map['unitPrice'],
      // Read from map, provide a default of 0.0 if it's null (for old records)
      purchasePrice: (map['purchasePrice'] as num?)?.toDouble() ?? 0.0, 
      itemTotal: map['itemTotal'],
    );
  }
}
