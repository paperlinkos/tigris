import 'package:flutter/material.dart';
import '../app/theme/app_typography.dart';
import '../app/theme/context_theme_extensions.dart';
import '../controllers/theme_controller.dart';
import '../services/auth_service.dart';
import '../widgets/calm_scaffold.dart';
import 'login_screen.dart';
import 'notion_import_screen.dart';

class SettingsScreen extends StatelessWidget {
  final AuthService? authService;

  const SettingsScreen({
    super.key,
    this.authService,
  });

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeControllerScope.maybeOf(context);
    final currentMode = themeController?.themeMode ?? ThemeMode.system;
    final auth = authService ?? AuthService();
    final user = auth.currentUser;
    final isGuest = user == null || user.isAnonymous;

    return CalmScaffold(
      title: 'SETTINGS',
      body: ListView(
        padding: const EdgeInsets.only(top: 20.0),
        children: [
          Text(
            'Preferences',
            style: AppTypography.title(
              fontSize: 26.0,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            'Fine-tune reading, sync environment, and account settings.',
            style: AppTypography.subtitle(
              fontSize: 14.0,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 32.0),

          // Account Section
          _buildSectionHeader(context, 'Account & Sync'),
          const SizedBox(height: 12.0),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: context.appSurface,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: context.appBorderSubtle, width: 0.8),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: context.appSurfaceSubtle,
                  radius: 20.0,
                  child: Icon(
                    isGuest ? Icons.person_outline_rounded : Icons.account_circle_rounded,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(width: 14.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isGuest ? 'Guest User (Offline Mode)' : (user.displayName ?? user.email ?? 'Signed In'),
                        style: AppTypography.uiHeadline(
                          fontSize: 15.0,
                          fontWeight: FontWeight.w600,
                          color: context.appTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        isGuest ? 'Notes save locally. Sign in to backup to cloud.' : (user.email ?? 'Cloud sync active'),
                        style: AppTypography.uiLabel(
                          fontSize: 12.0,
                          color: context.appTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    if (isGuest) {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => LoginScreen(authService: auth)),
                      );
                    } else {
                      await auth.signOut();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Signed out successfully')),
                        );
                      }
                    }
                  },
                  child: Text(
                    isGuest ? 'Sign In' : 'Sign Out',
                    style: AppTypography.uiLabel(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isGuest ? context.appTextPrimary : Colors.redAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32.0),

          // Appearance Section (Theme Selector)
          _buildSectionHeader(context, 'Appearance'),
          const SizedBox(height: 12.0),
          Container(
            decoration: BoxDecoration(
              color: context.appSurface,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: context.appBorderSubtle, width: 0.8),
            ),
            child: Column(
              children: [
                _buildThemeRadioTile(
                  context,
                  title: 'Light (Warm Paper)',
                  subtitle: 'Calm off-white reading environment',
                  icon: Icons.light_mode_outlined,
                  mode: ThemeMode.light,
                  groupValue: currentMode,
                  onChanged: (mode) => themeController?.setThemeMode(mode),
                ),
                Divider(height: 1.0, color: context.appBorderSubtle),
                _buildThemeRadioTile(
                  context,
                  title: 'Dark (Obsidian Charcoal)',
                  subtitle: 'Deep dark slate night mode',
                  icon: Icons.dark_mode_outlined,
                  mode: ThemeMode.dark,
                  groupValue: currentMode,
                  onChanged: (mode) => themeController?.setThemeMode(mode),
                ),
                Divider(height: 1.0, color: context.appBorderSubtle),
                _buildThemeRadioTile(
                  context,
                  title: 'System Default',
                  subtitle: 'Follow device display settings',
                  icon: Icons.brightness_auto_outlined,
                  mode: ThemeMode.system,
                  groupValue: currentMode,
                  onChanged: (mode) => themeController?.setThemeMode(mode),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32.0),

          _buildSettingsItem(
            context,
            title: 'Spaced Repetition',
            subtitle: 'Standard SM-2 Interval Calculation',
            icon: Icons.schedule_rounded,
          ),
          Divider(color: context.appBorderSubtle),
          _buildSettingsItem(
            context,
            title: 'Data & Storage',
            subtitle: 'Local-first with Cloud Firestore background sync',
            icon: Icons.cloud_done_outlined,
          ),
          Divider(color: context.appBorderSubtle),
          _buildSettingsItem(
            context,
            title: 'Import from Notion',
            subtitle: 'Convert Notion workspace pages into native notes',
            icon: Icons.import_export_rounded,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotionImportScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: AppTypography.uiLabel(
        fontSize: 12.0,
        fontWeight: FontWeight.w600,
        color: context.appTextTertiary,
      ).copyWith(letterSpacing: 0.8),
    );
  }

  Widget _buildThemeRadioTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required ThemeMode mode,
    required ThemeMode groupValue,
    required ValueChanged<ThemeMode> onChanged,
  }) {
    final isSelected = mode == groupValue;
    return ListTile(
      onTap: () => onChanged(mode),
      leading: Icon(
        icon,
        size: 20.0,
        color: isSelected ? context.appTextPrimary : context.appTextSecondary,
      ),
      title: Text(
        title,
        style: AppTypography.uiHeadline(
          fontSize: 15.0,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: context.appTextPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTypography.uiLabel(
          fontSize: 12.0,
          color: context.appTextSecondary,
        ),
      ),
      trailing: isSelected
          ? Icon(
              Icons.check_circle_rounded,
              size: 20.0,
              color: context.appTextPrimary,
            )
          : Icon(
              Icons.radio_button_unchecked_rounded,
              size: 20.0,
              color: context.appTextTertiary,
            ),
    );
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 4.0),
        child: Row(
          children: [
            Icon(icon, size: 22.0, color: context.appTextSecondary),
            const SizedBox(width: 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.uiHeadline(
                      fontSize: 15.0,
                      color: context.appTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    subtitle,
                    style: AppTypography.uiLabel(
                      fontSize: 12.5,
                      color: context.appTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14.0,
                color: context.appTextTertiary,
              ),
          ],
        ),
      ),
    );
  }
}
