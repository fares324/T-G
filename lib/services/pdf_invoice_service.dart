// lib/services/pdf_invoice_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:fouad_stock/model/invoice_model.dart';
import 'package:fouad_stock/model/store_details_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'settings_service.dart';

class PdfInvoiceService {
  final SettingsService _settingsService = SettingsService();

  Future<Uint8List> generateInvoicePdf(Invoice invoice) async {
    return await _generatePdf(invoice: invoice, isQuote: false);
  }

  Future<Uint8List> generatePriceQuotePdf(Invoice quoteData) async {
    return await _generatePdf(invoice: quoteData, isQuote: true);
  }

  Future<void> shareInvoice(Invoice invoice, BuildContext context) async {
    try {
      final Uint8List pdfBytes = await generateInvoicePdf(invoice);
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'invoice-${invoice.invoiceNumber}.pdf',
      );
    } catch (e) {
      _showErrorSnackbar(context, e);
    }
  }

  Future<void> sharePriceQuote(Invoice quoteData, BuildContext context) async {
    try {
      final Uint8List pdfBytes = await generatePriceQuotePdf(quoteData);
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'price-quote-${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      _showErrorSnackbar(context, e);
    }
  }

  void _showErrorSnackbar(BuildContext context, Object e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('فشل إنشاء أو مشاركة ملف PDF: $e', textAlign: TextAlign.right),
      ),
    );
  }

  Future<Uint8List> _generatePdf({required Invoice invoice, required bool isQuote}) async {
    final pdf = pw.Document();
    final DateFormat arabicDateTimeFormat = DateFormat.yMMMd('ar').add_jm();
    
    final StoreDetails storeDetails = await _settingsService.getStoreDetails();
    
    final fontData = await rootBundle.load("assets/fonts/Cairo-Regular.ttf");
    final ttfRegular = pw.Font.ttf(fontData);
    final boldFontData = await rootBundle.load("assets/fonts/Cairo-Bold.ttf");
    final ttfBold = pw.Font.ttf(boldFontData);

    final baseTextStyle = pw.TextStyle(font: ttfRegular, fontSize: 10);
    final boldTextStyle = pw.TextStyle(font: ttfBold, fontSize: 10);
    final titleTextStyle = pw.TextStyle(font: ttfBold, fontSize: 16);
    final headerTextStyle = pw.TextStyle(font: ttfBold, fontSize: 12);
    
    pw.MemoryImage? logoImage;
    if (storeDetails.logoPath != null && storeDetails.logoPath!.isNotEmpty) {
      try {
        final File logoFile = File(storeDetails.logoPath!);
        if (await logoFile.exists()) {
           logoImage = pw.MemoryImage(await logoFile.readAsBytes());
        }
      } catch (e) {
        print("Error loading logo image for PDF: $e");
      }
    }

    pw.MemoryImage? instaPayImage;
    if (storeDetails.instaPayQrPath != null && storeDetails.instaPayQrPath!.isNotEmpty) {
      try {
        final File qrFile = File(storeDetails.instaPayQrPath!);
        if (await qrFile.exists()) {
           instaPayImage = pw.MemoryImage(await qrFile.readAsBytes());
        }
      } catch (e) {
        print("Error loading InstaPay QR image for PDF: $e");
      }
    }

    pw.MemoryImage? walletImage;
    if (storeDetails.walletQrPath != null && storeDetails.walletQrPath!.isNotEmpty) {
      try {
        final File qrFile = File(storeDetails.walletQrPath!);
        if (await qrFile.exists()) {
           walletImage = pw.MemoryImage(await qrFile.readAsBytes());
        }
      } catch (e) {
        print("Error loading Wallet QR image for PDF: $e");
      }
    }
    
    pdf.addPage(
      pw.MultiPage(
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: ttfRegular, bold: ttfBold),
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            _buildHeader(
              invoice,
              storeDetails,
              titleTextStyle,
              baseTextStyle,
              logoImage,
              instaPayImage,
              walletImage,
              isQuote: isQuote
            ),
            pw.SizedBox(height: 15),
            _buildInvoiceDetails(invoice, arabicDateTimeFormat, baseTextStyle, boldTextStyle, isQuote: isQuote),
            pw.SizedBox(height: 15),
            pw.Text('الأصناف:', style: headerTextStyle, textDirection: pw.TextDirection.rtl),
            pw.SizedBox(height: 5),
            _buildItemsTable(invoice, baseTextStyle, boldTextStyle),
            pw.SizedBox(height: 15),
            _buildTotals(invoice, baseTextStyle, boldTextStyle, isQuote: isQuote),
            if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
              pw.SizedBox(height: 15),
              pw.Text('ملاحظات:', style: headerTextStyle, textDirection: pw.TextDirection.rtl),
              pw.Text(invoice.notes!, style: baseTextStyle, textDirection: pw.TextDirection.rtl),
            ],
            pw.Spacer(),
            _buildFooter(baseTextStyle, isQuote: isQuote),
          ];
        },
      ),
    );
    return pdf.save();
  }

  pw.Widget _buildHeader(
    Invoice invoice, 
    StoreDetails storeDetails, 
    pw.TextStyle titleStyle, 
    pw.TextStyle baseStyle, 
    pw.MemoryImage? logoImage,
    pw.MemoryImage? instaPayImage,
    pw.MemoryImage? walletImage,
    {required bool isQuote}
  ) {
    String documentTitle = isQuote ? 'عرض سعر' : (invoice.type == InvoiceType.sale ? 'فاتورة بيع' : 'فاتورة شراء');
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (logoImage != null)
                    pw.Container(
                      height: 80,
                      width: 80,
                      child: pw.Image(logoImage),
                    ),
                  if (logoImage != null) pw.SizedBox(height: 10),
                  pw.Text(storeDetails.name, style: titleStyle.copyWith(fontSize: 20)),
                  pw.SizedBox(height: 5),
                  pw.Text(storeDetails.address, style: baseStyle),
                  pw.SizedBox(height: 5),
                  pw.Text(storeDetails.phone, style: baseStyle),
                ],
              ),
            ),
            pw.SizedBox(
              width: 140,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                   if (instaPayImage != null || walletImage != null)
                    pw.Text('للدفع السريع:', style: baseStyle.copyWith(fontSize: 9)),
                   pw.SizedBox(height: 5),
                   pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      if (instaPayImage != null)
                        pw.Container(
                          height: 60,
                          width: 60,
                          child: pw.Image(instaPayImage),
                        ),
                      if (instaPayImage != null && walletImage != null)
                        pw.SizedBox(width: 10),
                      if (walletImage != null)
                        pw.Container(
                          height: 60,
                          width: 60,
                          child: pw.Image(walletImage),
                        ),
                    ]
                   )
                ],
              ),
            ),
          ]
        ),
        pw.SizedBox(height: 20),
        pw.Center(
          child: pw.Text(documentTitle, style: titleStyle),
        ),
        pw.SizedBox(height: 5),
      ],
    );
  }

  pw.Widget _buildInvoiceDetails(Invoice invoice, DateFormat dateTimeFormat, pw.TextStyle baseStyle, pw.TextStyle boldStyle, {required bool isQuote}) {
    String documentNumberLabel = isQuote ? 'عرض سعر رقم:' : 'رقم الفاتورة:';
    String documentNumber = isQuote ? DateFormat('yyyyMMdd').format(DateTime.now()) : invoice.invoiceNumber;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('$documentNumberLabel $documentNumber', style: boldStyle),
            pw.Text('التاريخ: ${dateTimeFormat.format(invoice.date)}', style: baseStyle),
          ],
        ),
        if (invoice.clientName != null && invoice.clientName!.isNotEmpty) ...[
          pw.SizedBox(height: 5),
          pw.Text('${isQuote ? "مقدم إلى" : (invoice.type == InvoiceType.sale ? "اسم العميل" : "اسم المورد")}: ${invoice.clientName}', style: baseStyle),
        ],
      ],
    );
  }

  pw.Widget _buildItemsTable(Invoice invoice, pw.TextStyle baseStyle, pw.TextStyle boldStyle) {
    final headers = ['الإجمالي الفرعي', 'سعر الوحدة', 'الكمية', 'الصنف'];
    final data = invoice.items.map((item) {
      return [
        '${item.itemTotal.toStringAsFixed(2)} ج.م',
        '${item.unitPrice.toStringAsFixed(2)} ج.م',
        item.quantity.toString(),
        item.productName,
      ];
    }).toList();

    return pw.Table.fromTextArray(
      headers: headers,
      data: data,
      border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
      headerStyle: boldStyle.copyWith(color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
      cellStyle: baseStyle.copyWith(fontSize: 9),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      cellAlignment: pw.Alignment.centerRight,
      cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerLeft, 2: pw.Alignment.center, 3: pw.Alignment.centerRight},
    );
  }

  pw.Widget _buildTotals(Invoice invoice, pw.TextStyle baseStyle, pw.TextStyle boldStyle, {required bool isQuote}) {
    return pw.Container(
      alignment: pw.Alignment.centerLeft,
      child: pw.SizedBox(
        width: 250,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildTotalRow('المجموع الفرعي:', '${invoice.subtotal.toStringAsFixed(2)} ج.م', baseStyle),
            if (invoice.taxRatePercentage > 0 || invoice.taxAmount > 0)
              _buildTotalRow('الضريبة (${invoice.taxRatePercentage.toStringAsFixed(invoice.taxRatePercentage.truncateToDouble() == invoice.taxRatePercentage ? 0 : 1)}%):', '${invoice.taxAmount.toStringAsFixed(2)} ج.م', baseStyle),
            if (invoice.discountAmount > 0)
              _buildTotalRow('الخصم:', '${invoice.discountAmount.toStringAsFixed(2)} ج.م', baseStyle, valueColor: PdfColors.green700),
            pw.Divider(color: PdfColors.grey, height: 10),
            _buildTotalRow('الإجمالي الكلي:', '${invoice.grandTotal.toStringAsFixed(2)} ج.م', boldStyle.copyWith(fontSize: 14)),
            
            if (!isQuote) ...[
              pw.Divider(color: PdfColors.grey300, height: 15, thickness: 0.5, indent: 20, endIndent: 20),
              _buildTotalRow('المبلغ المدفوع:', '${invoice.amountPaid.toStringAsFixed(2)} ج.م', baseStyle.copyWith(color: PdfColors.green700)),
              _buildTotalRow('المبلغ المتبقي:', '${invoice.balanceDue.toStringAsFixed(2)} ج.م', boldStyle.copyWith(color: invoice.balanceDue > 0.01 ? PdfColors.red700 : PdfColors.green700)),
            ]
          ],
        ),
      ),
    );
  }

  pw.Widget _buildTotalRow(String title, String value, pw.TextStyle style, {PdfColor? valueColor}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(value, style: style.copyWith(color: valueColor), textDirection: pw.TextDirection.ltr),
          pw.Text(title, style: style),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(pw.TextStyle baseStyle, {required bool isQuote}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Divider(color: PdfColors.grey, height: 20),
        if (isQuote)
          pw.Text('هذا العرض ساري لمدة 15 يوماً من تاريخه. الأسعار شاملة الضريبة.', style: baseStyle.copyWith(fontStyle: pw.FontStyle.italic, color: PdfColors.grey600)),
        pw.SizedBox(height: 5),
        pw.Text('شكراً لتعاملكم معنا!', style: baseStyle, textDirection: pw.TextDirection.rtl),
      ],
    );
  }
}
// // lib/services/pdf_invoice_service.dart
// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart' show rootBundle;
// import 'package:fouad_stock/model/invoice_model.dart';
// import 'package:fouad_stock/model/store_details_model.dart';
// import 'package:pdf/pdf.dart';
// import 'package:pdf/widgets.dart' as pw;
// import 'package:printing/printing.dart';
// import 'package:intl/intl.dart';
// import 'settings_service.dart';

