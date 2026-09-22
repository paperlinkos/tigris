import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tigris/app/di/repository_scope.dart';
import 'package:tigris/app/theme/app_theme.dart';
import 'package:tigris/models/note.dart';
import 'package:tigris/models/review_item.dart';
import 'package:tigris/persistence/in_memory_storage.dart';
import 'package:tigris/repositories/local_note_repository.dart';
import 'package:tigris/repositories/local_review_repository.dart';
import 'package:tigris/screens/home_screen.dart';

void main() {
  group('HomeScreen Tests', () {
    testWidgets('Renders greeting, empty memory state, and empty notes state', (WidgetTester tester) async {
      final storage = InMemoryStorage();
      final noteRepo = LocalNoteRepository(storage: storage);
      final reviewRepo = LocalReviewRepository(storage: storage);

      bool createNoteTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: RepositoryScope(
            noteRepository: noteRepo,
            reviewRepository: reviewRepo,
            child: HomeScreen(
              onCreateNote: () {
                createNoteTapped = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Greeting & Primary Action
      expect(find.textContaining('Good '), findsOneWidget);
      expect(find.text('New note'), findsOneWidget);

      // Verify Section 1: YOUR MEMORY (Empty State)
      expect(find.text('YOUR MEMORY'), findsOneWidget);
      expect(find.text('Nothing due for review.'), findsOneWidget);
      expect(find.text('Ideas scheduled for active recall will surface here.'), findsOneWidget);

      // Verify Section 3: RECENT NOTES (Empty State)
      expect(find.text('RECENT NOTES'), findsOneWidget);
      expect(find.text('Your notes will appear here.'), findsOneWidget);
      expect(find.text('Create your first note'), findsOneWidget);

      // Tap Primary "+ New note" action
      await tester.tap(find.text('New note'));
      await tester.pump();
      expect(createNoteTapped, isTrue);

      // Tap "Create your first note" text action
      createNoteTapped = false;
      await tester.tap(find.text('Create your first note'));
      await tester.pump();
      expect(createNoteTapped, isTrue);
    });

    testWidgets('Renders items when real data exists in repositories', (WidgetTester tester) async {
      final storage = InMemoryStorage();
      final noteRepo = LocalNoteRepository(storage: storage);
      final reviewRepo = LocalReviewRepository(storage: storage);

      // Seed 1 real note and 1 real review item
      await noteRepo.saveNote(
        Note(
          id: 'note_1',
          title: 'Epictetus Enchiridion',
          subtitle: 'Core precepts on freedom',
          content: 'Some things are in our control...',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await reviewRepo.saveReview(
        ReviewItem(
          id: 'rev_1',
          noteId: 'note_1',
          dueAt: DateTime.now().subtract(const Duration(hours: 1)),
          intervalDays: 1,
        ),
      );

      bool reviewNowTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: RepositoryScope(
            noteRepository: noteRepo,
            reviewRepository: reviewRepo,
            child: HomeScreen(
              onCreateNote: () {},
              onStartReview: () {
                reviewNowTapped = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Section 1 should show due item count and Review now button
      expect(find.text('1 item due today'), findsOneWidget);
      expect(find.text('Review now'), findsOneWidget);

      await tester.tap(find.text('Review now'));
      await tester.pump();
      expect(reviewNowTapped, isTrue);

      // Section 2: Continue Learning displays the in-progress note
      expect(find.text('CONTINUE LEARNING'), findsOneWidget);

      // Section 3: Recent Notes lists the note
      expect(find.text('Epictetus Enchiridion'), findsNWidgets(2)); // continue learning + recent notes
      expect(find.text('Core precepts on freedom'), findsNWidgets(2));
    });
  });
}
