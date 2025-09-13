// lib/screens/new_purchase_invoice_screen.dart
import 'package:flutter/material.dart';
import 'package:fouad_stock/model/invoice_item_model.dart' as db_invoice_item;
import 'package:fouad_stock/model/invoice_model.dart';
import 'package:fouad_stock/model/product_model.dart';
import 'package:fouad_stock/model/product_variant_model.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../providers/invoice_provider.dart';

class _ProvisionalPurchaseItem {
  final Product parentProduct;
  final ProductVariant variant;
  int quantity;
  double unitPurchasePrice;

  _ProvisionalPurchaseItem({
    required this.parentProduct,
    required this.variant,
    this.quantity = 1,
    required this.unitPurchasePrice,
  });

  String get displayName => variant.displayName.isEmpty
      ? parentProduct.name
      : '${parentProduct.name} (${variant.displayName})';

  double get itemTotal => quantity * unitPurchasePrice;
}

class NewPurchaseInvoiceScreen extends StatefulWidget {
  const NewPurchaseInvoiceScreen({super.key});

  @override
  State<NewPurchaseInvoiceScreen> createState() =>
      _NewPurchaseInvoiceScreenState();
}

class _NewPurchaseInvoiceScreenState extends State<NewPurchaseInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  late DateFormat _arabicDateFormat;

  String _invoiceNumber = 'جار التحميل...';
  DateTime _selectedDate = DateTime.now();
  final _supplierNameController = TextEditingController();
  final _taxRateController = TextEditingController(text: '0');
  final _discountController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  final List<_ProvisionalPurchaseItem> _invoiceItems = [];

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
    Future.microtask(
        () => Provider.of<ProductProvider>(context, listen: false).fetchProducts());
  }

  Future<void> _loadNextInvoiceNumber() async {
    try {
      final invoiceProvider =
          Provider.of<InvoiceProvider>(context, listen: false);
      final nextNumber =
          await invoiceProvider.getNextInvoiceNumber(InvoiceType.purchase);
      if (mounted) {
        setState(() {
          _invoiceNumber = nextNumber;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _invoiceNumber = 'خطأ!';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('فشل تحميل رقم فاتورة الشراء: $e',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontFamily: 'Cairo'))),
        );
      }
    }
  }

  @override
  void dispose() {
    _supplierNameController.dispose();
    _taxRateController.dispose();
    _discountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _calculateTotals() {
    double currentSubtotal = 0;
    for (var item in _invoiceItems) {
      currentSubtotal += item.itemTotal;
    }

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
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      locale: const Locale('ar', ''),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _addItemToInvoice(_ProvisionalPurchaseItem newItem) {
    int existingIndex = _invoiceItems.indexWhere((item) =>
        item.variant.id == newItem.variant.id &&
        item.unitPurchasePrice == newItem.unitPurchasePrice);

    if (existingIndex != -1) {
      setState(() {
        _invoiceItems[existingIndex].quantity += newItem.quantity;
      });
    } else {
      setState(() {
        _invoiceItems.add(newItem);
      });
    }
    _calculateTotals();
  }

  void _removeItem(int index) {
    setState(() {
      _invoiceItems.removeAt(index);
      _calculateTotals();
    });
  }

  void _updateItemQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) {
      _removeItem(index);
      return;
    }
    setState(() {
      _invoiceItems[index].quantity = newQuantity;
      _calculateTotals();
    });
  }

  void _updateItemPrice(int index, double newPrice) {
    if (newPrice < 0) return;
    setState(() {
      _invoiceItems[index].unitPurchasePrice = newPrice;
      _calculateTotals();
    });
  }

  Future<void> _showProductSelectionDialog() async {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);

    final Product? selectedProduct = await showDialog<Product>(
      context: context,
      builder: (ctx) => _ProductPickerDialog(productProvider: productProvider),
    );

    if (selectedProduct == null || !mounted) return;

    ProductVariant? selectedVariant;
    if (selectedProduct.hasVariants && selectedProduct.variants.length > 1) {
      selectedVariant = await showDialog<ProductVariant>(
        context: context,
        builder: (ctx) => _VariantPickerDialog(product: selectedProduct),
      );
    } else if (selectedProduct.variants.isNotEmpty) {
      selectedVariant = selectedProduct.variants.first;
    }

    if (selectedVariant == null || !mounted) return;

    _promptForQuantityAndPrice(selectedProduct, selectedVariant);
  }

  Future<void> _promptForQuantityAndPrice(
      Product parentProduct, ProductVariant variant) async {
    final qtyController = TextEditingController(text: '1');
    final priceController = TextEditingController(
        text: variant.purchasePrice > 0
            ? variant.purchasePrice.toStringAsFixed(2)
            : '');
    final GlobalKey<FormState> dialogFormKey = GlobalKey<FormState>();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(
              'أدخل كمية وسعر الشراء لـ "${parentProduct.name} (${variant.displayName})"',
              textAlign: TextAlign.right,
              style: TextStyle(fontFamily: 'Cairo')),
          content: Form(
            key: dialogFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontFamily: 'Cairo'),
                  decoration: const InputDecoration(
                      labelText: 'الكمية المستلمة*',
                      hintText: 'أدخل الكمية',
                      labelStyle: TextStyle(fontFamily: 'Cairo'),
                      hintStyle: TextStyle(fontFamily: 'Cairo')),
                  autofocus: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'الكمية مطلوبة';
                    final qty = int.tryParse(value);
                    if (qty == null || qty <= 0) return 'كمية غير صالحة';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  style: TextStyle(fontFamily: 'Cairo'),
                  decoration: const InputDecoration(
                      labelText: 'سعر شراء الوحدة*',
                      hintText: 'أدخل السعر',
                      suffixText: 'ج.م',
                      labelStyle: TextStyle(fontFamily: 'Cairo')),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'السعر مطلوب';
                    final price = double.tryParse(value);
                    if (price == null || price < 0) return 'سعر غير صالح';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child:
                    const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo'))),
            ElevatedButton(
              onPressed: () {
                if (dialogFormKey.currentState!.validate()) {
                  Navigator.of(ctx).pop({
                    'quantity': int.parse(qtyController.text),
                    'price': double.parse(priceController.text),
                  });
                }
              },
              child:
                  const Text("موافق", style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        );
      },
    );

    if (result != null) {
      _addItemToInvoice(_ProvisionalPurchaseItem(
        parentProduct: parentProduct,
        variant: variant,
        quantity: result['quantity'] as int,
        unitPurchasePrice: result['price'] as double,
      ));
    }
  }

  Future<void> _saveInvoice() async {
    if (_invoiceItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('الرجاء إضافة صنف واحد على الأقل لفاتورة الشراء.',
                textAlign: TextAlign.right,
                style: TextStyle(fontFamily: 'Cairo'))),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final invoiceProvider =
        Provider.of<InvoiceProvider>(context, listen: false);
    final productProvider =
        Provider.of<ProductProvider>(context, listen: false);

    final List<db_invoice_item.InvoiceItem> finalInvoiceItems =
        _invoiceItems.map((item) {
      return db_invoice_item.InvoiceItem(
        invoiceId: 0,
        productId: item.variant.id!,
        productName: item.displayName,
        category: item.parentProduct.category,
        quantity: item.quantity,
        unitPrice: item.unitPurchasePrice,
        purchasePrice: item.unitPurchasePrice,
        itemTotal: item.itemTotal,
      );
    }).toList();

    final newInvoice = Invoice(
      invoiceNumber: _invoiceNumber,
      date: _selectedDate,
      clientName: _supplierNameController.text.isEmpty
          ? null
          : _supplierNameController.text.trim(),
      items: [],
      subtotal: _subtotal,
      taxRatePercentage: double.tryParse(_taxRateController.text) ?? 0.0,
      taxAmount: _taxAmount,
      discountAmount: double.tryParse(_discountController.text) ?? 0.0,
      grandTotal: _grandTotal,
      type: InvoiceType.purchase,
      notes: _notesController.text.isEmpty ? null : _notesController.text.trim(),
      lastUpdated: DateTime.now(),
    );

    String? result = await invoiceProvider.createPurchaseInvoice(
      invoiceData: newInvoice,
      invoiceItems: finalInvoiceItems,
      productProvider: productProvider,
    );

    if (mounted) {
      setState(() {
        _isSaving = false;
      });
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ فاتورة الشراء بنجاح!',
                textAlign: TextAlign.right,
                style: TextStyle(fontFamily: 'Cairo')),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل حفظ فاتورة الشراء: $result',
                textAlign: TextAlign.right,
                style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('فاتورة شراء جديدة', style: TextStyle(fontFamily: 'Cairo')),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: _isSaving
                ? const Center(
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.0,
                        )))
                : IconButton(
                    icon: const Icon(Icons.save_alt_outlined),
                    tooltip: 'حفظ فاتورة الشراء',
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
            Text('تفاصيل فاتورة الشراء',
                style: theme.textTheme.titleLarge
                    ?.copyWith(color: theme.primaryColor, fontFamily: 'Cairo'),
                textAlign: TextAlign.right),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: TextEditingController(text: _invoiceNumber),
                    readOnly: true,
                    textAlign: TextAlign.right,
                    style: TextStyle(fontFamily: 'Cairo'),
                    decoration: const InputDecoration(
                        labelText: 'رقم الفاتورة',
                        labelStyle: TextStyle(fontFamily: 'Cairo')),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                          labelText: 'التاريخ',
                          labelStyle: TextStyle(fontFamily: 'Cairo')),
                      child: Text(_arabicDateFormat.format(_selectedDate),
                          textAlign: TextAlign.right,
                          style: TextStyle(fontFamily: 'Cairo')),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _supplierNameController,
              textAlign: TextAlign.right,
              style: TextStyle(fontFamily: 'Cairo'),
              decoration: const InputDecoration(
                  labelText: 'اسم المورد (اختياري)',
                  labelStyle: TextStyle(fontFamily: 'Cairo')),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('الأصناف المشتراة',
                    style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.primaryColor, fontFamily: 'Cairo'),
                    textAlign: TextAlign.right),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_shopping_cart),
                  label:
                      const Text('إضافة صنف', style: TextStyle(fontFamily: 'Cairo')),
                  onPressed: _showProductSelectionDialog,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.secondary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildInvoiceItemsList(),
            const SizedBox(height: 20),
            Text('ملخص الفاتورة',
                style: theme.textTheme.titleLarge
                    ?.copyWith(color: theme.primaryColor, fontFamily: 'Cairo'),
                textAlign: TextAlign.right),
            const SizedBox(height: 12),
            _buildSummaryRow(
                'المجموع الفرعي:', '${_subtotal.toStringAsFixed(2)} ج.م'),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _taxRateController,
                    textAlign: TextAlign.right,
                    style: TextStyle(fontFamily: 'Cairo'),
                    decoration: const InputDecoration(
                        labelText: 'نسبة الضريبة (%)',
                        suffixText: '%',
                        labelStyle: TextStyle(fontFamily: 'Cairo')),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value != null &&
                          value.isNotEmpty &&
                          (double.tryParse(value) == null ||
                              double.parse(value) < 0)) {
                        return 'نسبة غير صالحة';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: _buildSummaryRow(
                      'مبلغ الضريبة:', '${_taxAmount.toStringAsFixed(2)} ج.م'),
                ),
              ],
            ),
            TextFormField(
              controller: _discountController,
              textAlign: TextAlign.right,
              style: TextStyle(fontFamily: 'Cairo'),
              decoration: const InputDecoration(
                  labelText: 'مبلغ الخصم من المورد (ج.م)',
                  suffixText: 'ج.م',
                  labelStyle: TextStyle(fontFamily: 'Cairo')),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value != null &&
                    value.isNotEmpty &&
                    (double.tryParse(value) == null ||
                        double.parse(value) < 0)) {
                  return 'مبلغ غير صالح';
                }
                return null;
              },
            ),
            const Divider(height: 20, thickness: 1),
            _buildSummaryRow(
                'الإجمالي للدفع:', '${_grandTotal.toStringAsFixed(2)} ج.م',
                isGrandTotal: true),
            const SizedBox(height: 20),
            TextFormField(
              controller: _notesController,
              textAlign: TextAlign.right,
              style: TextStyle(fontFamily: 'Cairo'),
              decoration: const InputDecoration(
                  labelText: 'ملاحظات (اختياري)',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(fontFamily: 'Cairo')),
              maxLines: 3,
            ),
            const SizedBox(height: 30),
            _isSaving
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveInvoice,
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: const Text('حفظ فاتورة الشراء',
                          style:
                              TextStyle(fontSize: 18, fontFamily: 'Cairo')),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceItemsList() {
    if (_invoiceItems.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20.0),
        child: Center(
            child: Text('لم تتم إضافة أصناف بعد.',
                textAlign: TextAlign.right,
                style: TextStyle(fontFamily: 'Cairo'))),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _invoiceItems.length,
      itemBuilder: (context, index) {
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
                    Expanded(
                        child: Text(item.displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.right)),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _removeItem(index),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        initialValue: item.quantity.toString(),
                        textAlign: TextAlign.right,
                        decoration: const InputDecoration(
                            labelText: 'الكمية', isDense: true),
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
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        initialValue:
                            item.unitPurchasePrice.toStringAsFixed(2),
                        textAlign: TextAlign.right,
                        decoration: const InputDecoration(
                            labelText: 'سعر شراء الوحدة',
                            isDense: true,
                            suffixText: 'ج.م'),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (value) {
                          final newPrice = double.tryParse(value);
                          if (newPrice != null) {
                            _updateItemPrice(index, newPrice);
                          }
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'مطلوب';
                          final price = double.tryParse(value);
                          if (price == null || price < 0) return 'غير صالح';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                        'الإجمالي: ${item.itemTotal.toStringAsFixed(2)} ج.م',
                        textAlign: TextAlign.left,
                        style: const TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isGrandTotal = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: (isGrandTotal
                      ? theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)
                      : theme.textTheme.bodyLarge) ??
                  TextStyle(fontFamily: 'Cairo')),
          Text(value,
              style: (isGrandTotal
                          ? theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColor)
                          : theme.textTheme.bodyLarge)
                      ?.copyWith(fontFamily: 'Cairo') ??
                  TextStyle(fontFamily: 'Cairo')),
        ],
      ),
    );
  }
}

