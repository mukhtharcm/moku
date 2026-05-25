import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:window_manager/window_manager.dart';

import 'l10n/l10n.dart';

// Screens: mobile + tablet use full-screen; desktop uses split panes below
import 'features/library/screens/library_screen.dart';
import 'features/search/screens/search_screen.dart' as discover;
import 'features/collections/screens/collections_screen.dart';
import 'features/stats/stats_page.dart';
import 'features/settings/screens/settings_screen.dart';

// Desktop split-pane widgets
import 'features/library/widgets/library_sidebar.dart';
import 'features/library/widgets/library_detail_pane.dart';
import 'features/collections/widgets/shelves_sidebar.dart';
import 'features/collections/widgets/shelves_detail_pane.dart';
import 'features/search/widgets/discover_sidebar.dart';
import 'features/settings/widgets/settings_sidebar.dart';
import 'features/settings/widgets/settings_detail_pane.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  // ── Title-bar height (macOS) ─────────────────────────────────────────────
  double _titleBarHeight =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS ? 28.0 : 0.0;

  // ── Settings section selection (desktop only) ────────────────────────────
  SettingsSection _settingsSection = SettingsSection.appearance;

  // ── Full-screen screens for mobile / tablet ──────────────────────────────
  final _screens = const [
    LibraryScreen(),
    discover.SearchScreen(),
    CollectionsScreen(),
    StatsPage(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _syncTitleBarHeight();
  }

  Future<void> _syncTitleBarHeight() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.macOS &&
        defaultTargetPlatform != TargetPlatform.linux &&
        defaultTargetPlatform != TargetPlatform.windows) {
      return;
    }
    try {
      final h = await windowManager.getTitleBarHeight();
      if (mounted && h.toDouble() != _titleBarHeight) {
        setState(() => _titleBarHeight = h.toDouble());
      }
    } catch (_) {}
  }

  // ── Destination metadata ─────────────────────────────────────────────────
  static const _destinations = [
    _NavDestination(
      icon: Icons.auto_stories_outlined,
      selectedIcon: Icons.auto_stories_rounded,
      labelKey: 'library',
    ),
    _NavDestination(
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore_rounded,
      labelKey: 'discover',
    ),
    _NavDestination(
      icon: Icons.collections_bookmark_outlined,
      selectedIcon: Icons.collections_bookmark_rounded,
      labelKey: 'shelves',
    ),
    _NavDestination(
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart_rounded,
      labelKey: 'stats',
    ),
    _NavDestination(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
      labelKey: 'settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isTablet = width >= 600;
    final isDesktop = width >= 1000;

    final bool nativeDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.windows);

    if (isDesktop) return _buildDesktopLayout(context, nativeDesktop);
    if (isTablet) return _buildTabletLayout(context, nativeDesktop);
    return _buildMobileLayout(context);
  }

  // ── Desktop: icon rail + context panel + main pane ──────────────────────

  Widget _buildDesktopLayout(
      BuildContext context, bool nativeDesktop) {
    final colorScheme = Theme.of(context).colorScheme;
    // Stats (index 3) has no sidebar — the main pane fills the full width.
    final hasSidebar = _currentIndex != 3;

    return Scaffold(
      body: Row(
        children: [
          // 1. Narrow icon rail
          _IconRail(
            selectedIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            titleBarHeight: _titleBarHeight,
            nativeDesktop: nativeDesktop,
            destinations: _destinations,
            labels: _destinationLabels(context),
          ),

          VerticalDivider(
              thickness: 1,
              width: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.3)),

          // 2. Context panel (260 px)
          if (hasSidebar) ...[
            SizedBox(
              width: 260,
              child: _buildContextPanel(context),
            ),
            VerticalDivider(
                thickness: 1,
                width: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
          ],

          // 3. Main pane
          Expanded(child: _buildMainPane(context)),
        ],
      ),
    );
  }

  Widget _buildContextPanel(BuildContext context) {
    return switch (_currentIndex) {
      0 => const LibrarySidebar(),
      1 => const DiscoverSidebar(),
      2 => const ShelvesSidebar(),
      4 => SettingsSidebar(
          selected: _settingsSection,
          onSelect: (s) => setState(() => _settingsSection = s),
        ),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildMainPane(BuildContext context) {
    return switch (_currentIndex) {
      0 => const LibraryDetailPane(),
      1 => const _DiscoverMainPane(),
      2 => const ShelvesDetailPane(),
      3 => const StatsPage(),
      4 => SettingsDetailPane(section: _settingsSection),
      _ => const SizedBox.shrink(),
    };
  }

  // ── Tablet: single NavigationRail + full screen content ─────────────────

  Widget _buildTabletLayout(BuildContext context, bool nativeDesktop) {
    final colorScheme = Theme.of(context).colorScheme;
    final topInset = _titleBarHeight;

    Widget leading;
    leading = Padding(
      padding: EdgeInsets.only(top: topInset, bottom: 4),
      child: Icon(Icons.auto_stories_rounded,
          color: colorScheme.primary, size: 22),
    );
    if (nativeDesktop) leading = DragToMoveArea(child: leading);

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: false,
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) =>
                setState(() => _currentIndex = i),
            minWidth: 72,
            leading: leading,
            destinations: _destinations.map((d) {
              final labels = _destinationLabels(context);
              return NavigationRailDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: Text(labels[_destinations.indexOf(d)]),
              );
            }).toList(),
          ),
          VerticalDivider(
              thickness: 1,
              width: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
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

  Widget _buildMobileLayout(BuildContext context) {
    final labels = _destinationLabels(context);

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
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: List.generate(
          _destinations.length,
          (i) => NavigationDestination(
            icon: Icon(_destinations[i].icon),
            selectedIcon: Icon(_destinations[i].selectedIcon),
            label: labels[i],
          ),
        ),
      ),
    );
  }

  List<String> _destinationLabels(BuildContext context) {
    final l10n = context.l10n;
    return [
      l10n.navLibrary,
      l10n.navDiscover,
      l10n.navShelves,
      l10n.navStats,
      l10n.navSettings,
    ];
  }
}

