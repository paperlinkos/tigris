import 'package:flutter/material.dart';
import '../../app/theme/app_typography.dart';
import '../../app/theme/context_theme_extensions.dart';

class FabMenuButton extends StatelessWidget {
  final VoidCallback onCreateNote;

  const FabMenuButton({
    super.key,
    required this.onCreateNote,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      key: const Key('home_fab_menu'),
      offset: const Offset(0, -46),
      elevation: 4,
      color: context.appSurface,
      menuPadding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 100, maxWidth: 120),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
        side: BorderSide(color: context.appBorderSubtle, width: 1.0),
      ),
      onSelected: (value) {
        if (value == 'new_note') {
          onCreateNote();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'new_note',
          height: 38.0,
          padding: const EdgeInsets.symmetric(horizontal: 14.0),
          child: Center(
            child: Text(
              'New note',
              style: AppTypography.uiHeadline(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: context.appTextPrimary,
              ),
            ),
          ),
        ),
      ],
      child: Material(
        elevation: 4.0,
        shape: const CircleBorder(),
        color: context.appTextPrimary,
        child: SizedBox(
          width: 44.0,
          height: 44.0,
          child: Center(
            child: Icon(
              Icons.add_rounded,
              color: context.appBg,
              size: 24.0,
            ),
          ),
        ),
      ),
    );
  }
}