// Helper Widgets
class _ProductPickerDialog extends StatefulWidget {
  final ProductProvider productProvider;
  const _ProductPickerDialog({required this.productProvider});

  @override
  State<_ProductPickerDialog> createState() => _ProductPickerDialogState();
}
class _ProductPickerDialogState extends State<_ProductPickerDialog> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final allProducts = widget.productProvider.products;
    final filteredProducts = _searchQuery.isEmpty
        ? allProducts
        : allProducts.where((p) =>
            p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (p.productCode?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
          ).toList();

    return AlertDialog(
      title: const Text('اختر منتجاً', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                labelText: 'ابحث بالاسم أو الكود',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() { _searchController.clear(); _searchQuery = ''; })) : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: filteredProducts.isEmpty
                ? const Center(child: Text("لا توجد منتجات تطابق البحث.", style: TextStyle(fontFamily: 'Cairo')))
                : ListView.builder(
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      return ListTile(
                        title: Text(product.name, textAlign: TextAlign.right),
                        subtitle: Text('الصنف: ${product.category} - الكمية الحالية: ${product.totalQuantity}', textAlign: TextAlign.right), // FIX
                        onTap: () => Navigator.of(context).pop(product),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
      actions: [ TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("إلغاء"))],
    );
  }
}

class _VariantPickerDialog extends StatelessWidget {
  final Product product;
  const _VariantPickerDialog({required this.product});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('اختر المتغير لـ: ${product.name}', textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo')),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: product.variants.length,
          itemBuilder: (context, index) {
            final variant = product.variants[index];
            return ListTile(
              title: Text(variant.displayName, textAlign: TextAlign.right),
              subtitle: Text('الحالي: ${variant.quantity}', textAlign: TextAlign.right),
              onTap: () => Navigator.of(context).pop(variant),
            );
          },
        ),
      ),
      actions: [ TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("إلغاء"))],
    );
  }
}

