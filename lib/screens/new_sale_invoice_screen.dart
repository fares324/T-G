// lib/screens/new_sale_invoice_screen.dart
import 'package:flutter/material.dart';
import 'package:fouad_stock/enum/filter_enums.dart';
import 'package:fouad_stock/model/invoice_item_model.dart' as db_invoice_item;
import 'package:fouad_stock/model/invoice_model.dart';
import 'package:fouad_stock/model/product_model.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../providers/invoice_provider.dart';
import '../helpers/db_helpers.dart';

class _ProvisionalInvoiceItem {
  final Product product;
  int quantity;

  _ProvisionalInvoiceItem({required this.product, this.quantity = 1});

  double get unitPrice => product.sellingPrice;
  double get itemTotal => quantity * unitPrice;
}

class NewSaleInvoiceScreen extends StatefulWidget {
  const NewSaleInvoiceScreen({super.key});

  @override
  State<NewSaleInvoiceScreen> createState() => _NewSaleInvoiceScreenState();
}

class _NewSaleInvoiceScreenState extends State<NewSaleInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  late DateFormat _arabicDateFormat;

  String _invoiceNumber = 'جار التحميل...';
  DateTime _selectedDate = DateTime.now();
  final _clientNameController = TextEditingController();
  final _taxRateController = TextEditingController(text: '0');
  final _discountController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  final List<_ProvisionalInvoiceItem> _invoiceItems = [];

  double _subtotal = 0.0;
  double _taxAmount = 0.0;
  double _grandTotal = 0.0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _arabicDateFormat = DateFormat.yMMMd('ar');
    _loadNextInvoiceNumber();
    _taxRateController.addListener(_calculateTotals);
    _discountController.addListener(_calculateTotals);
    Future.microtask(() => Provider.of<ProductProvider>(context, listen: false).fetchProducts(filter: ProductListFilter.none));
  }

  Future<void> _loadNextInvoiceNumber() async {
    try {
      final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
      final nextNumber = await invoiceProvider.getNextInvoiceNumber(InvoiceType.sale);
      if (mounted) {
        setState(() { _invoiceNumber = nextNumber; });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _invoiceNumber = 'خطأ!'; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تحميل رقم الفاتورة: $e', textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo'))),
        );
      }
    }
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _taxRateController.dispose();
    _discountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _calculateTotals() {
    double currentSubtotal = _invoiceItems.fold(0.0, (sum, item) => sum + item.itemTotal);
    final taxRate = double.tryParse(_taxRateController.text) ?? 0.0;
    final discount = double.tryParse(_discountController.text) ?? 0.0;
    final currentTaxAmount = (currentSubtotal * taxRate) / 100.0;
    final currentGrandTotal = currentSubtotal + currentTaxAmount - discount;

    if (mounted) {
      setState(() {
        _subtotal = currentSubtotal;
        _taxAmount = currentTaxAmount;
        _grandTotal = currentGrandTotal < 0 ? 0 : currentGrandTotal;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context, initialDate: _selectedDate,
      firstDate: DateTime(2000), lastDate: DateTime(2101),
      locale: const Locale('ar', ''),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() { _selectedDate = picked; });
    }
  }

  void _addItemToInvoice(_ProvisionalInvoiceItem newItem) async {
    int existingIndex = _invoiceItems.indexWhere((item) => item.product.id == newItem.product.id);
    
    if (existingIndex != -1) {
      final productInDb = await DatabaseHelper.instance.getProductById(newItem.product.id!);
      int currentStock = productInDb?.quantity ?? 0;
      int quantityAlreadyInInvoiceForThisProduct = _invoiceItems[existingIndex].quantity;
      int quantityAttemptingToAdd = newItem.quantity;

      if ((quantityAlreadyInInvoiceForThisProduct + quantityAttemptingToAdd) > currentStock) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('لا يمكن إضافة المزيد. الكمية المتوفرة للمنتج "${newItem.product.name}" هي ${currentStock - quantityAlreadyInInvoiceForThisProduct} (صافي).', textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo'))),
        );
        }
        return;
      }
      setState(() { _invoiceItems[existingIndex].quantity += quantityAttemptingToAdd; });
    } else {
      final productInDb = await DatabaseHelper.instance.getProductById(newItem.product.id!);
      int currentStock = productInDb?.quantity ?? 0;
      if (newItem.quantity > currentStock) {
          if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('الكمية المطلوبة للمنتج "${newItem.product.name}" (${newItem.quantity}) أكبر من المتوفر بالمخزون ($currentStock).', textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo'))),
          );
          }
          return;
      }
      setState(() { _invoiceItems.add(newItem); });
    }
    _calculateTotals();
  }

  void _removeItem(int index) {
    setState(() {
      _invoiceItems.removeAt(index);
      _calculateTotals();
    });
  }

  void _updateItemQuantity(int index, int newQuantity) async {
    if (newQuantity <= 0) {
      bool? confirmRemove = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
              title: const Text('تأكيد', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
              content: const Text('الكمية صفر أو أقل ستؤدي إلى حذف الصنف. هل أنت متأكد؟', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
                TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('حذف الصنف', style: TextStyle(fontFamily: 'Cairo', color: Colors.red))),
              ],
            ));
      if (confirmRemove == true) {
        _removeItem(index);
      }
      return;
    }
    final productInDb = await DatabaseHelper.instance.getProductById(_invoiceItems[index].product.id!);
    int currentStock = productInDb?.quantity ?? 0;

    if (newQuantity > currentStock) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('لا يمكن تحديد هذه الكمية. الكمية المتوفرة للمنتج "${_invoiceItems[index].product.name}" هي ${currentStock}', textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo'))),
      );
      }
      return;
    }
    setState(() {
      _invoiceItems[index].quantity = newQuantity;
      _calculateTotals();
    });
  }

  void _addAllProducts() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
        content: const Text('هل تريد حقًا إضافة جميع المنتجات؟ سيتم حذف أي أصناف مضافة حاليًا.', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('موافق', style: TextStyle(color: Colors.teal))),
        ],
      ),
    );

    if (confirmed != true) return;

    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    if (productProvider.products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد منتجات لإضافتها.', textAlign: TextAlign.right)));
      return;
    }

    setState(() {
      _invoiceItems.clear();
      for (var product in productProvider.products) {
        if (product.quantity > 0) {
          _invoiceItems.add(_ProvisionalInvoiceItem(product: product, quantity: 1));
        }
      }
    });
    _calculateTotals();
  }

  Future<void> _showProductSelectionDialog() async {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    if (productProvider.products.isEmpty && !productProvider.isLoading) {
      await productProvider.fetchProducts(filter: ProductListFilter.none);
      if (!mounted) return;
    }
    
    if (productProvider.products.isEmpty) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد منتجات في المخزون لإضافتها.', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo'))),
      );
      }
      return;
    }

    final selectedProduct = await showDialog<Product>(
      context: context,
      builder: (BuildContext ctx) {
        final searchController = TextEditingController();
        String searchQuery = '';
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final allProducts = productProvider.products;

            final filteredProducts = searchQuery.isEmpty
                ? allProducts
                : allProducts.where((p) =>
                    p.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                    (p.productCode?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false)
                  ).toList();

            return AlertDialog(
              title: const Text('إضافة منتج للبيع', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
              contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.6,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      onChanged: (value) {
                        setDialogState(() {
                          searchQuery = value;
                        });
                      },
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontFamily: 'Cairo'),
                      decoration: InputDecoration(
                        labelText: 'ابحث بالاسم أو الكود',
                        hintText: 'ابحث هنا...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: searchQuery.isNotEmpty ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setDialogState(() {
                              searchController.clear();
                              searchQuery = '';
                            });
                          },
                        ) : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: filteredProducts.isEmpty
                        ? const Center(child: Text("لا توجد منتجات تطابق البحث.", style: TextStyle(fontFamily: 'Cairo')))
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filteredProducts.length,
                            itemBuilder: (BuildContext context, int index) {
                              Product product = filteredProducts[index];
                              int qtyInInvoice = _invoiceItems.where((item) => item.product.id == product.id).fold(0, (sum, item) => sum + item.quantity);
                              int availableForAdding = product.quantity - qtyInInvoice;
                              bool canAdd = availableForAdding > 0;

                              return ListTile(
                                title: Text(product.name, textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo')),
                                subtitle: Text('المتاح للإضافة: $availableForAdding - السعر: ${product.sellingPrice.toStringAsFixed(2)} ج.م', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontFamily: 'Cairo')),
                                onTap: canAdd ? () => Navigator.of(ctx).pop(product) : null,
                                enabled: canAdd,
                                trailing: canAdd ? null : const Text("نفذ", style: TextStyle(color: Colors.red, fontFamily: 'Cairo')),
                              );
                            },
                          ),
                    ),
                  ],
                ),
              ),
              actions: [ TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo')))],
            );
          },
        );
      },
    );

    if (selectedProduct != null) {
      _promptForQuantity(selectedProduct);
    }
  }

  Future<void> _promptForQuantity(Product product) async {
    final qtyController = TextEditingController(text: '1');
    final productDetailsFromDb = await DatabaseHelper.instance.getProductById(product.id!);
    final int currentStock = productDetailsFromDb?.quantity ?? 0;
    
    final int qtyAlreadyInInvoice = _invoiceItems.where((item) => item.product.id == product.id).fold(0, (sum, item) => sum + item.quantity);
    final int availableQty = currentStock - qtyAlreadyInInvoice;

    if (availableQty <= 0) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('المنتج "${product.name}" نفذت كميته أو كل الكمية المتاحة مضافة بالفعل.', textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo'))),
        );
        return;
    }

    final selectedQuantity = await showDialog<int>(
      context: context,
      builder: (BuildContext ctx) {
        final formKeyDialog = GlobalKey<FormState>();
        return AlertDialog(
          title: Text('أدخل الكمية لـ ${product.name}', textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo')),
          content: Form(
            key: formKeyDialog,
            child: TextFormField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              style: const TextStyle(fontFamily: 'Cairo'),
              decoration: InputDecoration(hintText: 'الكمية (المتاح للإضافة: $availableQty)', hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
              autofocus: true,
              validator: (value) {
                if (value == null || value.isEmpty) return 'الكمية مطلوبة';
                final qty = int.tryParse(value);
                if (qty == null || qty <= 0) return 'كمية غير صالحة';
                if (qty > availableQty) return 'الكمية أكبر من المتاح ($availableQty)';
                return null;
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo'))),
            ElevatedButton(
              onPressed: () {
                if (formKeyDialog.currentState!.validate()) {
                  Navigator.of(ctx).pop(int.parse(qtyController.text));
                }
              },
              child: const Text("موافق", style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        );
      },
    );

    if (selectedQuantity != null && selectedQuantity > 0) {
      _addItemToInvoice(_ProvisionalInvoiceItem(product: product, quantity: selectedQuantity));
    }
  }

  Future<void> _saveInvoice() async {
    if (_invoiceItems.isEmpty) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إضافة صنف واحد على الأقل للفاتورة.', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo'))),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() { _isSaving = true; });

    final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
    final productProvider = Provider.of<ProductProvider>(context, listen: false);

    final List<db_invoice_item.InvoiceItem> finalInvoiceItems = _invoiceItems.map((item) {
      return db_invoice_item.InvoiceItem(
        invoiceId: 0, 
        productId: item.product.id!,
        productName: item.product.name,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        purchasePrice: item.product.purchasePrice,
        itemTotal: item.itemTotal,
      );
    }).toList();

    final newInvoice = Invoice(
      invoiceNumber: _invoiceNumber,
      date: _selectedDate,
      clientName: _clientNameController.text.isEmpty ? null : _clientNameController.text.trim(),
      items: [], 
      subtotal: _subtotal,
      taxRatePercentage: double.tryParse(_taxRateController.text.trim()) ?? 0.0,
      taxAmount: _taxAmount,
      discountAmount: double.tryParse(_discountController.text.trim()) ?? 0.0,
      grandTotal: _grandTotal,
      type: InvoiceType.sale,
      notes: _notesController.text.isEmpty ? null : _notesController.text.trim(), lastUpdated: DateTime.now(),
    );

    String? result = await invoiceProvider.createSaleInvoice(
      invoiceData: newInvoice,
      invoiceItems: finalInvoiceItems,
      productProvider: productProvider,
    );

    if (mounted) {
      setState(() { _isSaving = false; });
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حفظ الفاتورة بنجاح برقم: $_invoiceNumber', textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل حفظ الفاتورة: $result', textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const String pageTitle = 'فاتورة بيع جديدة'; 

    return Scaffold(
      appBar: AppBar(
        title: Text(pageTitle, style: const TextStyle(fontFamily: 'Cairo')),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: _isSaving
                ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0,)))
                : IconButton(
                    icon: const Icon(Icons.save_alt_outlined),
                    tooltip: 'حفظ الفاتورة',
                    onPressed: _saveInvoice,
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Text('تفاصيل الفاتورة', style: theme.textTheme.titleLarge?.copyWith(color: theme.primaryColor, fontFamily: 'Cairo'), textAlign: TextAlign.right),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: TextEditingController(text: _invoiceNumber),
                    readOnly: true,
                    textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo'),
                    decoration: const InputDecoration(labelText: 'رقم الفاتورة', labelStyle: TextStyle(fontFamily: 'Cairo')),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'التاريخ', labelStyle: TextStyle(fontFamily: 'Cairo')),
                      child: Text(_arabicDateFormat.format(_selectedDate), textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo')),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _clientNameController,
              textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo'),
              decoration: const InputDecoration(labelText: 'اسم العميل (اختياري)', labelStyle: TextStyle(fontFamily: 'Cairo')),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('الأصناف', style: theme.textTheme.titleLarge?.copyWith(color: theme.primaryColor, fontFamily: 'Cairo'), textAlign: TextAlign.right),
                Row(
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.playlist_add_check, size: 20),
                      label: const Text('إضافة الكل', style: TextStyle(fontFamily: 'Cairo')),
                      onPressed: _addAllProducts,
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('إضافة صنف', style: TextStyle(fontFamily: 'Cairo')),
                      onPressed: _showProductSelectionDialog,
                      style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.secondary),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildInvoiceItemsList(),
            const SizedBox(height: 20),
            Text('ملخص الفاتورة', style: theme.textTheme.titleLarge?.copyWith(color: theme.primaryColor, fontFamily: 'Cairo'), textAlign: TextAlign.right),
            const SizedBox(height: 12),
            _buildSummaryRow('المجموع الفرعي:', '${_subtotal.toStringAsFixed(2)} ج.م'),
            Row(
                children: [
                    Expanded(flex: 2, child: TextFormField(controller: _taxRateController, textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo'), decoration: const InputDecoration(labelText: 'نسبة الضريبة (%)', suffixText: '%', labelStyle: TextStyle(fontFamily: 'Cairo')), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v){ if(v!=null && v.isNotEmpty && (double.tryParse(v)==null || double.parse(v) < 0)) return 'نسبة غير صالحة'; return null;},)),
                    const SizedBox(width: 16),
                    Expanded(flex: 3, child: _buildSummaryRow('مبلغ الضريبة:', '${_taxAmount.toStringAsFixed(2)} ج.م')),
                ]
            ),
            TextFormField(controller: _discountController, textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo'), decoration: const InputDecoration(labelText: 'مبلغ الخصم (ج.م)', suffixText: 'ج.م', labelStyle: TextStyle(fontFamily: 'Cairo')), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v){ if(v!=null && v.isNotEmpty && (double.tryParse(v)==null || double.parse(v) < 0)) return 'مبلغ غير صالح'; if(v!=null && v.isNotEmpty && (_subtotal + _taxAmount > 0) && (double.tryParse(v)! > _subtotal + _taxAmount)) return 'الخصم أكبر'; return null;},),
            const Divider(height: 20, thickness: 1),
            _buildSummaryRow('الإجمالي الكلي:', '${_grandTotal.toStringAsFixed(2)} ج.م', isGrandTotal: true),
            const SizedBox(height: 20),
            TextFormField(controller: _notesController, textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo'), decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)', border: OutlineInputBorder(), labelStyle: TextStyle(fontFamily: 'Cairo')), maxLines: 3,),
            const SizedBox(height: 30),
              _isSaving 
                  ? const Center(child: CircularProgressIndicator()) 
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveInvoice,
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: theme.primaryColor),
                        child: const Text('حفظ الفاتورة', style: TextStyle(fontSize: 18, fontFamily: 'Cairo', color: Colors.white)),
                      ),
                    ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceItemsList() {
    final theme = Theme.of(context);
    if (_invoiceItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Center(child: Text('لم تتم إضافة أصناف بعد.', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo', color: theme.textTheme.bodyMedium?.color ?? Colors.grey))),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _invoiceItems.length,
      itemBuilder: (ctx, index) {
        final item = _invoiceItems[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(item.product.name, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: Theme.of(ctx).textTheme.bodyLarge?.color), textAlign: TextAlign.right)),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _removeItem(index),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: item.quantity.toString(),
                        textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo', color: Theme.of(ctx).textTheme.bodyLarge?.color),
                        decoration: InputDecoration(labelText: 'الكمية', isDense: true, labelStyle: TextStyle(fontFamily: 'Cairo', color: Theme.of(ctx).textTheme.bodyMedium?.color)),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          final newQty = int.tryParse(value);
                          if (newQty != null) {
                            _updateItemQuantity(index, newQty);
                          }
                        },
                        validator: (value) {
                            if (value == null || value.isEmpty) return 'مطلوب';
                            final qty = int.tryParse(value);
                            if (qty == null || qty <= 0) return 'غير صالح';
                            return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text('سعر الوحدة: ${NumberFormat.currency(locale: 'ar', symbol: 'ج.م', decimalDigits: 2).format(item.unitPrice)}', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo', color: Theme.of(ctx).textTheme.bodyMedium?.color))),
                    const SizedBox(width: 10),
                    Expanded(child: Text('الإجمالي: ${NumberFormat.currency(locale: 'ar', symbol: 'ج.م', decimalDigits: 2).format(item.itemTotal)}', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: Theme.of(ctx).textTheme.bodyLarge?.color))),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isGrandTotal = false}) {
    final theme = Theme.of(context);
    TextStyle defaultStyle = (isGrandTotal 
        ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontFamily: 'Cairo') 
        : theme.textTheme.bodyLarge?.copyWith(fontFamily: 'Cairo')) 
        ?? TextStyle(fontFamily: 'Cairo', fontWeight: isGrandTotal ? FontWeight.bold : FontWeight.normal, fontSize: isGrandTotal ? 16 : 14, color: theme.textTheme.bodyLarge?.color);

    TextStyle valueStyle = (isGrandTotal 
        ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.primaryColor, fontFamily: 'Cairo') 
        : theme.textTheme.bodyLarge?.copyWith(fontFamily: 'Cairo')) 
        ?? TextStyle(fontFamily: 'Cairo', fontWeight: isGrandTotal ? FontWeight.bold : FontWeight.normal, fontSize: isGrandTotal ? 16: 14, color: isGrandTotal ? theme.primaryColor : null);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: defaultStyle, textAlign: TextAlign.right),
          Text(value, style: valueStyle, textAlign: TextAlign.left),
        ],
      ),
    );
  }
}
