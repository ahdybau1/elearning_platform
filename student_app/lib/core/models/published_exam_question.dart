/// Projection serveur : aucune note interne, confiance IA ou réponse verrouillée.
class PublishedExamQuestion {
  const PublishedExamQuestion({required this.id, required this.order,
    required this.statement, this.answer});
  final String id;
  final int order;
  final String statement;
  final String? answer;

  factory PublishedExamQuestion.fromJson(Map<String, dynamic> json) => PublishedExamQuestion(
    id: json['id'] as String,
    order: json['question_order'] as int,
    statement: json['statement'] as String,
    answer: json['proposed_answer'] as String?,
  );
}