class _QuantityPickerDialog extends StatelessWidget {
  final String productName;
  final String variantName;
  final TextEditingController qtyController;

  const _QuantityPickerDialog({
    required this.productName,
    required this.variantName,
    required this.qtyController,
  });

  @override
  Widget build(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    return AlertDialog(
      title: Text('أدخل الكمية لـ $productName (${variantName.isEmpty ? "افتراضي" : variantName})', textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo')),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: qtyController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(labelText: 'الكمية*'),
          autofocus: true,
          validator: (value) {
            if (value == null || value.isEmpty) return 'الكمية مطلوبة';
            final qty = int.tryParse(value);
            if (qty == null || qty <= 0) return 'كمية غير صالحة';
            return null;
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("إلغاء")),
        ElevatedButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.of(context).pop(int.parse(qtyController.text));
            }
          },
          child: const Text("موافق"),
        ),
      ],
    );
  }
}



// // lib/screens/new_purchase_invoice_screen.dart
// import 'package:flutter/material.dart';
// import 'package:fouad_stock/model/invoice_item_model.dart' as db_invoice_item;
// import 'package:fouad_stock/model/invoice_model.dart';
// import 'package:fouad_stock/model/product_model.dart';
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
// import '../providers/product_provider.dart';
// import '../providers/invoice_provider.dart';