// class PdfInvoiceService {
//   final SettingsService _settingsService = SettingsService();

//   Future<Uint8List> generateInvoicePdf(Invoice invoice) async {
//     return await _generatePdf(invoice: invoice, isQuote: false);
//   }

//   Future<Uint8List> generatePriceQuotePdf(Invoice quoteData) async {
//     return await _generatePdf(invoice: quoteData, isQuote: true);
//   }

//   Future<void> shareInvoice(Invoice invoice, BuildContext context) async {
//     try {
//       final Uint8List pdfBytes = await generateInvoicePdf(invoice);
//       await Printing.sharePdf(
//         bytes: pdfBytes,
//         filename: 'invoice-${invoice.invoiceNumber}.pdf',
//       );
//     } catch (e) {
//       _showErrorSnackbar(context, e);
//     }
//   }

//   Future<void> sharePriceQuote(Invoice quoteData, BuildContext context) async {
//     try {
//       final Uint8List pdfBytes = await generatePriceQuotePdf(quoteData);
//       await Printing.sharePdf(
//         bytes: pdfBytes,
//         filename: 'price-quote-${DateTime.now().millisecondsSinceEpoch}.pdf',
//       );
//     } catch (e) {
//       _showErrorSnackbar(context, e);
//     }
//   }

//   void _showErrorSnackbar(BuildContext context, Object e) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('فشل إنشاء أو مشاركة ملف PDF: $e', textAlign: TextAlign.right),
//       ),
//     );
//   }

