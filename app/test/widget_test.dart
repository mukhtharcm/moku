import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moku/core/services/opds_catalog_service.dart';
import 'package:moku/features/search/screens/search_screen.dart';

void main() {
  testWidgets(
    'CatalogDropdownItem renders inside dropdowns without layout exceptions',
    (WidgetTester tester) async {
      const catalog = CatalogSource(
        id: 'custom',
        title: 'Pocket Catalog',
        url: 'https://example.com/opds',
        kind: CatalogKind.custom,
        protocol: CatalogProtocol.opds2,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: DropdownButtonFormField<String>(
                  initialValue: catalog.id,
                  isExpanded: true,
                  selectedItemBuilder: (context) => const [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Pocket Catalog'),
                    ),
                  ],
                  items: [
                    DropdownMenuItem<String>(
                      value: catalog.id,
                      child: CatalogDropdownItem(catalog: catalog),
                    ),
                  ],
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      expect(find.text('Pocket Catalog'), findsWidgets);
      expect(find.text('Custom'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
