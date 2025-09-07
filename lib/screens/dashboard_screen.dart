// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:fouad_stock/enum/filter_enums.dart';
import 'package:fouad_stock/screens/inventory_report_screen.dart';
import 'package:provider/provider.dart';
import 'package:fouad_stock/providers/product_provider.dart';
import 'package:fouad_stock/providers/invoice_provider.dart';
import 'package:fouad_stock/screens/new_sale_invoice_screen.dart';
import 'package:fouad_stock/screens/new_purchase_invoice_screen.dart';
import 'package:fouad_stock/screens/product_list_screen.dart';
import 'package:fouad_stock/screens/invoices_list_screen.dart';
import 'package:fouad_stock/screens/price_quote_screen.dart';
import 'package:fouad_stock/screens/sales_report_screen.dart';
import 'package:intl/intl.dart';

// Define colors
const Color kpiCardColor1 = Color(0xFF3B76F6); // Blue
const Color kpiCardColor2 = Color(0xFF8A5CF3); // Purple
const Color kpiCardColor3 = Color(0xFFF2994A); // Orange
const Color kpiCardColor4 = Color(0xFF4FD1C5); // Teal/Greenish
const Color kpiCardColor5 = Color(0xFFD64D4D); // Red for Debts
const Color kpiCardColor6 = Color(0xFF56CCF2); // Light Blue

