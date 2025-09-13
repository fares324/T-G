// lib/screens/price_quote_screen.dart
import 'package:flutter/material.dart';
import 'package:fouad_stock/model/invoice_model.dart';
import 'package:fouad_stock/model/product_model.dart';
import 'package:fouad_stock/model/product_variant_model.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../services/pdf_invoice_service.dart';
import 'package:fouad_stock/model/invoice_item_model.dart' as db_invoice_item;

class _QuoteItem {
  final Product parentProduct;
  final ProductVariant variant;
  int quantity;
  double unitPrice; // Changed to be editable

  _QuoteItem({
    required this.parentProduct,
    required this.variant,
    this.quantity = 1,
    required this.unitPrice,
  });

  String get displayName => variant.displayName.isEmpty
      ? parentProduct.name
      : '${parentProduct.name} (${variant.displayName})';

  double get itemTotal => quantity * unitPrice;
}

class PriceQuoteScreen extends StatefulWidget {
  const PriceQuoteScreen({super.key});

  @override
  State<PriceQuoteScreen> createState() => _PriceQuoteScreenState();
}

class _PriceQuoteScreenState extends State<PriceQuoteScreen> {
  final _formKey = GlobalKey<FormState>();
  late DateFormat _arabicDateFormat;

  DateTime _selectedDate = DateTime.now();
  final _clientNameController = TextEditingController();
  final _taxRateController = TextEditingController(text: '0');
  final _discountController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  final List<_QuoteItem> _quoteItems = [];
  // --- NEW: Controllers for editable prices ---
  final Map<String, TextEditingController> _itemPriceControllers = {};


