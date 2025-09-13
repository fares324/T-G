// lib/screens/edit_invoice_screen.dart
import 'package:flutter/material.dart';
import 'package:fouad_stock/model/invoice_item_model.dart' as db_invoice_item;
import 'package:fouad_stock/model/invoice_model.dart';
import 'package:fouad_stock/model/product_model.dart';
import 'package:fouad_stock/model/product_variant_model.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../providers/invoice_provider.dart';

// Modified helper class to work with variants
class _EditableInvoiceItem {
  final int? originalItemId;
  final Product parentProduct;
  final ProductVariant variant;
  int quantity;
  double unitPrice;
  final String itemKey;

  _EditableInvoiceItem({
    this.originalItemId,
    required this.parentProduct,
    required this.variant,
    required this.quantity,
    required this.unitPrice,
  }) : itemKey = originalItemId?.toString() ?? UniqueKey().toString();

  String get displayName => variant.displayName.isEmpty
      ? parentProduct.name
      : '${parentProduct.name} (${variant.displayName})';

  double get itemTotal => quantity * unitPrice;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _EditableInvoiceItem &&
          runtimeType == other.runtimeType &&
          itemKey == other.itemKey;

  @override
  int get hashCode => itemKey.hashCode;
}

class EditInvoiceScreen extends StatefulWidget {
  final Invoice originalInvoice;

  const EditInvoiceScreen({super.key, required this.originalInvoice});

  @override
  State<EditInvoiceScreen> createState() => _EditInvoiceScreenState();
}

