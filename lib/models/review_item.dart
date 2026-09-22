class ReviewItem {
  final String id;
  final String noteId;
  final DateTime dueAt;
  final int intervalDays;
  final int repetitionCount;
  final double easeFactor;
  final DateTime? lastReviewedAt;

  const ReviewItem({
    required this.id,
    required this.noteId,
    required this.dueAt,
    this.intervalDays = 1,
    this.repetitionCount = 0,
    this.easeFactor = 2.5,
    this.lastReviewedAt,
  });

  bool get isDue => DateTime.now().isAfter(dueAt);

  ReviewItem copyWith({
    String? id,
    String? noteId,
    DateTime? dueAt,
    int? intervalDays,
    int? repetitionCount,
    double? easeFactor,
    DateTime? lastReviewedAt,
  }) {
    return ReviewItem(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      dueAt: dueAt ?? this.dueAt,
      intervalDays: intervalDays ?? this.intervalDays,
      repetitionCount: repetitionCount ?? this.repetitionCount,
      easeFactor: easeFactor ?? this.easeFactor,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'noteId': noteId,
      'dueAt': dueAt.toIso8601String(),
      'intervalDays': intervalDays,
      'repetitionCount': repetitionCount,
      'easeFactor': easeFactor,
      'lastReviewedAt': lastReviewedAt?.toIso8601String(),
    };
  }

  factory ReviewItem.fromJson(Map<String, dynamic> json) {
    return ReviewItem(
      id: json['id'] as String,
      noteId: json['noteId'] as String,
      dueAt: DateTime.parse(json['dueAt'] as String),
      intervalDays: json['intervalDays'] as int? ?? 1,
      repetitionCount: json['repetitionCount'] as int? ?? 0,
      easeFactor: (json['easeFactor'] as num?)?.toDouble() ?? 2.5,
      lastReviewedAt: json['lastReviewedAt'] != null
          ? DateTime.parse(json['lastReviewedAt'] as String)
          : null,
    );
  }
}