//   Future<Uint8List> _generatePdf({required Invoice invoice, required bool isQuote}) async {
//     final pdf = pw.Document();
//     final DateFormat arabicDateTimeFormat = DateFormat.yMMMd('ar').add_jm();
//     final StoreDetails storeDetails = await _settingsService.getStoreDetails();
    
//     final fontData = await rootBundle.load("assets/fonts/Cairo-Regular.ttf");
//     final ttfRegular = pw.Font.ttf(fontData);
//     final boldFontData = await rootBundle.load("assets/fonts/Cairo-Bold.ttf");
//     final ttfBold = pw.Font.ttf(boldFontData);

//     final baseTextStyle = pw.TextStyle(font: ttfRegular, fontSize: 10);
//     final boldTextStyle = pw.TextStyle(font: ttfBold, fontSize: 10);
//     final titleTextStyle = pw.TextStyle(font: ttfBold, fontSize: 16);
//     final headerTextStyle = pw.TextStyle(font: ttfBold, fontSize: 12);
    
//     pdf.addPage(
//       pw.MultiPage(
//         textDirection: pw.TextDirection.rtl,
//         theme: pw.ThemeData.withFont(base: ttfRegular, bold: ttfBold),
//         pageFormat: PdfPageFormat.a4,
//         build: (pw.Context context) {
//           return [
//             _buildHeader(invoice, storeDetails, titleTextStyle, baseTextStyle, isQuote: isQuote),
//             pw.SizedBox(height: 20),
//             _buildInvoiceDetails(invoice, arabicDateTimeFormat, baseTextStyle, boldTextStyle, isQuote: isQuote),
//             pw.SizedBox(height: 20),
//             pw.Text('الأصناف:', style: headerTextStyle, textDirection: pw.TextDirection.rtl),
//             pw.SizedBox(height: 8),
//             _buildItemsTable(invoice, baseTextStyle, boldTextStyle),
//             pw.SizedBox(height: 20),
//             _buildTotals(invoice, baseTextStyle, boldTextStyle, isQuote: isQuote),
//             if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
//               pw.SizedBox(height: 20),
//               pw.Text('ملاحظات:', style: headerTextStyle, textDirection: pw.TextDirection.rtl),
//               pw.Text(invoice.notes!, style: baseTextStyle, textDirection: pw.TextDirection.rtl),
//             ],
//             pw.Spacer(),
//             _buildFooter(baseTextStyle, isQuote: isQuote),
//           ];
//         },
//       ),
//     );
//     return pdf.save();
//   }

