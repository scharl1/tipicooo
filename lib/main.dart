import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
// kIsWeb

// Hive
import 'hive/hive_boxes.dart';

// Pagine
import 'pages/profile_page.dart';
import 'pages/users/user_page.dart';
import 'pages/users/user_cashback_page.dart';
import 'pages/users/create_purchase_page.dart';
import 'pages/users/activity_payments_page.dart';
import 'pages/users/user_activities_page.dart';
import 'pages/users/user_actions_page.dart';
import 'pages/users/affiliate_activity_page.dart';
import 'pages/users/affiliate_activity_status_page.dart';
import 'pages/drivers_page.dart';
import 'pages/search_page.dart';
import 'pages/favorites_page.dart';
import 'pages/notifications_page.dart';
import 'pages/home_page.dart';
import 'pages/init_page.dart';

// Pagine suggerimenti
import 'pages/users/suggest/suggest_page.dart';
import 'pages/users/suggest/suggest_user.dart';
import 'pages/users/suggest/suggest_activity_page.dart';

// Pagina registrazione attività
import 'activity/register_activity_v2_page.dart';

// Logiche
import 'logiche/auth/auth_service.dart';
import 'logiche/navigation/app_routes.dart';
import 'logiche/auth/auth_state.dart';
import 'logiche/requests/user_request_service.dart';
import 'logiche/requests/activity_request_service.dart';
import 'logiche/requests/purchase_service.dart';

// NotificationController
import 'logiche/notifications/notification_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inizializza Hive
  await Hive.initFlutter();

  // Box notifiche
  await Hive.openBox('notifications');

  // Box registrazione attività
  await Hive.openBox(HiveBoxes.registerActivity);

  // Box profilo (avatar ecc.)
  await Hive.openBox('profile');

  // Carica notifiche salvate
  await NotificationController.instance.init();

  // Inizializza Amplify/Cognito
  await AuthService.configure();

  // Inizializza lo stato login leggendo Cognito
  await AuthState.initialize();

  // Se la sessione Cognito e' gia' valida (es. app riaperta), avvia i polling.
  if (AuthState.isUserLoggedIn) {
    await UserRequestService.startAdminPolling();
    await ActivityRequestService.startAdminPolling();
    await PurchaseService.startActivityPolling();
  }

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

      // L'app parte da InitPage
      home: const InitPage(),

      routes: {
        // Rotte principali
        AppRoutes.home: (context) => HomePage(),
        AppRoutes.user: (context) => UserPage(),

        // Pagina "Suggerisci"
        AppRoutes.suggest: (context) => const SuggestPage(),

        // Invita con WhatsApp
        AppRoutes.suggestUser: (context) {
          final userId = AuthState.user?.userId ?? '';
          return SuggestUserPage(userId: userId);
        },

        // Suggerisci attività
        AppRoutes.suggestActivity: (context) => const SuggestActivityPage(),

        // Registra attività
        AppRoutes.registerActivity: (context) => const RegisterActivityV2Page(),

        // Le tue attività
        AppRoutes.userActivities: (context) => const UserActivitiesPage(),

        // Le mie azioni
        AppRoutes.userActions: (context) => const UserActionsPage(),

        // I tuoi cashback
        AppRoutes.userCashback: (context) => const UserCashbackPage(),

        // Affilia attività
        AppRoutes.affiliateActivity: (context) => const AffiliateActivityPage(),
        AppRoutes.affiliateActivityStatus: (context) =>
            const AffiliateActivityStatusPage(),

        // Sei un autista
        AppRoutes.drivers: (context) => const DriversPage(),

        // Registra pagamento (cashback)
        AppRoutes.createPurchase: (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map?;
          final activityRequestId = (args?["activityRequestId"] ?? "").toString();
          final activityTitle = (args?["activityTitle"] ?? "Attività").toString();
          return CreatePurchasePage(
            activityRequestId: activityRequestId,
            activityTitle: activityTitle,
          );
        },

        // Accetta pagamenti (per attività registrate)
        AppRoutes.activityPayments: (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map?;
          final activityRequestId = (args?["activityRequestId"] ?? "").toString();
          return ActivityPaymentsPage(
            activityRequestId: activityRequestId.isEmpty ? null : activityRequestId,
          );
        },

        // Pagine generali
        AppRoutes.profile: (context) => ProfilePage(),
        AppRoutes.search: (context) => SearchPage(),
        AppRoutes.favorites: (context) => FavoritesPage(),
        AppRoutes.notifications: (context) => NotificationsPage(),

      },
    );
  }
}
