// lib/screens/add_edit_product_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fouad_stock/model/product_model.dart';
import 'package:fouad_stock/model/product_variant_model.dart';
import 'package:fouad_stock/providers/product_provider.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

// Helper class to manage option controllers in the UI
class _OptionController {
  final TextEditingController nameController;
  final TextEditingController valuesController;
  _OptionController({String name = '', String values = ''})
      : nameController = TextEditingController(text: name),
        valuesController = TextEditingController(text: values);

  void dispose() {
    nameController.dispose();
    valuesController.dispose();
  }
}

class AddEditProductScreen extends StatefulWidget {
  final Product? product;

  const AddEditProductScreen({super.key, this.product});

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for parent product details
  late TextEditingController _nameController;
  late TextEditingController _categoryController;
  late TextEditingController _unitOfMeasureController;
  
  // State for managing variants
  final List<_OptionController> _optionControllers = [];
  List<ProductVariant> _variants = [];
  // --- FIX: Use index as key for stability ---
  final Map<int, TextEditingController> _variantQtyControllers = {};
  final Map<int, TextEditingController> _variantSellingPriceControllers = {};
  final Map<int, TextEditingController> _variantPurchasePriceControllers = {};
  final Map<int, TextEditingController> _variantSkuControllers = {};
 
  bool _isSaving = false;
  
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _categoryController = TextEditingController(text: widget.product?.category ?? '');
    _unitOfMeasureController = TextEditingController(text: widget.product?.unitOfMeasure ?? 'قطعة');

    if (widget.product != null) {
      _variants = List<ProductVariant>.from(widget.product!.variants.map((v) => v.copyWith()));
      
      if (widget.product!.hasVariants) {
        Map<String, Set<String>> optionsMap = {};
        for (var variant in _variants) {
          variant.attributes.forEach((key, value) {
            optionsMap.putIfAbsent(key, () => {}).add(value);
          });
        }
        optionsMap.forEach((name, values) {
          _optionControllers.add(_OptionController(
            name: name,
            values: values.join(', '),
          ));
        });
      }

    } else {
      _variants.add(ProductVariant(
          productId: 0,
          attributes: {},
          purchasePrice: 0,
          sellingPrice: 0,
          quantity: 0,
      ));
    }

