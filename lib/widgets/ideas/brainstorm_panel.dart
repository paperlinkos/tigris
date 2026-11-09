import 'package:flutter/material.dart';
import '../../app/theme/context_theme_extensions.dart';
import '../../models/note.dart';
import '../../services/idea_brief.dart';
import '../../services/idea_chat_service.dart';

class BrainstormPanel extends StatefulWidget {
  final Note root;
  final List<Note> notes;
  final IdeaChatService service;
  BrainstormPanel({
    super.key,
    required this.root,
    required this.notes,
    IdeaChatService? service,
  }) : service = service ?? IdeaChatService();
  @override
  State<BrainstormPanel> createState() => _BrainstormPanelState();
}

class _BrainstormPanelState extends State<BrainstormPanel> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <IdeaChatMessage>[];
  bool _sending = false;
  String? _error;
  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _messages.add(IdeaChatMessage('user', text));
      _input.clear();
      _sending = true;
      _error = null;
    });
    try {
      final answer = await widget.service.reply(
        ideaContext: buildIdeaBrief(widget.root, widget.notes),
        messages: _messages,
      );
      if (mounted) {
        setState(() => _messages.add(IdeaChatMessage('assistant', answer)));
      }
    } on IdeaChatException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        await Future<void>.delayed(Duration.zero);
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.appRaised,
    appBar: AppBar(
      backgroundColor: context.appRaised,
      elevation: 0,
      title: const Text('Brainstorm'),
      actions: [
        IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Text(
            'Chat uses this idea and its pages as context. Nothing from this chat is saved to your notes.',
            style: TextStyle(color: context.appTextSecondary, fontSize: 13),
          ),
        ),
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'What would you like to explore about “${widget.root.title.isEmpty ? 'this idea' : widget.root.title}”?',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.appTextSecondary),
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _messages.length + (_sending ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }
                    final message = _messages[index];
                    final mine = message.role == 'user';
                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(maxWidth: 460),
                        decoration: BoxDecoration(
                          color: mine
                              ? context.appRowSelected
                              : context.appSurfaceSubtle,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(message.content),
                      ),
                    );
                  },
                ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('brainstorm_input'),
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'Explore this idea…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: const Key('brainstorm_send'),
                  tooltip: 'Send',
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
