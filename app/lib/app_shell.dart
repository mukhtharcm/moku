import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:window_manager/window_manager.dart';

import 'l10n/l10n.dart';
import 'features/library/screens/library_screen.dart';
import 'features/search/screens/search_screen.dart';
import 'features/collections/screens/collections_screen.dart';
import 'features/stats/stats_page.dart';
import 'features/settings/screens/settings_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  final _screens = const [
    LibraryScreen(),
    SearchScreen(),
    CollectionsScreen(),
    StatsPage(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final width = MediaQuery.sizeOf(context).width;
    final isTablet = width >= 600;
    final isDesktop = width >= 1000;
    final colorScheme = Theme.of(context).colorScheme;

    // On macOS with TitleBarStyle.hidden the Flutter engine correctly reports
    // the title-bar height (~28pt) via viewPadding.top (fullSizeContentView
    // makes the window report that inset as a safe-area). We use it to push
    // the rail's leading content below the traffic-light buttons.
    final topInset = MediaQuery.viewPaddingOf(context).top;

    // Only wrap interactive areas in DragToMoveArea on real desktop OSes.
    final bool nativeDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.windows);

    Widget railLeading;
    if (isDesktop) {
      railLeading = Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          topInset > 0 ? topInset + 8 : 20,
          20,
          4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories_rounded,
              color: colorScheme.primary,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              l10n.appTitle,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    } else {
      railLeading = Padding(
        padding: EdgeInsets.only(top: topInset, bottom: 4),
        child: Icon(
          Icons.auto_stories_rounded,
          color: colorScheme.primary,
          size: 22,
        ),
      );
    }

    if (nativeDesktop) {
      railLeading = DragToMoveArea(child: railLeading);
    }

    // ── Tablet / Desktop: side NavigationRail ───────────────────────────────
    if (isTablet) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: isDesktop,
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) =>
                  setState(() => _currentIndex = index),
              minWidth: 72,
              minExtendedWidth: 220,
              leading: railLeading,
              destinations: [
                NavigationRailDestination(
                  icon: const Icon(Icons.auto_stories_outlined),
                  selectedIcon: const Icon(Icons.auto_stories_rounded),
                  label: Text(l10n.navLibrary),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.explore_outlined),
                  selectedIcon: const Icon(Icons.explore_rounded),
                  label: Text(l10n.navDiscover),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.collections_bookmark_outlined),
                  selectedIcon: const Icon(Icons.collections_bookmark_rounded),
                  label: Text(l10n.navShelves),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.bar_chart_outlined),
                  selectedIcon: const Icon(Icons.bar_chart_rounded),
                  label: Text(l10n.navStats),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings_rounded),
                  label: Text(l10n.navSettings),
                ),
              ],
            ),
            VerticalDivider(
              thickness: 1,
              width: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
            ),
          ],
        ),
      );
    }

    // ── Mobile: bottom NavigationBar ────────────────────────────────────────
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: IndexedStack(
          key: ValueKey(_currentIndex),
          index: _currentIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) =>
            setState(() => _currentIndex = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.auto_stories_outlined),
            selectedIcon: const Icon(Icons.auto_stories_rounded),
            label: l10n.navLibrary,
          ),
          NavigationDestination(
            icon: const Icon(Icons.explore_outlined),
            selectedIcon: const Icon(Icons.explore_rounded),
            label: l10n.navDiscover,
          ),
          NavigationDestination(
            icon: const Icon(Icons.collections_bookmark_outlined),
            selectedIcon: const Icon(Icons.collections_bookmark_rounded),
            label: l10n.navShelves,
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart_rounded),
            label: l10n.navStats,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings_rounded),
            label: l10n.navSettings,
          ),
        ],
      ),
    );
  }
}