//   pw.Widget _buildHeader(Invoice invoice, StoreDetails storeDetails, pw.TextStyle titleStyle, pw.TextStyle baseStyle, {required bool isQuote}) {
//     String documentTitle = isQuote ? 'عرض سعر' : (invoice.type == InvoiceType.sale ? 'فاتورة بيع' : 'فاتورة شراء');
//     return pw.Column(
//       crossAxisAlignment: pw.CrossAxisAlignment.center,
//       children: [
//         pw.Text(storeDetails.name, style: titleStyle.copyWith(fontSize: 20, font: titleStyle.font)),
//         pw.Text(storeDetails.address, style: baseStyle, textAlign: pw.TextAlign.center),
//         pw.Text(storeDetails.phone, style: baseStyle),
//         pw.SizedBox(height: 20),
//         pw.Text(documentTitle, style: titleStyle),
//         pw.SizedBox(height: 5),
//       ],
//     );
//   }

//   pw.Widget _buildInvoiceDetails(Invoice invoice, DateFormat dateTimeFormat, pw.TextStyle baseStyle, pw.TextStyle boldStyle, {required bool isQuote}) {
//     String documentNumberLabel = isQuote ? 'رقم عرض السعر:' : 'رقم الفاتورة:';
//     return pw.Column(
//       crossAxisAlignment: pw.CrossAxisAlignment.start,
//       children: [
//         pw.Row(
//           mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//           children: [
//             pw.Text('$documentNumberLabel ${invoice.invoiceNumber}', style: boldStyle),
//             pw.Text('التاريخ: ${dateTimeFormat.format(invoice.date)}', style: baseStyle),
//           ],
//         ),
//         if (invoice.clientName != null && invoice.clientName!.isNotEmpty) ...[
//           pw.SizedBox(height: 5),
//           pw.Text('${isQuote ? "مقدم إلى" : (invoice.type == InvoiceType.sale ? "اسم العميل" : "اسم المورد")}: ${invoice.clientName}', style: baseStyle),
//         ],
//       ],
//     );
//   }