    _initializeVariantControllers();
  }
  
  void _initializeVariantControllers() {
     _disposeVariantControllers();
     for (int i = 0; i < _variants.length; i++) {
      var variant = _variants[i];
      _variantQtyControllers[i] = TextEditingController(text: variant.quantity.toString());
      _variantSellingPriceControllers[i] = TextEditingController(text: variant.sellingPrice.toStringAsFixed(2));
      _variantPurchasePriceControllers[i] = TextEditingController(text: variant.purchasePrice.toStringAsFixed(2));
      _variantSkuControllers[i] = TextEditingController(text: variant.sku ?? '');
    }
  }
  
  void _disposeVariantControllers() {
    _variantQtyControllers.values.forEach((c) => c.dispose());
    _variantSellingPriceControllers.values.forEach((c) => c.dispose());
    _variantPurchasePriceControllers.values.forEach((c) => c.dispose());
    _variantSkuControllers.values.forEach((c) => c.dispose());
    _variantQtyControllers.clear();
    _variantSellingPriceControllers.clear();
    _variantPurchasePriceControllers.clear();
    _variantSkuControllers.clear();
  }


  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _unitOfMeasureController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    _disposeVariantControllers();
    super.dispose();
  }

  void _addOption() {
    setState(() {
      if(_optionControllers.isEmpty && _variants.length == 1 && !_variants.first.hasAttributes) {
        _variants = []; 
      }
      _optionControllers.add(_OptionController());
      _generateVariants();
    });
  }

  void _removeOption(int index) {
    setState(() {
      _optionControllers[index].dispose();
      _optionControllers.removeAt(index);
      _generateVariants();
    });
  }

  void _updateVariantsFromControllers() {
    for (int i = 0; i < _variants.length; i++) {
      _variants[i].quantity = int.tryParse(_variantQtyControllers[i]?.text ?? '0') ?? 0;
      _variants[i].sellingPrice = double.tryParse(_variantSellingPriceControllers[i]?.text ?? '0.0') ?? 0.0;
      _variants[i].purchasePrice = double.tryParse(_variantPurchasePriceControllers[i]?.text ?? '0.0') ?? 0.0;
      _variants[i].sku = _variantSkuControllers[i]?.text.trim();
    }
  }

  void _generateVariants() {
    _updateVariantsFromControllers();

    if (_optionControllers.every((c) => c.nameController.text.trim().isEmpty || c.valuesController.text.trim().isEmpty)) {
      setState(() {
         if(_variants.isEmpty){
            _variants.add(ProductVariant(productId: widget.product?.id ?? 0, attributes: {}, purchasePrice: 0, sellingPrice: 0, quantity: 0));
         } else {
            final firstVariant = _variants.first;
            _variants = [firstVariant.copyWith(attributes: {})];
         }
      });
      _initializeVariantControllers();
      return;
    }

    List<Map<String, String>> allCombinations = [{}];
    for (var optionController in _optionControllers) {
      String optionName = optionController.nameController.text.trim();
      List<String> values = optionController.valuesController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      
      if (optionName.isEmpty || values.isEmpty) continue;

      List<Map<String, String>> newCombinations = [];
      for (var combination in allCombinations) {
        for (var value in values) {
          Map<String, String> newCombination = Map.from(combination);
          newCombination[optionName] = value;
          newCombinations.add(newCombination);
        }
      }
      allCombinations = newCombinations;
    }
    
    setState(() {
      final oldVariants = List<ProductVariant>.from(_variants);
      
      _variants = allCombinations.map((attributes) {
          final existing = oldVariants.firstWhere(
             (v) => mapEquals(v.attributes, attributes),
             orElse: () => ProductVariant(
                  productId: widget.product?.id ?? 0, 
                  attributes: attributes,
                  purchasePrice: 0, sellingPrice: 0, quantity: 0
             ),
          );
          return existing.copyWith(attributes: attributes);
      }).toList();
      _initializeVariantControllers();
    });
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    _updateVariantsFromControllers();

    if (_variants.isEmpty) {
       _variants.add(ProductVariant(productId: 0, attributes: {}, purchasePrice: 0, sellingPrice: 0, quantity: 0));
    }

    setState(() { _isSaving = true; });

    final productProvider = Provider.of<ProductProvider>(context, listen: false);

    final parentProduct = Product(
      id: widget.product?.id,
      name: _nameController.text.trim(),
      category: _categoryController.text.trim(),
      unitOfMeasure: _unitOfMeasureController.text.trim(),
      addedDate: widget.product?.addedDate ?? DateTime.now(),
      lastUpdated: DateTime.now(),
      variants: _variants,
    );
    
    try {
      if (widget.product == null) {
        await productProvider.addProduct(parentProduct);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة المنتج بنجاح!'), backgroundColor: Colors.green));
      } else {
        await productProvider.updateProduct(parentProduct);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث المنتج بنجاح!'), backgroundColor: Colors.green));
      }
      if(mounted) Navigator.of(context).pop();
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل حفظ المنتج: $e'), backgroundColor: Colors.red));
    } finally {
      if(mounted) setState(() { _isSaving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'إضافة منتج جديد' : 'تعديل منتج'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveForm,
            tooltip: 'حفظ',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildSectionTitle('المعلومات الأساسية'),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'اسم المنتج*'),
              textAlign: TextAlign.right,
              validator: (value) => (value == null || value.trim().isEmpty) ? 'الاسم مطلوب' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _categoryController,
              decoration: const InputDecoration(labelText: 'الصنف*'),
              textAlign: TextAlign.right,
              validator: (value) => (value == null || value.trim().isEmpty) ? 'الصنف مطلوب' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _unitOfMeasureController,
              decoration: const InputDecoration(labelText: 'وحدة القياس*'),
              textAlign: TextAlign.right,
              validator: (value) => (value == null || value.trim().isEmpty) ? 'الوحدة مطلوبة' : null,
            ),
            
            const Divider(height: 40),
            
            _buildSectionTitle('الخيارات والمتغيرات'),
            ..._buildOptionFields(),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('إضافة خيار (مثل اللون أو المقاس)'),
              onPressed: _addOption,
            ),
            
            const SizedBox(height: 24),
            
            _buildVariantsTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).primaryColor)),
    );
  }

  List<Widget> _buildOptionFields() {
    return List.generate(_optionControllers.length, (index) {
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _optionControllers[index].nameController,
                      decoration: const InputDecoration(labelText: 'اسم الخيار', hintText: 'مثال: اللون'),
                      textAlign: TextAlign.right,
                      onChanged: (_) => _generateVariants(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _removeOption(index),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _optionControllers[index].valuesController,
                decoration: const InputDecoration(labelText: 'قيم الخيار (افصل بينها بفاصلة)', hintText: 'مثال: أحمر, أزرق, أخضر'),
                textAlign: TextAlign.right,
                onChanged: (_) => _generateVariants(),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildVariantsTable() {
    bool hasOptions = _optionControllers.any((c) => c.nameController.text.isNotEmpty && c.valuesController.text.isNotEmpty);
    
    if (_variants.isEmpty && !hasOptions) {
      return _buildSimpleProductFields();
    }
    
    if (_variants.isEmpty && hasOptions) {
      return const Center(child: Text('لا توجد متغيرات. قم بإضافة قيم للخيارات.'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasOptions) _buildSectionTitle('قائمة المتغيرات'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              if (hasOptions) const DataColumn(label: Text('المتغير')),
              const DataColumn(label: Text('سعر الشراء*')),
              const DataColumn(label: Text('سعر البيع*')),
              const DataColumn(label: Text('الكمية*')),
              const DataColumn(label: Text('SKU')),
            ],
            rows: List.generate(_variants.length, (index) {
              return DataRow(cells: [
                if (hasOptions) DataCell(Text(_variants[index].displayName)),
                DataCell(TextFormField(controller: _variantPurchasePriceControllers[index], keyboardType: TextInputType.number, decoration: const InputDecoration(isDense: true), validator: (v) => (v == null || v.isEmpty) ? 'مطلوب' : null)),
                DataCell(TextFormField(controller: _variantSellingPriceControllers[index], keyboardType: TextInputType.number, decoration: const InputDecoration(isDense: true), validator: (v) => (v == null || v.isEmpty) ? 'مطلوب' : null)),
                DataCell(TextFormField(controller: _variantQtyControllers[index], keyboardType: TextInputType.number, decoration: const InputDecoration(isDense: true), validator: (v) => (v == null || v.isEmpty) ? 'مطلوب' : null)),
                DataCell(TextFormField(controller: _variantSkuControllers[index], decoration: const InputDecoration(isDense: true))),
              ]);
            }),
          ),
        ),
      ],
    );
  }
  
  Widget _buildSimpleProductFields(){
    if (_variants.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSectionTitle('التسعير والمخزون'),
            TextFormField(
              controller: _variantPurchasePriceControllers[0],
              decoration: const InputDecoration(labelText: 'سعر الشراء*'),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              validator: (v) => (v == null || v.isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: 12),
             TextFormField(
              controller: _variantSellingPriceControllers[0],
              decoration: const InputDecoration(labelText: 'سعر البيع*'),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              validator: (v) => (v == null || v.isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _variantQtyControllers[0],
              decoration: const InputDecoration(labelText: 'الكمية*'),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              validator: (v) => (v == null || v.isEmpty) ? 'مطلوب' : null,
            ),
             const SizedBox(height: 12),
            TextFormField(
              controller: _variantSkuControllers[0],
              decoration: const InputDecoration(labelText: 'SKU (اختياري)'),
              textAlign: TextAlign.right,
            ),
          ],
        ),
      ),
    );
  }
}













