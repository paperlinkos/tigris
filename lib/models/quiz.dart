class QuizQuestion {
  final String id;
  final String noteId;
  final String prompt;
  final List<String> options;
  final int correctOptionIndex;
  final String? explanation;

  const QuizQuestion({
    required this.id,
    required this.noteId,
    required this.prompt,
    required this.options,
    required this.correctOptionIndex,
    this.explanation,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'noteId': noteId,
      'prompt': prompt,
      'options': options,
      'correctOptionIndex': correctOptionIndex,
      'explanation': explanation,
    };
  }

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      id: json['id'] as String,
      noteId: json['noteId'] as String,
      prompt: json['prompt'] as String,
      options: (json['options'] as List<dynamic>).cast<String>(),
      correctOptionIndex: json['correctOptionIndex'] as int,
      explanation: json['explanation'] as String?,
    );
  }
}
