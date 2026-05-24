import 'package:flutter_test/flutter_test.dart';
import 'package:moku/core/services/opds_catalog_service.dart';

void main() {
  test('browse-only catalogs are supported without being searchable', () {
    const catalog = CatalogSource(
      id: 'custom',
      title: 'GoPDS Library',
      url: 'https://books.gorkos.net/opds',
      kind: CatalogKind.custom,
      protocol: CatalogProtocol.opds1,
    );

    expect(catalog.isCustom, isTrue);
    expect(catalog.supportsSearch, isFalse);
  });
}
