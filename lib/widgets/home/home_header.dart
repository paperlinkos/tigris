import 'package:flutter/material.dart';
import '../../app/theme/context_theme_extensions.dart';
import '../brand/tigris_logo.dart';

enum HomeViewMode { notes, tasks }

class HomeHeader extends StatelessWidget {
  final HomeViewMode viewMode;
  final ValueChanged<HomeViewMode> onViewModeChanged;

  const HomeHeader({
    super.key,
    required this.viewMode,
    required this.onViewModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left: Sidebar Toggle Button
        InkWell(
          key: const Key('sidebar_toggle_button'),
          onTap: () {
            Scaffold.of(context).openDrawer();
          },
          borderRadius: BorderRadius.circular(8.0),
          child: Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: context.appSurface,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: context.appBorderSubtle, width: 1.0),
            ),
            child: Icon(
              Icons.view_sidebar_outlined,
              size: 20.0,
              color: context.appTextPrimary,
            ),
          ),
        ),

        // Center: Notes / Tasks Segmented Toggle
        Container(
          height: 36.0,
          padding: const EdgeInsets.all(3.0),
          decoration: BoxDecoration(
            color: context.appSurfaceSubtle,
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(color: context.appBorderSubtle, width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSegment(
                context,
                label: 'Notes',
                isSelected: viewMode == HomeViewMode.notes,
                onTap: () => onViewModeChanged(HomeViewMode.notes),
              ),
              _buildSegment(
                context,
                label: 'Tasks',
                isSelected: viewMode == HomeViewMode.tasks,
                onTap: () => onViewModeChanged(HomeViewMode.tasks),
              ),
            ],
          ),
        ),

        // Right: Tigris Brand Mark Emblem
        const Padding(
          padding: EdgeInsets.only(right: 4.0),
          child: TigrisLogo(size: 22.0),
        ),
      ],
    );
  }

  Widget _buildSegment(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: isSelected ? context.appSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withAlpha(context.isDarkMode ? 30 : 15),
                    blurRadius: 3.0,
                    offset: const Offset(0, 1),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? context.appTextPrimary : context.appTextSecondary,
          ),
        ),
      ),
    );
  }
}
