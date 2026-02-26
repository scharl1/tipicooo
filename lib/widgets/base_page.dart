import 'package:flutter/material.dart';
import 'package:tipicooo/widgets/app_header.dart';
import 'package:tipicooo/widgets/layout/app_body_layout.dart';

class BasePage extends StatefulWidget {
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
  final VoidCallback? onBackPressed;
  final Future<void> Function()? onRefresh;

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
    this.onBackPressed,
    this.onRefresh,
  });

  @override
  State<BasePage> createState() => _BasePageState();
}

class _BasePageState extends State<BasePage> {
  final UniformButtonWidthController _widthController =
      UniformButtonWidthController();
  final ScrollController _scrollController = ScrollController(
    keepScrollOffset: false,
  );

  @override
  void dispose() {
    _scrollController.dispose();
    _widthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget pageBody = widget.scrollable
        ? SingleChildScrollView(
            controller: _scrollController,
            primary: false,
            physics: const AlwaysScrollableScrollPhysics(),
            child: widget.body,
          )
        : widget.body;

    if (widget.onRefresh != null) {
      pageBody = RefreshIndicator(
        onRefresh: widget.onRefresh!,
        child: pageBody,
      );
    }

    return Scaffold(
      appBar: AppHeader(
        title: widget.headerTitle,
        showBack: widget.showBack,
        showHome: widget.showHome,
        showBell: widget.showBell,
        showProfile: widget.showProfile,
        showLogout: widget.showLogout,
        onLogout: widget.onLogout,
        onBackPressed: widget.onBackPressed,
      ),
      body: UniformButtonWidthScope(
        controller: _widthController,
        child: Stack(
          children: [
            pageBody,

            if (widget.isLoading)
              Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: widget.bottomNavigationBar,
    );
  }
}
