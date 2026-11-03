import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_routes.dart';
import 'screens/admin/interaction_logs_screen.dart';
import 'screens/admin/knowledge_base_screen.dart';
import 'screens/admin/unanswered_inquiries_screen.dart';
import 'screens/activate_account_screen.dart';
import 'screens/entry_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/student_chat_screen.dart';
import 'screens/visitor_chat_screen.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

// Changed: main() is now async so Supabase can connect before the app starts.
// The URL and key are read from env.json (run with --dart-define-from-file=env.json).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );
 
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OASSIS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: _onGenerateRoute,
    );
  }

  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    final routeName = settings.name ?? AppRoutes.entry;

    if (_isAdminRoute(routeName) && !AuthService.instance.isAdmin) {
      final fallback = AuthService.instance.isStudent
          ? const StudentChatScreen()
          : const EntryScreen();
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => fallback,
      );
    }

    if (_isStudentRoute(routeName) && !AuthService.instance.isStudent) {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const EntryScreen(),
      );
    }

    final page = switch (routeName) {
      AppRoutes.splash => const SplashScreen(),
      AppRoutes.entry => const EntryScreen(),
      AppRoutes.activateAccount => ActivateAccountScreen(
        initialEmail: settings.arguments as String?,
      ),
      AppRoutes.visitorChat => const VisitorChatScreen(),
      AppRoutes.studentChat => const StudentChatScreen(),
      AppRoutes.knowledgeBase => const KnowledgeBaseScreen(),
      AppRoutes.unansweredInquiries => const UnansweredInquiriesScreen(),
      AppRoutes.interactionLogs => const InteractionLogsScreen(),
      _ => const EntryScreen(),
    };

    return MaterialPageRoute<void>(settings: settings, builder: (_) => page);
  }

  bool _isAdminRoute(String routeName) => switch (routeName) {
    AppRoutes.knowledgeBase ||
    AppRoutes.unansweredInquiries ||
    AppRoutes.interactionLogs => true,
    _ => false,
  };
  bool _isStudentRoute(String routeName) => routeName == AppRoutes.studentChat;
}
