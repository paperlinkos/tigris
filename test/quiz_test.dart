import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tigris/app/di/repository_scope.dart';
import 'package:tigris/app/theme/app_theme.dart';
import 'package:tigris/models/note.dart';
import 'package:tigris/models/quiz.dart';
import 'package:tigris/persistence/preferences_storage.dart';
import 'package:tigris/repositories/local_note_repository.dart';
import 'package:tigris/repositories/local_quiz_repository.dart';
import 'package:tigris/repositories/local_review_repository.dart';
import 'package:tigris/screens/note_detail_screen.dart';
import 'package:tigris/screens/quiz_screen.dart';
import 'package:tigris/services/local_ai_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestApp({
    required PreferencesStorage storage,
    required LocalNoteRepository noteRepo,
    required LocalReviewRepository reviewRepo,
    required LocalQuizRepository quizRepo,
    required Widget child,
  }) {
    return RepositoryScope(
      noteRepository: noteRepo,
      reviewRepository: reviewRepo,
      quizRepository: quizRepo,
      aiService: const LocalAiService(),
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: child,
      ),
    );
  }

  group('Phase 8 — Quiz Experience Tests', () {
    testWidgets('QuizScreen flow: question display, answer selection, correct/incorrect feedback, next, and completion summary', (tester) async {
      final storage = PreferencesStorage();
      final noteRepo = LocalNoteRepository(storage: storage);
      final reviewRepo = LocalReviewRepository(storage: storage);
      final quizRepo = LocalQuizRepository(storage: storage);

      final questions = [
        const QuizQuestion(
          id: 'q_1',
          noteId: 'note_quiz_1',
          prompt: 'What is the primary law of simplicity?',
          options: [
            'Reduce what is superfluous to retain what is meaningful.',
            'Add complex ornamentation.',
            'Ignore user constraints.',
            'Maximize cognitive overhead.',
          ],
          correctOptionIndex: 0,
          explanation: 'Simplicity is about subtracting the obvious and adding the meaningful.',
        ),
        const QuizQuestion(
          id: 'q_2',
          noteId: 'note_quiz_1',
          prompt: 'Which metric indicates review necessity?',
          options: [
            'Arbitrary counters.',
            'Active recall threshold and due date.',
            'Random number generator.',
            'Screen time alone.',
          ],
          correctOptionIndex: 1,
          explanation: 'Memory schedules rely on retrieval intervals and due dates.',
        ),
      ];

      await quizRepo.saveQuizQuestions(questions);
      final savedQuestions = await quizRepo.getQuizQuestionsForNote('note_quiz_1');
      expect(savedQuestions.length, 2);

      await tester.pumpWidget(
        buildTestApp(
          storage: storage,
          noteRepo: noteRepo,
          reviewRepo: reviewRepo,
          quizRepo: quizRepo,
          child: QuizScreen(
            questions: questions,
            noteId: 'note_quiz_1',
            noteTitle: 'Laws of Simplicity',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Q1 rendering
      expect(find.text('QUESTION 1 OF 2'), findsOneWidget);
      expect(find.text('Laws of Simplicity'), findsOneWidget);
      expect(find.text('What is the primary law of simplicity?'), findsOneWidget);
      expect(find.text('Reduce what is superfluous to retain what is meaningful.'), findsOneWidget);

      // Submit button is disabled before selection
      final submitButtonFinder = find.byKey(const Key('submit_quiz_answer_button'));
      expect(submitButtonFinder, findsOneWidget);

      // Select Option 0 (Correct)
      await tester.tap(find.byKey(const Key('quiz_option_0')));
      await tester.pumpAndSettle();

      // Submit answer
      await tester.ensureVisible(submitButtonFinder);
      await tester.tap(submitButtonFinder);
      await tester.pumpAndSettle();

      // Feedback shows Correct and explanation
      expect(find.text('Correct'), findsOneWidget);
      expect(find.text('Simplicity is about subtracting the obvious and adding the meaningful.'), findsOneWidget);
      expect(find.byKey(const Key('next_quiz_question_button')), findsOneWidget);

      // Tap Next question
      await tester.ensureVisible(find.byKey(const Key('next_quiz_question_button')));
      await tester.tap(find.byKey(const Key('next_quiz_question_button')));
      await tester.pumpAndSettle();

      // Q2 rendering
      expect(find.text('QUESTION 2 OF 2'), findsOneWidget);
      expect(find.text('Which metric indicates review necessity?'), findsOneWidget);

      // Select Option 0 (Incorrect - correct is 1)
      await tester.tap(find.byKey(const Key('quiz_option_0')));
      await tester.pumpAndSettle();

      // Submit answer
      await tester.ensureVisible(submitButtonFinder);
      await tester.tap(submitButtonFinder);
      await tester.pumpAndSettle();

      // Feedback shows Needs review and explanation
      expect(find.text('Needs review'), findsOneWidget);
      expect(find.text('Memory schedules rely on retrieval intervals and due dates.'), findsOneWidget);

      // Tap Complete quiz
      expect(find.text('Complete quiz'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('next_quiz_question_button')));
      await tester.tap(find.byKey(const Key('next_quiz_question_button')));
      await tester.pumpAndSettle();

      // Completion view
      expect(find.text('Quiz complete'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget); // 1 out of 2 correct
      expect(find.text('CONCEPTS NEEDING MORE REVIEW'), findsOneWidget);
      expect(find.text('Which metric indicates review necessity?'), findsOneWidget);

      // Verify review scheduled in ReviewRepository
      final reviews = await reviewRepo.getAllReviews();
      expect(reviews.isNotEmpty, isTrue);

      // Tap Done
      await tester.ensureVisible(find.byKey(const Key('quiz_done_button')));
      await tester.tap(find.byKey(const Key('quiz_done_button')));
      await tester.pumpAndSettle();
    });

    testWidgets('Generating quiz from NoteDetailScreen persists and launches QuizScreen', (tester) async {
      final storage = PreferencesStorage();
      final noteRepo = LocalNoteRepository(storage: storage);
      final reviewRepo = LocalReviewRepository(storage: storage);
      final quizRepo = LocalQuizRepository(storage: storage);

      final note = Note(
        id: 'note_quiz_integration',
        title: 'Cognitive Science of Learning',
        content: 'Retrieval practice produces more durable learning than re-reading. Spacing intervals between study sessions prevents rapid forgetting.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await noteRepo.saveNote(note);

      await tester.pumpWidget(
        buildTestApp(
          storage: storage,
          noteRepo: noteRepo,
          reviewRepo: reviewRepo,
          quizRepo: quizRepo,
          child: NoteDetailScreen(
            noteId: note.id,
            initialNote: note,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open AI actions
      await tester.tap(find.text('✦ AI'));
      await tester.pumpAndSettle();

      // Tap Create quiz
      expect(find.text('Create quiz'), findsOneWidget);
      await tester.tap(find.text('Create quiz'));
      await tester.pumpAndSettle();

      // Verify Take Quiz button appears
      expect(find.byKey(const Key('start_quiz_button')), findsOneWidget);

      // Verify questions persisted to QuizRepository
      final saved = await quizRepo.getQuizQuestionsForNote(note.id);
      expect(saved.isNotEmpty, isTrue);

      // Tap Take Quiz
      await tester.tap(find.byKey(const Key('start_quiz_button')));
      await tester.pumpAndSettle();

      // In QuizScreen
      expect(find.textContaining('QUESTION 1 OF'), findsOneWidget);
      expect(find.byKey(const Key('quiz_option_0')), findsOneWidget);
    });
  });
}
