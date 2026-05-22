import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../models/prescription_model.dart';

// =============================================================================
// MediSlot v2 — PDF Service
// Generates a professional prescription PDF, uploads to Supabase Storage,
// saves the public URL to the prescriptions table, and sets released_at.
// PDFs are generated once and reused.
// =============================================================================

class PdfService {
  final SupabaseClient _db = Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // Main entry point — generate, upload, update prescription record
  // Returns the public PDF URL or null on failure.
  // ---------------------------------------------------------------------------
  Future<String?> generateAndUpload({
    required PrescriptionModel prescription,
    required Map<String, dynamic> doctorInfo,
    required Map<String, dynamic> patientInfo,
  }) async {
    try {
      // 1. Generate PDF bytes
      final bytes = await _buildPdf(
        prescription: prescription,
        doctorInfo: doctorInfo,
        patientInfo: patientInfo,
      );

      // 2. Save to temp file
      final tempDir = await getTemporaryDirectory();
      final fileName =
          'prescription_${prescription.prescriptionId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      // 3. Upload to Supabase Storage
      final storagePath =
          '${prescription.patientId}/$fileName';

      await _db.storage
          .from(AppConstants.bucketPrescriptions)
          .upload(storagePath, file,
              fileOptions: const FileOptions(upsert: true));

      // 4. Get public URL
      final publicUrl = _db.storage
          .from(AppConstants.bucketPrescriptions)
          .getPublicUrl(storagePath);

      // 5. Update prescription record — set pdf_url and released_at
      final now = DateTime.now().toIso8601String();
      await _db
          .from(AppConstants.tablePrescriptions)
          .update({
            'pdf_url': publicUrl,
            'released_at': now,
          })
          .eq('prescription_id', prescription.prescriptionId);

      return publicUrl;
    } catch (e) {
      print('❌ PdfService.generateAndUpload error: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Build the PDF document in memory
  // ---------------------------------------------------------------------------
  Future<Uint8List> _buildPdf({
    required PrescriptionModel prescription,
    required Map<String, dynamic> doctorInfo,
    required Map<String, dynamic> patientInfo,
  }) async {
    final pdf = pw.Document();

    // Load fonts
    final regularFont =
        await rootBundle.load('assets/fonts/Inter-Regular.ttf').then(
              (data) => pw.Font.ttf(data),
              onError: (_) => pw.Font.helvetica(),
            ).catchError((_) => pw.Font.helvetica());
    final boldFont =
        await rootBundle.load('assets/fonts/Inter-Bold.ttf').then(
              (data) => pw.Font.ttf(data),
              onError: (_) => pw.Font.helveticaBold(),
            ).catchError((_) => pw.Font.helveticaBold());

    final baseTheme = pw.ThemeData.withFont(
      base: regularFont,
      bold: boldFont,
    );

    // Doctor photo (optional)
    pw.ImageProvider? doctorPhoto;
    final photoUrl = doctorInfo['photo_url'] as String?;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      try {
        final response = await _db.storage
            .from(AppConstants.bucketDoctorPhotos)
            .download(photoUrl.split('/').last);
        doctorPhoto = pw.MemoryImage(response);
      } catch (_) {
        // No photo — skip gracefully
      }
    }

    pdf.addPage(
      pw.MultiPage(
        theme: baseTheme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(
          doctorInfo: doctorInfo,
          doctorPhoto: doctorPhoto,
          boldFont: boldFont,
          regularFont: regularFont,
        ),
        footer: (context) => _buildFooter(
          pageNum: context.pageNumber,
          totalPages: context.pagesCount,
          regularFont: regularFont,
        ),
        build: (context) => [
          pw.SizedBox(height: 12),
          _buildPatientSection(
            patientInfo: patientInfo,
            prescription: prescription,
            boldFont: boldFont,
            regularFont: regularFont,
          ),
          pw.SizedBox(height: 16),
          _buildDiagnosisSection(prescription, boldFont, regularFont),
          if (prescription.medicines.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _buildMedicinesSection(
                prescription.medicines, boldFont, regularFont),
          ],
          if (prescription.recommendedTests != null &&
              prescription.recommendedTests!.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _buildTestsSection(
                prescription.recommendedTests!, boldFont, regularFont),
          ],
          if (prescription.additionalNotes != null &&
              prescription.additionalNotes!.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _buildNotesSection(
                prescription.additionalNotes!, boldFont, regularFont),
          ],
          if (prescription.followUpDate != null) ...[
            pw.SizedBox(height: 16),
            _buildFollowUp(prescription.followUpDate!, boldFont, regularFont),
          ],
          pw.SizedBox(height: 32),
          _buildSignature(doctorInfo, boldFont, regularFont),
        ],
      ),
    );

    return pdf.save();
  }

  // ---------------------------------------------------------------------------
  // PDF Section Builders
  // ---------------------------------------------------------------------------

  pw.Widget _buildHeader({
    required Map<String, dynamic> doctorInfo,
    pw.ImageProvider? doctorPhoto,
    required pw.Font boldFont,
    required pw.Font regularFont,
  }) {
    final primaryColor = PdfColor.fromHex('#2193b0');
    final doctorName =
        doctorInfo['profiles']?['name'] ?? doctorInfo['name'] ?? 'Doctor';
    final specialization = doctorInfo['specialization'] ?? '';
    final qualification = doctorInfo['qualification'] ?? '';
    final phone = doctorInfo['phone'] ?? '';

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: primaryColor,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      padding: const pw.EdgeInsets.all(16),
      child: pw.Row(
        children: [
          if (doctorPhoto != null) ...[
            pw.ClipOval(
              child: pw.Image(doctorPhoto, width: 56, height: 56,
                  fit: pw.BoxFit.cover),
            ),
            pw.SizedBox(width: 12),
          ],
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Dr. $doctorName',
                  style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 18,
                      color: PdfColors.white),
                ),
                if (specialization.isNotEmpty)
                  pw.Text(
                    '$qualification • $specialization',
                    style: pw.TextStyle(
                        font: regularFont,
                        fontSize: 11,
                        color: PdfColor.fromHex('#FFFFFFB3')),
                  ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'MediSlot',
                style: pw.TextStyle(
                    font: boldFont, fontSize: 16, color: PdfColors.white),
              ),
              if (phone.isNotEmpty)
                pw.Text(
                  '📞 $phone',
                  style: pw.TextStyle(
                      font: regularFont,
                      fontSize: 10,
                      color: PdfColor.fromHex('#FFFFFFB3')),
                ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPatientSection({
    required Map<String, dynamic> patientInfo,
    required PrescriptionModel prescription,
    required pw.Font boldFont,
    required pw.Font regularFont,
  }) {
    final dateStr = DateFormat('dd MMMM yyyy').format(
        DateTime.tryParse(prescription.date) ?? DateTime.now());

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColor.fromHex('#E8EDF2')),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      padding: const pw.EdgeInsets.all(12),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _label('Patient Name', boldFont),
                _value(patientInfo['name'] ?? '-', regularFont),
                pw.SizedBox(height: 6),
                pw.Row(children: [
                  pw.Expanded(child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _label('Age', boldFont),
                      _value('${patientInfo['age'] ?? '-'} yrs', regularFont),
                    ],
                  )),
                  pw.Expanded(child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _label('Gender', boldFont),
                      _value(patientInfo['gender'] ?? '-', regularFont),
                    ],
                  )),
                ]),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              _label('Date', boldFont),
              _value(dateStr, regularFont),
              pw.SizedBox(height: 6),
              _label('Prescription ID', boldFont),
              _value(prescription.prescriptionId.substring(0, 8).toUpperCase(),
                  regularFont),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildDiagnosisSection(
      PrescriptionModel p, pw.Font bold, pw.Font regular) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Diagnosis & Symptoms', bold),
        pw.SizedBox(height: 6),
        if (p.diagnosis != null && p.diagnosis!.isNotEmpty) ...[
          _label('Diagnosis', bold),
          _value(p.diagnosis!, regular),
          pw.SizedBox(height: 6),
        ],
        if (p.symptoms != null && p.symptoms!.isNotEmpty) ...[
          _label('Symptoms', bold),
          _value(p.symptoms!, regular),
        ],
      ],
    );
  }

  pw.Widget _buildMedicinesSection(
      List<Map<String, dynamic>> medicines, pw.Font bold, pw.Font regular) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Medicines', bold),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(
              color: PdfColor.fromHex('#E8EDF2'), width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration:
                  pw.BoxDecoration(color: PdfColor.fromHex('#E3F4F9')),
              children: [
                _tableHeader('Medicine', bold),
                _tableHeader('Dosage', bold),
                _tableHeader('Frequency', bold),
                _tableHeader('Duration', bold),
              ],
            ),
            ...medicines.map((med) => pw.TableRow(children: [
                  _tableCell(med['name'] ?? '-', regular),
                  _tableCell(med['dosage'] ?? '-', regular),
                  _tableCell(med['frequency'] ?? '-', regular),
                  _tableCell(med['duration'] ?? '-', regular),
                ])),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTestsSection(
      String tests, pw.Font bold, pw.Font regular) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Recommended Tests', bold),
        pw.SizedBox(height: 6),
        _value(tests, regular),
      ],
    );
  }

  pw.Widget _buildNotesSection(
      String notes, pw.Font bold, pw.Font regular) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Additional Notes', bold),
        pw.SizedBox(height: 6),
        _value(notes, regular),
      ],
    );
  }

  pw.Widget _buildFollowUp(
      String followUpDate, pw.Font bold, pw.Font regular) {
    String formatted = followUpDate;
    try {
      formatted =
          DateFormat('dd MMMM yyyy').format(DateTime.parse(followUpDate));
    } catch (_) {}

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#E3F4F9'),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      padding: const pw.EdgeInsets.all(10),
      child: pw.Row(children: [
        pw.Text('📅 ', style: pw.TextStyle(font: regular, fontSize: 12)),
        pw.Text('Follow-up on: ',
            style: pw.TextStyle(font: bold, fontSize: 12)),
        pw.Text(formatted,
            style: pw.TextStyle(font: regular, fontSize: 12,
                color: PdfColor.fromHex('#2193b0'))),
      ]),
    );
  }

  pw.Widget _buildSignature(
      Map<String, dynamic> doctorInfo, pw.Font bold, pw.Font regular) {
    final doctorName =
        doctorInfo['profiles']?['name'] ?? doctorInfo['name'] ?? 'Doctor';
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Container(
            width: 120,
            height: 1,
            color: PdfColors.black,
          ),
          pw.SizedBox(height: 4),
          pw.Text('Dr. $doctorName',
              style: pw.TextStyle(font: bold, fontSize: 11)),
          pw.Text('Signature',
              style: pw.TextStyle(
                  font: regular,
                  fontSize: 10,
                  color: PdfColors.grey600)),
        ],
      ),
    );
  }

  pw.Widget _buildFooter({
    required int pageNum,
    required int totalPages,
    required pw.Font regularFont,
  }) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300),
        ),
      ),
      padding: const pw.EdgeInsets.only(top: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated by MediSlot • ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
            style: pw.TextStyle(
                font: regularFont, fontSize: 9, color: PdfColors.grey600),
          ),
          pw.Text(
            'Page $pageNum / $totalPages',
            style: pw.TextStyle(
                font: regularFont, fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helper widgets
  // ---------------------------------------------------------------------------
  pw.Widget _sectionTitle(String text, pw.Font bold) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(text,
              style: pw.TextStyle(
                  font: bold,
                  fontSize: 13,
                  color: PdfColor.fromHex('#2193b0'))),
          pw.Container(
            height: 1.5,
            width: 40,
            color: PdfColor.fromHex('#2193b0'),
            margin: const pw.EdgeInsets.only(top: 3),
          ),
        ],
      );

  pw.Widget _label(String text, pw.Font bold) => pw.Text(text,
      style: pw.TextStyle(
          font: bold, fontSize: 10, color: PdfColors.grey700));

  pw.Widget _value(String text, pw.Font regular) => pw.Text(text,
      style: pw.TextStyle(font: regular, fontSize: 11));

  pw.Widget _tableHeader(String text, pw.Font bold) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(text,
            style: pw.TextStyle(font: bold, fontSize: 10)),
      );

  pw.Widget _tableCell(String text, pw.Font regular) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(text,
            style: pw.TextStyle(font: regular, fontSize: 10)),
      );
}
