// lib/providers/product_provider.dart
import 'package:flutter/material.dart';
import 'package:fouad_stock/enum/filter_enums.dart';
import 'package:fouad_stock/model/product_model.dart';
import 'package:sqflite/sqflite.dart';
import '../helpers/db_helpers.dart';

class ProductProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Product> _allProducts = []; // Master list of all products with variants
  List<Product> _displayProducts = []; // Filtered/searched list for the UI

  String _searchQuery = '';
  ProductListFilter _currentFilter = ProductListFilter.none;
  bool _isLoading = false;

  List<Product> get products => _displayProducts;
  bool get isLoading => _isLoading;
  ProductListFilter get currentFilter => _currentFilter;

  // --- NEW: Dynamic category getter ---
  List<String> get categories {
    if (_allProducts.isEmpty) return [];
    final allCategories = _allProducts.map((p) => p.category).toSet();
    return allCategories.toList()..sort();
  }

  ProductProvider() {
    fetchProducts();
  }

  // --- REWRITTEN: Main data fetching logic ---
  Future<void> fetchProducts({ProductListFilter? filter}) async {
    _isLoading = true;
    _currentFilter = filter ?? _currentFilter;
    notifyListeners();

    try {
      _allProducts = await _dbHelper.getAllProductsWithVariants();
      _applyFiltersAndSearch();
    } catch (e) {
      print("[ProductProvider] Error in fetchProducts: $e");
      _allProducts = [];
      _displayProducts = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // --- NEW: Combined filter and search logic ---
  void _applyFiltersAndSearch() {
      // 1. Apply the primary filter (low stock, expired, etc.)
      List<Product> filteredList;
      switch (_currentFilter) {
          case ProductListFilter.lowStock:
              filteredList = _allProducts.where((p) => p.isLowStock).toList();
              break;
          case ProductListFilter.outOfStock:
              filteredList = _allProducts.where((p) => p.isOutOfStock).toList();
              break;
          case ProductListFilter.expired:
              filteredList = _allProducts.where((p) => p.isExpired).toList();
              break;
          case ProductListFilter.nearingExpiry:
              filteredList = _allProducts.where((p) => p.isNearingExpiry).toList();
              break;
          case ProductListFilter.none:
          default:
              filteredList = List.from(_allProducts);
      }

      // 2. Apply the text search query on the already filtered list
      if (_searchQuery.isEmpty) {
          _displayProducts = filteredList;
      } else {
          String lowerCaseQuery = _searchQuery.toLowerCase();
          _displayProducts = filteredList.where((product) {
              return product.name.toLowerCase().contains(lowerCaseQuery) ||
                     (product.productCode?.toLowerCase().contains(lowerCaseQuery) ?? false) ||
                     product.category.toLowerCase().contains(lowerCaseQuery) ||
                     product.variants.any((v) => v.barcode?.toLowerCase().contains(lowerCaseQuery) ?? false);
          }).toList();
      }
  }

  // --- NEW: Public search method ---
  void searchProducts(String query, {ProductListFilter? filter}) {
    _searchQuery = query.trim();
    _currentFilter = filter ?? _currentFilter;
    _applyFiltersAndSearch();
    notifyListeners();
  }


  Future<void> addProduct(Product product) async {
    _isLoading = true;
    notifyListeners();
    try {
      final Product productToInsert = product.copyWith(
        addedDate: DateTime.now(),
        lastUpdated: DateTime.now(),
      );
      await _dbHelper.insertProductWithVariants(productToInsert, product.variants);
      await fetchProducts(filter: _currentFilter);
    } catch (e) {
      print("[ProductProvider] Error adding product: $e");
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateProduct(Product product) async {
    _isLoading = true;
    notifyListeners();
    try {
      final Product productToUpdate = product.copyWith(
        lastUpdated: DateTime.now(),
      );
      await _dbHelper.updateProductWithVariants(productToUpdate, product.variants);
      await fetchProducts(filter: _currentFilter);
    } catch (e) {
      print("[ProductProvider] Error updating product: $e");
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteProduct(int id) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _dbHelper.deleteProduct(id);
      await fetchProducts(filter: _currentFilter);
    } catch (e) {
      print("[ProductProvider] Error deleting product ID $id: $e");
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
  
  Map<String, dynamic>? findProductAndVariantByVariantId(int variantId) {
    for (var product in _allProducts) {
      for (var variant in product.variants) {
        if (variant.id == variantId) {
          return {'product': product, 'variant': variant};
        }
      }
    }
    return null;
  }
  
  Future<String?> recordUsage(
    int variantId,
    int quantityChange, {
    bool refreshList = true,
    Transaction? txn,
  }) async {
    try {
        if(txn != null){
           await _dbHelper.updateVariantQuantity(variantId, -quantityChange, txn: txn);
        } else {
          final db = await _dbHelper.database;
          await db.transaction((txn) async {
            await _dbHelper.updateVariantQuantity(variantId, -quantityChange, txn: txn);
          });
        }
        
        if (refreshList) {
          await fetchProducts(filter: _currentFilter);
        }
        return null; // Success
    } catch (e) {
        print("[ProductProvider] Error in recordUsage for variant ID $variantId: $e");
        return 'حدث خطأ أثناء تسجيل الصرف: ${e.toString()}';
    }
  }

  Future<String?> increaseStock(
    int variantId,
    int quantityChange, {
    bool refreshList = true,
    Transaction? txn,
  }) async {
    try {
        if(txn != null){
           await _dbHelper.updateVariantQuantity(variantId, quantityChange, txn: txn);
        } else {
          final db = await _dbHelper.database;
          await db.transaction((txn) async {
            await _dbHelper.updateVariantQuantity(variantId, quantityChange, txn: txn);
          });
        }

        if (refreshList) {
            await fetchProducts(filter: _currentFilter);
        }
        return null; // Success
    } catch (e) {
        print("[ProductProvider] Error in increaseStock for variant ID $variantId: $e");
        return 'حدث خطأ أثناء زيادة المخزون: ${e.toString()}';
    }
  }

  // --- Getters for Dashboard/Stats ---
  int get totalProductsCount => _allProducts.length;
  int get lowStockProductsCount => _allProducts.where((p) => p.isLowStock).length;
  int get outOfStockProductsCount => _allProducts.where((p) => p.isOutOfStock).length;
  int get expiredProductsCount => _allProducts.where((p) => p.isExpired).length;
  int get nearingExpiryProductsCount => _allProducts.where((p) => p.isNearingExpiry).length;
}





// // lib/providers/product_provider.dart
// import 'package:flutter/material.dart';
// import 'package:sqflite/sqflite.dart'; // For Transaction type
// import '../helpers/db_helpers.dart';
// import '../model/product_model.dart';
// import '../enum/filter_enums.dart'; // Make sure this path is correct

// class ProductProvider with ChangeNotifier {
//   final DatabaseHelper _dbHelper = DatabaseHelper.instance;
//   List<Product> _sourceProducts = [];
//   List<Product> _displayProducts = [];

//   String _searchQuery = '';
//   ProductListFilter _currentFilter = ProductListFilter.none;
//   bool _isLoading = false;

//   List<Product> get products => _displayProducts;
//   bool get isLoading => _isLoading;
//   ProductListFilter get currentFilter => _currentFilter;

//   // --- MODIFIED: Dynamic categories getter ---
//   // This now generates a unique list of categories from the actual products
//   List<String> get categories {
//     if (_sourceProducts.isEmpty) {
//       return [];
//     }
//     // Use a Set to get unique category names, then convert back to a list and sort it.
//     final categorySet = <String>{};
//     for (var product in _sourceProducts) {
//       categorySet.add(product.category);
//     }
//     final sortedCategories = categorySet.toList()..sort();
//     return sortedCategories;
//   }

//   ProductProvider() {
//     fetchProducts(filter: ProductListFilter.none);
//   }

//   Future<void> _updateProductLists({
//     ProductListFilter? newBaseFilter,
//     String? newSearchQuery,
//   }) async {
//     _isLoading = true;
//     notifyListeners();

//     _currentFilter = newBaseFilter ?? _currentFilter;
//     _searchQuery = (newSearchQuery ?? _searchQuery).trim();

//     try {
//       if (_searchQuery.isEmpty) {
//         _sourceProducts = await _dbHelper.getProductsFiltered(
//           filter: _currentFilter,
//         );
//       } else {
//         _sourceProducts = await _dbHelper.searchProducts(
//           _searchQuery,
//           filter: _currentFilter,
//         );
//       }
//       _applyClientSideSearch(); // This will update _displayProducts
//     } catch (e) {
//       print("[ProductProvider] Error in _updateProductLists: $e");
//       _sourceProducts = [];
//       _displayProducts = [];
//     } finally {
//       _isLoading = false;
//       notifyListeners();
//     }
//   }

//   Future<void> fetchProducts({ProductListFilter? filter}) async {
//     await _updateProductLists(newBaseFilter: filter, newSearchQuery: _searchQuery);
//   }

//   Future<void> searchProducts(String query, {ProductListFilter? filter}) async {
//     await _updateProductLists(
//       newBaseFilter: filter ?? _currentFilter,
//       newSearchQuery: query,
//     );
//   }

//   void _applyClientSideSearch() {
//     if (_searchQuery.isEmpty) {
//       _displayProducts = List.from(_sourceProducts);
//     } else {
//       String lowerCaseQuery = _searchQuery.toLowerCase();
//       _displayProducts = _sourceProducts
//           .where(
//             (product) =>
//                 product.name.toLowerCase().contains(lowerCaseQuery) ||
//                 (product.productCode?.toLowerCase().contains(lowerCaseQuery) ??
//                     false) ||
//                 (product.barcode?.toLowerCase().contains(lowerCaseQuery) ??
//                     false) ||
//                 product.category.toLowerCase().contains(lowerCaseQuery),
//           )
//           .toList();
//     }
//   }

//   Future<void> addProduct(Product product) async {
//     _isLoading = true;
//     notifyListeners();
//     try {
//       final Product productToInsert = product.copyWith(
//         addedDate: product.addedDate ?? DateTime.now(),
//         lastUpdated: product.lastUpdated ?? DateTime.now(),
//       );
//       await _dbHelper.insertProduct(productToInsert);
//       await fetchProducts(filter: _currentFilter);
//     } catch (e) {
//       print("[ProductProvider] Error adding product: $e");
//       _isLoading = false;
//       notifyListeners();
//       rethrow;
//     }
//   }

//   Future<void> updateProduct(Product product) async {
//     _isLoading = true;
//     notifyListeners();
//     try {
//       final Product productToUpdate = product.copyWith(
//         lastUpdated: DateTime.now(),
//       );
//       await _dbHelper.updateProduct(productToUpdate);
//       await fetchProducts(filter: _currentFilter);
//     } catch (e) {
//       print("[ProductProvider] Error updating product: $e");
//       _isLoading = false;
//       notifyListeners();
//       rethrow;
//     }
//   }

//   Future<void> deleteProduct(int id) async {
//     _isLoading = true;
//     notifyListeners();
//     try {
//       await _dbHelper.deleteProduct(id);
//       await fetchProducts(filter: _currentFilter);
//     } catch (e) {
//       print("[ProductProvider] Error deleting product ID $id: $e");
//       _isLoading = false;
//       notifyListeners();
//       rethrow;
//     }
//   }

//   Product? getProductByIdFromCache(int id) {
//     try {
//       return _displayProducts.firstWhere((p) => p.id == id);
//     } catch (e) {
//       try {
//           return _sourceProducts.firstWhere((p) => p.id == id);
//       } catch (e) {
//           print("[ProductProvider] Product with ID $id not found in cache.");
//           return null;
//       }
//     }
//   }

//   Future<String?> recordUsage(
//     int productId,
//     int quantityTaken, {
//     bool refreshList = true,
//     Transaction? txn,
//   }) async {
//     if (quantityTaken <= 0) {
//       return 'الكمية المصروفة يجب أن تكون أكبر من صفر.';
//     }

//     try {
//       Product? product = await _dbHelper.getProductById(productId, txn: txn);

//       if (product!.quantity < quantityTaken) {
//         return 'الكمية المطلوبة أكبر من المتوفر (${product.quantity}).';
//       }

//       final int newQuantity = product.quantity - quantityTaken;
//       final Product updatedProduct = product.copyWith(
//         quantity: newQuantity,
//         lastUpdated: DateTime.now(),
//       );

//       await _dbHelper.updateProduct(updatedProduct, txn: txn);

//       if (refreshList) {
//         await fetchProducts(filter: _currentFilter);
//       } else {
//         final indexInSource = _sourceProducts.indexWhere((p) => p.id == productId);
//         if (indexInSource != -1) {
//           _sourceProducts[indexInSource] = updatedProduct;
//         }
//         final indexInDisplay = _displayProducts.indexWhere((p) => p.id == productId);
//         if (indexInDisplay != -1) {
//           _displayProducts[indexInDisplay] = updatedProduct;
//         }
//         if(!refreshList) notifyListeners();
//       }
//       return null; // Success
//     } catch (e) {
//       print("[ProductProvider] Error in recordUsage for product ID $productId: $e");
//       return 'حدث خطأ أثناء تسجيل الصرف: ${e.toString()}';
//     }
//   }

//   Future<String?> increaseStock(
//     int productId,
//     int quantityAdded, {
//     bool refreshList = true,
//     Transaction? txn,
//   }) async {
//     if (quantityAdded <= 0) {
//       return 'الكمية المضافة يجب أن تكون أكبر من صفر.';
//     }

//     try {
//       Product? product = await _dbHelper.getProductById(productId, txn: txn);

//       final int newQuantity = product!.quantity + quantityAdded;
//       final Product updatedProduct = product.copyWith(
//         quantity: newQuantity,
//         lastUpdated: DateTime.now(),
//       );

//       await _dbHelper.updateProduct(updatedProduct, txn: txn);

//       if (refreshList) {
//         await fetchProducts(filter: _currentFilter);
//       } else {
//         final indexInSource = _sourceProducts.indexWhere((p) => p.id == productId);
//         if (indexInSource != -1) {
//           _sourceProducts[indexInSource] = updatedProduct;
//         }
//         final indexInDisplay = _displayProducts.indexWhere((p) => p.id == productId);
//         if (indexInDisplay != -1) {
//           _displayProducts[indexInDisplay] = updatedProduct;
//         }
//         if(!refreshList) notifyListeners();
//       }
//       return null;
//     } catch (e) {
//       print("[ProductProvider] Error in increaseStock for product ID $productId: $e");
//       return 'حدث خطأ أثناء زيادة المخزون: ${e.toString()}';
//     }
//   }

//   int get totalProductsCount {
//     return _sourceProducts.length;
//   }
//   int get lowStockProductsCount {
//     return _sourceProducts.where((p) => p.isLowStock).length;
//   }
//   int get outOfStockProductsCount {
//     return _sourceProducts.where((p) => p.isOutOfStock).length;
//   }
//   int get expiredProductsCount {
//     return _sourceProducts.where((p) => p.isExpired).length;
//   }
//   int get nearingExpiryProductsCount {
//     return _sourceProducts.where((p) => p.isNearingExpiry).length;
//   }
// }
