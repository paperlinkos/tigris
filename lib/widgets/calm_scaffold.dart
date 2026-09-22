import 'package:flutter/material.dart';
import '../app/theme/app_colors.dart';

class CalmScaffold extends StatelessWidget {
  final Widget body;
  final Widget? trailingHeaderAction;
  final String? title;

  const CalmScaffold({
    super.key,
    required this.body,
    this.trailingHeaderAction,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 28.0),
              if (title != null || trailingHeaderAction != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (title != null)
                      Text(
                        title!,
                        style: const TextStyle(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.8,
                          color: AppColors.textSecondary,
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    ?trailingHeaderAction,
                  ],
                ),
                const SizedBox(height: 24.0),
              ],
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}
