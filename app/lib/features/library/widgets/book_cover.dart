import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/models.dart';

/// A book cover with realistic depth via shadow and a subtle spine edge.
class BookCoverWidget extends StatelessWidget {
  final Book book;
  final double? width;
  final double? height;
  final double borderRadius;
  final bool showShadow;

  const BookCoverWidget({
    super.key,
    required this.book,
    this.width,
    this.height,
    this.borderRadius = 12,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget cover;
    if (book.coverPath != null && File(book.coverPath!).existsSync()) {
      cover = Image.file(
        File(book.coverPath!),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _PlaceholderCover(book: book, width: width, height: height),
      );
    } else {
      cover = _PlaceholderCover(book: book, width: width, height: height);
    }

    return Container(
      decoration: showShadow
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(2, 4),
                ),
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            )
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          children: [
            cover,
            // Spine highlight — subtle left-edge gradient
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 6,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.18),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderCover extends StatelessWidget {
  final Book book;
  final double? width;
  final double? height;

  const _PlaceholderCover({
    required this.book,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final hash = book.title.hashCode;
    final hue = (hash % 360).toDouble().abs();
    // Richer, deeper placeholder colors
    final baseColor = HSLColor.fromAHSL(1, hue, 0.35, 0.28).toColor();
    final darkColor = HSLColor.fromAHSL(1, hue, 0.45, 0.14).toColor();
    final accentColor = HSLColor.fromAHSL(1, (hue + 30) % 360, 0.5, 0.55).toColor();

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [baseColor, darkColor],
          stops: const [0.3, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Decorative pattern — subtle geometric accent
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.auto_stories,
              size: 80,
              color: Colors.white.withValues(alpha: 0.04),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Accent line
                Container(
                  width: 24,
                  height: 3,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: Text(
                    book.title,
                    style: GoogleFonts.literata(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  book.author,
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
