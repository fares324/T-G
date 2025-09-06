// lib/screens/inventory_report_screen.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:fouad_stock/model/product_model.dart';
import 'package:fouad_stock/providers/product_provider.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

// Imports for Excel Export & File Handling
import 'package:excel/excel.dart' as ex;
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../services/settings_service.dart';

class InventoryReportScreen extends StatefulWidget {
  const InventoryReportScreen({super.key});

  @override
  State<InventoryReportScreen> createState() => _InventoryReportScreenState();
}

class _InventoryReportScreenState extends State<InventoryReportScreen> {
  List<Product> _allProducts = [];
  List<Product> _displayedProducts = [];
  bool _isLoading = false;
  bool _isExporting = false;

  int _totalUniqueProducts = 0;
  int _totalUnitsInStock = 0;
  double _totalStockValueByPurchasePrice = 0.0;

  String _sortByValue = 'name_asc';
  final Map<String, String> _sortOptions = {
    'name_asc': 'الاسم (أ-ي)',
    'name_desc': 'الاسم (ي-أ)',
    'qty_asc': 'الكمية (الأقل)',
    'qty_desc': 'الكمية (الأكثر)',
    'value_asc': 'القيمة (الأقل)',
    'value_desc': 'القيمة (الأكثر)',
    'expiry_asc': 'الانتهاء (الأقدم)',
    'expiry_desc': 'الانتهاء (الأحدث)',
  };

