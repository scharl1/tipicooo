// lib/logiche/navigation/app_routes.dart

class AppRoutes {
  // ⭐ Rotta iniziale (InitPage)
  static const String init = '/init';

  // Rotte basate sul ruolo Cognito (usate DOPO il login)
  static const String user = '/user';

  // Rotte generali
  static const String home = '/home';
  static const String profile = '/profile';
  static const String search = '/search';
  static const String favorites = '/favorites';
  static const String notifications = '/notifications';

  // ⭐ Rotta per la pagina "Suggerisci"
  static const String suggest = '/suggest';

  // ⭐ Rotta per la pagina "Invita con WhatsApp"
  static const String suggestUser = '/suggest_user';

  // ⭐ Rotta per la pagina "Suggerisci attività"
  static const String suggestActivity = '/suggest_activity';

  // ⭐ NUOVA ROTTA per la pagina "Registra attività"
  static const String registerActivity = '/register_activity';

  // ⭐ Rotta per la pagina "Le tue attività"
  static const String userActivities = '/user_activities';

  // ⭐ Rotta per la pagina "Le mie azioni"
  static const String userActions = '/user_actions';

  // ⭐ Rotta per la pagina "I tuoi cashback"
  static const String userCashback = '/user_cashback';

  // Affilia attività
  static const String affiliateActivity = '/affiliate_activity';
  static const String affiliateActivityStatus = '/affiliate_activity_status';

  // Attività dedicate agli autisti
  static const String drivers = '/drivers';

  // Cashback flow
  static const String createPurchase = '/create_purchase';

  // Activity payments (merchant approval UI)
  static const String activityPayments = '/activity_payments';
}
