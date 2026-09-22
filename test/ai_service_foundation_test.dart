import 'package:flutter_test/flutter_test.dart';
import 'package:tigris/models/ai_responses.dart';
import 'package:tigris/models/flashcard.dart';
import 'package:tigris/models/quiz.dart';
import 'package:tigris/services/local_ai_service.dart';

void main() {
  group('Phase 5 — AI Service Foundation Tests', () {
    const sampleContent =
        'The principle of cognitive reframing allows individuals to identify and challenge irrational or maladaptive thoughts. '
        'By consciously altering cognitive distortions, emotional regulation and psychological resilience are significantly enhanced.';

    test('summarizeNote returns structured AiSummaryResponse', () async {
      const service = LocalAiService();
      final response = await service.summarizeNote(noteContent: sampleContent);

      expect(response, isA<AiSummaryResponse>());
      expect(response.summary.isNotEmpty, isTrue);
      expect(response.keyPoints.isNotEmpty, isTrue);
      expect(response.summary, contains('cognitive reframing'));
    });

    test('generateFlashcards returns structured Flashcards grounded in content', () async {
      const service = LocalAiService();
      final flashcards = await service.generateFlashcards(
        noteId: 'note_ai_1',
        noteContent: sampleContent,
      );

      expect(flashcards, isA<List<Flashcard>>());
      expect(flashcards.length, greaterThanOrEqualTo(1));
      expect(flashcards.first.noteId, equals('note_ai_1'));
      expect(flashcards.first.front.isNotEmpty, isTrue);
      expect(flashcards.first.back.isNotEmpty, isTrue);
    });

    test('generateQuiz returns structured QuizQuestions with options and explanations', () async {
      const service = LocalAiService();
      final quiz = await service.generateQuiz(
        noteId: 'note_ai_1',
        noteContent: sampleContent,
      );

      expect(quiz, isA<List<QuizQuestion>>());
      expect(quiz.length, greaterThanOrEqualTo(1));
      expect(quiz.first.noteId, equals('note_ai_1'));
      expect(quiz.first.options.length, equals(4));
      expect(quiz.first.correctOptionIndex, equals(0));
      expect(quiz.first.explanation, isNotNull);
    });

    test('explainNote returns accessible simplified concepts', () async {
      const service = LocalAiService();
      final explanation = await service.explainNote(noteContent: sampleContent);

      expect(explanation, isA<AiExplainResponse>());
      expect(explanation.explanation, contains('In simple terms'));
      expect(explanation.simplifiedConcepts.isNotEmpty, isTrue);
    });

    test('generateTeachMeSession and submitTeachMeAnswer manage dialogue flow', () async {
      const service = LocalAiService();
      final session = await service.generateTeachMeSession(
        noteId: 'note_ai_1',
        noteTitle: 'Cognitive Reframing',
        noteContent: sampleContent,
      );

      expect(session, isA<TeachMeSession>());
      expect(session.noteTitle, equals('Cognitive Reframing'));
      expect(session.exchanges.length, equals(1));
      expect(session.exchanges.first.question, contains('In your own words'));
      expect(session.isCompleted, isFalse);

      // Round 1: Submit user answer
      final round1 = await service.submitTeachMeAnswer(
        session: session,
        userAnswer: 'It is about reframing distortions to improve resilience.',
      );

      expect(round1.exchanges.first.userAnswer, isNotNull);
      expect(round1.exchanges.first.feedback, isNotNull);
      expect(round1.exchanges.length, equals(2)); // Added follow-up question
      expect(round1.isCompleted, isFalse);

      // Round 2: Complete dialogue
      final round2 = await service.submitTeachMeAnswer(
        session: round1,
        userAnswer: 'I would pause when experiencing anxiety and examine the evidence.',
      );

      expect(round2.isCompleted, isTrue);
    });

    test('Handles simulated failure and enables retry', () async {
      const failingService = LocalAiService(shouldSimulateFailure: true);
      expect(
        () => failingService.summarizeNote(noteContent: sampleContent),
        throwsA(isA<Exception>()),
      );

      // Recover on retry with working service
      const healthyService = LocalAiService(shouldSimulateFailure: false);
      final response = await healthyService.summarizeNote(noteContent: sampleContent);
      expect(response.summary, isNotEmpty);
    });

    test('Rejects empty content without silent modification', () async {
      const service = LocalAiService();
      expect(
        () => service.summarizeNote(noteContent: '   '),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => service.generateFlashcards(noteId: 'n', noteContent: ''),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
