import 'package:flutter/material.dart';
import '../app/theme/context_theme_extensions.dart';

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
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: context.appBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (canPop) ...[
                        InkWell(
                          key: const Key('calm_scaffold_back_button'),
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(8.0),
                          child: Container(
                            padding: const EdgeInsets.all(7.0),
                            decoration: BoxDecoration(
                              color: context.appSurface,
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(color: context.appBorderSubtle, width: 1.0),
                            ),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 16.0,
                              color: context.appTextPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12.0),
                      ],
                      if (title != null)
                        Text(
                          title!,
                          style: TextStyle(
                            fontSize: 14.0,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.8,
                            color: context.appTextSecondary,
                          ),
                        ),
                    ],
                  ),
                  if (trailingHeaderAction != null)
                    trailingHeaderAction!
                  else
                    const SizedBox.shrink(),
                ],
              ),
              const SizedBox(height: 20.0),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}
