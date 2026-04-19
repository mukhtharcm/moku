import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenLibraryService {
  static const _baseUrl = 'https://openlibrary.org';
  static const _coversUrl = 'https://covers.openlibrary.org';

  final http.Client _client;

  OpenLibraryService({http.Client? client}) : _client = client ?? http.Client();

  /// Search books by query
  Future<List<OpenLibraryBook>> searchBooks(
    String query, {
    int page = 1,
    int limit = 20,
  }) async {
    final uri = Uri.parse('$_baseUrl/search.json').replace(
      queryParameters: {
        'q': query,
        'page': page.toString(),
        'limit': limit.toString(),
        'fields':
            'key,title,author_name,first_publish_year,cover_i,isbn,language,publisher,subject,number_of_pages_median',
      },
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to search books: ${response.statusCode}');
    }

    final data = json.decode(response.body);
    final docs = data['docs'] as List<dynamic>? ?? [];

    return docs.map((doc) => OpenLibraryBook.fromJson(doc)).toList();
  }

  /// Get book details by Open Library key
  Future<Map<String, dynamic>> getBookDetails(String key) async {
    final uri = Uri.parse('$_baseUrl$key.json');
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to get book details: ${response.statusCode}');
    }
    return json.decode(response.body);
  }

  /// Get cover image URL
  static String? getCoverUrl(int? coverId, {String size = 'M'}) {
    if (coverId == null) return null;
    return '$_coversUrl/b/id/$coverId-$size.jpg';
  }

  void dispose() {
    _client.close();
  }
}

class OpenLibraryBook {
  final String key;
  final String title;
  final List<String> authors;
  final int? firstPublishYear;
  final int? coverId;
  final List<String> isbn;
  final List<String> languages;
  final List<String> publishers;
  final List<String> subjects;
  final int? pageCount;

  const OpenLibraryBook({
    required this.key,
    required this.title,
    required this.authors,
    this.firstPublishYear,
    this.coverId,
    this.isbn = const [],
    this.languages = const [],
    this.publishers = const [],
    this.subjects = const [],
    this.pageCount,
  });

  factory OpenLibraryBook.fromJson(Map<String, dynamic> json) {
    return OpenLibraryBook(
      key: json['key'] ?? '',
      title: json['title'] ?? 'Unknown',
      authors: (json['author_name'] as List<dynamic>?)
              ?.map((a) => a.toString())
              .toList() ??
          [],
      firstPublishYear: json['first_publish_year'] as int?,
      coverId: json['cover_i'] as int?,
      isbn: (json['isbn'] as List<dynamic>?)
              ?.map((i) => i.toString())
              .toList() ??
          [],
      languages: (json['language'] as List<dynamic>?)
              ?.map((l) => l.toString())
              .toList() ??
          [],
      publishers: (json['publisher'] as List<dynamic>?)
              ?.map((p) => p.toString())
              .toList() ??
          [],
      subjects: (json['subject'] as List<dynamic>?)
              ?.map((s) => s.toString())
              .take(5)
              .toList() ??
          [],
      pageCount: json['number_of_pages_median'] as int?,
    );
  }

  String? get coverUrl => OpenLibraryService.getCoverUrl(coverId);
  String get authorString => authors.join(', ');
}