class _EditInvoiceScreenState extends State<EditInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  late DateFormat _arabicDateFormat;

  late TextEditingController _invoiceNumberController;
  late DateTime _selectedDate;
  late TextEditingController _clientOrSupplierNameController;
  late TextEditingController _taxRateController;
  late TextEditingController _discountController;
  late TextEditingController _notesController;

  final List<_EditableInvoiceItem> _editableItems = [];
  final Map<String, TextEditingController> _itemQuantityControllers = {};
  final Map<String, TextEditingController> _itemPriceControllers = {};

  double _subtotal = 0.0;
  double _taxAmount = 0.0;
  double _grandTotal = 0.0;

  bool _isLoading = true;
  bool _isSaving = false;
  late InvoiceType _invoiceType;

  @override
  void initState() {
    super.initState();
    _arabicDateFormat = DateFormat.yMMMd('ar');
    _invoiceType = widget.originalInvoice.type;

    _invoiceNumberController = TextEditingController(text: widget.originalInvoice.invoiceNumber);
    _selectedDate = widget.originalInvoice.date;
    _clientOrSupplierNameController = TextEditingController(text: widget.originalInvoice.clientName ?? '');
    _taxRateController = TextEditingController(text: widget.originalInvoice.taxRatePercentage.toString());
    _discountController = TextEditingController(text: widget.originalInvoice.discountAmount.toString());
    _notesController = TextEditingController(text: widget.originalInvoice.notes ?? '');

    _taxRateController.addListener(_calculateTotals);
    _discountController.addListener(_calculateTotals);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadInvoiceItems();
      }
    });
  }

  Future<void> _loadInvoiceItems() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });

    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    await productProvider.fetchProducts();

    if (!mounted) return;

    _editableItems.clear();
    _itemQuantityControllers.forEach((_, controller) => controller.dispose());
    _itemQuantityControllers.clear();
    _itemPriceControllers.forEach((_, controller) => controller.dispose());
    _itemPriceControllers.clear();

    for (var dbItem in widget.originalInvoice.items) {
      final found = productProvider.findProductAndVariantByVariantId(dbItem.productId);
      
      if (found != null && found['product'] != null && found['variant'] != null) {
        final editableItem = _EditableInvoiceItem(
          originalItemId: dbItem.id,
          parentProduct: found['product']!,
          variant: found['variant']!,
          quantity: dbItem.quantity,
          unitPrice: dbItem.unitPrice,
        );
        _editableItems.add(editableItem);
        _itemQuantityControllers[editableItem.itemKey] = TextEditingController(text: dbItem.quantity.toString());
        _itemPriceControllers[editableItem.itemKey] = TextEditingController(text: dbItem.unitPrice.toStringAsFixed(2));
      }
    }
    
    _calculateTotals();
    if (mounted) {
      setState(() { _isLoading = false; });
    }
  }

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _clientOrSupplierNameController.dispose();
    _taxRateController.dispose();
    _discountController.dispose();
    _notesController.dispose();
    _itemQuantityControllers.forEach((_, controller) => controller.dispose());
    _itemPriceControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  void _calculateTotals() {
    _updateItemsFromControllers(); 
    double currentSubtotal = 0;
    for (var item in _editableItems) {
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

  void _addItemToInvoice(_EditableInvoiceItem newItem) {
    int existingIndex = _editableItems.indexWhere((item) => item.variant.id == newItem.variant.id);
    
    if (existingIndex != -1) {
       setState(() {
        _editableItems[existingIndex].quantity += newItem.quantity;
        _itemQuantityControllers[_editableItems[existingIndex].itemKey]?.text = _editableItems[existingIndex].quantity.toString();
      });
    } else {
      setState(() {
        _editableItems.add(newItem);
         _itemQuantityControllers[newItem.itemKey] = TextEditingController(text: newItem.quantity.toString());
        _itemPriceControllers[newItem.itemKey] = TextEditingController(text: newItem.unitPrice.toStringAsFixed(2));
      });
    }
    _calculateTotals();
  }

  void _removeItem(int uiIndex) {
    if (uiIndex < 0 || uiIndex >= _editableItems.length) return;
    setState(() {
      final itemToRemove = _editableItems[uiIndex];
      _itemQuantityControllers.remove(itemToRemove.itemKey)?.dispose();
      _itemPriceControllers.remove(itemToRemove.itemKey)?.dispose();
      _editableItems.removeAt(uiIndex);
    });
    _calculateTotals();
  }
  
  void _updateItemsFromControllers() {
    for(var item in _editableItems) {
      final qtyText = _itemQuantityControllers[item.itemKey]?.text;
      if (qtyText != null) {
        item.quantity = int.tryParse(qtyText) ?? item.quantity;
      }
      final priceText = _itemPriceControllers[item.itemKey]?.text;
      if (priceText != null) {
        item.unitPrice = double.tryParse(priceText) ?? item.unitPrice;
      }
    }
  }

  void _updateItemQuantityFromField(int uiIndex, String value) async {
    final editableItem = _editableItems[uiIndex];
    final newQty = int.tryParse(value);

    if (newQty == null || newQty <= 0) {
      return;
    }

    if (_invoiceType == InvoiceType.sale) {
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      final found = productProvider.findProductAndVariantByVariantId(editableItem.variant.id!);
      if (found == null || found['variant'] == null) return;
      
      int currentStockInDb = found['variant']!.quantity;
      int originalItemQtyFromDbInvoice = 0;
      
      if (editableItem.originalItemId != null) {
          var originalDbItem = widget.originalInvoice.items.firstWhere(
              (item) => item.id == editableItem.originalItemId,
              orElse: () => db_invoice_item.InvoiceItem(id: -1, invoiceId: 0, productId: 0, productName: '', category: '', quantity: 0, unitPrice: 0, purchasePrice: 0, itemTotal: 0)
          );
          originalItemQtyFromDbInvoice = originalDbItem.quantity;
      }

      int effectivelyAvailable = currentStockInDb + originalItemQtyFromDbInvoice;

      if (newQty > effectivelyAvailable) {
          if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          'الكمية أكبر من المتاح ($effectivelyAvailable) للمنتج "${editableItem.displayName}".',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontFamily: 'Cairo'),
                      ),
                      backgroundColor: Colors.red,
                  ),
              );
          }
          _itemQuantityControllers[editableItem.itemKey]?.text = editableItem.quantity.toString();
          return;
      }
    }
    setState(() {
        editableItem.quantity = newQty;
        _calculateTotals();
    });
  }

  void _updateItemPriceFromField(int uiIndex, String value) {
    final editableItem = _editableItems[uiIndex];
    final newPrice = double.tryParse(value);

    if (newPrice == null || newPrice < 0) {
       return;
    }
    
    if (_invoiceType == InvoiceType.purchase) {
        setState(() {
            editableItem.unitPrice = newPrice;
            _calculateTotals();
        });
    }
  }

  Future<void> _showProductSelectionDialog() async {
     final productProvider = Provider.of<ProductProvider>(context, listen: false);
    
    final Product? selectedProduct = await showDialog<Product>(
      context: context,
      builder: (ctx) => _ProductPickerDialog(productProvider: productProvider, invoiceItems: _editableItems),
    );

    if (selectedProduct == null || !mounted) return;

    ProductVariant? selectedVariant;
    if (selectedProduct.hasVariants && selectedProduct.variants.length > 1) {
      selectedVariant = await showDialog<ProductVariant>(
        context: context,
        builder: (ctx) => _VariantPickerDialog(product: selectedProduct),
      );
    } else if (selectedProduct.variants.isNotEmpty){
      selectedVariant = selectedProduct.variants.first;
    }

    if (selectedVariant == null || !mounted) return;

    _promptForQuantityAndPrice(selectedProduct, selectedVariant);
  }

  Future<void> _promptForQuantityAndPrice(Product parentProduct, ProductVariant variant) async {
    final qtyController = TextEditingController(text: '1');
    final priceController = TextEditingController(
      text: _invoiceType == InvoiceType.sale
          ? variant.sellingPrice.toStringAsFixed(2)
          : variant.purchasePrice.toStringAsFixed(2),
    );
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _QuantityAndPricePickerDialog(
        productName: parentProduct.name,
        variantName: variant.displayName,
        qtyController: qtyController,
        priceController: priceController,
        availableQty: variant.quantity, // This needs to be adjusted for edits
        invoiceType: _invoiceType,
      ),
    );

    if (result != null) {
      _addItemToInvoice(_EditableInvoiceItem(
        parentProduct: parentProduct,
        variant: variant,
        quantity: result['quantity'] as int,
        unitPrice: result['price'] as double,
      ));
    }
  }


  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    _updateItemsFromControllers();

    setState(() { _isSaving = true; });

    final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
    final productProvider = Provider.of<ProductProvider>(context, listen: false);

    final List<db_invoice_item.InvoiceItem> finalUpdatedItems = _editableItems.map((item) {
          return db_invoice_item.InvoiceItem(
            id: item.originalItemId,
            invoiceId: widget.originalInvoice.id!,
            productId: item.variant.id!,
            productName: item.displayName,
            category: item.parentProduct.category,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            purchasePrice: item.variant.purchasePrice,
            itemTotal: item.itemTotal,
          );
        }).toList();

    final updatedInvoiceData = Invoice(
      id: widget.originalInvoice.id!,
      invoiceNumber: _invoiceNumberController.text,
      date: _selectedDate,
      clientName: _clientOrSupplierNameController.text.isEmpty ? null : _clientOrSupplierNameController.text,
      items: [],
      subtotal: _subtotal,
      taxRatePercentage: double.tryParse(_taxRateController.text) ?? 0.0,
      taxAmount: _taxAmount,
      discountAmount: double.tryParse(_discountController.text) ?? 0.0,
      grandTotal: _grandTotal,
      type: widget.originalInvoice.type,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      paymentStatus: widget.originalInvoice.paymentStatus,
      amountPaid: widget.originalInvoice.amountPaid,
      lastUpdated: DateTime.now(),
    );

    String? result = await invoiceProvider.updateInvoice(
      originalInvoice: widget.originalInvoice,
      updatedInvoiceData: updatedInvoiceData,
      updatedInvoiceItems: finalUpdatedItems,
      productProvider: productProvider,
    );

    if (mounted) {
      setState(() { _isSaving = false; });
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث الفاتورة بنجاح!', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تحديث الفاتورة: $result', textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String pageTitle = 'تعديل فاتورة ${_invoiceType == InvoiceType.sale ? "بيع" : "شراء"} رقم:';
    final String clientSupplierLabel = _invoiceType == InvoiceType.sale ? 'اسم العميل (اختياري)' : 'اسم المورد (اختياري)';
    final String itemsLabelText = _invoiceType == InvoiceType.sale ? 'الأصناف المباعة' : 'الأصناف المشتراة';
    final String saveButtonLabel = 'حفظ التعديلات';

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('$pageTitle ${widget.originalInvoice.invoiceNumber}', style: TextStyle(fontFamily: 'Cairo'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('$pageTitle ${_invoiceNumberController.text}', style: TextStyle(fontFamily: 'Cairo')),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: _isSaving
                ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0)))
                : IconButton(icon: const Icon(Icons.save_alt_outlined), tooltip: saveButtonLabel, onPressed: _saveChanges),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Text('تعديل تفاصيل الفاتورة', style: theme.textTheme.titleLarge?.copyWith(color: theme.primaryColor, fontFamily: 'Cairo'), textAlign: TextAlign.right),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _invoiceNumberController,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontFamily: 'Cairo'),
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
              controller: _clientOrSupplierNameController,
              textAlign: TextAlign.right,
              style: const TextStyle(fontFamily: 'Cairo'),
              decoration: InputDecoration(labelText: clientSupplierLabel, labelStyle: const TextStyle(fontFamily: 'Cairo')),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(itemsLabelText, style: theme.textTheme.titleLarge?.copyWith(color: theme.primaryColor, fontFamily: 'Cairo'), textAlign: TextAlign.right),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('إضافة صنف جديد', style: TextStyle(fontFamily: 'Cairo')),
                  onPressed: _showProductSelectionDialog,
                  style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.secondary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildInvoiceItemsList(context),
            const SizedBox(height: 20),
            Text('ملخص الفاتورة', style: theme.textTheme.titleLarge?.copyWith(color: theme.primaryColor, fontFamily: 'Cairo'), textAlign: TextAlign.right),
            const SizedBox(height: 12),
            _buildSummaryRow(context, 'المجموع الفرعي:', '${_subtotal.toStringAsFixed(2)} ج.م'),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _taxRateController,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontFamily: 'Cairo'),
                    decoration: const InputDecoration(labelText: 'نسبة الضريبة (%)', suffixText: '%', labelStyle: TextStyle(fontFamily: 'Cairo')),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) { if (v != null && v.isNotEmpty && (double.tryParse(v) == null || double.parse(v) < 0)) return 'غير صالحة'; return null; },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(flex: 3, child: _buildSummaryRow(context, 'مبلغ الضريبة:', '${_taxAmount.toStringAsFixed(2)} ج.م')),
              ],
            ),
              TextFormField(
              controller: _discountController,
              textAlign: TextAlign.right,
              style: const TextStyle(fontFamily: 'Cairo'),
              decoration: const InputDecoration(labelText: 'مبلغ الخصم (ج.م)', suffixText: 'ج.م', labelStyle: TextStyle(fontFamily: 'Cairo')),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) { if (v != null && v.isNotEmpty && (double.tryParse(v) == null || double.parse(v) < 0)) return 'غير صالح'; if (v != null && v.isNotEmpty && (_subtotal + _taxAmount > 0) && (double.tryParse(v)! > _subtotal + _taxAmount)) return 'الخصم أكبر'; return null; },
            ),
            const Divider(height: 20, thickness: 1),
            _buildSummaryRow(context, 'الإجمالي الكلي:', '${_grandTotal.toStringAsFixed(2)} ج.م', isGrandTotal: true),
            const SizedBox(height: 20),
            TextFormField(
              controller: _notesController,
              textAlign: TextAlign.right,
              style: const TextStyle(fontFamily: 'Cairo'),
              decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)', border: OutlineInputBorder(), labelStyle: TextStyle(fontFamily: 'Cairo')),
              maxLines: 3,
            ),
            const SizedBox(height: 30),
            _isSaving
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveChanges,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: theme.primaryColor),
                      child: Text(saveButtonLabel, style: const TextStyle(fontSize: 18, fontFamily: 'Cairo', color: Colors.white)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceItemsList(BuildContext context) {
    final theme = Theme.of(context);
    if (_editableItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Center(
          child: Text('لم تتم إضافة أصناف بعد.', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo', color: theme.textTheme.bodyMedium?.color)),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _editableItems.length,
      itemBuilder: (ctx, index) {
        final item = _editableItems[index];
        final quantityController = _itemQuantityControllers[item.itemKey]!;
        final priceController = _itemPriceControllers[item.itemKey]!;
        
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
                    Expanded(child: Text(item.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'), textAlign: TextAlign.right)),
                    IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _removeItem(index), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: quantityController,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontFamily: 'Cairo'),
                        decoration: const InputDecoration(labelText: 'الكمية', isDense: true, labelStyle: TextStyle(fontFamily: 'Cairo')),
                        keyboardType: TextInputType.number,
                        onChanged: (value) => _updateItemQuantityFromField(index, value),
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
                        controller: priceController,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontFamily: 'Cairo'),
                        decoration: InputDecoration(
                          labelText: _invoiceType == InvoiceType.sale ? 'سعر بيع الوحدة' : 'سعر شراء الوحدة',
                          labelStyle: const TextStyle(fontFamily: 'Cairo'),
                          isDense: true,
                          suffixText: 'ج.م',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        readOnly: _invoiceType == InvoiceType.sale,
                        onChanged: (value) => _updateItemPriceFromField(index, value),
                        validator: (value) { if (value == null || value.isEmpty) return 'مطلوب'; final price = double.tryParse(value); if (price == null || price < 0) return 'غير صالح'; return null; },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('الإجمالي: ${NumberFormat.currency(locale: 'ar', symbol: 'ج.م', decimalDigits: 2).format(item.itemTotal)}', textAlign: TextAlign.left, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(BuildContext context, String label, String value, {bool isGrandTotal = false}) {
    final theme = Theme.of(context);
    TextStyle? defaultStyle = isGrandTotal ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontFamily: 'Cairo') : theme.textTheme.bodyLarge?.copyWith(fontFamily: 'Cairo');
    defaultStyle ??= TextStyle(fontFamily: 'Cairo', fontWeight: isGrandTotal ? FontWeight.bold : FontWeight.normal, fontSize: isGrandTotal ? 16 : 14);

    TextStyle? valueStyle = isGrandTotal ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.primaryColor, fontFamily: 'Cairo') : theme.textTheme.bodyLarge?.copyWith(fontFamily: 'Cairo');
    valueStyle ??= TextStyle(fontFamily: 'Cairo', fontWeight: isGrandTotal ? FontWeight.bold : FontWeight.normal, fontSize: isGrandTotal ? 16 : 14, color: isGrandTotal ? theme.primaryColor : null);

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

// --- HELPER WIDGETS ---

class _ProductPickerDialog extends StatefulWidget {
  final ProductProvider productProvider;
  const _ProductPickerDialog({required this.productProvider, required List<_EditableInvoiceItem> invoiceItems});

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
      title: const Text('إضافة منتج', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
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
                        subtitle: Text('الصنف: ${product.category} - المتاح: ${product.totalQuantity}', textAlign: TextAlign.right),
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

class _QuantityAndPricePickerDialog extends StatelessWidget {
  final String productName;
  final String variantName;
  final TextEditingController qtyController;
  final TextEditingController priceController;
  final int availableQty;
  final InvoiceType invoiceType;

  const _QuantityAndPricePickerDialog({
    required this.productName,
    required this.variantName,
    required this.qtyController,
    required this.priceController,
    required this.availableQty,
    required this.invoiceType,
  });

  @override
  Widget build(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    return AlertDialog(
      title: Text('أدخل الكمية والسعر لـ $productName (${variantName.isEmpty ? "افتراضي" : variantName})', textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo')),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                labelText: 'الكمية*',
                hintText: invoiceType == InvoiceType.sale ? 'المتاح: $availableQty' : null,
              ),
              autofocus: true,
              validator: (value) {
                if (value == null || value.isEmpty) return 'الكمية مطلوبة';
                final qty = int.tryParse(value);
                if (qty == null || qty <= 0) return 'كمية غير صالحة';
                if (invoiceType == InvoiceType.sale && qty > availableQty) return 'الكمية أكبر من المتاح';
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                labelText: invoiceType == InvoiceType.sale ? 'سعر البيع*' : 'سعر الشراء*', 
                suffixText: 'ج.م'
              ),
              readOnly: invoiceType == InvoiceType.sale,
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
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("إلغاء")),
        ElevatedButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.of(context).pop({
                'quantity': int.parse(qtyController.text),
                'price': double.parse(priceController.text),
              });
            }
          },
          child: const Text("موافق"),
        ),
      ],
    );
  }
}




// // lib/screens/edit_invoice_screen.dart
// import 'package:flutter/material.dart';
// import 'package:fouad_stock/enum/filter_enums.dart';
// import 'package:fouad_stock/model/invoice_item_model.dart' as db_invoice_item;
// import 'package:fouad_stock/model/invoice_model.dart';
// import 'package:fouad_stock/model/product_model.dart';
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
// import '../providers/product_provider.dart';
// import '../providers/invoice_provider.dart';
// import '../helpers/db_helpers.dart';

// class _EditableInvoiceItem {
//   final int? originalItemId;
//   Product product;
//   int quantity;
//   double unitPrice;
//   final String itemKey;

//   _EditableInvoiceItem({
//     this.originalItemId,
//     required this.product,
//     required this.quantity,
//     required this.unitPrice,
//   }) : itemKey = originalItemId?.toString() ?? UniqueKey().toString();

//   double get itemTotal => quantity * unitPrice;

//   @override
//   bool operator ==(Object other) =>
//       identical(this, other) ||
//       other is _EditableInvoiceItem &&
//           runtimeType == other.runtimeType &&
//           itemKey == other.itemKey;

//   @override
//   int get hashCode => itemKey.hashCode;
// }

// class EditInvoiceScreen extends StatefulWidget {
//   final Invoice originalInvoice;

//   const EditInvoiceScreen({super.key, required this.originalInvoice});

//   @override
//   State<EditInvoiceScreen> createState() => _EditInvoiceScreenState();
// }

// class _EditInvoiceScreenState extends State<EditInvoiceScreen> {
//   final _formKey = GlobalKey<FormState>();
//   late DateFormat _arabicDateFormat;

//   late TextEditingController _invoiceNumberController;
//   late DateTime _selectedDate;
//   late TextEditingController _clientOrSupplierNameController;
//   late TextEditingController _taxRateController;
//   late TextEditingController _discountController;
//   late TextEditingController _notesController;

//   final List<_EditableInvoiceItem> _editableItems = [];
//   final Map<String, TextEditingController> _itemQuantityControllers = {};
//   final Map<String, TextEditingController> _itemPriceControllers = {};

//   double _subtotal = 0.0;
//   double _taxAmount = 0.0;
//   double _grandTotal = 0.0;

//   bool _isLoading = true;
//   bool _isSaving = false;
//   late InvoiceType _invoiceType;

//   @override
//   void initState() {
//     super.initState();
//     _arabicDateFormat = DateFormat.yMMMd('ar');
//     _invoiceType = widget.originalInvoice.type;

//     _invoiceNumberController = TextEditingController(
//       text: widget.originalInvoice.invoiceNumber,
//     );
//     _selectedDate = widget.originalInvoice.date;
//     _clientOrSupplierNameController = TextEditingController(
//       text: widget.originalInvoice.clientName ?? '',
//     );
//     _taxRateController = TextEditingController(
//       text: widget.originalInvoice.taxRatePercentage.toString(),
//     );
//     _discountController = TextEditingController(
//       text: widget.originalInvoice.discountAmount.toString(),
//     );
//     _notesController = TextEditingController(
//       text: widget.originalInvoice.notes ?? '',
//     );

//     _taxRateController.addListener(_calculateTotals);
//     _discountController.addListener(_calculateTotals);

//     _loadInvoiceItems();
//   }

//   Future<void> _loadInvoiceItems() async {
//     if (!mounted) return;
//     setState(() {
//       _isLoading = true;
//     });

//     _editableItems.clear();
//     _itemQuantityControllers.forEach((_, controller) => controller.dispose());
//     _itemQuantityControllers.clear();
//     _itemPriceControllers.forEach((_, controller) => controller.dispose());
//     _itemPriceControllers.clear();

//     for (var dbItem in widget.originalInvoice.items) {
//       Product? product = await DatabaseHelper.instance.getProductById(
//         dbItem.productId,
//       );
//       if (product != null) {
//         final editableItem = _EditableInvoiceItem(
//           originalItemId: dbItem.id,
//           product: product,
//           quantity: dbItem.quantity,
//           unitPrice: dbItem.unitPrice,
//         );
//         _editableItems.add(editableItem);
//         _itemQuantityControllers[editableItem.itemKey] = TextEditingController(
//           text: dbItem.quantity.toString(),
//         );
//         _itemPriceControllers[editableItem.itemKey] = TextEditingController(
//           text: dbItem.unitPrice.toStringAsFixed(2),
//         );
//       } else {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(
//                 'لم يتم العثور على المنتج "${dbItem.productName}" (ID: ${dbItem.productId}).',
//                 textAlign: TextAlign.right,
//                 style: const TextStyle(
//                   color: Colors.orange,
//                   fontFamily: 'Cairo',
//                 ),
//               ),
//             ),
//           );
//         }
//       }
//     }
//     _calculateTotals();
//     if (mounted) {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }

//   @override
//   void dispose() {
//     _invoiceNumberController.dispose();
//     _clientOrSupplierNameController.dispose();
//     _taxRateController.dispose();
//     _discountController.dispose();
//     _notesController.dispose();
//     _itemQuantityControllers.forEach((_, controller) => controller.dispose());
//     _itemPriceControllers.forEach((_, controller) => controller.dispose());
//     super.dispose();
//   }

//   void _calculateTotals() {
//     double currentSubtotal = 0;
//     for (var item in _editableItems) {
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

//   void _addItemToInvoice(_EditableInvoiceItem newItem) async {
//     int existingVisualIndex = _editableItems.indexWhere(
//       (item) =>
//           item.product.id == newItem.product.id &&
//           item.unitPrice == newItem.unitPrice,
//     );
//     bool mergeQuantities = existingVisualIndex != -1;

//     if (mergeQuantities) {
//       final editableItem = _editableItems[existingVisualIndex];
//       Product? pDetails = await DatabaseHelper.instance.getProductById(
//         editableItem.product.id!,
//       );
//       int stockQty = pDetails?.quantity ?? 0;
//       int currentInvoiceQty = editableItem.quantity;
//       int requestedAdditionalQty = newItem.quantity;
//       int finalRequestedQty = currentInvoiceQty + requestedAdditionalQty;

//       if (_invoiceType == InvoiceType.sale) {
//         int originalItemQtyOnThisLine = 0;
//         if (editableItem.originalItemId != null) {
//           var originalDbItem = widget.originalInvoice.items.firstWhere(
//             (dbItem) => dbItem.id == editableItem.originalItemId,
//             orElse: () => db_invoice_item.InvoiceItem(
//               id: -1,
//               invoiceId: 0,
//               productId: 0,
//               productName: '',
//               quantity: 0,
//               unitPrice: 0,
//               purchasePrice: 0, // FIX: Added required parameter
//               itemTotal: 0,
//             ),
//           );
//           originalItemQtyOnThisLine = originalDbItem.quantity;
//         }
//         int effectivelyAvailable = stockQty + originalItemQtyOnThisLine;
//         if (finalRequestedQty > effectivelyAvailable) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(
//                 'لا يمكن إضافة المزيد. الكمية المتوفرة ($effectivelyAvailable) للمنتج "${editableItem.product.name}" غير كافية.',
//                 textAlign: TextAlign.right,
//                 style: const TextStyle(fontFamily: 'Cairo'),
//               ),
//             ),
//           );
//           return;
//         }
//       }
//       setState(() {
//         editableItem.quantity = finalRequestedQty;
//         _itemQuantityControllers[editableItem.itemKey]?.text = finalRequestedQty
//             .toString();
//       });
//     } else {
//       if (_invoiceType == InvoiceType.sale) {
//         Product? pDetails = await DatabaseHelper.instance.getProductById(
//           newItem.product.id!,
//         );
//         int stockQty = pDetails?.quantity ?? 0;
//         if (newItem.quantity > stockQty) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(
//                 'الكمية المطلوبة للمنتج "${newItem.product.name}" (${newItem.quantity}) أكبر من المتوفر بالمخزون ($stockQty).',
//                 textAlign: TextAlign.right,
//                 style: const TextStyle(fontFamily: 'Cairo'),
//               ),
//             ),
//           );
//           return;
//         }
//       }
//       setState(() {
//         _editableItems.add(newItem);
//         _itemQuantityControllers[newItem.itemKey] = TextEditingController(
//           text: newItem.quantity.toString(),
//         );
//         _itemPriceControllers[newItem.itemKey] = TextEditingController(
//           text: newItem.unitPrice.toStringAsFixed(2),
//         );
//       });
//     }
//     _calculateTotals();
//   }

//   void _removeItem(int uiIndex) {
//     if (uiIndex < 0 || uiIndex >= _editableItems.length) return;
//     setState(() {
//       final itemToRemove = _editableItems[uiIndex];
//       _itemQuantityControllers.remove(itemToRemove.itemKey)?.dispose();
//       _itemPriceControllers.remove(itemToRemove.itemKey)?.dispose();
//       _editableItems.removeAt(uiIndex);
//     });
//     _calculateTotals();
//   }

//   void _updateItemQuantityFromField(int uiIndex, String value) async {
//     final editableItem = _editableItems[uiIndex];
//     final newQty = int.tryParse(value);

//     if (newQty == null || newQty <= 0) {
//       _itemQuantityControllers[editableItem.itemKey]?.text = editableItem
//           .quantity
//           .toString();
//       if (mounted)
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text(
//               'الكمية يجب أن تكون رقماً صحيحاً أكبر من صفر.',
//               textAlign: TextAlign.right,
//               style: TextStyle(fontFamily: 'Cairo'),
//             ),
//           ),
//         );
//       return;
//     }

//     if (_invoiceType == InvoiceType.sale) {
//       final productInDb = await DatabaseHelper.instance.getProductById(
//         editableItem.product.id!,
//       );
//       int originalItemQtyFromDbInvoice = 0;
//       if (editableItem.originalItemId != null) {
//         var originalDbItem = widget.originalInvoice.items.firstWhere(
//           (item) => item.id == editableItem.originalItemId,
//           orElse: () => db_invoice_item.InvoiceItem(
//             id: -1,
//             invoiceId: 0,
//             productId: editableItem.product.id!,
//             productName: '',
//             quantity: 0,
//             unitPrice: 0,
//             purchasePrice: 0, // FIX: Added required parameter
//             itemTotal: 0,
//           ),
//         );
//         originalItemQtyFromDbInvoice = originalDbItem.quantity;
//       }
//       int currentStockInDb = productInDb?.quantity ?? 0;
//       int effectivelyAvailable =
//           currentStockInDb + originalItemQtyFromDbInvoice;

//       if (newQty > effectivelyAvailable) {
//         if (mounted)
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(
//                 'لا يمكن تحديد هذه الكمية. المخزون الفعلي بعد إرجاع الكمية الأصلية (${effectivelyAvailable}) غير كاف للمنتج "${editableItem.product.name}".',
//                 textAlign: TextAlign.right,
//                 style: const TextStyle(fontFamily: 'Cairo'),
//               ),
//             ),
//           );
//         _itemQuantityControllers[editableItem.itemKey]?.text = editableItem
//             .quantity
//             .toString();
//         return;
//       }
//     }
//     setState(() {
//       editableItem.quantity = newQty;
//       _calculateTotals();
//     });
//   }

//   void _updateItemPriceFromField(int uiIndex, String value) {
//     final editableItem = _editableItems[uiIndex];
//     final newPrice = double.tryParse(value);
//     if (newPrice == null || newPrice < 0) {
//       _itemPriceControllers[editableItem.itemKey]?.text = editableItem.unitPrice
//           .toStringAsFixed(2);
//       if (mounted)
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text(
//               'السعر يجب أن يكون رقماً صالحاً.',
//               textAlign: TextAlign.right,
//               style: TextStyle(fontFamily: 'Cairo'),
//             ),
//           ),
//         );
//       return;
//     }
//     setState(() {
//       editableItem.unitPrice = newPrice;
//       _calculateTotals();
//     });
//   }

//   Future<void> _showProductSelectionDialog() async {
//     final productProvider = Provider.of<ProductProvider>(context, listen: false);
//     await productProvider.fetchProducts(filter: ProductListFilter.none);
//     if (!mounted) return;

//     if (productProvider.products.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('لا توجد منتجات في المخزون لإضافتها.', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo'))),
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
//               title: Text(
//                 _invoiceType == InvoiceType.sale ? 'إضافة منتج للبيع' : 'إضافة منتج للشراء',
//                 textAlign: TextAlign.right,
//                 style: TextStyle(fontFamily: 'Cairo'),
//               ),
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
//                               int currentStockInDb = product.quantity;
//                               int qtyAlreadyOnThisInvoiceForThisProduct = _editableItems.where((item) => item.product.id == product.id).fold(0, (sum, item) => sum + item.quantity);
//                               int originalQtyOnThisInvoice = widget.originalInvoice.items.where((item) => item.productId == product.id).fold(0, (sum, item) => sum + item.quantity);
                              
//                               int effectivelyAvailable = currentStockInDb + originalQtyOnThisInvoice - qtyAlreadyOnThisInvoiceForThisProduct;
//                               bool canAdd = _invoiceType == InvoiceType.purchase || (_invoiceType == InvoiceType.sale && effectivelyAvailable > 0);
                              
//                               String availabilityText = _invoiceType == InvoiceType.sale
//                                   ? 'المتاح للإضافة: $effectivelyAvailable - سعر البيع: ${product.sellingPrice.toStringAsFixed(2)} ج.م'
//                                   : 'الحالي بالمخزن: ${product.quantity} - سعر الشراء: ${product.purchasePrice.toStringAsFixed(2)} ج.م';

//                               return ListTile(
//                                 title: Text(product.name, textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
//                                 subtitle: Text(availabilityText, textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontFamily: 'Cairo')),
//                                 onTap: canAdd ? () => Navigator.of(ctx).pop(product) : null,
//                                 enabled: canAdd,
//                                 trailing: canAdd ? null : const Text("نفذ", style: TextStyle(color: Colors.red, fontFamily: 'Cairo')),
//                               );
//                             },
//                           ),
//                     ),
//                   ],
//                 ),
//               ),
//               actions: [
//                 TextButton(
//                   onPressed: () => Navigator.of(ctx).pop(),
//                   child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo')),
//                 ),
//               ],
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
//     final priceController = TextEditingController(
//       text: _invoiceType == InvoiceType.sale
//           ? product.sellingPrice.toStringAsFixed(2)
//           : (product.purchasePrice > 0 ? product.purchasePrice.toStringAsFixed(2) : ''),
//     );
//     final GlobalKey<FormState> dialogFormKey = GlobalKey<FormState>();

//     Product? freshProductDetails = await DatabaseHelper.instance.getProductById(product.id!);
//     int currentProductStock = freshProductDetails?.quantity ?? product.quantity;

//     int qtyAlreadyOnThisInvoiceForThisProduct = _editableItems.where((item) => item.product.id == product.id).fold(0, (sum, item) => sum + item.quantity);
//     int originalQtySoldForThisProduct = 0;
//     if (_invoiceType == InvoiceType.sale) {
//       widget.originalInvoice.items.where((item) => item.productId == product.id).forEach((item) { originalQtySoldForThisProduct += item.quantity; });
//     }
//     int maxAllowedForNewSaleItem = currentProductStock + originalQtySoldForThisProduct - qtyAlreadyOnThisInvoiceForThisProduct;

//     final result = await showDialog<Map<String, dynamic>>(
//       context: context,
//       builder: (BuildContext ctx) {
//         return AlertDialog(
//           title: Text('أدخل الكمية والسعر لـ "${product.name}"', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
//           content: Form(
//             key: dialogFormKey,
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 TextFormField(
//                   controller: qtyController,
//                   keyboardType: TextInputType.number,
//                   textAlign: TextAlign.right,
//                   style: const TextStyle(fontFamily: 'Cairo'),
//                   decoration: InputDecoration(
//                     labelText: 'الكمية*',
//                     labelStyle: const TextStyle(fontFamily: 'Cairo'),
//                     hintText: _invoiceType == InvoiceType.sale ? 'الحد الأقصى للإضافة: $maxAllowedForNewSaleItem' : 'أدخل الكمية',
//                     hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
//                   ),
//                   autofocus: true,
//                   validator: (value) {
//                     if (value == null || value.isEmpty) return 'الكمية مطلوبة';
//                     final qty = int.tryParse(value);
//                     if (qty == null || qty <= 0) return 'كمية غير صالحة';
//                     if (_invoiceType == InvoiceType.sale && qty > maxAllowedForNewSaleItem) {
//                       return 'الكمية أكبر من المتاح للإضافة ($maxAllowedForNewSaleItem)';
//                     }
//                     return null;
//                   },
//                 ),
//                 const SizedBox(height: 10),
//                 TextFormField(
//                   controller: priceController,
//                   keyboardType: const TextInputType.numberWithOptions(decimal: true),
//                   textAlign: TextAlign.right,
//                   style: const TextStyle(fontFamily: 'Cairo'),
//                   decoration: InputDecoration(
//                     labelText: _invoiceType == InvoiceType.sale ? 'سعر بيع الوحدة*' : 'سعر شراء الوحدة*',
//                     labelStyle: const TextStyle(fontFamily: 'Cairo'),
//                     suffixText: 'ج.م',
//                   ),
//                   readOnly: _invoiceType == InvoiceType.sale,
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
//             TextButton(
//               onPressed: () => Navigator.of(ctx).pop(),
//               child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo')),
//             ),
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
//       _addItemToInvoice(
//         _EditableInvoiceItem(
//           product: product,
//           quantity: result['quantity'] as int,
//           unitPrice: result['price'] as double,
//         ),
//       );
//     }
//   }

//   Future<void> _saveChanges() async {
//     if (!_formKey.currentState!.validate()) {
//       return;
//     }
    
//     setState(() { _isSaving = true; });

//     final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
//     final productProvider = Provider.of<ProductProvider>(context, listen: false);

//     final List<db_invoice_item.InvoiceItem> finalUpdatedItems = _editableItems.map((item) {
//           return db_invoice_item.InvoiceItem(
//             id: item.originalItemId,
//             invoiceId: widget.originalInvoice.id!,
//             productId: item.product.id!,
//             productName: item.product.name,
//             quantity: item.quantity,
//             unitPrice: item.unitPrice,
//             purchasePrice: item.product.purchasePrice,
//             itemTotal: item.itemTotal,
//           );
//         }).toList();

//     final updatedInvoiceData = Invoice(
//       id: widget.originalInvoice.id!,
//       invoiceNumber: _invoiceNumberController.text,
//       date: _selectedDate,
//       clientName: _clientOrSupplierNameController.text.isEmpty ? null : _clientOrSupplierNameController.text,
//       items: [],
//       subtotal: _subtotal,
//       taxRatePercentage: double.tryParse(_taxRateController.text) ?? 0.0,
//       taxAmount: _taxAmount,
//       discountAmount: double.tryParse(_discountController.text) ?? 0.0,
//       grandTotal: _grandTotal,
//       type: widget.originalInvoice.type,
//       notes: _notesController.text.isEmpty ? null : _notesController.text,
//       paymentStatus: widget.originalInvoice.paymentStatus,
//       amountPaid: widget.originalInvoice.amountPaid,
//       lastUpdated: DateTime.now(),
//     );

//     String? result = await invoiceProvider.updateInvoice(
//       originalInvoice: widget.originalInvoice,
//       updatedInvoiceData: updatedInvoiceData,
//       updatedInvoiceItems: finalUpdatedItems,
//       productProvider: productProvider,
//     );

//     if (mounted) {
//       setState(() { _isSaving = false; });
//       if (result == null) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('تم تحديث الفاتورة بنجاح!', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
//             backgroundColor: Colors.green,
//           ),
//         );
//         Navigator.of(context).pop(true);
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('فشل تحديث الفاتورة: $result', textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo')),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final String pageTitle = 'تعديل فاتورة ${_invoiceType == InvoiceType.sale ? "بيع" : "شراء"} رقم:';
//     final String clientSupplierLabel = _invoiceType == InvoiceType.sale ? 'اسم العميل (اختياري)' : 'اسم المورد (اختياري)';
//     final String itemsLabelText = _invoiceType == InvoiceType.sale ? 'الأصناف المباعة' : 'الأصناف المشتراة';
//     final String saveButtonLabel = 'حفظ التعديلات';

//     if (_isLoading) {
//       return Scaffold(
//         appBar: AppBar(title: Text('$pageTitle ${widget.originalInvoice.invoiceNumber}', style: TextStyle(fontFamily: 'Cairo'))),
//         body: const Center(child: CircularProgressIndicator()),
//       );
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: Text('$pageTitle ${_invoiceNumberController.text}', style: TextStyle(fontFamily: 'Cairo')),
//         actions: [
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 12.0),
//             child: _isSaving
//                 ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0)))
//                 : IconButton(icon: const Icon(Icons.save_alt_outlined), tooltip: saveButtonLabel, onPressed: _saveChanges),
//           ),
//         ],
//       ),
//       body: Form(
//         key: _formKey,
//         child: ListView(
//           padding: const EdgeInsets.all(16.0),
//           children: [
//             Text('تعديل تفاصيل الفاتورة', style: theme.textTheme.titleLarge?.copyWith(color: theme.primaryColor, fontFamily: 'Cairo'), textAlign: TextAlign.right),
//             const SizedBox(height: 12),
//             Row(
//               children: [
//                 Expanded(
//                   child: TextFormField(
//                     controller: _invoiceNumberController,
//                     textAlign: TextAlign.right,
//                     style: const TextStyle(fontFamily: 'Cairo'),
//                     decoration: const InputDecoration(labelText: 'رقم الفاتورة', labelStyle: TextStyle(fontFamily: 'Cairo')),
//                   ),
//                 ),
//                 const SizedBox(width: 16),
//                 Expanded(
//                   child: InkWell(
//                     onTap: () => _selectDate(context),
//                     child: InputDecorator(
//                       decoration: const InputDecoration(labelText: 'التاريخ', labelStyle: TextStyle(fontFamily: 'Cairo')),
//                       child: Text(_arabicDateFormat.format(_selectedDate), textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo')),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 12),
//             TextFormField(
//               controller: _clientOrSupplierNameController,
//               textAlign: TextAlign.right,
//               style: const TextStyle(fontFamily: 'Cairo'),
//               decoration: InputDecoration(labelText: clientSupplierLabel, labelStyle: const TextStyle(fontFamily: 'Cairo')),
//             ),
//             const SizedBox(height: 20),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text(itemsLabelText, style: theme.textTheme.titleLarge?.copyWith(color: theme.primaryColor, fontFamily: 'Cairo'), textAlign: TextAlign.right),
//                 ElevatedButton.icon(
//                   icon: const Icon(Icons.add_shopping_cart),
//                   label: const Text('إضافة صنف جديد', style: TextStyle(fontFamily: 'Cairo')),
//                   onPressed: _showProductSelectionDialog,
//                   style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.secondary),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 8),
//             _buildInvoiceItemsList(context),
//             const SizedBox(height: 20),
//             Text('ملخص الفاتورة', style: theme.textTheme.titleLarge?.copyWith(color: theme.primaryColor, fontFamily: 'Cairo'), textAlign: TextAlign.right),
//             const SizedBox(height: 12),
//             _buildSummaryRow(context, 'المجموع الفرعي:', '${_subtotal.toStringAsFixed(2)} ج.م'),
//             Row(
//               children: [
//                 Expanded(
//                   flex: 2,
//                   child: TextFormField(
//                     controller: _taxRateController,
//                     textAlign: TextAlign.right,
//                     style: const TextStyle(fontFamily: 'Cairo'),
//                     decoration: const InputDecoration(labelText: 'نسبة الضريبة (%)', suffixText: '%', labelStyle: TextStyle(fontFamily: 'Cairo')),
//                     keyboardType: const TextInputType.numberWithOptions(decimal: true),
//                     validator: (v) { if (v != null && v.isNotEmpty && (double.tryParse(v) == null || double.parse(v) < 0)) return 'غير صالحة'; return null; },
//                   ),
//                 ),
//                 const SizedBox(width: 16),
//                 Expanded(flex: 3, child: _buildSummaryRow(context, 'مبلغ الضريبة:', '${_taxAmount.toStringAsFixed(2)} ج.م')),
//               ],
//             ),
//               TextFormField(
//               controller: _discountController,
//               textAlign: TextAlign.right,
//               style: const TextStyle(fontFamily: 'Cairo'),
//               decoration: const InputDecoration(labelText: 'مبلغ الخصم (ج.م)', suffixText: 'ج.م', labelStyle: TextStyle(fontFamily: 'Cairo')),
//               keyboardType: const TextInputType.numberWithOptions(decimal: true),
//               validator: (v) { if (v != null && v.isNotEmpty && (double.tryParse(v) == null || double.parse(v) < 0)) return 'غير صالح'; if (v != null && v.isNotEmpty && (_subtotal + _taxAmount > 0) && (double.tryParse(v)! > _subtotal + _taxAmount)) return 'الخصم أكبر'; return null; },
//             ),
//             const Divider(height: 20, thickness: 1),
//             _buildSummaryRow(context, 'الإجمالي الكلي:', '${_grandTotal.toStringAsFixed(2)} ج.م', isGrandTotal: true),
//             const SizedBox(height: 20),
//             TextFormField(
//               controller: _notesController,
//               textAlign: TextAlign.right,
//               style: const TextStyle(fontFamily: 'Cairo'),
//               decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)', border: OutlineInputBorder(), labelStyle: TextStyle(fontFamily: 'Cairo')),
//               maxLines: 3,
//             ),
//             const SizedBox(height: 30),
//             _isSaving
//                 ? const Center(child: CircularProgressIndicator())
//                 : SizedBox(
//                     width: double.infinity,
//                     child: ElevatedButton(
//                       onPressed: _saveChanges,
//                       style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: theme.primaryColor),
//                       child: Text(saveButtonLabel, style: const TextStyle(fontSize: 18, fontFamily: 'Cairo', color: Colors.white)),
//                     ),
//                   ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildInvoiceItemsList(BuildContext context) {
//     final theme = Theme.of(context);
//     if (_editableItems.isEmpty) {
//       return Padding(
//         padding: const EdgeInsets.symmetric(vertical: 20.0),
//         child: Center(
//           child: Text('لم تتم إضافة أصناف بعد.', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo', color: theme.textTheme.bodyMedium?.color)),
//         ),
//       );
//     }
//     return ListView.builder(
//       shrinkWrap: true,
//       physics: const NeverScrollableScrollPhysics(),
//       itemCount: _editableItems.length,
//       itemBuilder: (ctx, index) {
//         final item = _editableItems[index];
//         final quantityController = _itemQuantityControllers[item.itemKey] ?? TextEditingController(text: item.quantity.toString());
//         if (_itemQuantityControllers[item.itemKey] == null) _itemQuantityControllers[item.itemKey] = quantityController;

//         final priceController = _itemPriceControllers[item.itemKey] ?? TextEditingController(text: item.unitPrice.toStringAsFixed(2));
//         if (_itemPriceControllers[item.itemKey] == null) _itemPriceControllers[item.itemKey] = priceController;

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
//                     Expanded(child: Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'), textAlign: TextAlign.right)),
//                     IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _removeItem(index), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
//                   ],
//                 ),
//                 const SizedBox(height: 8),
//                 Row(
//                   children: [
//                     Expanded(
//                       flex: 2,
//                       child: TextFormField(
//                         controller: quantityController,
//                         textAlign: TextAlign.right,
//                         style: const TextStyle(fontFamily: 'Cairo'),
//                         decoration: const InputDecoration(labelText: 'الكمية', isDense: true, labelStyle: TextStyle(fontFamily: 'Cairo')),
//                         keyboardType: TextInputType.number,
//                         onFieldSubmitted: (value) { _updateItemQuantityFromField(index, value); },
//                         validator: (value) {
//                           if (value == null || value.isEmpty) return 'مطلوب';
//                           final qty = int.tryParse(value);
//                           if (qty == null || qty <= 0) return 'غير صالح';
//                           if (_invoiceType == InvoiceType.sale) {
//                             int originalItemQty = 0;
//                             if (item.originalItemId != null) {
//                               var originalDbItem = widget.originalInvoice.items.firstWhere((dbItem) => dbItem.id == item.originalItemId, orElse: () => db_invoice_item.InvoiceItem(id: -1, invoiceId: 0, productId: item.product.id!, productName: '', quantity: 0, unitPrice: 0, purchasePrice: 0, itemTotal: 0));
//                               originalItemQty = originalDbItem.quantity;
//                             }
//                             final productInApp = Provider.of<ProductProvider>(context, listen: false).getProductByIdFromCache(item.product.id!);
//                             int effectivelyAvailable = (productInApp?.quantity ?? 0) + originalItemQty;
//                             if (qty > effectivelyAvailable) return 'أكبر من المتاح ($effectivelyAvailable)';
//                           }
//                           return null;
//                         },
//                       ),
//                     ),
//                     const SizedBox(width: 10),
//                     Expanded(
//                       flex: 3,
//                       child: TextFormField(
//                         controller: priceController,
//                         textAlign: TextAlign.right,
//                         style: const TextStyle(fontFamily: 'Cairo'),
//                         decoration: InputDecoration(
//                           labelText: _invoiceType == InvoiceType.sale ? 'سعر بيع الوحدة' : 'سعر شراء الوحدة',
//                           labelStyle: const TextStyle(fontFamily: 'Cairo'),
//                           isDense: true,
//                           suffixText: 'ج.م',
//                         ),
//                         keyboardType: const TextInputType.numberWithOptions(decimal: true),
//                         readOnly: _invoiceType == InvoiceType.sale,
//                         onFieldSubmitted: (value) { _updateItemPriceFromField(index, value); },
//                         validator: (value) { if (value == null || value.isEmpty) return 'مطلوب'; final price = double.tryParse(value); if (price == null || price < 0) return 'غير صالح'; return null; },
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 8),
//                 Align(
//                   alignment: Alignment.centerLeft,
//                   child: Text('الإجمالي: ${NumberFormat.currency(locale: 'ar', symbol: 'ج.م', decimalDigits: 2).format(item.itemTotal)}', textAlign: TextAlign.left, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildSummaryRow(BuildContext context, String label, String value, {bool isGrandTotal = false}) {
//     final theme = Theme.of(context);
//     TextStyle? defaultStyle = isGrandTotal ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontFamily: 'Cairo') : theme.textTheme.bodyLarge?.copyWith(fontFamily: 'Cairo');
//     defaultStyle ??= TextStyle(fontFamily: 'Cairo', fontWeight: isGrandTotal ? FontWeight.bold : FontWeight.normal, fontSize: isGrandTotal ? 16 : 14);

//     TextStyle? valueStyle = isGrandTotal ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.primaryColor, fontFamily: 'Cairo') : theme.textTheme.bodyLarge?.copyWith(fontFamily: 'Cairo');
//     valueStyle ??= TextStyle(fontFamily: 'Cairo', fontWeight: isGrandTotal ? FontWeight.bold : FontWeight.normal, fontSize: isGrandTotal ? 16 : 14, color: isGrandTotal ? theme.primaryColor : null);

//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4.0),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(label, style: defaultStyle, textAlign: TextAlign.right),
//           Text(value, style: valueStyle, textAlign: TextAlign.left),
//         ],
//       ),
//     );
//   }
// }
