import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'app/di/repository_scope.dart';
import 'app/theme/app_theme.dart';
import 'app/navigation/app_shell.dart';
import 'controllers/theme_controller.dart';
import 'persistence/preferences_storage.dart';
import 'persistence/storage_interface.dart';
import 'repositories/flashcard_repository.dart';
import 'repositories/firestore_note_repository.dart';
import 'repositories/local_flashcard_repository.dart';
import 'repositories/local_note_repository.dart';
import 'repositories/local_quiz_repository.dart';
import 'repositories/local_review_repository.dart';
import 'repositories/note_repository.dart';
import 'repositories/offline_first_note_repository.dart';
import 'repositories/quiz_repository.dart';
import 'repositories/review_repository.dart';
import 'services/cloud_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization warning: $e');
  }
  runApp(const PersonalLearningApp());
}

class PersonalLearningApp extends StatefulWidget {
  final StorageInterface? storage;
  final NoteRepository? noteRepository;
  final ReviewRepository? reviewRepository;
  final FlashcardRepository? flashcardRepository;
  final QuizRepository? quizRepository;
  final ThemeController? themeController;

  const PersonalLearningApp({
    super.key,
    this.storage,
    this.noteRepository,
    this.reviewRepository,
    this.flashcardRepository,
    this.quizRepository,
    this.themeController,
  });

  @override
  State<PersonalLearningApp> createState() => _PersonalLearningAppState();
}

class _PersonalLearningAppState extends State<PersonalLearningApp> {
  late final NoteRepository _noteRepository;
  late final ReviewRepository _reviewRepository;
  late final FlashcardRepository _flashcardRepository;
  late final QuizRepository _quizRepository;
  late final CloudSyncService _syncService;
  late final ThemeController _themeController;
  StreamSubscription<User?>? _authSub;
  Timer? _periodicSyncTimer;

  @override
  void initState() {
    super.initState();
    final storage = widget.storage ?? PreferencesStorage();
    _syncService = CloudSyncService();
    _themeController = widget.themeController ?? ThemeController(storage: storage);

    if (widget.noteRepository != null) {
      _noteRepository = widget.noteRepository!;
    } else {
      final localRepo = LocalNoteRepository(storage: storage);
      FirestoreNoteRepository? firestoreRepo;
      try {
        if (Firebase.apps.isNotEmpty) {
          firestoreRepo = FirestoreNoteRepository();
        }
      } catch (_) {
        firestoreRepo = null;
      }
      _noteRepository = OfflineFirstNoteRepository(
        localRepo: localRepo,
        firestoreRepo: firestoreRepo,
        syncService: _syncService,
      );
    }
    _reviewRepository = widget.reviewRepository ?? LocalReviewRepository(storage: storage);
    _flashcardRepository = widget.flashcardRepository ?? LocalFlashcardRepository(storage: storage);
    _quizRepository = widget.quizRepository ?? LocalQuizRepository(storage: storage);

    _setupCloudSyncListeners();
  }

  void _setupCloudSyncListeners() {
    try {
      if (Firebase.apps.isNotEmpty) {
        _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
          if (user != null && !user.isAnonymous) {
            _triggerCloudSync();
          }
        });
      }
    } catch (_) {}

    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null && !currentUser.isAnonymous) {
          _triggerCloudSync();
        }
      } catch (_) {}
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerCloudSync();
    });
  }

  void _triggerCloudSync() {
    final repo = _noteRepository;
    if (repo is OfflineFirstNoteRepository) {
      repo.syncWithCloud();
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _periodicSyncTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepositoryScope(
      noteRepository: _noteRepository,
      reviewRepository: _reviewRepository,
      flashcardRepository: _flashcardRepository,
      quizRepository: _quizRepository,
      child: ThemeControllerScope(
        themeController: _themeController,
        child: ListenableBuilder(
          listenable: _themeController,
          builder: (context, child) {
            return MaterialApp(
              title: 'Active Learning',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: _themeController.themeMode,
              home: AppShell(
                storage: widget.storage,
                noteRepository: _noteRepository,
                reviewRepository: _reviewRepository,
              ),
            );
          },
        ),
      ),
    );
  }
}
