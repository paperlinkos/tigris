import '../models/note.dart';
import '../models/note_block.dart';

enum IdeaAgent { codex, claudeCode, other }

List<Note> inWorkspace(List<Note> notes, String workspace) =>
    notes.where((note) => note.workspace == workspace).toList();

String ideaBriefSlug(String title) {
  final slug = title.toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final value = slug.isEmpty ? 'idea' : slug;
  return value.substring(0, value.length > 40 ? 40 : value.length);
}

String _title(Note note, {bool root = false}) {
  final value = note.title.trim();
  return value.isEmpty ? (root ? 'Untitled idea' : 'Untitled') : value;
}

String _text(Note note) => note.blocks.where((block) =>
    block.type != BlockType.page && block.type != BlockType.divider).map((block) {
  final content = block.content;
  return switch (block.type) {
    BlockType.bullet => '- $content',
    BlockType.number => '1. $content',
    BlockType.heading => '### $content',
    _ => content,
  };
}).join('\n');

String _firstLine(Note note) {
  for (final line in _text(note).split('\n')) {
    if (line.trim().isNotEmpty) return line.trim();
  }
  return '';
}

String buildIdeaBrief(Note root, List<Note> all) {
  final eligible = all.where((note) => note.workspace == Note.ideasWorkspace).toList();
  final byParent = <String, List<Note>>{};
  for (final note in eligible) {
    if (note.parentId != null) byParent.putIfAbsent(note.parentId!, () => []).add(note);
  }
  for (final children in byParent.values) {
    children.sort((a, b) { final time = a.createdAt.compareTo(b.createdAt); return time != 0 ? time : a.id.compareTo(b.id); });
  }
  final visited = <String>{};
  final tree = <({Note note, int depth})>[];
  void visit(Note note, int depth) {
    if (!visited.add(note.id)) return;
    tree.add((note: note, depth: depth));
    for (final child in byParent[note.id] ?? const <Note>[]) { visit(child, depth + 1); }
  }
  visit(root, 0);
  final goal = _firstLine(root);
  final out = StringBuffer('# ${_title(root, root: true)}\n\n## Goal\n${goal.isEmpty ? 'Describe the goal.' : goal}\n\n## Ideas and pages\n');
  for (final row in tree) {
    final first = _firstLine(row.note);
    out.writeln('${'  ' * row.depth}- ${_title(row.note, root: row.depth == 0)}: $first');
  }
  out.write('\n## Details\n');
  for (final row in tree) {
    out.writeln('### ${_title(row.note, root: row.depth == 0)}');
    out.writeln(_text(row.note));
  }
  out.write('\n## Done when\n- It works and has tests.\n- Finish with a full outline of what you did.\n');
  return out.toString();
}

String _quote(String value) => "'${value.replaceAll("'", r"'\''")}'";

// Escapes text for use inside double quotes in a shell.
String _dq(String value) => value.replaceAllMapped(RegExp(r'[\\$`"]'), (m) => '\\${m[0]}');

// A path as a shell word. A leading ~/ must stay unquoted to expand, so it
// becomes "$HOME/..." instead.
String _shellPath(String path) =>
    path.startsWith('~/') ? '"\$HOME/${_dq(path.substring(2))}"' : _quote(path);

String ideaAgentCommand(IdeaAgent agent, String briefPath) => switch (agent) {
  IdeaAgent.codex => 'codex "\$(cat ${_shellPath(briefPath)})"',
  IdeaAgent.claudeCode => 'claude "Read ${_dq(briefPath)} and start on it"',
  IdeaAgent.other => 'Paste the brief into your agent, or point it at ${_quote(briefPath)}',
};
