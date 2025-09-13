// lib/screens/invoice_details_screen.dart
import 'package:flutter/material.dart';
import 'package:fouad_stock/model/invoice_item_model.dart' as db_invoice_item;
import 'package:fouad_stock/model/invoice_model.dart';
import 'package:fouad_stock/screens/edit_invoice_screen.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/pdf_invoice_service.dart';
import '../providers/invoice_provider.dart';
import '../providers/product_provider.dart';

class InvoiceDetailsScreen extends StatefulWidget {
  final int invoiceId;
  final Invoice initialInvoice;

  const InvoiceDetailsScreen({
    super.key,
    required this.invoiceId,
    required this.initialInvoice,
  });

  @override
  State<InvoiceDetailsScreen> createState() => _InvoiceDetailsScreenState();
}

class _InvoiceDetailsScreenState extends State<InvoiceDetailsScreen> {
  late DateFormat _arabicDateFormat;
  late Invoice _invoice;
  bool _isLoadingDetails = false;

  @override
  void initState() {
    super.initState();
    _arabicDateFormat = DateFormat.yMMMd('ar');
    _invoice = widget.initialInvoice;
    // --- FIX: Defer the initial data load to ensure it runs after the first frame ---
    WidgetsBinding.instance.addPostFrameCallback((_) {
       if(mounted) _refreshInvoiceDetails();
    });
  }
  
  // --- NEW: Method to reload the invoice details from the provider ---
  Future<void> _refreshInvoiceDetails() async {
    if(!mounted) return;
    setState(() {
      _isLoadingDetails = true;
    });
    
    final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
    // Directly fetch the single invoice we need, which is more efficient
    final updatedInvoice = await invoiceProvider.getInvoiceById(widget.invoiceId);

    // If the invoice was deleted from another screen, it might be null.
    // In that case, we can safely pop the screen.
    if (updatedInvoice == null && mounted) {
        Navigator.of(context).pop();
        return;
    }

    if (updatedInvoice != null && mounted) {
      setState(() {
        _invoice = updatedInvoice;
      });
    }
    
    if(mounted){
      setState(() {
        _isLoadingDetails = false;
      });
    }
  }


