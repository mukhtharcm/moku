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
    final vPad = compact ? MokuSpacing.s1 + 2 : MokuSpacing.s2 + 2;

    return InkWell(
      onTap: onTap,
      borderRadius: MokuRadius.smAll,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: EdgeInsets.only(
          // Left padding shrinks to make room for the accent border
          left: selected ? MokuSpacing.s2 - 2 : MokuSpacing.s2 + 2,
          right: MokuSpacing.s2 + 2,
          top: vPad,
          bottom: vPad,
        ),
        decoration: BoxDecoration(
          // No background fill — selection is communicated by the left
          // border and text weight only. Much less Material-y.
          border: Border(
            left: BorderSide(
              color: selected
                  ? colorScheme.primary
                  : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: MokuSpacing.s2 + 2),
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
                        color: colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.65),
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
