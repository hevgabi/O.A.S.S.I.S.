import 'package:flutter/material.dart';

import 'app_routes.dart';
import 'screens/admin/interaction_logs_screen.dart';
import 'screens/admin/knowledge_base_screen.dart';
import 'screens/admin/unanswered_inquiries_screen.dart';
import 'screens/entry_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/student_chat_screen.dart';
import 'screens/visitor_chat_screen.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

void main() {
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

    final page = switch (routeName) {
      AppRoutes.splash => const SplashScreen(),
      AppRoutes.entry => const EntryScreen(),
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
}
