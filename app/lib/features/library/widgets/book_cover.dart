import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/models/models.dart';

class BookCoverWidget extends StatelessWidget {
  final Book book;
  final double? width;
  final double? height;
  final double borderRadius;

  const BookCoverWidget({
    super.key,
    required this.book,
    this.width,
    this.height,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: book.coverPath != null && File(book.coverPath!).existsSync()
          ? Image.file(
              File(book.coverPath!),
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _PlaceholderCover(book: book, width: width, height: height, colorScheme: colorScheme),
            )
          : _PlaceholderCover(book: book, width: width, height: height, colorScheme: colorScheme),
    );
  }
}

class _PlaceholderCover extends StatelessWidget {
  final Book book;
  final double? width;
  final double? height;
  final ColorScheme colorScheme;

  const _PlaceholderCover({
    required this.book,
    this.width,
    this.height,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    // Generate a consistent color from the book title
    final hash = book.title.hashCode;
    final hue = (hash % 360).toDouble().abs();
    final bgColor = HSLColor.fromAHSL(1, hue, 0.3, 0.25).toColor();

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bgColor,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            bgColor,
            HSLColor.fromAHSL(1, hue, 0.4, 0.15).toColor(),
          ],
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            book.title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            book.author,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
