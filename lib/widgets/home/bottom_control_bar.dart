import 'package:flutter/material.dart';
import '../../app/theme/app_typography.dart';
import '../../app/theme/context_theme_extensions.dart';

class BottomControlBar extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onCreateNote;

  const BottomControlBar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.onCreateNote,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      color: context.appBg,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Left: Search Bar
            Expanded(
              child: Container(
                height: 44.0,
                decoration: BoxDecoration(
                  color: context.appSurface,
                  borderRadius: BorderRadius.circular(22.0),
                  border: Border.all(color: context.appBorderSubtle, width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(context.isDarkMode ? 30 : 10),
                      blurRadius: 4.0,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 18.0,
                      color: context.appTextTertiary,
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        onChanged: onSearchChanged,
                        style: AppTypography.body(
                          fontSize: 14.5,
                          color: context.appTextPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search notes or tasks...',
                          hintStyle: TextStyle(
                            color: context.appTextTertiary,
                            fontSize: 14.0,
                          ),
                          border: InputBorder.none,
                          isCollapsed: true,
                        ),
                      ),
                    ),
                    if (searchController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          searchController.clear();
                          onSearchChanged('');
                        },
                        child: Icon(
                          Icons.cancel_rounded,
                          size: 16.0,
                          color: context.appTextTertiary,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 10.0),

            // Right: Compact FAB Menu Button
            PopupMenuButton<String>(
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
            ),
          ],
        ),
      ),
    );
  }
}
