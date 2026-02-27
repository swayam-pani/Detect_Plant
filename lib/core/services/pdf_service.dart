import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

final pdfServiceProvider = Provider((ref) => PdfGenerationService());

class PdfGenerationService {
  Future<void> generateAndPrintReport({
    required String imagePath,
    required Map<String, dynamic> result,
    required String riskStatus,
    required String wikiExtract,
  }) async {
    final pdf = pw.Document();

    final imageBytes = await File(imagePath).readAsBytes();
    final image = pw.MemoryImage(imageBytes);

    final plant = result['plant'] ?? 'Unknown';
    final disease = result['disease'] ?? 'None';
    final isHealthy = result['isHealthy'] ?? true;
    final conf = (result['confidence'] ?? 0.0) * 100;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Plant Disease Detection Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),

              // Section 1: Authentication
              pw.Text(
                'Section 1: Captured Image Authentication',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Center(child: pw.Image(image, height: 200)),
              pw.SizedBox(height: 10),
              pw.Text('Detected Plant: ${plant.toString().toUpperCase()}'),
              pw.SizedBox(height: 20),

              // Section 2: Disease Information
              pw.Text(
                'Section 2: Disease Information',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                isHealthy
                    ? 'Condition: Healthy Plant'
                    : 'Detected Disease: ${disease.toString().replaceAll('_', ' ')}',
              ),
              pw.SizedBox(height: 5),
              pw.Text('Model Confidence: ${conf.toStringAsFixed(1)}%'),
              pw.SizedBox(height: 20),

              // Section 3: Risk Status
              pw.Text(
                'Section 3: Risk Status',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Severity: $riskStatus',
                style: pw.TextStyle(
                  color: isHealthy ? PdfColors.green : PdfColors.red,
                ),
              ),
              pw.SizedBox(height: 20),

              // Section 4 & 5: Precautions & Details
              pw.Text(
                'Section 4 & 5: Additional Details & Precautions',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                wikiExtract.isNotEmpty
                    ? wikiExtract
                    : 'No specific information found.',
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                isHealthy
                    ? 'Maintain regular watering and fertilization.'
                    : 'Refer to local agricultural guidelines for treatment.',
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Plant_Report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }
}
