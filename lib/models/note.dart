import 'dart:convert';
import 'note_block.dart';

class Note {
  final String id;
  final String title;
  final String? subtitle;
  final String content;
  final String? formatting;
  final String? blocksJson;
  final String? parentId;
  final List<String> childrenIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPinned;
  final List<String> tags;

  const Note({
    required this.id,
    required this.title,
    this.subtitle,
    required this.content,
    this.formatting,
    this.blocksJson,
    this.parentId,
    this.childrenIds = const [],
    required this.createdAt,
    required this.updatedAt,
    this.isPinned = false,
    this.tags = const [],
  });

  bool get isRoot => parentId == null;
  bool get hasChildren => childrenIds.isNotEmpty;

  /// Returns parsed blocks. Auto-migrates legacy content if `blocksJson` is absent.
  List<NoteBlock> get blocks {
    if (blocksJson != null && blocksJson!.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(blocksJson!);
        final result = list
            .map((e) => NoteBlock.fromJson(e as Map<String, dynamic>))
            .toList();
        if (result.isNotEmpty) return result;
      } catch (_) {
        // Fallback to legacy parsing if jsonDecode fails
      }
    }

    // Auto-migrate legacy plain text / formatting
    if (content.isEmpty) {
      return [NoteBlock(type: BlockType.text, content: '')];
    }

    final lines = content.split('\n');
    final List<NoteBlock> migrated = [];

    for (final line in lines) {
      if (line.startsWith('# ')) {
        migrated.add(NoteBlock(
          type: BlockType.heading,
          content: line.substring(2),
        ));
      } else if (line.startsWith('## ')) {
        migrated.add(NoteBlock(
          type: BlockType.heading,
          content: line.substring(3),
        ));
      } else if (line.startsWith('• ') || line.startsWith('- ') || line.startsWith('* ')) {
        migrated.add(NoteBlock(
          type: BlockType.bullet,
          content: cleanMarkerPrefix(line.substring(2)),
        ));
      } else if (RegExp(r'^\d+\.\s+').hasMatch(line)) {
        final match = RegExp(r'^\d+\.\s+').firstMatch(line)!;
        migrated.add(NoteBlock(
          type: BlockType.number,
          content: cleanMarkerPrefix(line.substring(match.end)),
        ));
      } else if (line.trim() == '---') {
        migrated.add(NoteBlock(
          type: BlockType.divider,
          content: '',
        ));
      } else {
        migrated.add(NoteBlock(
          type: BlockType.text,
          content: line,
        ));
      }
    }

    return migrated.isEmpty
        ? [NoteBlock(type: BlockType.text, content: '')]
        : migrated;
  }

  Note copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? content,
    String? formatting,
    String? blocksJson,
    String? parentId,
    List<String>? childrenIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPinned,
    List<String>? tags,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      content: content ?? this.content,
      formatting: formatting ?? this.formatting,
      blocksJson: blocksJson ?? this.blocksJson,
      parentId: parentId ?? this.parentId,
      childrenIds: childrenIds ?? this.childrenIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
      tags: tags ?? this.tags,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'content': content,
      if (formatting != null) 'formatting': formatting,
      if (blocksJson != null) 'blocksJson': blocksJson,
      'parentId': parentId,
      'childrenIds': childrenIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isPinned': isPinned,
      'tags': tags,
    };
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      content: json['content'] as String? ?? '',
      formatting: json['formatting'] as String?,
      blocksJson: json['blocksJson'] as String?,
      parentId: json['parentId'] as String?,
      childrenIds: (json['childrenIds'] as List<dynamic>?)?.cast<String>() ?? const [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isPinned: json['isPinned'] as bool? ?? false,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }
}
