import 'package:flutter/material.dart';
import '../../../core/models/models.dart';
import '../../../core/models/book_localizations.dart';
import 'book_cover.dart';
import '../../../core/ui/ui.dart';

class BookGridItem extends StatelessWidget {
  final Book book;
  final double? progress;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const BookGridItem({
    super.key,
    required this.book,
    this.progress,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final title = bookTitleLabel(context, book.title);
    final author = bookAuthorLabel(context, book.author);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                BookCoverWidget(
                  book: book,
                  width: double.infinity,
                  height: double.infinity,
                ),
                // Progress bar overlay at bottom
                if (progress != null && progress! > 0.01)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                        color: colors.surfaceElevated.withValues(
                          alpha: 0.6,
                        ),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress!,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                            color: colors.accent,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            author,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
