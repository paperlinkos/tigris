class AiSummaryResponse {
  final String summary;
  final List<String> keyPoints;

  const AiSummaryResponse({
    required this.summary,
    this.keyPoints = const [],
  });

  Map<String, dynamic> toJson() => {
    'summary': summary,
    'keyPoints': keyPoints,
  };

  factory AiSummaryResponse.fromJson(Map<String, dynamic> json) => AiSummaryResponse(
    summary: json['summary'] as String,
    keyPoints: (json['keyPoints'] as List<dynamic>?)?.cast<String>() ?? const [],
  );
}

class AiExplainResponse {
  final String explanation;
  final List<String> simplifiedConcepts;

  const AiExplainResponse({
    required this.explanation,
    this.simplifiedConcepts = const [],
  });

  Map<String, dynamic> toJson() => {
    'explanation': explanation,
    'simplifiedConcepts': simplifiedConcepts,
  };

  factory AiExplainResponse.fromJson(Map<String, dynamic> json) => AiExplainResponse(
    explanation: json['explanation'] as String,
    simplifiedConcepts: (json['simplifiedConcepts'] as List<dynamic>?)?.cast<String>() ?? const [],
  );
}

class TeachMeExchange {
  final String question;
  final String? userAnswer;
  final String? feedback;
  final bool? isUnderstood;

  const TeachMeExchange({
    required this.question,
    this.userAnswer,
    this.feedback,
    this.isUnderstood,
  });

  TeachMeExchange copyWith({
    String? question,
    String? userAnswer,
    String? feedback,
    bool? isUnderstood,
  }) {
    return TeachMeExchange(
      question: question ?? this.question,
      userAnswer: userAnswer ?? this.userAnswer,
      feedback: feedback ?? this.feedback,
      isUnderstood: isUnderstood ?? this.isUnderstood,
    );
  }

  Map<String, dynamic> toJson() => {
    'question': question,
    'userAnswer': userAnswer,
    'feedback': feedback,
    'isUnderstood': isUnderstood,
  };

  factory TeachMeExchange.fromJson(Map<String, dynamic> json) => TeachMeExchange(
    question: json['question'] as String,
    userAnswer: json['userAnswer'] as String?,
    feedback: json['feedback'] as String?,
    isUnderstood: json['isUnderstood'] as bool?,
  );
}

class TeachMeSession {
  final String sessionId;
  final String noteId;
  final String noteTitle;
  final List<TeachMeExchange> exchanges;
  final bool isCompleted;

  const TeachMeSession({
    required this.sessionId,
    required this.noteId,
    required this.noteTitle,
    required this.exchanges,
    this.isCompleted = false,
  });

  TeachMeSession copyWith({
    String? sessionId,
    String? noteId,
    String? noteTitle,
    List<TeachMeExchange>? exchanges,
    bool? isCompleted,
  }) {
    return TeachMeSession(
      sessionId: sessionId ?? this.sessionId,
      noteId: noteId ?? this.noteId,
      noteTitle: noteTitle ?? this.noteTitle,
      exchanges: exchanges ?? this.exchanges,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'noteId': noteId,
    'noteTitle': noteTitle,
    'exchanges': exchanges.map((e) => e.toJson()).toList(),
    'isCompleted': isCompleted,
  };

  factory TeachMeSession.fromJson(Map<String, dynamic> json) => TeachMeSession(
    sessionId: json['sessionId'] as String,
    noteId: json['noteId'] as String,
    noteTitle: json['noteTitle'] as String,
    exchanges: (json['exchanges'] as List<dynamic>)
        .map((e) => TeachMeExchange.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    isCompleted: json['isCompleted'] as bool? ?? false,
  );
}
