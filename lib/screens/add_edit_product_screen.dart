// lib/screens/add_edit_product_screen.dart
import 'package:flutter/material.dart';
import 'package:fouad_stock/model/product_model.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';

class AddEditProductScreen extends StatefulWidget {
  final Product? product;

  const AddEditProductScreen({super.key, this.product});

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _productCodeController;
  late TextEditingController _descriptionController;
  late TextEditingController _purchasePriceController;
  late TextEditingController _sellingPriceController;
  late TextEditingController _quantityController;
  late TextEditingController _unitOfMeasureController;
  late TextEditingController _lowStockThresholdController;
  late TextEditingController _expiryDateController;
  late TextEditingController _categoryController;

  DateTime? _expiryDate;
  late DateFormat _arabicDateFormat;

  @override
  void initState() {
    super.initState();
    _arabicDateFormat = DateFormat.yMMMd('ar');

    if (widget.product != null) {
      _nameController = TextEditingController(text: widget.product!.name);
      _productCodeController = TextEditingController(text: widget.product!.productCode);
      _descriptionController = TextEditingController(text: widget.product!.description);
      _purchasePriceController = TextEditingController(text: widget.product!.purchasePrice.toString());
      _sellingPriceController = TextEditingController(text: widget.product!.sellingPrice.toString());
      _quantityController = TextEditingController(text: widget.product!.quantity.toString());
      _unitOfMeasureController = TextEditingController(text: widget.product!.unitOfMeasure);
      _lowStockThresholdController = TextEditingController(text: widget.product!.lowStockThreshold?.toString() ?? '10');
      _categoryController = TextEditingController(text: widget.product!.category);
      
      // Check if the date is a real date and not our placeholder
      if (widget.product!.expiryDate.year < 9000) {
        _expiryDate = widget.product!.expiryDate;
        _expiryDateController = TextEditingController(text: _arabicDateFormat.format(_expiryDate!));
      } else {
        _expiryDate = null;
        _expiryDateController = TextEditingController();
      }
    } else {
      _nameController = TextEditingController();
      _productCodeController = TextEditingController();
      _descriptionController = TextEditingController();
      _purchasePriceController = TextEditingController();
      _sellingPriceController = TextEditingController();
      _quantityController = TextEditingController();
      _unitOfMeasureController = TextEditingController(text: 'قطعة');
      _lowStockThresholdController = TextEditingController(text: '10');
      _expiryDateController = TextEditingController();
      _categoryController = TextEditingController();
      _expiryDate = null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _productCodeController.dispose();
    _descriptionController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _quantityController.dispose();
    _unitOfMeasureController.dispose();
    _lowStockThresholdController.dispose();
    _expiryDateController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _selectExpiryDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      locale: const Locale('ar', ''),
    );
    if (picked != null) {
      setState(() {
        _expiryDate = picked;
        _expiryDateController.text = _arabicDateFormat.format(_expiryDate!);
      });
    }
  }

