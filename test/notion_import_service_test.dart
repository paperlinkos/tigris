import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
  });
}
