import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tigris/app/di/repository_scope.dart';
import 'package:tigris/app/theme/app_theme.dart';
import 'package:tigris/models/note.dart';
import 'package:tigris/persistence/in_memory_storage.dart';
import 'package:tigris/repositories/local_note_repository.dart';
import 'package:tigris/repositories/local_review_repository.dart';
import 'package:tigris/screens/notes_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 4 — Note Discovery & Search Tests', () {
    test('searchNotes in LocalNoteRepository finds matches across title, subtitle, and content', () async {
      final storage = InMemoryStorage();
      final repo = LocalNoteRepository(storage: storage);

      await repo.saveNote(Note(
        id: 'n1',
        title: 'Quantum Computing Foundations',
        subtitle: 'Qubits and Entanglement',
        content: 'Superposition principle and gate operations.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await repo.saveNote(Note(
        id: 'n2',
        title: 'Stoic Meditations',
        subtitle: 'Daily morning journaling',
        content: 'Reflect upon virtue, wisdom, and temperance.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await repo.saveNote(Note(
        id: 'n3',
        parentId: 'n1',
        title: 'Shor Algorithm',
        subtitle: 'Quantum prime factorization',
        content: 'Exponential speedup over classical RSA algorithms.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // 1. Search by title keyword
      final titleMatches = await repo.searchNotes('Quantum');
      expect(titleMatches.length, equals(2)); // n1 and n3

      // 2. Search by subtitle keyword
      final subtitleMatches = await repo.searchNotes('journaling');
      expect(subtitleMatches.length, equals(1));
      expect(subtitleMatches.first.id, equals('n2'));

      // 3. Search by body content keyword
      final contentMatches = await repo.searchNotes('exponential speedup');
      expect(contentMatches.length, equals(1));
      expect(contentMatches.first.id, equals('n3'));

      // 4. Case insensitivity and special characters
      final caseMatches = await repo.searchNotes('QuBiTs');
      expect(caseMatches.length, equals(1));
      expect(caseMatches.first.id, equals('n1'));

      // 5. Empty query returns empty list
      expect(await repo.searchNotes('   '), isEmpty);

      // 6. Non-matching query returns empty list
      expect(await repo.searchNotes('unrelated query'), isEmpty);
    });

    testWidgets('Interactive search UI dynamically filters and opens notes', (WidgetTester tester) async {
      final storage = InMemoryStorage();
      final noteRepo = LocalNoteRepository(storage: storage);
      final reviewRepo = LocalReviewRepository(storage: storage);

      // Root note 1
      await noteRepo.saveNote(Note(
        id: 'r_business',
        title: 'Business Architecture',
        subtitle: 'Enterprise scaling strategy',
        content: 'Focus on high-leverage organizational habits.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Deeply nested child note
      await noteRepo.saveNote(Note(
        id: 'c_smart_q',
        parentId: 'r_business',
        title: 'Smart Q Estates',
        subtitle: 'PropTech platform',
        content: 'Service apartments reservation infrastructure.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: RepositoryScope(
            noteRepository: noteRepo,
            reviewRepository: reviewRepo,
            child: const NotesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify search input is present
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Business Architecture'), findsOneWidget);

      // Enter query matching deeply nested child note
      await tester.enterText(find.byType(TextField), 'PropTech');
      await tester.pumpAndSettle();

      // Verify search results header and item
      expect(find.text('1 RESULT'), findsOneWidget);
      expect(find.text('Smart Q Estates'), findsOneWidget);
      expect(find.text('PropTech platform'), findsOneWidget);

      // Tap search result to open NoteDetailScreen
      await tester.tap(find.text('Smart Q Estates'));
      await tester.pumpAndSettle();

      // Verify note detail editor opened for the searched note
      expect(find.text('Service apartments reservation infrastructure.'), findsOneWidget);

      // Pop back to NotesScreen
      await tester.tap(find.byType(IconButton).first);
      await tester.pumpAndSettle();

      // Clear search query
      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pumpAndSettle();

      // Verify returned to hierarchy root list
      expect(find.text('Business Architecture'), findsOneWidget);

      // Search non-existing query
      await tester.enterText(find.byType(TextField), 'nonexistent topic xyz');
      await tester.pumpAndSettle();

      expect(find.text('No matches found.'), findsOneWidget);
      expect(find.textContaining('No notes match "nonexistent topic xyz"'), findsOneWidget);
    });
  });
}
