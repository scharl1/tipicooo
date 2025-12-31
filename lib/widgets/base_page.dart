import 'package:flutter/material.dart';
import '../widgets/app_header.dart';
import '../widgets/loader_widget.dart';

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
  final bool scrollable;

  final VoidCallback? onLogout;

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
    this.scrollable = true,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(
        title: headerTitle,
        showBell: showBell,
        showBack: showBack,
        showHome: showHome,
        showLogout: showLogout,
        showProfile: showProfile,
        onLogout: onLogout,
      ),

      body: SafeArea(
        child: Stack(
          children: [
            // ⭐ FIX DEFINITIVO: niente Center, niente ScrollView quando non serve
            scrollable
                ? SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: body,
                  )
                : body,

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