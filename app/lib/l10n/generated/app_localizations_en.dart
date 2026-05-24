// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Moku';

  @override
  String get bookUnknownTitle => 'Untitled';

  @override
  String get bookUnknownAuthor => 'Unknown author';

  @override
  String get formatEpub => 'EPUB';

  @override
  String get formatPdf => 'PDF';

  @override
  String get formatText => 'Text';

  @override
  String get formatComicCbz => 'Comic (CBZ)';

  @override
  String get formatHtml => 'HTML';

  @override
  String get navLibrary => 'Library';

  @override
  String get navDiscover => 'Discover';

  @override
  String get navShelves => 'Shelves';

  @override
  String get navStats => 'Stats';

  @override
  String get navSettings => 'Settings';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonCreate => 'Create';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonRemove => 'Remove';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonSave => 'Save';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonTryAgain => 'Try Again';

  @override
  String get commonImportFiles => 'Import files';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingWelcomeTitle => 'Welcome to Moku';

  @override
  String get onboardingWelcomeSubtitle => 'Your cozy reading companion';

  @override
  String get onboardingWelcomeBody =>
      'Import EPUB, PDF, TXT, CBZ, and HTML files,\ntrack progress, and read distraction-free.';

  @override
  String get onboardingGetStarted => 'Get Started';

  @override
  String get onboardingImportTitle => 'Import Your Books';

  @override
  String get onboardingImportBody =>
      'Add EPUB, PDF, TXT, CBZ, and HTML files from your device.\nYour library stays on your device, fully offline.';

  @override
  String get onboardingImportLater => 'I\'ll do this later';

  @override
  String get onboardingSyncTitle => 'Sync Across Devices';

  @override
  String get onboardingSyncOfflineBody =>
      'Moku works fully offline - no account needed.';

  @override
  String get onboardingSyncServerBody =>
      'Want to sync books and progress across devices?\nConnect your own PocketBase server in Settings.';

  @override
  String get onboardingStartReading => 'Start Reading';

  @override
  String get librarySearchHint => 'Search your library...';

  @override
  String get librarySearchAction => 'Search library';

  @override
  String get libraryCloseSearch => 'Close search';

  @override
  String get libraryErrorFallback => 'Something went wrong';

  @override
  String get librarySectionTitle => 'Library';

  @override
  String get libraryFabImport => 'Import';

  @override
  String get librarySwitchToListView => 'Switch to list view';

  @override
  String get librarySwitchToGridView => 'Switch to grid view';

  @override
  String get librarySortRecent => 'Recent';

  @override
  String get librarySortTitle => 'Title';

  @override
  String get librarySortAuthor => 'Author';

  @override
  String get libraryBookInfo => 'Book Info';

  @override
  String get libraryInfoChapters => 'Chapters';

  @override
  String get libraryInfoPublisher => 'Publisher';

  @override
  String get libraryInfoLanguage => 'Language';

  @override
  String get libraryInfoIsbn => 'ISBN';

  @override
  String get libraryDeleteBookTitle => 'Delete Book';

  @override
  String libraryDeleteBookMessage({required Object title}) {
    return 'Remove \"$title\" from your library?';
  }

  @override
  String get libraryEmptySearchTitle => 'No books found';

  @override
  String get libraryEmptySearchBody => 'Try a different search term';

  @override
  String get libraryEmptyTitle => 'Your library awaits';

  @override
  String get libraryEmptyBody =>
      'Import your first book or comic to start reading';

  @override
  String get libraryContinueReading => 'Continue Reading';

  @override
  String libraryProgressRead({required int progress}) {
    return '$progress% read';
  }

  @override
  String get searchTitle => 'Discover';

  @override
  String get searchCatalogOpenLibraryTitle => 'Open Library';

  @override
  String get searchCatalogProjectGutenbergTitle => 'Project Gutenberg';

  @override
  String get searchManageCatalogs => 'Manage catalogs';

  @override
  String get searchCatalogLabel => 'Catalog';

  @override
  String get searchGenericCatalogName => 'catalog';

  @override
  String get searchPromptGenericCatalogName => 'a catalog';

  @override
  String searchHint({required Object catalogTitle}) {
    return 'Search $catalogTitle...';
  }

  @override
  String searchInitialPromptTitle({required Object catalogTitle}) {
    return 'Search $catalogTitle';
  }

  @override
  String get searchInitialPromptBody =>
      'Find downloadable books and add them straight to your library.';

  @override
  String get searchErrorFallback => 'Something went wrong.';

  @override
  String get searchErrorInvalidCatalogInput =>
      'Enter a valid catalog name and URL.';

  @override
  String get searchErrorDuplicateCatalog =>
      'That catalog has already been added.';

  @override
  String get searchErrorCatalogAuthenticationRequired =>
      'This catalog requires sign-in or other authentication.';

  @override
  String get searchErrorCatalogAccessDenied =>
      'This catalog denied access from the app.';

  @override
  String get searchErrorDownloadRedirected =>
      'The download redirected too many times.';

  @override
  String get searchErrorDownloadFailed => 'The download failed.';

  @override
  String get searchErrorCatalogNotSearchable =>
      'This catalog does not provide a searchable OPDS feed.';

  @override
  String get searchErrorSearchFailed => 'The catalog search failed.';

  @override
  String get searchErrorCatalogLoadFailed => 'Could not load that catalog.';

  @override
  String get searchErrorCatalogMissingSearchLink =>
      'This catalog does not expose a usable search link.';

  @override
  String get searchErrorCatalogSearchDescriptionFailed =>
      'Could not load the catalog search description.';

  @override
  String get searchErrorCatalogSearchTemplateMissing =>
      'Could not find a usable search template for this catalog.';

  @override
  String get searchBrowseEmpty => 'Nothing to browse here yet.';

  @override
  String get searchEmptyResults => 'No downloadable books found';

  @override
  String get searchNoCatalogSelected => 'Choose a catalog to start searching';

  @override
  String searchBookAdded({required Object title}) {
    return '$title added to your library';
  }

  @override
  String searchDownloadFailed({required Object error}) {
    return 'Download failed: $error';
  }

  @override
  String get searchCatalogsTitle => 'Catalogs';

  @override
  String get searchCatalogsBody =>
      'Built-ins are ready to use. Add your own OPDS catalogs too.';

  @override
  String get searchRemoveCatalog => 'Remove catalog';

  @override
  String get searchNoCustomCatalogs => 'No custom catalogs yet.';

  @override
  String get searchAddCustomCatalog => 'Add Custom Catalog';

  @override
  String get searchAddCustomCatalogTitle => 'Add Custom Catalog';

  @override
  String get searchCatalogNameLabel => 'Catalog name';

  @override
  String get searchCatalogUrlLabel => 'Catalog URL';

  @override
  String searchCouldNotAddCatalog({required Object error}) {
    return 'Could not add catalog: $error';
  }

  @override
  String get searchCatalogTypeCustom => 'Custom';

  @override
  String get searchOpenSourcePage => 'Open source page';

  @override
  String get searchDownloading => 'Downloading...';

  @override
  String get searchDownloaded => 'Downloaded';

  @override
  String searchDownloadFormat({required Object formatName}) {
    return 'Download $formatName';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionAppearance => 'Appearance';

  @override
  String get settingsLanguageTitle => 'App Language';

  @override
  String get settingsLanguageSystem => 'System';

  @override
  String get settingsLanguageSystemSubtitle => 'Follow device language';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageArabic => 'العربية';

  @override
  String get settingsSectionBattery => 'Battery';

  @override
  String get settingsSectionSync => 'Sync';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeSystemSubtitle => 'Follow device theme';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsPowerSaverTitle => 'Power Saver';

  @override
  String get settingsPowerSaverSubtitle =>
      'Reduce animations and scroll updates';

  @override
  String get settingsSyncServerTitle => 'Sync Server';

  @override
  String get settingsSyncConnected => 'Connected';

  @override
  String get settingsSyncNotLoggedIn => 'Not logged in';

  @override
  String get settingsSyncNotConfigured => 'Not configured';

  @override
  String settingsVersion({required Object version}) {
    return 'Version $version';
  }

  @override
  String settingsVersionValue({required Object version}) {
    return '$version';
  }

  @override
  String settingsVersionValueWithBuild({
    required Object version,
    required Object build,
  }) {
    return '$version ($build)';
  }

  @override
  String get settingsVersionUnavailable => 'Version unavailable';

  @override
  String get settingsVersionLoading => 'Loading version...';

  @override
  String get settingsOpenSourceTitle => 'Open Source';

  @override
  String get settingsOpenSourceSubtitle => 'Flutter + PocketBase';

  @override
  String get syncSettingsTitle => 'Sync Settings';

  @override
  String get syncStatusDisconnected => 'Disconnected';

  @override
  String get syncStatusConnecting => 'Connecting...';

  @override
  String get syncStatusConnected => 'Connected';

  @override
  String get syncStatusSyncing => 'Syncing...';

  @override
  String get syncStatusError => 'Error';

  @override
  String syncLastSynced({required Object value}) {
    return 'Last synced: $value';
  }

  @override
  String get syncNeverSynced => 'Never synced';

  @override
  String get syncServerSectionTitle => 'Server';

  @override
  String get syncServerUrlLabel => 'Server URL';

  @override
  String get syncServerUrlHint => 'https://your-server.com';

  @override
  String get syncConnect => 'Connect';

  @override
  String get syncCreateAccount => 'Create Account';

  @override
  String get syncLogin => 'Login';

  @override
  String get syncHaveAccountLogin => 'Have an account? Login';

  @override
  String get syncNewRegister => 'New? Register';

  @override
  String get syncEmailLabel => 'Email';

  @override
  String get syncPasswordLabel => 'Password';

  @override
  String get syncRegister => 'Register';

  @override
  String get syncSectionTitle => 'Sync';

  @override
  String get syncAutoSyncTitle => 'Automatic sync';

  @override
  String get syncAutoSyncSubtitle =>
      'Sync in the background on startup, foreground, and after changes.';

  @override
  String get syncSyncNow => 'Sync Now';

  @override
  String get syncAccountTitle => 'Account';

  @override
  String get syncLogout => 'Logout';

  @override
  String get syncRecentErrors => 'Recent Sync Errors';

  @override
  String syncFailedToConnect({required Object error}) {
    return 'Failed to connect: $error';
  }

  @override
  String syncRegistrationFailed({required Object error}) {
    return 'Registration failed: $error';
  }

  @override
  String syncLoginFailed({required Object error}) {
    return 'Login failed: $error';
  }

  @override
  String get syncAuthExpired => 'Authentication expired. Please log in again.';

  @override
  String syncPartialFailure({required Object collections}) {
    return 'Sync partially failed: $collections';
  }

  @override
  String syncFailed({required Object error}) {
    return 'Sync failed: $error';
  }

  @override
  String get syncFailedToConnectGeneric => 'Failed to connect to the server.';

  @override
  String get syncRegistrationFailedGeneric =>
      'Registration failed. Please try again.';

  @override
  String get syncLoginFailedGeneric =>
      'Login failed. Please check your credentials and try again.';

  @override
  String get syncFailedGeneric => 'Sync failed. Please try again.';

  @override
  String get syncErrorLogGenericMessage => 'This data could not be synced.';

  @override
  String get syncCollectionBooks => 'Books';

  @override
  String get syncCollectionReadingProgress => 'Reading progress';

  @override
  String get syncCollectionBookmarks => 'Bookmarks';

  @override
  String get syncCollectionHighlights => 'Highlights';

  @override
  String get syncCollectionShelves => 'Shelves';

  @override
  String get syncCollectionShelfBooks => 'Shelf books';

  @override
  String get syncCollectionReadingSessions => 'Reading sessions';

  @override
  String get syncCollectionReadingGoals => 'Reading goals';

  @override
  String get syncCollectionUnknown => 'Other data';

  @override
  String get collectionsTitle => 'Shelves';

  @override
  String get collectionsEmptyTitle => 'No shelves yet';

  @override
  String get collectionsEmptyBody => 'Organize your books into collections';

  @override
  String get collectionsCreateShelf => 'Create Shelf';

  @override
  String get collectionsNewShelfTitle => 'New Shelf';

  @override
  String get collectionsNameLabel => 'Name';

  @override
  String get collectionsNameHint => 'e.g. Favorites, To Read...';

  @override
  String get collectionsDescriptionOptionalLabel => 'Description (optional)';

  @override
  String get collectionsDeleteShelfTitle => 'Delete Shelf';

  @override
  String collectionsDeleteShelfMessage({required Object name}) {
    return 'Delete \"$name\"? Your books won\'t be removed from the library.';
  }

  @override
  String get collectionDetailAddBooksTooltip => 'Add books';

  @override
  String get collectionDetailEmptyTitle => 'No books in this collection';

  @override
  String get collectionDetailAddBooks => 'Add Books';

  @override
  String get collectionDetailRemoveTitle => 'Remove from Collection';

  @override
  String collectionDetailRemoveMessage({
    required Object title,
    required Object collectionName,
  }) {
    return 'Remove \"$title\" from \"$collectionName\"?';
  }

  @override
  String get collectionDetailAllBooksAlreadyAdded =>
      'All books are already in this collection';

  @override
  String get collectionDetailAddBooksTitle => 'Add Books';

  @override
  String collectionDetailAddedBook({required Object title}) {
    return 'Added \"$title\"';
  }

  @override
  String get readerAnnotations => 'Annotations';

  @override
  String readerHighlightsTab({required int count}) {
    return 'Highlights ($count)';
  }

  @override
  String readerBookmarksTab({required int count}) {
    return 'Bookmarks ($count)';
  }

  @override
  String get readerNoHighlightsYet => 'No highlights yet';

  @override
  String get readerNoHighlightsHint =>
      'Select text while reading to highlight it';

  @override
  String get readerNoBookmarksYet => 'No bookmarks yet';

  @override
  String get readerDeleteBookmarkTitle => 'Delete Bookmark';

  @override
  String get readerDeleteBookmarkMessage =>
      'Are you sure you want to delete this bookmark?';

  @override
  String get readerBookmarkAdded => 'Bookmark added';

  @override
  String readerQuotedSelection({required Object text}) {
    return '\"$text\"';
  }

  @override
  String readerChapterLabel({required int chapterNumber}) {
    return 'Chapter $chapterNumber';
  }

  @override
  String get readerDeleteHighlightTitle => 'Delete Highlight';

  @override
  String get readerDeleteHighlightMessage =>
      'Are you sure you want to delete this highlight?';

  @override
  String get readerEditNote => 'Edit Note';

  @override
  String get readerAddNote => 'Add Note';

  @override
  String get readerNoteHint => 'Enter your note...';

  @override
  String get readerHighlight => 'Highlight';

  @override
  String get readerHighlightWithNote => 'Highlight with Note';

  @override
  String get readerCopiedToClipboard => 'Copied to clipboard';

  @override
  String get readerErrorTitle => 'Reader Error';

  @override
  String readerLoadFailed({required Object error}) {
    return 'Failed to load this book: $error';
  }

  @override
  String get readerUnknownError =>
      'Something went wrong while opening this book.';

  @override
  String get readerExitZenMode => 'Exit Zen Mode';

  @override
  String get readerZenMode => 'Zen Mode';

  @override
  String get readerSwitchToLightMode => 'Switch to light mode';

  @override
  String get readerSwitchToDarkMode => 'Switch to dark mode';

  @override
  String get readerTableOfContents => 'Table of Contents';

  @override
  String get readerSettings => 'Settings';

  @override
  String get readerBookmark => 'Bookmark';

  @override
  String get readerTypography => 'Typography';

  @override
  String get readerReadingDirection => 'Reading direction';

  @override
  String get readerDirectionAuto => 'Auto';

  @override
  String get readerDirectionLeftToRight => 'Left to right';

  @override
  String get readerDirectionRightToLeft => 'Right to left';

  @override
  String get readerTheme => 'Theme';

  @override
  String get readerContents => 'Contents';

  @override
  String readerPageOf({required int currentPage, required int totalPages}) {
    return 'Page $currentPage of $totalPages';
  }

  @override
  String readerChapterProgress({
    required Object chapterTitle,
    required int percent,
  }) {
    return '$chapterTitle · $percent%';
  }

  @override
  String get readerFontFamilySystem => 'System';

  @override
  String get readerFontFamilySerif => 'Serif';

  @override
  String get readerFontFamilySansSerif => 'Sans Serif';

  @override
  String get readerFontFamilyMonospace => 'Monospace';

  @override
  String get statsTitle => 'Reading Stats';

  @override
  String get statsErrorFallback => 'Error';

  @override
  String statsLoadFailed({required Object error}) {
    return 'Failed to load stats: $error';
  }

  @override
  String get statsTotalTime => 'Total Time';

  @override
  String get statsBooksStartedThisYear => 'Books Started This Year';

  @override
  String get statsSessions => 'Sessions';

  @override
  String statsSessionCount({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions',
      one: '1 session',
      zero: 'No sessions',
    );
    return '$_temp0';
  }

  @override
  String get statsRecentSessions => 'Recent Sessions';

  @override
  String get statsCurrentStreak => 'Current Streak';

  @override
  String get statsLongestStreak => 'Longest Streak';

  @override
  String get statsReadingActivity => 'Reading Activity';

  @override
  String get statsHeatmapLess => 'Less';

  @override
  String get statsHeatmapMore => 'More';

  @override
  String statsHeatmapNoReading({required Object date}) {
    return '$date: No reading';
  }

  @override
  String statsHeatmapMinutes({required Object date, required int minutes}) {
    return '$date: $minutes min';
  }

  @override
  String statsDurationHoursMinutes({required int hours, required int minutes}) {
    return '${hours}h ${minutes}m';
  }

  @override
  String statsDurationMinutes({required int minutes}) {
    return '${minutes}m';
  }
}
