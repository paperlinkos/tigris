import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tigris/models/note.dart';
import 'package:tigris/services/idea_chat_service.dart';
import 'package:tigris/widgets/ideas/brainstorm_panel.dart';

class _Credentials implements IdeaChatCredentials {
  IdeaChatSettings settings = IdeaChatSettings.openRouter;
  String? key = 'secret';
  @override
  Future<void> clear() async {
    key = null;
  }

  @override
  Future<String?> loadKey() async => key;
  @override
  Future<IdeaChatSettings> loadSettings() async => settings;
  @override
  Future<void> save(IdeaChatSettings next, String apiKey) async {
    settings = next;
    key = apiKey;
  }
}

void main() {
  test(
    'sends OpenAI-compatible context and returns the assistant reply',
    () async {
      late Map<String, dynamic> request;
      final service = IdeaChatService(
        credentials: _Credentials(),
        client: MockClient((incoming) async {
          expect(incoming.headers['authorization'], 'Bearer secret');
          request = jsonDecode(incoming.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': 'Start with the audience.'},
                },
              ],
            }),
            200,
          );
        }),
      );
      final reply = await service.reply(
        ideaContext: '# Idea',
        messages: const [IdeaChatMessage('user', 'Help me refine this')],
      );
      expect(reply, 'Start with the audience.');
      expect(request['model'], 'openrouter/free');
      expect(
        (request['messages'] as List).first['content'],
        contains('IDEA CONTEXT'),
      );
    },
  );

  test('requires a user key before making a request', () async {
    final credentials = _Credentials()..key = null;
    final service = IdeaChatService(credentials: credentials);
    await expectLater(
      service.reply(ideaContext: 'Idea', messages: const []),
      throwsA(isA<IdeaChatException>()),
    );
  });

  testWidgets('Brainstorm sends a message and displays the reply', (
    tester,
  ) async {
    final idea = Note(
      id: 'idea',
      title: 'A better capture flow',
      content: 'Make capturing ideas quicker.',
      workspace: Note.ideasWorkspace,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BrainstormPanel(
          root: idea,
          notes: [idea],
          service: _ReplyingService(),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('brainstorm_input')),
      'What should I do first?',
    );
    await tester.tap(find.byKey(const Key('brainstorm_send')));
    await tester.pumpAndSettle();
    expect(find.text('What should I do first?'), findsOneWidget);
    expect(
      find.text('Start with the shortest useful version.'),
      findsOneWidget,
    );
  });

  testWidgets('Brainstorm fits a 390 by 844 phone viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final idea = Note(
      id: 'idea',
      title: 'Phone idea',
      content: '',
      workspace: Note.ideasWorkspace,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BrainstormPanel(
          root: idea,
          notes: [idea],
          service: _ReplyingService(),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}

class _ReplyingService extends IdeaChatService {
  _ReplyingService() : super(credentials: _Credentials());
  @override
  Future<String> reply({
    required String ideaContext,
    required List<IdeaChatMessage> messages,
  }) async => 'Start with the shortest useful version.';
}
