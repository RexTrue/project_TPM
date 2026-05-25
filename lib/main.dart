import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/services/database_service.dart';
import 'core/services/supabase_service.dart';
import 'core/services/location_service.dart';
import 'core/services/biometric_service.dart';
import 'core/services/gemini_service.dart';
import 'data/repositories/user_repository.dart';
import 'data/repositories/material_repository.dart';
import 'data/repositories/quiz_repository.dart';
import 'data/repositories/question_repository.dart';
import 'data/repositories/score_repository.dart';
import 'data/repositories/user_location_repository.dart';
import 'data/repositories/chat_repository.dart';
import 'data/sources/local/user_local_data_source.dart';
import 'data/sources/local/material_local_data_source.dart';
import 'data/sources/local/quiz_local_data_source.dart';
import 'data/sources/local/question_local_data_source.dart';
import 'data/sources/local/score_local_data_source.dart';
import 'data/sources/local/user_location_local_data_source.dart';
import 'data/sources/remote/chat_remote_data_source.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/question_provider.dart';
import 'presentation/providers/score_provider.dart';
import 'presentation/providers/chat_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/providers/location_provider.dart';
import 'presentation/providers/mentor_provider.dart';
import 'presentation/providers/student_provider.dart';
import 'presentation/screens/splash/splash_screen.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/auth/register_screen.dart';
import 'presentation/screens/chatbot/chatbot_screen.dart';
import 'presentation/screens/game/quiz_minigame_screen.dart';
import 'presentation/screens/game/compass_hunt_screen.dart';
import 'presentation/screens/profile/membership_screen.dart';
import 'presentation/screens/profile/edit_profile_screen.dart';
import 'presentation/screens/profile/mentor_profile_screen.dart';
import 'presentation/screens/profile/profile_screen.dart';
import 'presentation/screens/profile/statistics_screen.dart';
import 'presentation/screens/notifications/updates_notification_screen.dart';
import 'presentation/screens/leaderboard/leaderboard_screen.dart';
import 'presentation/screens/feedback/feedback_screen.dart';
import 'presentation/screens/mentor/mentor_upload_screen.dart';
import 'presentation/screens/mentor/mentor_create_quiz_screen.dart';
import 'presentation/screens/mentor/mentor_materials_screen.dart';
import 'presentation/screens/mentor/mentor_quiz_list_screen.dart';
import 'presentation/screens/student/student_materials_screen.dart';
import 'presentation/screens/student/student_quiz_list_screen.dart';
import 'presentation/screens/student/student_take_quiz_screen.dart';
import 'presentation/screens/student/mentor_search_screen.dart';
import 'presentation/navigation/navigation.dart';
import 'presentation/navigation/app_shell.dart';
import 'notifications/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    _logWebStorageOrigin();
  }

  // Initialize Supabase (if configured)
  final supa = SupabaseService();
  await supa.init();

  final databaseService = DatabaseService();

  if (!kIsWeb) {
    // Initialize database and verify integrity before starting UI.
    final healthy = await databaseService.ensureHealthy();
    if (!healthy) {
      // If integrity check fails, try opening once more to let onUpgrade run.
      try {
        await databaseService.database;
      } catch (_) {
        // Log and continue. UI will still run but DB operations should be guarded.
      }
    }

    // Migrate any cached users into SQLite before launching UI.
    try {
      final userLocal = UserLocalDataSource(databaseService);
      await userLocal.migratePrefsToDb();
    } catch (_) {
      // Ignore migration failures.
    }
  }

  runApp(MyApp(databaseService: databaseService));
}

void _logWebStorageOrigin() {
  final origin = Uri.base.origin;
  debugPrint('[WebStorage] Running on origin: $origin');

  if (Uri.base.port != 5000) {
    debugPrint(
      '[WebStorage] WARNING: Flutter Web storage is separated by hostname and port.',
    );
    debugPrint(
      '[WebStorage] Current port is ${Uri.base.port}, so previous data from another port will not be visible.',
    );
    debugPrint(
      '[WebStorage] Run with: flutter run -d chrome --web-hostname 127.0.0.1 --web-port 5000',
    );
  }
}

class MyApp extends StatelessWidget {
  final DatabaseService? databaseService;

  const MyApp({super.key, this.databaseService});

