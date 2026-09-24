import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tigris/app/di/repository_scope.dart';
import 'package:tigris/models/note.dart';
import 'package:tigris/models/note_analysis.dart';
import 'package:tigris/persistence/in_memory_storage.dart';
import 'package:tigris/repositories/local_note_repository.dart';
import 'package:tigris/repositories/local_review_repository.dart';
import 'package:tigris/screens/note_detail_screen.dart';
import 'package:tigris/services/firebase_ai_service.dart';
import 'package:tigris/services/local_ai_service.dart';
import 'package:tigris/widgets/ai/note_analysis_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NoteAnalysis & UnknownTerm Models', () {
    test('Correctly deserializes strict JSON schema from Gemini', () {
      final jsonMap = {
        'title': 'The Law of Life in Christ Jesus',
        'date': 'September 24, 2026',
        'service': 'Sunday Service',
        'speaker': 'Pastor Chris',
        'topics': ['Faith', 'Life', 'Righteousness'],
        'keyPoints': [
          'The law of the spirit of life has freed us.',
          'Walk according to the spirit, not the flesh.',
        ],
        'unknownTerms': [
          {
            'term': 'H.E.Z.P.',
            'reason':
                'The abbreviation appears meaningful but its definition cannot be determined confidently from the note.',
          }
        ],
      };

      final analysis = NoteAnalysis.fromJson(jsonMap);

      expect(analysis.title, equals('The Law of Life in Christ Jesus'));
      expect(analysis.date, equals('September 24, 2026'));
      expect(analysis.service, equals('Sunday Service'));
      expect(analysis.speaker, equals('Pastor Chris'));
      expect(analysis.topics, equals(['Faith', 'Life', 'Righteousness']));
      expect(analysis.keyPoints.length, equals(2));
      expect(analysis.unknownTerms.length, equals(1));
      expect(analysis.unknownTerms.first.term, equals('H.E.Z.P.'));
      expect(
        analysis.unknownTerms.first.reason,
        contains('definition cannot be determined confidently'),
      );
    });

    test('Handles missing, null, or empty fields safely', () {
      final analysis = NoteAnalysis.fromJson({});

      expect(analysis.title, isEmpty);
      expect(analysis.date, isEmpty);
      expect(analysis.service, isEmpty);
      expect(analysis.speaker, isEmpty);
      expect(analysis.topics, isEmpty);
      expect(analysis.keyPoints, isEmpty);
      expect(analysis.unknownTerms, isEmpty);
      expect(analysis.isEmpty, isTrue);
    });
  });

  group('FirebaseAiService Unit Tests', () {
    test('Rejects empty content immediately with AiServiceException', () async {
      final service = FirebaseAiService();

      expect(
        () => service.analyzeNote(noteId: 'n1', content: '   '),
        throwsA(isA<AiServiceException>().having(
          (e) => e.message,
          'message',
          contains('cannot be empty'),
        )),
      );
    });

    test('Rejects unauthenticated request if not logged into Firebase', () async {
      final service = FirebaseAiService();

      expect(
        () => service.analyzeNote(noteId: 'n1', content: 'H.E.Z.P. spoke about faith.'),
        throwsA(isA<AiServiceException>().having(
          (e) => e.message,
          'message',
          contains('must be signed in'),
        )),
      );
    });
  });

  group('LocalAiService & Unknown Terms Heuristics', () {
    test('Flags unknown abbreviations like H.E.Z.P. in note content', () async {
      const localService = LocalAiService();
      final analysis = await localService.analyzeNote(
        noteId: 'test_note',
        content: 'H.E.Z.P. arrived at the auditorium and spoke on faith. HEZP taught the believers.',
      );

      expect(analysis.unknownTerms, isNotEmpty);
      final termNames = analysis.unknownTerms.map((u) => u.term).toList();
      expect(termNames, contains('H.E.Z.P.'));
      expect(
        analysis.unknownTerms.first.reason,
        contains('cannot be determined confidently'),
      );
    });
  });

  group('NoteAnalysisSheet Widget Tests', () {
    testWidgets('Renders structured fields and unknown terms properly', (tester) async {
      final mockService = _MockAiService(
        NoteAnalysis(
          title: 'Sunday Faith Convention',
          date: '2026-09-24',
          service: 'Sunday Morning Service',
          speaker: 'Pastor Felix',
          topics: ['Grace', 'Victory'],
          keyPoints: ['Walk in love always.', 'Stand firm in the truth.'],
          unknownTerms: [
            const UnknownTerm(
              term: 'H.E.Z.P.',
              reason: 'Abbreviation whose definition is not explained in the note.',
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteAnalysisSheet(
              noteId: 'note_1',
              noteTitle: 'Sunday Faith Convention',
              noteContent: 'H.E.Z.P. shared powerful words today.',
              aiService: mockService,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('UNDERSTAND NOTE'), findsOneWidget);
      expect(find.text('Sunday Faith Convention'), findsOneWidget);
      expect(find.text('Sunday Morning Service'), findsOneWidget);
      expect(find.text('Pastor Felix'), findsOneWidget);
      expect(find.text('Grace'), findsOneWidget);
      expect(find.text('Victory'), findsOneWidget);
      expect(find.text('Walk in love always.'), findsOneWidget);
      expect(find.text('H.E.Z.P.'), findsOneWidget);
      expect(find.textContaining('Abbreviation whose definition is not explained'), findsOneWidget);
    });

    testWidgets('Shows error message with retry button on failure', (tester) async {
      final failingService = _FailingAiService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteAnalysisSheet(
              noteId: 'note_1',
              noteTitle: 'Empty Note',
              noteContent: 'Testing error flow',
              aiService: failingService,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Analysis Notice'), findsOneWidget);
      expect(find.text('Simulated AI upstream failure'), findsOneWidget);
      expect(find.text('Retry Analysis'), findsOneWidget);
    });
  });

  group('NoteDetailScreen UNDERSTAND NOTE Button Integration', () {
    testWidgets('Tapping UNDERSTAND NOTE button opens analysis sheet', (tester) async {
      final storage = InMemoryStorage();
      final noteRepo = LocalNoteRepository(storage: storage);
      final reviewRepo = LocalReviewRepository(storage: storage);
      final mockService = _MockAiService(
        const NoteAnalysis(
          title: 'Notes from H.E.Z.P.',
          keyPoints: ['Living by the Word'],
          unknownTerms: [
            UnknownTerm(
              term: 'H.E.Z.P.',
              reason: 'Undefined abbreviation.',
            ),
          ],
        ),
      );

      final note = Note(
        id: 'test_n1',
        title: 'Sunday Service',
        content: 'H.E.Z.P. ministered on righteousness.',
        updatedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await noteRepo.saveNote(note);

      await tester.pumpWidget(
        MaterialApp(
          home: RepositoryScope(
            noteRepository: noteRepo,
            reviewRepository: reviewRepo,
            aiService: mockService,
            child: NoteDetailScreen(
              noteId: 'test_n1',
              initialNote: note,
              noteRepository: noteRepo,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the UNDERSTAND NOTE button is present
      final understandBtn = find.byKey(const Key('understand_note_button'));
      expect(understandBtn, findsOneWidget);

      // Tap UNDERSTAND NOTE
      await tester.tap(understandBtn);
      await tester.pumpAndSettle();

      // Verify the sheet opened and rendered analysis
      expect(find.text('UNDERSTAND NOTE'), findsWidgets);
      expect(find.text('Notes from H.E.Z.P.'), findsOneWidget);
      expect(find.text('H.E.Z.P.'), findsOneWidget);
    });
  });
}

class _MockAiService extends LocalAiService {
  final NoteAnalysis analysisResult;
  _MockAiService(this.analysisResult);

  @override
  Future<NoteAnalysis> analyzeNote({
    required String noteId,
    required String content,
  }) async {
    return analysisResult;
  }
}

class _FailingAiService extends LocalAiService {
  @override
  Future<NoteAnalysis> analyzeNote({
    required String noteId,
    required String content,
  }) async {
    throw const AiServiceException('Simulated AI upstream failure');
  }
}
