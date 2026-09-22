class Note {
  final String id;
  final String title;
  final String? subtitle;
  final String content;
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
    this.parentId,
    this.childrenIds = const [],
    required this.createdAt,
    required this.updatedAt,
    this.isPinned = false,
    this.tags = const [],
  });

  bool get isRoot => parentId == null;
  bool get hasChildren => childrenIds.isNotEmpty;

  Note copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? content,
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
      content: json['content'] as String,
      parentId: json['parentId'] as String?,
      childrenIds: (json['childrenIds'] as List<dynamic>?)?.cast<String>() ?? const [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isPinned: json['isPinned'] as bool? ?? false,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }
}
