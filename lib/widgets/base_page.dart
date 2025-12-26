import 'package:flutter/material.dart';
import '../widgets/app_header.dart';
import '../widgets/loader_widget.dart';
import '../logiche/auth/auth_utils.dart';

class BasePage extends StatelessWidget {
  final String headerTitle;
  final bool showBell;
  final bool showBack;
  final bool showHome;
  final bool showLogout;
  final bool showProfile;
  final Widget body;
  final Widget? bottomNavigationBar;
  final bool isLoading;

  const BasePage({
    super.key,
    required this.headerTitle,
    this.showBell = false,
    this.showBack = false,
    this.showHome = false,
    this.showLogout = false,
    this.showProfile = false,
    required this.body,
    this.bottomNavigationBar,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: FutureBuilder<bool>(
          future: AuthUtils.isLoggedIn(),
          builder: (context, snapshot) {
            final loggedIn = snapshot.data ?? false;

            return AppHeader(
              title: headerTitle,
              showBell: showBell,
              showBack: showBack,
              showHome: showHome,
              showLogout: showLogout,
              showProfile: showProfile || loggedIn,
            );
          },
        ),
      ),

      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  body,
                  const SizedBox(height: 40),
                ],
              ),
            ),

            if (isLoading)
              const Positioned.fill(
                child: LoaderWidget(),
              ),
          ],
        ),
      ),

      bottomNavigationBar: bottomNavigationBar,
    );
  }
}