import 'package:flutter/widgets.dart';

import '../../../core/services/opds_catalog_service.dart';
import '../../../l10n/l10n.dart';

String catalogTitleLabel(BuildContext context, CatalogSource catalog) {
  return catalogTitleForId(context, catalog.id, fallbackTitle: catalog.title);
}

String catalogBookTitleLabel(BuildContext context, CatalogBook book) {
  return catalogTitleForId(
    context,
    book.catalogId,
    fallbackTitle: book.catalogTitle,
  );
}

String catalogTitleForId(
  BuildContext context,
  String catalogId, {
  String fallbackTitle = '',
}) {
  final l10n = context.l10n;

  return switch (catalogId) {
    'open-library' => l10n.searchCatalogOpenLibraryTitle,
    'project-gutenberg' => l10n.searchCatalogProjectGutenbergTitle,
    _ =>
      fallbackTitle.trim().isEmpty
          ? l10n.searchGenericCatalogName
          : fallbackTitle,
  };
}

String catalogErrorMessage(BuildContext context, Object error) {
  if (error is CatalogException) {
    return catalogErrorCodeMessage(context, error.code);
  }

  return context.l10n.searchErrorFallback;
}

String catalogErrorCodeMessage(BuildContext context, CatalogErrorCode? code) {
  final l10n = context.l10n;

  return switch (code) {
    CatalogErrorCode.invalidCatalogInput => l10n.searchErrorInvalidCatalogInput,
    CatalogErrorCode.duplicateCatalog => l10n.searchErrorDuplicateCatalog,
    CatalogErrorCode.catalogAuthenticationRequired =>
      l10n.searchErrorCatalogAuthenticationRequired,
    CatalogErrorCode.catalogAccessDenied => l10n.searchErrorCatalogAccessDenied,
    CatalogErrorCode.downloadRedirectLoop => l10n.searchErrorDownloadRedirected,
    CatalogErrorCode.downloadFailed => l10n.searchErrorDownloadFailed,
    CatalogErrorCode.catalogNotSearchable =>
      l10n.searchErrorCatalogNotSearchable,
    CatalogErrorCode.searchFailed => l10n.searchErrorSearchFailed,
    CatalogErrorCode.catalogLoadFailed => l10n.searchErrorCatalogLoadFailed,
    CatalogErrorCode.opds2MissingSearchLink ||
    CatalogErrorCode.opds1MissingSearchDescription =>
      l10n.searchErrorCatalogMissingSearchLink,
    CatalogErrorCode.catalogSearchDescriptionFailed =>
      l10n.searchErrorCatalogSearchDescriptionFailed,
    CatalogErrorCode.catalogSearchTemplateMissing =>
      l10n.searchErrorCatalogSearchTemplateMissing,
    null => l10n.searchErrorFallback,
  };
}
