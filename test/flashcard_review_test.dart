import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tigris/app/di/repository_scope.dart';
import 'package:tigris/app/theme/app_theme.dart';
import 'package:tigris/models/flashcard.dart';
import 'package:tigris/models/note.dart';
import 'package:tigris/persistence/preferences_storage.dart';
import 'package:tigris/repositories/local_flashcard_repository.dart';
import 'package:tigris/repositories/local_note_repository.dart';
import 'package:tigris/repositories/local_review_repository.dart';
import 'package:tigris/screens/flashcard_review_screen.dart';
import 'package:tigris/screens/note_detail_screen.dart';
import 'package:tigris/services/local_ai_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestApp({
    required PreferencesStorage storage,
    required LocalNoteRepository noteRepo,
    required LocalReviewRepository reviewRepo,
    required LocalFlashcardRepository flashcardRepo,
    required Widget child,
  }) {
    return RepositoryScope(
      noteRepository: noteRepo,
      reviewRepository: reviewRepo,
      flashcardRepository: flashcardRepo,
      aiService: const LocalAiService(),
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: child,
      ),
    );
  }

  group('Phase 7 — Flashcard System Tests', () {
    testWidgets('FlashcardReviewScreen shows question, reveals answer, rates, advances, and completes', (tester) async {
      final storage = PreferencesStorage();
      final noteRepo = LocalNoteRepository(storage: storage);
      final reviewRepo = LocalReviewRepository(storage: storage);
      final flashcardRepo = LocalFlashcardRepository(storage: storage);

      final cards = [
        Flashcard(
          id: 'card_1',
          noteId: 'note_123',
          front: 'What is the primary thesis?',
          back: 'Focus on high leverage systems.',
          createdAt: DateTime.now(),
        ),
        Flashcard(
          id: 'card_2',
          noteId: 'note_123',
          front: 'What is the secondary principle?',
          back: 'Eliminate non-essential commitments.',
          createdAt: DateTime.now(),
        ),
      ];

      // Save to repository to verify persistence
      await flashcardRepo.saveFlashcards(cards);
      final retrieved = await flashcardRepo.getFlashcardsForNote('note_123');
      expect(retrieved.length, 2);

      await tester.pumpWidget(
        buildTestApp(
          storage: storage,
          noteRepo: noteRepo,
          reviewRepo: reviewRepo,
          flashcardRepo: flashcardRepo,
          child: FlashcardReviewScreen(
            flashcards: cards,
            noteId: 'note_123',
            noteTitle: 'Strategic Systems',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Card 1 header and question
      expect(find.text('CARD 1 OF 2'), findsOneWidget);
      expect(find.text('Strategic Systems'), findsOneWidget);
      expect(find.text('What is the primary thesis?'), findsOneWidget);
      // Answer should not be visible yet
      expect(find.text('Focus on high leverage systems.'), findsNothing);
      expect(find.byKey(const Key('show_answer_button')), findsOneWidget);

      // Tap Show answer
      await tester.tap(find.byKey(const Key('show_answer_button')));
      await tester.pumpAndSettle();

      // Answer now revealed
      expect(find.text('Focus on high leverage systems.'), findsOneWidget);
      expect(find.byKey(const Key('rate_again_button')), findsOneWidget);
      expect(find.byKey(const Key('rate_hard_button')), findsOneWidget);
      expect(find.byKey(const Key('rate_good_button')), findsOneWidget);
      expect(find.byKey(const Key('rate_easy_button')), findsOneWidget);

      // Rate "Good" on Card 1
      await tester.tap(find.byKey(const Key('rate_good_button')));
      await tester.pumpAndSettle();

      // Should now advance to Card 2
      expect(find.text('CARD 2 OF 2'), findsOneWidget);
      expect(find.text('What is the secondary principle?'), findsOneWidget);
      expect(find.text('Eliminate non-essential commitments.'), findsNothing);
      expect(find.byKey(const Key('show_answer_button')), findsOneWidget);

      // Tap Show answer for Card 2
      await tester.tap(find.byKey(const Key('show_answer_button')));
      await tester.pumpAndSettle();
      expect(find.text('Eliminate non-essential commitments.'), findsOneWidget);

      // Rate "Easy" on Card 2
      await tester.tap(find.byKey(const Key('rate_easy_button')));
      await tester.pumpAndSettle();

      // Should now show Completion Screen
      expect(find.text('Review complete'), findsOneWidget);
      expect(find.textContaining('You recalled 2 cards'), findsOneWidget);
      expect(find.byKey(const Key('review_done_button')), findsOneWidget);

      // Verify review items persisted in ReviewRepository
      final allReviews = await reviewRepo.getAllReviews();
      expect(allReviews.isNotEmpty, isTrue);

      // Tap Done
      await tester.tap(find.byKey(const Key('review_done_button')));
      await tester.pumpAndSettle();
    });

    testWidgets('Generating flashcards from NoteDetailScreen persists and launches review', (tester) async {
      final storage = PreferencesStorage();
      final noteRepo = LocalNoteRepository(storage: storage);
      final reviewRepo = LocalReviewRepository(storage: storage);
      final flashcardRepo = LocalFlashcardRepository(storage: storage);

      final note = Note(
        id: 'note_ai_fc',
        title: 'Deep Work Philosophy',
        content: 'Deep work is the ability to focus without distraction on a cognitively demanding task. It creates new value and improves skills.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await noteRepo.saveNote(note);

      await tester.pumpWidget(
        buildTestApp(
          storage: storage,
          noteRepo: noteRepo,
          reviewRepo: reviewRepo,
          flashcardRepo: flashcardRepo,
          child: NoteDetailScreen(
            noteId: note.id,
            initialNote: note,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open AI actions sheet
      expect(find.text('✦ AI'), findsOneWidget);
      await tester.tap(find.text('✦ AI'));
      await tester.pumpAndSettle();

      // Tap Create flashcards
      expect(find.text('Create flashcards'), findsOneWidget);
      await tester.tap(find.text('Create flashcards'));
      await tester.pumpAndSettle();

      // Verify Start Review button is present
      expect(find.byKey(const Key('start_flashcard_review_button')), findsOneWidget);

      // Verify flashcards were persisted to FlashcardRepository
      final savedCards = await flashcardRepo.getFlashcardsForNote(note.id);
      expect(savedCards.isNotEmpty, isTrue);

      // Tap Start Review
      await tester.tap(find.byKey(const Key('start_flashcard_review_button')));
      await tester.pumpAndSettle();

      // Review screen opens with Card 1
      expect(find.textContaining('CARD 1 OF'), findsOneWidget);
      expect(find.byKey(const Key('show_answer_button')), findsOneWidget);

      // Answer reveal and rate
      await tester.tap(find.byKey(const Key('show_answer_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rate_again_button')));
      await tester.pumpAndSettle();

      // Progressed to next card
      expect(find.textContaining('CARD 2 OF'), findsOneWidget);
    });
  });
}
