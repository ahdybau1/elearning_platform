import 'package:flutter/material.dart';

class EditableLessonBlock {
  final Map<String, dynamic> originalJson;
  String type;
  final TextEditingController headingCtrl;
  final TextEditingController bodyCtrl;
  final TextEditingController formulasCtrl;

  EditableLessonBlock({
    required this.type,
    String heading = '',
    String body = '',
    List<String> formulas = const [],
    this.originalJson = const {},
  }) : headingCtrl = TextEditingController(text: heading),
       bodyCtrl = TextEditingController(text: body),
       formulasCtrl = TextEditingController(text: formulas.join('\n'));

  factory EditableLessonBlock.fromJson(Map<String, dynamic> json) {
    final rawFormulas = json['formulas'] ?? json['latex_formulas'];
    return EditableLessonBlock(
      originalJson: Map<String, dynamic>.from(json),
      type: (json['type'] as String?)?.trim().toLowerCase().isNotEmpty == true
          ? (json['type'] as String).trim().toLowerCase()
          : 'paragraph',
      heading: (json['heading'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      formulas: rawFormulas is List
          ? rawFormulas.map((f) => f.toString()).toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson(int order) {
    final formulas = formulasCtrl.text
        .split('\n')
        .map((f) => f.trim())
        .where((f) => f.isNotEmpty)
        .toList();
    return {
      ...originalJson,
      'type': type,
      'heading': headingCtrl.text.trim().isEmpty
          ? null
          : headingCtrl.text.trim(),
      'body': bodyCtrl.text.trim(),
      'formulas': formulas,
      'order': order,
    };
  }

  bool get isEmpty =>
      originalJson.isEmpty &&
      headingCtrl.text.trim().isEmpty &&
      bodyCtrl.text.trim().isEmpty &&
      formulasCtrl.text.trim().isEmpty;

  void dispose() {
    headingCtrl.dispose();
    bodyCtrl.dispose();
    formulasCtrl.dispose();
  }
}
