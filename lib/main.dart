import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'app/di/repository_scope.dart';
import 'app/theme/app_theme.dart';
import 'app/navigation/app_shell.dart';
import 'controllers/theme_controller.dart';
import 'persistence/app_storage.dart';
import 'persistence/storage_interface.dart';
import 'repositories/flashcard_repository.dart';
import 'repositories/firestore_cloud_note_store.dart';
import 'repositories/local_flashcard_repository.dart';
import 'repositories/local_note_repository.dart';
import 'repositories/local_quiz_repository.dart';
import 'repositories/local_review_repository.dart';
import 'repositories/note_repository.dart';
import 'repositories/offline_first_note_repository.dart';
import 'repositories/quiz_repository.dart';
import 'repositories/review_repository.dart';
import 'services/cloud_sync_service.dart';
import 'services/note_sync_engine.dart';
import 'services/sync_coordinator.dart';

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

class _PersonalLearningAppState extends State<PersonalLearningApp>
    with WidgetsBindingObserver {
  late final NoteRepository _noteRepository;
  late final ReviewRepository _reviewRepository;
  late final FlashcardRepository _flashcardRepository;
  late final QuizRepository _quizRepository;
  late final CloudSyncService _syncService;
  late final ThemeController _themeController;
  NoteSyncEngine? _syncEngine;
  SyncCoordinator? _syncCoordinator;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final storage = widget.storage ?? AppStorage.instance;
    _syncService = CloudSyncService();
    _themeController =
        widget.themeController ?? ThemeController(storage: storage);

    if (widget.noteRepository != null) {
      _noteRepository = widget.noteRepository!;
      _syncService.setSignedOut();
    } else {
      final localRepo = LocalNoteRepository(storage: storage);
      try {
        if (Firebase.apps.isNotEmpty) {
          if (!kIsWeb) {
            FirebaseFirestore.instance.settings = const Settings(
              persistenceEnabled: false,
            );
          }
          final engine = NoteSyncEngine(
            storage: storage,
            localRepo: localRepo,
            cloud: FirestoreCloudNoteStore(),
            status: _syncService,
          );
          final coordinator = SyncCoordinator(
            authChanges: FirebaseAuth.instance.authStateChanges().map(
              (user) => user == null || user.isAnonymous ? null : user.uid,
            ),
            connectivityChanges: _connectivityChanges(),
            runSync: (uid) async {
              await engine.sync(uid);
            },
            status: _syncService,
          );
          _syncEngine = engine;
          _syncCoordinator = coordinator;
          coordinator.start();
        } else {
          _syncService.setSignedOut();
        }
      } catch (_) {
        _syncService.setSignedOut();
      }
      _noteRepository = OfflineFirstNoteRepository(
        localRepo: localRepo,
        syncService: _syncService,
        syncEngine: _syncEngine,
        onLocalChange: _syncCoordinator?.requestSoon,
        onSyncRequested: _syncCoordinator?.syncNow,
      );
    }
    _reviewRepository =
        widget.reviewRepository ?? LocalReviewRepository(storage: storage);
    _flashcardRepository =
        widget.flashcardRepository ??
        LocalFlashcardRepository(storage: storage);
    _quizRepository =
        widget.quizRepository ?? LocalQuizRepository(storage: storage);
  }

  /// Starts with the current state, because the plugin only reports changes and
  /// an app opened offline would otherwise never see itself come back online.
  Stream<bool> _connectivityChanges() async* {
    bool isOnline(List<ConnectivityResult> results) =>
        !results.every((result) => result == ConnectivityResult.none);
    final connectivity = Connectivity();
    yield isOnline(await connectivity.checkConnectivity());
    yield* connectivity.onConnectivityChanged.map(isOnline);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _syncCoordinator?.onAppResumed();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncCoordinator?.dispose();
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
              title: 'Tigris',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: _themeController.themeMode,
              home: AppShell(
                storage: widget.storage,
                noteRepository: _noteRepository,
                reviewRepository: _reviewRepository,
                syncService: _syncService,
                syncEngine: _syncEngine,
                syncCoordinator: _syncCoordinator,
              ),
            );
          },
        ),
      ),
    );
  }
}
