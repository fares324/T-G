// lib/screens/sales_report_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:fouad_stock/model/invoice_model.dart';
import 'package:fouad_stock/providers/invoice_provider.dart';
import 'package:fouad_stock/providers/product_provider.dart';
import 'package:fouad_stock/screens/invoice_details_screen.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:excel/excel.dart' as ex;
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../services/settings_service.dart';

enum DateRangePreset { today, yesterday, last7Days, last30Days, thisMonth, custom }

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  DateRangePreset _selectedPreset = DateRangePreset.today;
  List<Invoice> _salesInvoices = [];
  bool _isLoading = false;
  bool _isExporting = false;

  double _totalSales = 0.0;
  double _totalDiscounts = 0.0;
  double _totalCost = 0.0;
  double _netProfit = 0.0;
  int _invoiceCount = 0;

  List<FlSpot> _chartSpots = [];
  double _chartMinX = 0, _chartMaxX = 0, _chartMinY = 0, _chartMaxY = 0;
  List<String> _bottomTitles = [];
  List<Map<String, dynamic>> _topSellingProducts = [];
  
  final DateFormat _headerDateFormatter = DateFormat('d MMM', 'ar');
  final DateFormat _listDateFormatter = DateFormat('yyyy/MM/dd', 'ar');
  final NumberFormat _currencyFormatter = NumberFormat.currency(locale: 'ar', symbol: 'ج.م', decimalDigits: 0);
  final NumberFormat _currencyFormatterWithDecimals = NumberFormat.currency(locale: 'ar', symbol: 'ج.م', decimalDigits: 2);
  final NumberFormat _numberFormatter = NumberFormat.decimalPattern('ar');
  final DateFormat _filenameTimestampFormatter = DateFormat('yyyyMMdd_HHmmss');
  final SettingsService _settingsService = SettingsService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) { _setDateRange(DateRangePreset.today); }
    });
  }

  void _setDateRange(DateRangePreset preset, {DateTime? customStart, DateTime? customEnd}) {
    final now = DateTime.now(); DateTime newStart; DateTime newEnd;
    switch (preset) {
      case DateRangePreset.today: newStart = DateTime(now.year, now.month, now.day); newEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999); break;
      case DateRangePreset.yesterday: final yesterday = now.subtract(const Duration(days: 1)); newStart = DateTime(yesterday.year, yesterday.month, yesterday.day); newEnd = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59, 999); break;
      case DateRangePreset.last7Days: newEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999); newStart = newEnd.subtract(const Duration(days: 6)); newStart = DateTime(newStart.year, newStart.month, newStart.day); break;
      case DateRangePreset.last30Days: newEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999); newStart = newEnd.subtract(const Duration(days: 29)); newStart = DateTime(newStart.year, newStart.month, newStart.day); break;
      case DateRangePreset.thisMonth: newStart = DateTime(now.year, now.month, 1); newEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999); break;
      case DateRangePreset.custom: newStart = customStart ?? DateTime(now.year, now.month, now.day); newEnd = customEnd ?? DateTime(now.year, now.month, now.day, 23, 59, 59, 999); if (newEnd.isBefore(newStart)) newEnd = newStart; newStart = DateTime(newStart.year, newStart.month, newStart.day); newEnd = DateTime(newEnd.year, newEnd.month, newEnd.day, 23, 59, 59, 999); break;
    }
    if (mounted) { setState(() { _startDate = newStart; _endDate = newEnd; _selectedPreset = preset; });}
    _fetchReportData();
  }

  Future<void> _selectCustomDateRange(BuildContext context) async {
    final initialDateRange = DateTimeRange(start: _startDate, end: _endDate);
    final ThemeData currentTheme = Theme.of(context);
    final newDateRange = await showDateRangePicker( context: context, initialDateRange: initialDateRange, firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 365)), locale: const Locale('ar'),
      builder: (context, child) {
        return Theme(
          data: currentTheme.copyWith(
              colorScheme: currentTheme.colorScheme.copyWith(
                primary: currentTheme.colorScheme.primary,
                onPrimary: Colors.white,
                surface: currentTheme.cardColor,
                onSurface: currentTheme.colorScheme.onSurface,
              )
          ),
          child: child!
        );
      },
    );
    if (newDateRange != null) { _setDateRange(DateRangePreset.custom, customStart: newDateRange.start, customEnd: newDateRange.end); }
  }

  Future<void> _fetchReportData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _salesInvoices = [];
      _topSellingProducts = [];
      _totalSales = 0.0;
      _totalDiscounts = 0.0;
      _totalCost = 0.0;
      _netProfit = 0.0;
      _invoiceCount = 0;
    });

    final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
    
    try {
      final invoices = await invoiceProvider.getSalesInvoicesByDateRange(_startDate, _endDate);
      final reportData = invoiceProvider.generateSalesReport(invoices);

      if (mounted) {
        setState(() {
          _salesInvoices = invoices;
          _totalSales = reportData.totalSales;
          _totalDiscounts = reportData.totalDiscounts;
          _totalCost = reportData.totalCost;
          _netProfit = reportData.netProfit;
          _invoiceCount = reportData.invoiceCount;
          
          _prepareChartData(invoices, _startDate, _endDate);
          _calculateTopSellingProducts(invoices);
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.red.shade700, content: Text('خطأ جلب بيانات التقرير: $error', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo'))));
      }
    } finally {
      if (mounted) { setState(() { _isLoading = false; });}
    }
  }

  void _calculateTopSellingProducts(List<Invoice> invoices) {
    if (invoices.isEmpty) {
      if (mounted) setState(() => _topSellingProducts = []);
      return;
    }
    Map<int, Map<String, dynamic>> productSales = {};
    for (var invoice in invoices) {
      for (var item in invoice.items) {
        if (productSales.containsKey(item.productId)) {
          productSales[item.productId]!['quantitySold'] += item.quantity;
        } else {
          productSales[item.productId] = {
            'productId': item.productId,
            'productName': item.productName,
            'quantitySold': item.quantity,
          };
        }
      }
    }
    List<Map<String, dynamic>> sortedProducts = productSales.values.toList();
    sortedProducts.sort((a, b) => (b['quantitySold'] as int).compareTo(a['quantitySold'] as int));
    if (mounted) {
      setState(() {
        _topSellingProducts = sortedProducts.take(3).toList();
      });
    }
  }

  void _prepareChartData(List<Invoice> invoices, DateTime reportStartDate, DateTime reportEndDate) {
    if (invoices.isEmpty) { setState(() { _chartSpots = []; _chartMinX = 0; _chartMaxX = 0; _chartMinY = 0; _chartMaxY = 0; _bottomTitles = []; }); return;}
    Map<int, double> dailyTotals = {}; int totalDaysInPeriod = reportEndDate.difference(reportStartDate).inDays + 1;
    for (int i = 0; i < totalDaysInPeriod; i++) { dailyTotals[i] = 0.0; }
    for (var invoice in invoices) { int dayIndex = invoice.date.difference(reportStartDate).inDays; if (dayIndex >= 0 && dayIndex < totalDaysInPeriod) { dailyTotals[dayIndex] = (dailyTotals[dayIndex] ?? 0) + invoice.grandTotal;}}
    List<FlSpot> spots = []; List<String> bottomTitles = [];
    DateFormat bottomTitleFormatter = DateFormat('E','ar');
    if (totalDaysInPeriod == 1) bottomTitleFormatter = DateFormat('HH','ar');
    else if (totalDaysInPeriod > 7 && totalDaysInPeriod <= 35) bottomTitleFormatter = DateFormat('d','ar');
    else if (totalDaysInPeriod > 35) bottomTitleFormatter = DateFormat('dd/MM','ar');
    double maxY = 0;
    int labelInterval = (totalDaysInPeriod / 7).ceil();
    for (int i = 0; i < totalDaysInPeriod; i++) {
        spots.add(FlSpot(i.toDouble(), dailyTotals[i] ?? 0.0));
        if ((dailyTotals[i] ?? 0.0) > maxY) maxY = dailyTotals[i] ?? 0.0;
        DateTime currentDay = reportStartDate.add(Duration(days: i));
        if (totalDaysInPeriod == 1) {
            bottomTitles.add(bottomTitleFormatter.format(currentDay));
        } else if (i == 0 || i == totalDaysInPeriod - 1 || (i % labelInterval == 0 && totalDaysInPeriod > 7) || (totalDaysInPeriod <=7) ) {
             bottomTitles.add(bottomTitleFormatter.format(currentDay));
        }
        else {
            bottomTitles.add('');
        }
    }
    setState(() { _chartSpots = spots; _chartMinX = 0; _chartMaxX = (totalDaysInPeriod - 1).toDouble(); _chartMinY = 0; _chartMaxY = maxY == 0 ? 100 : maxY * 1.2; _bottomTitles = bottomTitles; });
  }

  Future<void> _exportSalesReportToExcel() async {
    if (_salesInvoices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد بيانات للتصدير!', style: TextStyle(fontFamily: 'Cairo'))));
      return;
    }
    setState(() => _isExporting = true);
    try {
      final String storeName = await _settingsService.getStoreName();
      var excel = ex.Excel.createExcel();
      ex.Sheet sheetObject = excel['Sales Report'];
      
      ex.CellStyle titleStyle = ex.CellStyle(bold: true, fontSize: 16, horizontalAlign: ex.HorizontalAlign.Right);
      ex.CellStyle dateStyle = ex.CellStyle(fontSize: 12, horizontalAlign: ex.HorizontalAlign.Right);
      ex.CellStyle headerStyle = ex.CellStyle(bold: true, backgroundColorHex: ex.ExcelColor.fromHexString('#DDEBF7'), horizontalAlign: ex.HorizontalAlign.Center, verticalAlign: ex.VerticalAlign.Center);
      ex.CellStyle totalLabelStyle = ex.CellStyle(bold: true, backgroundColorHex: ex.ExcelColor.fromHexString('#F2F2F2'), horizontalAlign: ex.HorizontalAlign.Right);
      ex.CellStyle totalValueStyle = ex.CellStyle(bold: true, backgroundColorHex: ex.ExcelColor.fromHexString('#F2F2F2'), numberFormat: ex.NumFormat.custom(formatCode: '#,##0.00" ج.م"'));

      sheetObject.merge(ex.CellIndex.indexByString("A1"), ex.CellIndex.indexByString("I1"));
      sheetObject.cell(ex.CellIndex.indexByString("A1")).value = ex.TextCellValue("تقرير المبيعات لـ: $storeName");
      sheetObject.cell(ex.CellIndex.indexByString("A1")).cellStyle = titleStyle;
      sheetObject.merge(ex.CellIndex.indexByString("A2"), ex.CellIndex.indexByString("I2"));
      sheetObject.cell(ex.CellIndex.indexByString("A2")).value = ex.TextCellValue("الفترة من: ${_listDateFormatter.format(_startDate)} إلى: ${_listDateFormatter.format(_endDate)}");
      sheetObject.cell(ex.CellIndex.indexByString("A2")).cellStyle = dateStyle;
      sheetObject.appendRow([]);
      
      int summaryRow = 4;
      sheetObject.cell(ex.CellIndex.indexByString("A$summaryRow")).value = ex.TextCellValue("إجمالي المبيعات (قبل الخصم)");
      sheetObject.cell(ex.CellIndex.indexByString("B$summaryRow")).value = ex.DoubleCellValue(_totalSales);
      sheetObject.cell(ex.CellIndex.indexByString("C$summaryRow")).value = ex.TextCellValue("إجمالي الخصومات");
      sheetObject.cell(ex.CellIndex.indexByString("D$summaryRow")).value = ex.DoubleCellValue(_totalDiscounts);
      sheetObject.cell(ex.CellIndex.indexByString("E$summaryRow")).value = ex.TextCellValue("صافي الربح");
      sheetObject.cell(ex.CellIndex.indexByString("F$summaryRow")).value = ex.DoubleCellValue(_netProfit);
      for(int i=0; i<6; i++){
        sheetObject.cell(ex.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: summaryRow-1)).cellStyle = i.isEven ? totalLabelStyle : totalValueStyle;
      }
      sheetObject.appendRow([]);

      List<ex.CellValue> headers = [
        ex.TextCellValue('رقم الفاتورة'), ex.TextCellValue('التاريخ'), ex.TextCellValue('العميل'),
        ex.TextCellValue('اسم المنتج'), ex.TextCellValue('الكمية'), ex.TextCellValue('سعر بيع الوحدة'),
        ex.TextCellValue('إجمالي بيع المنتج'), ex.TextCellValue('تكلفة شراء المنتج'), ex.TextCellValue('الربح من المنتج (بعد الخصم)')
      ];
      sheetObject.appendRow(headers);
      for (var i = 0; i < headers.length; i++) {
        sheetObject.cell(ex.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: sheetObject.maxRows-1)).cellStyle = headerStyle;
      }

      // --- CHANGED: Item-centric data rows with prorated discount ---
      for (var invoice in _salesInvoices) {
        for (var item in invoice.items) {
          double itemTotalSale = item.unitPrice * item.quantity;
          double itemTotalCost = item.purchasePrice * item.quantity;
          double grossItemProfit = itemTotalSale - itemTotalCost;

          // Prorate the discount based on the item's value relative to the invoice subtotal
          double itemShareOfDiscount = 0.0;
          if (invoice.subtotal > 0) { // Avoid division by zero
            itemShareOfDiscount = (itemTotalSale / invoice.subtotal) * invoice.discountAmount;
          }
          
          double netItemProfit = grossItemProfit - itemShareOfDiscount;

          List<ex.CellValue> rowData = [
            ex.TextCellValue(invoice.invoiceNumber),
            ex.DateCellValue(year: invoice.date.year, month: invoice.date.month, day: invoice.date.day),
            ex.TextCellValue(invoice.clientName ?? 'غير محدد'),
            ex.TextCellValue(item.productName),
            ex.IntCellValue(item.quantity),
            ex.DoubleCellValue(item.unitPrice),
            ex.DoubleCellValue(itemTotalSale),
            ex.DoubleCellValue(itemTotalCost),
            ex.DoubleCellValue(netItemProfit), // Use the net profit after discount
          ];
          sheetObject.appendRow(rowData);
        }
      }

      for (var i = 0; i < headers.length; i++) { sheetObject.setColumnAutoFit(i); }
      var fileBytes = excel.encode();
      if (fileBytes != null && mounted) {
        String timestamp = _filenameTimestampFormatter.format(DateTime.now());
        String suggestedFileName = "SalesReport_Items_${timestamp}.xlsx";
        String? savedFilePath = await FilePicker.platform.saveFile(
          dialogTitle: 'اختر مكان حفظ التقرير:',
          fileName: suggestedFileName,
          bytes: Uint8List.fromList(fileBytes),
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
        );
        if (savedFilePath != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم حفظ التقرير بنجاح!', style: TextStyle(fontFamily: 'Cairo')),
              action: SnackBarAction(label: 'مشاركة', onPressed: () async {
                await Share.shareXFiles([XFile(savedFilePath)], text: 'تقرير مبيعات المنتجات');
              }),
            ),
          );
        }
      }
    } catch (e) {
      print("Export Error: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل تصدير التقرير: $e', style: TextStyle(fontFamily: 'Cairo'))));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  String _getPresetButtonText(DateRangePreset preset) {
    switch (preset) {
      case DateRangePreset.today: return 'اليوم';
      case DateRangePreset.yesterday: return 'الأمس';
      case DateRangePreset.last7Days: return '7 أيام';
      case DateRangePreset.last30Days: return '30 يوم';
      case DateRangePreset.thisMonth: return 'هذا الشهر';
      default: return 'مخصص';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقرير المبيعات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        backgroundColor: Colors.teal.shade900,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: _isExporting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0)) : const Icon(Icons.share_outlined),
            tooltip: 'تصدير إلى Excel',
            onPressed: _isExporting ? null : _exportSalesReportToExcel,
          ),
          IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'تحديث', onPressed: _isLoading ? null : _fetchReportData),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0),
            child: _buildDateFilter(theme),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSalesChart(theme),
                        const SizedBox(height: 20),
                        Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: _buildKpiCard('إجمالي المبيعات', _currencyFormatter.format(_totalSales), '${_numberFormatter.format(_invoiceCount)} فاتورة', theme)),
                                const SizedBox(width: 12),
                                Expanded(child: _buildKpiCard('إجمالي الخصومات', _currencyFormatter.format(_totalDiscounts), 'على المبيعات', theme)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(child: _buildKpiCard('إجمالي التكلفة', _currencyFormatter.format(_totalCost), 'تكلفة البضاعة', theme)),
                                const SizedBox(width: 12),
                                Expanded(child: _buildKpiCard('صافي الربح', _currencyFormatter.format(_netProfit), 'بعد الخصم والتكلفة', theme)),
                              ],
                            ),
                          ],
                        ),
                        _buildTopSellingProductsSection(theme),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("الفواتير", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface, fontFamily: 'Cairo')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_salesInvoices.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40.0),
                            child: Column(
                              children: [
                                Icon(Icons.inbox_outlined, size: 50, color: theme.disabledColor),
                                const SizedBox(height: 16),
                                Text('لا توجد فواتير لهذه الفترة', style: theme.textTheme.titleMedium?.copyWith(color: theme.disabledColor, fontFamily: 'Cairo')),
                              ],
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _salesInvoices.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final invoice = _salesInvoices[index];
                              return _buildInvoiceListItem(invoice, index, theme);
                            },
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilter(ThemeData theme) {
    List<DateRangePreset> presetsToShow = [DateRangePreset.today, DateRangePreset.last7Days, DateRangePreset.thisMonth, DateRangePreset.custom];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0), height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: presetsToShow.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final preset = presetsToShow[index];
          final bool isSelected = _selectedPreset == preset;
          Color chipBgColor = isSelected ? Colors.teal : theme.cardColor.withOpacity(0.5);
          Color labelColor = isSelected ? Colors.white : theme.colorScheme.onSurface.withOpacity(0.7);
          BorderSide borderSide = isSelected ? BorderSide.none : BorderSide(color: theme.dividerColor, width: 1.0);
          if (preset == DateRangePreset.custom) {
            return ActionChip(
              avatar: Icon(Icons.calendar_month_outlined, size: 18, color: labelColor),
              label: Text(isSelected ? '${_headerDateFormatter.format(_startDate)} - ${_headerDateFormatter.format(_endDate)}' : 'مخصص', overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Cairo')),
              onPressed: () => _selectCustomDateRange(context),
              backgroundColor: chipBgColor,
              labelStyle: TextStyle(color: labelColor, fontWeight: FontWeight.w500, fontSize: 13, fontFamily: 'Cairo'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: borderSide),
              elevation: isSelected ? 2 : 0.5,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            );
          }
          return ChoiceChip(
            label: Text(_getPresetButtonText(preset), style: TextStyle(fontFamily: 'Cairo')),
            selected: isSelected,
            onSelected: (selected) { if (selected) _setDateRange(preset);},
            backgroundColor: chipBgColor,
            selectedColor: chipBgColor,
            labelStyle: TextStyle(color: labelColor, fontWeight: FontWeight.w500, fontSize: 13, fontFamily: 'Cairo'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: borderSide),
            elevation: isSelected ? 2 : 0.5,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          );
        },
      ),
    );
  }

  Widget _buildSalesChart(ThemeData theme) {
    final List<Color> chartGradient = [theme.colorScheme.primary, theme.colorScheme.primary.withOpacity(0.6)];
    final Color gridColor = theme.dividerColor;
    final Color titleColor = theme.colorScheme.onSurfaceVariant;
    final Color cardBg = theme.brightness == Brightness.dark ? theme.colorScheme.surface.withOpacity(0.05) : theme.cardColor;
    final Color textColorOnCard = theme.colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(theme.brightness == Brightness.dark ? 0.1 : 0.05), blurRadius: 8, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("إجمالي المبيعات", style: theme.textTheme.titleLarge?.copyWith(color: textColorOnCard, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: 2.0,
            child: _chartSpots.isEmpty && !_isLoading ? Center(child: Text("لا توجد بيانات للرسم البياني", style: TextStyle(color: theme.disabledColor, fontFamily: 'Cairo')))
                : _isLoading && _chartSpots.isEmpty ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                    : Padding(
                        padding: const EdgeInsets.only(right: 24.0, left: 8.0, top: 16, bottom: 0),
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(show: true, drawVerticalLine: true, horizontalInterval: _chartMaxY > 0 ? _chartMaxY / 3 : 25, verticalInterval: 1, getDrawingHorizontalLine: (value) => FlLine(color: gridColor.withOpacity(0.5), strokeWidth: 0.5), getDrawingVerticalLine: (value) => FlLine(color: gridColor.withOpacity(0.5), strokeWidth: 0.5)),
                            titlesData: FlTitlesData(
                              show: true,
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, interval: 1, getTitlesWidget: (value, meta) { final index = value.toInt(); if (index >= 0 && index < _bottomTitles.length && _bottomTitles[index].isNotEmpty) { return Padding(padding: const EdgeInsets.only(top: 6.0), child: Text(_bottomTitles[index], style: TextStyle(color: titleColor, fontWeight: FontWeight.normal, fontSize: 9, fontFamily: 'Cairo'))); } return const SizedBox.shrink();})),
                              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 50, getTitlesWidget: (value, meta) { if (value == _chartMinY || value == _chartMaxY || (value > _chartMinY && value < _chartMaxY && meta.appliedInterval > 0 && value % meta.appliedInterval < 1 && (_chartMaxY - _chartMinY) / meta.appliedInterval <= 5 )) { return Padding(padding: const EdgeInsets.only(right: 4.0), child: Text(_currencyFormatter.format(value), style: TextStyle(color: titleColor, fontWeight: FontWeight.normal, fontSize: 9, fontFamily: 'Cairo'), textAlign: TextAlign.right)); } return const SizedBox.shrink();}, interval: _chartMaxY > 0 ? _chartMaxY / (_chartMaxY > 500 ? 3 : 2) : 25)),
                            ),
                            borderData: FlBorderData(show: false),
                            minX: _chartMinX, maxX: _chartMaxX, minY: _chartMinY, maxY: _chartMaxY,
                            lineBarsData: [LineChartBarData(spots: _chartSpots, isCurved: true, gradient: LinearGradient(colors: chartGradient), barWidth: 2.5, isStrokeCapRound: true, dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: chartGradient.map((color) => color.withOpacity(0.3)).toList(), begin: Alignment.topCenter, end: Alignment.bottomCenter)))],
                            lineTouchData: LineTouchData(handleBuiltInTouches: true, touchTooltipData: LineTouchTooltipData(getTooltipColor: (touchedSpot) => cardBg.withOpacity(0.9), getTooltipItems: (List<LineBarSpot> touchedBarSpots) { return touchedBarSpots.map((barSpot) { final flSpot = barSpot; return LineTooltipItem('${_currencyFormatter.format(flSpot.y)}\n', TextStyle(color: textColorOnCard, fontWeight: FontWeight.bold, fontFamily: 'Cairo'), children: [TextSpan(text: _bottomTitles.isNotEmpty && _bottomTitles.length > flSpot.x.toInt() && flSpot.x.toInt() >= 0 ? _bottomTitles[flSpot.x.toInt()] : '', style: TextStyle(color: titleColor, fontWeight: FontWeight.normal, fontSize: 10, fontFamily: 'Cairo'))]); }).toList(); })),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, String secondaryValue, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.teal,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(theme.brightness == Brightness.dark ? 0.2 : 0.1), blurRadius: 6, offset: const Offset(0, 3))]
      ),
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20, fontFamily: 'Cairo'), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(title, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12, fontFamily: 'Cairo'), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildTopSellingProductsSection(ThemeData theme) {
    if (_isLoading && _topSellingProducts.isEmpty) { return const SizedBox.shrink(); }
    if (_topSellingProducts.isEmpty && !_isLoading) { return Padding(padding: const EdgeInsets.symmetric(vertical: 20.0), child: Center(child: Text('لا توجد بيانات لعرض المنتجات الأكثر مبيعاً.', style: TextStyle(fontFamily: 'Cairo', color: theme.disabledColor)))); }
    if (_topSellingProducts.isEmpty) { return const SizedBox.shrink(); }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 24.0, bottom: 12.0),
          child: Text("أكثر 3 منتجات مبيعاً (حسب الكمية)", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface, fontFamily: 'Cairo'), textAlign: TextAlign.right),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _topSellingProducts.length,
          itemBuilder: (context, index) {
            final productData = _topSellingProducts[index];
            final rank = index + 1;
            return Card(
              elevation: 1.5,
              margin: const EdgeInsets.symmetric(vertical: 5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: Colors.teal.withOpacity(0.8), child: Text('$rank', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo'))),
                title: Text(productData['productName'] as String, style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Cairo', color: theme.colorScheme.onSurface)),
                trailing: Text('الكمية: ${_numberFormatter.format(productData['quantitySold'] as int)}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 15, fontFamily: 'Cairo')),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildInvoiceListItem(Invoice invoice, int index, ThemeData theme) {
    Color currentStatusColor = paymentStatusColor(invoice.paymentStatus, theme);
    String currentStatusText = paymentStatusToString(invoice.paymentStatus);
    Color currentCardBg = theme.cardColor;
    Color currentText = theme.colorScheme.onSurface;
    Color currentSubText = theme.colorScheme.onSurfaceVariant;
    Color currentAmountColor = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
      decoration: BoxDecoration(color: currentCardBg, borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: () {
          if (invoice.id != null) { Navigator.of(context).push(MaterialPageRoute(builder: (context) => InvoiceDetailsScreen(invoiceId: invoice.id!, initialInvoice: invoice))); } 
          else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('خطأ: معرف الفاتورة غير متوفر.', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')))); }
        },
        borderRadius: BorderRadius.circular(10),
        child: Row(
          children: [
            CircleAvatar(radius: 20, backgroundColor: theme.colorScheme.primary.withOpacity(0.1), child: Icon(Icons.receipt_long_outlined, size: 20, color: theme.colorScheme.primary)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(invoice.clientName ?? invoice.invoiceNumber, style: TextStyle(fontWeight: FontWeight.bold, color: currentText, fontSize: 15, fontFamily: 'Cairo')),
                const SizedBox(height: 2),
                Text('المرجع: ${invoice.invoiceNumber}', style: TextStyle(color: currentSubText, fontSize: 12, fontFamily: 'Cairo')),
              ]),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_currencyFormatterWithDecimals.format(invoice.grandTotal), style: TextStyle(fontWeight: FontWeight.bold, color: currentAmountColor, fontSize: 15, fontFamily: 'Cairo')),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: currentStatusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: Text(currentStatusText, style: TextStyle(fontSize: 10, color: currentStatusColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

String paymentStatusToString(PaymentStatus status) {
  switch (status) {
    case PaymentStatus.paid: return 'مدفوعة';
    case PaymentStatus.partiallyPaid: return 'مدفوعة جزئياً';
    case PaymentStatus.unpaid: return 'غير مدفوعة';
    default: return 'غير معروف';
  }
}

Color paymentStatusColor(PaymentStatus status, ThemeData theme) {
  switch (status) {
    case PaymentStatus.paid: return Colors.green.shade600;
    case PaymentStatus.partiallyPaid: return Colors.orange.shade700;
    case PaymentStatus.unpaid: return theme.colorScheme.error;
    default: return theme.disabledColor;
  }
}
// // lib/screens/sales_report_screen.dart
// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import 'package:fouad_stock/model/invoice_model.dart';
// import 'package:fouad_stock/providers/invoice_provider.dart';
// import 'package:fouad_stock/providers/product_provider.dart';
// import 'package:fouad_stock/screens/invoice_details_screen.dart';
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
// import 'package:fl_chart/fl_chart.dart';
// import 'package:excel/excel.dart' as ex;
// import 'package:file_picker/file_picker.dart';
// import 'package:share_plus/share_plus.dart';
// import '../services/settings_service.dart';

// enum DateRangePreset { today, yesterday, last7Days, last30Days, thisMonth, custom }

// class SalesReportScreen extends StatefulWidget {
//   const SalesReportScreen({super.key});

//   @override
//   State<SalesReportScreen> createState() => _SalesReportScreenState();
// }

// class _SalesReportScreenState extends State<SalesReportScreen> {
//   DateTime _startDate = DateTime.now();
//   DateTime _endDate = DateTime.now();
//   DateRangePreset _selectedPreset = DateRangePreset.today;
//   List<Invoice> _salesInvoices = [];
//   Map<String, dynamic> _salesSummary = {'total': 0.0, 'count': 0};
//   bool _isLoading = false;
//   bool _isExporting = false;
//   List<FlSpot> _chartSpots = [];
//   double _chartMinX = 0, _chartMaxX = 0, _chartMinY = 0, _chartMaxY = 0;
//   List<String> _bottomTitles = [];
//   List<Map<String, dynamic>> _topSellingProducts = [];
  
//   double _totalProfit = 0.0;

//   final DateFormat _headerDateFormatter = DateFormat('d MMM', 'ar');
//   final DateFormat _listDateFormatter = DateFormat('yyyy/MM/dd', 'ar');
//   final NumberFormat _currencyFormatter = NumberFormat.currency(locale: 'ar', symbol: 'ج.م', decimalDigits: 0);
//   final NumberFormat _currencyFormatterWithDecimals = NumberFormat.currency(locale: 'ar', symbol: 'ج.م', decimalDigits: 2);
//   final NumberFormat _numberFormatter = NumberFormat.decimalPattern('ar');
//   final DateFormat _filenameTimestampFormatter = DateFormat('yyyyMMdd_HHmmss');
//   final SettingsService _settingsService = SettingsService();

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (mounted) { _setDateRange(DateRangePreset.today); }
//     });
//   }

//   void _setDateRange(DateRangePreset preset, {DateTime? customStart, DateTime? customEnd}) {
//     final now = DateTime.now(); DateTime newStart; DateTime newEnd;
//     switch (preset) {
//       case DateRangePreset.today: newStart = DateTime(now.year, now.month, now.day); newEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999); break;
//       case DateRangePreset.yesterday: final yesterday = now.subtract(const Duration(days: 1)); newStart = DateTime(yesterday.year, yesterday.month, yesterday.day); newEnd = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59, 999); break;
//       case DateRangePreset.last7Days: newEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999); newStart = newEnd.subtract(const Duration(days: 6)); newStart = DateTime(newStart.year, newStart.month, newStart.day); break;
//       case DateRangePreset.last30Days: newEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999); newStart = newEnd.subtract(const Duration(days: 29)); newStart = DateTime(newStart.year, newStart.month, newStart.day); break;
//       case DateRangePreset.thisMonth: newStart = DateTime(now.year, now.month, 1); newEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999); break;
//       case DateRangePreset.custom: newStart = customStart ?? DateTime(now.year, now.month, now.day); newEnd = customEnd ?? DateTime(now.year, now.month, now.day, 23, 59, 59, 999); if (newEnd.isBefore(newStart)) newEnd = newStart; newStart = DateTime(newStart.year, newStart.month, newStart.day); newEnd = DateTime(newEnd.year, newEnd.month, newEnd.day, 23, 59, 59, 999); break;
//     }
//     if (mounted) { setState(() { _startDate = newStart; _endDate = newEnd; _selectedPreset = preset; });}
//     _fetchReportData();
//   }

//   Future<void> _selectCustomDateRange(BuildContext context) async {
//     final initialDateRange = DateTimeRange(start: _startDate, end: _endDate);
//     final ThemeData currentTheme = Theme.of(context);
//     final newDateRange = await showDateRangePicker( context: context, initialDateRange: initialDateRange, firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 365)), locale: const Locale('ar'),
//       builder: (context, child) {
//         return Theme(
//           data: currentTheme.copyWith(
//               colorScheme: currentTheme.colorScheme.copyWith(
//                 primary: currentTheme.colorScheme.primary,
//                 onPrimary: Colors.white,
//                 surface: currentTheme.cardColor,
//                 onSurface: currentTheme.colorScheme.onSurface,
//               )
//           ),
//           child: child!
//         );
//       },
//     );
//     if (newDateRange != null) { _setDateRange(DateRangePreset.custom, customStart: newDateRange.start, customEnd: newDateRange.end); }
//   }

//   Future<void> _fetchReportData() async {
//     if (!mounted) return;
//     setState(() {
//       _isLoading = true;
//       _chartSpots = [];
//       _salesInvoices = [];
//       _topSellingProducts = [];
//       _totalProfit = 0.0;
//     });
//     final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
//     final productProvider = Provider.of<ProductProvider>(context, listen: false);
//     try {
//       final invoices = await invoiceProvider.getSalesInvoicesByDateRange(_startDate, _endDate);
//       double totalSales = 0;
//       double totalProfit = 0;
//       for (var inv in invoices) { 
//         totalSales += inv.grandTotal;
//         // --- FIX: Calculate totalProfit with fallback for old invoices ---
//         for (var item in inv.items) {
//           double cost = item.purchasePrice;
//           // If the stored purchase price is 0 (likely an old invoice),
//           // find the product's current purchase price as a fallback.
//           if (cost <= 0) {
//             final product = productProvider.getProductByIdFromCache(item.productId);
//             cost = product?.purchasePrice ?? 0.0;
//           }
//           totalProfit += (item.unitPrice - cost) * item.quantity;
//         }
//       }
//       if (mounted) {
//         setState(() {
//           _salesInvoices = invoices;
//           _salesSummary = {'total': totalSales, 'count': invoices.length};
//           _totalProfit = totalProfit;
//           _prepareChartData(invoices, _startDate, _endDate);
//           _calculateTopSellingProducts(invoices);
//         });
//       }
//     } catch (error) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.red.shade700, content: Text('خطأ جلب بيانات التقرير: $error', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo'))));
//         setState(() {
//           _salesInvoices = [];
//           _salesSummary = {'total': 0.0, 'count': 0};
//           _chartSpots = [];
//           _topSellingProducts = [];
//           _totalProfit = 0.0;
//         });
//       }
//     } finally {
//       if (mounted) { setState(() { _isLoading = false; });}
//     }
//   }

//   void _calculateTopSellingProducts(List<Invoice> invoices) {
//     if (invoices.isEmpty) {
//       if (mounted) setState(() => _topSellingProducts = []);
//       return;
//     }

//     Map<int, Map<String, dynamic>> productSales = {};

//     for (var invoice in invoices) {
//       for (var item in invoice.items) {
//         if (productSales.containsKey(item.productId)) {
//           productSales[item.productId]!['quantitySold'] += item.quantity;
//         } else {
//           productSales[item.productId] = {
//             'productId': item.productId,
//             'productName': item.productName,
//             'quantitySold': item.quantity,
//           };
//         }
//       }
//     }

//     List<Map<String, dynamic>> sortedProducts = productSales.values.toList();
//     sortedProducts.sort((a, b) => (b['quantitySold'] as int).compareTo(a['quantitySold'] as int));

//     if (mounted) {
//       setState(() {
//         _topSellingProducts = sortedProducts.take(3).toList();
//       });
//     }
//   }

//   void _prepareChartData(List<Invoice> invoices, DateTime reportStartDate, DateTime reportEndDate) {
//     if (invoices.isEmpty) { setState(() { _chartSpots = []; _chartMinX = 0; _chartMaxX = 0; _chartMinY = 0; _chartMaxY = 0; _bottomTitles = []; }); return;}
//     Map<int, double> dailyTotals = {}; int totalDaysInPeriod = reportEndDate.difference(reportStartDate).inDays + 1;
//     for (int i = 0; i < totalDaysInPeriod; i++) { dailyTotals[i] = 0.0; }
//     for (var invoice in invoices) { int dayIndex = invoice.date.difference(reportStartDate).inDays; if (dayIndex >= 0 && dayIndex < totalDaysInPeriod) { dailyTotals[dayIndex] = (dailyTotals[dayIndex] ?? 0) + invoice.grandTotal;}}
//     List<FlSpot> spots = []; List<String> bottomTitles = [];
//     DateFormat bottomTitleFormatter = DateFormat('E','ar');
//     if (totalDaysInPeriod == 1) bottomTitleFormatter = DateFormat('HH','ar');
//     else if (totalDaysInPeriod > 7 && totalDaysInPeriod <= 35) bottomTitleFormatter = DateFormat('d','ar');
//     else if (totalDaysInPeriod > 35) bottomTitleFormatter = DateFormat('dd/MM','ar');

//     double maxY = 0;
//     int labelInterval = (totalDaysInPeriod / 7).ceil();

//     for (int i = 0; i < totalDaysInPeriod; i++) {
//         spots.add(FlSpot(i.toDouble(), dailyTotals[i] ?? 0.0));
//         if ((dailyTotals[i] ?? 0.0) > maxY) maxY = dailyTotals[i] ?? 0.0;
//         DateTime currentDay = reportStartDate.add(Duration(days: i));
        
//         if (totalDaysInPeriod == 1) {
//             bottomTitles.add(bottomTitleFormatter.format(currentDay));
//         } else if (i == 0 || i == totalDaysInPeriod - 1 || (i % labelInterval == 0 && totalDaysInPeriod > 7) || (totalDaysInPeriod <=7) ) {
//              bottomTitles.add(bottomTitleFormatter.format(currentDay));
//         }
//         else {
//             bottomTitles.add('');
//         }
//     }
//     setState(() { _chartSpots = spots; _chartMinX = 0; _chartMaxX = (totalDaysInPeriod - 1).toDouble(); _chartMinY = 0; _chartMaxY = maxY == 0 ? 100 : maxY * 1.2; _bottomTitles = bottomTitles; });
//   }

//   String _getPresetButtonText(DateRangePreset preset) {
//     switch (preset) { case DateRangePreset.today: return 'اليوم'; case DateRangePreset.yesterday: return 'الأمس'; case DateRangePreset.last7Days: return '7 أيام'; case DateRangePreset.last30Days: return '30 يوم'; case DateRangePreset.thisMonth: return 'هذا الشهر'; default: return 'مخصص';}
//   }

//   Widget _buildDateFilter(ThemeData theme) {
//     List<DateRangePreset> presetsToShow = [DateRangePreset.today, DateRangePreset.last7Days, DateRangePreset.thisMonth, DateRangePreset.custom];
//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 8.0), height: 50,
//       child: ListView.separated( scrollDirection: Axis.horizontal, itemCount: presetsToShow.length, separatorBuilder: (context, index) => const SizedBox(width: 8),
//         itemBuilder: (context, index) {
//           final preset = presetsToShow[index]; final bool isSelected = _selectedPreset == preset;
//           Color chipBgColor = isSelected ? Colors.teal: theme.cardColor.withOpacity(0.5);
//           Color labelColor = isSelected ? Colors.white : theme.colorScheme.onSurface.withOpacity(0.7);
//           BorderSide borderSide = isSelected ? BorderSide.none : BorderSide(color: theme.dividerColor, width: 1.0);

//           if (preset == DateRangePreset.custom) {
//             return ActionChip( avatar: Icon(Icons.calendar_month_outlined, size: 18, color: labelColor), label: Text(isSelected ? '${_headerDateFormatter.format(_startDate)} - ${_headerDateFormatter.format(_endDate)}' : 'مخصص', overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Cairo')), onPressed: () => _selectCustomDateRange(context), backgroundColor: chipBgColor, labelStyle: TextStyle(color: labelColor, fontWeight: FontWeight.w500, fontSize: 13, fontFamily: 'Cairo'), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: borderSide), elevation: isSelected ? 2 : 0.5, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),);
//           }
//           return ChoiceChip(label: Text(_getPresetButtonText(preset), style: TextStyle(fontFamily: 'Cairo')), selected: isSelected, onSelected: (selected) { if (selected) _setDateRange(preset);}, backgroundColor: chipBgColor, selectedColor: chipBgColor, labelStyle: TextStyle(color: labelColor, fontWeight: FontWeight.w500, fontSize: 13, fontFamily: 'Cairo'), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: borderSide), elevation: isSelected ? 2 : 0.5, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),);
//         },),);
//   }

//   Widget _buildSalesChart(ThemeData theme) {
//     final List<Color> chartGradient = [theme.colorScheme.primary, theme.colorScheme.primary.withOpacity(0.6)];
//     final Color gridColor = theme.dividerColor;
//     final Color titleColor = theme.colorScheme.onSurfaceVariant;
//     final Color cardBg = theme.brightness == Brightness.dark ? theme.colorScheme.surface.withOpacity(0.05) : theme.cardColor;
//     final Color textColorOnCard = theme.colorScheme.onSurface;

//     return Container( padding: const EdgeInsets.fromLTRB(0, 16,0, 8), decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(theme.brightness == Brightness.dark ? 0.1 : 0.05), blurRadius: 8, offset: const Offset(0, 4))]),
//       child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
//           Padding(padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 12.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Text("إجمالي المبيعات", style: theme.textTheme.titleLarge?.copyWith(color: textColorOnCard, fontWeight: FontWeight.bold, fontFamily: 'Cairo')), ],),),
//           AspectRatio(aspectRatio: 2.0,
//             child: _chartSpots.isEmpty && !_isLoading ? Center(child: Text("لا توجد بيانات للرسم البياني", style: TextStyle(color: theme.disabledColor, fontFamily: 'Cairo')))
//                 : _isLoading && _chartSpots.isEmpty ? const Center(child: CircularProgressIndicator(strokeWidth: 2)) : Padding( padding: const EdgeInsets.only(right: 24.0, left: 8.0, top: 16, bottom: 0),
//                     child: LineChart(LineChartData(gridData: FlGridData(show: true, drawVerticalLine: true, horizontalInterval: _chartMaxY > 0 ? _chartMaxY / 3 : 25, verticalInterval: 1, getDrawingHorizontalLine: (value) => FlLine(color: gridColor.withOpacity(0.5), strokeWidth: 0.5), getDrawingVerticalLine: (value) => FlLine(color: gridColor.withOpacity(0.5), strokeWidth: 0.5),),
//                         titlesData: FlTitlesData(show: true, rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
//                           bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, interval: 1, getTitlesWidget: (value, meta) { final index = value.toInt(); if (index >= 0 && index < _bottomTitles.length && _bottomTitles[index].isNotEmpty) { return Padding(padding: const EdgeInsets.only(top: 6.0), child: Text(_bottomTitles[index], style: TextStyle(color: titleColor, fontWeight: FontWeight.normal, fontSize: 9, fontFamily: 'Cairo'))); } return const SizedBox.shrink();},),),
//                           leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 50, getTitlesWidget: (value, meta) { if (value == _chartMinY || value == _chartMaxY || (value > _chartMinY && value < _chartMaxY && meta.appliedInterval > 0 && value % meta.appliedInterval < 1 && (_chartMaxY - _chartMinY) / meta.appliedInterval <= 5 )) { return Padding(padding: const EdgeInsets.only(right:4.0), child: Text(_currencyFormatter.format(value), style: TextStyle(color: titleColor, fontWeight: FontWeight.normal, fontSize: 9, fontFamily: 'Cairo'), textAlign: TextAlign.right));} return const SizedBox.shrink();}, interval: _chartMaxY > 0 ? _chartMaxY / (_chartMaxY > 500 ? 3:2) : 25,),),),
//                         borderData: FlBorderData(show: false), minX: _chartMinX, maxX: _chartMaxX, minY: _chartMinY, maxY: _chartMaxY,
//                         lineBarsData: [ LineChartBarData(spots: _chartSpots, isCurved: true, gradient: LinearGradient(colors: chartGradient), barWidth: 2.5, isStrokeCapRound: true, dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: chartGradient.map((color) => color.withOpacity(0.3)).toList(), begin: Alignment.topCenter, end: Alignment.bottomCenter),),),],
//                         lineTouchData: LineTouchData(handleBuiltInTouches: true, touchTooltipData: LineTouchTooltipData(getTooltipColor: (touchedSpot) => cardBg.withOpacity(0.9), getTooltipItems: (List<LineBarSpot> touchedBarSpots) { return touchedBarSpots.map((barSpot) { final flSpot = barSpot; return LineTooltipItem('${_currencyFormatter.format(flSpot.y)}\n', TextStyle(color: textColorOnCard, fontWeight: FontWeight.bold, fontFamily: 'Cairo'), children: [ TextSpan(text: _bottomTitles.isNotEmpty && _bottomTitles.length > flSpot.x.toInt() && flSpot.x.toInt() >= 0 ? _bottomTitles[flSpot.x.toInt()] : '', style: TextStyle(color: titleColor, fontWeight: FontWeight.normal, fontSize: 10, fontFamily: 'Cairo')) ],);}).toList(); } ),),
//                     ),),),) ],),);
//   }

//   Widget _buildKpiCard(String title, String value, String secondaryValue, ThemeData theme) {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.teal,
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: [ BoxShadow( color: Colors.black.withOpacity(theme.brightness == Brightness.dark ? 0.2 : 0.1), blurRadius: 6, offset: const Offset(0,3)) ]
//       ),
//       padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         mainAxisAlignment: MainAxisAlignment.start,
//         children: [
//           Text(
//             value,
//             style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18, fontFamily: 'Cairo'),
//             maxLines: 1, overflow: TextOverflow.ellipsis,
//           ),
//           const SizedBox(height: 2),
//           Text(
//             title,
//             style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11, fontFamily: 'Cairo'),
//             maxLines: 1, overflow: TextOverflow.ellipsis,
//           ),
//           const Spacer(),
//           Align(
//             alignment: Alignment.bottomRight,
//             child: Text(
//               secondaryValue,
//               style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
//             ),
//           )
//         ],
//       ),
//     );
//   }

//   Widget _buildTopSellingProductsSection(ThemeData theme) {
//     if (_isLoading && _topSellingProducts.isEmpty) {
//       return const SizedBox.shrink();
//     }
//     if (_topSellingProducts.isEmpty && !_isLoading) {
//       return Padding(
//         padding: const EdgeInsets.symmetric(vertical: 20.0),
//         child: Center(child: Text('لا توجد بيانات لعرض المنتجات الأكثر مبيعاً.', style: TextStyle(fontFamily: 'Cairo', color: theme.disabledColor))),
//       );
//     }
//      if (_topSellingProducts.isEmpty) {
//       return const SizedBox.shrink();
//     }

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Padding(
//           padding: const EdgeInsets.only(top: 24.0, bottom: 12.0),
//           child: Text(
//             "أكثر 3 منتجات مبيعاً (حسب الكمية)",
//             style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface, fontFamily: 'Cairo'),
//             textAlign: TextAlign.right,
//           ),
//         ),
//         ListView.builder(
//           shrinkWrap: true,
//           physics: const NeverScrollableScrollPhysics(),
//           itemCount: _topSellingProducts.length,
//           itemBuilder: (context, index) {
//             final productData = _topSellingProducts[index];
//             final rank = index + 1;
//             return Card(
//               elevation: 1.5,
//               margin: const EdgeInsets.symmetric(vertical: 5),
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//               child: ListTile(
//                 leading: CircleAvatar(
//                   backgroundColor: Colors.teal.withOpacity(0.8),
//                   child: Text('$rank', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
//                 ),
//                 title: Text(productData['productName'] as String, style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Cairo', color: theme.colorScheme.onSurface)),
//                 trailing: Text(
//                   'الكمية: ${_numberFormatter.format(productData['quantitySold'] as int)}',
//                   style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 15, fontFamily: 'Cairo'),
//                 ),
//               ),
//             );
//           },
//         ),
//       ],
//     );
//   }

//   Widget _buildInvoiceListItem(Invoice invoice, int index, ThemeData theme) {
//     Color currentStatusColor = paymentStatusColor(invoice.paymentStatus, theme);
//     String currentStatusText = paymentStatusToString(invoice.paymentStatus);
//     Color currentCardBg = theme.cardColor;
//     Color currentText = theme.colorScheme.onSurface;
//     Color currentSubText = theme.colorScheme.onSurfaceVariant;
//     Color currentAmountColor = theme.colorScheme.primary;

//     return Container( padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0), decoration: BoxDecoration(color: currentCardBg, borderRadius: BorderRadius.circular(10)),
//       child: InkWell(
//         onTap: () { if (invoice.id != null) { Navigator.of(context).push(MaterialPageRoute(builder: (context) => InvoiceDetailsScreen(invoiceId: invoice.id!, initialInvoice: invoice)));} else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('خطأ: معرف الفاتورة غير متوفر.', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo'))));}},
//         borderRadius: BorderRadius.circular(10),
//         child: Row(children: [
//             CircleAvatar(radius: 20, backgroundColor: theme.colorScheme.primary.withOpacity(0.1), child: Icon(Icons.receipt_long_outlined, size: 20, color: theme.colorScheme.primary),),
//             const SizedBox(width: 12),
//             Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(invoice.clientName ?? invoice.invoiceNumber, style: TextStyle(fontWeight: FontWeight.bold, color: currentText, fontSize: 15, fontFamily: 'Cairo')), const SizedBox(height: 2), Text('المرجع: ${invoice.invoiceNumber}', style: TextStyle(color: currentSubText, fontSize: 12, fontFamily: 'Cairo')), ],),),
//             const SizedBox(width: 8),
//             Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
//                 Text(_currencyFormatterWithDecimals.format(invoice.grandTotal), style: TextStyle(fontWeight: FontWeight.bold, color: currentAmountColor, fontSize: 15, fontFamily: 'Cairo')),
//                 const SizedBox(height: 4),
//                 Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: currentStatusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12),),
//                   child: Text(currentStatusText, style: TextStyle(fontSize: 10, color: currentStatusColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),),
//                 ),
//               ],),
//           ],),
//       ),);
//   }

//   Future<void> _exportSalesReportToExcel() async {
//     if (_salesInvoices.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد بيانات للتصدير!', style: TextStyle(fontFamily: 'Cairo'))));
//       return;
//     }

//     setState(() => _isExporting = true);

//     try {
//       final productProvider = Provider.of<ProductProvider>(context, listen: false);
//       final String storeName = await _settingsService.getStoreName();
//       var excel = ex.Excel.createExcel();
//       ex.Sheet sheetObject = excel['Sales Report'];

//       // Styles
//       ex.CellStyle titleStyle = ex.CellStyle(bold: true, fontSize: 16, horizontalAlign: ex.HorizontalAlign.Right);
//       ex.CellStyle dateStyle = ex.CellStyle(fontSize: 12, horizontalAlign: ex.HorizontalAlign.Right);
//       ex.CellStyle headerStyle = ex.CellStyle(bold: true, backgroundColorHex: ex.ExcelColor.fromHexString('#DDEBF7'), horizontalAlign: ex.HorizontalAlign.Center, verticalAlign: ex.VerticalAlign.Center);
//       ex.CellStyle defaultStyle = ex.CellStyle(horizontalAlign: ex.HorizontalAlign.Right);
//       ex.CellStyle currencyStyle = ex.CellStyle(horizontalAlign: ex.HorizontalAlign.Right);
//       ex.CellStyle totalStyle = ex.CellStyle(bold: true, backgroundColorHex: ex.ExcelColor.fromHexString('#F2F2F2'));
//       ex.CellStyle totalCurrencyStyle = totalStyle.copyWith(horizontalAlignVal: ex.HorizontalAlign.Right);

//       // Report Header
//       sheetObject.merge(ex.CellIndex.indexByString("A1"), ex.CellIndex.indexByString("H1"));
//       sheetObject.cell(ex.CellIndex.indexByString("A1")).value = ex.TextCellValue("تقرير المبيعات لـ: $storeName");
//       sheetObject.cell(ex.CellIndex.indexByString("A1")).cellStyle = titleStyle;

//       sheetObject.merge(ex.CellIndex.indexByString("A2"), ex.CellIndex.indexByString("H2"));
//       sheetObject.cell(ex.CellIndex.indexByString("A2")).value = ex.TextCellValue("الفترة من: ${_listDateFormatter.format(_startDate)} إلى: ${_listDateFormatter.format(_endDate)}");
//       sheetObject.cell(ex.CellIndex.indexByString("A2")).cellStyle = dateStyle;
      
//       sheetObject.appendRow([]); // Spacer

//       // Summary
//       sheetObject.appendRow([ex.TextCellValue('إجمالي المبيعات'), ex.DoubleCellValue(_salesSummary['total']), ex.TextCellValue('إجمالي الربح'), ex.DoubleCellValue(_totalProfit), ex.TextCellValue('عدد الفواتير'), ex.IntCellValue(_salesSummary['count'])]);
//       int summaryRow = 3; // Adjusted index
//       sheetObject.cell(ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: summaryRow)).cellStyle = totalStyle;
//       sheetObject.cell(ex.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: summaryRow)).cellStyle = totalCurrencyStyle;
//       sheetObject.cell(ex.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: summaryRow)).cellStyle = totalStyle;
//       sheetObject.cell(ex.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: summaryRow)).cellStyle = totalCurrencyStyle;
//       sheetObject.cell(ex.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: summaryRow)).cellStyle = totalStyle;
//       sheetObject.cell(ex.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: summaryRow)).cellStyle = totalStyle;
      
//       sheetObject.appendRow([]); // Spacer

//       // Headers for detailed list
//       List<ex.CellValue> headers = [
//         ex.TextCellValue('رقم الفاتورة'), ex.TextCellValue('تاريخ الفاتورة'), ex.TextCellValue('اسم المنتج'), ex.TextCellValue('الصنف'), ex.TextCellValue('الكمية'), ex.TextCellValue('سعر البيع'), ex.TextCellValue('ربح الوحدة'), ex.TextCellValue('إجمالي الربح')
//       ];
//       sheetObject.appendRow(headers);
//       int headerRow = 5; // Adjusted index
//       for (var i = 0; i < headers.length; i++) {
//         sheetObject.cell(ex.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: headerRow)).cellStyle = headerStyle;
//       }

//       // Data rows
//       for (var invoice in _salesInvoices) {
//         for (var item in invoice.items) {
//           final product = productProvider.getProductByIdFromCache(item.productId);
//           double cost = item.purchasePrice;
//           if (cost <= 0) {
//             cost = product?.purchasePrice ?? 0.0;
//           }
//           double profitPerUnit = item.unitPrice - cost;
//           double totalProfitForItem = profitPerUnit * item.quantity;
//           List<ex.CellValue> rowData = [
//             ex.TextCellValue(invoice.invoiceNumber),
//             ex.DateCellValue(year: invoice.date.year, month: invoice.date.month, day: invoice.date.day),
//             ex.TextCellValue(item.productName),
//             ex.TextCellValue(product?.category ?? 'غير معروف'), // Get category from product
//             ex.IntCellValue(item.quantity),
//             ex.DoubleCellValue(item.unitPrice),
//             ex.DoubleCellValue(profitPerUnit),
//             ex.DoubleCellValue(totalProfitForItem)
//           ];
//           sheetObject.appendRow(rowData);
//         }
//       }

//       // Auto-fit columns
//       for (var i = 0; i < headers.length; i++) {
//         sheetObject.setColumnAutoFit(i);
//       }

//       var fileBytes = excel.encode();
//       if (fileBytes != null) {
//         String timestamp = _filenameTimestampFormatter.format(DateTime.now());
//         String suggestedFileName = "SalesReport_${timestamp}.xlsx";

//         String? savedFilePath = await FilePicker.platform.saveFile(
//           dialogTitle: 'اختر مكان حفظ التقرير:',
//           fileName: suggestedFileName,
//           bytes: Uint8List.fromList(fileBytes),
//           type: FileType.custom,
//           allowedExtensions: ['xlsx'],
//         );

//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text('تم حفظ التقرير بنجاح!', style: TextStyle(fontFamily: 'Cairo')),
//               action: SnackBarAction(label: 'مشاركة', onPressed: () async {
//                 await Share.shareXFiles([XFile(savedFilePath!)], text: 'تقرير المبيعات');
//               }),
//             ),
//           );
//         }
//       }
//     } catch (e) {
//       print("Export Error: $e");
//       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل تصدير التقرير: $e', style: TextStyle(fontFamily: 'Cairo'))));
//     } finally {
//       if (mounted) setState(() => _isExporting = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final ThemeData theme = Theme.of(context);
//     double avgSale = (_salesSummary['count'] ?? 0) > 0 ? (_salesSummary['total'] ?? 0.0) / (_salesSummary['count'] == 0 ? 1 :_salesSummary['count']) : 0.0;

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('تقرير المبيعات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
//         backgroundColor: Colors.teal.shade900,
//         elevation: 1,
//         iconTheme: const IconThemeData(color: Colors.white),
//         actions: [
//           IconButton(
//             icon: _isExporting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0)) : const Icon(Icons.share_outlined),
//             tooltip: 'تصدير إلى Excel',
//             onPressed: _isExporting ? null : _exportSalesReportToExcel,
//           ),
//           IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'تحديث', onPressed: _isLoading ? null : _fetchReportData),
//         ],
//       ),
//       body: Column( crossAxisAlignment: CrossAxisAlignment.stretch, children: [
//           Padding( padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0), child: _buildDateFilter(theme),),
//           Expanded(
//             child: _isLoading && _chartSpots.isEmpty && _salesInvoices.isEmpty && _topSellingProducts.isEmpty
//                 ? const Center(child: CircularProgressIndicator())
//                 : SingleChildScrollView( padding: const EdgeInsets.all(16.0),
//                     child: Column( crossAxisAlignment: CrossAxisAlignment.stretch, children: [
//                         _buildSalesChart(theme),
//                         const SizedBox(height: 20),
//                         GridView.count(
//                           shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
//                           crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12,
//                           childAspectRatio:1,
//                           children: [
//                               _buildKpiCard('إجمالي المبيعات', _currencyFormatter.format(_salesSummary['total'] ?? 0.0), '${_numberFormatter.format(_salesSummary['count'] ?? 0)} فاتورة', theme),
//                               _buildKpiCard('إجمالي الأرباح', _currencyFormatter.format(_totalProfit), 'صافي الربح', theme),
//                               _buildKpiCard('متوسط الفاتورة', _currencyFormatter.format(avgSale), 'لكل عملية بيع', theme),
//                             ],
//                         ),
//                         _buildTopSellingProductsSection(theme),
//                         const SizedBox(height: 24),
//                         Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
//                             Text("الفواتير", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface, fontFamily: 'Cairo')),
//                           ],),
//                         const SizedBox(height: 12),
//                         if (_isLoading && _salesInvoices.isEmpty)
//                           const Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text("جاري تحميل الفواتير...", style: TextStyle(fontFamily: 'Cairo'))))
//                         else if (_salesInvoices.isEmpty)
//                           Padding( padding: const EdgeInsets.symmetric(vertical: 40.0), child: Column(children: [
//                               Icon(Icons.inbox_outlined, size: 50, color: theme.disabledColor),
//                               const SizedBox(height: 16),
//                               Text('لا توجد فواتير لهذه الفترة', style: theme.textTheme.titleMedium?.copyWith(color: theme.disabledColor, fontFamily: 'Cairo')),
//                             ],),)
//                         else
//                           ListView.separated(
//                             shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
//                             itemCount: _salesInvoices.length,
//                             separatorBuilder: (context, index) => const SizedBox(height: 10),
//                             itemBuilder: (context, index) {
//                               final invoice = _salesInvoices[index];
//                               return _buildInvoiceListItem(invoice, index, theme);
//                             },
//                           ),
//                       ],),),),
//         ],),);
//   }
// }

// String paymentStatusToString(PaymentStatus status) {
//   switch (status) {
//     case PaymentStatus.paid: return 'مدفوعة';
//     case PaymentStatus.partiallyPaid: return 'مدفوعة جزئياً';
//     case PaymentStatus.unpaid: return 'غير مدفوعة';
//     default: return 'غير معروف';
//   }
// }

// Color paymentStatusColor(PaymentStatus status, ThemeData theme) {
//   switch (status) {
//     case PaymentStatus.paid: return Colors.green.shade600;
//     case PaymentStatus.partiallyPaid: return Colors.orange.shade700;
//     case PaymentStatus.unpaid: return theme.colorScheme.error;
//     default: return theme.disabledColor;
//   }
// }
