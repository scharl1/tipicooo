import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MLayout extends StatelessWidget {
  final Widget child;
  final int selectedIndex;
  final Function(int) onMenuTap;
  final bool showAdminDot;
  final bool showActivityDot;
  final bool showUsersDot;
  final bool showNotificationsDot;
  final int notificationsCount;

  const MLayout({
    super.key,
    required this.child,
    required this.selectedIndex,
    required this.onMenuTap,
    this.showAdminDot = false,
    this.showActivityDot = false,
    this.showUsersDot = false,
    this.showNotificationsDot = false,
    this.notificationsCount = 0,
  });

  Future<void> _goBackToApp() async {
    final appUri = Uri.parse('tipicooo://home');
    final webUri = Uri.parse('https://ilpassaparoladicarlo.com');
    final opened = await launchUrl(appUri, mode: LaunchMode.externalApplication);
    if (opened) return;
    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final showTopMenuDot = notificationsCount > 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;

        if (isMobile) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.blue.shade700,
              automaticallyImplyLeading: false,
              leading: Builder(
                builder: (context) {
                  return IconButton(
                    onPressed: () => Scaffold.of(context).openDrawer(),
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.menu, color: Colors.white),
                        if (showTopMenuDot)
                          Positioned(
                            right: -2,
                            top: -4,
                            child: _badge(notificationsCount),
                          ),
                      ],
                    ),
                  );
                },
              ),
              title: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Tipic.ooo Ufficio',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            drawer: _buildDrawer(context),
            body: Container(
              color: Colors.white,
              child: child,
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              _buildSidebar(showTopMenuDot),
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: child,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebar(bool showTopMenuDot) {
    return Container(
      width: 240,
      color: Colors.blue.shade700,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Tipic.ooo Ufficio',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (showTopMenuDot) _badge(notificationsCount),
              ],
            ),
          ),
          const SizedBox(height: 40),
          if (showTopMenuDot)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 2),
              child: Text(
                'Nuove notifiche',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          _menuButton('Torna all\'app', _goBackToApp),
          const SizedBox(height: 20),
          _menuItem('Sezione Admin', 0, showDot: showAdminDot),
          const SizedBox(height: 10),
          _menuItem('Sezione Attività', 1, showDot: showActivityDot),
          const SizedBox(height: 10),
          _menuItem('Sezione Utenti', 2, showDot: showUsersDot),
          const SizedBox(height: 10),
          _menuItem(
            'Notifiche',
            3,
            showDot: showNotificationsDot,
            showCount: true,
          ),
          const SizedBox(height: 10),
          _menuItem('Collaboratori', 4),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Container(
        color: Colors.blue.shade700,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Text(
                  'Tipic.ooo Ufficio',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(color: Colors.white24),
              _drawerButton(context, 'Torna all\'app', _goBackToApp),
              const Divider(color: Colors.white24),
              _drawerItem(context, 'Sezione Admin', 0, showDot: showAdminDot),
              _drawerItem(context, 'Sezione Attività', 1, showDot: showActivityDot),
              _drawerItem(context, 'Sezione Utenti', 2, showDot: showUsersDot),
              _drawerItem(
                context,
                'Notifiche',
                3,
                showDot: showNotificationsDot,
                showCount: true,
              ),
              _drawerItem(context, 'Collaboratori', 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuButton(String label, Future<void> Function() onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            onTap();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.blue.shade800,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _drawerButton(
    BuildContext context,
    String label,
    Future<void> Function() onTap,
  ) {
    return ListTile(
      title: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: () async {
        Navigator.of(context).pop();
        await onTap();
      },
    );
  }

  Widget _menuItem(
    String label,
    int index, {
    bool showDot = false,
    bool showCount = false,
  }) {
    final selected = selectedIndex == index;

    return InkWell(
      onTap: () => onMenuTap(index),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        color: selected ? Colors.blue.shade900 : Colors.transparent,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (showDot) (showCount ? _badge(notificationsCount) : _redDot()),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(
    BuildContext context,
    String label,
    int index, {
    bool showDot = false,
    bool showCount = false,
  }) {
    final selected = selectedIndex == index;

    return ListTile(
      title: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (showDot) (showCount ? _badge(notificationsCount) : _redDot()),
        ],
      ),
      selected: selected,
      selectedTileColor: Colors.blue.shade900,
      onTap: () {
        Navigator.of(context).pop();
        onMenuTap(index);
      },
    );
  }

  Widget _redDot() {
    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _badge(int count) {
    final label = count > 99 ? '99+' : count.toString();
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
    );
  }
}

