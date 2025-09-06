// lib/models/invoice_model.dart
import 'package:flutter/material.dart'; // Keep for ThemeData in paymentStatusColor
import 'invoice_item_model.dart';

enum InvoiceType { sale, purchase }

enum PaymentStatus { unpaid, partiallyPaid, paid }

String paymentStatusToString(PaymentStatus status) {
  switch (status) {
    case PaymentStatus.unpaid:
      return 'غير مدفوع';
    case PaymentStatus.partiallyPaid:
      return 'مدفوع جزئياً';
    case PaymentStatus.paid:
      return 'مدفوع بالكامل';
    default: // Should not happen if all cases are covered
      return status.toString().split('.').last;
  }
}

PaymentStatus stringToPaymentStatus(String? statusString) {
  if (statusString == null) return PaymentStatus.unpaid;
  return PaymentStatus.values.firstWhere(
    (e) => e.toString() == statusString,
    orElse: () => PaymentStatus.unpaid, // Default if string doesn't match any enum
  );
}

Color paymentStatusColor(PaymentStatus status, ThemeData theme) {
  switch (status) {
    case PaymentStatus.paid:
      return Colors.green.shade600;
    case PaymentStatus.partiallyPaid:
      return Colors.orange.shade700;
    case PaymentStatus.unpaid:
      return theme.colorScheme.error;
    default:
      return theme.disabledColor;
  }
}

class Invoice {
  int? id;
  String invoiceNumber;
  DateTime date;
  String? clientName;
  List<InvoiceItem> items; // This list is usually populated after fetching the main invoice
  double subtotal;
  double taxRatePercentage;
  double taxAmount;
  double discountAmount;
  double grandTotal;
  InvoiceType type;
  String? notes;

  PaymentStatus paymentStatus;
  double amountPaid;
  DateTime? lastUpdated; // Made nullable

  Invoice({
    this.id,
    required this.invoiceNumber,
    required this.date,
    this.clientName,
    required this.items,
    required this.subtotal,
    this.taxRatePercentage = 0.0,
    required this.taxAmount,
    this.discountAmount = 0.0,
    required this.grandTotal,
    this.type = InvoiceType.sale,
    this.notes,
    this.paymentStatus = PaymentStatus.unpaid,
    this.amountPaid = 0.0,
    this.lastUpdated, // Now optional in constructor
  });

  double get balanceDue =>
      (grandTotal - amountPaid) < 0.01 ? 0.0 : (grandTotal - amountPaid);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
      'date': date.toIso8601String(),
      'clientName': clientName,
      'subtotal': subtotal,
      'taxRatePercentage': taxRatePercentage,
      'taxAmount': taxAmount,
      'discountAmount': discountAmount,
      'grandTotal': grandTotal,
      'type': type.toString(),
      'notes': notes,
      'paymentStatus': paymentStatus.toString(),
      'amountPaid': amountPaid,
      // --- MODIFIED: Include lastUpdated in toMap ---
      'lastUpdated': lastUpdated?.toIso8601String(),
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['id'] as int?,
      invoiceNumber: map['invoiceNumber'] as String,
      date: DateTime.parse(map['date'] as String),
      clientName: map['clientName'] as String?,
      items: [], // Items should be fetched separately and populated
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      taxRatePercentage: (map['taxRatePercentage'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (map['taxAmount'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (map['discountAmount'] as num?)?.toDouble() ?? 0.0,
      grandTotal: (map['grandTotal'] as num?)?.toDouble() ?? 0.0,
      type: InvoiceType.values.firstWhere(
        (e) => e.toString() == map['type'],
        orElse: () => InvoiceType.sale,
      ),
      notes: map['notes'] as String?,
      paymentStatus: stringToPaymentStatus(map['paymentStatus'] as String?),
      amountPaid: (map['amountPaid'] as num?)?.toDouble() ?? 0.0,
      // --- MODIFIED: Correctly parse lastUpdated from map ---
      lastUpdated: map['lastUpdated'] == null ? null : DateTime.parse(map['lastUpdated'] as String),
    );
  }

  // Optional: copyWith method for easier updates
  Invoice copyWith({
    int? id,
    String? invoiceNumber,
    DateTime? date,
    String? clientName,
    List<InvoiceItem>? items,
    double? subtotal,
    double? taxRatePercentage,
    double? taxAmount,
    double? discountAmount,
    double? grandTotal,
    InvoiceType? type,
    String? notes,
    PaymentStatus? paymentStatus,
    double? amountPaid,
    DateTime? lastUpdated,
    bool setClientNameToNull = false, // Flags to explicitly set nullable fields to null
    bool setNotesToNull = false,
    bool setLastUpdatedToNull = false,
  }) {
    return Invoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      date: date ?? this.date,
      clientName: setClientNameToNull ? null : (clientName ?? this.clientName),
      items: items ?? this.items, // Be careful with deep copy if items are mutable
      subtotal: subtotal ?? this.subtotal,
      taxRatePercentage: taxRatePercentage ?? this.taxRatePercentage,
      taxAmount: taxAmount ?? this.taxAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      grandTotal: grandTotal ?? this.grandTotal,
      type: type ?? this.type,
      notes: setNotesToNull ? null : (notes ?? this.notes),
      paymentStatus: paymentStatus ?? this.paymentStatus,
      amountPaid: amountPaid ?? this.amountPaid,
      lastUpdated: setLastUpdatedToNull ? null : (lastUpdated ?? this.lastUpdated),
    );
  }
}