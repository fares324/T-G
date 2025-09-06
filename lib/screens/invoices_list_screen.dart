// lib/screens/invoices_list_screen.dart
import 'package:flutter/material.dart';
import 'package:fouad_stock/enum/filter_enums.dart';
import 'package:fouad_stock/model/invoice_model.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/invoice_provider.dart';
import 'new_sale_invoice_screen.dart';
import 'invoice_details_screen.dart';
import 'new_purchase_invoice_screen.dart';

class InvoicesListScreen extends StatefulWidget {
  final InvoiceListFilter? filter;
  final String? appBarTitle;

  const InvoicesListScreen({
    super.key,
    this.filter,
    this.appBarTitle,
  });

  @override
  State<InvoicesListScreen> createState() => _InvoicesListScreenState();
}

class _InvoicesListScreenState extends State<InvoicesListScreen> {
  late DateFormat _arabicDateFormat;
  String _effectiveAppBarTitle = 'قائمة الفواتير';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _arabicDateFormat = DateFormat.yMMMd('ar');
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateTitleAndFetch();
        _searchController.addListener(() {
          Provider.of<InvoiceProvider>(context, listen: false).searchInvoices(_searchController.text);
        });
    });
  }
  
  @override
  void dispose() {
    // Clear search query in provider when screen is disposed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Check if the widget is still in the tree before accessing the provider
      if(mounted) {
         Provider.of<InvoiceProvider>(context, listen: false).searchInvoices('');
      }
    });
    _searchController.dispose();
    super.dispose();
  }

  void _updateTitleAndFetch() {
    if (widget.appBarTitle != null && widget.appBarTitle!.isNotEmpty) {
      _effectiveAppBarTitle = widget.appBarTitle!;
    } else {
      switch (widget.filter) {
        case InvoiceListFilter.todaySales:
          _effectiveAppBarTitle = 'فواتير مبيعات اليوم';
          break;
        case InvoiceListFilter.todayPurchases:
          _effectiveAppBarTitle = 'فواتير مشتريات اليوم';
          break;
        case InvoiceListFilter.unpaidSales:
          _effectiveAppBarTitle = 'فواتير مبيعات غير مدفوعة';
          break;
        default:
          _effectiveAppBarTitle = 'كل الفواتير';
      }
    }
    _refreshInvoices();
  }

  Future<void> _refreshInvoices() async {
    _searchController.clear();
    await Provider.of<InvoiceProvider>(context, listen: false).fetchInvoices(filter: widget.filter);
  }

  void _navigateToNewSaleInvoiceScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const NewSaleInvoiceScreen()),
    ).then((_) {
      _refreshInvoices();
    });
  }

  void _navigateToNewPurchaseInvoiceScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const NewPurchaseInvoiceScreen()),
    ).then((_) {
      _refreshInvoices();
    });
  }

  void _navigateToInvoiceDetails(BuildContext context, Invoice invoice) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => InvoiceDetailsScreen(invoiceId: invoice.id!, initialInvoice: invoice),
      ),
    ).then((_) {
      _refreshInvoices();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final invoiceProvider = context.watch<InvoiceProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_effectiveAppBarTitle, style: const TextStyle(fontFamily: 'Cairo')),
        actions: [
          PopupMenuButton<InvoiceType>(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: "إنشاء فاتورة جديدة",
            onSelected: (InvoiceType type) {
              if (type == InvoiceType.sale) {
                _navigateToNewSaleInvoiceScreen(context);
              } else if (type == InvoiceType.purchase) {
                _navigateToNewPurchaseInvoiceScreen(context);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<InvoiceType>>[
              PopupMenuItem<InvoiceType>(
                value: InvoiceType.sale,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text('فاتورة بيع جديدة', textAlign: TextAlign.right),
                    const SizedBox(width: 8),
                    Icon(Icons.receipt_long_outlined, color: theme.colorScheme.primary),
                  ],
                ),
              ),
              PopupMenuItem<InvoiceType>(
                value: InvoiceType.purchase,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text('فاتورة شراء جديدة', textAlign: TextAlign.right),
                    const SizedBox(width: 8),
                    Icon(Icons.add_shopping_cart_outlined, color: theme.colorScheme.secondary),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 0),
              child: TextField(
                controller: _searchController,
                textAlign: TextAlign.right,
                style: const TextStyle(fontFamily: 'Cairo'),
                decoration: InputDecoration(
                  hintText: 'ابحث برقم الفاتورة أو اسم العميل...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      invoiceProvider.searchInvoices('');
                    },
                  ) : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshInvoices,
                child: Builder(
                  builder: (context) {
                    if (invoiceProvider.isLoading && invoiceProvider.invoices.isEmpty) {
                      return Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                        ),
                      );
                    }
                    
                    if (invoiceProvider.errorMessage != null && invoiceProvider.invoices.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, color: theme.colorScheme.error, size: 60),
                              const SizedBox(height: 16),
                              Text('خطأ في تحميل الفواتير:', style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.error, fontFamily: 'Cairo'), textAlign: TextAlign.center),
                              const SizedBox(height: 8),
                              Text(invoiceProvider.errorMessage!, style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'Cairo'), textAlign: TextAlign.center),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(icon: const Icon(Icons.refresh), label: const Text('حاول مرة أخرى', style: TextStyle(fontFamily: 'Cairo')), onPressed: _refreshInvoices)
                            ],
                          ),
                        ),
                      );
                    }

                    if (invoiceProvider.invoices.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty ? 'لا توجد فواتير بعد.' : 'لا توجد فواتير تطابق بحثك.',
                              style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600, fontFamily: 'Cairo'),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(8.0),
                      itemCount: invoiceProvider.invoices.length,
                      itemBuilder: (context, index) {
                        final invoice = invoiceProvider.invoices[index];
                        String statusText = paymentStatusToString(invoice.paymentStatus);
                        Color statusColor;
                        IconData statusIcon;

                        switch (invoice.paymentStatus) {
                          case PaymentStatus.paid:
                            statusColor = Colors.green.shade700;
                            statusIcon = Icons.check_circle_outline;
                            break;
                          case PaymentStatus.partiallyPaid:
                            statusColor = Colors.orange.shade700;
                            statusIcon = Icons.hourglass_bottom_outlined;
                            break;
                          case PaymentStatus.unpaid:
                            statusColor = theme.colorScheme.error;
                            statusIcon = Icons.error_outline;
                            break;
                          default:
                            statusColor = Colors.grey;
                            statusIcon = Icons.help_outline;
                            print("Warning: Unknown PaymentStatus encountered: ${invoice.paymentStatus}");
                            break;
                        }

                        final cardBorderColor = invoice.type == InvoiceType.sale
                            ? theme.colorScheme.primary.withOpacity(0.3)
                            : theme.colorScheme.secondary.withOpacity(0.3);

                        return Card(
                          elevation: 2.0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.0),
                              side: BorderSide(color: cardBorderColor, width: 1)
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
                            leading: CircleAvatar(
                              backgroundColor: invoice.type == InvoiceType.sale ? theme.colorScheme.primary.withOpacity(0.1) : theme.colorScheme.secondary.withOpacity(0.1),
                              child: Icon(
                                invoice.type == InvoiceType.sale ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                color: invoice.type == InvoiceType.sale ? theme.colorScheme.primary : theme.colorScheme.secondary,
                                size: 28,
                              ),
                            ),
                            title: Text(invoice.invoiceNumber, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface, fontFamily: 'Cairo')),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text('التاريخ: ${_arabicDateFormat.format(invoice.date)}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.8), fontFamily: 'Cairo')),
                                if (invoice.clientName != null && invoice.clientName!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2.0),
                                    child: Text('${invoice.type == InvoiceType.sale ? "العميل" : "المورد"}: ${invoice.clientName}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.8), fontFamily: 'Cairo')),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(statusIcon, color: statusColor, size: 15),
                                      const SizedBox(width: 4),
                                      Text(statusText, style: theme.textTheme.bodySmall?.copyWith(color: statusColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${NumberFormat.currency(locale: 'ar', symbol: 'ج.م', decimalDigits: 2).format(invoice.grandTotal)}', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, fontSize: 15, color: invoice.type == InvoiceType.sale ? theme.colorScheme.primary : theme.colorScheme.secondary, fontFamily: 'Cairo')),
                                if (invoice.paymentStatus != PaymentStatus.paid && invoice.balanceDue > 0.01)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2.0),
                                    child: Text('المتبقي: ${NumberFormat.currency(locale: 'ar', symbol: 'ج.م', decimalDigits: 2).format(invoice.balanceDue)}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error, fontSize: 11, fontFamily: 'Cairo')),
                                  ),
                              ],
                            ),
                            onTap: () => _navigateToInvoiceDetails(context, invoice),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      
    );
    
  }
}

// Helper function, ensure it's defined or imported
String paymentStatusToString(PaymentStatus status) {
  switch (status) {
    case PaymentStatus.paid: return 'مدفوعة';
    case PaymentStatus.partiallyPaid: return 'مدفوعة جزئياً';
    case PaymentStatus.unpaid: return 'غير مدفوعة';
    default: return 'غير معروف';
  }
}
