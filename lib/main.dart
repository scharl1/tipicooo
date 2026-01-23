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
import 'pages/home_page.dart';
import 'pages/init_page.dart';

// ⭐ Pagine suggerimenti
import 'pages/users/suggest/suggest_page.dart';
import 'pages/users/suggest/suggest_user.dart';

// Logiche
import 'logiche/auth/auth_service.dart';
import 'logiche/navigation/app_routes.dart';
import 'logiche/auth/auth_state.dart';

// NotificationController
import 'logiche/notifications/notification_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inizializza Hive
  await Hive.initFlutter();
  await Hive.openBox('notifications');

  // Carica notifiche salvate
  await NotificationController.instance.init();

  // Inizializza Amplify/Cognito
  await AuthService.configure();

  // ⭐ Inizializza lo stato login leggendo Cognito
  await AuthState.initialize();

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

      // ⭐ L'app parte da InitPage
      home: const InitPage(),

      routes: {
        // Rotte principali
        AppRoutes.home: (context) => HomePage(),
        AppRoutes.user: (context) => UserPage(),

        // ⭐ Rotta per la pagina "Suggerisci"
        AppRoutes.suggest: (context) => const SuggestPage(),

        // ⭐ NUOVA ROTTA: Invita con WhatsApp
        AppRoutes.suggestUser: (context) {
  final userId = AuthState.user?.userId ?? '';
  return SuggestUserPage(userId: userId);
},

        // Pagine generali
        AppRoutes.profile: (context) => ProfilePage(),
        AppRoutes.signup: (context) => SignupPage(),
        AppRoutes.login: (context) => LoginPage(),
        AppRoutes.search: (context) => SearchPage(),
        AppRoutes.favorites: (context) => FavoritesPage(),
        AppRoutes.notifications: (context) => NotificationsPage(),

        // TestPage
        AppRoutes.testPage: (context) => TestPage(),
      },
    );
  }
}