//   pw.Widget _buildItemsTable(Invoice invoice, pw.TextStyle baseStyle, pw.TextStyle boldStyle) {
//     final headers = ['الإجمالي الفرعي', 'سعر الوحدة', 'الكمية', 'الصنف'];
//     final data = invoice.items.map((item) {
//       return [
//         '${item.itemTotal.toStringAsFixed(2)} ج.م',
//         '${item.unitPrice.toStringAsFixed(2)} ج.م',
//         item.quantity.toString(),
//         item.productName,
//       ];
//     }).toList();

//     return pw.Table.fromTextArray(
//       headers: headers,
//       data: data,
//       border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
//       headerStyle: boldStyle.copyWith(color: PdfColors.white),
//       headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
//       cellStyle: baseStyle,
//       cellAlignment: pw.Alignment.centerRight,
//       cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerLeft, 2: pw.Alignment.center, 3: pw.Alignment.centerRight},
//     );
//   }

//   pw.Widget _buildTotals(Invoice invoice, pw.TextStyle baseStyle, pw.TextStyle boldStyle, {required bool isQuote}) {
//     return pw.Container(
//       alignment: pw.Alignment.centerLeft,
//       child: pw.SizedBox(
//         width: 250,
//         child: pw.Column(
//           crossAxisAlignment: pw.CrossAxisAlignment.start,
//           children: [
//             _buildTotalRow('المجموع الفرعي:', '${invoice.subtotal.toStringAsFixed(2)} ج.م', baseStyle),
//             if (invoice.taxRatePercentage > 0 || invoice.taxAmount > 0)
//               _buildTotalRow('الضريبة (${invoice.taxRatePercentage.toStringAsFixed(invoice.taxRatePercentage.truncateToDouble() == invoice.taxRatePercentage ? 0 : 1)}%):', '${invoice.taxAmount.toStringAsFixed(2)} ج.م', baseStyle),
//             if (invoice.discountAmount > 0)
//               _buildTotalRow('الخصم:', '${invoice.discountAmount.toStringAsFixed(2)} ج.م', baseStyle, valueColor: PdfColors.green700),
//             pw.Divider(color: PdfColors.grey, height: 10),
//             _buildTotalRow('الإجمالي الكلي:', '${invoice.grandTotal.toStringAsFixed(2)} ج.م', boldStyle.copyWith(fontSize: 14)),
            
