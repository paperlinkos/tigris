import 'package:flutter/material.dart';
import '../app/theme/app_colors.dart';
import '../app/theme/app_typography.dart';
import '../widgets/calm_scaffold.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CalmScaffold(
      title: 'SETTINGS',
      body: ListView(
        padding: const EdgeInsets.only(top: 20.0),
        children: [
          Text(
            'Preferences',
            style: AppTypography.title(fontSize: 26.0),
          ),
          const SizedBox(height: 8.0),
          Text(
            'Fine-tune your reading, recall intervals, and storage environment.',
            style: AppTypography.subtitle(fontSize: 14.0),
          ),
          const SizedBox(height: 36.0),
          _buildSettingsItem(
            title: 'Appearance',
            subtitle: 'Warm off-white (Default)',
            icon: Icons.palette_outlined,
          ),
          const Divider(),
          _buildSettingsItem(
            title: 'Spaced Repetition',
            subtitle: 'Standard SM-2 Interval Calculation',
            icon: Icons.schedule_rounded,
          ),
          const Divider(),
          _buildSettingsItem(
            title: 'Data & Storage',
            subtitle: 'Local in-memory storage (Phase 0 Foundation)',
            icon: Icons.storage_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          Icon(icon, size: 22.0, color: AppColors.textSecondary),
          const SizedBox(width: 16.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.uiHeadline(fontSize: 15.0),
                ),
                const SizedBox(height: 4.0),
                Text(
                  subtitle,
                  style: AppTypography.uiLabel(fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