  @override
  Widget build(BuildContext context) {
    // Use provided DatabaseService (initialized at startup) or create a new one
    final databaseService = this.databaseService ?? DatabaseService();

    // Initialize Gemini Service untuk AI Chatbot
    final geminiService = GeminiService();

    // Initialize Data Sources
    final userLocalDataSource = UserLocalDataSource(databaseService);
    final materialLocalDataSource = MaterialLocalDataSource(databaseService);
    final quizLocalDataSource = QuizLocalDataSource(databaseService);
    final questionLocalDataSource = QuestionLocalDataSource(databaseService);
    final scoreLocalDataSource = ScoreLocalDataSource(databaseService);
    final userLocationLocalDataSource = UserLocationLocalDataSource(
      databaseService,
    );
    final chatRemoteDataSource = ChatRemoteDataSource(
      geminiService,
      materialLocalDataSource,
    );

    // Initialize Repositories
    final userRepository = UserRepository(userLocalDataSource);
    final materialRepository = MaterialRepository(materialLocalDataSource);
    final quizRepository = QuizRepository(quizLocalDataSource);
    final questionRepository = QuestionRepository(questionLocalDataSource);
    final scoreRepository = ScoreRepository(scoreLocalDataSource);
    final userLocationRepository = UserLocationRepository(
      userLocationLocalDataSource,
    );
    final chatRepository = ChatRepository(chatRemoteDataSource);
    final locationService = LocationService();
    final biometricService = BiometricService();
    final notificationService = NotificationService();
    notificationService.initialize();

    return MultiProvider(
      providers: [
        // Providers
        ChangeNotifierProvider(create: (_) => AuthProvider(userRepository)),
        ChangeNotifierProvider(
          create: (_) => MentorProvider(
            materialRepository,
            quizRepository,
            userRepository,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => StudentProvider(
            materialRepository,
            quizRepository,
            userRepository,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => QuestionProvider(questionRepository),
        ),
        ChangeNotifierProvider(create: (_) => ScoreProvider(scoreRepository)),
        ChangeNotifierProvider(create: (_) => ChatProvider(chatRepository)),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (_) =>
              LocationProvider(locationService, userLocationRepository),
        ),
        Provider<BiometricService>.value(value: biometricService),
        Provider<NotificationService>.value(value: notificationService),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'EduFun',
            locale: const Locale('id', 'ID'),
            supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.isDarkMode
                ? ThemeMode.dark
                : ThemeMode.light,
            debugShowCheckedModeBanner: false,
            initialRoute: AppNavigation.splash,
            routes: {
              AppNavigation.splash: (context) => const SplashScreen(),
              AppNavigation.login: (context) => const LoginScreen(),
              AppNavigation.register: (context) => const RegisterScreen(),
              AppNavigation.home: (context) => const AppShell(),
              AppNavigation.quiz: (context) => const QuizMinigameScreen(),
              AppNavigation.chatbot: (context) => const ChatbotScreen(),
              AppNavigation.quizMinigame: (context) =>
                  const QuizMinigameScreen(),
              AppNavigation.compassHunt: (context) => const CompassHuntScreen(),
              AppNavigation.membership: (context) => const MembershipScreen(),
              AppNavigation.mentorMembership: (context) {
                final args =
                    ModalRoute.of(context)?.settings.arguments
                        as Map<String, dynamic>?;
                return MembershipScreen(
                  mentorId: args?['mentorId'] as int?,
                  mentorName: args?['mentorName'] as String?,
                );
              },
              AppNavigation.profile: (context) => const ProfileScreen(),
              AppNavigation.editProfile: (context) => const EditProfileScreen(),
              AppNavigation.mentorProfile: (context) {
                final args =
                    ModalRoute.of(context)?.settings.arguments
                        as Map<String, dynamic>?;
                final mentorId = args != null && args['mentorId'] != null
                    ? args['mentorId'] as int
                    : 0;
                return MentorProfileScreen(mentorId: mentorId);
              },
              AppNavigation.statistics: (context) {
                final args =
                    ModalRoute.of(context)?.settings.arguments
                        as Map<String, dynamic>?;
                return StatisticsScreen(userId: args?['userId'] as int?);
              },
              AppNavigation.notifications: (context) =>
                  const UpdatesNotificationScreen(),
              AppNavigation.leaderboard: (context) => const LeaderboardScreen(),
              AppNavigation.feedback: (context) => const FeedbackScreen(),
              AppNavigation.mentorUpload: (context) =>
                  const MentorUploadScreen(),
              AppNavigation.mentorMaterials: (context) =>
                  const MentorMaterialsScreen(),
              AppNavigation.mentorQuizzes: (context) =>
                  const MentorQuizListScreen(),
              AppNavigation.mentorCreateQuiz: (context) =>
                  const MentorCreateQuizScreen(),
              AppNavigation.studentMaterials: (context) =>
                  const StudentMaterialsScreen(),
              AppNavigation.studentQuizzes: (context) =>
                  const StudentQuizListScreen(),
              AppNavigation.mentorSearch: (context) =>
                  const MentorSearchScreen(),
              AppNavigation.studentTakeQuiz: (context) {
                final args =
                    ModalRoute.of(context)?.settings.arguments
                        as Map<String, dynamic>?;
                final quizId = args != null && args['quizId'] != null
                    ? args['quizId'] as int
                    : 0;
                return StudentTakeQuizScreen(quizId: quizId);
              },
            },
          );
        },
      ),
    );
  }
}