// // lib/screens/add_edit_product_screen.dart
// import 'package:flutter/material.dart';
// import 'package:fouad_stock/model/product_model.dart';
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
// import '../providers/product_provider.dart';

// class AddEditProductScreen extends StatefulWidget {
//   final Product? product;

//   const AddEditProductScreen({super.key, this.product});

//   @override
//   State<AddEditProductScreen> createState() => _AddEditProductScreenState();
// }

// class _AddEditProductScreenState extends State<AddEditProductScreen> {
//   final _formKey = GlobalKey<FormState>();
  
//   late TextEditingController _nameController;
//   late TextEditingController _productCodeController;
//   late TextEditingController _descriptionController;
//   late TextEditingController _purchasePriceController;
//   late TextEditingController _sellingPriceController;
//   late TextEditingController _quantityController;
//   late TextEditingController _unitOfMeasureController;
//   late TextEditingController _lowStockThresholdController;
//   late TextEditingController _expiryDateController;
//   late TextEditingController _categoryController;

//   DateTime? _expiryDate;
//   late DateFormat _arabicDateFormat;

//   @override
//   void initState() {
//     super.initState();
//     _arabicDateFormat = DateFormat.yMMMd('ar');

//     if (widget.product != null) {
//       _nameController = TextEditingController(text: widget.product!.name);
//       _productCodeController = TextEditingController(text: widget.product!.productCode);
//       _descriptionController = TextEditingController(text: widget.product!.description);
//       _purchasePriceController = TextEditingController(text: widget.product!.purchasePrice.toString());
//       _sellingPriceController = TextEditingController(text: widget.product!.sellingPrice.toString());
//       _quantityController = TextEditingController(text: widget.product!.quantity.toString());
//       _unitOfMeasureController = TextEditingController(text: widget.product!.unitOfMeasure);
//       _lowStockThresholdController = TextEditingController(text: widget.product!.lowStockThreshold?.toString() ?? '10');
//       _categoryController = TextEditingController(text: widget.product!.category);
      
