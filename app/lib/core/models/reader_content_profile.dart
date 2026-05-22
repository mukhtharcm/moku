import 'package:equatable/equatable.dart';

enum ContentTextDirection { ltr, rtl }

enum ReaderDirectionOverride { auto, ltr, rtl }

enum ReaderDirectionSource {
  override,
  formatMetadata,
  contentMetadata,
  bookMetadata,
  heuristic,
  fallback,
}

class ReaderContentProfile extends Equatable {
  final String? languageTag;
  final ContentTextDirection textDirection;
  final ContentTextDirection pageProgressionDirection;
  final ReaderDirectionSource directionSource;

  const ReaderContentProfile({
    required this.languageTag,
    required this.textDirection,
    required this.pageProgressionDirection,
    required this.directionSource,
  });

  bool get isRtl => textDirection == ContentTextDirection.rtl;
  bool get isPageProgressionRtl =>
      pageProgressionDirection == ContentTextDirection.rtl;

  @override
  List<Object?> get props => [
    languageTag,
    textDirection,
    pageProgressionDirection,
    directionSource,
  ];
}