//             // Only show payment details for actual invoices, not quotes
//             if (!isQuote) ...[
//               pw.Divider(color: PdfColors.grey300, height: 15, thickness: 0.5, indent: 20, endIndent: 20),
//               _buildTotalRow('المبلغ المدفوع:', '${invoice.amountPaid.toStringAsFixed(2)} ج.م', baseStyle.copyWith(color: PdfColors.green700)),
//               _buildTotalRow('المبلغ المتبقي:', '${invoice.balanceDue.toStringAsFixed(2)} ج.م', boldStyle.copyWith(color: invoice.balanceDue > 0.01 ? PdfColors.red700 : PdfColors.green700)),
//             ]
//           ],
//         ),
//       ),
//     );
//   }

//   pw.Widget _buildTotalRow(String title, String value, pw.TextStyle style, {PdfColor? valueColor}) {
//     return pw.Padding(
//       padding: const pw.EdgeInsets.symmetric(vertical: 2.0),
//       child: pw.Row(
//         mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//         children: [
//           pw.Text(value, style: style.copyWith(color: valueColor), textDirection: pw.TextDirection.ltr),
//           pw.Text(title, style: style),
//         ],
//       ),
//     );
//   }

//   pw.Widget _buildFooter(pw.TextStyle baseStyle, {required bool isQuote}) {
//     return pw.Column(
//       crossAxisAlignment: pw.CrossAxisAlignment.center,
//       children: [
//         pw.Divider(color: PdfColors.grey, height: 20),
//         if (isQuote)
//           pw.Text('هذا العرض ساري لمدة 15 يوماً من تاريخه. الأسعار شاملة الضريبة.', style: baseStyle.copyWith(fontStyle: pw.FontStyle.italic, color: PdfColors.grey600)),
//         pw.SizedBox(height: 5),
//         pw.Text('شكراً لتعاملكم معنا!', style: baseStyle, textDirection: pw.TextDirection.rtl),
//       ],
//     );
//   }
// }


// // lib/services/pdf_invoice_service.dart
// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart' show rootBundle;
// import 'package:fouad_stock/model/invoice_model.dart';
// import 'package:fouad_stock/model/store_details_model.dart';
// import 'package:pdf/pdf.dart';
// import 'package:pdf/widgets.dart' as pw;
// import 'package:printing/printing.dart';
// import 'package:intl/intl.dart';
// import 'settings_service.dart';

// class PdfInvoiceService {
//   final SettingsService _settingsService = SettingsService();

//   Future<Uint8List> generateInvoicePdf(Invoice invoice) async {
//     final pdf = pw.Document();
    
//     final DateFormat arabicDateTimeFormat = DateFormat.yMMMd('ar').add_jm();

//     final fontData = await rootBundle.load("assets/fonts/Cairo-Regular.ttf");
//     final ttfRegular = pw.Font.ttf(fontData);
//     final boldFontData = await rootBundle.load("assets/fonts/Cairo-Bold.ttf");
//     final ttfBold = pw.Font.ttf(boldFontData);

//     final baseTextStyle = pw.TextStyle(font: ttfRegular, fontSize: 10);
//     final boldTextStyle = pw.TextStyle(font: ttfBold, fontSize: 10);
//     final titleTextStyle = pw.TextStyle(font: ttfBold, fontSize: 16);
//     final headerTextStyle = pw.TextStyle(font: ttfBold, fontSize: 12);

//     final StoreDetails storeDetails = await _settingsService.getStoreDetails();

