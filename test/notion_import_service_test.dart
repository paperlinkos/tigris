import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tigris/persistence/in_memory_storage.dart';
import 'package:tigris/repositories/local_note_repository.dart';
import 'package:tigris/services/notion_import_service.dart';

void main() {
  group('NotionImportService Unit & Hierarchy Tests', () {
    test('NotionPage.fromJson extracts title, icon, and lastEditedAt correctly', () {
      final json = {
        'id': 'page_123',
        'url': 'https://notion.so/page_123',
        'last_edited_time': '2026-09-22T10:00:00.000Z',
        'icon': {'type': 'emoji', 'emoji': '📚'},
        'properties': {
          'Name': {
            'type': 'title',
            'title': [
              {'plain_text': 'Stoicism & Modern Life'}
            ]
          }
        }
      };

      final page = NotionPage.fromJson(json);
      expect(page.id, equals('page_123'));
      expect(page.title, equals('Stoicism & Modern Life'));
      expect(page.icon, equals('📚'));
      expect(page.lastEditedAt.year, equals(2026));
    });

    test('fetchAccessiblePages parses search endpoint response correctly', () async {
      final service = NotionImportService(
        client: MockClient((req) async {
          expect(req.url.path, endsWith('/search'));
          expect(req.headers['Authorization'], equals('Bearer secret_test'));
          return http.Response('''{
            "results": [
              {
                "id": "p1",
                "last_edited_time": "2026-09-22T10:00:00.000Z",
                "properties": {
                  "Title": {
                    "type": "title",
                    "title": [{"plain_text": "Deep Work Strategy"}]
                  }
                }
              }
            ]
          }''', 200);
        }),
      );

      final pages = await service.fetchAccessiblePages('secret_test');
      expect(pages.length, equals(1));
      expect(pages.first.id, equals('p1'));
      expect(pages.first.title, equals('Deep Work Strategy'));
    });

    test('convertPageToContent parses Notion block types to Markdown and child pages', () async {
      final mockClient = MockClient((req) async {
        return http.Response('''{
          "results": [
            {
              "type": "heading_1",
              "heading_1": {"rich_text": [{"plain_text": "Overview"}]}
            },
            {
              "type": "paragraph",
              "paragraph": {"rich_text": [{"plain_text": "This is a Notion paragraph."}]}
            },
            {
              "type": "to_do",
              "to_do": {"checked": true, "rich_text": [{"plain_text": "Complete research"}]}
            },
            {
              "type": "child_page",
              "id": "child_page_99",
              "child_page": {"title": "Subpage Detail"}
            }
          ]
        }''', 200);
      });

      final service = NotionImportService(client: mockClient);
      final result = await service.convertPageToContent('secret_test', 'page_root');

      final content = result['content'] as String;
      final childPageIds = result['childPageIds'] as List<String>;

      expect(content, contains('# Overview'));
      expect(content, contains('This is a Notion paragraph.'));
      expect(content, contains('[x] Complete research'));
      expect(content, contains('📄 **Subpage**: Subpage Detail'));
      expect(childPageIds, contains('child_page_99'));
    });

    test('convertPageToContent parses nested blocks and assigns proper indentLevels', () async {
      final mockClient = MockClient((req) async {
        final path = req.url.path;
        if (path.contains('/blocks/page_root/children')) {
          return http.Response('''{
            "results": [
              {
                "id": "b1",
                "type": "bulleted_list_item",
                "has_children": true,
                "bulleted_list_item": {"rich_text": [{"plain_text": "Top bullet"}]}
              }
            ]
          }''', 200);
        } else if (path.contains('/blocks/b1/children')) {
          return http.Response('''{
            "results": [
              {
                "id": "b2",
                "type": "bulleted_list_item",
                "has_children": true,
                "bulleted_list_item": {"rich_text": [{"plain_text": "Nested bullet"}]}
              }
            ]
          }''', 200);
        } else if (path.contains('/blocks/b2/children')) {
          return http.Response('''{
            "results": [
              {
                "id": "b3",
                "type": "numbered_list_item",
                "has_children": false,
                "numbered_list_item": {"rich_text": [{"plain_text": "Deep numbered item"}]}
              }
            ]
          }''', 200);
        }
        return http.Response('{"results": []}', 200);
      });

      final service = NotionImportService(client: mockClient);
      final result = await service.convertPageToContent('secret_test', 'page_root');

      final blocks = result['blocks'] as List<dynamic>;
      expect(blocks.length, equals(3));
      expect(blocks[0].content, equals('Top bullet'));
      expect(blocks[0].indentLevel, equals(0));

      expect(blocks[1].content, equals('Nested bullet'));
      expect(blocks[1].indentLevel, equals(1));

      expect(blocks[2].content, equals('Deep numbered item'));
      expect(blocks[2].indentLevel, equals(2));
    });

    test('importSelectedPages recursively imports pages in notes and pages in those notes', () async {
      final mockClient = MockClient((req) async {
        final path = req.url.path;
        if (path.contains('/blocks/root_page/children')) {
          return http.Response('''{
            "results": [
              {
                "id": "child_page_1",
                "type": "child_page",
                "child_page": {"title": "Design Specs"}
              }
            ]
          }''', 200);
        } else if (path.contains('/blocks/child_page_1/children')) {
          return http.Response('''{
            "results": [
              {
                "id": "grandchild_page_1",
                "type": "child_page",
                "child_page": {"title": "Color Palette"}
              }
            ]
          }''', 200);
        } else if (path.contains('/blocks/grandchild_page_1/children')) {
          return http.Response('''{
            "results": [
              {
                "id": "b_deep",
                "type": "paragraph",
                "has_children": false,
                "paragraph": {"rich_text": [{"plain_text": "Primary color is #121212"}]}
              }
            ]
          }''', 200);
        }
        return http.Response('{"results": []}', 200);
      });

      final service = NotionImportService(client: mockClient);
      final storage = InMemoryStorage();
      final repo = LocalNoteRepository(storage: storage);

      final imported = await service.importSelectedPages(
        token: 'secret_test',
        selectedPages: [
          NotionPage(
            id: 'root_page',
            title: 'Project Roadmap',
            lastEditedAt: DateTime(2026, 9, 24),
          ),
        ],
        noteRepository: repo,
      );

      // Should have imported all 3 notes: root, child, grandchild
      expect(imported.length, equals(3));

      final rootNote = await repo.getNote('notion_root_page');
      expect(rootNote, isNotNull);
      expect(rootNote!.title, equals('Project Roadmap'));
      expect(rootNote.parentId, isNull);
      expect(rootNote.childrenIds, contains('notion_child_page_1'));
      expect(rootNote.blocks.first.targetNoteId, equals('notion_child_page_1'));

      final childNote = await repo.getNote('notion_child_page_1');
      expect(childNote, isNotNull);
      expect(childNote!.title, equals('Design Specs'));
      expect(childNote.parentId, equals('notion_root_page'));
      expect(childNote.childrenIds, contains('notion_grandchild_page_1'));
      expect(childNote.blocks.first.targetNoteId, equals('notion_grandchild_page_1'));

      final grandchildNote = await repo.getNote('notion_grandchild_page_1');
      expect(grandchildNote, isNotNull);
      expect(grandchildNote!.title, equals('Color Palette'));
      expect(grandchildNote.parentId, equals('notion_child_page_1'));
      expect(grandchildNote.childrenIds, isEmpty);
      expect(grandchildNote.blocks.first.content, equals('Primary color is #121212'));
    });
  });
}
