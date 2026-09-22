import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tigris/app/di/repository_scope.dart';
import 'package:tigris/app/navigation/app_shell.dart';
import 'package:tigris/app/theme/app_theme.dart';
import 'package:tigris/models/flashcard.dart';
import 'package:tigris/models/note.dart';
import 'package:tigris/models/review_item.dart';
import 'package:tigris/persistence/preferences_storage.dart';
import 'package:tigris/repositories/local_flashcard_repository.dart';
import 'package:tigris/repositories/local_note_repository.dart';
import 'package:tigris/repositories/local_review_repository.dart';
import 'package:tigris/screens/home_screen.dart';
import 'package:tigris/screens/review_session_screen.dart';
import 'package:tigris/services/review_scheduler_service.dart';

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
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: child,
      ),
    );
  }

  group('Phase 10 & 11 — Review Engine and Memory-Driven Home Tests', () {
    test('StandardReviewSchedulerService computes correct SM-2 intervals for all ratings', () {
      const scheduler = StandardReviewSchedulerService();

      final initial = scheduler.scheduleInitialReview(noteId: 'test_note');
      expect(initial.intervalDays, 1);
      expect(initial.repetitionCount, 0);
      expect(initial.easeFactor, 2.5);

      // Again (rating = 1) -> resets interval to 1
      final afterAgain = scheduler.scheduleNextReview(currentItem: initial, rating: 1);
      expect(afterAgain.intervalDays, 1);
      expect(afterAgain.repetitionCount, 0);
      expect(afterAgain.easeFactor, lessThan(2.5));

      // Good (rating = 4) on initial item -> repetition 1, interval 1
      final afterGood1 = scheduler.scheduleNextReview(currentItem: initial, rating: 4);
      expect(afterGood1.repetitionCount, 1);
      expect(afterGood1.intervalDays, 1);

      // Good (rating = 4) on second review -> repetition 2, interval 6
      final afterGood2 = scheduler.scheduleNextReview(currentItem: afterGood1, rating: 4);
      expect(afterGood2.repetitionCount, 2);
      expect(afterGood2.intervalDays, 6);

      // Easy (rating = 5) on third review -> interval = (6 * easeFactor) > 6
      final afterEasy3 = scheduler.scheduleNextReview(currentItem: afterGood2, rating: 5);
      expect(afterEasy3.repetitionCount, 3);
      expect(afterEasy3.intervalDays, greaterThan(6));
    });

    testWidgets('ReviewSessionScreen empty state displays calm zero-due screen', (tester) async {
      final storage = PreferencesStorage();
      final noteRepo = LocalNoteRepository(storage: storage);
      final reviewRepo = LocalReviewRepository(storage: storage);
      final flashcardRepo = LocalFlashcardRepository(storage: storage);

      await tester.pumpWidget(
        buildTestApp(
          storage: storage,
          noteRepo: noteRepo,
          reviewRepo: reviewRepo,
          flashcardRepo: flashcardRepo,
          child: const ReviewSessionScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nothing due for review'), findsOneWidget);
      expect(find.byKey(const Key('return_home_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('return_home_button')));
      await tester.pumpAndSettle();
    });

    testWidgets('ReviewSessionScreen reviews real queue, reveals answer, rates, and completes', (tester) async {
      final storage = PreferencesStorage();
      final noteRepo = LocalNoteRepository(storage: storage);
      final reviewRepo = LocalReviewRepository(storage: storage);
      final flashcardRepo = LocalFlashcardRepository(storage: storage);

      final note = Note(
        id: 'note_mem_1',
        title: 'Stoic Principles',
        subtitle: 'Ancient Wisdom for Modern Agency',
        content: 'Focus only on what is within your direct sphere of control.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await noteRepo.saveNote(note);

      final card = Flashcard(
        id: 'card_stoic_1',
        noteId: note.id,
        front: 'What is the dichotomy of control?',
        back: 'Distinguishing between what is up to us and what is not.',
        createdAt: DateTime.now(),
      );
      await flashcardRepo.saveFlashcard(card);

      // Seed a due review item for this note
      final dueItem = ReviewItem(
        id: 'rev_due_1',
        noteId: note.id,
        dueAt: DateTime.now().subtract(const Duration(hours: 2)), // overdue
        intervalDays: 1,
        repetitionCount: 0,
        easeFactor: 2.5,
      );
      await reviewRepo.saveReview(dueItem);

      await tester.pumpWidget(
        buildTestApp(
          storage: storage,
          noteRepo: noteRepo,
          reviewRepo: reviewRepo,
          flashcardRepo: flashcardRepo,
          child: const ReviewSessionScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verified active item
      expect(find.text('REVIEW 1 OF 1'), findsOneWidget);
      expect(find.text('Stoic Principles'), findsOneWidget);
      expect(find.text('What is the dichotomy of control?'), findsOneWidget);
      expect(find.byKey(const Key('review_session_show_answer')), findsOneWidget);

      // Reveal answer
      await tester.tap(find.byKey(const Key('review_session_show_answer')));
      await tester.pumpAndSettle();

      expect(find.text('Distinguishing between what is up to us and what is not.'), findsOneWidget);
      expect(find.byKey(const Key('rate_good_button')), findsOneWidget);

      // Rate Good
      await tester.tap(find.byKey(const Key('rate_good_button')));
      await tester.pumpAndSettle();

      // Summary screen
      expect(find.text('Review complete'), findsOneWidget);
      expect(find.textContaining('You reviewed 1 item'), findsOneWidget);
      expect(find.byKey(const Key('review_session_done_button')), findsOneWidget);

      // Verify item updated in repository (interval updated, dueAt pushed into the future)
      final updated = await reviewRepo.getReviewForNote(note.id);
      expect(updated, isNotNull);
      expect(updated!.repetitionCount, 1);
      expect(updated.dueAt.isAfter(DateTime.now()), isTrue);
    });

    testWidgets('Home screen transitions: empty -> populated reviews -> launch review -> empty again', (tester) async {
      final storage = PreferencesStorage();
      final noteRepo = LocalNoteRepository(storage: storage);
      final reviewRepo = LocalReviewRepository(storage: storage);
      final flashcardRepo = LocalFlashcardRepository(storage: storage);

      // Initially empty
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: AppShell(
            storage: storage,
            noteRepository: noteRepo,
            reviewRepository: reviewRepo,
            flashcardRepository: flashcardRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Home shows "Nothing due for review."
      expect(find.text('YOUR MEMORY'), findsOneWidget);
      expect(find.text('Nothing due for review.'), findsOneWidget);

      // Create a note and a due review
      final note = Note(
        id: 'home_note_test',
        title: 'Capital Allocation',
        subtitle: 'Principles of compounding',
        content: 'Long term horizons reward patient conviction.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await noteRepo.saveNote(note);

      final reviewItem = ReviewItem(
        id: 'rev_home_1',
        noteId: note.id,
        dueAt: DateTime.now().subtract(const Duration(minutes: 5)),
        intervalDays: 1,
        repetitionCount: 0,
        easeFactor: 2.5,
      );
      await reviewRepo.saveReview(reviewItem);

      // Reload Home
      final homeState = tester.state<HomeScreenState>(find.byType(HomeScreen));
      await homeState.reload();
      await tester.pumpAndSettle();

      // Home now shows real count and review button
      expect(find.text('1 item due today'), findsOneWidget);
      expect(find.byKey(const Key('start_review_button')), findsOneWidget);

      // Continue learning displays this recent note
      expect(find.text('CONTINUE LEARNING'), findsOneWidget);
      expect(find.text('Capital Allocation'), findsWidgets);

      // Tap start review
      await tester.tap(find.byKey(const Key('start_review_button')));
      await tester.pumpAndSettle();

      // Now inside ReviewSessionScreen
      expect(find.text('REVIEW 1 OF 1'), findsOneWidget);
      await tester.tap(find.byKey(const Key('review_session_show_answer')));
      await tester.pumpAndSettle();

      // Rate Easy
      await tester.tap(find.byKey(const Key('rate_easy_button')));
      await tester.pumpAndSettle();

      // Return Home
      expect(find.byKey(const Key('review_session_done_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('review_session_done_button')));
      await tester.pumpAndSettle();

      // Home is now clear again!
      expect(find.text('Nothing due for review.'), findsOneWidget);
    });
  });
}