//     pdf.addPage(
//       pw.MultiPage(
//         textDirection: pw.TextDirection.rtl,
//         theme: pw.ThemeData.withFont(base: ttfRegular, bold: ttfBold),
//         pageFormat: PdfPageFormat.a4,
//         build: (pw.Context context) {
//           return [
//             _buildHeader(invoice, storeDetails, titleTextStyle, baseTextStyle),
//             pw.SizedBox(height: 20),
//             _buildInvoiceDetails(invoice, arabicDateTimeFormat, baseTextStyle, boldTextStyle),
//             pw.SizedBox(height: 20),
//             pw.Text('الأصناف:', style: headerTextStyle, textDirection: pw.TextDirection.rtl),
//             pw.SizedBox(height: 8),
//             _buildItemsTable(invoice, baseTextStyle, boldTextStyle),
//             pw.SizedBox(height: 20),
//             _buildTotals(invoice, baseTextStyle, boldTextStyle), // Updated method
//             if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
//               pw.SizedBox(height: 20),
//               pw.Text('ملاحظات:', style: headerTextStyle, textDirection: pw.TextDirection.rtl),
//               pw.Text(invoice.notes!, style: baseTextStyle, textDirection: pw.TextDirection.rtl),
//             ],
//             pw.Spacer(),
//             _buildFooter(baseTextStyle),
//           ];
//         },
//       ),
//     );

//     return pdf.save();
//   }

//   pw.Widget _buildHeader(
//     Invoice invoice,
//     StoreDetails storeDetails,
//     pw.TextStyle titleStyle,
//     pw.TextStyle baseStyle,
//   ) {
//     return pw.Column(
//       crossAxisAlignment: pw.CrossAxisAlignment.center,
//       children: [
//         pw.Text(storeDetails.name, style: titleStyle.copyWith(fontSize: 20, font: titleStyle.font)),
//         pw.Text(storeDetails.address, style: baseStyle, textAlign: pw.TextAlign.center),
//         pw.Text(storeDetails.phone, style: baseStyle),
//         pw.SizedBox(height: 20),
//         pw.Text(invoice.type == InvoiceType.sale ? 'فاتورة بيع' : 'فاتورة شراء', style: titleStyle),
//         pw.SizedBox(height: 5),
//       ],
//     );
//   }

//   pw.Widget _buildInvoiceDetails(
//     Invoice invoice,
//     DateFormat dateTimeFormat,
//     pw.TextStyle baseStyle,
//     pw.TextStyle boldStyle,
//   ) {
//     return pw.Column(
//       crossAxisAlignment: pw.CrossAxisAlignment.start,
//       children: [
//         pw.Row(
//           mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//           children: [
//             pw.Text('رقم الفاتورة: ${invoice.invoiceNumber}', style: boldStyle),
//             pw.Text('التاريخ: ${dateTimeFormat.format(invoice.date)}', style: baseStyle),
//           ],
//         ),
//         if (invoice.clientName != null && invoice.clientName!.isNotEmpty) ...[
//           pw.SizedBox(height: 5),
//           pw.Text('${invoice.type == InvoiceType.sale ? "اسم العميل" : "اسم المورد"}: ${invoice.clientName}', style: baseStyle),
//         ],
//       ],
//     );
//   }

//   pw.Widget _buildItemsTable(
//     Invoice invoice,
//     pw.TextStyle baseStyle,
//     pw.TextStyle boldStyle,
//   ) {
//     final headers = ['الإجمالي الفرعي', 'سعر الوحدة', 'الكمية', 'الصنف'];
//     final data = invoice.items.map((item) {
//       return [
//         '${item.itemTotal.toStringAsFixed(2)} ج.م',
//         '${item.unitPrice.toStringAsFixed(2)} ج.م',
//         item.quantity.toString(),
//         item.productName,
//       ];
//     }).toList();

//     return pw.Table.fromTextArray(
//       headers: headers,
//       data: data,
//       border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
//       headerStyle: boldStyle.copyWith(color: PdfColors.white),
//       headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
//       cellStyle: baseStyle,
//       cellAlignment: pw.Alignment.centerRight,
//       cellAlignments: {
//         0: pw.Alignment.centerLeft,
//         1: pw.Alignment.centerLeft,
//         2: pw.Alignment.center,
//         3: pw.Alignment.centerRight,
//       },
//     );
//   }

//   // --- MODIFIED: _buildTotals to match the visual layout from the image ---
//   pw.Widget _buildTotals(
//     Invoice invoice,
//     pw.TextStyle baseStyle,
//     pw.TextStyle boldStyle,
//   ) {
//     return pw.Container(
//       alignment: pw.Alignment.centerLeft,
//       child: pw.SizedBox(
//         width: 250, // Increased width slightly for better spacing
//         child: pw.Column(
//           crossAxisAlignment: pw.CrossAxisAlignment.start,
//           children: [
//             _buildTotalRow('المجموع الفرعي:', '${invoice.subtotal.toStringAsFixed(2)} ج.م', baseStyle),
            