//       // Check if the date is a real date and not our placeholder
//       if (widget.product!.expiryDate.year < 9000) {
//         _expiryDate = widget.product!.expiryDate;
//         _expiryDateController = TextEditingController(text: _arabicDateFormat.format(_expiryDate!));
//       } else {
//         _expiryDate = null;
//         _expiryDateController = TextEditingController();
//       }
//     } else {
//       _nameController = TextEditingController();
//       _productCodeController = TextEditingController();
//       _descriptionController = TextEditingController();
//       _purchasePriceController = TextEditingController();
//       _sellingPriceController = TextEditingController();
//       _quantityController = TextEditingController();
//       _unitOfMeasureController = TextEditingController(text: 'قطعة');
//       _lowStockThresholdController = TextEditingController(text: '10');
//       _expiryDateController = TextEditingController();
//       _categoryController = TextEditingController();
//       _expiryDate = null;
//     }
//   }

//   @override
//   void dispose() {
//     _nameController.dispose();
//     _productCodeController.dispose();
//     _descriptionController.dispose();
//     _purchasePriceController.dispose();
//     _sellingPriceController.dispose();
//     _quantityController.dispose();
//     _unitOfMeasureController.dispose();
//     _lowStockThresholdController.dispose();
//     _expiryDateController.dispose();
//     _categoryController.dispose();
//     super.dispose();
//   }

//   Future<void> _selectExpiryDate(BuildContext context) async {
//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 365)),
//       firstDate: DateTime(2000),
//       lastDate: DateTime(2101),
//       locale: const Locale('ar', ''),
//     );
//     if (picked != null) {
//       setState(() {
//         _expiryDate = picked;
//         _expiryDateController.text = _arabicDateFormat.format(_expiryDate!);
//       });
//     }
//   }

//   void _saveForm() async {
//     if (_formKey.currentState!.validate()) {
//       final productProvider = Provider.of<ProductProvider>(context, listen: false);
      
//       final newProduct = Product(
//         id: widget.product?.id,
//         name: _nameController.text.trim(),
//         productCode: _productCodeController.text.trim(),
//         category: _categoryController.text.trim(),
//         description: _descriptionController.text.trim(),
//         purchasePrice: double.tryParse(_purchasePriceController.text) ?? 0.0,
//         sellingPrice: double.tryParse(_sellingPriceController.text) ?? 0.0,
//         quantity: int.tryParse(_quantityController.text) ?? 0,
//         unitOfMeasure: _unitOfMeasureController.text.trim(),
//         expiryDate: _expiryDate ?? DateTime(9999), // Save a far-future date if null
//         lowStockThreshold: int.tryParse(_lowStockThresholdController.text),
//       );

