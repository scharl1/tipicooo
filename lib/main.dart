import 'package:flutter/material.dart';
import 'pages/profile_page.dart';
import 'pages/users/signup_page.dart';
import 'pages/users/login_page.dart';
import 'pages/users/user_page.dart';
import 'pages/search_page.dart';
import 'pages/favorites_page.dart';
import 'pages/notifications_page.dart';
import 'pages/test_page.dart';

import 'logiche/auth/auth_service.dart';
import 'logiche/navigation/app_routes.dart';

// 👇 IMPORTANTE: AuthGate decide se mandare l’utente a HomePage o UserPage
import 'pages/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.configure(); // inizializza Amplify/Cognito
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

      // 👇 L'app parte dalla route iniziale
      initialRoute: AppRoutes.home,

      // 👇 Tutte le rotte registrate
      routes: {
        // AuthGate decide se mandare l’utente a HomePage o UserPage
        AppRoutes.home: (context) => const AuthGate(),

        // Pagine principali
        AppRoutes.profile: (context) => const ProfilePage(),
        AppRoutes.signup: (context) => const SignupPage(),
        AppRoutes.login: (context) => const LoginPage(),
        AppRoutes.user: (context) => const UserPage(),
        AppRoutes.search: (context) => const SearchPage(),
        AppRoutes.favorites: (context) => const FavoritesPage(),
        AppRoutes.notifications: (context) => const NotificationsPage(),

        // 👇 La TestPage ora funziona
        AppRoutes.testPage: (context) => const TestPage(),
      },
    );
  }
}