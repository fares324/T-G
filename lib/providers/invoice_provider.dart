// lib/providers/invoice_provider.dart
import 'package:flutter/material.dart';
import 'package:fouad_stock/enum/filter_enums.dart';
import 'package:fouad_stock/model/invoice_item_model.dart' as db_invoice_item;
import 'package:fouad_stock/model/invoice_model.dart';
import '../helpers/db_helpers.dart';
import 'product_provider.dart';

// Class to hold report data
class SalesReport {
  final double totalSales;
  final double totalCost;
  final double totalDiscounts;
  final double netProfit;
  final int invoiceCount;

  SalesReport({
    this.totalSales = 0.0,
    this.totalCost = 0.0,
    this.totalDiscounts = 0.0,
    this.netProfit = 0.0,
    this.invoiceCount = 0,
  });
}

class InvoiceProvider with ChangeNotifier {
  List<Invoice> _allFetchedInvoices = [];
  List<Invoice> _invoices = [];
  bool _isLoading = false;
  String? _errorMessage;
  InvoiceListFilter _currentFilter = InvoiceListFilter.none;
  String _searchQuery = '';

  List<Invoice> get invoices => _invoices;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  InvoiceListFilter get currentFilter => _currentFilter;

  InvoiceProvider() {
    fetchInvoices();
  }
  
  // --- NEW METHOD TO CALCULATE REPORT STATISTICS ---
  SalesReport generateSalesReport(List<Invoice> invoices) {
    double totalSales = 0.0;
    double totalCost = 0.0;
    double totalDiscounts = 0.0;

    // Loop through each invoice to calculate totals
    for (final invoice in invoices) {
      // 1. Add the subtotal (sales before discount) to totalSales
      totalSales += invoice.subtotal;
      
      // 2. Add the discount amount to totalDiscounts
      totalDiscounts += invoice.discountAmount;

      // 3. Loop through items to calculate the cost of goods for this invoice
      for (final item in invoice.items) {
        totalCost += (item.purchasePrice * item.quantity);
      }
    }

    // 4. Calculate the final net profit using the correct formula
    final double netProfit = totalSales - totalCost - totalDiscounts;

    // Return the complete report object
    return SalesReport(
      totalSales: totalSales,
      totalCost: totalCost,
      totalDiscounts: totalDiscounts,
      netProfit: netProfit,
      invoiceCount: invoices.length,
    );
  }

  void _setLoading(bool loading) {
    if (_isLoading == loading) return;
    _isLoading = loading;
    notifyListeners();
  }

  void _clearErrorMessage() {
    if (_errorMessage != null) {
      _errorMessage = null;
    }
  }

