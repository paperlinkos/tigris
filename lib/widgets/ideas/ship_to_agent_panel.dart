import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/app_typography.dart';
import '../../app/theme/context_theme_extensions.dart';
import '../../models/note.dart';
import '../../repositories/note_repository.dart';
import '../../services/idea_brief.dart';

class ShipToAgentPanel extends StatefulWidget {
  final Note root;
  final List<Note> notes;
  final NoteRepository repository;
  const ShipToAgentPanel({super.key, required this.root, required this.notes, required this.repository});
  @override State<ShipToAgentPanel> createState() => _ShipToAgentPanelState();
}

class _ShipToAgentPanelState extends State<ShipToAgentPanel> {
  late final TextEditingController _brief = TextEditingController(text: buildIdeaBrief(widget.root, widget.notes));
  IdeaAgent _agent = IdeaAgent.codex;
  String get _name => switch (_agent) { IdeaAgent.codex => 'Codex', IdeaAgent.claudeCode => 'Claude Code', IdeaAgent.other => 'Other' };
  String get _path => '~/.claude/handoffs/Ideas/${ideaBriefSlug(widget.root.title)}.md';
  @override void dispose() { _brief.dispose(); super.dispose(); }
  void _copy(String value, String label) { Clipboard.setData(ClipboardData(text: value)); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied'), duration: const Duration(seconds: 1))); }
  Future<void> _copyBrief() async {
    _copy(_brief.text, 'Brief');
    await widget.repository.saveNote(widget.root.copyWith(ideaStatus: 'Handed off', handedOffTo: _name, handedOffAt: DateTime.now(), updatedAt: DateTime.now()));
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ship to an agent'), automaticallyImplyLeading: true),
    body: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 8, children: [for (final agent in IdeaAgent.values) ChoiceChip(label: Text(switch (agent) { IdeaAgent.codex => 'Codex', IdeaAgent.claudeCode => 'Claude Code', IdeaAgent.other => 'Other' }), selected: _agent == agent, onSelected: (_) => setState(() => _agent = agent))]),
      const SizedBox(height: 16),
      Expanded(child: TextField(key: const Key('idea_brief_field'), controller: _brief, maxLines: null, expands: true, style: const TextStyle(fontFamily: 'monospace'), decoration: InputDecoration(border: OutlineInputBorder(borderSide: BorderSide(color: context.appBorder))))),
      const SizedBox(height: 12),
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: context.appSidebar, borderRadius: BorderRadius.circular(6)), child: SelectableText(ideaAgentCommand(_agent, _path), style: const TextStyle(fontFamily: 'monospace'))),
      const SizedBox(height: 12),
      Row(children: [Expanded(child: ElevatedButton(onPressed: _copyBrief, child: const Text('Copy brief'))), const SizedBox(width: 8), Expanded(child: OutlinedButton(onPressed: () => _copy(ideaAgentCommand(_agent, _path), 'Command'), child: const Text('Copy command')))]),
      const SizedBox(height: 8), Text('Save as file and Run in Terminal are coming. For now, paste the command into your terminal.', style: AppTypography.uiLabel(fontSize: 12, color: context.appTextSecondary)),
    ])),
  );
}
