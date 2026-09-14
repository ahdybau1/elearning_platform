import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/models/content_models.dart';

/// Génère un PDF imprimable/téléchargeable d'une leçon (Section demandée : "cours en PDF lisible
/// sur la machine de l'utilisateur"). Rend la version structurée par l'IA (sections, pièges
/// classiques, conseils d'examen, quiz) quand elle est disponible, sinon le texte brut de la
/// leçon. Les formules LaTeX sont affichées telles quelles (encadrées par $...$/$$...$$) : ce
/// package ne fait pas de rendu mathématique, mais la notation reste lisible à l'impression.
class LessonPdfGenerator {
  static Future<void> printOrSave({
    required Lesson lesson,
    required String subjectName,
    required String chapterTitle,
  }) async {
    // Police par défaut (Helvetica) sans support Unicode : le "•" des puces et tout accent
    // composé plantent silencieusement le rendu sans cette police de repli.
    final baseFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();
    final italicFont = await PdfGoogleFonts.notoSansItalic();

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont, italic: italicFont),
    );
    final blocks = (lesson.contentJson['blocks'] as List?)
        ?.whereType<Map>()
        .map((b) => Map<String, dynamic>.from(b))
        .toList();
    final structured = lesson.contentJson['ai_structured'] as Map<String, dynamic>?;
    final body = lesson.contentJson['body'] as String? ?? '';
    final media = (lesson.contentJson['media'] as List?) ?? [];

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              '$subjectName • $chapterTitle',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
            pw.Divider(color: PdfColors.grey400),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber}/${context.pagesCount}',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.Text(
            lesson.title,
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Niveau d\'accès : ${lesson.minSubscriptionTier}',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700, fontStyle: pw.FontStyle.italic),
          ),
          pw.SizedBox(height: 20),
          if (blocks != null && blocks.isNotEmpty)
            ..._buildBlocks(blocks)
          else if (structured != null)
            ..._buildStructured(structured)
          else
            _buildPlainBody(body),
          if (media.isNotEmpty) ...[
            pw.SizedBox(height: 24),
            pw.Text('Médias attachés', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            ...media.map((m) => pw.Bullet(
                  text: '${m['filename'] ?? m['url'] ?? ''}',
                  style: const pw.TextStyle(fontSize: 10),
                )),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: '${lesson.title}.pdf',
    );
  }

  static pw.Widget _buildPlainBody(String body) {
    return pw.Text(
      body.isEmpty ? 'Aucun contenu rédigé.' : body,
      style: const pw.TextStyle(fontSize: 12, lineSpacing: 3),
    );
  }

  /// Rend le format natif `content_json['blocks']` (CF-002 — source de vérité une fois la leçon
  /// éditée manuellement, y compris après une structuration IA modifiée à la main). Pièges et
  /// conseils d'examen arrivent ici comme un bloc unique au corps formaté en puces (`•  item`, voir
  /// `_blocksFromAiStructured` côté `lessons_manager_screen.dart`) plutôt que des listes séparées.
  static List<pw.Widget> _buildBlocks(List<Map<String, dynamic>> blocks) {
    final widgets = <pw.Widget>[];
    for (final block in blocks) {
      final type = (block['type'] as String?)?.trim().toLowerCase() ?? 'paragraph';
      final heading = (block['heading'] as String?)?.trim();
      final body = (block['body'] as String?) ?? '';
      final formulas = (block['formulas'] as List?) ?? const [];

      if (type == 'piege' || type == 'conseil_examen') {
        final isPiege = type == 'piege';
        widgets.add(pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: isPiege ? PdfColors.red50 : PdfColors.green50,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                (heading != null && heading.isNotEmpty)
                    ? heading
                    : (isPiege ? 'Piège classique' : 'Conseil d\'examen'),
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: isPiege ? PdfColors.red900 : PdfColors.green900,
                ),
              ),
              pw.SizedBox(height: 4),
              for (final line in body.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty))
                pw.Bullet(
                  text: line.replaceFirst(RegExp(r'^•\s*'), ''),
                  style: const pw.TextStyle(fontSize: 11),
                ),
            ],
          ),
        ));
        widgets.add(pw.SizedBox(height: 14));
        continue;
      }

      if (type == 'paragraph') {
        if (body.isNotEmpty) {
          widgets.add(pw.Text(body, style: const pw.TextStyle(fontSize: 12, lineSpacing: 3)));
          widgets.add(pw.SizedBox(height: 14));
        }
        continue;
      }

      // theoreme / definition / formule / methode / exemple / type inconnu : rendu carte titrée.
      if (heading != null && heading.isNotEmpty) {
        widgets.add(pw.Text(heading, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)));
        widgets.add(pw.SizedBox(height: 4));
      }
      if (body.isNotEmpty) {
        widgets.add(pw.Text(body, style: const pw.TextStyle(fontSize: 12, lineSpacing: 3)));
      }
      for (final f in formulas) {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4, left: 12),
          child: pw.Text('$f', style: pw.TextStyle(fontSize: 12, color: PdfColors.indigo)),
        ));
      }
      widgets.add(pw.SizedBox(height: 14));
    }
    return widgets;
  }

  static List<pw.Widget> _buildStructured(Map<String, dynamic> structured) {
    final widgets = <pw.Widget>[];
    final summary = structured['summary'] as String?;
    if (summary != null && summary.isNotEmpty) {
      widgets.add(pw.Text(summary, style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic)));
      widgets.add(pw.SizedBox(height: 16));
    }

    final sections = (structured['sections'] as List?) ?? [];
    for (final s in sections) {
      final section = Map<String, dynamic>.from(s as Map);
      widgets.add(pw.Text(
        section['heading'] as String? ?? '',
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
      ));
      widgets.add(pw.SizedBox(height: 4));
      widgets.add(pw.Text(section['body'] as String? ?? '', style: const pw.TextStyle(fontSize: 12, lineSpacing: 3)));
      final formulas = (section['latex_formulas'] as List?) ?? [];
      for (final f in formulas) {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4, left: 12),
          child: pw.Text('$f', style: pw.TextStyle(fontSize: 12, color: PdfColors.indigo)),
        ));
      }
      widgets.add(pw.SizedBox(height: 14));
    }

    final traps = (structured['common_traps'] as List?) ?? [];
    if (traps.isNotEmpty) {
      widgets.add(pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.red50,
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Pièges classiques', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
            pw.SizedBox(height: 4),
            ...traps.map((t) => pw.Bullet(text: '$t', style: const pw.TextStyle(fontSize: 11))),
          ],
        ),
      ));
      widgets.add(pw.SizedBox(height: 14));
    }

    final tips = (structured['exam_tips'] as List?) ?? [];
    if (tips.isNotEmpty) {
      widgets.add(pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.green50,
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Conseils d\'examen', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
            pw.SizedBox(height: 4),
            ...tips.map((t) => pw.Bullet(text: '$t', style: const pw.TextStyle(fontSize: 11))),
          ],
        ),
      ));
      widgets.add(pw.SizedBox(height: 14));
    }

    final quiz = (structured['quiz_questions'] as List?) ?? [];
    if (quiz.isNotEmpty) {
      widgets.add(pw.Text('Quiz d\'évaluation', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)));
      widgets.add(pw.SizedBox(height: 6));
      for (var i = 0; i < quiz.length; i++) {
        final q = Map<String, dynamic>.from(quiz[i] as Map);
        final options = (q['options'] as List?) ?? [];
        widgets.add(pw.Text('${i + 1}. ${q['question']}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)));
        for (final o in options) {
          widgets.add(pw.Text('   • $o', style: const pw.TextStyle(fontSize: 10)));
        }
        widgets.add(pw.SizedBox(height: 8));
      }
    }

    return widgets;
  }
}
