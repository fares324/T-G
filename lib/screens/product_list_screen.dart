// lib/screens/products_list_screen.dart
import 'package:flutter/material.dart';
import 'package:fouad_stock/enum/filter_enums.dart';
import 'package:fouad_stock/model/product_model.dart';
import 'package:fouad_stock/model/product_variant_model.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import 'add_edit_product_screen.dart';
import 'store_settings_screen.dart';

class ProductsListScreen extends StatefulWidget {
  final ProductListFilter? filter;
  final String? appBarTitle;

  const ProductsListScreen({
    super.key,
    this.filter,
    this.appBarTitle,
  });

  @override
  State<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends State<ProductsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _effectiveAppBarTitle = 'قائمة المنتجات';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _updateTitleAndFetchInitialProducts();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final searchTerm = _searchController.text;
    if (_isSearching != searchTerm.isNotEmpty) {
      setState(() { _isSearching = searchTerm.isNotEmpty; });
    }
    Provider.of<ProductProvider>(context, listen: false).searchProducts(searchTerm, filter: widget.filter);
  }

  void _updateTitleAndFetchInitialProducts() {
    if (widget.appBarTitle != null && widget.appBarTitle!.isNotEmpty) {
      _effectiveAppBarTitle = widget.appBarTitle!;
    } else {
      switch (widget.filter) {
        case ProductListFilter.lowStock: _effectiveAppBarTitle = 'منتجات على وشك النفاذ'; break;
        case ProductListFilter.outOfStock: _effectiveAppBarTitle = 'منتجات نفذت كميتها'; break;
        case ProductListFilter.expired: _effectiveAppBarTitle = 'منتجات منتهية الصلاحية'; break;
        case ProductListFilter.nearingExpiry: _effectiveAppBarTitle = 'منتجات قارب انتهاء صلاحيتها'; break;
        default: _effectiveAppBarTitle = 'كل المنتجات';
      }
    }
    Future.microtask(() => Provider.of<ProductProvider>(context, listen: false).fetchProducts(filter: widget.filter));
  }

  Future<void> _refreshProducts() async {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    await productProvider.fetchProducts(filter: widget.filter);
    if (_isSearching) {
      productProvider.searchProducts(_searchController.text, filter: widget.filter);
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  // <-- CHANGED: This function now waits for a result and refreshes the list
  void _navigateToAddEditProductScreen(BuildContext context, {Product? product}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (ctx) => AddEditProductScreen(product: product)),
    );

    if (result == true && mounted) {
      _refreshProducts();
    }
  }

  Future<void> _confirmDelete(BuildContext context, Product product) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          title: Text('تأكيد الحذف', style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary, fontFamily: 'Cairo')),
          content: Text('هل أنت متأكد أنك تريد حذف منتج "${product.name}" وكل متغيراته؟', style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'Cairo')),
          actions: <Widget>[
            TextButton(
              child: Text('إلغاء', style: TextStyle(color: theme.textTheme.bodyMedium?.color ?? Colors.black, fontFamily: 'Cairo')),
              onPressed: () => Navigator.of(dialogCtx).pop(false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.error),
              child: const Text('حذف', style: TextStyle(fontFamily: 'Cairo')),
              onPressed: () => Navigator.of(dialogCtx).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true && product.id != null) {
      try {
        await Provider.of<ProductProvider>(context, listen: false).deleteProduct(product.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف المنتج بنجاح', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل حذف المنتج: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: theme.colorScheme.error),
          );
        }
      }
    }
  }

  Future<void> _showRecordVariantUsageDialog(BuildContext context, Product parent, ProductVariant variant) async {
    final theme = Theme.of(context);
    final qtyCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('تسجيل استخدام: ${parent.name} (${variant.displayName})', style: theme.textTheme.titleLarge),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('الكمية الحالية: ${variant.quantity} ${parent.unitOfMeasure}', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 15),
                TextFormField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(labelText: 'الكمية المصروفة*'),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'الرجاء إدخال الكمية.';
                    final int? qty = int.tryParse(value);
                    if (qty == null || qty <= 0) return 'الكمية يجب أن تكون أكبر من صفر.';
                    if (qty > variant.quantity) return 'الكمية أكبر من المتوفر بالمخزون.';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('إلغاء'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              child: const Text('حفظ'),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final int quantityTaken = int.parse(qtyCtrl.text);
                  final productProvider = Provider.of<ProductProvider>(context, listen: false);
                  
                  String? result = await productProvider.recordUsage(variant.id!, -quantityTaken);
                  
                  if(context.mounted) {
                    Navigator.of(dialogContext).pop();
                    if (result == null) {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل الصرف بنجاح'), backgroundColor: Colors.green));
                    } else {
                       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل تسجيل الصرف: $result'), backgroundColor: Colors.red));
                    }
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_effectiveAppBarTitle, style: const TextStyle(fontFamily: 'Cairo')),
        actions: [
          IconButton(icon: const Icon(Icons.add_box_outlined), tooltip: 'إضافة منتج جديد', onPressed: () => _navigateToAddEditProductScreen(context)),
          IconButton(icon: const Icon(Icons.settings_outlined), tooltip: 'إعدادات التطبيق', onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const StoreSettingsScreen()))),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              textAlign: TextAlign.right,
              style: TextStyle(fontFamily: 'Cairo', color: theme.appBarTheme.titleTextStyle?.color ?? theme.colorScheme.onPrimary),
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم, الكود, أو الصنف...',
                hintStyle: TextStyle(fontFamily: 'Cairo', color: (theme.appBarTheme.titleTextStyle?.color ?? theme.colorScheme.onPrimary).withOpacity(0.7)),
                prefixIcon: Icon(Icons.search, color: (theme.appBarTheme.titleTextStyle?.color ?? theme.colorScheme.onPrimary).withOpacity(0.7)),
                suffixIcon: _isSearching ? IconButton(icon: Icon(Icons.clear, color: (theme.appBarTheme.titleTextStyle?.color ?? theme.colorScheme.onPrimary).withOpacity(0.7)), onPressed: () => _searchController.clear()) : null,
                filled: true,
                fillColor: theme.brightness == Brightness.dark ? theme.cardColor.withOpacity(0.5) : theme.colorScheme.surface.withOpacity(0.15),
                contentPadding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 16.0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(25.0), borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshProducts,
        child: Consumer<ProductProvider>(
          builder: (ctx, provider, _) {
            if (provider.isLoading && provider.products.isEmpty) {
              return Center(child: CircularProgressIndicator());
            }
            if (provider.products.isEmpty) {
              return Center(child: Text(_isSearching ? 'لا توجد منتجات تطابق بحثك.' : 'لا توجد منتجات. قم بإضافة البعض!', style: TextStyle(fontFamily: 'Cairo')));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: provider.products.length,
              itemBuilder: (listCtx, i) { 
                return ProductParentCard(
                  key: ValueKey(provider.products[i].id.toString() + provider.products[i].variants.hashCode.toString()),
                  product: provider.products[i],
                  onDelete: () => _confirmDelete(context, provider.products[i]),
                  onEdit: () => _navigateToAddEditProductScreen(context, product: provider.products[i]),
                  onRecordUsage: (variant) => _showRecordVariantUsageDialog(context, provider.products[i], variant),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class ProductParentCard extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(ProductVariant) onRecordUsage;

  const ProductParentCard({
    super.key, 
    required this.product,
    required this.onEdit,
    required this.onDelete,
    required this.onRecordUsage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final numberFormatter = NumberFormat.decimalPattern('ar');
    final currencyFormatter = NumberFormat.currency(locale: 'ar', symbol: 'ج.م', decimalDigits: 2);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: ExpansionTile(
        key: PageStorageKey<String>('product_${product.id}'),
        title: Text(product.name, style: theme.textTheme.titleLarge),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الصنف: ${product.category}', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary)),
            Text('إجمالي الكمية: ${numberFormatter.format(product.totalQuantity)} ${product.unitOfMeasure}', style: theme.textTheme.bodyMedium),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: Icon(Icons.edit_outlined, color: theme.colorScheme.secondary), tooltip: 'تعديل', onPressed: onEdit),
            IconButton(icon: Icon(Icons.delete_outline, color: theme.colorScheme.error), tooltip: 'حذف', onPressed: onDelete),
          ],
        ),
        childrenPadding: const EdgeInsets.all(16).copyWith(top: 0),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: product.variants.map((variant) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(variant.displayName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('الكمية: ${numberFormatter.format(variant.quantity)}', style: theme.textTheme.bodyMedium),
                      Text('سعر البيع: ${currencyFormatter.format(variant.sellingPrice)}', style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.remove_shopping_cart_outlined, color: theme.colorScheme.primary),
                  tooltip: 'صرف',
                  onPressed: variant.quantity > 0 ? () => onRecordUsage(variant) : null,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}



// // lib/screens/products_list_screen.dart
// import 'package:flutter/material.dart';
// import 'package:fouad_stock/enum/filter_enums.dart';
// import 'package:fouad_stock/model/product_model.dart';
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
// import '../providers/product_provider.dart';
// import 'add_edit_product_screen.dart';
// import 'new_sale_invoice_screen.dart';
// import 'invoices_list_screen.dart'; 
// import 'store_settings_screen.dart'; 

// class ProductsListScreen extends StatefulWidget {
//   final ProductListFilter? filter;
//   final String? appBarTitle;

//   const ProductsListScreen({
//     super.key,
//     this.filter,
//     this.appBarTitle,
//   });

//   @override
//   State<ProductsListScreen> createState() => _ProductsListScreenState();
// }

// class _ProductsListScreenState extends State<ProductsListScreen> {
//   final TextEditingController _searchController = TextEditingController();
//   late DateFormat _arabicDateFormat;
//   String _effectiveAppBarTitle = 'قائمة المنتجات';
//   bool _isSearching = false;

//   @override
//   void initState() {
//     super.initState();
//     _arabicDateFormat = DateFormat.yMMMd('ar');
//     _updateTitleAndFetchInitialProducts();
//     _searchController.addListener(_onSearchChanged);
//   }

//   void _onSearchChanged() {
//     final searchTerm = _searchController.text;
//     if (_isSearching != searchTerm.isNotEmpty) {
//       setState(() { _isSearching = searchTerm.isNotEmpty; });
//     }
//     Provider.of<ProductProvider>(context, listen: false).searchProducts(searchTerm, filter: widget.filter);
//   }

//   void _updateTitleAndFetchInitialProducts() {
//     if (widget.appBarTitle != null && widget.appBarTitle!.isNotEmpty) {
//       _effectiveAppBarTitle = widget.appBarTitle!;
//     } else {
//       switch (widget.filter) {
//         case ProductListFilter.lowStock: _effectiveAppBarTitle = 'منتجات على وشك النفاذ'; break;
//         case ProductListFilter.outOfStock: _effectiveAppBarTitle = 'منتجات نفذت كميتها'; break;
//         case ProductListFilter.expired: _effectiveAppBarTitle = 'منتجات منتهية الصلاحية'; break;
//         case ProductListFilter.nearingExpiry: _effectiveAppBarTitle = 'منتجات قارب انتهاء صلاحيتها'; break;
//         default: _effectiveAppBarTitle = 'كل المنتجات';
//       }
//     }
//     Future.microtask(() => Provider.of<ProductProvider>(context, listen: false).fetchProducts(filter: widget.filter));
//   }

//   Future<void> _refreshProducts() async {
//     final productProvider = Provider.of<ProductProvider>(context, listen: false);
//     if (_isSearching) {
//       await productProvider.searchProducts(_searchController.text, filter: widget.filter);
//     } else {
//       await productProvider.fetchProducts(filter: widget.filter);
//     }
//   }

//   @override
//   void dispose() {
//     _searchController.removeListener(_onSearchChanged);
//     _searchController.dispose();
//     super.dispose();
//   }

//   void _navigateToAddEditProductScreen(BuildContext context, {Product? product}) {
//     Navigator.of(context).push(
//       MaterialPageRoute(builder: (ctx) => AddEditProductScreen(product: product)),
//     ).then((_) { _refreshProducts(); });
//   }

//   Future<void> _confirmDelete(BuildContext context, int productId) async {
//     final theme = Theme.of(context);
//     final confirmed = await showDialog<bool>(
//       context: context,
//       builder: (BuildContext dialogCtx) {
//         return AlertDialog(
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
//           title: Text('تأكيد الحذف', style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary, fontFamily: 'Cairo')),
//           content: Text('هل أنت متأكد أنك تريد حذف هذا المنتج؟', style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'Cairo')),
//           actions: <Widget>[
//             TextButton(
//               child: Text('إلغاء', style: TextStyle(color: theme.textTheme.bodyMedium?.color ?? Colors.black, fontFamily: 'Cairo')),
//               onPressed: () => Navigator.of(dialogCtx).pop(false),
//             ),
//             ElevatedButton(
//               style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.error),
//               child: const Text('حذف', style: TextStyle(fontFamily: 'Cairo')),
//               onPressed: () => Navigator.of(dialogCtx).pop(true),
//             ),
//           ],
//         );
//       },
//     );

//     if (confirmed == true) {
//       try {
//         await Provider.of<ProductProvider>(context, listen: false).deleteProduct(productId);
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text('تم حذف المنتج بنجاح', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green),
//           );
//         }
//       } catch (e) {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('فشل حذف المنتج: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: theme.colorScheme.error),
//           );
//         }
//       }
//     }
//   }

//   Future<void> _showRecordUsageDialog(BuildContext context, Product product) async {
//     final theme = Theme.of(context);
//     final TextEditingController qtyCtrl = TextEditingController();
//     final GlobalKey<FormState> formKey = GlobalKey<FormState>();
//     String? errorMessage;

//     return showDialog<void>(
//       context: context,
//       barrierDismissible: true,
//       builder: (BuildContext dialogContext) {
//         return StatefulBuilder(
//           builder: (context, setStateDialog) {
//             return AlertDialog(
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
//               title: Text('تسجيل استخدام: ${product.name}', style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary, fontSize: 18, fontFamily: 'Cairo')),
//               content: SingleChildScrollView(
//                   child: Form(
//                     key: formKey,
//                     child: ListBody(
//                       children: <Widget>[
//                         Text('الكمية الحالية: ${product.quantity} ${product.unitOfMeasure}', style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'Cairo')),
//                         const SizedBox(height: 15),
//                         TextFormField(
//                           controller: qtyCtrl,
//                           keyboardType: TextInputType.number,
//                           textAlign: TextAlign.right,
//                           style: const TextStyle(fontFamily: 'Cairo'),
//                           decoration: InputDecoration(
//                             labelText: 'الكمية المصروفة/المستخدمة*',
//                             hintText: 'أدخل الكمية هنا',
//                             labelStyle: const TextStyle(fontFamily: 'Cairo'),
//                             hintStyle: const TextStyle(fontFamily: 'Cairo'),
//                             border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
//                           ),
//                           validator: (value) {
//                             if (value == null || value.isEmpty) return 'الرجاء إدخال الكمية.';
//                             final int? qty = int.tryParse(value);
//                             if (qty == null) return 'الرجاء إدخال رقم صحيح.';
//                             if (qty <= 0) return 'الكمية يجب أن تكون أكبر من صفر.';
//                             if (qty > product.quantity) return 'الكمية أكبر من المتوفر بالمخزون.';
//                             return null;
//                           },
//                         ),
//                         if (errorMessage != null) ...[
//                           const SizedBox(height: 10),
//                           Text(errorMessage!, style: TextStyle(color: theme.colorScheme.error, fontSize: 13, fontFamily: 'Cairo'), textAlign: TextAlign.right),
//                         ]
//                       ],
//                     ),
//                   ),
//                 ),
//                 actionsAlignment: MainAxisAlignment.spaceBetween,
//                 actionsPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
//                 actions: <Widget>[
//                     TextButton(child: Text('إلغاء', style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontFamily: 'Cairo')),
//                       onPressed: () => Navigator.of(dialogContext).pop()),
//                     ElevatedButton(child: const Text('حفظ الصرف', style: TextStyle(fontFamily: 'Cairo')),
//                       onPressed: () async {
//                         if (formKey.currentState!.validate()) {
//                           final int quantityTaken = int.parse(qtyCtrl.text);
//                           final productProvider = Provider.of<ProductProvider>(context, listen: false);
//                           setStateDialog(() { errorMessage = null; });
//                           String? result = await productProvider.recordUsage(product.id!, quantityTaken, refreshList: true);
//                           if (mounted) {
//                             setStateDialog(() { errorMessage = result; });
//                                                     }
//                         }
//                       }),
//                 ],
//             );
//           }
//         );
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(_effectiveAppBarTitle, style: const TextStyle(fontFamily: 'Cairo')),
//         actions: [
//           IconButton(icon: const Icon(Icons.receipt_long_outlined), tooltip: 'عرض الفواتير', onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const InvoicesListScreen()))),
//           IconButton(icon: const Icon(Icons.add_box_outlined), tooltip: 'إضافة منتج جديد', onPressed: () => _navigateToAddEditProductScreen(context)),
//           IconButton(icon: const Icon(Icons.settings_outlined), tooltip: 'إعدادات التطبيق', onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const StoreSettingsScreen()))),
//         ],
//         bottom: PreferredSize(
//           preferredSize: const Size.fromHeight(60.0),
//           child: Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
//             child: TextField(
//               controller: _searchController,
//               textAlign: TextAlign.right,
//               style: TextStyle(fontFamily: 'Cairo', color: theme.appBarTheme.titleTextStyle?.color ?? theme.colorScheme.onPrimary),
//               decoration: InputDecoration(
//                 hintText: 'ابحث بالاسم, الكود, أو الصنف...',
//                 hintStyle: TextStyle(fontFamily: 'Cairo', color: (theme.appBarTheme.titleTextStyle?.color ?? theme.colorScheme.onPrimary).withOpacity(0.7)),
//                 prefixIcon: Icon(Icons.search, color: (theme.appBarTheme.titleTextStyle?.color ?? theme.colorScheme.onPrimary).withOpacity(0.7)),
//                 suffixIcon: _searchController.text.isNotEmpty ? IconButton(icon: Icon(Icons.clear, color: (theme.appBarTheme.titleTextStyle?.color ?? theme.colorScheme.onPrimary).withOpacity(0.7)), onPressed: () => _searchController.clear()) : null,
//                 filled: true,
//                 fillColor: theme.brightness == Brightness.dark ? theme.cardColor.withOpacity(0.5) : theme.colorScheme.surface.withOpacity(0.15),
//                 contentPadding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 16.0),
//                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(25.0), borderSide: BorderSide.none),
//                 focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(25.0), borderSide: BorderSide(color: theme.colorScheme.primary.withOpacity(0.5), width: 1)),
//               ),
//             ),
//           ),
//         ),
//       ),
//       body: RefreshIndicator(
//         onRefresh: _refreshProducts, color: theme.primaryColor, backgroundColor: theme.cardColor,
//         child: Consumer<ProductProvider>(
//           builder: (ctx, provider, _) {
//             if (provider.isLoading && provider.products.isEmpty && !_isSearching) {
//               return Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary)));
//             }
//             if (provider.products.isEmpty && (_isSearching || (widget.filter != null && widget.filter != ProductListFilter.none))) {
//                 return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
//                     Icon(_isSearching ? Icons.search_off_rounded : Icons.filter_list_off_rounded, size: 80, color: Colors.grey.shade400),
//                     const SizedBox(height: 16),
//                     Text(_isSearching ? 'لا توجد منتجات تطابق بحثك عن "${_searchController.text}".' : 'لا توجد منتجات تطابق الفلتر الحالي.',
//                       style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600, fontFamily: 'Cairo'), textAlign: TextAlign.center),
//                   ],),);
//             }
//             if (provider.products.isEmpty && !_isSearching && (widget.filter == null || widget.filter == ProductListFilter.none)) {
//               return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
//                       Icon(Icons.inventory_rounded, size: 80, color: Colors.grey.shade400), // Changed Icon
//                       const SizedBox(height: 16),
//                       Text('لا توجد منتجات. قم بإضافة البعض!', style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600, fontFamily: 'Cairo'), textAlign: TextAlign.center),
//                       const SizedBox(height: 20),
//                       ElevatedButton.icon(icon: const Icon(Icons.add), label: const Text('إضافة أول منتج', style: TextStyle(fontFamily: 'Cairo')), onPressed: () => _navigateToAddEditProductScreen(context))
//                     ],),);
//             }
//             return ListView.builder(
//               padding: const EdgeInsets.only(top: 8.0, bottom: 80.0), 
//               itemCount: provider.products.length,
//               itemBuilder: (listCtx, i) { 
//                 final product = provider.products[i];
                
//                 final bool isOutOfStock = product.isOutOfStock;
//                 final bool isLowStock = product.isLowStock;
//                 final bool isExpired = product.isExpired;
//                 final bool isNearingExpiry = product.isNearingExpiry;
//                 final bool hasExpiryDate = product.expiryDate.year < 9000; // Check for our placeholder date
//                 Color cardBorderColor = Colors.transparent;
//                 String stockStatusText = '';
//                 TextStyle stockStatusStyle = Theme.of(listCtx).textTheme.bodySmall!.copyWith(fontWeight: FontWeight.bold, fontFamily: 'Cairo');
//                 Color? stockStatusBgColor;

//                 if (isOutOfStock) {
//                   cardBorderColor = Theme.of(listCtx).colorScheme.error.withOpacity(0.7); stockStatusText = 'نفذ المخزون!';
//                   stockStatusStyle = stockStatusStyle.copyWith(color: Theme.of(listCtx).colorScheme.error);
//                   stockStatusBgColor = Theme.of(listCtx).colorScheme.error.withOpacity(0.1);
//                 } else if (isExpired) {
//                   cardBorderColor = Theme.of(listCtx).colorScheme.error.withOpacity(0.5);
//                 } else if (isLowStock) {
//                   cardBorderColor = (Theme.of(listCtx).colorScheme.tertiaryContainer ?? Colors.amber.shade100).withOpacity(0.9);
//                   stockStatusText = 'كمية منخفضة!';
//                   stockStatusStyle = stockStatusStyle.copyWith(color: Theme.of(listCtx).colorScheme.onTertiaryContainer ?? Colors.amber.shade900);
//                   stockStatusBgColor = (Theme.of(listCtx).colorScheme.tertiaryContainer ?? Colors.amber.shade100).withOpacity(0.2);
//                 } else if (isNearingExpiry && !isExpired && hasExpiryDate) { 
//                     cardBorderColor = (Theme.of(listCtx).colorScheme.surfaceContainerHighest ?? Colors.orange.shade300).withOpacity(0.7);
//                     if (stockStatusText.isEmpty) {
//                         stockStatusText = 'قارب على الانتهاء';
//                         stockStatusStyle = stockStatusStyle.copyWith(color: Colors.orange.shade800);
//                         stockStatusBgColor = Colors.orange.withOpacity(0.1);
//                     }
//                 }
                
//                 return Card(
//                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0), side: BorderSide(color: cardBorderColor, width: cardBorderColor != Colors.transparent ? 1.5 : 0.0)),
//                   elevation: cardBorderColor != Colors.transparent ? 2.5 : 1.5,
//                   margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
//                   child: Padding(padding: const EdgeInsets.all(12.0),
//                     child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//                         Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
//                             Expanded(child: Text(product.name, style: Theme.of(listCtx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(listCtx).colorScheme.onSurface, fontFamily: 'Cairo'), maxLines: 2, overflow: TextOverflow.ellipsis)),
//                             const SizedBox(width: 8),
//                             Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//                               decoration: BoxDecoration(color: (Theme.of(listCtx).colorScheme.secondaryContainer ?? Colors.teal.shade50).withOpacity(0.8), borderRadius: BorderRadius.circular(20.0)),
//                               child: Text(NumberFormat.currency(locale: 'ar', symbol: 'ج.م', decimalDigits: 2).format(product.sellingPrice),
//                                 style: Theme.of(listCtx).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(listCtx).colorScheme.onSecondaryContainer ?? Theme.of(listCtx).colorScheme.secondary, fontFamily: 'Cairo')))]),
//                         const SizedBox(height: 10),
//                         Text('الصنف: ${product.category}', style: Theme.of(listCtx).textTheme.bodyMedium?.copyWith(color: Theme.of(listCtx).colorScheme.onSurface.withOpacity(0.7), fontFamily: 'Cairo')),
//                         const SizedBox(height: 6),
//                         Row(children: [ Icon(Icons.inventory_2_outlined, size: 16, color: Theme.of(listCtx).colorScheme.onSurface.withOpacity(0.6)), const SizedBox(width: 6),
//                             Text('المتبقي: ${NumberFormat.decimalPattern('ar').format(product.quantity)} ${product.unitOfMeasure}',
//                               style: Theme.of(listCtx).textTheme.bodyMedium?.copyWith(fontWeight: isOutOfStock || isLowStock ? FontWeight.bold : FontWeight.normal, color: isOutOfStock ? Theme.of(listCtx).colorScheme.error : Theme.of(listCtx).colorScheme.onSurface, fontFamily: 'Cairo'))]),
//                         const SizedBox(height: 6),
//                         // --- MODIFIED: Conditionally show expiry date ---
//                         if (hasExpiryDate)
//                           Row(children: [ Icon(Icons.date_range_outlined, size: 16, color: Theme.of(listCtx).colorScheme.onSurface.withOpacity(0.6)), const SizedBox(width: 6),
//                               Text('الانتهاء: ${_arabicDateFormat.format(product.expiryDate)}',
//                                 style: Theme.of(listCtx).textTheme.bodyMedium?.copyWith(color: isExpired ? Theme.of(listCtx).colorScheme.error : (isNearingExpiry ? (Theme.of(listCtx).colorScheme.tertiary != Colors.transparent ? Theme.of(listCtx).colorScheme.tertiary : Colors.orange.shade700) : Theme.of(listCtx).colorScheme.onSurface), fontWeight: isExpired || isNearingExpiry ? FontWeight.bold : FontWeight.normal, fontFamily: 'Cairo'))]),
//                         if (isExpired) Padding(padding: const EdgeInsets.only(top: 8.0), child: Align(alignment: Alignment.centerRight, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Theme.of(listCtx).colorScheme.error.withOpacity(0.15), borderRadius: BorderRadius.circular(6)), child: Text("منتهي الصلاحية!", style: TextStyle(color: Theme.of(listCtx).colorScheme.error, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo')))))
//                         else if (stockStatusText.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8.0), child: Align(alignment: Alignment.centerRight, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: stockStatusBgColor ?? stockStatusStyle.color?.withOpacity(0.1) ?? Colors.transparent, borderRadius: BorderRadius.circular(6)), child: Text(stockStatusText, style: stockStatusStyle.copyWith(fontSize: 13))))),
//                         const Divider(height: 24, thickness: 0.7),
//                         Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
//                             _buildActionChip(context: listCtx, icon: Icons.remove_shopping_cart_outlined, label: 'صرف', color: Theme.of(listCtx).colorScheme.primary, onPressed: product.quantity > 0 ? () => _showRecordUsageDialog(listCtx, product) : null),
//                             _buildActionChip(context: listCtx, icon: Icons.edit_outlined, label: 'تعديل', color: Theme.of(listCtx).colorScheme.secondary, onPressed: () => _navigateToAddEditProductScreen(listCtx, product: product)),
//                             _buildActionChip(context: listCtx, icon: Icons.delete_outline, label: 'حذف', color: Theme.of(listCtx).colorScheme.error, 
//                               onPressed: () {
//                                 if (product.id != null) { _confirmDelete(listCtx, product.id!); } 
//                                 else { ScaffoldMessenger.of(listCtx).showSnackBar(const SnackBar(content: Text('خطأ: معرف المنتج غير صالح للحذف.', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')))); }
//                               }),
//                           ],),
//                       ],),),
//                 );},
//             );
//           },
//         ),
//       ),
//       floatingActionButton: FloatingActionButton.extended(
//         onPressed: () {
//           Navigator.of(context).push(
//             MaterialPageRoute(builder: (context) => const NewSaleInvoiceScreen()),
//           ).then((_){ _refreshProducts(); });
//         },
//         label: const Text('فاتورة بيع جديدة', style: TextStyle(fontFamily: 'Cairo')),
//         icon: const Icon(Icons.receipt_long_outlined),
//       ),
//     );
//   }

//   Widget _buildActionChip({ required BuildContext context, required IconData icon, required String label, required Color color, required VoidCallback? onPressed}) {
//     return Tooltip(message: label, child: IconButton(
//         icon: Icon(icon, color: onPressed == null ? Colors.grey.shade400 : color),
//         iconSize: 22, onPressed: onPressed, padding: const EdgeInsets.all(8), constraints: const BoxConstraints(),
//       ),);
//   }
// }
