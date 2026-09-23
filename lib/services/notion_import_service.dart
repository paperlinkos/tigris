import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/note.dart';
import '../repositories/note_repository.dart';

class NotionPage {
  final String id;
  final String title;
  final String? url;
  final DateTime lastEditedAt;
  final String? icon;

  const NotionPage({
    required this.id,
    required this.title,
    this.url,
    required this.lastEditedAt,
    this.icon,
  });

  factory NotionPage.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final url = json['url'] as String?;
    final lastEditedStr = json['last_edited_time'] as String?;
    final lastEditedAt = lastEditedStr != null
        ? DateTime.parse(lastEditedStr)
        : DateTime.now();

    String title = 'Untitled Notion Page';
    final properties = json['properties'] as Map<String, dynamic>?;
    if (properties != null) {
      for (final prop in properties.values) {
        if (prop is Map<String, dynamic> && prop['type'] == 'title') {
          final titleList = prop['title'] as List<dynamic>?;
          if (titleList != null && titleList.isNotEmpty) {
            final textObj = titleList.first as Map<String, dynamic>?;
            final plainText = textObj?['plain_text'] as String?;
            if (plainText != null && plainText.trim().isNotEmpty) {
              title = plainText.trim();
              break;
            }
          }
        }
      }
    }

    String? iconStr;
    final iconMap = json['icon'] as Map<String, dynamic>?;
    if (iconMap != null && iconMap['type'] == 'emoji') {
      iconStr = iconMap['emoji'] as String?;
    }

    return NotionPage(
      id: id,
      title: title,
      url: url,
      lastEditedAt: lastEditedAt,
      icon: iconStr,
    );
  }
}

class NotionImportService {
  final http.Client _client;
  final String baseUrl;

  NotionImportService({
    http.Client? client,
    this.baseUrl = 'https://api.notion.com/v1',
  }) : _client = client ?? http.Client();

  Map<String, String> _headers(String token) {
    return {
      'Authorization': 'Bearer ${token.trim()}',
      'Notion-Version': '2022-06-28',
      'Content-Type': 'application/json',
    };
  }