  Future<void> fetchInvoices({InvoiceListFilter? filter}) async {
    _currentFilter = filter ?? _currentFilter;
    _isLoading = true;
    notifyListeners();
    _clearErrorMessage();
    try {
      _allFetchedInvoices = await DatabaseHelper.instance.getAllInvoices(filter: _currentFilter);
      searchInvoices(_searchQuery);
    } catch (e) {
      _errorMessage = "حدث خطأ أثناء جلب الفواتير: $e";
      _invoices = [];
      _allFetchedInvoices = [];
      print(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void searchInvoices(String query) {
    _searchQuery = query;
    if (_searchQuery.isEmpty) {
      _invoices = List.from(_allFetchedInvoices);
    } else {
      final lowerCaseQuery = _searchQuery.toLowerCase();
      _invoices = _allFetchedInvoices.where((invoice) {
        final clientMatch = invoice.clientName?.toLowerCase().contains(lowerCaseQuery) ?? false;
        final numberMatch = invoice.invoiceNumber.toLowerCase().contains(lowerCaseQuery);
        return clientMatch || numberMatch;
      }).toList();
    }
    notifyListeners();
  }

  Future<Invoice?> getInvoiceById(int invoiceId) async {
    _clearErrorMessage();
    _setLoading(true);
    Invoice? invoice;
    try {
      invoice = await DatabaseHelper.instance.getInvoiceById(invoiceId);
      if (invoice == null) {
        _errorMessage = "الفاتورة غير موجودة.";
      }
    } catch (e) {
      _errorMessage = "حدث خطأ أثناء جلب تفاصيل الفاتورة: $e";
      print(_errorMessage);
      invoice = null;
    }
    _setLoading(false);
    return invoice;
  }

  Future<String> getNextInvoiceNumber(InvoiceType type) async {
    try {
      return await DatabaseHelper.instance.getNextInvoiceNumber(type);
    } catch (e) {
      print("[InvoiceProvider] Error getNextInvoiceNumber: $e");
      rethrow;
    }
  }

  Future<String?> createSaleInvoice({
    required Invoice invoiceData,
    required List<db_invoice_item.InvoiceItem> invoiceItems,
    required ProductProvider productProvider,
  }) async {
    _setLoading(true);
    _clearErrorMessage();
    try {
      final newInvoiceId = await DatabaseHelper.instance.createSaleTransaction(
        invoiceData,
        invoiceItems,
      );

      await productProvider.fetchProducts();
      
      final newCompleteInvoice = await DatabaseHelper.instance.getInvoiceById(newInvoiceId);
      if(newCompleteInvoice != null) {
        _allFetchedInvoices.insert(0, newCompleteInvoice);
        searchInvoices(_searchQuery);
      } else {
        await fetchInvoices(filter: _currentFilter);
      }
      _setLoading(false);
      return null;
    } catch (e) {
      _errorMessage = "حدث خطأ أثناء إنشاء الفاتورة: ${e.toString().replaceFirst("Exception: ", "")}";
      print("[InvoiceProvider] Error creating sale invoice (transaction rolled back): $_errorMessage");
      _setLoading(false);
      return _errorMessage;
    }
  }

  Future<String?> createPurchaseInvoice({
    required Invoice invoiceData,
    required List<db_invoice_item.InvoiceItem> invoiceItems,
    required ProductProvider productProvider,
  }) async {
    _setLoading(true);
    _clearErrorMessage();
    try {
      final newInvoiceId = await DatabaseHelper.instance.createPurchaseTransaction(
        invoiceData,
        invoiceItems,
      );
      
      await productProvider.fetchProducts();

      final newCompleteInvoice = await DatabaseHelper.instance.getInvoiceById(newInvoiceId);
      if(newCompleteInvoice != null) {
        _allFetchedInvoices.insert(0, newCompleteInvoice);
        searchInvoices(_searchQuery);
      } else {
        await fetchInvoices(filter: _currentFilter);
      }
      _setLoading(false);
      return null;
    } catch (e) {
      _errorMessage = "حدث خطأ جسيم أثناء إنشاء فاتورة الشراء: ${e.toString().replaceFirst("Exception: ", "")}";
      print("[InvoiceProvider] Error creating purchase invoice (transaction rolled back): $_errorMessage");
      _setLoading(false);
      return _errorMessage;
    }
  }
  
  Future<String?> deleteInvoiceAndReconcileStock(Invoice invoice, ProductProvider productProvider) async {
    if (invoice.id == null) {
      return "معرف الفاتورة غير صالح.";
    }
    _setLoading(true);
    _clearErrorMessage();
    final db = await DatabaseHelper.instance.database;
    try {
      await db.transaction((txn) async {
        for (var item in invoice.items) {
          int quantityChange = (invoice.type == InvoiceType.sale) ? item.quantity : -item.quantity;
          await DatabaseHelper.instance.updateVariantQuantity(item.productId, quantityChange, txn: txn);
        }
        await DatabaseHelper.instance.deleteInvoiceAndItems(invoice.id!, txn: txn);
      });
      
      _allFetchedInvoices.removeWhere((inv) => inv.id == invoice.id);
      searchInvoices(_searchQuery); 
      
      await productProvider.fetchProducts();
      
      _setLoading(false);
      return null;
    } catch (e) {
      _errorMessage = "حدث خطأ أثناء حذف الفاتورة: $e";
      print("[InvoiceProvider] Error deleting invoice: $_errorMessage");
      _setLoading(false);
      return _errorMessage;
    }
  }

  Future<String?> updateInvoice({
    required Invoice originalInvoice,
    required Invoice updatedInvoiceData,
    required List<db_invoice_item.InvoiceItem> updatedInvoiceItems,
    required ProductProvider productProvider,
  }) async {
    _setLoading(true);
    _clearErrorMessage();
    final db = await DatabaseHelper.instance.database;
    try {
      await db.transaction((txn) async {
        Map<int, int> stockChanges = {};
        for (var item in originalInvoice.items) {
          stockChanges[item.productId] = (stockChanges[item.productId] ?? 0) - item.quantity;
        }
        for (var item in updatedInvoiceItems) {
          stockChanges[item.productId] = (stockChanges[item.productId] ?? 0) + item.quantity;
        }
        for (var entry in stockChanges.entries) {
          int variantId = entry.key;
          int quantityChange = entry.value;
          if (quantityChange != 0) {
            int stockAdjustment = (updatedInvoiceData.type == InvoiceType.sale) ? -quantityChange : quantityChange;
            await DatabaseHelper.instance.updateVariantQuantity(variantId, stockAdjustment, txn: txn);
          }
        }
        await txn.delete(DatabaseHelper.tableInvoiceItems, where: '${DatabaseHelper.columnInvoiceIdFk} = ?', whereArgs: [originalInvoice.id!]);
        for (var item in updatedInvoiceItems) {
          final itemMap = item.toMap();
          itemMap.remove('id'); 
          itemMap['invoiceId'] = originalInvoice.id!;
          await txn.insert(DatabaseHelper.tableInvoiceItems, itemMap);
        }
        await DatabaseHelper.instance.updateInvoiceRecord(updatedInvoiceData, txn: txn);
      });

      await productProvider.fetchProducts();
      await fetchInvoices();

      _setLoading(false);
      return null;

    } catch (e) {
      _errorMessage = "فشل تحديث الفاتورة: ${e.toString().replaceFirst("Exception: ", "")}";
      print("[InvoiceProvider] Error updating invoice: $_errorMessage");
      _setLoading(false);
      return _errorMessage;
    }
  }
  
  Future<String?> recordPayment(int invoiceId, double paymentAmountReceived) async {
    if (paymentAmountReceived <= 0) return "مبلغ الدفعة يجب أن يكون أكبر من صفر.";
    _setLoading(true); _clearErrorMessage();
    try {
      Invoice? invoice = await DatabaseHelper.instance.getInvoiceById(invoiceId);
      if (invoice == null || invoice.id == null) {
        _errorMessage = "الفاتورة (معرف $invoiceId) غير موجودة."; _setLoading(false); return _errorMessage;
      }
      if (invoice.paymentStatus == PaymentStatus.paid && invoice.balanceDue <= 0.009) {
        _errorMessage = "الفاتورة مسددة بالكامل."; _setLoading(false); return _errorMessage;
      }
      double newAmountPaidCalc = invoice.amountPaid + paymentAmountReceived;
      PaymentStatus newPaymentStatusCalc;
      if (newAmountPaidCalc >= (invoice.grandTotal - 0.009)) {
        newAmountPaidCalc = invoice.grandTotal; newPaymentStatusCalc = PaymentStatus.paid;
      } else if (newAmountPaidCalc > 0) {
        newPaymentStatusCalc = PaymentStatus.partiallyPaid;
      } else {
        newAmountPaidCalc = (newAmountPaidCalc <= 0) ? 0.0 : newAmountPaidCalc;
        newPaymentStatusCalc = (newAmountPaidCalc <=0) ? PaymentStatus.unpaid : invoice.paymentStatus;
      }
      await DatabaseHelper.instance.updateInvoicePaymentDetails(invoice.id!, newPaymentStatusCalc, newAmountPaidCalc);
      
      final index = _allFetchedInvoices.indexWhere((inv) => inv.id == invoiceId);
      if (index != -1) {
        _allFetchedInvoices[index].amountPaid = newAmountPaidCalc;
        _allFetchedInvoices[index].paymentStatus = newPaymentStatusCalc;
        searchInvoices(_searchQuery);
      } else {
        await fetchInvoices(filter: _currentFilter);
      }
      _setLoading(false);
      return null; 
    } catch (e) {
      _errorMessage = "حدث خطأ أثناء تسجيل الدفعة: $e"; print(_errorMessage);
      _setLoading(false); return _errorMessage;
    }
  }

  Future<Map<String, dynamic>> getTodaysSalesSummary() async {
    try {
      List<Invoice> data = await DatabaseHelper.instance.getTodaysSalesInvoices();
      return {'total': data.fold(0.0, (sum, inv) => sum + inv.grandTotal), 'count': data.length};
    } catch (e) { print("[InvProv] Error getTodaysSalesSummary: $e"); return {'total': 0.0, 'count': 0}; }
  }

  Future<Map<String, dynamic>> getTodaysPurchasesSummary() async {
    try {
      List<Invoice> data = await DatabaseHelper.instance.getTodaysPurchasesInvoices();
      return {'total': data.fold(0.0, (sum, inv) => sum + inv.grandTotal), 'count': data.length};
    } catch (e) { print("[InvProv] Error getTodaysPurchasesSummary: $e"); return {'total': 0.0, 'count': 0}; }
  }

  Future<double> getTotalUnpaidSalesAmount() async {
    try {
      List<Invoice> unpaid = await DatabaseHelper.instance.getUnpaidSalesInvoices();
      double totalDue = unpaid.fold(0.0, (sum, inv) => sum + inv.balanceDue);
      return totalDue;
    } catch (e) { print("[InvProv] Error getTotalUnpaidSalesAmount: $e"); return 0.0; }
  }
  
  Future<double> getTotalUnpaidPurchasesAmount() async {
    try {
      List<Invoice> unpaid = await DatabaseHelper.instance.getUnpaidPurchasesInvoices();
      double totalDue = unpaid.fold(0.0, (sum, inv) => sum + inv.balanceDue);
      return totalDue;
    } catch (e) { print("[InvProv] Error getTotalUnpaidPurchasesAmount: $e"); return 0.0; }
  }

  Future<List<Invoice>> getSalesInvoicesByDateRange(DateTime startDate, DateTime endDate) async {
    _setLoading(true);
    _clearErrorMessage();
    List<Invoice> salesInvoices = [];
    try {
      salesInvoices = await DatabaseHelper.instance.getInvoicesByDateRangeAndType(startDate, endDate, InvoiceType.sale);
    } catch (e) {
      _errorMessage = "حدث خطأ أثناء جلب فواتير المبيعات: $e"; print(_errorMessage);
    }
    _setLoading(false);
    return salesInvoices;
  }
}


// // lib/providers/invoice_provider.dart
// import 'package:flutter/material.dart';
// import 'package:fouad_stock/enum/filter_enums.dart';
// import 'package:fouad_stock/model/invoice_item_model.dart' as db_invoice_item;
// import 'package:fouad_stock/model/invoice_model.dart';
// import '../helpers/db_helpers.dart';
// import 'product_provider.dart';

// class InvoiceProvider with ChangeNotifier {
//   List<Invoice> _allFetchedInvoices = []; // Holds the master list for the current filter
//   List<Invoice> _invoices = []; // Holds the displayed list (can be filtered)
//   bool _isLoading = false;
//   String? _errorMessage;
//   InvoiceListFilter _currentFilter = InvoiceListFilter.none;
//   String _searchQuery = '';

//   List<Invoice> get invoices => _invoices;
//   bool get isLoading => _isLoading;
//   String? get errorMessage => _errorMessage;
//   InvoiceListFilter get currentFilter => _currentFilter;

//   InvoiceProvider() {
//     fetchInvoices();
//   }

//   void _setLoading(bool loading) {
//     if (_isLoading == loading) return;
//     _isLoading = loading;
//     notifyListeners();
//   }

//   void _clearErrorMessage() {
//     if (_errorMessage != null) {
//       _errorMessage = null;
//     }
//   }

//   Future<void> fetchInvoices({InvoiceListFilter? filter}) async {
//     _currentFilter = filter ?? _currentFilter;
//     _isLoading = true;
//     notifyListeners();
//     _clearErrorMessage();
//     try {
//       switch (_currentFilter) {
//         case InvoiceListFilter.todaySales:
//           _allFetchedInvoices = await DatabaseHelper.instance.getTodaysSalesInvoices();
//           break;
//         case InvoiceListFilter.todayPurchases:
//           _allFetchedInvoices = await DatabaseHelper.instance.getTodaysPurchasesInvoices();
//           break;
//         case InvoiceListFilter.unpaidSales:
//           _allFetchedInvoices = await DatabaseHelper.instance.getUnpaidSalesInvoices();
//           break;
//         // --- MODIFIED: Added case for the new filter ---
//         case InvoiceListFilter.unpaidPurchases:
//           _allFetchedInvoices = await DatabaseHelper.instance.getUnpaidPurchasesInvoices();
//           break;
//         case InvoiceListFilter.none:
//         default:
//           _allFetchedInvoices = await DatabaseHelper.instance.getAllInvoices();
//       }
//       // After fetching, apply any existing search query
//       searchInvoices(_searchQuery);
//     } catch (e) {
//       _errorMessage = "حدث خطأ أثناء جلب الفواتير: $e";
//       _invoices = [];
//       _allFetchedInvoices = [];
//       print(_errorMessage);
//     } finally {
//       _isLoading = false;
//       notifyListeners();
//     }
//   }

//   void searchInvoices(String query) {
//     _searchQuery = query;
//     if (_searchQuery.isEmpty) {
//       _invoices = List.from(_allFetchedInvoices);
//     } else {
//       final lowerCaseQuery = _searchQuery.toLowerCase();
//       _invoices = _allFetchedInvoices.where((invoice) {
//         final clientMatch = invoice.clientName?.toLowerCase().contains(lowerCaseQuery) ?? false;
//         final numberMatch = invoice.invoiceNumber.toLowerCase().contains(lowerCaseQuery);
//         return clientMatch || numberMatch;
//       }).toList();
//     }
//     notifyListeners();
//   }

//   Future<Invoice?> getInvoiceById(int invoiceId) async {
//     _clearErrorMessage();
//     _setLoading(true);
//     Invoice? invoice;
//     try {
//       invoice = await DatabaseHelper.instance.getInvoiceById(invoiceId);
//       if (invoice == null) {
//         _errorMessage = "الفاتورة غير موجودة.";
//       }
//     } catch (e) {
//       _errorMessage = "حدث خطأ أثناء جلب تفاصيل الفاتورة: $e";
//       print(_errorMessage);
//       invoice = null; 
//     }
//     _setLoading(false);
//     return invoice;
//   }

//   Future<String> getNextInvoiceNumber(InvoiceType type) async {
//     try {
//       return await DatabaseHelper.instance.getNextInvoiceNumber(type);
//     } catch (e) {
//       print("[InvoiceProvider] Error getNextInvoiceNumber: $e");
//       rethrow;
//     }
//   }

//   Future<String?> createSaleInvoice({
//     required Invoice invoiceData,
//     required List<db_invoice_item.InvoiceItem> invoiceItems,
//     required ProductProvider productProvider,
//   }) async {
//     _setLoading(true);
//     _clearErrorMessage();
//     for (var item in invoiceItems) {
//       final product = await DatabaseHelper.instance.getProductById(item.productId);
//       if (product == null || product.quantity < item.quantity) {
//         _errorMessage = "كمية المنتج ${item.productName} غير كافية (${product?.quantity ?? 0} متوفر).";
//         _setLoading(false);
//         return _errorMessage;
//       }
//     }
//     final db = await DatabaseHelper.instance.database;
//     try {
//       final newInvoiceId = await db.transaction<int>((txn) async {
//         final invoiceId = await DatabaseHelper.instance.insertInvoiceWithItems(invoiceData, invoiceItems, txnPassed: txn);
//         if (invoiceId <= 0) {
//           throw Exception('فشل في حفظ بيانات الفاتورة.');
//         }
//         for (var item in invoiceItems) {
//           String? stockUpdateError = await productProvider.recordUsage(
//               item.productId, item.quantity,
//               refreshList: false, txn: txn);
//           if (stockUpdateError != null) {
//             throw Exception(stockUpdateError);
//           }
//         }
//         return invoiceId;
//       });

//       final newCompleteInvoice = await DatabaseHelper.instance.getInvoiceById(newInvoiceId);
//       if(newCompleteInvoice != null) {
//         _allFetchedInvoices.insert(0, newCompleteInvoice);
//         searchInvoices(_searchQuery);
//       } else {
//         await fetchInvoices(filter: _currentFilter);
//       }
//       await productProvider.fetchProducts();

//       _setLoading(false);
//       return null;
//     } catch (e) {
//       _errorMessage = "حدث خطأ أثناء إنشاء الفاتورة: ${e.toString().replaceFirst("Exception: ", "")}";
//       print("[InvoiceProvider] Error creating sale invoice (transaction rolled back): $_errorMessage");
//       _setLoading(false);
//       return _errorMessage;
//     }
//   }

//   Future<String?> createPurchaseInvoice({
//     required Invoice invoiceData,
//     required List<db_invoice_item.InvoiceItem> invoiceItems,
//     required ProductProvider productProvider,
//   }) async {
//     _setLoading(true);
//     _clearErrorMessage();
//     final db = await DatabaseHelper.instance.database;
//     try {
//       final newInvoiceId = await db.transaction<int>((txn) async {
//         final invoiceId = await DatabaseHelper.instance.insertInvoiceWithItems(invoiceData, invoiceItems, txnPassed: txn);
//         if (invoiceId <= 0) {
//           throw Exception('فشل في حفظ بيانات فاتورة الشراء.');
//         }
//         for (var item in invoiceItems) {
//           String? stockUpdateError = await productProvider.increaseStock(
//               item.productId, item.quantity,
//               refreshList: false, txn: txn);
//           if (stockUpdateError != null) {
//             throw Exception(stockUpdateError);
//           }
//         }
//         return invoiceId;
//       });
      
//       final newCompleteInvoice = await DatabaseHelper.instance.getInvoiceById(newInvoiceId);
//       if(newCompleteInvoice != null) {
//         _allFetchedInvoices.insert(0, newCompleteInvoice);
//         searchInvoices(_searchQuery);
//       } else {
//         await fetchInvoices(filter: _currentFilter);
//       }
//       await productProvider.fetchProducts();

//       _setLoading(false);
//       return null;
//     } catch (e) {
//       _errorMessage = "حدث خطأ جسيم أثناء إنشاء فاتورة الشراء: ${e.toString().replaceFirst("Exception: ", "")}";
//       print("[InvoiceProvider] Error creating purchase invoice (transaction rolled back): $_errorMessage");
//       _setLoading(false);
//       return _errorMessage;
//     }
//   }
  
//   Future<String?> deleteInvoiceAndReconcileStock(Invoice invoice, ProductProvider productProvider) async {
//     if (invoice.id == null) {
//       return "معرف الفاتورة غير صالح.";
//     }
//     _setLoading(true);
//     _clearErrorMessage();
//     final db = await DatabaseHelper.instance.database;
//     try {
//       await db.transaction((txn) async {
//         for (var item in invoice.items) {
//           if (invoice.type == InvoiceType.sale) {
//             await productProvider.increaseStock(item.productId, item.quantity, refreshList: false, txn: txn);
//           } else {
//             await productProvider.recordUsage(item.productId, item.quantity, refreshList: false, txn: txn);
//           }
//         }
//         await DatabaseHelper.instance.deleteInvoiceAndItems(invoice.id!, txn: txn);
//       });
      
//       _allFetchedInvoices.removeWhere((inv) => inv.id == invoice.id);
//       searchInvoices(_searchQuery); 
      
//       await productProvider.fetchProducts();
      
//       _setLoading(false);
//       return null;
//     } catch (e) {
//       _errorMessage = "حدث خطأ أثناء حذف الفاتورة: $e";
//       print("[InvoiceProvider] Error deleting invoice: $_errorMessage");
//       _setLoading(false);
//       return _errorMessage;
//     }
//   }

//   Future<String?> updateInvoice({
//     required Invoice originalInvoice,
//     required Invoice updatedInvoiceData,
//     required List<db_invoice_item.InvoiceItem> updatedInvoiceItems,
//     required ProductProvider productProvider,
//   }) async {
//     _setLoading(true);
//     _clearErrorMessage();

//     final db = await DatabaseHelper.instance.database;

//     try {
//       Map<int, int> stockChanges = {};
//       Map<int, int> originalQuantities = { for (var item in originalInvoice.items) item.productId : item.quantity };
//       Map<int, int> updatedQuantities = {};
//       for (var item in updatedInvoiceItems) {
//         updatedQuantities[item.productId] = (updatedQuantities[item.productId] ?? 0) + item.quantity;
//       }
      
//       final allProductIds = {...originalQuantities.keys, ...updatedQuantities.keys};

//       for (var productId in allProductIds) {
//         int oldQty = originalQuantities[productId] ?? 0;
//         int newQty = updatedQuantities[productId] ?? 0;
//         int change = newQty - oldQty;
//         if (change != 0) {
//           stockChanges[productId] = change;
//         }
//       }

//       if (updatedInvoiceData.type == InvoiceType.sale) {
//         for (var entry in stockChanges.entries) {
//           int productId = entry.key;
//           int quantityChange = entry.value;

//           if (quantityChange > 0) {
//             final product = await DatabaseHelper.instance.getProductById(productId);
//             if (product == null || product.quantity < quantityChange) {
//               throw Exception("الكمية غير كافية للمنتج (ID: $productId). المتوفر: ${product?.quantity ?? 0}, المطلوب زيادة: $quantityChange");
//             }
//           }
//         }
//       }

//       await db.transaction((txn) async {
//         for (var entry in stockChanges.entries) {
//           int productId = entry.key;
//           int quantityChange = entry.value;
//           if (updatedInvoiceData.type == InvoiceType.sale) {
//             await productProvider.recordUsage(productId, quantityChange, txn: txn, refreshList: false);
//           } else {
//             await productProvider.increaseStock(productId, quantityChange, txn: txn, refreshList: false);
//           }
//         }

//         await txn.delete(DatabaseHelper.tableInvoiceItems, where: '${DatabaseHelper.columnInvoiceIdFk} = ?', whereArgs: [originalInvoice.id!]);
//         for (var item in updatedInvoiceItems) {
//           final itemMap = item.toMap();
//           itemMap.remove('id'); 
//           itemMap['invoiceId'] = originalInvoice.id!;
//           await txn.insert(DatabaseHelper.tableInvoiceItems, itemMap);
//         }
        
//         await DatabaseHelper.instance.updateInvoiceRecord(updatedInvoiceData, txn: txn);
//       });

//       final updatedCompleteInvoice = await DatabaseHelper.instance.getInvoiceById(originalInvoice.id!);
//       if (updatedCompleteInvoice != null) {
//         final index = _allFetchedInvoices.indexWhere((inv) => inv.id == originalInvoice.id);
//         if (index != -1) {
//           _allFetchedInvoices[index] = updatedCompleteInvoice;
//           searchInvoices(_searchQuery);
//         } else {
//           await fetchInvoices(filter: _currentFilter);
//         }
//       } else {
//         await fetchInvoices(filter: _currentFilter);
//       }
//       await productProvider.fetchProducts();

//       _setLoading(false);
//       return null;

//     } catch (e) {
//       _errorMessage = "فشل تحديث الفاتورة: ${e.toString().replaceFirst("Exception: ", "")}";
//       print("[InvoiceProvider] Error updating invoice: $_errorMessage");
//       _setLoading(false);
//       return _errorMessage;
//     }
//   }
  
//   Future<String?> recordPayment(int invoiceId, double paymentAmountReceived) async {
//     if (paymentAmountReceived <= 0) return "مبلغ الدفعة يجب أن يكون أكبر من صفر.";
//     _setLoading(true); _clearErrorMessage();
//     try {
//       Invoice? invoice = await DatabaseHelper.instance.getInvoiceById(invoiceId);
//       if (invoice == null || invoice.id == null) {
//         _errorMessage = "الفاتورة (معرف $invoiceId) غير موجودة."; _setLoading(false); return _errorMessage;
//       }
//       if (invoice.paymentStatus == PaymentStatus.paid && invoice.balanceDue <= 0.009) {
//         _errorMessage = "الفاتورة مسددة بالكامل."; _setLoading(false); return _errorMessage;
//       }
//       double newAmountPaidCalc = invoice.amountPaid + paymentAmountReceived;
//       PaymentStatus newPaymentStatusCalc;
//       if (newAmountPaidCalc >= (invoice.grandTotal - 0.009)) {
//         newAmountPaidCalc = invoice.grandTotal; newPaymentStatusCalc = PaymentStatus.paid;
//       } else if (newAmountPaidCalc > 0) {
//         newPaymentStatusCalc = PaymentStatus.partiallyPaid;
//       } else {
//         newAmountPaidCalc = (newAmountPaidCalc <= 0) ? 0.0 : newAmountPaidCalc;
//         newPaymentStatusCalc = (newAmountPaidCalc <=0) ? PaymentStatus.unpaid : invoice.paymentStatus;
//       }
//       await DatabaseHelper.instance.updateInvoicePaymentDetails(invoice.id!, newPaymentStatusCalc, newAmountPaidCalc);
      
//       final index = _allFetchedInvoices.indexWhere((inv) => inv.id == invoiceId);
//       if (index != -1) {
//         _allFetchedInvoices[index].amountPaid = newAmountPaidCalc;
//         _allFetchedInvoices[index].paymentStatus = newPaymentStatusCalc;
//         searchInvoices(_searchQuery);
//       } else {
//         await fetchInvoices(filter: _currentFilter);
//       }
//       _setLoading(false);
//       return null; 
//     } catch (e) {
//       _errorMessage = "حدث خطأ أثناء تسجيل الدفعة: $e"; print(_errorMessage);
//       _setLoading(false); return _errorMessage;
//     }
//   }

//   Future<Map<String, dynamic>> getTodaysSalesSummary() async {
//     try {
//       List<Invoice> data = await DatabaseHelper.instance.getTodaysSalesInvoices();
//       return {'total': data.fold(0.0, (sum, inv) => sum + inv.grandTotal), 'count': data.length};
//     } catch (e) { print("[InvProv] Error getTodaysSalesSummary: $e"); return {'total': 0.0, 'count': 0}; }
//   }

//   Future<Map<String, dynamic>> getTodaysPurchasesSummary() async {
//     try {
//       List<Invoice> data = await DatabaseHelper.instance.getTodaysPurchasesInvoices();
//       return {'total': data.fold(0.0, (sum, inv) => sum + inv.grandTotal), 'count': data.length};
//     } catch (e) { print("[InvProv] Error getTodaysPurchasesSummary: $e"); return {'total': 0.0, 'count': 0}; }
//   }

//   Future<double> getTotalUnpaidSalesAmount() async {
//     try {
//       List<Invoice> unpaid = await DatabaseHelper.instance.getUnpaidSalesInvoices();
//       double totalDue = unpaid.fold(0.0, (sum, inv) => sum + inv.balanceDue);
//       return totalDue;
//     } catch (e) { print("[InvProv] Error getTotalUnpaidSalesAmount: $e"); return 0.0; }
//   }

//   // --- NEW: Method to calculate total unpaid purchases ---
//   Future<double> getTotalUnpaidPurchasesAmount() async {
//     try {
//       List<Invoice> unpaid = await DatabaseHelper.instance.getUnpaidPurchasesInvoices();
//       double totalDue = unpaid.fold(0.0, (sum, inv) => sum + inv.balanceDue);
//       return totalDue;
//     } catch (e) { print("[InvProv] Error getTotalUnpaidPurchasesAmount: $e"); return 0.0; }
//   }

//   Future<List<Invoice>> getSalesInvoicesByDateRange(DateTime startDate, DateTime endDate) async {
//     bool originalLoadingState = _isLoading;
//     if (!_isLoading) _setLoading(true); else if (!originalLoadingState && _isLoading) notifyListeners();
    
//     _clearErrorMessage();
//     List<Invoice> salesInvoices = [];
//     try {
//       final effectiveEndDate = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);
//       salesInvoices = await DatabaseHelper.instance.getInvoicesByDateRangeAndType(startDate, effectiveEndDate, InvoiceType.sale);
//     } catch (e) {
//       _errorMessage = "حدث خطأ أثناء جلب فواتير المبيعات: $e"; print(_errorMessage);
//     }
//     if (!originalLoadingState) _setLoading(false); else if (_errorMessage != null) notifyListeners();
//     return salesInvoices;
//   }
// }