//       try {
//         if (widget.product == null) {
//           await productProvider.addProduct(newProduct);
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text('تمت إضافة المنتج بنجاح!', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green),
//           );
//         } else {
//           await productProvider.updateProduct(newProduct);
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text('تم تحديث المنتج بنجاح!', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green),
//           );
//         }
//         if (mounted) {
//           Navigator.of(context).pop();
//         }
//       } catch (error) {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('فشل حفظ المنتج: $error', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red)
//           );
//         }
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final productProvider = Provider.of<ProductProvider>(context);

//     return Scaffold(
//       appBar: AppBar(
//         title: Text(widget.product == null ? 'إضافة منتج جديد' : 'تعديل المنتج'),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.save),
//             onPressed: _saveForm,
//             tooltip: 'حفظ',
//           ),
//         ],
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Form(
//           key: _formKey,
//           child: ListView(
//             children: <Widget>[
//               TextFormField(
//                 controller: _nameController,
//                 decoration: const InputDecoration(labelText: 'اسم المنتج*'),
//                 textInputAction: TextInputAction.next,
//                 textAlign: TextAlign.right,
//                 validator: (value) {
//                   if (value == null || value.trim().isEmpty) {
//                     return 'الرجاء إدخال اسم المنتج.';
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 12),
//               TextFormField(
//                 controller: _productCodeController,
//                 decoration: const InputDecoration(labelText: 'كود المنتج/SKU (اختياري)'),
//                 textInputAction: TextInputAction.next,
//                 textAlign: TextAlign.right,
//               ),
//               const SizedBox(height: 12),
//               Autocomplete<String>(
//                 initialValue: TextEditingValue(text: _categoryController.text),
//                 optionsBuilder: (TextEditingValue textEditingValue) {
//                   if (textEditingValue.text == '') {
//                     return const Iterable<String>.empty();
//                   }
//                   return productProvider.categories.where((String option) {
//                     return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
//                   });
//                 },
//                 onSelected: (String selection) {
//                   _categoryController.text = selection;
//                 },
//                 fieldViewBuilder: (BuildContext context, TextEditingController fieldController, FocusNode fieldFocusNode, VoidCallback onFieldSubmitted) {
//                     // This listener ensures our state controller is always in sync with the field controller
//                     fieldController.addListener(() {
//                       _categoryController.text = fieldController.text;
//                     });
//                     return TextFormField(
//                       controller: fieldController,
//                       focusNode: fieldFocusNode,
//                       textAlign: TextAlign.right,
//                       decoration: const InputDecoration(labelText: 'الصنف*'),
//                       validator: (value) {
//                         if (value == null || value.trim().isEmpty) {
//                           return 'الرجاء إدخال أو اختيار صنف.';
//                         }
//                         return null;
//                       },
//                     );
//                 },
//                 optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<String> onSelected, Iterable<String> options) {
//                   return Align(
//                     alignment: Alignment.topRight,
//                     child: Material(
//                       elevation: 4.0,
//                       child: ConstrainedBox(
//                         constraints: BoxConstraints(maxHeight: 200),
//                         child: ListView.builder(
//                           padding: EdgeInsets.zero,
//                           shrinkWrap: true,
//                           itemCount: options.length,
//                           itemBuilder: (BuildContext context, int index) {
//                             final String option = options.elementAt(index);
//                             return InkWell(
//                               onTap: () {
//                                 onSelected(option);
//                               },
//                               child: Padding(
//                                 padding: const EdgeInsets.all(16.0),
//                                 child: Text(option, textAlign: TextAlign.right),
//                               ),
//                             );
//                           },
//                         ),
//                       ),
//                     ),
//                   );
//                 },
//               ),
//               const SizedBox(height: 12),
//               TextFormField(
//                 controller: _descriptionController,
//                 decoration: const InputDecoration(labelText: 'الوصف (اختياري)'),
//                 maxLines: 2,
//                 textInputAction: TextInputAction.next,
//                 textAlign: TextAlign.right,
//               ),
//               const SizedBox(height: 12),
//               TextFormField(
//                 controller: _purchasePriceController,
//                 decoration: const InputDecoration(labelText: 'سعر الشراء*'),
//                 keyboardType: const TextInputType.numberWithOptions(decimal: true),
//                 textInputAction: TextInputAction.next,
//                 textAlign: TextAlign.right,
//                 validator: (value) {
//                   if (value == null || value.isEmpty) return 'الرجاء إدخال سعر الشراء.';
//                   if (double.tryParse(value) == null) return 'الرجاء إدخال رقم صحيح.';
//                   if (double.parse(value) < 0) return 'السعر لا يمكن أن يكون سالباً.';
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 12),
//               TextFormField(
//                 controller: _sellingPriceController,
//                 decoration: const InputDecoration(labelText: 'سعر البيع*'),
//                 keyboardType: const TextInputType.numberWithOptions(decimal: true),
//                 textInputAction: TextInputAction.next,
//                 textAlign: TextAlign.right,
//                 validator: (value) {
//                   if (value == null || value.isEmpty) return 'الرجاء إدخال سعر البيع.';
//                   if (double.tryParse(value) == null) return 'الرجاء إدخال رقم صحيح.';
//                   if (double.parse(value) < 0) return 'السعر لا يمكن أن يكون سالباً.';
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 12),
//               TextFormField(
//                 controller: _quantityController,
//                 decoration: const InputDecoration(labelText: 'الكمية*'),
//                 keyboardType: TextInputType.number,
//                 textInputAction: TextInputAction.next,
//                 textAlign: TextAlign.right,
//                 validator: (value) {
//                   if (value == null || value.isEmpty) return 'الرجاء إدخال الكمية.';
//                   if (int.tryParse(value) == null) return 'الرجاء إدخال عدد صحيح.';
//                   if (int.parse(value) < 0) return 'الكمية لا يمكن أن تكون سالبة.';
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 12),
//               TextFormField(
//                 controller: _unitOfMeasureController,
//                 decoration: const InputDecoration(labelText: 'وحدة القياس* (مثال: قطعة, علبة)'),
//                 textInputAction: TextInputAction.next,
//                 textAlign: TextAlign.right,
//                 validator: (value) {
//                   if (value == null || value.trim().isEmpty) return 'الرجاء إدخال وحدة القياس.';
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 12),
//               TextFormField(
//                 controller: _expiryDateController,
//                 decoration: InputDecoration(
//                   labelText: 'تاريخ الانتهاء (اختياري)',
//                   suffixIcon: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       IconButton(
//                         icon: const Icon(Icons.clear, size: 20, color: Colors.grey),
//                         onPressed: () {
//                           setState(() {
//                             _expiryDate = null;
//                             _expiryDateController.clear();
//                           });
//                         },
//                       ),
//                       const Icon(Icons.calendar_today),
//                     ],
//                   )
//                 ),
//                 readOnly: true,
//                 textAlign: TextAlign.right,
//                 onTap: () => _selectExpiryDate(context),
//               ),
//               const SizedBox(height: 12),
//               TextFormField(
//                 controller: _lowStockThresholdController,
//                 decoration: const InputDecoration(labelText: 'حد التنبيه للكمية المنخفضة (اختياري)'),
//                 keyboardType: TextInputType.number,
//                 textInputAction: TextInputAction.done,
//                 textAlign: TextAlign.right,
//                 validator: (value) {
//                   if (value != null && value.isNotEmpty && int.tryParse(value) == null) {
//                     return 'الرجاء إدخال رقم صحيح أو اتركه فارغاً.';
//                   }
//                   if (value != null && value.isNotEmpty && int.parse(value) < 0) {
//                     return 'الحد لا يمكن أن يكون سالباً.';
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 20),
//               ElevatedButton(
//                 onPressed: _saveForm,
//                 child: Text(widget.product == null ? 'إضافة المنتج' : 'حفظ التعديلات'),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
