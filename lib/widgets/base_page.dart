import 'package:flutter/material.dart';
import 'package:tipicooo/widgets/app_header.dart';

class BasePage extends StatelessWidget {
  final String headerTitle;
  final bool showBack;
  final bool showHome;
  final bool showBell;
  final bool showProfile;
  final bool showLogout;
  final bool isLoading;
  final bool scrollable; // ⭐ AGGIUNTO
  final Widget body;
  final Widget? bottomNavigationBar;
  final VoidCallback? onLogout;

  const BasePage({
    super.key,
    required this.headerTitle,
    this.showBack = false,
    this.showHome = false,
    this.showBell = false,
    this.showProfile = false,
    this.showLogout = false,
    this.isLoading = false,
    this.scrollable = true, // ⭐ DEFAULT
    required this.body,
    this.bottomNavigationBar,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(
        title: headerTitle,
        showBack: showBack,
        showHome: showHome,
        showBell: showBell,
        showProfile: showProfile,
        showLogout: showLogout,
        onLogout: onLogout,
      ),
      body: Stack(
        children: [
          scrollable
              ? SingleChildScrollView(child: body)
              : body,

          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}