const Color darkDashboardBackground = Color(0xFF1A1D21);
const Color darkCardBackground = Color(0xFF252A30);
const Color darkTextColor = Color(0xFFEAEAEA);
const Color darkSecondaryTextColor = Color(0xFFA0AEC0);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;

  double _todaySalesTotal = 0.0;
  int _todaySalesCount = 0;
  double _todayPurchasesTotal = 0.0;
  int _todayPurchasesCount = 0;
  double _totalUnpaidAmount = 0.0;
  double _totalUnpaidPurchasesAmount = 0.0;

  final NumberFormat _currencyFormatter = NumberFormat.currency(locale: 'ar', symbol: 'ج.م', decimalDigits: 2);
  final NumberFormat _numberFormatter = NumberFormat.decimalPattern('ar');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchDashboardData();
      }
    });
  }

  Future<void> _fetchDashboardData() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });

    try {
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);

      await Future.wait([
          productProvider.fetchProducts(filter: ProductListFilter.none),
          invoiceProvider.fetchInvoices(filter: InvoiceListFilter.none)
      ]);

      final salesSummary = await invoiceProvider.getTodaysSalesSummary();
      final purchasesSummary = await invoiceProvider.getTodaysPurchasesSummary();
      final double unpaidAmount = await invoiceProvider.getTotalUnpaidSalesAmount();
      final double unpaidPurchases = await invoiceProvider.getTotalUnpaidPurchasesAmount();

      if (mounted) {
        setState(() {
          _todaySalesTotal = (salesSummary['total'] as num?)?.toDouble() ?? 0.0;
          _todaySalesCount = (salesSummary['count'] as int?) ?? 0;
          _todayPurchasesTotal = (purchasesSummary['total'] as num?)?.toDouble() ?? 0.0;
          _todayPurchasesCount = (purchasesSummary['count'] as int?) ?? 0;
          _totalUnpaidAmount = unpaidAmount;
          _totalUnpaidPurchasesAmount = unpaidPurchases;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red.shade700, content: Text('خطأ تحميل بيانات لوحة التحكم: $error', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo'))),
        );
      }
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData currentTheme = Theme.of(context);
    final bool isActuallyDarkMode = currentTheme.brightness == Brightness.dark;

    final Color screenBgColor = isActuallyDarkMode ? currentTheme.scaffoldBackgroundColor : darkDashboardBackground;
    final Color defaultCardBgColor = isActuallyDarkMode ? currentTheme.cardColor : darkCardBackground;
    final Color mainTextColor = isActuallyDarkMode ? currentTheme.textTheme.bodyLarge?.color ?? darkTextColor : darkTextColor;
    final Color secondaryTextColor = isActuallyDarkMode ? currentTheme.textTheme.bodyMedium?.color ?? darkSecondaryTextColor : darkSecondaryTextColor;
    final Color appBarActualTextColor = currentTheme.appBarTheme.titleTextStyle?.color ?? mainTextColor;

    return Theme(
      data: currentTheme.copyWith(
        scaffoldBackgroundColor: screenBgColor,
        brightness: Brightness.dark, 
        cardColor: defaultCardBgColor,
        textTheme: currentTheme.textTheme.apply(fontFamily: 'Cairo', bodyColor: mainTextColor, displayColor: mainTextColor)
          .copyWith(
            titleLarge: currentTheme.textTheme.titleLarge?.copyWith(color: mainTextColor, fontFamily: 'Cairo'),
            titleMedium: currentTheme.textTheme.titleMedium?.copyWith(color: mainTextColor, fontFamily: 'Cairo'),
            bodyMedium: currentTheme.textTheme.bodyMedium?.copyWith(color: secondaryTextColor, fontFamily: 'Cairo'),
            labelLarge: currentTheme.textTheme.labelLarge?.copyWith(color: mainTextColor, fontFamily: 'Cairo')
          ),
        appBarTheme: currentTheme.appBarTheme.copyWith(
          backgroundColor: screenBgColor, 
          elevation: 0, 
          titleTextStyle: TextStyle(color: appBarActualTextColor, fontSize: 20, fontWeight: FontWeight.w600, fontFamily: 'Cairo'),
          iconTheme: IconThemeData(color: appBarActualTextColor),
        ),
        iconTheme: currentTheme.iconTheme.copyWith(color: mainTextColor),
        dividerColor: Colors.white12,
        splashColor: kpiCardColor1.withOpacity(0.1),
        highlightColor: kpiCardColor1.withOpacity(0.05),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('لوحة التحكم'),
          actions: [
            IconButton(icon: const Icon(Icons.refresh_outlined), tooltip: 'تحديث البيانات', onPressed: _isLoading ? null : _fetchDashboardData),
          ],
        ),
        body: Builder(
          builder: (context) {
            final productProvider = context.watch<ProductProvider>(); 

            return _isLoading 
                ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(kpiCardColor1)))
                : RefreshIndicator(
                    onRefresh: _fetchDashboardData,
                    color: kpiCardColor1,
                    backgroundColor: Theme.of(context).cardColor,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 18.0),
                      children: <Widget>[
                        _buildKpiSection(context), 
                        const SizedBox(height: 28),
                        _buildSectionTitle(context, 'نظرة عامة على المخزون'), 
                        _buildInventoryMetricsGrid(context, productProvider, Theme.of(context).cardColor),
                        const SizedBox(height: 28),
                        _buildSectionTitle(context, 'إجراءات سريعة'), 
                        _buildQuickActions(context), 
                        const SizedBox(height: 20),
                      ],
                    ),
                  );
          }
        )
      ),
    );
  }

  Widget _buildKpiSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('المؤشرات الرئيسية', textAlign: TextAlign.right, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            // --- MODIFIED: Adjust grid for 5 items ---
            int crossAxisCount = constraints.maxWidth > 1200 ? 5 : (constraints.maxWidth > 650 ? 3 : 2);
            double childAspectRatio = constraints.maxWidth > 1200 ? 1.2 : (constraints.maxWidth > 650 ? 1.3 : 1.5);
            
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12.0, mainAxisSpacing: 12.0,
              childAspectRatio: childAspectRatio,
              children: <Widget>[
                _buildKpiCard(context: context, title: 'مبيعات اليوم', value: _currencyFormatter.format(_todaySalesTotal), icon: Icons.trending_up_rounded, backgroundColor: kpiCardColor1,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => InvoicesListScreen(filter: InvoiceListFilter.todaySales, appBarTitle: 'فواتير مبيعات اليوم')))),
                _buildKpiCard(context: context, title: 'مشتريات اليوم', value: _currencyFormatter.format(_todayPurchasesTotal), icon: Icons.shopping_cart_checkout_rounded, backgroundColor: kpiCardColor2,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => InvoicesListScreen(filter: InvoiceListFilter.todayPurchases, appBarTitle: 'فواتير مشتريات اليوم')))),
                _buildKpiCard(context: context, title: 'المبالغ المستحقة', value: _currencyFormatter.format(_totalUnpaidAmount), icon: Icons.account_balance_wallet_outlined, backgroundColor: kpiCardColor3,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => InvoicesListScreen(filter: InvoiceListFilter.unpaidSales, appBarTitle: 'الفواتير المستحقة (غير مدفوعة)')))),
                _buildKpiCard(context: context, title: 'مديونياتي', value: _currencyFormatter.format(_totalUnpaidPurchasesAmount), icon: Icons.upload_file_rounded, backgroundColor: kpiCardColor5,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => InvoicesListScreen(filter: InvoiceListFilter.unpaidPurchases, appBarTitle: 'فواتير شراء غير مدفوعة')))),
                // --- FIXED: Added the missing card back ---
                _buildKpiCard(context: context, title: 'فواتير بيع اليوم', value: _numberFormatter.format(_todaySalesCount), icon: Icons.receipt_long_outlined, backgroundColor: kpiCardColor4,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => InvoicesListScreen(filter: InvoiceListFilter.todaySales, appBarTitle: 'فواتير مبيعات اليوم')))),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildKpiCard({ required BuildContext context, required String title, required String value, required IconData icon, required Color backgroundColor, VoidCallback? onTap}) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(16.0),
      child: Container(
        decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(16.0), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), spreadRadius: 1, blurRadius: 8, offset: const Offset(0, 4))]),
        padding: const EdgeInsets.all(16.0),
        child: Column( crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 28, color: Colors.white.withOpacity(0.9)),
                Expanded(child: Text(title, textAlign: TextAlign.right, style: textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 15) ?? TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500, fontFamily: 'Cairo'), overflow: TextOverflow.ellipsis, maxLines: 2)),
              ],
            ),
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: Text(value, textAlign: TextAlign.right, style: textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 26) ?? TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, fontFamily: 'Cairo'), overflow: TextOverflow.ellipsis, maxLines: 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 16.0, right: 4.0),
      child: Text(title, textAlign: TextAlign.right, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 20)),
    );
  }
  
  Widget _buildInventoryMetricsGrid(BuildContext context, ProductProvider productProvider, Color cardBgColor) {
    final List<Widget> cards = [
      _buildSummaryCard(context: context, title: 'إجمالي المنتجات', value: _numberFormatter.format(productProvider.totalProductsCount), icon: Icons.inventory_2_outlined, cardColor: cardBgColor, valueColor: kpiCardColor6,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProductsListScreen(appBarTitle: 'كل المنتجات', filter: ProductListFilter.none))),
      ),
      _buildSummaryCard(context: context, title: 'نقص في المخزون', value: _numberFormatter.format(productProvider.lowStockProductsCount), icon: Icons.warning_amber_rounded, cardColor: cardBgColor, valueColor: kpiCardColor3,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProductsListScreen(filter: ProductListFilter.lowStock, appBarTitle: 'منتجات على وشك النفاذ'))),
      ),
      _buildSummaryCard(context: context, title: 'نفذ من المخزون', value: _numberFormatter.format(productProvider.outOfStockProductsCount), icon: Icons.production_quantity_limits_rounded, cardColor: cardBgColor, valueColor: const Color(0xFFEB5757),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProductsListScreen(filter: ProductListFilter.outOfStock, appBarTitle: 'منتجات نفذت كميتها'))),
      ),
      _buildSummaryCard(context: context, title: 'منتجات منتهية الصلاحية', value: _numberFormatter.format(productProvider.expiredProductsCount), icon: Icons.event_busy_outlined, cardColor: cardBgColor, valueColor: Colors.red.shade400,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProductsListScreen(filter: ProductListFilter.expired, appBarTitle: 'منتجات منتهية الصلاحية'))),
      ),
      _buildSummaryCard(context: context, title: 'قارب انتهاء صلاحيتها', value: _numberFormatter.format(productProvider.nearingExpiryProductsCount), icon: Icons.history_toggle_off_outlined, cardColor: cardBgColor, valueColor: Colors.amber.shade400,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProductsListScreen(filter: ProductListFilter.nearingExpiry, appBarTitle: 'منتجات قارب انتهاء صلاحيتها'))),
      ),
    ];
    
    if (productProvider.isLoading && productProvider.products.isEmpty && productProvider.currentFilter == ProductListFilter.none) {
          cards.add(_buildSummaryCard(context: context, title: 'تحميل المخزون...', value: "...", icon: Icons.hourglass_empty, cardColor: cardBgColor, valueColor: darkSecondaryTextColor));
    }
    return GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
        crossAxisSpacing: 12.0, mainAxisSpacing: 12.0, childAspectRatio: 1.45,
      ),
      itemBuilder: (context, index) => cards[index],
    );
  }

  Widget _buildSummaryCard({required BuildContext context, required String title, required String value, required IconData icon, required Color cardColor, required Color valueColor, VoidCallback? onTap}) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12.0), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), spreadRadius: 0, blurRadius: 6, offset: const Offset(0, 3))]),
      child: InkWell( onTap: onTap, borderRadius: BorderRadius.circular(12.0),
        child: Padding( padding: const EdgeInsets.symmetric(horizontal:12, vertical: 16.0),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Row(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(title, textAlign: TextAlign.right, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500, fontSize: 15) ?? TextStyle(fontSize: 15, fontWeight: FontWeight.w500, fontFamily: 'Cairo'), maxLines: 2, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    Icon(icon, size: 22, color: valueColor.withOpacity(0.8)),
                  ],
                ),
                const SizedBox(height: 8), 
                FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: Text(value, textAlign: TextAlign.right, style: textTheme.titleMedium?.copyWith(color: valueColor, fontWeight: FontWeight.bold, fontSize: 20) ?? TextStyle(color: valueColor, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Cairo'), maxLines: 1)),
              ],
            ),
          ),
      ),
    );
  }

  Widget _buildQuickActionCard({ required BuildContext context, required IconData icon, required String label, required VoidCallback onPressed, Color? iconColor }) {
    final theme = Theme.of(context);
    final cardBackgroundColor = theme.cardColor; 
    final textColor = theme.textTheme.labelLarge?.color ?? (isDarkMode(context) ? darkTextColor : Colors.black87);
    final effectiveIconColor = iconColor ?? kpiCardColor6.withOpacity(0.9);

    return Card(
      elevation: 3.0, color: cardBackgroundColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: InkWell( onTap: onPressed, borderRadius: BorderRadius.circular(12.0),
        child: Padding( padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 12.0),
          child: Column( mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: effectiveIconColor),
              const SizedBox(height: 12),
              Text( label, textAlign: TextAlign.center,
                style: TextStyle( color: textColor, fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Cairo'),
                overflow: TextOverflow.ellipsis, maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool isDarkMode(BuildContext context) {
      return Theme.of(context).brightness == Brightness.dark;
  }

  Widget _buildQuickActions(BuildContext context) {
    final List<Map<String, dynamic>> actions = [
      { 'label': 'فاتورة بيع جديدة', 'icon': Icons.receipt_long_outlined, 'onPressed': () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewSaleInvoiceScreen())).then((_) { if (mounted) _fetchDashboardData(); }), 'iconColor': kpiCardColor1, },
      { 'label': 'فاتورة شراء جديدة', 'icon': Icons.add_shopping_cart_outlined, 'onPressed': () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewPurchaseInvoiceScreen())).then((_) { if (mounted) _fetchDashboardData(); }), 'iconColor': kpiCardColor2, },
      { 'label': 'إنشاء عرض سعر', 'icon': Icons.request_quote_outlined, 'onPressed': () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PriceQuoteScreen())), 'iconColor': Colors.lightGreen.shade400, },
      { 'label': 'عرض كل المنتجات', 'icon': Icons.inventory_2_outlined, 'onPressed': () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductsListScreen(filter: ProductListFilter.none, appBarTitle: 'كل المنتجات'))).then((_) { if (mounted) _fetchDashboardData(); }), 'iconColor': kpiCardColor6, },
      { 'label': 'عرض كل الفواتير', 'icon': Icons.article_outlined, 'onPressed': () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => InvoicesListScreen(filter: InvoiceListFilter.none, appBarTitle: 'كل الفواتير'))).then((_) { if (mounted) _fetchDashboardData(); }), 'iconColor': kpiCardColor4, },
      { 'label': 'تقرير المبيعات', 'icon': Icons.assessment_outlined, 'onPressed': () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SalesReportScreen())).then((_) { if (mounted) _fetchDashboardData(); }), 'iconColor': kpiCardColor3, },
      { 'label': 'تقرير المخزون', 'icon': Icons.inventory, 'onPressed': () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InventoryReportScreen())), 'iconColor': Colors.blueGrey.shade300,},
    ];

    return GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: actions.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 450 ? 3 : 2,
        crossAxisSpacing: 12.0, mainAxisSpacing: 12.0, childAspectRatio: 1.1,
      ),
      itemBuilder: (context, index) {
        final action = actions[index];
        return _buildQuickActionCard(
          context: context, icon: action['icon'] as IconData, label: action['label'] as String,
          onPressed: action['onPressed'] as VoidCallback, iconColor: action['iconColor'] as Color?, 
        );
      },
    );
  }
}

