import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moku/core/models/book.dart';
import 'package:moku/core/services/opds_catalog_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'adds a valid OPDS1 custom catalog and stores its search template',
    () async {
      final client = MockClient((request) async {
        if (request.url.toString() ==
            'https://m.gutenberg.org/ebooks/search.opds/') {
          return http.Response(
            '''<?xml version="1.0" encoding="utf-8"?>
          <feed xmlns="http://www.w3.org/2005/Atom">
            <link rel="search" type="application/opensearchdescription+xml" href="/opensearch.xml" />
          </feed>''',
            200,
            headers: {'content-type': 'application/atom+xml; charset=UTF-8'},
          );
        }

        if (request.url.toString() ==
            'https://m.gutenberg.org/opensearch.xml') {
          return http.Response(
            '''<?xml version="1.0" encoding="UTF-8"?>
          <OpenSearchDescription xmlns="http://a9.com/-/spec/opensearch/1.1/">
            <Url type="application/atom+xml" template="https://m.gutenberg.org/ebooks/search.opds/?query={searchTerms}" />
          </OpenSearchDescription>''',
            200,
            headers: {'content-type': 'application/opensearchdescription+xml'},
          );
        }

        return http.Response('not found', 404);
      });

      final service = OpdsCatalogService(client: client);
      addTearDown(service.dispose);

      final catalog = await service.addCustomCatalog(
        title: 'Mobile Gutenberg',
        url: 'm.gutenberg.org/ebooks/search.opds/',
      );

      expect(catalog.kind, CatalogKind.custom);
      expect(catalog.protocol, CatalogProtocol.opds1);
      expect(catalog.url, 'https://m.gutenberg.org/ebooks/search.opds/');
      expect(
        catalog.searchTemplate,
        'https://m.gutenberg.org/ebooks/search.opds/?query={searchTerms}',
      );

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList('discover_custom_catalogs');
      expect(stored, isNotNull);
      final decoded = json.decode(stored!.single) as Map<String, dynamic>;
      expect(decoded['title'], 'Mobile Gutenberg');
    },
  );

  test(
    'adds a browse-only OPDS1 custom catalog without requiring search metadata',
    () async {
      final client = MockClient((request) async {
        if (request.url.toString() == 'https://books.gorkos.net/opds') {
          return http.Response(
            '''<?xml version="1.0" encoding="utf-8"?>
          <feed xmlns="http://www.w3.org/2005/Atom">
            <title>GoPDS Library</title>
            <entry>
              <id>authors-a-d</id>
              <title>Authors A-D (986)</title>
              <link rel="subsection" type="application/atom+xml;profile=opds-catalog;kind=acquisition" href="/opds?authors=a-d&amp;page=1&amp;limit=100" />
            </entry>
          </feed>''',
            200,
            headers: {'content-type': 'application/atom+xml; charset=UTF-8'},
          );
        }

        return http.Response('not found', 404);
      });

      final service = OpdsCatalogService(client: client);
      addTearDown(service.dispose);

      final catalog = await service.addCustomCatalog(
        title: 'GoPDS Library',
        url: 'books.gorkos.net/opds',
      );

      expect(catalog.kind, CatalogKind.custom);
      expect(catalog.protocol, CatalogProtocol.opds1);
      expect(catalog.url, 'https://books.gorkos.net/opds');
      expect(catalog.searchTemplate, isNull);
      expect(catalog.supportsSearch, isFalse);
    },
  );

  test('maps 401 catalog responses to authentication required', () async {
    final service = OpdsCatalogService(
      client: MockClient(
        (_) async => http.Response(
          'unauthorized',
          401,
          headers: {'content-type': 'text/plain'},
        ),
      ),
    );
    addTearDown(service.dispose);

    expect(
      () => service.addCustomCatalog(
        title: 'Standard Ebooks',
        url: 'https://standardebooks.org/feeds/opds',
      ),
      throwsA(
        isA<CatalogException>().having(
          (error) => error.code,
          'code',
          CatalogErrorCode.catalogAuthenticationRequired,
        ),
      ),
    );
  });

  test('maps 403 catalog responses to access denied', () async {
    final service = OpdsCatalogService(
      client: MockClient(
        (_) async => http.Response(
          'forbidden',
          403,
          headers: {'content-type': 'text/plain'},
        ),
      ),
    );
    addTearDown(service.dispose);

    expect(
      () => service.addCustomCatalog(
        title: 'Blocked Feed',
        url: 'https://catalog.feedbooks.com/catalog/index.json',
      ),
      throwsA(
        isA<CatalogException>().having(
          (error) => error.code,
          'code',
          CatalogErrorCode.catalogAccessDenied,
        ),
      ),
    );
  });

  test(
    'follows OPDS1 subsection book feeds and returns downloadable books',
    () async {
      final client = MockClient((request) async {
        final url = request.url.toString();
        if (url == 'https://m.gutenberg.org/ebooks/search.opds/') {
          return http.Response(
            '''<?xml version="1.0" encoding="utf-8"?>
          <feed xmlns="http://www.w3.org/2005/Atom">
            <link rel="search" type="application/opensearchdescription+xml" href="/opensearch.xml" />
          </feed>''',
            200,
            headers: {'content-type': 'application/atom+xml; charset=UTF-8'},
          );
        }

        if (url == 'https://m.gutenberg.org/opensearch.xml') {
          return http.Response(
            '''<?xml version="1.0" encoding="UTF-8"?>
          <OpenSearchDescription xmlns="http://a9.com/-/spec/opensearch/1.1/">
            <Url type="application/atom+xml" template="https://m.gutenberg.org/ebooks/search.opds/?query={searchTerms}" />
          </OpenSearchDescription>''',
            200,
            headers: {'content-type': 'application/opensearchdescription+xml'},
          );
        }

        if (url == 'https://m.gutenberg.org/ebooks/search.opds/?query=alice') {
          return http.Response(
            '''<?xml version="1.0" encoding="utf-8"?>
          <feed xmlns="http://www.w3.org/2005/Atom">
            <entry>
              <id>https://m.gutenberg.org/ebooks/11.opds</id>
              <title>Alice's Adventures in Wonderland</title>
              <link rel="subsection" type="application/atom+xml;profile=opds-catalog" href="/ebooks/11.opds" />
            </entry>
          </feed>''',
            200,
            headers: {'content-type': 'application/atom+xml; charset=UTF-8'},
          );
        }

        if (url == 'https://m.gutenberg.org/ebooks/11.opds') {
          return http.Response(
            '''<?xml version="1.0" encoding="utf-8"?>
          <feed xmlns="http://www.w3.org/2005/Atom">
            <entry>
              <id>https://m.gutenberg.org/ebooks/11</id>
              <title>Alice's Adventures in Wonderland</title>
              <author><name>Lewis Carroll</name></author>
              <link rel="http://opds-spec.org/acquisition" type="application/epub+zip" href="/ebooks/11.epub.images" />
              <link rel="alternate" type="text/html" href="/ebooks/11" />
            </entry>
          </feed>''',
            200,
            headers: {'content-type': 'application/atom+xml; charset=UTF-8'},
          );
        }

        return http.Response('not found', 404);
      });

      final service = OpdsCatalogService(client: client);
      addTearDown(service.dispose);

      final catalog = await service.addCustomCatalog(
        title: 'Mobile Gutenberg',
        url: 'm.gutenberg.org/ebooks/search.opds/',
      );
      final books = await service.searchBooks(catalog, 'alice');

      expect(books, hasLength(1));
      expect(books.single.title, "Alice's Adventures in Wonderland");
      expect(books.single.author, 'Lewis Carroll');
      expect(books.single.preferredAcquisition.format, BookFormat.epub);
    },
  );

  test('loads OPDS1 browse pages with navigation entries', () async {
    final client = MockClient((request) async {
      if (request.url.toString() == 'https://books.gorkos.net/opds') {
        return http.Response(
          '''<?xml version="1.0" encoding="utf-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom">
          <title>GoPDS Library</title>
          <entry>
            <id>authors-a-d</id>
            <title>Authors A-D (986)</title>
            <summary>Browse authors A through D</summary>
            <link rel="subsection" type="application/atom+xml;profile=opds-catalog;kind=acquisition" href="/opds?authors=a-d&amp;page=1&amp;limit=100" />
          </entry>
          <entry>
            <id>browse-category</id>
            <title>Browse by Category (1120)</title>
            <link rel="subsection" type="application/atom+xml;profile=opds-catalog;kind=acquisition" href="/opds?categories=a-z&amp;page=1&amp;limit=100" />
          </entry>
        </feed>''',
          200,
          headers: {'content-type': 'application/atom+xml; charset=UTF-8'},
        );
      }

      return http.Response('not found', 404);
    });

    final service = OpdsCatalogService(client: client);
    addTearDown(service.dispose);

    const catalog = CatalogSource(
      id: 'custom-gopds',
      title: 'GoPDS Library',
      url: 'https://books.gorkos.net/opds',
      kind: CatalogKind.custom,
      protocol: CatalogProtocol.opds1,
    );

    final page = await service.loadCatalogPage(catalog);

    expect(page.title, 'GoPDS Library');
    expect(page.books, isEmpty);
    expect(page.navigationEntries, hasLength(2));
    expect(page.navigationEntries.first.title, 'Authors A-D (986)');
    expect(
      page.navigationEntries.first.uri.toString(),
      'https://books.gorkos.net/opds?authors=a-d&page=1&limit=100',
    );
  });
}