//             // Box for Tax details
//             pw.Container(
//               padding: const pw.EdgeInsets.all(8),
//               decoration: pw.BoxDecoration(
//                 border: pw.Border.all(color: PdfColors.grey, width: 0.5),
//                 borderRadius: pw.BorderRadius.circular(5),
//               ),
//               child: pw.Column(
//                 children: [
//                   _buildTotalRow('نسبة الضريبة (%):', '${invoice.taxRatePercentage.toStringAsFixed(invoice.taxRatePercentage.truncateToDouble() == invoice.taxRatePercentage ? 0 : 1)}%', baseStyle),
//                   _buildTotalRow('مبلغ الضريبة:', '${invoice.taxAmount.toStringAsFixed(2)} ج.م', baseStyle),
//                 ]
//               )
//             ),
//             pw.SizedBox(height: 5),

//             // Box for Discount details
//             if (invoice.discountAmount > 0)
//               pw.Container(
//                 padding: const pw.EdgeInsets.all(8),
//                 decoration: pw.BoxDecoration(
//                   border: pw.Border.all(color: PdfColors.grey, width: 0.5),
//                   borderRadius: pw.BorderRadius.circular(5),
//                 ),
//                 child: _buildTotalRow('مبلغ الخصم (ج.م):', '${invoice.discountAmount.toStringAsFixed(2)} ج.م', baseStyle, valueColor: PdfColors.green700)
//               ),

//             pw.Divider(color: PdfColors.grey, height: 15),
//             _buildTotalRow('الإجمالي الكلي:', '${invoice.grandTotal.toStringAsFixed(2)} ج.م', boldStyle.copyWith(fontSize: 14)),
            
//             pw.Divider(color: PdfColors.grey300, height: 15, thickness: 0.5, indent: 20, endIndent: 20),
//             _buildTotalRow('المبلغ المدفوع:', '${invoice.amountPaid.toStringAsFixed(2)} ج.م', baseStyle.copyWith(color: PdfColors.green700)),
//             _buildTotalRow('المبلغ المتبقي:', '${invoice.balanceDue.toStringAsFixed(2)} ج.م', boldStyle.copyWith(color: invoice.balanceDue > 0.01 ? PdfColors.red700 : PdfColors.green700)),
//           ],
//         ),
//       ),
//     );
//   }

//   // --- NEW HELPER for building rows in the totals section ---
//   pw.Widget _buildTotalRow(String title, String value, pw.TextStyle style, {PdfColor? valueColor}) {
//     return pw.Padding(
//       padding: const pw.EdgeInsets.symmetric(vertical: 2.0),
//       child: pw.Row(
//         mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//         children: [
//           pw.Text(
//             value,
//             style: style.copyWith(color: valueColor),
//             textDirection: pw.TextDirection.ltr,
//           ),
//           pw.Text(title, style: style),
//         ],
//       ),
//     );
//   }


//   pw.Widget _buildFooter(pw.TextStyle baseStyle) {
//     return pw.Column(
//       crossAxisAlignment: pw.CrossAxisAlignment.center,
//       children: [
//         pw.Divider(color: PdfColors.grey, height: 20),
//         pw.Text(
//           'شكراً لتعاملكم معنا!',
//           style: baseStyle,
//           textDirection: pw.TextDirection.rtl,
//         ),
//       ],
//     );
//   }

//   Future<void> shareInvoice(Invoice invoice, BuildContext context) async {
//     try {
//       final Uint8List pdfBytes = await generateInvoicePdf(invoice);
//       await Printing.sharePdf(
//         bytes: pdfBytes,
//         filename: 'invoice-${invoice.invoiceNumber}.pdf',
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             'فشل إنشاء أو مشاركة ملف PDF: $e',
//             textAlign: TextAlign.right,
//           ),
//         ),
//       );
//     }
//   }
// }