  void _saveForm() async {
    if (_formKey.currentState!.validate()) {
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      
      final newProduct = Product(
        id: widget.product?.id,
        name: _nameController.text.trim(),
        productCode: _productCodeController.text.trim(),
        category: _categoryController.text.trim(),
        description: _descriptionController.text.trim(),
        purchasePrice: double.tryParse(_purchasePriceController.text) ?? 0.0,
        sellingPrice: double.tryParse(_sellingPriceController.text) ?? 0.0,
        quantity: int.tryParse(_quantityController.text) ?? 0,
        unitOfMeasure: _unitOfMeasureController.text.trim(),
        expiryDate: _expiryDate ?? DateTime(9999), // Save a far-future date if null
        lowStockThreshold: int.tryParse(_lowStockThresholdController.text),
      );

      try {
        if (widget.product == null) {
          await productProvider.addProduct(newProduct);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تمت إضافة المنتج بنجاح!', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green),
          );
        } else {
          await productProvider.updateProduct(newProduct);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تحديث المنتج بنجاح!', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green),
          );
        }
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل حفظ المنتج: $error', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red)
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'إضافة منتج جديد' : 'تعديل المنتج'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveForm,
            tooltip: 'حفظ',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'اسم المنتج*'),
                textInputAction: TextInputAction.next,
                textAlign: TextAlign.right,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'الرجاء إدخال اسم المنتج.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _productCodeController,
                decoration: const InputDecoration(labelText: 'كود المنتج/SKU (اختياري)'),
                textInputAction: TextInputAction.next,
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 12),
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _categoryController.text),
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text == '') {
                    return const Iterable<String>.empty();
                  }
                  return productProvider.categories.where((String option) {
                    return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                  });
                },
                onSelected: (String selection) {
                  _categoryController.text = selection;
                },
                fieldViewBuilder: (BuildContext context, TextEditingController fieldController, FocusNode fieldFocusNode, VoidCallback onFieldSubmitted) {
                    // This listener ensures our state controller is always in sync with the field controller
                    fieldController.addListener(() {
                      _categoryController.text = fieldController.text;
                    });
                    return TextFormField(
                      controller: fieldController,
                      focusNode: fieldFocusNode,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(labelText: 'الصنف*'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'الرجاء إدخال أو اختيار صنف.';
                        }
                        return null;
                      },
                    );
                },
                optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<String> onSelected, Iterable<String> options) {
                  return Align(
                    alignment: Alignment.topRight,
                    child: Material(
                      elevation: 4.0,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (BuildContext context, int index) {
                            final String option = options.elementAt(index);
                            return InkWell(
                              onTap: () {
                                onSelected(option);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(option, textAlign: TextAlign.right),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'الوصف (اختياري)'),
                maxLines: 2,
                textInputAction: TextInputAction.next,
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _purchasePriceController,
                decoration: const InputDecoration(labelText: 'سعر الشراء*'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                textAlign: TextAlign.right,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'الرجاء إدخال سعر الشراء.';
                  if (double.tryParse(value) == null) return 'الرجاء إدخال رقم صحيح.';
                  if (double.parse(value) < 0) return 'السعر لا يمكن أن يكون سالباً.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sellingPriceController,
                decoration: const InputDecoration(labelText: 'سعر البيع*'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                textAlign: TextAlign.right,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'الرجاء إدخال سعر البيع.';
                  if (double.tryParse(value) == null) return 'الرجاء إدخال رقم صحيح.';
                  if (double.parse(value) < 0) return 'السعر لا يمكن أن يكون سالباً.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(labelText: 'الكمية*'),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                textAlign: TextAlign.right,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'الرجاء إدخال الكمية.';
                  if (int.tryParse(value) == null) return 'الرجاء إدخال عدد صحيح.';
                  if (int.parse(value) < 0) return 'الكمية لا يمكن أن تكون سالبة.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _unitOfMeasureController,
                decoration: const InputDecoration(labelText: 'وحدة القياس* (مثال: قطعة, علبة)'),
                textInputAction: TextInputAction.next,
                textAlign: TextAlign.right,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'الرجاء إدخال وحدة القياس.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _expiryDateController,
                decoration: InputDecoration(
                  labelText: 'تاريخ الانتهاء (اختياري)',
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.clear, size: 20, color: Colors.grey),
                        onPressed: () {
                          setState(() {
                            _expiryDate = null;
                            _expiryDateController.clear();
                          });
                        },
                      ),
                      const Icon(Icons.calendar_today),
                    ],
                  )
                ),
                readOnly: true,
                textAlign: TextAlign.right,
                onTap: () => _selectExpiryDate(context),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lowStockThresholdController,
                decoration: const InputDecoration(labelText: 'حد التنبيه للكمية المنخفضة (اختياري)'),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                textAlign: TextAlign.right,
                validator: (value) {
                  if (value != null && value.isNotEmpty && int.tryParse(value) == null) {
                    return 'الرجاء إدخال رقم صحيح أو اتركه فارغاً.';
                  }
                  if (value != null && value.isNotEmpty && int.parse(value) < 0) {
                    return 'الحد لا يمكن أن يكون سالباً.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveForm,
                child: Text(widget.product == null ? 'إضافة المنتج' : 'حفظ التعديلات'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