  double _subtotal = 0.0;
  double _taxAmount = 0.0;
  double _grandTotal = 0.0;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _arabicDateFormat = DateFormat.yMMMd('ar');
    _taxRateController.addListener(_calculateTotals);
    _discountController.addListener(_calculateTotals);
    Future.microtask(() => Provider.of<ProductProvider>(context, listen: false).fetchProducts());
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _taxRateController.dispose();
    _discountController.dispose();
    _notesController.dispose();
    _itemPriceControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  void _calculateTotals() {
    double currentSubtotal = _quoteItems.fold(0.0, (sum, item) => sum + item.itemTotal);
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
      setState(() { _selectedDate = picked; });
    }
  }

  void _addItemToQuote(_QuoteItem newItem) {
    int existingIndex = _quoteItems.indexWhere((item) => item.variant.id == newItem.variant.id);
    
    if (existingIndex != -1) {
      setState(() { _quoteItems[existingIndex].quantity += newItem.quantity; });
    } else {
      setState(() { 
        _quoteItems.add(newItem); 
        _itemPriceControllers[newItem.variant.id.toString()] = TextEditingController(text: newItem.unitPrice.toStringAsFixed(2));
      });
    }
    _calculateTotals();
  }

  void _removeItem(int index) {
    setState(() {
      final itemToRemove = _quoteItems[index];
      _itemPriceControllers.remove(itemToRemove.variant.id.toString())?.dispose();
      _quoteItems.removeAt(index);
      _calculateTotals();
    });
  }

  void _updateItemQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) {
      _removeItem(index);
      return;
    }
    setState(() {
      _quoteItems[index].quantity = newQuantity;
      _calculateTotals();
    });
  }

  // --- NEW: Method to update item price from text field ---
  void _updateItemPrice(int index, double newPrice) {
    if (newPrice < 0) return;
    setState(() {
      _quoteItems[index].unitPrice = newPrice;
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
      _quoteItems.clear();
      _itemPriceControllers.forEach((_, c) => c.dispose());
      _itemPriceControllers.clear();

      for (var product in productProvider.products) {
        for (var variant in product.variants) {
          final newItem = _QuoteItem(
            parentProduct: product, 
            variant: variant, 
            quantity: 1,
            unitPrice: variant.sellingPrice,
          );
          _quoteItems.add(newItem);
          _itemPriceControllers[newItem.variant.id.toString()] = TextEditingController(text: newItem.unitPrice.toStringAsFixed(2));
        }
      }
    });
    _calculateTotals();
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
    } else if (selectedProduct.variants.isNotEmpty){
      selectedVariant = selectedProduct.variants.first;
    }

    if (selectedVariant == null || !mounted) return;

    _promptForQuantityAndPrice(selectedProduct, selectedVariant);
  }

  // --- NEW: Method to prompt for both quantity and price ---
  Future<void> _promptForQuantityAndPrice(Product parentProduct, ProductVariant variant) async {
    final qtyController = TextEditingController(text: '1');
    final priceController = TextEditingController(text: variant.sellingPrice.toStringAsFixed(2));
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<Map<String, double>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('أدخل الكمية والسعر لـ ${parentProduct.name} (${variant.displayName})', textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo')),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                style: const TextStyle(fontFamily: 'Cairo'),
                decoration: const InputDecoration(labelText: 'الكمية*', labelStyle: TextStyle(fontFamily: 'Cairo')),
                autofocus: true,
                validator: (v) => (v == null || v.isEmpty || (int.tryParse(v) ?? 0) <= 0) ? 'كمية غير صالحة' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                style: const TextStyle(fontFamily: 'Cairo'),
                decoration: const InputDecoration(labelText: 'سعر الوحدة*', labelStyle: TextStyle(fontFamily: 'Cairo'), suffixText: 'ج.م'),
                validator: (v) => (v == null || v.isEmpty || (double.tryParse(v) ?? -1) < 0) ? 'سعر غير صالح' : null,
              ),
            ],
          ),
        ),
        actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo'))),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop({
                    'quantity': double.parse(qtyController.text),
                    'price': double.parse(priceController.text),
                  });
                }
              },
              child: const Text("موافق", style: TextStyle(fontFamily: 'Cairo')),
            ),
        ],
      ),
    );

    if (result != null) {
      _addItemToQuote(_QuoteItem(
        parentProduct: parentProduct, 
        variant: variant, 
        quantity: result['quantity']!.toInt(),
        unitPrice: result['price']!,
      ));
    }
  }

  Future<void> _generateAndShareQuote() async {
    _updateItemsFromControllers();
    if (_quoteItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إضافة صنف واحد على الأقل.', textAlign: TextAlign.right)));
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    
    setState(() { _isGenerating = true; });

    final quoteData = Invoice(
      invoiceNumber: 'عرض سعر',
      date: _selectedDate,
      clientName: _clientNameController.text.trim(),
      items: _quoteItems.map((item) => db_invoice_item.InvoiceItem(
        productId: item.variant.id!,
        productName: item.displayName,
        category: item.parentProduct.category,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        purchasePrice: item.variant.purchasePrice,
        itemTotal: item.itemTotal,
        invoiceId: 0,
      )).toList(),
      subtotal: _subtotal,
      taxRatePercentage: double.tryParse(_taxRateController.text) ?? 0.0,
      taxAmount: _taxAmount,
      discountAmount: double.tryParse(_discountController.text) ?? 0.0,
      grandTotal: _grandTotal,
      type: InvoiceType.sale,
      notes: _notesController.text.trim(),
      paymentStatus: PaymentStatus.unpaid,
      amountPaid: 0,
      lastUpdated: DateTime.now(),
    );

    final pdfService = PdfInvoiceService();
    await pdfService.sharePriceQuote(quoteData, context);

    if (mounted) {
      setState(() { _isGenerating = false; });
    }
  }

  // Helper to sync controller values back to the data model before saving
  void _updateItemsFromControllers() {
    for(var item in _quoteItems) {
      final priceText = _itemPriceControllers[item.variant.id.toString()]?.text;
      if (priceText != null) {
        item.unitPrice = double.tryParse(priceText) ?? item.unitPrice;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء عرض سعر', style: TextStyle(fontFamily: 'Cairo')),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: _isGenerating
                ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0)))
                : IconButton(
                    icon: const Icon(Icons.share_outlined),
                    tooltip: 'إنشاء PDF ومشاركة',
                    onPressed: _generateAndShareQuote,
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Text('تفاصيل عرض السعر', style: theme.textTheme.titleLarge?.copyWith(color: theme.primaryColor, fontFamily: 'Cairo'), textAlign: TextAlign.right),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _selectDate(context),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'تاريخ عرض السعر', labelStyle: TextStyle(fontFamily: 'Cairo')),
                child: Text(_arabicDateFormat.format(_selectedDate), textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo')),
              ),
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
            _buildQuoteItemsList(),
            const SizedBox(height: 20),
            Text('ملخص الأسعار', style: theme.textTheme.titleLarge?.copyWith(color: theme.primaryColor, fontFamily: 'Cairo'), textAlign: TextAlign.right),
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
              _isGenerating 
                  ? const Center(child: CircularProgressIndicator()) 
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _generateAndShareQuote,
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: theme.primaryColor),
                        child: const Text('إنشاء PDF ومشاركة', style: TextStyle(fontSize: 18, fontFamily: 'Cairo', color: Colors.white)),
                      ),
                    ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuoteItemsList() {
    final theme = Theme.of(context);
    if (_quoteItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Center(child: Text('لم تتم إضافة أصناف بعد.', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo', color: theme.textTheme.bodyMedium?.color ?? Colors.grey))),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _quoteItems.length,
      itemBuilder: (ctx, index) {
        final item = _quoteItems[index];
        final priceController = _itemPriceControllers[item.variant.id.toString()]!;
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(item.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'), textAlign: TextAlign.right)),
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
                        textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo'),
                        decoration: InputDecoration(labelText: 'الكمية', isDense: true, labelStyle: TextStyle(fontFamily: 'Cairo')),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          final newQty = int.tryParse(value);
                          if (newQty != null) {
                            _updateItemQuantity(index, newQty);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: priceController,
                        textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo'),
                        decoration: InputDecoration(labelText: 'سعر الوحدة', isDense: true, suffixText: 'ج.م', labelStyle: TextStyle(fontFamily: 'Cairo')),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (value) {
                          final newPrice = double.tryParse(value);
                          if (newPrice != null) {
                            _updateItemPrice(index, newPrice);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                 const SizedBox(height: 8),
                  Align(
                  alignment: Alignment.centerLeft,
                  child: Text('الإجمالي: ${NumberFormat.currency(locale: 'ar', symbol: 'ج.م', decimalDigits: 2).format(item.itemTotal)}', textAlign: TextAlign.left, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'))),
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
        ?? TextStyle(fontFamily: 'Cairo', fontWeight: isGrandTotal ? FontWeight.bold : FontWeight.normal, fontSize: isGrandTotal ? 16 : 14);

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

// --- HELPER WIDGETS ---

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
                        subtitle: Text('الصنف: ${product.category}', textAlign: TextAlign.right),
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
              subtitle: Text('السعر: ${variant.sellingPrice.toStringAsFixed(2)}', textAlign: TextAlign.right),
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

  const _QuantityAndPricePickerDialog({
    required this.productName,
    required this.variantName,
    required this.qtyController,
    required this.priceController,
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
              decoration: const InputDecoration(labelText: 'الكمية*'),
              autofocus: true,
              validator: (value) {
                if (value == null || value.isEmpty) return 'الكمية مطلوبة';
                final qty = int.tryParse(value);
                if (qty == null || qty <= 0) return 'كمية غير صالحة';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              decoration: const InputDecoration(labelText: 'سعر الوحدة*', suffixText: 'ج.م'),
              validator: (v) => (v == null || v.isEmpty || (double.tryParse(v) ?? -1) < 0) ? 'سعر غير صالح' : null,
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
                'quantity': double.parse(qtyController.text),
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




// // lib/screens/price_quote_screen.dart
// import 'package:flutter/material.dart';
// import 'package:fouad_stock/model/invoice_model.dart';
// import 'package:fouad_stock/model/product_model.dart';
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
// import '../providers/product_provider.dart';
// import '../services/pdf_invoice_service.dart';
// import 'package:fouad_stock/model/invoice_item_model.dart' as db_invoice_item;

// // Helper class to manage items in the UI before generating the quote
// class _QuoteItem {
//   final Product product;
//   int quantity;

//   _QuoteItem({required this.product, this.quantity = 1});

//   double get unitPrice => product.sellingPrice;
//   double get itemTotal => quantity * unitPrice;
// }

// class PriceQuoteScreen extends StatefulWidget {
//   const PriceQuoteScreen({super.key});

//   @override
//   State<PriceQuoteScreen> createState() => _PriceQuoteScreenState();
// }

// class _PriceQuoteScreenState extends State<PriceQuoteScreen> {
//   final _formKey = GlobalKey<FormState>();
//   late DateFormat _arabicDateFormat;

//   DateTime _selectedDate = DateTime.now();
//   final _clientNameController = TextEditingController();
//   final _taxRateController = TextEditingController(text: '0');
//   final _discountController = TextEditingController(text: '0');
//   final _notesController = TextEditingController();

//   final List<_QuoteItem> _quoteItems = [];

//   double _subtotal = 0.0;
//   double _taxAmount = 0.0;
//   double _grandTotal = 0.0;
//   bool _isGenerating = false;

//   @override
//   void initState() {
//     super.initState();
//     _arabicDateFormat = DateFormat.yMMMd('ar');
//     _taxRateController.addListener(_calculateTotals);
//     _discountController.addListener(_calculateTotals);
//     // Ensure product list is available for selection
//     Future.microtask(() => Provider.of<ProductProvider>(context, listen: false).fetchProducts());
//   }

//   @override
//   void dispose() {
//     _clientNameController.dispose();
//     _taxRateController.dispose();
//     _discountController.dispose();
//     _notesController.dispose();
//     super.dispose();
//   }

//   void _calculateTotals() {
//     double currentSubtotal = _quoteItems.fold(0.0, (sum, item) => sum + item.itemTotal);
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
//       setState(() { _selectedDate = picked; });
//     }
//   }

//   void _addItemToQuote(_QuoteItem newItem) {
//     int existingIndex = _quoteItems.indexWhere((item) => item.product.id == newItem.product.id);
    
//     if (existingIndex != -1) {
//       setState(() { _quoteItems[existingIndex].quantity += newItem.quantity; });
//     } else {
//       setState(() { _quoteItems.add(newItem); });
//     }
//     _calculateTotals();
//   }

//   void _removeItem(int index) {
//     setState(() {
//       _quoteItems.removeAt(index);
//       _calculateTotals();
//     });
//   }

//   void _updateItemQuantity(int index, int newQuantity) {
//     if (newQuantity <= 0) {
//       _removeItem(index);
//       return;
//     }
//     setState(() {
//       _quoteItems[index].quantity = newQuantity;
//       _calculateTotals();
//     });
//   }
  
//   void _addAllProducts() async {
//     final confirmed = await showDialog<bool>(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: const Text('تأكيد', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
//         content: const Text('هل تريد حقًا إضافة جميع المنتجات؟ سيتم حذف أي أصناف مضافة حاليًا.', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
//         actions: [
//           TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء')),
//           TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('موافق', style: TextStyle(color: Colors.teal))),
//         ],
//       ),
//     );

//     if (confirmed != true) return;

//     final productProvider = Provider.of<ProductProvider>(context, listen: false);
//     if (productProvider.products.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد منتجات لإضافتها.', textAlign: TextAlign.right)));
//       return;
//     }

//     setState(() {
//       _quoteItems.clear();
//       for (var product in productProvider.products) {
//         if (product.quantity > 0) {
//           _quoteItems.add(_QuoteItem(product: product, quantity: 1));
//         }
//       }
//     });
//     _calculateTotals();
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
//               title: const Text('اختر منتجاً', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
//               contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
//               content: SizedBox(
//                 width: double.maxFinite,
//                 height: MediaQuery.of(context).size.height * 0.6,
//                 child: Column(
//                   children: [
//                     TextField(
//                       controller: searchController,
//                       onChanged: (value) => setDialogState(() => searchQuery = value),
//                       textAlign: TextAlign.right,
//                       decoration: InputDecoration(
//                         labelText: 'ابحث بالاسم أو الكود',
//                         prefixIcon: const Icon(Icons.search),
//                         suffixIcon: searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setDialogState(() { searchController.clear(); searchQuery = ''; })) : null,
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
//                                 subtitle: Text('السعر: ${product.sellingPrice.toStringAsFixed(2)} ج.م', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontFamily: 'Cairo')),
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
//       _promptForQuantity(selectedProduct);
//     }
//   }

//   Future<void> _promptForQuantity(Product product) async {
//     final qtyController = TextEditingController(text: '1');
//     final result = await showDialog<int>(
//       context: context,
//       builder: (BuildContext ctx) {
//         final formKeyDialog = GlobalKey<FormState>();
//         return AlertDialog(
//           title: Text('أدخل الكمية لـ ${product.name}', textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo')),
//           content: Form(
//             key: formKeyDialog,
//             child: TextFormField(
//               controller: qtyController,
//               keyboardType: TextInputType.number,
//               textAlign: TextAlign.right,
//               style: const TextStyle(fontFamily: 'Cairo'),
//               decoration: const InputDecoration(labelText: 'الكمية*', labelStyle: TextStyle(fontFamily: 'Cairo')),
//               autofocus: true,
//               validator: (value) {
//                 if (value == null || value.isEmpty) return 'الكمية مطلوبة';
//                 final qty = int.tryParse(value);
//                 if (qty == null || qty <= 0) return 'كمية غير صالحة';
//                 return null;
//               },
//             ),
//           ),
//           actions: [
//             TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo'))),
//             ElevatedButton(
//               onPressed: () {
//                 if (formKeyDialog.currentState!.validate()) {
//                   Navigator.of(ctx).pop(int.parse(qtyController.text));
//                 }
//               },
//               child: const Text("موافق", style: TextStyle(fontFamily: 'Cairo')),
//             ),
//           ],
//         );
//       },
//     );

//     if (result != null && result > 0) {
//       _addItemToQuote(_QuoteItem(product: product, quantity: result));
//     }
//   }

//   Future<void> _generateAndShareQuote() async {
//     if (_quoteItems.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إضافة صنف واحد على الأقل.', textAlign: TextAlign.right)));
//       return;
//     }
//     if (!_formKey.currentState!.validate()) return;
    
//     setState(() { _isGenerating = true; });

//     final quoteData = Invoice(
//       invoiceNumber: 'عرض سعر',
//       date: _selectedDate,
//       clientName: _clientNameController.text.trim(),
//       items: _quoteItems.map((item) => db_invoice_item.InvoiceItem(
//         productId: item.product.id!,
//         productName: item.product.name,
//         quantity: item.quantity,
//         unitPrice: item.unitPrice,
//         itemTotal: item.itemTotal,
//         invoiceId: 0, purchasePrice: item.product.purchasePrice,
//       )).toList(),
//       subtotal: _subtotal,
//       taxRatePercentage: double.tryParse(_taxRateController.text) ?? 0.0,
//       taxAmount: _taxAmount,
//       discountAmount: double.tryParse(_discountController.text) ?? 0.0,
//       grandTotal: _grandTotal,
//       type: InvoiceType.sale,
//       notes: _notesController.text.trim(),
//       paymentStatus: PaymentStatus.unpaid,
//       amountPaid: 0,
//       lastUpdated: DateTime.now(),
//     );

//     final pdfService = PdfInvoiceService();
//     await pdfService.sharePriceQuote(quoteData, context);

//     if (mounted) {
//       setState(() { _isGenerating = false; });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('إنشاء عرض سعر', style: TextStyle(fontFamily: 'Cairo')),
//         actions: [
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 12.0),
//             child: _isGenerating
//                 ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0)))
//                 : IconButton(
//                     icon: const Icon(Icons.share_outlined),
//                     tooltip: 'إنشاء PDF ومشاركة',
//                     onPressed: _generateAndShareQuote,
//                   ),
//           ),
//         ],
//       ),
//       body: Form(
//         key: _formKey,
//         child: ListView(
//           padding: const EdgeInsets.all(16.0),
//           children: [
//             Text('تفاصيل عرض السعر', style: theme.textTheme.titleLarge?.copyWith(color: theme.primaryColor, fontFamily: 'Cairo'), textAlign: TextAlign.right),
//             const SizedBox(height: 12),
//             InkWell(
//               onTap: () => _selectDate(context),
//               child: InputDecorator(
//                 decoration: const InputDecoration(labelText: 'تاريخ عرض السعر', labelStyle: TextStyle(fontFamily: 'Cairo')),
//                 child: Text(_arabicDateFormat.format(_selectedDate), textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo')),
//               ),
//             ),
//             const SizedBox(height: 12),
//             TextFormField(
//               controller: _clientNameController,
//               textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo'),
//               decoration: const InputDecoration(labelText: 'اسم العميل (اختياري)', labelStyle: TextStyle(fontFamily: 'Cairo')),
//             ),
//             const SizedBox(height: 20),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text('الأصناف', style: theme.textTheme.titleLarge?.copyWith(color: theme.primaryColor, fontFamily: 'Cairo'), textAlign: TextAlign.right),
//                 Row(
//                   children: [
//                     TextButton.icon(
//                       icon: const Icon(Icons.playlist_add_check, size: 20),
//                       label: const Text('إضافة الكل', style: TextStyle(fontFamily: 'Cairo')),
//                       onPressed: _addAllProducts,
//                       style: TextButton.styleFrom(
//                         foregroundColor: theme.colorScheme.secondary,
//                       ),
//                     ),
//                     const SizedBox(width: 8),
//                     ElevatedButton.icon(
//                       icon: const Icon(Icons.add_shopping_cart),
//                       label: const Text('إضافة صنف', style: TextStyle(fontFamily: 'Cairo')),
//                       onPressed: _showProductSelectionDialog,
//                       style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.secondary),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//             const SizedBox(height: 8),
//             _buildQuoteItemsList(),
//             const SizedBox(height: 20),
//             Text('ملخص الأسعار', style: theme.textTheme.titleLarge?.copyWith(color: theme.primaryColor, fontFamily: 'Cairo'), textAlign: TextAlign.right),
//             const SizedBox(height: 12),
//             _buildSummaryRow('المجموع الفرعي:', '${_subtotal.toStringAsFixed(2)} ج.م'),
//             Row(
//                 children: [
//                     Expanded(flex: 2, child: TextFormField(controller: _taxRateController, textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo'), decoration: const InputDecoration(labelText: 'نسبة الضريبة (%)', suffixText: '%', labelStyle: TextStyle(fontFamily: 'Cairo')), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v){ if(v!=null && v.isNotEmpty && (double.tryParse(v)==null || double.parse(v) < 0)) return 'نسبة غير صالحة'; return null;},)),
//                     const SizedBox(width: 16),
//                     Expanded(flex: 3, child: _buildSummaryRow('مبلغ الضريبة:', '${_taxAmount.toStringAsFixed(2)} ج.م')),
//                 ]
//             ),
//             TextFormField(controller: _discountController, textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo'), decoration: const InputDecoration(labelText: 'مبلغ الخصم (ج.م)', suffixText: 'ج.م', labelStyle: TextStyle(fontFamily: 'Cairo')), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v){ if(v!=null && v.isNotEmpty && (double.tryParse(v)==null || double.parse(v) < 0)) return 'مبلغ غير صالح'; if(v!=null && v.isNotEmpty && (_subtotal + _taxAmount > 0) && (double.tryParse(v)! > _subtotal + _taxAmount)) return 'الخصم أكبر'; return null;},),
//             const Divider(height: 20, thickness: 1),
//             _buildSummaryRow('الإجمالي الكلي:', '${_grandTotal.toStringAsFixed(2)} ج.م', isGrandTotal: true),
//             const SizedBox(height: 20),
//             TextFormField(controller: _notesController, textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo'), decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)', border: OutlineInputBorder(), labelStyle: TextStyle(fontFamily: 'Cairo')), maxLines: 3,),
//             const SizedBox(height: 30),
//               _isGenerating 
//                   ? const Center(child: CircularProgressIndicator()) 
//                   : SizedBox(
//                       width: double.infinity,
//                       child: ElevatedButton(
//                         onPressed: _generateAndShareQuote,
//                         style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: theme.primaryColor),
//                         child: const Text('إنشاء PDF ومشاركة', style: TextStyle(fontSize: 18, fontFamily: 'Cairo', color: Colors.white)),
//                       ),
//                     ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildQuoteItemsList() {
//     final theme = Theme.of(context);
//     if (_quoteItems.isEmpty) {
//       return Padding(
//         padding: const EdgeInsets.symmetric(vertical: 20.0),
//         child: Center(child: Text('لم تتم إضافة أصناف بعد.', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo', color: theme.textTheme.bodyMedium?.color ?? Colors.grey))),
//       );
//     }
//     return ListView.builder(
//       shrinkWrap: true,
//       physics: const NeverScrollableScrollPhysics(),
//       itemCount: _quoteItems.length,
//       itemBuilder: (ctx, index) {
//         final item = _quoteItems[index];
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
//                     IconButton(
//                       icon: const Icon(Icons.delete_outline, color: Colors.red),
//                       onPressed: () => _removeItem(index),
//                       padding: EdgeInsets.zero,
//                       constraints: const BoxConstraints(),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 4),
//                 Row(
//                   children: [
//                     Expanded(
//                       child: TextFormField(
//                         initialValue: item.quantity.toString(),
//                         textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo'),
//                         decoration: InputDecoration(labelText: 'الكمية', isDense: true, labelStyle: TextStyle(fontFamily: 'Cairo')),
//                         keyboardType: TextInputType.number,
//                         onChanged: (value) {
//                           final newQty = int.tryParse(value);
//                           if (newQty != null) {
//                             _updateItemQuantity(index, newQty);
//                           }
//                         },
//                         validator: (value) {
//                             if (value == null || value.isEmpty) return 'مطلوب';
//                             final qty = int.tryParse(value);
//                             if (qty == null || qty <= 0) return 'غير صالح';
//                             return null;
//                         },
//                       ),
//                     ),
//                     const SizedBox(width: 10),
//                     Expanded(child: Text('سعر الوحدة: ${NumberFormat.currency(locale: 'ar', symbol: 'ج.م', decimalDigits: 2).format(item.unitPrice)}', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo'))),
//                     const SizedBox(width: 10),
//                     Expanded(child: Text('الإجمالي: ${NumberFormat.currency(locale: 'ar', symbol: 'ج.م', decimalDigits: 2).format(item.itemTotal)}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'))),
//                   ],
//                 )
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildSummaryRow(String label, String value, {bool isGrandTotal = false}) {
//     final theme = Theme.of(context);
//     TextStyle defaultStyle = (isGrandTotal 
//         ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontFamily: 'Cairo') 
//         : theme.textTheme.bodyLarge?.copyWith(fontFamily: 'Cairo')) 
//         ?? TextStyle(fontFamily: 'Cairo', fontWeight: isGrandTotal ? FontWeight.bold : FontWeight.normal, fontSize: isGrandTotal ? 16 : 14);

//     TextStyle valueStyle = (isGrandTotal 
//         ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.primaryColor, fontFamily: 'Cairo') 
//         : theme.textTheme.bodyLarge?.copyWith(fontFamily: 'Cairo')) 
//         ?? TextStyle(fontFamily: 'Cairo', fontWeight: isGrandTotal ? FontWeight.bold : FontWeight.normal, fontSize: isGrandTotal ? 16: 14, color: isGrandTotal ? theme.primaryColor : null);

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
