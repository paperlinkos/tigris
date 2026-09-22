import '../models/ai_responses.dart';
import '../models/flashcard.dart';
import '../models/quiz.dart';
import 'ai_service.dart';

class LocalAiService implements AiService {
  final bool shouldSimulateFailure;

  const LocalAiService({this.shouldSimulateFailure = false});

  void _checkFailure() {
    if (shouldSimulateFailure) {
      throw Exception('AI service is temporarily unavailable. Please retry.');
    }
  }

  List<String> _extractSentences(String content) {
    return content
        .split(RegExp(r'(?<=[.!?])\s+|\n+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.length > 5)
        .toList();
  }

  @override
  Future<AiSummaryResponse> summarizeNote({required String noteContent}) async {
    _checkFailure();
    final clean = noteContent.trim();
    if (clean.isEmpty) {
      throw ArgumentError('Note content cannot be empty.');
    }

    final sentences = _extractSentences(clean);
    if (sentences.isEmpty) {
      return AiSummaryResponse(
        summary: clean,
        keyPoints: [clean],
      );
    }

    final summary = sentences.take(2).join(' ');
    final keyPoints = sentences.take(4).toList();

    return AiSummaryResponse(
      summary: summary,
      keyPoints: keyPoints,
    );
  }

  @override
  Future<List<Flashcard>> generateFlashcards({
    required String noteId,
    required String noteContent,
  }) async {
    _checkFailure();
    final clean = noteContent.trim();
    if (clean.isEmpty) {
      throw ArgumentError('Note content cannot be empty.');
    }

    final sentences = _extractSentences(clean);
    final cards = <Flashcard>[];

    for (int i = 0; i < sentences.length; i++) {
      final sentence = sentences[i];
      // Create QA pairs from sentence structure
      cards.add(
        Flashcard(
          id: 'card_${noteId}_$i',
          noteId: noteId,
          front: 'What is the core idea regarding: "${sentence.length > 40 ? sentence.substring(0, 40) : sentence}..."?',
          back: sentence,
          createdAt: DateTime.now(),
        ),
      );
      if (cards.length >= 5) break;
    }

    if (cards.isEmpty) {
      cards.add(
        Flashcard(
          id: 'card_${noteId}_0',
          noteId: noteId,
          front: 'What does this note reflect on?',
          back: clean,
          createdAt: DateTime.now(),
        ),
      );
    }

    return cards;
  }

  @override
  Future<List<QuizQuestion>> generateQuiz({
    required String noteId,
    required String noteContent,
  }) async {
    _checkFailure();
    final clean = noteContent.trim();
    if (clean.isEmpty) {
      throw ArgumentError('Note content cannot be empty.');
    }

    final sentences = _extractSentences(clean);
    final questions = <QuizQuestion>[];

    for (int i = 0; i < sentences.length; i++) {
      final sentence = sentences[i];
      final prompt = 'Which statement best reflects the concept discussed in: "${sentence.length > 35 ? sentence.substring(0, 35) : sentence}..."?';
      final options = [
        sentence,
        'An unrelated assertion contrary to the text.',
        'A distraction premise not supported by the notes.',
        'A generic statement with no correlation to the topic.',
      ];

      questions.add(
        QuizQuestion(
          id: 'quiz_${noteId}_$i',
          noteId: noteId,
          prompt: prompt,
          options: options,
          correctOptionIndex: 0,
          explanation: 'Directly grounded in the source note: "$sentence"',
        ),
      );
      if (questions.length >= 4) break;
    }

    if (questions.isEmpty) {
      questions.add(
        QuizQuestion(
          id: 'quiz_${noteId}_0',
          noteId: noteId,
          prompt: 'What is the key takeaway of this reflection?',
          options: [
            clean,
            'Opposite conclusion',
            'Unrelated concept',
            'None of the above',
          ],
          correctOptionIndex: 0,
          explanation: 'Directly drawn from your writing.',
        ),
      );
    }

    return questions;
  }

  @override
  Future<AiExplainResponse> explainNote({required String noteContent}) async {
    _checkFailure();
    final clean = noteContent.trim();
    if (clean.isEmpty) {
      throw ArgumentError('Note content cannot be empty.');
    }

    final sentences = _extractSentences(clean);
    final explanation = sentences.isNotEmpty
        ? 'In simple terms: ${sentences.first}'
        : 'In simple terms: $clean';

    final concepts = sentences.map((s) => '• $s').take(3).toList();

    return AiExplainResponse(
      explanation: explanation,
      simplifiedConcepts: concepts,
    );
  }

  @override
  Future<TeachMeSession> generateTeachMeSession({
    required String noteId,
    required String noteTitle,
    required String noteContent,
  }) async {
    _checkFailure();
    final clean = noteContent.trim();
    if (clean.isEmpty) {
      throw ArgumentError('Note content cannot be empty.');
    }

    final sentences = _extractSentences(clean);
    final firstQuestion = sentences.isNotEmpty
        ? 'Let\'s see what you remember about "$noteTitle". In your own words, what does the note discuss regarding "${sentences.first.length > 30 ? sentences.first.substring(0, 30) : sentences.first}..."?'
        : 'In your own words, how would you explain the core thought of "$noteTitle"?';

    return TeachMeSession(
      sessionId: 'teach_${noteId}_${DateTime.now().millisecondsSinceEpoch}',
      noteId: noteId,
      noteTitle: noteTitle,
      exchanges: [
        TeachMeExchange(question: firstQuestion),
      ],
      isCompleted: false,
    );
  }

  @override
  Future<TeachMeSession> submitTeachMeAnswer({
    required TeachMeSession session,
    required String userAnswer,
  }) async {
    _checkFailure();
    final cleanAnswer = userAnswer.trim();
    if (cleanAnswer.isEmpty) {
      throw ArgumentError('Answer cannot be empty.');
    }

    final currentExchanges = List<TeachMeExchange>.from(session.exchanges);
    final lastIndex = currentExchanges.length - 1;
    final lastExchange = currentExchanges[lastIndex];

    final updatedLast = lastExchange.copyWith(
      userAnswer: cleanAnswer,
      feedback: 'Great retrieval. You touched on the key aspects from your notes.',
      isUnderstood: true,
    );
    currentExchanges[lastIndex] = updatedLast;

    // Conclude after 2 rounds of retrieval
    if (currentExchanges.length >= 2) {
      return session.copyWith(
        exchanges: currentExchanges,
        isCompleted: true,
      );
    }

    // Add follow-up question
    currentExchanges.add(
      const TeachMeExchange(
        question: 'Follow-up: How would you apply this principle in a practical scenario?',
      ),
    );

    return session.copyWith(
      exchanges: currentExchanges,
      isCompleted: false,
    );
  }
}
