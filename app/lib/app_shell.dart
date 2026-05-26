import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:window_manager/window_manager.dart';

import 'core/sync/sync_config.dart';
import 'core/ui/ui.dart';
import 'l10n/l10n.dart';

// Screens: mobile + tablet use full-screen; desktop uses split panes below
import 'core/models/book.dart';
import 'features/library/cubit/library_cubit.dart';
import 'features/library/screens/library_screen.dart';
import 'features/reader/screens/reader_screen.dart';
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
import 'features/search/cubit/search_cubit.dart';
import 'features/search/cubit/search_state.dart';
import 'features/settings/widgets/settings_sidebar.dart';
import 'features/settings/widgets/settings_detail_pane.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WindowListener {
  int _currentIndex = 0;
  Book? _readingBook; // non-null = desktop inline reader is active
  late final FocusNode _shellFocus;

  // ── Title-bar height (macOS) ─────────────────────────────────────────────
  // Seeded to the platform default; updated once the window is ready.
  // _windowedTitleBarHeight caches the last known non-zero value so we can
  // restore it instantly when leaving fullscreen (getTitleBarHeight() is
  // unreliable mid-transition and often returns 0).
  double _titleBarHeight =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS ? 28.0 : 0.0;
  double _windowedTitleBarHeight =
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
    _shellFocus = FocusNode();
    _syncTitleBarHeight();
    // Listen for fullscreen transitions so we can zero/restore titleBarHeight.
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.macOS ||
         defaultTargetPlatform == TargetPlatform.linux ||
         defaultTargetPlatform == TargetPlatform.windows)) {
      windowManager.addListener(this);
    }
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
      if (!mounted) return;
      if (h > 0) {
        // Cache the real windowed height so we can restore it after fullscreen.
        _windowedTitleBarHeight = h.toDouble();
        if (h.toDouble() != _titleBarHeight) {
          setState(() => _titleBarHeight = h.toDouble());
        }
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
  void dispose() {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.macOS ||
         defaultTargetPlatform == TargetPlatform.linux ||
         defaultTargetPlatform == TargetPlatform.windows)) {
      windowManager.removeListener(this);
    }
    _shellFocus.dispose();
    super.dispose();
  }

  @override
  void onWindowEnterFullScreen() {
    // In macOS fullscreen the title bar collapses — clear the reserved space.
    if (mounted) setState(() => _titleBarHeight = 0);
  }

  @override
  void onWindowLeaveFullScreen() {
    // Restore immediately from cache — getTitleBarHeight() is unreliable
    // mid-transition and often returns 0 while the animation is still running.
    if (mounted) setState(() => _titleBarHeight = _windowedTitleBarHeight);
    // Then confirm with the real value once the transition has settled.
    Future.delayed(MokuMotion.normal, _syncTitleBarHeight);
  }

  void _openBookInline(Book book) => setState(() => _readingBook = book);
  void _closeReader()            => setState(() => _readingBook = null);

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;
    final meta = HardwareKeyboard.instance.isMetaPressed;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final cmd = meta || ctrl;

    // ⌘O / Ctrl+O  — import book
    if (cmd && key == LogicalKeyboardKey.keyO) {
      context.read<LibraryCubit>().importBook();
      return;
    }

    // ⌘F / Ctrl+F  — jump to Discover (search)
    if (cmd && key == LogicalKeyboardKey.keyF) {
      setState(() => _currentIndex = 1);
      return;
    }

    // ←1–5  — jump directly to section (no modifier needed)
    if (!cmd) {
      final digit = {
        LogicalKeyboardKey.digit1: 0,
        LogicalKeyboardKey.digit2: 1,
        LogicalKeyboardKey.digit3: 2,
        LogicalKeyboardKey.digit4: 3,
        LogicalKeyboardKey.digit5: 4,
      }[key];
      if (digit != null) setState(() => _currentIndex = digit);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isTablet = width >= 600;
    final isDesktop = width >= 1000;

    final bool nativeDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.windows);

    final layout = isDesktop
        ? _buildDesktopLayout(context, nativeDesktop)
        : isTablet
            ? _buildTabletLayout(context, nativeDesktop)
            : _buildMobileLayout(context);

    // On native desktop, wrap in KeyboardListener for shell shortcuts.
    if (nativeDesktop) {
      return KeyboardListener(
        focusNode: _shellFocus,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: layout,
      );
    }
    return layout;
  }

  // ── Desktop: icon rail + context panel + main pane ──────────────────────

  Widget _buildDesktopLayout(BuildContext context, bool nativeDesktop) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasSidebar = _currentIndex != 3;
    final railBg = Theme.of(context).navigationRailTheme.backgroundColor ??
        colorScheme.surfaceContainerLow;
    final dividerColor = colorScheme.outlineVariant;

    return Scaffold(
      body: Stack(
        children: [
          // ── Rail background fills the title-bar zone seamlessly ────────
          if (_titleBarHeight > 0)
            Positioned(
              top: 0, left: 0,
              width: 56,
              height: _titleBarHeight,
              child: ColoredBox(color: railBg),
            ),

          // ── All content starts below the traffic lights ────────────────
          Padding(
            padding: EdgeInsets.only(top: _titleBarHeight),
            child: Row(
              children: [
                _IconRail(
                  selectedIndex: _currentIndex,
                  onTap: (i) => setState(() => _currentIndex = i),
                  destinations: _destinations,
                  labels: _destinationLabels(context),
                ),
                VerticalDivider(
                    thickness: 1, width: 1, color: dividerColor),
                if (hasSidebar) ...[
                  SizedBox(
                    width: 240,
                    child: _buildContextPanel(context),
                  ),
                  VerticalDivider(
                      thickness: 1, width: 1, color: dividerColor),
                ],
                Expanded(child: _buildMainPane(context)),
              ],
            ),
          ),

          // ── Full-width drag handle in the title-bar zone ───────────────
          if (nativeDesktop && _titleBarHeight > 0)
            Positioned(
              top: 0, left: 0, right: 0,
              height: _titleBarHeight,
              child: DragToMoveArea(child: const SizedBox.expand()),
            ),
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
    // Inline reader: takes over the main pane on desktop.
    if (_readingBook != null) {
      return ReaderScreen(
        key: ValueKey(_readingBook!.id),
        book: _readingBook!,
        onClose: _closeReader,
      );
    }
    return switch (_currentIndex) {
      0 => LibraryDetailPane(onOpenBook: _openBookInline),
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
    final railBg = Theme.of(context).navigationRailTheme.backgroundColor ??
        colorScheme.surfaceContainerLow;
    final dividerColor = colorScheme.outlineVariant;

    return Scaffold(
      body: Stack(
        children: [
          // ── Rail background fills the title-bar zone ───────────────────
          if (_titleBarHeight > 0)
            Positioned(
              top: 0, left: 0,
              width: 72,
              height: _titleBarHeight,
              child: ColoredBox(color: railBg),
            ),

          // ── Content starts below the traffic lights ────────────────────
          Padding(
            padding: EdgeInsets.only(top: _titleBarHeight),
            child: Row(
              children: [
                NavigationRail(
                  extended: false,
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (i) =>
                      setState(() => _currentIndex = i),
                  minWidth: 72,
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
                    thickness: 1, width: 1, color: dividerColor),
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: _screens,
                  ),
                ),
              ],
            ),
          ),

          // ── Full-width drag handle in the title-bar zone ───────────────
          if (nativeDesktop && _titleBarHeight > 0)
            Positioned(
              top: 0, left: 0, right: 0,
              height: _titleBarHeight,
              child: DragToMoveArea(child: const SizedBox.expand()),
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
        duration: MokuMotion.fast,
        child: IndexedStack(
          key: ValueKey(_currentIndex),
          index: _currentIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sync progress strip — 2px hairline above the nav bar, visible
          // on every page of the mobile layout.
          const _SyncProgressStrip(),
          NavigationBar(
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
        ],
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
// When no catalog is selected yet, show a placeholder — the sidebar already
// lists the available catalogs. Once a catalog is selected via the sidebar,
// the full SearchScreen takes over for browse + search.

class _DiscoverMainPane extends StatelessWidget {
  const _DiscoverMainPane();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SearchCubit, SearchState>(
      builder: (context, state) {
        if (state.isAtCatalogList) {
          return _NoCatalogSelected();
        }
        return const discover.SearchScreen();
      },
    );
  }
}

class _NoCatalogSelected extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.explore_outlined,
            size: 64,
            color: colorScheme.primary.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 20),
          Text(
            'Pick a catalog',
            style: MokuText.sectionHeading(),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a source from the sidebar to browse books.',
            style: MokuText.body(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
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
  final List<_NavDestination> destinations;
  final List<String> labels;

  const _IconRail({
    required this.selectedIndex,
    required this.onTap,
    required this.destinations,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final railBg = theme.navigationRailTheme.backgroundColor ??
        colorScheme.surfaceContainerLow;

    final mainDests = destinations.sublist(0, 4);
    final bottomDest = destinations[4];

    return Container(
      width: 56,
      color: railBg,
      child: Column(
        children: [
          const SizedBox(height: 10),

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

          // Sync indicator in the gap above settings.
          // Shows a small spinning icon while syncing — visible on every page.
          const Spacer(),
          _SyncRailIndicator(),

          // Settings pinned to the bottom
          _IconRailItem(
            icon: bottomDest.icon,
            selectedIcon: bottomDest.selectedIcon,
            label: labels[4],
            isSelected: selectedIndex == 4,
            onTap: () => onTap(4),
          ),
          const SizedBox(height: 10),
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

    final brightness = colorScheme.brightness;
    final selectedBg = brightness == Brightness.light
        ? colorScheme.primary.withValues(alpha: 0.12)
        : colorScheme.primary.withValues(alpha: 0.20);

    return Tooltip(
      message: label,
      preferBelow: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: MokuRadius.smAll,
            child: AnimatedContainer(
              duration: MokuMotion.instant,
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected ? selectedBg : Colors.transparent,
                borderRadius: MokuRadius.smAll,
              ),
              child: Icon(
                isSelected ? selectedIcon : icon,
                size: 24,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sync indicators ─────────────────────────────────────────────────────────

/// 2 px progress bar shown above the mobile NavigationBar and at the
/// bottom of the desktop rail. Invisible when idle; indeterminate shimmer
/// while syncing metadata; determinate fill during a file download.
class _SyncProgressStrip extends StatelessWidget {
  const _SyncProgressStrip();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncConfigCubit, SyncConfigState>(
      buildWhen: (prev, curr) =>
          prev.status != curr.status ||
          prev.progress != curr.progress,
      builder: (context, state) {
        if (state.status != SyncStatus.syncing) {
          return const SizedBox.shrink();
        }
        final fileProgress = state.progress?.fileProgress;
        return SizedBox(
          height: 2,
          child: LinearProgressIndicator(
            value: fileProgress,
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation(
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.75),
            ),
            minHeight: 2,
          ),
        );
      },
    );
  }
}

/// Small spinning sync icon shown in the icon rail between the last nav item
/// and the settings icon. Only appears while a sync is in flight so it
/// doesn't clutter the rail when idle.
class _SyncRailIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncConfigCubit, SyncConfigState>(
      buildWhen: (prev, curr) => prev.status != curr.status,
      builder: (context, state) {
        if (state.status != SyncStatus.syncing) {
          return const SizedBox(height: 8); // small gap above settings
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SizedBox(
            width: 44,
            height: 32,
            child: Center(
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation(
                    Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
