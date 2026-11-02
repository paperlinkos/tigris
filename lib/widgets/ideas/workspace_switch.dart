import 'package:flutter/material.dart';
import '../../app/theme/app_typography.dart';
import '../../app/theme/context_theme_extensions.dart';
import '../../models/note.dart';

class WorkspaceSwitch extends StatelessWidget {
  final String workspace;
  final ValueChanged<String> onChanged;
  const WorkspaceSwitch({super.key, required this.workspace, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    height: 30,
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(color: context.appSidebar, borderRadius: BorderRadius.circular(6)),
    child: Row(children: [
      Expanded(child: _segment(context, Note.notesWorkspace, 'Notes')),
      Expanded(child: _segment(context, Note.ideasWorkspace, 'Ideas')),
    ]),
  );

  Widget _segment(BuildContext context, String value, String label) {
    final selected = workspace == value;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: TextButton(
        key: Key('workspace_${value}_button'),
        onPressed: () => onChanged(value),
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 26),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          backgroundColor: selected ? context.appRaised : Colors.transparent,
          foregroundColor: context.appTextPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: selected ? BorderSide(color: context.appBorder) : BorderSide.none),
        ),
        child: Text(label, style: AppTypography.uiLabel(fontSize: 13, fontWeight: FontWeight.w500, color: context.appTextPrimary)),
      ),
    );
  }
}
