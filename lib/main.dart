import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Pagine
import 'pages/profile_page.dart';
import 'pages/users/signup_page.dart';
import 'pages/users/login_page.dart';
import 'pages/users/user_page.dart';
import 'pages/search_page.dart';
import 'pages/favorites_page.dart';
import 'pages/notifications_page.dart';
import 'pages/test_page.dart';

// Logiche
import 'logiche/auth/auth_service.dart';
import 'logiche/navigation/app_routes.dart';
import 'logiche/auth/auth_gate.dart';

// ⭐ NotificationController
import 'logiche/notifications/notification_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ⭐ Inizializza Hive
  await Hive.initFlutter();
  await Hive.openBox('notifications');

  // ⭐ Carica notifiche salvate
  await NotificationController.instance.init();

  // ⭐ Inizializza Amplify/Cognito
  await AuthService.configure();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tipicooo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),

      // ⭐ L'app parte da AuthGate
      initialRoute: AppRoutes.home,

      routes: {
        AppRoutes.home: (context) => const AuthGate(),

        // Pagine principali
        AppRoutes.profile: (context) => const ProfilePage(),
        AppRoutes.signup: (context) => const SignupPage(),
        AppRoutes.login: (context) => const LoginPage(),
        AppRoutes.user: (context) => const UserPage(),
        AppRoutes.search: (context) => const SearchPage(),
        AppRoutes.favorites: (context) => const FavoritesPage(),
        AppRoutes.notifications: (context) => const NotificationsPage(),

        // TestPage
        AppRoutes.testPage: (context) => const TestPage(),
      },
    );
  }
}