import 'package:equatable/equatable.dart';
import '../../../core/database/database.dart' as db;
import '../../../core/models/models.dart';
import '../../../core/services/epub_service.dart';
import '../../../core/theme/app_theme.dart';

enum ReaderStatus { initial, loading, loaded, error }

/// Available font families for the reader
enum ReaderFontFamily {
  system('System', '-apple-system, system-ui, sans-serif'),
  serif('Serif', 'Georgia, "Times New Roman", serif'),
  sansSerif('Sans Serif', '"Helvetica Neue", Helvetica, Arial, sans-serif'),
  mono('Monospace', '"SF Mono", Menlo, monospace');

  final String displayName;
  final String cssFontFamily;
  const ReaderFontFamily(this.displayName, this.cssFontFamily);
}

class ReaderState extends Equatable {
  final ReaderStatus status;
  final Book book;
  final int currentChapter;
  final List<EpubChapterInfo> chapters;
  final String currentContent;
  final double fontSize;
  final double lineHeight;
  final double horizontalMargin;
  final ReaderFontFamily fontFamily;
  final ReaderTheme readerTheme;
  final bool showControls;
  final bool showToc;
  final double scrollProgress;
  final String? errorMessage;
  final List<db.Highlight> highlights;
  final bool zenMode;

  const ReaderState({
    this.status = ReaderStatus.initial,
    required this.book,
    this.currentChapter = 0,
    this.chapters = const [],
    this.currentContent = '',
    this.fontSize = 18,
    this.lineHeight = 1.8,
    this.horizontalMargin = 24,
    this.fontFamily = ReaderFontFamily.serif,
    this.readerTheme = ReaderTheme.light,
    this.showControls = false,
    this.showToc = false,
    this.scrollProgress = 0.0,
    this.errorMessage,
    this.highlights = const [],
    this.zenMode = false,
  });

  ReaderState copyWith({
    ReaderStatus? status,
    Book? book,
    int? currentChapter,
    List<EpubChapterInfo>? chapters,
    String? currentContent,
    double? fontSize,
    double? lineHeight,
    double? horizontalMargin,
    ReaderFontFamily? fontFamily,
    ReaderTheme? readerTheme,
    bool? showControls,
    bool? showToc,
    double? scrollProgress,
    String? errorMessage,
    List<db.Highlight>? highlights,
    bool? zenMode,
  }) {
    return ReaderState(
      status: status ?? this.status,
      book: book ?? this.book,
      currentChapter: currentChapter ?? this.currentChapter,
      chapters: chapters ?? this.chapters,
      currentContent: currentContent ?? this.currentContent,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      horizontalMargin: horizontalMargin ?? this.horizontalMargin,
      fontFamily: fontFamily ?? this.fontFamily,
      readerTheme: readerTheme ?? this.readerTheme,
      showControls: showControls ?? this.showControls,
      showToc: showToc ?? this.showToc,
      scrollProgress: scrollProgress ?? this.scrollProgress,
      errorMessage: errorMessage ?? this.errorMessage,
      highlights: highlights ?? this.highlights,
      zenMode: zenMode ?? this.zenMode,
    );
  }

  bool get hasNextChapter => currentChapter < chapters.length - 1;
  bool get hasPreviousChapter => currentChapter > 0;

  String get chapterTitle {
    if (chapters.isEmpty || currentChapter >= chapters.length) {
      return 'Chapter ${currentChapter + 1}';
    }
    return chapters[currentChapter].title;
  }

  @override
  List<Object?> get props => [
    status,
    book,
    currentChapter,
    chapters,
    currentContent,
    fontSize,
    lineHeight,
    horizontalMargin,
    fontFamily,
    readerTheme,
    showControls,
    showToc,
    scrollProgress,
    errorMessage,
    highlights,
    zenMode,
  ];
}
