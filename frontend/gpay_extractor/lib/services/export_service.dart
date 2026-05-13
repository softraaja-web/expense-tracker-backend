// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as xl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/transaction.dart';

/// Service for exporting transaction data to CSV, Excel, and PDF.
class ExportService {
  static final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  /// Trigger a browser download from bytes.
  static void _downloadFile(Uint8List bytes, String fileName, String mimeType) {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  // ─── CSV Export ──────────────────────────────────────────────────────

  static void exportToCsv({
    required List<Transaction> transactions,
    required int month,
    required int year,
  }) {
    final rows = <List<String>>[
      ['Date', 'Recipient', 'Amount', 'Category', 'Type', 'UPI ID'],
      ...transactions.map((tx) => [
        tx.date,
        tx.recipient,
        tx.amount,
        tx.tag,
        tx.type,
        tx.upiId ?? '',
      ]),
    ];

    final csvData = const ListToCsvConverter().convert(rows);
    final bytes = Uint8List.fromList(csvData.codeUnits);
    final fileName = 'transactions_${_months[month - 1]}_$year.csv';
    _downloadFile(bytes, fileName, 'text/csv');
  }

  // ─── Excel Export ────────────────────────────────────────────────────

  static void exportToExcel({
    required List<Transaction> transactions,
    required Map<String, double> categoryTotals,
    required double totalExpense,
    required int month,
    required int year,
  }) {
    final excel = xl.Excel.createExcel();

    // ── Summary Sheet ──
    final summarySheet = excel['Summary'];
    summarySheet.appendRow([
      xl.TextCellValue('Monthly Report - ${_months[month - 1]} $year'),
    ]);
    summarySheet.appendRow([]);
    summarySheet.appendRow([
      xl.TextCellValue('Total Expense'),
      xl.DoubleCellValue(totalExpense),
    ]);
    summarySheet.appendRow([
      xl.TextCellValue('Total Transactions'),
      xl.IntCellValue(transactions.length),
    ]);
    summarySheet.appendRow([
      xl.TextCellValue('Categories'),
      xl.IntCellValue(categoryTotals.length),
    ]);
    summarySheet.appendRow([]);
    summarySheet.appendRow([
      xl.TextCellValue('Category'),
      xl.TextCellValue('Amount (₹)'),
      xl.TextCellValue('% of Total'),
    ]);

    final sortedCategories = categoryTotals.keys.toList()
      ..sort((a, b) => categoryTotals[b]!.compareTo(categoryTotals[a]!));

    for (final cat in sortedCategories) {
      final val = categoryTotals[cat]!;
      final pct = totalExpense > 0 ? (val / totalExpense * 100) : 0.0;
      summarySheet.appendRow([
        xl.TextCellValue(cat),
        xl.DoubleCellValue(val),
        xl.TextCellValue('${pct.toStringAsFixed(1)}%'),
      ]);
    }

    // ── Transactions Sheet ──
    final txSheet = excel['Transactions'];
    txSheet.appendRow([
      xl.TextCellValue('Date'),
      xl.TextCellValue('Recipient'),
      xl.TextCellValue('Amount'),
      xl.TextCellValue('Category'),
      xl.TextCellValue('Type'),
      xl.TextCellValue('UPI ID'),
    ]);

    for (final tx in transactions) {
      txSheet.appendRow([
        xl.TextCellValue(tx.date),
        xl.TextCellValue(tx.recipient),
        xl.TextCellValue(tx.amount),
        xl.TextCellValue(tx.tag),
        xl.TextCellValue(tx.type),
        xl.TextCellValue(tx.upiId ?? ''),
      ]);
    }

    // Remove default sheet if it exists
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final bytes = excel.save();
    if (bytes != null) {
      final fileName = 'transactions_${_months[month - 1]}_$year.xlsx';
      _downloadFile(
        Uint8List.fromList(bytes),
        fileName,
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    }
  }

  // ─── PDF Export ──────────────────────────────────────────────────────

  static Future<void> exportToPdf({
    required List<Transaction> transactions,
    required Map<String, double> categoryTotals,
    required double totalExpense,
    required int month,
    required int year,
  }) async {
    final pdf = pw.Document();
    final monthName = _months[month - 1];
    final sortedCategories = categoryTotals.keys.toList()
      ..sort((a, b) => categoryTotals[b]!.compareTo(categoryTotals[a]!));

    // ── Page 1: Summary ──
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Monthly Expense Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#4834D4'),
                  ),
                ),
                pw.Text(
                  '$monthName $year',
                  style: pw.TextStyle(
                    fontSize: 16,
                    color: PdfColor.fromHex('#6C63FF'),
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Divider(color: PdfColor.fromHex('#E8ECF4'), thickness: 1),
            pw.SizedBox(height: 16),
          ],
        ),
        build: (context) => [
          // Summary boxes
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _pdfInfoBox('Total Expense', 'Rs. ${totalExpense.toStringAsFixed(2)}'),
              _pdfInfoBox('Transactions', '${transactions.length}'),
              _pdfInfoBox('Categories', '${categoryTotals.length}'),
            ],
          ),
          pw.SizedBox(height: 30),

          // Category breakdown
          pw.Text(
            'Category Breakdown',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: PdfColor.fromHex('#E8ECF4')),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#6C63FF')),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            headers: ['Category', 'Amount (Rs.)', '% of Total', 'Count'],
            data: sortedCategories.map((cat) {
              final val = categoryTotals[cat]!;
              final pct = totalExpense > 0 ? (val / totalExpense * 100) : 0.0;
              final count = transactions.where((tx) => tx.tag == cat).length;
              return [
                cat,
                val.toStringAsFixed(2),
                '${pct.toStringAsFixed(1)}%',
                '$count',
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 30),

          // Transactions list
          pw.Text(
            'Transaction Details',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: PdfColor.fromHex('#E8ECF4')),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#4834D4')),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            columnWidths: {
              0: const pw.FixedColumnWidth(80),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FixedColumnWidth(70),
              3: const pw.FixedColumnWidth(70),
            },
            headers: ['Date', 'Recipient', 'Amount', 'Category'],
            data: transactions.map((tx) => [
              tx.date,
              tx.recipient,
              tx.amount,
              tx.tag,
            ]).toList(),
          ),
        ],
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 12),
          child: pw.Text(
            'Generated by GPay Extractor • Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
      ),
    );

    final bytes = await pdf.save();
    final fileName = 'report_${monthName}_$year.pdf';
    _downloadFile(
      Uint8List.fromList(bytes),
      fileName,
      'application/pdf',
    );
  }

  /// Helper to build a styled info box for the PDF.
  static pw.Widget _pdfInfoBox(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F4F3FF'),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#4834D4')),
          ),
        ],
      ),
    );
  }
}
