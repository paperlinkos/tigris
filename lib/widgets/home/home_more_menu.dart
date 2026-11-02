import 'package:flutter/material.dart';
import '../../app/di/repository_scope.dart';
import '../../app/theme/app_typography.dart';
import '../../app/theme/context_theme_extensions.dart';
import '../../controllers/theme_controller.dart';
import '../../repositories/offline_first_note_repository.dart';
import '../../repositories/task_repository.dart';
import '../../screens/login_screen.dart';
import '../../screens/review_session_screen.dart';
import '../../screens/settings_screen.dart';
import '../../services/auth_service.dart';
import '../../services/backup_service.dart';
import '../../services/cloud_sync_service.dart';
import '../../services/drive_account.dart';
import '../../services/note_sync_engine.dart';
import '../../services/sync_coordinator.dart';
import '../../views/tasks_view.dart';
import '../desktop_panel.dart';

String syncStatusText(SyncState state) => switch (state) {
  SyncState.signedOut => 'On this device only',
  SyncState.savedLocally => 'Saved on this device',
  SyncState.syncing => 'Syncing...',
  SyncState.synced => 'Synced',
  SyncState.offline => 'Offline. Will sync when you reconnect.',
  SyncState.accountMismatch =>
    'Sync paused. These notes belong to another account.',
  SyncState.error => "Couldn't sync. Will try again.",
};

class HomeMoreMenuActions {
  final BuildContext context;
  final CloudSyncService? syncService;
  final NoteSyncEngine? syncEngine;
  final SyncCoordinator? syncCoordinator;
  final BackupService? backupService;
  final DriveAccount? driveAccount;
  final TaskRepository taskRepository;
  final VoidCallback? onStartReview;

  HomeMoreMenuActions({
    required this.context,
    required this.taskRepository,
    this.syncService,
    this.syncEngine,
    this.syncCoordinator,
    this.backupService,
    this.driveAccount,
    this.onStartReview,
  });

  Future<void> openTasks() => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => Scaffold(
        backgroundColor: context.appBg,
        appBar: AppBar(
          backgroundColor: context.appBg,
          title: Text(
            'Tasks',
            style: AppTypography.uiHeadline(color: context.appTextPrimary),
          ),
        ),
        body: TasksView(taskRepository: taskRepository, searchQuery: ''),
      ),
    ),
  );

  Future<void> sync() async {
    final repo = RepositoryScope.maybeOf(context)?.noteRepository;
    if (repo is OfflineFirstNoteRepository) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Syncing notes...')));
      await repo.syncWithCloud();
    }
  }

  Future<void> openSignIn() => openScreen(
    context,
    (_) => LoginScreen(authService: AuthService()),
    width: 420,
    height: 640,
  );

  Future<void> openSettings() => openScreen(
    context,
    (context) => SettingsScreen(
      syncService: syncService,
      syncEngine: syncEngine,
      syncCoordinator: syncCoordinator,
      backupService: backupService,
      driveAccount: driveAccount,
    ),
  );

  Future<void> openReview() async {
    if (onStartReview != null) {
      onStartReview!();
      return;
    }
    final scope = RepositoryScope.maybeOf(context);
    if (scope == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RepositoryScope(
          noteRepository: scope.noteRepository,
          reviewRepository: scope.reviewRepository,
          flashcardRepository: scope.flashcardRepository,
          quizRepository: scope.quizRepository,
          child: const ReviewSessionScreen(),
        ),
      ),
    );
  }

  void toggleTheme() => ThemeControllerScope.maybeOf(context)?.toggleDarkMode();
}

class HomeMoreMenu extends StatelessWidget {
  final VoidCallback onSignIn;
  final VoidCallback onReview;
  final VoidCallback onTasks;
  final VoidCallback onSync;
  final VoidCallback onTheme;
  final VoidCallback onSettings;

  const HomeMoreMenu({
    super.key,
    required this.onSignIn,
    required this.onReview,
    required this.onTasks,
    required this.onSync,
    required this.onTheme,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeControllerScope.maybeOf(context);
    final signedOut = !AuthService().isAuthenticated;
    return PopupMenuButton<String>(
      key: const Key('home_more_menu'),
      tooltip: 'More',
      icon: Icon(Icons.more_horiz_rounded, color: context.appTextPrimary),
      color: context.appRaised,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: context.appBorder),
      ),
      onSelected: (value) {
        switch (value) {
          case 'signin':
            onSignIn();
          case 'review':
            onReview();
          case 'tasks':
            onTasks();
          case 'sync':
            onSync();
          case 'theme':
            onTheme();
          case 'settings':
            onSettings();
        }
      },
      itemBuilder: (context) => [
        if (signedOut) _item(context, 'signin', 'Sign in'),
        _item(context, 'review', 'Review'),
        _item(context, 'tasks', 'Tasks'),
        _item(context, 'sync', 'Sync notes'),
        if (themeController != null)
          _item(
            context,
            'theme',
            context.isDarkMode ? 'Light mode' : 'Dark mode',
          ),
        _item(context, 'settings', 'Settings'),
      ],
    );
  }

  PopupMenuItem<String> _item(
    BuildContext context,
    String value,
    String label,
  ) => PopupMenuItem<String>(
    value: value,
    height: 42,
    child: Text(
      label,
      style: AppTypography.uiLabel(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: context.appTextPrimary,
      ),
    ),
  );
}
