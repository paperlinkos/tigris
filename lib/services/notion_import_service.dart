import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/note.dart';
import '../models/note_block.dart';
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
            final fullTitle = titleList
                .map((t) => (t as Map<String, dynamic>?)?['plain_text'] as String? ?? '')
                .join('')
                .trim();
            if (fullTitle.isNotEmpty) {
              title = fullTitle;
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

class ParsedRichText {
  final String plainText;
  final List<InlineAttribute> attributes;

  const ParsedRichText(this.plainText, this.attributes);
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

  /// Fetch all block children of a given Notion page or parent block, with pagination support
  Future<List<Map<String, dynamic>>> fetchPageBlocks(String token, String blockId) async {
    final allResults = <Map<String, dynamic>>[];
    String? startCursor;
    bool hasMore = true;

    while (hasMore) {
      final queryParams = <String, String>{'page_size': '100'};
      if (startCursor != null) {
        queryParams['start_cursor'] = startCursor;
      }
      final uri = Uri.parse('$baseUrl/blocks/$blockId/children')
          .replace(queryParameters: queryParams);

      final response = await _client.get(uri, headers: _headers(token));

      if (response.statusCode == 429) {
        // Rate limited — back off slightly and retry once
        await Future.delayed(const Duration(milliseconds: 1000));
        final retryResponse = await _client.get(uri, headers: _headers(token));
        if (retryResponse.statusCode != 200) {
          debugPrint('Error fetching blocks for $blockId on retry: ${retryResponse.body}');
          break;
        }
        final retryData = jsonDecode(retryResponse.body) as Map<String, dynamic>;
        final results = retryData['results'] as List<dynamic>? ?? [];
        allResults.addAll(results.cast<Map<String, dynamic>>());
        hasMore = retryData['has_more'] == true;
        startCursor = retryData['next_cursor'] as String?;
        continue;
      }

      if (response.statusCode != 200) {
        debugPrint('Error fetching blocks for $blockId: ${response.body}');
        break;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];
      allResults.addAll(results.cast<Map<String, dynamic>>());

      hasMore = data['has_more'] == true;
      startCursor = data['next_cursor'] as String?;
    }

    return allResults;
  }

  /// Parse Notion rich text array into plain text and inline attributes (bold, italic)
  ParsedRichText _parseRichText(List<dynamic>? richText) {
    if (richText == null || richText.isEmpty) {
      return const ParsedRichText('', []);
    }

    final sb = StringBuffer();
    final attributes = <InlineAttribute>[];

    for (final item in richText) {
      if (item is Map<String, dynamic>) {
        final text = item['plain_text'] as String?;
        if (text != null && text.isNotEmpty) {
          final start = sb.length;
          sb.write(text);
          final end = sb.length;

          final annotations = item['annotations'] as Map<String, dynamic>?;
          if (annotations != null) {
            if (annotations['bold'] == true) {
              attributes.add(InlineAttribute(start: start, end: end, type: 'bold'));
            }
            if (annotations['italic'] == true) {
              attributes.add(InlineAttribute(start: start, end: end, type: 'italic'));
            }
          }
        }
      }
    }

    return ParsedRichText(sb.toString(), attributes);
  }

  /// Recursively processes raw Notion blocks, assigning proper indentation to nested blocks
  /// (e.g. nested bulleted lists, numbered sub-items, toggle items) and collecting subpage references.
  Future<void> _processBlocksRecursively({
    required String token,
    required List<Map<String, dynamic>> rawBlocks,
    required int indentLevel,
    required List<NoteBlock> noteBlocksOut,
    required StringBuffer contentBufferOut,
    required List<String> childPageIdsOut,
    required Map<String, String> childPageTitlesOut,
  }) async {
    final clampedIndent = indentLevel.clamp(0, 5);

    for (final block in rawBlocks) {
      final type = block['type'] as String?;
      if (type == null) continue;

      final blockData = block[type] as Map<String, dynamic>?;
      if (blockData == null) continue;

      final blockId = (block['id'] as String?) ?? 'blk_${DateTime.now().microsecondsSinceEpoch}';
      final hasChildren = block['has_children'] == true;

      final richTextList = blockData['rich_text'] as List<dynamic>?;
      final parsed = _parseRichText(richTextList);
      final text = parsed.plainText;
      final attrs = parsed.attributes;

      final indentSpaces = '  ' * clampedIndent;

      switch (type) {
        case 'paragraph':
          contentBufferOut.writeln('$indentSpaces$text\n');
          noteBlocksOut.add(NoteBlock(
            type: BlockType.text,
            content: text,
            indentLevel: clampedIndent,
            inlineAttributes: attrs,
          ));
          break;

        case 'heading_1':
        case 'heading_2':
        case 'heading_3':
          contentBufferOut.writeln('# $text\n');
          noteBlocksOut.add(NoteBlock(
            type: BlockType.heading,
            content: text,
            indentLevel: clampedIndent,
            inlineAttributes: attrs,
          ));
          break;

        case 'bulleted_list_item':
          contentBufferOut.writeln('$indentSpaces• $text');
          noteBlocksOut.add(NoteBlock(
            type: BlockType.bullet,
            content: cleanMarkerPrefix(text),
            indentLevel: clampedIndent,
            inlineAttributes: attrs,
          ));
          break;

        case 'numbered_list_item':
          contentBufferOut.writeln('${indentSpaces}1. $text');
          noteBlocksOut.add(NoteBlock(
            type: BlockType.number,
            content: cleanMarkerPrefix(text),
            indentLevel: clampedIndent,
            inlineAttributes: attrs,
          ));
          break;

        case 'to_do':
          final checked = blockData['checked'] == true;
          contentBufferOut.writeln('$indentSpaces${checked ? '[x]' : '[ ]'} $text');
          noteBlocksOut.add(NoteBlock(
            type: BlockType.bullet,
            content: (checked ? '[x] ' : '[ ] ') + cleanMarkerPrefix(text),
            indentLevel: clampedIndent,
            inlineAttributes: attrs,
          ));
          break;

        case 'toggle':
          contentBufferOut.writeln('$indentSpaces• $text');
          noteBlocksOut.add(NoteBlock(
            type: BlockType.bullet,
            content: cleanMarkerPrefix(text),
            indentLevel: clampedIndent,
            inlineAttributes: attrs,
          ));
          break;

        case 'callout':
          String iconPrefix = '';
          final iconMap = blockData['icon'] as Map<String, dynamic>?;
          if (iconMap != null && iconMap['type'] == 'emoji') {
            final emoji = iconMap['emoji'] as String?;
            if (emoji != null) iconPrefix = '$emoji ';
          }
          final calloutText = '$iconPrefix$text'.trim();
          contentBufferOut.writeln('$indentSpaces> $calloutText\n');
          noteBlocksOut.add(NoteBlock(
            type: BlockType.text,
            content: calloutText,
            indentLevel: clampedIndent,
            inlineAttributes: attrs,
          ));
          break;

        case 'quote':
          contentBufferOut.writeln('$indentSpaces> $text\n');
          noteBlocksOut.add(NoteBlock(
            type: BlockType.text,
            content: text,
            indentLevel: clampedIndent,
            inlineAttributes: attrs,
          ));
          break;

        case 'code':
          final lang = blockData['language'] as String? ?? '';
          contentBufferOut.writeln('```$lang\n$text\n```\n');
          noteBlocksOut.add(NoteBlock(
            type: BlockType.text,
            content: text,
            indentLevel: clampedIndent,
            inlineAttributes: attrs,
          ));
          break;

        case 'divider':
          contentBufferOut.writeln('---\n');
          noteBlocksOut.add(NoteBlock(
            type: BlockType.divider,
            indentLevel: clampedIndent,
          ));
          break;

        case 'child_page':
          final childTitle = blockData['title'] as String? ?? 'Untitled Subpage';
          childPageIdsOut.add(blockId);
          childPageTitlesOut[blockId] = childTitle;
          final childNativeId = 'notion_${blockId.replaceAll("-", "")}';
          contentBufferOut.writeln('$indentSpaces📄 **Subpage**: $childTitle\n');
          noteBlocksOut.add(NoteBlock(
            type: BlockType.page,
            targetNoteId: childNativeId,
            content: childTitle,
            indentLevel: clampedIndent,
          ));
          break;

        default:
          if (blockData.containsKey('rich_text')) {
            final fallbackParsed = _parseRichText(blockData['rich_text'] as List<dynamic>?);
            if (fallbackParsed.plainText.trim().isNotEmpty) {
              contentBufferOut.writeln('$indentSpaces${fallbackParsed.plainText}\n');
              noteBlocksOut.add(NoteBlock(
                type: BlockType.text,
                content: fallbackParsed.plainText,
                indentLevel: clampedIndent,
                inlineAttributes: fallbackParsed.attributes,
              ));
            }
          }
          break;
      }

      // If this block has child blocks (nested bullet, sub-numbered item, toggle content, etc.),
      // recursively fetch its children and increment the indentation level!
      if (hasChildren && type != 'child_page') {
        final childBlocks = await fetchPageBlocks(token, blockId);
        if (childBlocks.isNotEmpty) {
          await _processBlocksRecursively(
            token: token,
            rawBlocks: childBlocks,
            indentLevel: indentLevel + 1,
            noteBlocksOut: noteBlocksOut,
            contentBufferOut: contentBufferOut,
            childPageIdsOut: childPageIdsOut,
            childPageTitlesOut: childPageTitlesOut,
          );
        }
      }
    }
  }

  /// Converts Notion block items into markdown content & subpage definitions,
  /// preserving nested indentation hierarchy for list items and sub-blocks.
  Future<Map<String, dynamic>> convertPageToContent(
    String token,
    String pageId,
  ) async {
    final blocks = await fetchPageBlocks(token, pageId);
    final contentBuffer = StringBuffer();
    final childPageIds = <String>[];
    final childPageTitles = <String, String>{};
    final noteBlocks = <NoteBlock>[];

    await _processBlocksRecursively(
      token: token,
      rawBlocks: blocks,
      indentLevel: 0,
      noteBlocksOut: noteBlocks,
      contentBufferOut: contentBuffer,
      childPageIdsOut: childPageIds,
      childPageTitlesOut: childPageTitles,
    );

    return {
      'content': contentBuffer.toString().trim(),
      'childPageIds': childPageIds,
      'childPageTitles': childPageTitles,
      'blocks': noteBlocks,
    };
  }

  /// Imports a list of selected Notion pages into native Tigris Notes,
  /// recursively preserving multi-level nested subpages (pages in notes and pages in those notes)
  /// and block indentation hierarchies.
  Future<List<Note>> importSelectedPages({
    required String token,
    required List<NotionPage> selectedPages,
    required NoteRepository noteRepository,
    void Function(double progress, String currentStep)? onProgress,
  }) async {
    final importedNotes = <Note>[];
    final processedPageIds = <String>{};
    final total = selectedPages.length;

    for (var i = 0; i < total; i++) {
      final page = selectedPages[i];
      if (processedPageIds.contains(page.id)) {
        // Already recursively imported as a subpage of an earlier page
        continue;
      }

      final stepText = 'Importing ${page.title}...';
      onProgress?.call((i + 1) / total, stepText);

      await _importPageDeeply(
        token: token,
        pageId: page.id,
        pageTitle: page.title,
        parentId: null,
        updatedAt: page.lastEditedAt,
        noteRepository: noteRepository,
        importedNotesCollector: importedNotes,
        processedPageIds: processedPageIds,
        onStep: (step) => onProgress?.call((i + 0.5) / total, step),
      );
    }

    return importedNotes;
  }

  /// Recursively imports a page and all its nested subpages at arbitrary depth,
  /// setting the correct parentId, childrenIds, and inline page block pointers.
  Future<Note> _importPageDeeply({
    required String token,
    required String pageId,
    required String pageTitle,
    required String? parentId,
    required DateTime updatedAt,
    required NoteRepository noteRepository,
    required List<Note> importedNotesCollector,
    required Set<String> processedPageIds,
    void Function(String currentStep)? onStep,
  }) async {
    processedPageIds.add(pageId);
    final nativeNoteId = 'notion_${pageId.replaceAll("-", "")}';
    onStep?.call('Importing $pageTitle...');

    final converted = await convertPageToContent(token, pageId);
    final content = converted['content'] as String;
    final childPageIds = converted['childPageIds'] as List<String>;
    final childPageTitles = converted['childPageTitles'] as Map<String, String>;
    final blocks = converted['blocks'] as List<NoteBlock>? ?? [];

    final now = DateTime.now();

    // 1. Recursively import all child pages (pages inside this note, and pages inside those notes)
    final createdChildIds = <String>[];
    for (final childId in childPageIds) {
      final childTitle = childPageTitles[childId] ?? 'Untitled Subpage';
      try {
        final childNote = await _importPageDeeply(
          token: token,
          pageId: childId,
          pageTitle: childTitle,
          parentId: nativeNoteId,
          updatedAt: updatedAt,
          noteRepository: noteRepository,
          importedNotesCollector: importedNotesCollector,
          processedPageIds: processedPageIds,
          onStep: onStep,
        );
        createdChildIds.add(childNote.id);
      } catch (e) {
        debugPrint('Error importing subpage $childId ($childTitle): $e');
      }
    }

    // 2. Create the current note with its childrenIds pointing to all imported subpages
    final note = Note(
      id: nativeNoteId,
      parentId: parentId,
      title: pageTitle,
      content: content,
      blocksJson: jsonEncode(blocks.map((b) => b.toJson()).toList()),
      childrenIds: createdChildIds,
      createdAt: now,
      updatedAt: updatedAt,
    );

    await noteRepository.saveNote(note);
    importedNotesCollector.add(note);
    return note;
  }
}
