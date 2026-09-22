class Flashcard {
  final String id;
  final String noteId;
  final String front;
  final String back;
  final DateTime createdAt;

  const Flashcard({
    required this.id,
    required this.noteId,
    required this.front,
    required this.back,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'noteId': noteId,
      'front': front,
      'back': back,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    return Flashcard(
      id: json['id'] as String,
      noteId: json['noteId'] as String,
      front: json['front'] as String,
      back: json['back'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
