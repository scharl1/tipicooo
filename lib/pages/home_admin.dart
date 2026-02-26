// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tipicooo_office/layout/m_layout.dart';
import 'package:tipicooo_office/logiche/office_auth.dart';
import 'package:tipicooo_office/pages/admin_requests_page.dart';
import 'package:tipicooo_office/pages/activities/activity_home_page.dart';
import 'package:tipicooo_office/pages/collaborators/collaborators_page.dart';
import 'package:tipicooo_office/pages/office_notifications_page.dart';
import 'package:tipicooo_office/pages/users/users_home_page.dart';

class HomeAdmin extends StatefulWidget {
  final int initialSelectedIndex;

  const HomeAdmin({super.key, this.initialSelectedIndex = 0});

  @override
  State<HomeAdmin> createState() => _HomeAdminState();
}

class _HomeAdminState extends State<HomeAdmin> {
  late int selectedIndex;
  bool _showAdminDot = false;
  bool _showActivityDot = false;
  bool _showUsersDot = false;
  bool _showNotificationsDot = false;
  int _notificationsCount = 0;
  Timer? _refreshTimer;
  bool _accessRevoked = false;
  int _lastRejectedNewCount = 0;
  int _adminCount = 0;
  int _activityCount = 0;
  int _newUsersCount = 0;
  int _deletedUsersCount = 0;
  int _rejectedCount = 0;
  static const String _seenAdminCountKey = "officeSeenAdminCount";
  static const String _seenActivityCountKey = "officeSeenActivityCount";
  static const String _seenUsersCountKey = "officeSeenUsersCount";

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.initialSelectedIndex;
    _refreshDots();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshDots(),
    );
    OfficeAuth.tokenEpoch.addListener(_onTokenChanged);
  }

  @override
  void dispose() {
    OfficeAuth.tokenEpoch.removeListener(_onTokenChanged);
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _onTokenChanged() {
    if (!mounted) return;
    setState(() {
      // Trigger rebuild (gate).
      _accessRevoked = false;
    });
  }

  String? _getToken() {
    final token = OfficeAuth.token;
    if (token == null || token.isEmpty) {
      debugPrint("⚠️ Nessun token admin trovato in localStorage");
    }
    return token;
  }

  void _revokeAccess() {
    OfficeAuth.clearToken();
    if (!mounted) return;
    setState(() {
      _accessRevoked = true;
      _showAdminDot = false;
      _showActivityDot = false;
      _showUsersDot = false;
      _showNotificationsDot = false;
      _notificationsCount = 0;
      _adminCount = 0;
      _activityCount = 0;
      _newUsersCount = 0;
      _deletedUsersCount = 0;
      _rejectedCount = 0;
    });
  }

  Future<void> _refreshDots() async {
    final token = _getToken();
    if (token == null || token.isEmpty) {
      setState(() {
        _showAdminDot = false;
        _showActivityDot = false;
        _showUsersDot = false;
        _showNotificationsDot = false;
        _notificationsCount = 0;
        _adminCount = 0;
        _activityCount = 0;
        _newUsersCount = 0;
        _deletedUsersCount = 0;
        _rejectedCount = 0;
      });
      return;
    }

    final cacheBuster = DateTime.now().millisecondsSinceEpoch.toString();

    final adminUrl = Uri.parse(
      "https://dvyo7vax1g.execute-api.eu-south-1.amazonaws.com/prod/admin-list-requests?_=$cacheBuster",
    );
    final activityUrl = Uri.parse(
      "https://efs0gx9nm4.execute-api.eu-south-1.amazonaws.com/prod/activity-requests?status=pending&_=$cacheBuster",
    );
    final newUsersUrl = Uri.parse(
      "https://dvyo7vax1g.execute-api.eu-south-1.amazonaws.com/prod/admin-new-users-list?limit=500&_=$cacheBuster",
    );
    final deletedUsersUrl = Uri.parse(
      "https://dvyo7vax1g.execute-api.eu-south-1.amazonaws.com/prod/deleted-users-list?limit=500&_=$cacheBuster",
    );
    final rejectedPurchasesUrl = Uri.parse(
      "https://dvyo7vax1g.execute-api.eu-south-1.amazonaws.com/prod/admin-purchase-rejected-count?sinceAt=&_=$cacheBuster",
    );

    try {
      final headers = <String, String>{
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      };

      final results = await Future.wait([
        http.get(adminUrl, headers: headers),
        http.get(activityUrl, headers: headers),
        http.get(newUsersUrl, headers: headers),
        http.get(deletedUsersUrl, headers: headers),
        http.get(rejectedPurchasesUrl, headers: headers),
      ]);

      final adminRes = results[0];
      final activityRes = results[1];
      final newUsersRes = results[2];
      final deletedUsersRes = results[3];
      final rejectedRes = results[4];

      // Token non valido / accesso revocato (utente eliminato o rimosso dal ruolo).
      if (adminRes.statusCode == 401 ||
          adminRes.statusCode == 403 ||
          activityRes.statusCode == 401 ||
          activityRes.statusCode == 403 ||
          newUsersRes.statusCode == 401 ||
          newUsersRes.statusCode == 403 ||
          deletedUsersRes.statusCode == 401 ||
          deletedUsersRes.statusCode == 403 ||
          rejectedRes.statusCode == 401 ||
          rejectedRes.statusCode == 403) {
        _revokeAccess();
        return;
      }

      var adminCount = _adminCount;
      var activityCount = _activityCount;
      var newUsersCount = _newUsersCount;
      var deletedUsersCount = _deletedUsersCount;
      var rejectedCount = _rejectedCount;

      if (adminRes.statusCode == 200) {
        final data = jsonDecode(adminRes.body);
        final items = (data["items"] is List)
            ? data["items"] as List
            : <dynamic>[];
        adminCount = items.length;
      } else {
        debugPrint("admin-list-requests: ${adminRes.statusCode}");
      }

      if (activityRes.statusCode == 200) {
        final data = jsonDecode(activityRes.body);
        final items = (data["items"] is List)
            ? data["items"] as List
            : <dynamic>[];
        activityCount = items.length;
      } else {
        debugPrint("activity-requests pending: ${activityRes.statusCode}");
      }

      if (rejectedRes.statusCode == 200) {
        final data = jsonDecode(rejectedRes.body);
        final newCount = (data["newCount"] ?? 0) as int;
        final latestRejectedAt = (data["latestRejectedAt"] ?? "").toString();
        final totalCount = (data["count"] ?? newCount) as int;
        rejectedCount = totalCount;
        if (latestRejectedAt.isNotEmpty) {
          _setRejectedLatestAt(latestRejectedAt);
        }

        // "Notifica" in Office: snackbar quando compaiono nuovi rifiuti.
        if (mounted && newCount > 0 && _lastRejectedNewCount == 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "Ci sono $newCount pagamenti rifiutati da controllare.",
                ),
              ),
            );
          });
        }
        _lastRejectedNewCount = newCount;
      } else {
        debugPrint("admin-purchase-rejected-count: ${rejectedRes.statusCode}");
      }

      if (newUsersRes.statusCode == 200) {
        final data = jsonDecode(newUsersRes.body);
        final items = (data["items"] is List)
            ? data["items"] as List
            : <dynamic>[];
        final latestSk = (data["nextSk"] ?? "").toString();
        newUsersCount = items.length;
        if (latestSk.isNotEmpty) {
          _setNewUsersLatestSk(latestSk);
        }
      } else {
        debugPrint("admin-new-users-list: ${newUsersRes.statusCode}");
      }

      // Se esiste almeno 1 utente eliminato (ultimo periodo) mostriamo dot.
      if (deletedUsersRes.statusCode == 200) {
        final data = jsonDecode(deletedUsersRes.body);
        final items = (data["items"] is List)
            ? data["items"] as List
            : <dynamic>[];
        deletedUsersCount = items.length;
      } else {
        debugPrint("deleted-users-list: ${deletedUsersRes.statusCode}");
      }

      if (mounted) {
        final activityTotal = activityCount + rejectedCount;
        final usersTotal = newUsersCount + deletedUsersCount;

        final seenAdmin = _readSeenCount(_seenAdminCountKey);
        final seenActivity = _readSeenCount(_seenActivityCountKey);
        final seenUsers = _readSeenCount(_seenUsersCountKey);

        final unreadAdmin = (adminCount - seenAdmin).clamp(0, 1 << 30);
        final unreadActivity = (activityTotal - seenActivity).clamp(0, 1 << 30);
        final unreadUsers = (usersTotal - seenUsers).clamp(0, 1 << 30);
        final totalNotifications = unreadAdmin + unreadActivity + unreadUsers;

        final adminDot = unreadAdmin > 0;
        final activityDot = unreadActivity > 0;
        final usersDot = unreadUsers > 0;
        setState(() {
          _adminCount = adminCount;
          _activityCount = activityCount;
          _newUsersCount = newUsersCount;
          _deletedUsersCount = deletedUsersCount;
          _rejectedCount = rejectedCount;
          _showAdminDot = adminDot;
          _showActivityDot = activityDot;
          _showUsersDot = usersDot;
          _notificationsCount = totalNotifications;
          _showNotificationsDot = totalNotifications > 0;
        });
      }
    } catch (e) {
      debugPrint("Errore refresh dots: $e");
    }
  }

  static const String _newUsersLatestSkKey = "officeNewUsersLatestSk";
  static const String _rejectedLatestAtKey = "officeRejectedLatestAt";

  int _readSeenCount(String key) {
    final raw = (html.window.localStorage[key] ?? "").trim();
    if (raw.isEmpty) return 0;
    return int.tryParse(raw) ?? 0;
  }

  void _markSectionRead(int index) {
    if (index == 0) {
      html.window.localStorage[_seenAdminCountKey] = _adminCount.toString();
      return;
    }
    if (index == 1) {
      final activityTotal = _activityCount + _rejectedCount;
      html.window.localStorage[_seenActivityCountKey] = activityTotal.toString();
      return;
    }
    if (index == 2) {
      final usersTotal = _newUsersCount + _deletedUsersCount;
      html.window.localStorage[_seenUsersCountKey] = usersTotal.toString();
      return;
    }
    if (index == 3) {
      html.window.localStorage[_seenAdminCountKey] = _adminCount.toString();
      html.window.localStorage[_seenActivityCountKey] =
          (_activityCount + _rejectedCount).toString();
      html.window.localStorage[_seenUsersCountKey] =
          (_newUsersCount + _deletedUsersCount).toString();
    }
  }

  void _setNewUsersLatestSk(String latestSk) {
    final trimmed = latestSk.trim();
    if (trimmed.isEmpty) return;
    html.window.localStorage[_newUsersLatestSkKey] = trimmed;
  }

  void _setRejectedLatestAt(String iso) {
    final trimmed = iso.trim();
    if (trimmed.isEmpty) return;
    html.window.localStorage[_rejectedLatestAtKey] = trimmed;
  }

  // ⭐ Qui colleghiamo gli index alle pagine
  Widget _getPage() {
    switch (selectedIndex) {
      case -1:
        return const _OfficeWelcomePage();
      case 0:
        return const AdminRequestsPage(); // ← SEZIONE ADMIN
      case 1:
        return const ActivityHomePage();
      case 2:
        return const UsersHomePage();
      case 3:
        return const OfficeNotificationsPage();
      case 4:
        return const CollaboratorsPage();
      default:
        return const _OfficeWelcomePage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final token = _getToken();
    if (_accessRevoked || token == null || token.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Accesso non disponibile",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Il tuo token ufficio non è valido o l'utente è stato eliminato/rimosso.\n\nApri Tipic.ooo dall'app mobile e premi \"Entra in ufficio\" per generare un nuovo accesso.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () => html.window.location.reload(),
                      child: const Text("Ricarica"),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        OfficeAuth.clearToken();
                        html.window.location.reload();
                      },
                      child: const Text("Pulisci token"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return MLayout(
      selectedIndex: selectedIndex,
      onMenuTap: (index) {
        _markSectionRead(index);
        setState(() {
          selectedIndex = index;
          if (index == 0) _showAdminDot = false;
          if (index == 1) _showActivityDot = false;
          if (index == 2) _showUsersDot = false;
          if (index == 3) {
            _showAdminDot = false;
            _showActivityDot = false;
            _showUsersDot = false;
            _showNotificationsDot = false;
            _notificationsCount = 0;
          }
        });
        // Aggiorna subito badge/contatori quando si cambia sezione.
        _refreshDots();
      },
      showAdminDot: _showAdminDot,
      showActivityDot: _showActivityDot,
      showUsersDot: _showUsersDot,
      showNotificationsDot: _showNotificationsDot,
      notificationsCount: _notificationsCount,
      child: _getPage(),
    );
  }
}

class _OfficeWelcomePage extends StatelessWidget {
  const _OfficeWelcomePage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 820),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Text(
            "Benvenuto nella sezione Tipic.ooo Ufficio",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}

