import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/models/content_models.dart';
import '../../../core/models/enums.dart';

/// Génère un PDF imprimable/téléchargeable d'un exercice (énoncé + corrigé), même logique que
/// LessonPdfGenerator. Le corrigé est imprimé sur une page séparée pour permettre une distribution
/// "sujet seul" facile (l'admin imprime juste la première partie s'il le souhaite).
class ExercisePdfGenerator {
  static Future<void> printOrSave({
    required Exercise exercise,
    required String subjectName,
    String? chapterTitle,
  }) async {
    final baseFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();
    final italicFont = await PdfGoogleFonts.notoSansItalic();

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont, italic: italicFont),
    );

    final statement = exercise.instructionsJson['statement'] as String? ?? '';
    final options = (exercise.instructionsJson['options'] as List?) ?? [];
    final correction = exercise.solutionJson['correction'] as String? ?? '';
    final media = (exercise.instructionsJson['media'] as List?) ?? [];
    final solutionMedia = (exercise.solutionJson['media'] as List?) ?? [];

    final context = [
      subjectName,
      ?chapterTitle,
    ].join(' • ');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(context, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
            pw.Divider(color: PdfColors.grey400),
          ],
        ),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Page ${ctx.pageNumber}/${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        ),
        build: (ctx) => [
          pw.Text(exercise.title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(
            '${exerciseTypeToDb(exercise.type)} • ${exerciseFormatToDb(exercise.format)} • '
            '${exerciseDifficultyToDb(exercise.difficulty)} • Niveau : ${exercise.minSubscriptionTier}',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700, fontStyle: pw.FontStyle.italic),
          ),
          pw.SizedBox(height: 20),
          pw.Text('Énoncé', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text(statement.isEmpty ? 'Aucun énoncé rédigé.' : statement,
              style: const pw.TextStyle(fontSize: 12, lineSpacing: 3)),
          if (options.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            ...List.generate(options.length, (i) {
              final letter = String.fromCharCode(65 + i);
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text('$letter. ${options[i]}', style: const pw.TextStyle(fontSize: 11)),
              );
            }),
          ],
          if (media.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text('Médias attachés', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            ...media.map((m) => pw.Bullet(
                  text: '${m['filename'] ?? m['url'] ?? ''}',
                  style: const pw.TextStyle(fontSize: 10),
                )),
          ],
          pw.SizedBox(height: 28),
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 8),
          pw.Text('Corrigé', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
          pw.SizedBox(height: 6),
          pw.Text(correction.isEmpty ? 'Aucun corrigé rédigé.' : correction,
              style: const pw.TextStyle(fontSize: 12, lineSpacing: 3)),
          if (solutionMedia.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text('Médias attachés au corrigé', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            ...solutionMedia.map((m) => pw.Bullet(
                  text: '${m['filename'] ?? m['url'] ?? ''}',
                  style: const pw.TextStyle(fontSize: 10),
                )),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => doc.save(), name: '${exercise.title}.pdf');
  }
}