  /// Search accessible Notion pages in workspace
  Future<List<NotionPage>> fetchAccessiblePages(String token) async {
    final uri = Uri.parse('$baseUrl/search');
    final response = await _client.post(
      uri,
      headers: _headers(token),
      body: jsonEncode({
        'filter': {
          'value': 'page',
          'property': 'object',
        },
        'page_size': 100,
      }),
    );

    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      final msg = err['message'] ?? 'Failed to connect to Notion API (${response.statusCode})';
      throw Exception(msg);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>? ?? [];
    return results
        .map((item) => NotionPage.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Fetch block children of a given Notion page or parent block
  Future<List<Map<String, dynamic>>> fetchPageBlocks(String token, String blockId) async {
    final uri = Uri.parse('$baseUrl/blocks/$blockId/children?page_size=100');
    final response = await _client.get(
      uri,
      headers: _headers(token),
    );

    if (response.statusCode != 200) {
      debugPrint('Error fetching blocks for $blockId: ${response.body}');
      return [];
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>? ?? [];
    return results.cast<Map<String, dynamic>>();
  }

  /// Parse Notion rich text array into plain text
  String _parseRichText(List<dynamic>? richText) {
    if (richText == null || richText.isEmpty) return '';
    final sb = StringBuffer();
    for (final item in richText) {
      if (item is Map<String, dynamic>) {
        final text = item['plain_text'] as String?;
        if (text != null) sb.write(text);
      }
    }
    return sb.toString();
  }

  /// Converts Notion block items into markdown content & subpage definitions
  Future<Map<String, dynamic>> convertPageToContent(
    String token,
    String pageId,
  ) async {
    final blocks = await fetchPageBlocks(token, pageId);
    final contentBuffer = StringBuffer();
    final childPageIds = <String>[];
    final childPageTitles = <String, String>{};

    for (final block in blocks) {
      final type = block['type'] as String?;
      if (type == null) continue;

      final blockData = block[type] as Map<String, dynamic>?;
      if (blockData == null) continue;

      switch (type) {
        case 'paragraph':
          final text = _parseRichText(blockData['rich_text'] as List<dynamic>?);
          contentBuffer.writeln(text);
          contentBuffer.writeln();
          break;

        case 'heading_1':
          final text = _parseRichText(blockData['rich_text'] as List<dynamic>?);
          contentBuffer.writeln('# $text\n');
          break;

        case 'heading_2':
          final text = _parseRichText(blockData['rich_text'] as List<dynamic>?);
          contentBuffer.writeln('## $text\n');
          break;

        case 'heading_3':
          final text = _parseRichText(blockData['rich_text'] as List<dynamic>?);
          contentBuffer.writeln('### $text\n');
          break;

        case 'bulleted_list_item':
          final text = _parseRichText(blockData['rich_text'] as List<dynamic>?);
          contentBuffer.writeln('• $text');
          break;

        case 'numbered_list_item':
          final text = _parseRichText(blockData['rich_text'] as List<dynamic>?);
          contentBuffer.writeln('1. $text');
          break;

        case 'to_do':
          final text = _parseRichText(blockData['rich_text'] as List<dynamic>?);
          final checked = blockData['checked'] == true;
          contentBuffer.writeln(checked ? '[x] $text' : '[ ] $text');
          break;

        case 'quote':
          final text = _parseRichText(blockData['rich_text'] as List<dynamic>?);
          contentBuffer.writeln('> $text\n');
          break;

        case 'code':
          final text = _parseRichText(blockData['rich_text'] as List<dynamic>?);
          final lang = blockData['language'] as String? ?? '';
          contentBuffer.writeln('```$lang\n$text\n```\n');
          break;

        case 'child_page':
          final childTitle = blockData['title'] as String? ?? 'Untitled Subpage';
          final childId = block['id'] as String;
          childPageIds.add(childId);
          childPageTitles[childId] = childTitle;
          contentBuffer.writeln('📄 **Subpage**: $childTitle\n');
          break;
      }
    }

    return {
      'content': contentBuffer.toString().trim(),
      'childPageIds': childPageIds,
      'childPageTitles': childPageTitles,
    };
  }

  /// Imports a list of selected Notion pages into native Tigris Notes
  Future<List<Note>> importSelectedPages({
    required String token,
    required List<NotionPage> selectedPages,
    required NoteRepository noteRepository,
    void Function(double progress, String currentStep)? onProgress,
  }) async {
    final importedNotes = <Note>[];
    final total = selectedPages.length;

    for (var i = 0; i < total; i++) {
      final page = selectedPages[i];
      final stepText = 'Importing ${page.title}...';
      onProgress?.call((i + 1) / total, stepText);

      final converted = await convertPageToContent(token, page.id);
      final content = converted['content'] as String;
      final childPageIds = converted['childPageIds'] as List<String>;
      final childPageTitles = converted['childPageTitles'] as Map<String, String>;

      final now = DateTime.now();
      final rootNoteId = 'notion_${page.id.replaceAll("-", "")}';

      // 1. Create Subpages first if any child_page blocks were found
      final createdChildIds = <String>[];
      for (final childId in childPageIds) {
        final childTitle = childPageTitles[childId] ?? 'Untitled Subpage';
        final childConverted = await convertPageToContent(token, childId);
        final childNativeId = 'notion_${childId.replaceAll("-", "")}';

        final childNote = Note(
          id: childNativeId,
          parentId: rootNoteId,
          title: childTitle,
          content: childConverted['content'] as String,
          createdAt: now,
          updatedAt: page.lastEditedAt,
        );

        await noteRepository.saveNote(childNote);
        importedNotes.add(childNote);
        createdChildIds.add(childNativeId);
      }

      // 2. Create Native Root Note
      final rootNote = Note(
        id: rootNoteId,
        title: page.title,
        content: content,
        childrenIds: createdChildIds,
        createdAt: now,
        updatedAt: page.lastEditedAt,
      );

      await noteRepository.saveNote(rootNote);
      importedNotes.add(rootNote);
    }

    return importedNotes;
  }
}