  Future<void> _recordPaymentDialog(Invoice invoice) async {
    if (!mounted) return;
    final theme = Theme.of(context);
    final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
    final amountController = TextEditingController();
    final GlobalKey<FormState> dialogFormKey = GlobalKey<FormState>();
    double maxPaymentAmount = invoice.balanceDue;

    if (maxPaymentAmount <= 0.009) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الفاتورة مسددة بالكامل بالفعل.', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo'))),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (BuildContext dialogCtx) {
        return AlertDialog(
          title: Text('تسجيل دفعة للفاتورة #${invoice.invoiceNumber}', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
          content: Form(
            key: dialogFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('المبلغ المتبقي: ${maxPaymentAmount.toStringAsFixed(2)} ج.م', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
                const SizedBox(height: 10),
                TextFormField(
                  controller: amountController,
                  textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'المبلغ المدفوع*', labelStyle: const TextStyle(fontFamily: 'Cairo'),
                    hintText: 'أدخل مبلغ الدفعة', hintStyle: const TextStyle(fontFamily: 'Cairo'),
                    suffixText: 'ج.م', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'الرجاء إدخال المبلغ.';
                    final amount = double.tryParse(value);
                    if (amount == null || amount <= 0) return 'الرجاء إدخال مبلغ صحيح أكبر من صفر.';
                    if (amount > maxPaymentAmount) return 'المبلغ يتجاوز المتبقي (${maxPaymentAmount.toStringAsFixed(2)} ج.م).';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: <Widget>[
            TextButton(
              child: Text('إلغاء', style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontFamily: 'Cairo')),
              onPressed: () => Navigator.of(dialogCtx).pop(),
            ),
            ElevatedButton(
              child: const Text('حفظ الدفعة', style: TextStyle(fontFamily: 'Cairo')),
              onPressed: () async {
                if (dialogFormKey.currentState!.validate()) {
                  final paymentAmount = double.parse(amountController.text);
                  Navigator.of(dialogCtx).pop(); 
                  if (!mounted) return;
                  final String? error = await invoiceProvider.recordPayment(invoice.id!, paymentAmount);
                  if (!mounted) return;
                  if (error == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم تسجيل الدفعة بنجاح!', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green),
                    );
                    _refreshInvoiceDetails();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('فشل تسجيل الدفعة: $error', textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmAndDeleteInvoice(Invoice invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('تأكيد الحذف', style: TextStyle(fontFamily: 'Cairo', color: Theme.of(context).colorScheme.error)),
          content: const Text(
            'هل أنت متأكد من حذف هذه الفاتورة؟\nسيتم إرجاع/خصم الكميات من المخزون. لا يمكن التراجع عن هذا الإجراء.',
            textAlign: TextAlign.right,
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: <Widget>[
            TextButton(
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
              child: const Text('نعم، قم بالحذف', style: TextStyle(fontFamily: 'Cairo')),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
      final productProvider = Provider.of<ProductProvider>(context, listen: false); 
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري الحذف...', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo'))));
      
      final String? error = await invoiceProvider.deleteInvoiceAndReconcileStock(invoice, productProvider);

      if (!mounted) return;

      if (error == null) {
        Navigator.of(context).pop(); 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف الفاتورة بنجاح!', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل حذف الفاتورة: $error', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  DataRow _buildItemRow(BuildContext context, db_invoice_item.InvoiceItem item) {
    final theme = Theme.of(context);
    return DataRow(
      cells: [
        DataCell(Text(item.productName, textAlign: TextAlign.right, style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'Cairo'))),
        DataCell(Text(item.quantity.toString(), textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'Cairo'))),
        DataCell(Text(NumberFormat.currency(locale: 'ar', symbol: 'ج.م', decimalDigits: 2).format(item.unitPrice), textAlign: TextAlign.left, style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'Cairo'))),
        DataCell(Text(NumberFormat.currency(locale: 'ar', symbol: 'ج.م', decimalDigits: 2).format(item.itemTotal), textAlign: TextAlign.left, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500, fontFamily: 'Cairo'))),
      ],
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value, {TextStyle? valueStyle, Color? valueColor}) {
    final theme = Theme.of(context);
    TextStyle defaultLabelStyle = theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.8), fontFamily: 'Cairo') ?? const TextStyle(fontFamily: 'Cairo');
    TextStyle defaultValueStyle = valueStyle ?? theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: valueColor, fontFamily: 'Cairo') ?? TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600, color: valueColor);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label:', style: defaultLabelStyle),
          Text(value, style: defaultValueStyle),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
      final theme = Theme.of(context);
      Color currentPaymentStatusColor = paymentStatusColor(_invoice.paymentStatus, theme);

      return Scaffold(
        appBar: AppBar(
          title: Text('تفاصيل الفاتورة رقم: ${_invoice.invoiceNumber}', style: const TextStyle(fontFamily: 'Cairo')),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'تعديل الفاتورة',
              // --- THIS IS THE FIX ---
              onPressed: () async {
                if (_invoice.paymentStatus == PaymentStatus.paid) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('لا يمكن تعديل فاتورة مدفوعة بالكامل.', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo'))),
                  );
                  return;
                }
                
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (context) => EditInvoiceScreen(originalInvoice: _invoice),
                  ),
                );

                if (result == true && mounted) {
                  _refreshInvoiceDetails();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'تصدير كـ PDF',
              onPressed: () async {
                final pdfService = PdfInvoiceService();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('جاري إنشاء ملف PDF...', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo'))),
                );
                await pdfService.shareInvoice(_invoice, context);
              },
            ),
            IconButton(
              icon: Icon(Icons.delete_forever_outlined, color: theme.colorScheme.error),
              tooltip: 'حذف الفاتورة',
              onPressed: () => _confirmAndDeleteInvoice(_invoice),
            ),
          ],
        ),
        body: _isLoadingDetails
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Fouad Stock - المخزن', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontFamily: 'Cairo'), textAlign: TextAlign.center),
                            const SizedBox(height: 8),
                            Center(child: Text(_invoice.type == InvoiceType.sale ? 'فاتورة بيع' : 'فاتورة شراء', style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.secondary, fontFamily: 'Cairo'))),
                            const Divider(height: 20, thickness: 1),
                            _buildDetailRow(context, 'رقم الفاتورة', _invoice.invoiceNumber),
                            _buildDetailRow(context, 'تاريخ الفاتورة', _arabicDateFormat.format(_invoice.date)),
                            if (_invoice.clientName != null && _invoice.clientName!.isNotEmpty)
                              _buildDetailRow(context, _invoice.type == InvoiceType.sale ? 'اسم العميل' : 'اسم المورد', _invoice.clientName!),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('الأصناف:', style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary, fontFamily: 'Cairo'), textAlign: TextAlign.right),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: 20,
                            headingRowColor: WidgetStateColor.resolveWith((states) => theme.colorScheme.primaryContainer.withOpacity(0.3)),
                            headingTextStyle: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onPrimaryContainer, fontFamily: 'Cairo'),
                            columns: const [
                              DataColumn(label: Text('الصنف', textAlign: TextAlign.right)),
                              DataColumn(label: Text('الكمية', textAlign: TextAlign.center), numeric: true),
                              DataColumn(label: Text('سعر الوحدة', textAlign: TextAlign.left), numeric: true),
                              DataColumn(label: Text('الإجمالي الفرعي', textAlign: TextAlign.left), numeric: true),
                            ],
                            rows: _invoice.items.map((item) => _buildItemRow(context, item)).toList(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildDetailRow(context, 'المجموع الفرعي', NumberFormat.currency(locale: 'ar', symbol: 'ج.م', decimalDigits: 2).format(_invoice.subtotal)),
                            if (_invoice.taxRatePercentage > 0 || _invoice.taxAmount > 0) ...[
                              _buildDetailRow(context, 'نسبة الضريبة (%)', '${_invoice.taxRatePercentage.toStringAsFixed(_invoice.taxRatePercentage.truncateToDouble() == _invoice.taxRatePercentage ? 0 : 1)}%'),
                              _buildDetailRow(context, 'مبلغ الضريبة', NumberFormat.currency(locale: 'ar', symbol: 'ج.م', decimalDigits: 2).format(_invoice.taxAmount)),
                            ],
                            if (_invoice.discountAmount > 0)
                              _buildDetailRow(context, 'الخصم', NumberFormat.currency(locale: 'ar', symbol: 'ج.م', decimalDigits: 2).format(_invoice.discountAmount), valueStyle: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.tertiary, fontFamily: 'Cairo')),
                            const Divider(thickness: 0.8, height: 15),
                            _buildDetailRow(context, 'الإجمالي الكلي', NumberFormat.currency(locale: 'ar', symbol: 'ج.م', decimalDigits: 2).format(_invoice.grandTotal), valueStyle: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontFamily: 'Cairo')),
                            const Divider(thickness: 0.8, height: 15, indent: 50, endIndent: 50),
                            _buildDetailRow(context, 'المبلغ المدفوع', NumberFormat.currency(locale: 'ar', symbol: 'ج.م', decimalDigits: 2).format(_invoice.amountPaid), valueStyle: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: Colors.green.shade700, fontFamily: 'Cairo')),
                            _buildDetailRow(context, 'المبلغ المتبقي', NumberFormat.currency(locale: 'ar', symbol: 'ج.م', decimalDigits: 2).format(_invoice.balanceDue), valueStyle: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: _invoice.balanceDue > 0.009 ? theme.colorScheme.error : Colors.green.shade700, fontFamily: 'Cairo')),
                            _buildDetailRow(context, 'حالة الدفع', paymentStatusToString(_invoice.paymentStatus), valueStyle: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: currentPaymentStatusColor, fontFamily: 'Cairo')),
                          ]
                        )
                      )
                    ),
                    const SizedBox(height: 10),
                    if (_invoice.paymentStatus != PaymentStatus.paid)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10.0),
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.payment_outlined),
                          label: const Text('تسجيل دفعة', style: TextStyle(fontFamily: 'Cairo')),
                          onPressed: () => _recordPaymentDialog(_invoice),
                          style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.secondary, padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                    if (_invoice.notes != null && _invoice.notes!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text('ملاحظات:', style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary, fontFamily: 'Cairo'), textAlign: TextAlign.right),
                      const SizedBox(height: 8),
                      Card(
                        elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(_invoice.notes!, style: theme.textTheme.bodyLarge?.copyWith(fontFamily: 'Cairo'), textAlign: TextAlign.right),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
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
    case PaymentStatus.paid: return Colors.green.shade700;
    case PaymentStatus.partiallyPaid: return Colors.orange.shade800;
    case PaymentStatus.unpaid: return theme.colorScheme.error;
    default: return theme.disabledColor;
  }
}


