import 'dart:convert';

import '../models/note.dart';
import '../models/note_block.dart';

class BackupFormatException implements Exception {
  final String message;
  const BackupFormatException(this.message);
}

String encodeBackup(List<Note> notes, DateTime createdAt) => jsonEncode({
      'format': 'tigris-backup',
      'version': 1,
      'createdAt': createdAt.toIso8601String(),
      'noteCount': notes.length,
      'notes': notes.map((note) => note.toJson()).toList(),
    });

List<Note> decodeBackup(String source) {
  dynamic decoded;
  try {
    decoded = jsonDecode(source);
  } catch (_) {
    throw const BackupFormatException('This backup is not valid JSON.');
  }
  if (decoded is! Map<String, dynamic>) {
    throw const BackupFormatException('This is not a Tigris backup file.');
  }
  if (decoded['format'] != 'tigris-backup') {
    throw const BackupFormatException('This is not a Tigris backup file.');
  }
  if (decoded['version'] != 1) {
    throw const BackupFormatException('This backup uses an unsupported format.');
  }
  final notesJson = decoded['notes'];
  final count = decoded['noteCount'];
  if (notesJson is! List || count is! int || notesJson.length != count) {
    throw const BackupFormatException('This backup is incomplete or corrupted.');
  }
  final notes = <Note>[];
  try {
    for (final item in notesJson) {
      if (item is! Map) throw const FormatException();
      notes.add(Note.fromJson(Map<String, dynamic>.from(item)));
    }
  } catch (_) {
    throw const BackupFormatException('This backup contains an invalid note.');
  }
  return notes;
}

String renderReadable(List<Note> notes, DateTime createdAt) {
  final byId = {for (final note in notes) note.id: note};
  final children = <String, List<Note>>{};
  final roots = <Note>[];
  for (final note in notes) {
    if (note.parentId == null || !byId.containsKey(note.parentId)) {
      roots.add(note);
    } else {
      children.putIfAbsent(note.parentId!, () => []).add(note);
    }
  }
  int compare(Note a, Note b) => a.title.toLowerCase().compareTo(b.title.toLowerCase());
  roots.sort(compare);
  for (final list in children.values) {
    list.sort(compare);
  }
  final lines = <String>[
    '# Tigris notes backup',
    '',
    'Saved ${createdAt.toIso8601String()}, ${notes.length} notes.',
  ];
  final visited = <String>{};
  void render(Note note, int depth) {
    if (!visited.add(note.id)) return;
    lines.add('');
    final headingDepth = (depth + 2).clamp(2, 6);
    lines.add('${List.filled(headingDepth, '#').join()} ${note.title.isEmpty ? 'Untitled' : note.title}');
    for (final block in note.blocks) {
      if (block.type == BlockType.page) continue;
      final indent = '  ' * block.indentLevel;
      switch (block.type) {
        case BlockType.heading:
          lines.add('$indent**${block.content}**');
        case BlockType.bullet:
          lines.add('$indent- ${block.content}');
        case BlockType.number:
          lines.add('${indent}1. ${block.content}');
        case BlockType.divider:
          lines.add('$indent---');
        case BlockType.text:
          lines.add('$indent${block.content}');
        case BlockType.page:
          break;
      }
    }
    for (final child in children[note.id] ?? const <Note>[]) {
      render(child, depth + 1);
    }
  }
  for (final root in roots) {
    render(root, 0);
  }
  final remaining = notes.where((note) => !visited.contains(note.id)).toList()..sort(compare);
  for (final note in remaining) {
    render(note, 0);
  }
  return '${lines.join('\n')}\n';
}
