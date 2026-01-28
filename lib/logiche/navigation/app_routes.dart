// lib/logiche/navigation/app_routes.dart

class AppRoutes {
  // ⭐ Rotta iniziale (InitPage)
  static const String init = '/init';

  // Rotte basate sul ruolo Cognito (usate DOPO il login)
  static const String admin = '/admin';
  static const String user = '/user';

  // Rotte generali
  static const String home = '/home';
  static const String profile = '/profile';
  static const String search = '/search';
  static const String favorites = '/favorites';
  static const String notifications = '/notifications';
  static const String signup = '/signup';
  static const String login = '/login';
  static const String testPage = '/test-page';

  // ⭐ Rotta per la pagina "Suggerisci"
  static const String suggest = '/suggest';

  // ⭐ Rotta per la pagina "Invita con WhatsApp"
  static const String suggestUser = '/suggest_user';

  // ⭐ Rotta per la pagina "Suggerisci attività"
  static const String suggestActivity = '/suggest_activity';

  // ⭐ NUOVA ROTTA per la pagina "Registra attività"
  static const String registerActivity = '/register_activity';
}