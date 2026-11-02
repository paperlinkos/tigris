import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:tigris/models/note.dart';
import 'package:tigris/models/note_block.dart';
import 'package:tigris/services/idea_brief.dart';

Note idea(String id, {String title = '', String text = '', String? parentId, DateTime? createdAt, List<NoteBlock>? blocks}) => Note(
  id: id, title: title, content: text, parentId: parentId, createdAt: createdAt ?? DateTime(2026), updatedAt: DateTime(2026), workspace: Note.ideasWorkspace,
  blocksJson: blocks == null ? null : jsonEncode(blocks.map((b) => b.toJson()).toList()),
);

void main() {
  test('single idea has the exact section order', () {
    final brief = buildIdeaBrief(idea('a', title: 'Build', text: 'A goal'), []);
    expect(brief, '# Build\n\n## Goal\nA goal\n\n## Ideas and pages\n- Build: A goal\n\n## Details\n### Build\nA goal\n\n## Done when\n- It works and has tests.\n- Finish with a full outline of what you did.\n');
  });
  test('nested pages use created tree order and indentation', () {
    final root = idea('r', title: 'Root'); final a = idea('a', title: 'A', parentId: 'r', createdAt: DateTime(2026, 1, 2)); final b = idea('b', title: 'B', parentId: 'r', createdAt: DateTime(2026, 1, 1)); final c = idea('c', title: 'C', parentId: 'b');
    expect(buildIdeaBrief(root, [root, a, b, c]), contains('- Root: \n  - B: \n    - C: \n  - A: \n'));
  });
  test('untitled names and empty goal have fallbacks', () { final root = idea('r'); final child = idea('c', parentId: 'r'); final brief = buildIdeaBrief(root, [root, child]); expect(brief, contains('# Untitled idea')); expect(brief, contains('Describe the goal.')); expect(brief, contains('  - Untitled:')); });
  test('block markdown omits pages and dividers', () { final root = idea('r', blocks: [NoteBlock(type: BlockType.bullet, content: 'bullet'), NoteBlock(type: BlockType.number, content: 'number'), NoteBlock(type: BlockType.heading, content: 'heading'), NoteBlock(type: BlockType.page, targetNoteId: 'x'), NoteBlock(type: BlockType.divider)]); final brief = buildIdeaBrief(root, [root]); expect(brief, contains('- bullet\n1. number\n### heading')); expect(brief, isNot(contains('targetNoteId'))); });
  test('cycles visit each page once and notes workspace is ignored', () { final root = idea('r', title: 'Root', parentId: 'b'); final b = idea('b', title: 'B', parentId: 'r'); final note = Note(id: 'n', title: 'Notes', content: '', parentId: 'r', createdAt: DateTime(2026), updatedAt: DateTime(2026)); final brief = buildIdeaBrief(root, [root, b, note]); expect(RegExp('### Root').allMatches(brief).length, 1); expect(RegExp('### B').allMatches(brief).length, 1); expect(brief, isNot(contains('Notes'))); });
  test('slug and agent commands are shell safe', () { expect(ideaBriefSlug(' Hello, world! '), 'hello-world'); expect(ideaBriefSlug('é'), 'idea'); expect(ideaBriefSlug(''), 'idea'); expect(ideaBriefSlug('x' * 100).length, 40); final path = "a b's.md"; expect(ideaAgentCommand(IdeaAgent.codex, path), r'''codex "$(cat 'a b'\''s.md')"''');
    expect(ideaAgentCommand(IdeaAgent.codex, '~/.claude/handoffs/Ideas/x y.md'), r'codex "$(cat "$HOME/.claude/handoffs/Ideas/x y.md")"');
    expect(ideaAgentCommand(IdeaAgent.claudeCode, '~/.claude/handoffs/Ideas/x.md'), 'claude "Read ~/.claude/handoffs/Ideas/x.md and start on it"'); expect(ideaAgentCommand(IdeaAgent.claudeCode, path), startsWith('claude')); expect(ideaAgentCommand(IdeaAgent.other, path), startsWith('Paste')); });
}
