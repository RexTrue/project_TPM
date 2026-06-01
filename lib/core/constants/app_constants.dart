/// App Constants
class AppConstants {
  // API
  static const String baseUrl = 'https://api.example.com';
  static const String timeout = '30';

  // Database
  static const String databaseName = 'edufun.db';
  static const int databaseVersion = 9;

  // Supabase can be enabled with:
  // flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  // Choose backend: 'sqlite', 'supabase', or 'auto'.
  // With 'auto', Supabase is used whenever SUPABASE_URL and SUPABASE_ANON_KEY are configured.
  // Default is now set to 'supabase' so the remote database is used by default.
  static const String databaseBackend = String.fromEnvironment(
    'DATABASE_BACKEND',
    defaultValue: 'supabase',
  );

  // Shared Preferences Keys
  static const String userIdKey = 'user_id';
  static const String usernameKey = 'username';
  static const String isLoggedInKey = 'is_logged_in';
  static const String userPhotoKey = 'user_photo';
  static const String authTokenKey = 'auth_token';
  static const String themeKey = 'theme';
  static const String isDarkMode = 'is_dark_mode';

  // Game
  static const int maxQuizTime = 30; // seconds
  static const int minScoreToPass = 60;

  // Notification
  static const int notificationId = 1;
  static const String notificationChannel = 'edufun_channel';
  static const String notificationTitle = 'EduFun';
  static const String notificationBody = 'Ayo belajar hari ini!';

  // Animation Duration
  static const Duration animationDuration = Duration(milliseconds: 300);

  // Categories
  static const List<String> categories = ['Math', 'Science', 'General'];

  // Difficulty Levels
  static const List<String> difficulties = ['Easy', 'Medium', 'Hard'];

  // Sensors
  static const double shakeThreshold = 15.0;
}
