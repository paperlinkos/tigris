enum BlockType {
  text,
  heading,
  bullet,
  number,
  page,
  divider;

  String toJson() => name;

  static BlockType fromJson(String json) {
    return BlockType.values.firstWhere(
      (e) => e.name == json,
      orElse: () => BlockType.text,
    );
  }
}

String cleanMarkerPrefix(String text) {
  var cleaned = text.trimLeft();
  bool changed = true;
  while (changed) {
    changed = false;
    if (cleaned.startsWith('• ') || cleaned.startsWith('- ') || cleaned.startsWith('* ')) {
      cleaned = cleaned.substring(2).trimLeft();
      changed = true;
    }
    final numMatch = RegExp(r'^\d+\.\s+').firstMatch(cleaned);
    if (numMatch != null) {
      cleaned = cleaned.substring(numMatch.end).trimLeft();
      changed = true;
    }
  }
  return cleaned;
}

class InlineAttribute {
  final int start;
  final int end;
  final String type; // 'bold' | 'italic'

  const InlineAttribute({
    required this.start,
    required this.end,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
        'start': start,
        'end': end,
        'type': type,
      };

  factory InlineAttribute.fromJson(Map<String, dynamic> json) => InlineAttribute(
        start: json['start'] as int? ?? 0,
        end: json['end'] as int? ?? 0,
        type: json['type'] as String? ?? 'bold',
      );
}

class NoteBlock {
  final String id;
  final BlockType type;
  final String content;
  final int indentLevel;
  final String? targetNoteId;
  final List<InlineAttribute> inlineAttributes;

  NoteBlock({
    String? id,
    required this.type,
    this.content = '',
    this.indentLevel = 0,
    this.targetNoteId,
    List<InlineAttribute>? inlineAttributes,
  })  : id = id ?? 'blk_${DateTime.now().microsecondsSinceEpoch}',
        inlineAttributes = inlineAttributes ?? const [];

  NoteBlock copyWith({
    String? id,
    BlockType? type,
    String? content,
    int? indentLevel,
    String? targetNoteId,
    List<InlineAttribute>? inlineAttributes,
  }) {
    return NoteBlock(
      id: id ?? this.id,
      type: type ?? this.type,
      content: content ?? this.content,
      indentLevel: indentLevel ?? this.indentLevel,
      targetNoteId: targetNoteId ?? this.targetNoteId,
      inlineAttributes: inlineAttributes ?? List.from(this.inlineAttributes),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.toJson(),
        'content': content,
        'indentLevel': indentLevel,
        if (targetNoteId != null) 'targetNoteId': targetNoteId,
        if (inlineAttributes.isNotEmpty)
          'inlineAttributes': inlineAttributes.map((a) => a.toJson()).toList(),
      };

  factory NoteBlock.fromJson(Map<String, dynamic> json) {
    return NoteBlock(
      id: json['id'] as String?,
      type: BlockType.fromJson(json['type'] as String? ?? 'text'),
      content: json['content'] as String? ?? '',
      indentLevel: (json['indentLevel'] as int? ?? 0).clamp(0, 5),
      targetNoteId: json['targetNoteId'] as String?,
      inlineAttributes: (json['inlineAttributes'] as List<dynamic>?)
              ?.map((e) => InlineAttribute.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