  String? _selectedCategoryFilter = "الكل";
  List<String> _availableCategories = ["الكل"];

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'ar',
    symbol: 'ج.م',
    decimalDigits: 2,
  );
  final NumberFormat _numberFormatter = NumberFormat.decimalPattern('ar');
  final DateFormat _dateFormatter = DateFormat('yyyy/MM/dd');
  final DateFormat _filenameTimestampFormatter = DateFormat('yyyyMMdd_HHmmss');

  static const Color screenBackground = Color(0xFF0A191E);
  static const Color cardBackground = Color(0xFF102A32);
  static const Color primaryTealAccent = Colors.tealAccent;
  static const Color lightTextColor = Colors.white;
  static Color secondaryTextColor = Colors.white.withOpacity(0.75);
  static const Color subtleDividerColor = Color(0xFF1E3C42);
  static const LinearGradient prominentCardGradient = LinearGradient(
    colors: [Color(0xFF00594D), Color(0xFF00796B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  final SettingsService _settingsService = SettingsService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchInventoryData();
      }
    });
  }

  Future<void> _fetchInventoryData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    await productProvider.fetchProducts();
    if (mounted) {
      setState(() {
        _allProducts = productProvider.products;
        _updateAvailableCategories(productProvider);
        _applyFiltersAndSort();
        _calculateSummaryKPIs();
        _isLoading = false;
      });
    }
  }

  void _updateAvailableCategories(ProductProvider productProvider) {
    final currentSelection = _selectedCategoryFilter;
    final dynamicCategories = productProvider.categories;
    _availableCategories = ["الكل"] + dynamicCategories;
    
    if (!_availableCategories.contains(currentSelection)) {
      _selectedCategoryFilter = "الكل";
    }
  }

  void _calculateSummaryKPIs() {
    _totalUniqueProducts = _allProducts.length;
    _totalUnitsInStock = _allProducts.fold(0, (sum, p) => sum + p.quantity);
    _totalStockValueByPurchasePrice = _allProducts.fold(
      0.0,
      (sum, p) => sum + (p.quantity * p.purchasePrice),
    );
  }

  void _applyFiltersAndSort() {
    List<Product> filtered = List.from(_allProducts);
    if (_selectedCategoryFilter != null && _selectedCategoryFilter != "الكل") {
      filtered = filtered
          .where((p) => p.category == _selectedCategoryFilter)
          .toList();
    }

    filtered.sort((a, b) {
      int compareResult = 0;
      List<String> sortParams = _sortByValue.split('_');
      String field = sortParams[0];
      bool ascending = sortParams[1] == 'asc';
      switch (field) {
        case 'name':
          compareResult = a.name.compareTo(b.name);
          break;
        case 'qty':
          compareResult = a.quantity.compareTo(b.quantity);
          break;
        case 'value':
          compareResult = (a.quantity * a.purchasePrice).compareTo(
            b.quantity * b.purchasePrice,
          );
          break;
        case 'expiry':
          bool aHasExpiry = a.expiryDate.year < 9000;
          bool bHasExpiry = b.expiryDate.year < 9000;
          if (aHasExpiry && !bHasExpiry) return ascending ? -1 : 1;
          if (!aHasExpiry && bHasExpiry) return ascending ? 1 : -1;
          compareResult = a.expiryDate.compareTo(b.expiryDate);
          break;
      }
      return ascending ? compareResult : -compareResult;
    });
    if (mounted)
      setState(() {
        _displayedProducts = filtered;
      });
  }

  Widget _buildProminentKpiCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: prominentCardGradient,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Icon(icon, size: 30, color: lightTextColor.withOpacity(0.85)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: lightTextColor,
                ),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  color: lightTextColor.withOpacity(0.8),
                ),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryKpi(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: lightTextColor.withOpacity(0.95),
          ),
          textAlign: TextAlign.right,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 1),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            color: secondaryTextColor.withOpacity(0.9),
          ),
          textAlign: TextAlign.right,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildControlsSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      margin: const EdgeInsets.only(bottom: 20, top: 8),
      decoration: BoxDecoration(
        color: cardBackground.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: _modernInputDecoration(
                    hint: 'جميع الأصناف',
                    icon: Icons.filter_list_rounded,
                  ),
                  style: const TextStyle(fontFamily: 'Cairo', color: lightTextColor, fontSize: 15),
                  dropdownColor: const Color(0xFF1A343B),
                  iconEnabledColor: secondaryTextColor,
                  value: _selectedCategoryFilter,
                  items: _availableCategories.map((String category) => DropdownMenuItem<String>(
                        value: category,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(category, style: const TextStyle(fontFamily: 'Cairo')),
                        ),
                      )).toList(),
                  onChanged: (String? newValue) => setState(() {
                    _selectedCategoryFilter = newValue;
                    _applyFiltersAndSort();
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: _modernInputDecoration(
                    hint: 'فرز حسب',
                    icon: Icons.sort_by_alpha_rounded,
                  ),
                  style: const TextStyle(fontFamily: 'Cairo', color: lightTextColor, fontSize: 15),
                  dropdownColor: const Color(0xFF1A343B),
                  iconEnabledColor: secondaryTextColor,
                  value: _sortByValue,
                  items: _sortOptions.entries.map((entry) => DropdownMenuItem<String>(
                        value: entry.key,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(entry.value, style: const TextStyle(fontFamily: 'Cairo')),
                        ),
                      )).toList(),
                  onChanged: (String? newValue) => setState(() {
                    if (newValue != null) _sortByValue = newValue;
                    _applyFiltersAndSort();
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _modernInputDecoration({required String hint, IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontFamily: 'Cairo', color: secondaryTextColor, fontSize: 15),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      filled: true,
      fillColor: screenBackground.withOpacity(0.8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      prefixIcon: icon != null ? Padding(padding: const EdgeInsets.only(right: 8.0, left: 4.0), child: Icon(icon, color: secondaryTextColor, size: 22)) : null,
    );
  }

  Widget _buildProductReportItemCard(Product product) {
    final stockValue = product.quantity * product.purchasePrice;
    final hasExpiryDate = product.expiryDate.year < 9000;
    bool isExpired = hasExpiryDate && product.isExpired;
    bool isNearingExpiry = hasExpiryDate && product.isNearingExpiry;
    bool isLowStock = product.isLowStock && !product.isOutOfStock;
    bool isOutOfStock = product.isOutOfStock;

    String statusText = "";
    Color statusColor = primaryTealAccent;
    IconData? statusIcon;

    if (isOutOfStock) {
      statusText = "نفذ";
      statusColor = Colors.redAccent.shade200;
      statusIcon = Icons.error_outline_rounded;
    } else if (isExpired) {
      statusText = "منتهي";
      statusColor = Colors.orangeAccent.shade200;
      statusIcon = Icons.hourglass_disabled_outlined;
    } else if (isLowStock) {
      statusText = "منخفض";
      statusColor = Colors.yellowAccent.shade400;
      statusIcon = Icons.warning_amber_rounded;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(14.0),
        border: statusText.isNotEmpty ? Border.all(color: statusColor.withOpacity(0.6), width: 1.2) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (statusIcon != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 16),
                      const SizedBox(width: 5),
                      Text(statusText, style: TextStyle(color: statusColor, fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              Expanded(
                child: Text(
                  product.name,
                  style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: lightTextColor),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Divider(color: subtleDividerColor, height: 28, thickness: 0.8),
          _buildDetailRowSlim("الصنف:", product.category),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: _buildDetailRowSlim("الكمية:", "${_numberFormatter.format(product.quantity)} ${product.unitOfMeasure}")),
              Expanded(child: _buildDetailRowSlim("قيمة المخزون:", _currencyFormatter.format(stockValue), valueColor: primaryTealAccent.withOpacity(0.95))),
            ],
          ),
          if (hasExpiryDate)
            _buildDetailRowSlim(
              "تاريخ الانتهاء:",
              _dateFormatter.format(product.expiryDate),
              valueColor: isExpired ? Colors.redAccent.shade200 : (isNearingExpiry ? Colors.orangeAccent.shade200 : null),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRowSlim(String label, String value, {Color? valueColor, FontWeight? valueWeight}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Text(
              value,
              style: TextStyle(fontFamily: 'Cairo', fontWeight: valueWeight ?? FontWeight.w500, fontSize: 14.5, color: valueColor ?? lightTextColor.withOpacity(0.9)),
              textAlign: TextAlign.left,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: secondaryTextColor), textAlign: TextAlign.right),
        ],
      ),
    );
  }

  Future<void> _exportInventoryToExcel() async {
    if (_displayedProducts.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد بيانات للتصدير!', style: TextStyle(fontFamily: 'Cairo')),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _isExporting = true;
    });

    try {
      final String storeName = await _settingsService.getStoreName();

      var excel = ex.Excel.createExcel();
      ex.Sheet sheetObject = excel['Inventory Report'];
      
      ex.CellStyle titleCellStyle = ex.CellStyle(bold: true, fontSize: 16, fontFamily: 'Calibri', horizontalAlign: ex.HorizontalAlign.Right, verticalAlign: ex.VerticalAlign.Center);
      ex.CellStyle dateCellStyle = ex.CellStyle(fontSize: 12, fontFamily: 'Calibri', horizontalAlign: ex.HorizontalAlign.Right, verticalAlign: ex.VerticalAlign.Center);
      ex.CellStyle headerStyle = ex.CellStyle(bold: true, fontSize: 11, fontFamily: 'Calibri', backgroundColorHex: ex.ExcelColor.fromHexString('#DDEBF7'), fontColorHex: ex.ExcelColor.fromHexString('#000000'), horizontalAlign: ex.HorizontalAlign.Center, verticalAlign: ex.VerticalAlign.Center, textWrapping: ex.TextWrapping.WrapText, bottomBorder: ex.Border(borderStyle: ex.BorderStyle.Thin, borderColorHex: ex.ExcelColor.fromHexString('#7F7F7F')));
      
      ex.CellStyle defaultDataTextStyle = ex.CellStyle(fontSize: 10, fontFamily: 'Arial', horizontalAlign: ex.HorizontalAlign.Right, verticalAlign: ex.VerticalAlign.Center);
      ex.CellStyle numberDataCellStyle = defaultDataTextStyle.copyWith(numberFormat: ex.NumFormat.standard_0);
      ex.CellStyle currencyDataCellStyle = defaultDataTextStyle.copyWith(numberFormat: ex.NumFormat.standard_2);
      ex.CellStyle dateDataCellStyle = defaultDataTextStyle.copyWith(numberFormat: ex.NumFormat.defaultDateTime);

      sheetObject.merge(ex.CellIndex.indexByString("A1"), ex.CellIndex.indexByString("I1"));
      var cellA1 = sheetObject.cell(ex.CellIndex.indexByString("A1"));
      cellA1.value = ex.TextCellValue("اسم المخزن: $storeName");
      cellA1.cellStyle = titleCellStyle;
      sheetObject.setRowHeight(0, 25);

      sheetObject.merge(ex.CellIndex.indexByString("A2"), ex.CellIndex.indexByString("I2"));
      var cellA2 = sheetObject.cell(ex.CellIndex.indexByString("A2"));
      cellA2.value = ex.TextCellValue("تقرير المخزون بتاريخ: ${_dateFormatter.format(DateTime.now())}");
      cellA2.cellStyle = dateCellStyle;
      sheetObject.setRowHeight(1, 20);

      sheetObject.appendRow([]);

      List<ex.CellValue> headers = [
        ex.TextCellValue('م'),
        ex.TextCellValue('اسم المنتج'),
        ex.TextCellValue('الصنف'),
        ex.TextCellValue('الكمية'),
        ex.TextCellValue('الوحدة'),
        ex.TextCellValue('سعر الشراء'),
        ex.TextCellValue('سعر البيع'),
        ex.TextCellValue('قيمة المخزون (شراء)'),
        ex.TextCellValue('تاريخ الانتهاء'),
      ];
      sheetObject.appendRow(headers);

      int headerRowActualIndex = 3;
      for (var i = 0; i < headers.length; i++) {
        var cell = sheetObject.cell(ex.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: headerRowActualIndex));
        cell.cellStyle = headerStyle;
      }
      sheetObject.setRowHeight(headerRowActualIndex, 35);

      for (int i = 0; i < _displayedProducts.length; i++) {
        Product p = _displayedProducts[i];
        bool hasExpiry = p.expiryDate.year < 9000;
        List<ex.CellValue?> rowData = [
          ex.IntCellValue(i + 1),
          ex.TextCellValue(p.name),
          ex.TextCellValue(p.category),
          ex.IntCellValue(p.quantity),
          ex.TextCellValue(p.unitOfMeasure),
          ex.DoubleCellValue(p.purchasePrice),
          ex.DoubleCellValue(p.sellingPrice),
          ex.DoubleCellValue(p.quantity * p.purchasePrice),
          hasExpiry ? ex.DateCellValue(year: p.expiryDate.year, month: p.expiryDate.month, day: p.expiryDate.day) : ex.TextCellValue('لا يوجد'),
        ];
        sheetObject.appendRow(rowData);
        int currentRowIndex = headerRowActualIndex + 1 + i;
        
        sheetObject.cell(ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRowIndex)).cellStyle = numberDataCellStyle;
        sheetObject.cell(ex.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRowIndex)).cellStyle = defaultDataTextStyle;
        sheetObject.cell(ex.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRowIndex)).cellStyle = defaultDataTextStyle;
        sheetObject.cell(ex.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRowIndex)).cellStyle = numberDataCellStyle;
        sheetObject.cell(ex.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRowIndex)).cellStyle = defaultDataTextStyle;
        sheetObject.cell(ex.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRowIndex)).cellStyle = currencyDataCellStyle;
        sheetObject.cell(ex.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: currentRowIndex)).cellStyle = currencyDataCellStyle;
        sheetObject.cell(ex.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: currentRowIndex)).cellStyle = currencyDataCellStyle;
        sheetObject.cell(ex.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: currentRowIndex)).cellStyle = hasExpiry ? dateDataCellStyle : defaultDataTextStyle;
      }

      sheetObject.setColumnWidth(0, 6);
      sheetObject.setColumnWidth(1, 40);
      sheetObject.setColumnWidth(2, 22);
      sheetObject.setColumnWidth(3, 10);
      sheetObject.setColumnWidth(4, 12);
      sheetObject.setColumnWidth(5, 18);
      sheetObject.setColumnWidth(6, 18);
      sheetObject.setColumnWidth(7, 22);
      sheetObject.setColumnWidth(8, 15);

      var fileBytes = excel.encode();
      if (fileBytes != null) {
        String simpleStoreName = storeName.replaceAll(RegExp(r'[^\p{L}\p{N}\s]+', unicode: true), '').replaceAll(' ', '_');
        if (simpleStoreName.isEmpty) simpleStoreName = "Store";
        String timestamp = _filenameTimestampFormatter.format(DateTime.now());
        String suggestedFileName = "Inventory_${simpleStoreName}_$timestamp.xlsx";

        String? savedFilePath = await FilePicker.platform.saveFile(
          dialogTitle: 'اختر مكان حفظ تقرير الإكسل:',
          fileName: suggestedFileName,
          bytes: Uint8List.fromList(fileBytes),
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 8),
            content: Text('تم حفظ التقرير بنجاح!', style: TextStyle(fontFamily: 'Cairo', fontSize: 14.5)),
            action: SnackBarAction(
              label: 'مشاركة الملف',
              textColor: primaryTealAccent,
              onPressed: () async {
                try {
                    final xfile = XFile(savedFilePath!);
                    await Share.shareXFiles([xfile], text: 'تقرير مخزون ${storeName}');
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('لا يمكن مشاركة الملف: $e', style: TextStyle(fontSize: 14.5))),
                    );
                  }
                }
              },
            ),
          ),
        );
            } else {
        throw Exception("فشل إنشاء بيانات ملف الإكسل.");
      }
    } catch (e) {
      print("Export Error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تصدير التقرير: ${e.toString().split('\n').first}', style: TextStyle(fontFamily: 'Cairo', fontSize: 14.5))),
      );
    } finally {
      if (mounted)
        setState(() {
          _isExporting = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: screenBackground,
        primaryColor: primaryTealAccent,
        hintColor: secondaryTextColor,
        fontFamily: 'Cairo',
        cardColor: cardBackground,
        dividerColor: subtleDividerColor,
        iconTheme: IconThemeData(color: secondaryTextColor),
        appBarTheme: const AppBarTheme(
          backgroundColor: screenBackground,
          elevation: 0,
          titleTextStyle: TextStyle(fontFamily: 'Cairo', fontSize: 22, fontWeight: FontWeight.bold, color: lightTextColor),
          iconTheme: IconThemeData(color: lightTextColor),
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: lightTextColor, fontFamily: 'Cairo', fontSize: 15),
          bodyMedium: TextStyle(color: secondaryTextColor, fontFamily: 'Cairo', fontSize: 14),
          titleLarge: TextStyle(color: lightTextColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 20),
          titleMedium: TextStyle(color: lightTextColor.withOpacity(0.9), fontWeight: FontWeight.w600, fontFamily: 'Cairo', fontSize: 18),
          titleSmall: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.w500, fontFamily: 'Cairo', fontSize: 16),
          headlineSmall: TextStyle(color: lightTextColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 24),
          labelLarge: TextStyle(color: lightTextColor, fontFamily: 'Cairo', fontSize: 17),
        ).apply(fontFamily: 'Cairo'),
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: TextStyle(fontFamily: 'Cairo', color: secondaryTextColor, fontSize: 15),
          hintStyle: TextStyle(fontFamily: 'Cairo', color: secondaryTextColor.withOpacity(0.7), fontSize: 15),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('نظرة عامة على المخزون'),
          actions: [ IconButton(icon: const Icon(Icons.refresh_outlined), onPressed: _isLoading ? null : _fetchInventoryData) ],
        ),
        body: _isLoading && _allProducts.isEmpty
            ? Center(child: CircularProgressIndicator(color: primaryTealAccent))
            : RefreshIndicator(
                onRefresh: _fetchInventoryData,
                color: primaryTealAccent,
                backgroundColor: cardBackground,
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    SizedBox(
                      height: 170,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 5,
                            child: _buildProminentKpiCard('قيمة المخزون الإجمالية', _currencyFormatter.format(_totalStockValueByPurchasePrice), Icons.account_balance_wallet_outlined),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 3,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
                              decoration: BoxDecoration(color: cardBackground.withOpacity(0.85), borderRadius: BorderRadius.circular(16)),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _buildSecondaryKpi('أنواع المنتجات', _numberFormatter.format(_totalUniqueProducts)),
                                  _buildSecondaryKpi('إجمالي الوحدات', _numberFormatter.format(_totalUnitsInStock)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildControlsSection(),
                    Padding(
                      padding: const EdgeInsets.only(right: 4.0, top: 12, bottom: 10.0),
                      child: Text('قائمة المنتجات (${_numberFormatter.format(_displayedProducts.length)})', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.right),
                    ),
                    if (_isLoading && _displayedProducts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(40.0),
                        child: Center(child: Text("...جاري التحديث", style: TextStyle(fontFamily: 'Cairo', fontSize: 17))),
                      )
                    else if (_displayedProducts.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 50.0, horizontal: 20.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_sharp, size: 64, color: secondaryTextColor.withOpacity(0.5)),
                            const SizedBox(height: 24),
                            Text(
                              'لا توجد منتجات تطابق بحثك أو لا يوجد مخزون.',
                              style: TextStyle(fontFamily: 'Cairo', fontSize: 18, color: secondaryTextColor),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _displayedProducts.length,
                        itemBuilder: (context, index) => _buildProductReportItemCard(_displayedProducts[index]),
                      ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: _isExporting ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: screenBackground, strokeWidth: 2.8)) : Icon(Icons.share_outlined, color: screenBackground, size: 22),
                      label: Text(
                        _isExporting ? 'جاري التصدير...' : 'مشاركة تقرير Excel',
                        style: TextStyle(fontFamily: 'Cairo', color: screenBackground, fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryTealAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isExporting ? null : _exportInventoryToExcel,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }
}