// class _ProvisionalPurchaseItem {
//   final Product product;
//   int quantity;
//   double unitPurchasePrice;

//   _ProvisionalPurchaseItem({
//     required this.product,
//     this.quantity = 1,
//     required this.unitPurchasePrice,
//   });

//   double get itemTotal => quantity * unitPurchasePrice;
// }

// class NewPurchaseInvoiceScreen extends StatefulWidget {
//   const NewPurchaseInvoiceScreen({super.key});

//   @override
//   State<NewPurchaseInvoiceScreen> createState() => _NewPurchaseInvoiceScreenState();
// }

// class _NewPurchaseInvoiceScreenState extends State<NewPurchaseInvoiceScreen> {
//   final _formKey = GlobalKey<FormState>();
//   late DateFormat _arabicDateFormat;

//   String _invoiceNumber = 'جار التحميل...';
//   DateTime _selectedDate = DateTime.now();
//   final _supplierNameController = TextEditingController();
//   final _taxRateController = TextEditingController(text: '0');
//   final _discountController = TextEditingController(text: '0');
//   final _notesController = TextEditingController();

//   final List<_ProvisionalPurchaseItem> _invoiceItems = [];

//   double _subtotal = 0.0;
//   double _taxAmount = 0.0;
//   double _grandTotal = 0.0;
//   bool _isSaving = false;

//   @override
//   void initState() {
//     super.initState();
//     _arabicDateFormat = DateFormat.yMMMd('ar');
//     _loadNextInvoiceNumber();
//     _taxRateController.addListener(_calculateTotals);
//     _discountController.addListener(_calculateTotals);
//     Future.microtask(() => Provider.of<ProductProvider>(context, listen: false).fetchProducts());
//   }

