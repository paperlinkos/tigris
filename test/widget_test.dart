import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tigris/main.dart';
import 'package:tigris/models/note.dart';
import 'package:tigris/persistence/in_memory_storage.dart';
import 'package:tigris/repositories/local_note_repository.dart';
import 'package:tigris/repositories/local_review_repository.dart';
import 'package:tigris/services/review_scheduler_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('App Shell Smoke & Navigation Tests', () {
    testWidgets('App shell loads Review home by default with Phase 1 structure', (WidgetTester tester) async {
      await tester.pumpWidget(const PersonalLearningApp());
      await tester.pumpAndSettle();

      expect(find.textContaining('Good '), findsOneWidget);
      expect(find.text('New note'), findsOneWidget);
      expect(find.text('YOUR MEMORY'), findsOneWidget);
      expect(find.text('Nothing due for review.'), findsOneWidget);
      expect(find.text('RECENT NOTES'), findsOneWidget);
      expect(find.text('Review'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('Can navigate to Notes and Settings screens', (WidgetTester tester) async {
      await tester.pumpWidget(const PersonalLearningApp());
      await tester.pump();

      // Tap on Notes nav tab
      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();

      expect(find.text('NOTES'), findsOneWidget);
      expect(find.text('All thoughts start here.'), findsOneWidget);

      // Tap on Settings nav tab
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('SETTINGS'), findsOneWidget);
      expect(find.text('Preferences'), findsOneWidget);
    });
  });

  group('Model & Architecture Tests', () {
    test('Note model supports nested hierarchy & serialization', () {
      final parent = Note(
        id: 'parent_1',
        title: 'Stoic Principles',
        subtitle: 'Ancient reflections',
        content: 'Reflections on virtue',
        childrenIds: ['child_1'],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final child = Note(
        id: 'child_1',
        parentId: 'parent_1',
        title: 'Trichotomy of Control',
        content: 'Control what you can',
        createdAt: DateTime(2026, 1, 2),
        updatedAt: DateTime(2026, 1, 2),
      );

      expect(parent.isRoot, isTrue);
      expect(parent.hasChildren, isTrue);
      expect(child.isRoot, isFalse);
      expect(child.parentId, equals('parent_1'));

      final json = parent.toJson();
      final recovered = Note.fromJson(json);
      expect(recovered.title, equals(parent.title));
      expect(recovered.childrenIds, contains('child_1'));
    });

    test('LocalNoteRepository and InMemoryStorage CRUD work cleanly', () async {
      final storage = InMemoryStorage();
      final repo = LocalNoteRepository(storage: storage);

      final note = Note(
        id: 'note_test_1',
        title: 'Deep Work',
        content: 'Focus without distraction',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repo.saveNote(note);
      final fetched = await repo.getNote('note_test_1');

      expect(fetched, isNotNull);
      expect(fetched!.title, equals('Deep Work'));

      final roots = await repo.getRootNotes();
      expect(roots.length, equals(1));

      await repo.deleteNote('note_test_1');
      final afterDelete = await repo.getNote('note_test_1');
      expect(afterDelete, isNull);
    });

    test('ReviewSchedulerService and LocalReviewRepository calculate intervals', () async {
      final storage = InMemoryStorage();
      final repo = LocalReviewRepository(storage: storage);
      final scheduler = StandardReviewSchedulerService();

      final initial = scheduler.scheduleInitialReview(noteId: 'note_123');
      expect(initial.intervalDays, equals(1));
      expect(initial.repetitionCount, equals(0));

      await repo.saveReview(initial);
      final allReviews = await repo.getAllReviews();
      expect(allReviews.length, equals(1));

      // Simulate successful recall (rating 5)
      final updated = scheduler.scheduleNextReview(currentItem: initial, rating: 5);
      expect(updated.repetitionCount, equals(1));
      expect(updated.intervalDays, equals(1));
      expect(updated.easeFactor, greaterThanOrEqualTo(2.5));
    });
  });
}
