/// Shared panel/sidebar atoms used across Library, Shelves, Settings,
/// Discover, and the Reader sidebar.
///
/// Every sidebar in the app must be built from these — never inline.
library;

import 'package:flutter/material.dart';
import '../tokens.dart';
import '../moku_text.dart';

// ── MokuPanelHeader ──────────────────────────────────────────────────────────
/// Top header row inside a sidebar or panel.
/// Shows a [label], optional [trailing] widget, and a bottom divider.
///
/// ```dart
/// MokuPanelHeader(label: 'Library', trailing: IconButton(...))
/// ```

class MokuPanelHeader extends StatelessWidget {
  final String label;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const MokuPanelHeader({
    super.key,
    required this.label,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(
      MokuSpacing.panelPadding,
      MokuSpacing.s3,
      MokuSpacing.s2,
      MokuSpacing.s2,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: padding,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: MokuText.sectionLabel(
                    color: colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.6),
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
        Divider(
          height: 1,
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ],
    );
  }
}

// ── MokuPanelItem ─────────────────────────────────────────────────────────────
/// A selectable row item inside a sidebar panel.
/// Used in library book list, shelf list, settings sections, catalog list, ToC.

class MokuPanelItem extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool selected;
  final bool compact;
  final VoidCallback? onTap;

  const MokuPanelItem({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.selected = false,
    this.compact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final vPad = compact ? MokuSpacing.s1 : MokuSpacing.s1 + 2;

    // Neutral selection — desktop-app style row highlight, slightly
    // tinted with the primary so the active row still reads as "active".
    final selectedBg = colorScheme.brightness == Brightness.light
        ? colorScheme.primary.withValues(alpha: 0.10)
        : colorScheme.primary.withValues(alpha: 0.18);

    return InkWell(
      onTap: onTap,
      borderRadius: MokuRadius.smAll,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(
          horizontal: MokuSpacing.s1,
          vertical: 1,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: MokuSpacing.s2,
          vertical: vPad,
        ),
        decoration: BoxDecoration(
          color: selected ? selectedBg : Colors.transparent,
          borderRadius: MokuRadius.smAll,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: MokuSpacing.s2),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: MokuText.panelItem(
                      selected: selected,
                      color: selected
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MokuText.caption(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: MokuSpacing.s1),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

// ── MokuSectionLabel ──────────────────────────────────────────────────────────
/// Small uppercase group label — e.g. "LANGUAGE", "THEME", "RECENTLY READ".

class MokuSectionLabel extends StatelessWidget {
  final String label;
  final EdgeInsetsGeometry padding;

  const MokuSectionLabel(
    this.label, {
    super.key,
    this.padding = const EdgeInsets.fromLTRB(
      MokuSpacing.panelPadding,
      MokuSpacing.s3,
      MokuSpacing.panelPadding,
      MokuSpacing.s1,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        label.toUpperCase(),
        style: MokuText.sectionLabel(
          color: Theme.of(context)
              .colorScheme
              .onSurfaceVariant
              .withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

// ── MokuPanelDivider ──────────────────────────────────────────────────────────
/// Consistent thin divider used inside panels and between sections.

class MokuPanelDivider extends StatelessWidget {
  final double indent;
  const MokuPanelDivider({super.key, this.indent = 0});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: indent,
      color: Theme.of(context)
          .colorScheme
          .outlineVariant
          .withValues(alpha: 0.3),
    );
  }
}

// ── MokuProgressBar ───────────────────────────────────────────────────────────
/// Thin inline reading progress bar used in book list items.

class MokuProgressBar extends StatelessWidget {
  final double progress; // 0.0 – 1.0
  final double height;

  const MokuProgressBar({
    super.key,
    required this.progress,
    this.height = 2.5,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(MokuRadius.pill),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: height,
        backgroundColor:
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
    );
  }
}