//   Future<void> _loadNextInvoiceNumber() async {
//     try {
//       final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
//       final nextNumber = await invoiceProvider.getNextInvoiceNumber(InvoiceType.purchase);
//       if (mounted) {
//         setState(() { _invoiceNumber = nextNumber; });
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() { _invoiceNumber = 'خطأ!'; });
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('فشل تحميل رقم فاتورة الشراء: $e', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo'))),
//         );
//       }
//     }
//   }

//   @override
//   void dispose() {
//     _supplierNameController.dispose();
//     _taxRateController.dispose();
//     _discountController.dispose();
//     _notesController.dispose();
//     super.dispose();
//   }

//   void _calculateTotals() {
//     double currentSubtotal = 0;
//     for (var item in _invoiceItems) {
//       currentSubtotal += item.itemTotal;
//     }

//     final taxRate = double.tryParse(_taxRateController.text) ?? 0.0;
//     final discount = double.tryParse(_discountController.text) ?? 0.0;

//     final currentTaxAmount = (currentSubtotal * taxRate) / 100.0;
//     final currentGrandTotal = currentSubtotal + currentTaxAmount - discount;

//     if (mounted) {
//       setState(() {
//         _subtotal = currentSubtotal;
//         _taxAmount = currentTaxAmount;
//         _grandTotal = currentGrandTotal < 0 ? 0 : currentGrandTotal;
//       });
//     }
//   }

//   Future<void> _selectDate(BuildContext context) async {
//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: _selectedDate,
//       firstDate: DateTime(2000),
//       lastDate: DateTime(2101),
//       locale: const Locale('ar', ''),
//     );
//     if (picked != null && picked != _selectedDate) {
//       setState(() {
//         _selectedDate = picked;
//       });
//     }
//   }

//   void _addItemToInvoice(_ProvisionalPurchaseItem newItem) {
//     int existingIndex = _invoiceItems.indexWhere((item) => item.product.id == newItem.product.id && item.unitPurchasePrice == newItem.unitPurchasePrice);
    
//     if (existingIndex != -1) {
//       setState(() {
//         _invoiceItems[existingIndex].quantity += newItem.quantity;
//       });
//     } else {
//       setState(() {
//         _invoiceItems.add(newItem);
//       });
//     }
//     _calculateTotals();
//   }

//   void _removeItem(int index) {
//     setState(() {
//       _invoiceItems.removeAt(index);
//       _calculateTotals();
//     });
//   }

//   void _updateItemQuantity(int index, int newQuantity) {
//     if (newQuantity <= 0) {
//       _removeItem(index);
//       return;
//     }
//     setState(() {
//       _invoiceItems[index].quantity = newQuantity;
//       _calculateTotals();
//     });
//   }
  
//   void _updateItemPrice(int index, double newPrice) {
//     if (newPrice < 0) return; 
//     setState(() {
//       _invoiceItems[index].unitPurchasePrice = newPrice;
//       _calculateTotals();
//     });
//   }

//   Future<void> _showProductSelectionDialog() async {
//     final productProvider = Provider.of<ProductProvider>(context, listen: false);
//     if (productProvider.products.isEmpty && !productProvider.isLoading) {
//       await productProvider.fetchProducts();
//       if (!mounted) return;
//     }
    
//     if (productProvider.products.isEmpty) {
//         ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('لا توجد منتجات معرفة لإضافتها. قم بإضافة منتجات أولاً.', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo'))),
//       );
//       return;
//     }

//     final selectedProduct = await showDialog<Product>(
//       context: context,
//       builder: (BuildContext ctx) {
//         final searchController = TextEditingController();
//         String searchQuery = '';
        
//         return StatefulBuilder(
//           builder: (context, setDialogState) {
//             final allProducts = productProvider.products;

//             final filteredProducts = searchQuery.isEmpty
//                 ? allProducts
//                 : allProducts.where((p) =>
//                     p.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
//                     (p.productCode?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false)
//                   ).toList();

//             return AlertDialog(
//               title: const Text('اختر منتج للشراء', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
//               contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
//               content: SizedBox(
//                 width: double.maxFinite,
//                 height: MediaQuery.of(context).size.height * 0.6,
//                 child: Column(
//                   children: [
//                     TextField(
//                       controller: searchController,
//                       onChanged: (value) {
//                         setDialogState(() {
//                           searchQuery = value;
//                         });
//                       },
//                       textAlign: TextAlign.right,
//                       style: const TextStyle(fontFamily: 'Cairo'),
//                       decoration: InputDecoration(
//                         labelText: 'ابحث بالاسم أو الكود',
//                         hintText: 'ابحث هنا...',
//                         prefixIcon: const Icon(Icons.search),
//                         suffixIcon: searchQuery.isNotEmpty ? IconButton(
//                           icon: const Icon(Icons.clear),
//                           onPressed: () {
//                             setDialogState(() {
//                               searchController.clear();
//                               searchQuery = '';
//                             });
//                           },
//                         ) : null,
//                         border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
//                       ),
//                     ),
//                     const SizedBox(height: 10),
//                     Expanded(
//                       child: filteredProducts.isEmpty
//                         ? const Center(child: Text("لا توجد منتجات تطابق البحث.", style: TextStyle(fontFamily: 'Cairo')))
//                         : ListView.builder(
//                             shrinkWrap: true,
//                             itemCount: filteredProducts.length,
//                             itemBuilder: (BuildContext context, int index) {
//                               Product product = filteredProducts[index];
//                               return ListTile(
//                                 title: Text(product.name, textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
//                                 subtitle: Text('الصنف: ${product.category} - الحالي: ${product.quantity} ${product.unitOfMeasure}', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
//                                 onTap: () => Navigator.of(ctx).pop(product),
//                               );
//                             },
//                           ),
//                     ),
//                   ],
//                 ),
//               ),
//               actions: [ TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo')))],
//             );
//           },
//         );
//       },
//     );

//     if (selectedProduct != null) {
//       _promptForQuantityAndPrice(selectedProduct);
//     }
//   }

//   Future<void> _promptForQuantityAndPrice(Product product) async {
//     final qtyController = TextEditingController(text: '1');
//     final priceController = TextEditingController(text: product.purchasePrice > 0 ? product.purchasePrice.toStringAsFixed(2) : '');
//     final GlobalKey<FormState> dialogFormKey = GlobalKey<FormState>();

//     final result = await showDialog<Map<String, dynamic>>(
//       context: context,
//       builder: (BuildContext ctx) {
//         return AlertDialog(
//           title: Text('أدخل كمية وسعر الشراء لـ "${product.name}"', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
//           content: Form(
//             key: dialogFormKey,
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 TextFormField(
//                   controller: qtyController,
//                   keyboardType: TextInputType.number,
//                   textAlign: TextAlign.right,
//                   style: TextStyle(fontFamily: 'Cairo'),
//                   decoration: const InputDecoration(labelText: 'الكمية المستلمة*', hintText: 'أدخل الكمية', labelStyle: TextStyle(fontFamily: 'Cairo'), hintStyle: TextStyle(fontFamily: 'Cairo')),
//                   autofocus: true,
//                   validator: (value) {
//                     if (value == null || value.isEmpty) return 'الكمية مطلوبة';
//                     final qty = int.tryParse(value);
//                     if (qty == null || qty <= 0) return 'كمية غير صالحة';
//                     return null;
//                   },
//                 ),
//                 const SizedBox(height: 10),
//                 TextFormField(
//                   controller: priceController,
//                   keyboardType: const TextInputType.numberWithOptions(decimal: true),
//                   textAlign: TextAlign.right,
//                   style: TextStyle(fontFamily: 'Cairo'),
//                   decoration: const InputDecoration(labelText: 'سعر شراء الوحدة*', hintText: 'أدخل السعر', suffixText: 'ج.م', labelStyle: TextStyle(fontFamily: 'Cairo')),
//                   validator: (value) {
//                     if (value == null || value.isEmpty) return 'السعر مطلوب';
//                     final price = double.tryParse(value);
//                     if (price == null || price < 0) return 'سعر غير صالح';
//                     return null;
//                   },
//                 ),
//               ],
//             ),
//           ),
//           actions: [
//             TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo'))),
//             ElevatedButton(
//               onPressed: () {
//                 if (dialogFormKey.currentState!.validate()) {
//                   Navigator.of(ctx).pop({
//                     'quantity': int.parse(qtyController.text),
//                     'price': double.parse(priceController.text),
//                   });
//                 }
//               },
//               child: const Text("موافق", style: TextStyle(fontFamily: 'Cairo')),
//             ),
//           ],
//         );
//       },
//     );

//     if (result != null) {
//       _addItemToInvoice(_ProvisionalPurchaseItem(
//         product: product,
//         quantity: result['quantity'] as int,
//         unitPurchasePrice: result['price'] as double,
//       ));
//     }
//   }

//   Future<void> _saveInvoice() async {
//     if (_invoiceItems.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('الرجاء إضافة صنف واحد على الأقل لفاتورة الشراء.', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo'))),
//       );
//       return;
//     }
//     if (!_formKey.currentState!.validate()) {
//       return;
//     }
    
//     setState(() { _isSaving = true; });

//     final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
//     final productProvider = Provider.of<ProductProvider>(context, listen: false);

//     final List<db_invoice_item.InvoiceItem> finalInvoiceItems = _invoiceItems.map((item) {
//       return db_invoice_item.InvoiceItem(
//         invoiceId: 0, 
//         productId: item.product.id!,
//         productName: item.product.name,
//         quantity: item.quantity,
//         unitPrice: item.unitPurchasePrice,
//         purchasePrice: item.unitPurchasePrice, // For purchase, sale price = purchase price
//         itemTotal: item.itemTotal,
//       );
//     }).toList();

//     final newInvoice = Invoice(
//       invoiceNumber: _invoiceNumber,
//       date: _selectedDate,
//       clientName: _supplierNameController.text.isEmpty ? null : _supplierNameController.text.trim(),
//       items: [], 
//       subtotal: _subtotal,
//       taxRatePercentage: double.tryParse(_taxRateController.text) ?? 0.0,
//       taxAmount: _taxAmount,
//       discountAmount: double.tryParse(_discountController.text) ?? 0.0,
//       grandTotal: _grandTotal,
//       type: InvoiceType.purchase,
//       notes: _notesController.text.isEmpty ? null : _notesController.text.trim(),
//       lastUpdated: DateTime.now(),
//     );

//     String? result = await invoiceProvider.createPurchaseInvoice(
//       invoiceData: newInvoice,
//       invoiceItems: finalInvoiceItems,
//       productProvider: productProvider,
//     );

//     if (mounted) {
//       setState(() { _isSaving = false; });
//       if (result == null) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('تم حفظ فاتورة الشراء بنجاح!', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
//             backgroundColor: Colors.green,
//           ),
//         );
//         Navigator.of(context).pop();
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('فشل حفظ فاتورة الشراء: $result', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
//             backgroundColor: Theme.of(context).colorScheme.error,
//           ),
//         );
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('فاتورة شراء جديدة', style: TextStyle(fontFamily: 'Cairo')),
//         actions: [
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 12.0),
//             child: _isSaving
//                 ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0,)))
//                 : IconButton(
//                     icon: const Icon(Icons.save_alt_outlined),
//                     tooltip: 'حفظ فاتورة الشراء',
//                     onPressed: _saveInvoice,
//                   ),
//           ),
//         ],
//       ),
//       body: Form(
//         key: _formKey,
//         child: ListView(
//           padding: const EdgeInsets.all(16.0),
//           children: [
//             Text('تفاصيل فاتورة الشراء', style: theme.textTheme.titleLarge?.copyWith(color: theme.primaryColor, fontFamily: 'Cairo'), textAlign: TextAlign.right),
//             const SizedBox(height: 12),
//             Row(
//               children: [
//                 Expanded(
//                   child: TextFormField(
//                     controller: TextEditingController(text: _invoiceNumber),
//                     readOnly: true,
//                     textAlign: TextAlign.right,
//                     style: TextStyle(fontFamily: 'Cairo'),
//                     decoration: const InputDecoration(labelText: 'رقم الفاتورة', labelStyle: TextStyle(fontFamily: 'Cairo')),
//                   ),
//                 ),
//                 const SizedBox(width: 16),
//                 Expanded(
//                   child: InkWell(
//                     onTap: () => _selectDate(context),
//                     child: InputDecorator(
//                       decoration: const InputDecoration(labelText: 'التاريخ', labelStyle: TextStyle(fontFamily: 'Cairo')),
//                       child: Text(_arabicDateFormat.format(_selectedDate), textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 12),
//             TextFormField(
//               controller: _supplierNameController,
//               textAlign: TextAlign.right,
//               style: TextStyle(fontFamily: 'Cairo'),
//               decoration: const InputDecoration(labelText: 'اسم المورد (اختياري)', labelStyle: TextStyle(fontFamily: 'Cairo')),
//             ),
//             const SizedBox(height: 20),

//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text('الأصناف المشتراة', style: theme.textTheme.titleLarge?.copyWith(color: theme.primaryColor, fontFamily: 'Cairo'), textAlign: TextAlign.right),
//                 ElevatedButton.icon(
//                   icon: const Icon(Icons.add_shopping_cart),
//                   label: const Text('إضافة صنف', style: TextStyle(fontFamily: 'Cairo')),
//                   onPressed: _showProductSelectionDialog,
//                   style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.secondary),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 8),
//             _buildInvoiceItemsList(),
//             const SizedBox(height: 20),

//             Text('ملخص الفاتورة', style: theme.textTheme.titleLarge?.copyWith(color: theme.primaryColor, fontFamily: 'Cairo'), textAlign: TextAlign.right),
//             const SizedBox(height: 12),
//             _buildSummaryRow('المجموع الفرعي:', '${_subtotal.toStringAsFixed(2)} ج.م'),
//             Row(
//               children: [
//                 Expanded(
//                   flex: 2,
//                   child: TextFormField(
//                     controller: _taxRateController,
//                     textAlign: TextAlign.right,
//                     style: TextStyle(fontFamily: 'Cairo'),
//                     decoration: const InputDecoration(labelText: 'نسبة الضريبة (%)', suffixText: '%', labelStyle: TextStyle(fontFamily: 'Cairo')),
//                     keyboardType: const TextInputType.numberWithOptions(decimal: true),
//                     validator: (value) {
//                       if (value != null && value.isNotEmpty && (double.tryParse(value) == null || double.parse(value) < 0)) {
//                         return 'نسبة غير صالحة';
//                       }
//                       return null;
//                     },
//                   ),
//                 ),
//                 const SizedBox(width: 16),
//                 Expanded(
//                   flex: 3,
//                   child: _buildSummaryRow('مبلغ الضريبة:', '${_taxAmount.toStringAsFixed(2)} ج.م'),
//                 ),
//               ],
//             ),
//               TextFormField(
//               controller: _discountController,
//               textAlign: TextAlign.right,
//               style: TextStyle(fontFamily: 'Cairo'),
//               decoration: const InputDecoration(labelText: 'مبلغ الخصم من المورد (ج.م)', suffixText: 'ج.م', labelStyle: TextStyle(fontFamily: 'Cairo')),
//                 keyboardType: const TextInputType.numberWithOptions(decimal: true),
//                 validator: (value) {
//                 if (value != null && value.isNotEmpty && (double.tryParse(value) == null || double.parse(value) < 0)) {
//                   return 'مبلغ غير صالح';
//                 }
//                 return null;
//               },
//             ),
//             const Divider(height: 20, thickness: 1),
//             _buildSummaryRow('الإجمالي للدفع:', '${_grandTotal.toStringAsFixed(2)} ج.م', isGrandTotal: true),
//             const SizedBox(height: 20),

//             TextFormField(
//               controller: _notesController,
//               textAlign: TextAlign.right,
//               style: TextStyle(fontFamily: 'Cairo'),
//               decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)', border: OutlineInputBorder(), labelStyle: TextStyle(fontFamily: 'Cairo')),
//               maxLines: 3,
//             ),
//             const SizedBox(height: 30),
//               _isSaving
//                   ? const Center(child: CircularProgressIndicator())
//                   : SizedBox(
//                       width: double.infinity,
//                       child: ElevatedButton(
//                         onPressed: _saveInvoice,
//                         style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
//                         child: const Text('حفظ فاتورة الشراء', style: TextStyle(fontSize: 18, fontFamily: 'Cairo')),
//                       ),
//                     ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildInvoiceItemsList() {
//     if (_invoiceItems.isEmpty) {
//       return const Padding(
//         padding: const EdgeInsets.symmetric(vertical: 20.0),
//         child: Center(child: Text('لم تتم إضافة أصناف بعد.', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo'))),
//       );
//     }
//     return ListView.builder(
//       shrinkWrap: true,
//       physics: const NeverScrollableScrollPhysics(),
//       itemCount: _invoiceItems.length,
//       itemBuilder: (context, index) {
//         final item = _invoiceItems[index];
//         return Card(
//           margin: const EdgeInsets.symmetric(vertical: 6.0),
//           child: Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Expanded(child: Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
//                     IconButton(
//                       icon: const Icon(Icons.delete_outline, color: Colors.red),
//                       onPressed: () => _removeItem(index),
//                       padding: EdgeInsets.zero,
//                       constraints: const BoxConstraints(),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 8),
//                 Row(
//                   children: [
//                     Expanded(
//                       flex: 2,
//                       child: TextFormField(
//                         initialValue: item.quantity.toString(),
//                         textAlign: TextAlign.right,
//                         decoration: const InputDecoration(labelText: 'الكمية', isDense: true),
//                         keyboardType: TextInputType.number,
//                         onChanged: (value) {
//                           final newQty = int.tryParse(value);
//                           if (newQty != null) {
//                             _updateItemQuantity(index, newQty);
//                           }
//                         },
//                           validator: (value) { 
//                             if (value == null || value.isEmpty) return 'مطلوب';
//                             final qty = int.tryParse(value);
//                             if (qty == null || qty <= 0) return 'غير صالح';
//                             return null;
//                           },
//                       ),
//                     ),
//                     const SizedBox(width: 10),
//                     Expanded(
//                       flex: 3,
//                       child: TextFormField( 
//                         initialValue: item.unitPurchasePrice.toStringAsFixed(2),
//                         textAlign: TextAlign.right,
//                         decoration: const InputDecoration(labelText: 'سعر شراء الوحدة', isDense: true, suffixText: 'ج.م'),
//                         keyboardType: const TextInputType.numberWithOptions(decimal: true),
//                         onChanged: (value) {
//                           final newPrice = double.tryParse(value);
//                           if (newPrice != null) {
//                             _updateItemPrice(index, newPrice);
//                           }
//                         },
//                         validator: (value) {
//                             if (value == null || value.isEmpty) return 'مطلوب';
//                             final price = double.tryParse(value);
//                             if (price == null || price < 0) return 'غير صالح';
//                             return null;
//                           },
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 8),
//                   Align(
//                   alignment: Alignment.centerLeft,
//                   child: Text('الإجمالي: ${item.itemTotal.toStringAsFixed(2)} ج.م', textAlign: TextAlign.left, style: const TextStyle(fontWeight: FontWeight.bold))),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildSummaryRow(String label, String value, {bool isGrandTotal = false}) {
//     final theme = Theme.of(context);
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4.0),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(label, style: (isGrandTotal ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold) : theme.textTheme.bodyLarge) ?? TextStyle(fontFamily: 'Cairo')),
//           Text(value, style: (isGrandTotal ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.primaryColor) : theme.textTheme.bodyLarge)?.copyWith(fontFamily: 'Cairo') ?? TextStyle(fontFamily: 'Cairo')),
//         ],
//       ),
//     );
//   }
// }