// ── Discover main pane ───────────────────────────────────────────────────────
// The full browse / search experience lives here, driven by SearchCubit
// which was already open. The sidebar just picks which catalog is active.

class _DiscoverMainPane extends StatelessWidget {
  const _DiscoverMainPane();

  @override
  Widget build(BuildContext context) {
    // Re-use SearchScreen's body content but without the outer scaffold's
    // catalog-list view (the sidebar drives catalog selection instead).
    // We still need a Scaffold for AppBar + proper layout.
    return const discover.SearchScreen();
  }
}

// ── Narrow icon rail (desktop only) ─────────────────────────────────────────

class _NavDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String labelKey;
  const _NavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.labelKey,
  });
}

class _IconRail extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final double titleBarHeight;
  final bool nativeDesktop;
  final List<_NavDestination> destinations;
  final List<String> labels;

  const _IconRail({
    required this.selectedIndex,
    required this.onTap,
    required this.titleBarHeight,
    required this.nativeDesktop,
    required this.destinations,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final railBg = theme.navigationRailTheme.backgroundColor ??
        colorScheme.surfaceContainerLow;

    // Separate Settings (index 4) to the bottom with a spacer
    final mainDests = destinations.sublist(0, 4);
    final bottomDest = destinations[4];

    Widget logo = Padding(
      padding: EdgeInsets.only(
        top: titleBarHeight > 0 ? titleBarHeight + 4 : 16,
        bottom: 8,
      ),
      child: Icon(Icons.auto_stories_rounded,
          color: colorScheme.primary, size: 22),
    );
    if (nativeDesktop) logo = DragToMoveArea(child: logo);

    return Container(
      width: 64,
      color: railBg,
      child: Column(
        children: [
          // Logo / drag handle
          logo,

          const Divider(height: 1),
          const SizedBox(height: 4),

          // Main nav items
          ...mainDests.asMap().entries.map((e) {
            final index = e.key;
            final dest = e.value;
            return _IconRailItem(
              icon: dest.icon,
              selectedIcon: dest.selectedIcon,
              label: labels[index],
              isSelected: selectedIndex == index,
              onTap: () => onTap(index),
            );
          }),

          const Spacer(),
          const Divider(height: 1),
          const SizedBox(height: 4),

          // Settings at the bottom
          _IconRailItem(
            icon: bottomDest.icon,
            selectedIcon: bottomDest.selectedIcon,
            label: labels[4],
            isSelected: selectedIndex == 4,
            onTap: () => onTap(4),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _IconRailItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _IconRailItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: label,
      preferBelow: false,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 48,
            height: 40,
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primaryContainer.withValues(alpha: 0.7)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isSelected ? selectedIcon : icon,
              size: 22,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}
