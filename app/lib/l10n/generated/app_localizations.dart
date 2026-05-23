import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ar'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Moku'**
  String get appTitle;

  /// No description provided for @bookUnknownTitle.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get bookUnknownTitle;

  /// No description provided for @bookUnknownAuthor.
  ///
  /// In en, this message translates to:
  /// **'Unknown author'**
  String get bookUnknownAuthor;

  /// No description provided for @formatEpub.
  ///
  /// In en, this message translates to:
  /// **'EPUB'**
  String get formatEpub;

  /// No description provided for @formatPdf.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get formatPdf;

  /// No description provided for @formatText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get formatText;

  /// No description provided for @formatComicCbz.
  ///
  /// In en, this message translates to:
  /// **'Comic (CBZ)'**
  String get formatComicCbz;

  /// No description provided for @formatHtml.
  ///
  /// In en, this message translates to:
  /// **'HTML'**
  String get formatHtml;

  /// No description provided for @navLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get navLibrary;

  /// No description provided for @navDiscover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get navDiscover;

  /// No description provided for @navShelves.
  ///
  /// In en, this message translates to:
  /// **'Shelves'**
  String get navShelves;

  /// No description provided for @navStats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get navStats;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get commonCreate;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// No description provided for @commonTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get commonTryAgain;

  /// No description provided for @commonImportFiles.
  ///
  /// In en, this message translates to:
  /// **'Import files'**
  String get commonImportFiles;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Moku'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your cozy reading companion'**
  String get onboardingWelcomeSubtitle;

  /// No description provided for @onboardingWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Import EPUB, PDF, TXT, CBZ, and HTML files,\ntrack progress, and read distraction-free.'**
  String get onboardingWelcomeBody;

  /// No description provided for @onboardingGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingGetStarted;

  /// No description provided for @onboardingImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import Your Books'**
  String get onboardingImportTitle;

  /// No description provided for @onboardingImportBody.
  ///
  /// In en, this message translates to:
  /// **'Add EPUB, PDF, TXT, CBZ, and HTML files from your device.\nYour library stays on your device, fully offline.'**
  String get onboardingImportBody;

  /// No description provided for @onboardingImportLater.
  ///
  /// In en, this message translates to:
  /// **'I\'\'ll do this later'**
  String get onboardingImportLater;

  /// No description provided for @onboardingSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync Across Devices'**
  String get onboardingSyncTitle;

  /// No description provided for @onboardingSyncOfflineBody.
  ///
  /// In en, this message translates to:
  /// **'Moku works fully offline - no account needed.'**
  String get onboardingSyncOfflineBody;

  /// No description provided for @onboardingSyncServerBody.
  ///
  /// In en, this message translates to:
  /// **'Want to sync books and progress across devices?\nConnect your own PocketBase server in Settings.'**
  String get onboardingSyncServerBody;

  /// No description provided for @onboardingStartReading.
  ///
  /// In en, this message translates to:
  /// **'Start Reading'**
  String get onboardingStartReading;

  /// No description provided for @librarySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search your library...'**
  String get librarySearchHint;

  /// No description provided for @librarySearchAction.
  ///
  /// In en, this message translates to:
  /// **'Search library'**
  String get librarySearchAction;

  /// No description provided for @libraryCloseSearch.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get libraryCloseSearch;

  /// No description provided for @libraryErrorFallback.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get libraryErrorFallback;

  /// No description provided for @librarySectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get librarySectionTitle;

  /// No description provided for @libraryFabImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get libraryFabImport;

  /// No description provided for @librarySwitchToListView.
  ///
  /// In en, this message translates to:
  /// **'Switch to list view'**
  String get librarySwitchToListView;

  /// No description provided for @librarySwitchToGridView.
  ///
  /// In en, this message translates to:
  /// **'Switch to grid view'**
  String get librarySwitchToGridView;

  /// No description provided for @librarySortRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get librarySortRecent;

  /// No description provided for @librarySortTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get librarySortTitle;

  /// No description provided for @librarySortAuthor.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get librarySortAuthor;

  /// No description provided for @libraryBookInfo.
  ///
  /// In en, this message translates to:
  /// **'Book Info'**
  String get libraryBookInfo;

  /// No description provided for @libraryInfoChapters.
  ///
  /// In en, this message translates to:
  /// **'Chapters'**
  String get libraryInfoChapters;

  /// No description provided for @libraryInfoPublisher.
  ///
  /// In en, this message translates to:
  /// **'Publisher'**
  String get libraryInfoPublisher;

  /// No description provided for @libraryInfoLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get libraryInfoLanguage;

  /// No description provided for @libraryInfoIsbn.
  ///
  /// In en, this message translates to:
  /// **'ISBN'**
  String get libraryInfoIsbn;

  /// No description provided for @libraryDeleteBookTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Book'**
  String get libraryDeleteBookTitle;

  /// No description provided for @libraryDeleteBookMessage.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{title}\" from your library?'**
  String libraryDeleteBookMessage({required Object title});

  /// No description provided for @libraryEmptySearchTitle.
  ///
  /// In en, this message translates to:
  /// **'No books found'**
  String get libraryEmptySearchTitle;

  /// No description provided for @libraryEmptySearchBody.
  ///
  /// In en, this message translates to:
  /// **'Try a different search term'**
  String get libraryEmptySearchBody;

  /// No description provided for @libraryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your library awaits'**
  String get libraryEmptyTitle;

  /// No description provided for @libraryEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Import your first book or comic to start reading'**
  String get libraryEmptyBody;

  /// No description provided for @libraryContinueReading.
  ///
  /// In en, this message translates to:
  /// **'Continue Reading'**
  String get libraryContinueReading;

  /// No description provided for @libraryProgressRead.
  ///
  /// In en, this message translates to:
  /// **'{progress}% read'**
  String libraryProgressRead({required int progress});

  /// No description provided for @searchTitle.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get searchTitle;

  /// No description provided for @searchCatalogOpenLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Open Library'**
  String get searchCatalogOpenLibraryTitle;

  /// No description provided for @searchCatalogProjectGutenbergTitle.
  ///
  /// In en, this message translates to:
  /// **'Project Gutenberg'**
  String get searchCatalogProjectGutenbergTitle;

  /// No description provided for @searchManageCatalogs.
  ///
  /// In en, this message translates to:
  /// **'Manage catalogs'**
  String get searchManageCatalogs;

  /// No description provided for @searchCatalogLabel.
  ///
  /// In en, this message translates to:
  /// **'Catalog'**
  String get searchCatalogLabel;

  /// No description provided for @searchGenericCatalogName.
  ///
  /// In en, this message translates to:
  /// **'catalog'**
  String get searchGenericCatalogName;

  /// No description provided for @searchPromptGenericCatalogName.
  ///
  /// In en, this message translates to:
  /// **'a catalog'**
  String get searchPromptGenericCatalogName;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search {catalogTitle}...'**
  String searchHint({required Object catalogTitle});

  /// No description provided for @searchInitialPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Search {catalogTitle}'**
  String searchInitialPromptTitle({required Object catalogTitle});

  /// No description provided for @searchInitialPromptBody.
  ///
  /// In en, this message translates to:
  /// **'Find downloadable books and add them straight to your library.'**
  String get searchInitialPromptBody;

  /// No description provided for @searchErrorFallback.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get searchErrorFallback;

  /// No description provided for @searchErrorInvalidCatalogInput.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid catalog name and URL.'**
  String get searchErrorInvalidCatalogInput;

  /// No description provided for @searchErrorDuplicateCatalog.
  ///
  /// In en, this message translates to:
  /// **'That catalog has already been added.'**
  String get searchErrorDuplicateCatalog;

  /// No description provided for @searchErrorDownloadRedirected.
  ///
  /// In en, this message translates to:
  /// **'The download redirected too many times.'**
  String get searchErrorDownloadRedirected;

  /// No description provided for @searchErrorDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'The download failed.'**
  String get searchErrorDownloadFailed;

  /// No description provided for @searchErrorCatalogNotSearchable.
  ///
  /// In en, this message translates to:
  /// **'This catalog does not provide a searchable OPDS feed.'**
  String get searchErrorCatalogNotSearchable;

  /// No description provided for @searchErrorSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'The catalog search failed.'**
  String get searchErrorSearchFailed;

  /// No description provided for @searchErrorCatalogLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load that catalog.'**
  String get searchErrorCatalogLoadFailed;

  /// No description provided for @searchErrorCatalogMissingSearchLink.
  ///
  /// In en, this message translates to:
  /// **'This catalog does not expose a usable search link.'**
  String get searchErrorCatalogMissingSearchLink;

  /// No description provided for @searchErrorCatalogSearchDescriptionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the catalog search description.'**
  String get searchErrorCatalogSearchDescriptionFailed;

  /// No description provided for @searchErrorCatalogSearchTemplateMissing.
  ///
  /// In en, this message translates to:
  /// **'Could not find a usable search template for this catalog.'**
  String get searchErrorCatalogSearchTemplateMissing;

  /// No description provided for @searchEmptyResults.
  ///
  /// In en, this message translates to:
  /// **'No downloadable books found'**
  String get searchEmptyResults;

  /// No description provided for @searchNoCatalogSelected.
  ///
  /// In en, this message translates to:
  /// **'Choose a catalog to start searching'**
  String get searchNoCatalogSelected;

  /// No description provided for @searchBookAdded.
  ///
  /// In en, this message translates to:
  /// **'{title} added to your library'**
  String searchBookAdded({required Object title});

  /// No description provided for @searchDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed: {error}'**
  String searchDownloadFailed({required Object error});

  /// No description provided for @searchCatalogsTitle.
  ///
  /// In en, this message translates to:
  /// **'Catalogs'**
  String get searchCatalogsTitle;

  /// No description provided for @searchCatalogsBody.
  ///
  /// In en, this message translates to:
  /// **'Built-ins are ready to use. Add your own OPDS catalogs too.'**
  String get searchCatalogsBody;

  /// No description provided for @searchRemoveCatalog.
  ///
  /// In en, this message translates to:
  /// **'Remove catalog'**
  String get searchRemoveCatalog;

  /// No description provided for @searchNoCustomCatalogs.
  ///
  /// In en, this message translates to:
  /// **'No custom catalogs yet.'**
  String get searchNoCustomCatalogs;

  /// No description provided for @searchAddCustomCatalog.
  ///
  /// In en, this message translates to:
  /// **'Add Custom Catalog'**
  String get searchAddCustomCatalog;

  /// No description provided for @searchAddCustomCatalogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Custom Catalog'**
  String get searchAddCustomCatalogTitle;

  /// No description provided for @searchCatalogNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Catalog name'**
  String get searchCatalogNameLabel;

  /// No description provided for @searchCatalogUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Catalog URL'**
  String get searchCatalogUrlLabel;

  /// No description provided for @searchCouldNotAddCatalog.
  ///
  /// In en, this message translates to:
  /// **'Could not add catalog: {error}'**
  String searchCouldNotAddCatalog({required Object error});

  /// No description provided for @searchCatalogTypeCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get searchCatalogTypeCustom;

  /// No description provided for @searchOpenSourcePage.
  ///
  /// In en, this message translates to:
  /// **'Open source page'**
  String get searchOpenSourcePage;

  /// No description provided for @searchDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get searchDownloading;

  /// No description provided for @searchDownloadFormat.
  ///
  /// In en, this message translates to:
  /// **'Download {formatName}'**
  String searchDownloadFormat({required Object formatName});

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsSectionAppearance;

  /// No description provided for @settingsLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get settingsLanguageTitle;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageSystemSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Follow device language'**
  String get settingsLanguageSystemSubtitle;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguageArabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get settingsLanguageArabic;

  /// No description provided for @settingsSectionBattery.
  ///
  /// In en, this message translates to:
  /// **'Battery'**
  String get settingsSectionBattery;

  /// No description provided for @settingsSectionSync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get settingsSectionSync;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsSectionAbout;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeSystemSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Follow device theme'**
  String get settingsThemeSystemSubtitle;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsPowerSaverTitle.
  ///
  /// In en, this message translates to:
  /// **'Power Saver'**
  String get settingsPowerSaverTitle;

  /// No description provided for @settingsPowerSaverSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reduce animations and scroll updates'**
  String get settingsPowerSaverSubtitle;

  /// No description provided for @settingsSyncServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync Server'**
  String get settingsSyncServerTitle;

  /// No description provided for @settingsSyncConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get settingsSyncConnected;

  /// No description provided for @settingsSyncNotLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Not logged in'**
  String get settingsSyncNotLoggedIn;

  /// No description provided for @settingsSyncNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get settingsSyncNotConfigured;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String settingsVersion({required Object version});

  /// No description provided for @settingsVersionValue.
  ///
  /// In en, this message translates to:
  /// **'{version}'**
  String settingsVersionValue({required Object version});

  /// No description provided for @settingsVersionValueWithBuild.
  ///
  /// In en, this message translates to:
  /// **'{version} ({build})'**
  String settingsVersionValueWithBuild({
    required Object version,
    required Object build,
  });

  /// No description provided for @settingsVersionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Version unavailable'**
  String get settingsVersionUnavailable;

  /// No description provided for @settingsVersionLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading version...'**
  String get settingsVersionLoading;

  /// No description provided for @settingsOpenSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Open Source'**
  String get settingsOpenSourceTitle;

  /// No description provided for @settingsOpenSourceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Flutter + PocketBase'**
  String get settingsOpenSourceSubtitle;

  /// No description provided for @syncSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync Settings'**
  String get syncSettingsTitle;

  /// No description provided for @syncStatusDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get syncStatusDisconnected;

  /// No description provided for @syncStatusConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get syncStatusConnecting;

  /// No description provided for @syncStatusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get syncStatusConnected;

  /// No description provided for @syncStatusSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get syncStatusSyncing;

  /// No description provided for @syncStatusError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get syncStatusError;

  /// No description provided for @syncLastSynced.
  ///
  /// In en, this message translates to:
  /// **'Last synced: {value}'**
  String syncLastSynced({required Object value});

  /// No description provided for @syncNeverSynced.
  ///
  /// In en, this message translates to:
  /// **'Never synced'**
  String get syncNeverSynced;

  /// No description provided for @syncServerSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get syncServerSectionTitle;

  /// No description provided for @syncServerUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get syncServerUrlLabel;

  /// No description provided for @syncServerUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://your-server.com'**
  String get syncServerUrlHint;

  /// No description provided for @syncConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get syncConnect;

  /// No description provided for @syncCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get syncCreateAccount;

  /// No description provided for @syncLogin.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get syncLogin;

  /// No description provided for @syncHaveAccountLogin.
  ///
  /// In en, this message translates to:
  /// **'Have an account? Login'**
  String get syncHaveAccountLogin;

  /// No description provided for @syncNewRegister.
  ///
  /// In en, this message translates to:
  /// **'New? Register'**
  String get syncNewRegister;

  /// No description provided for @syncEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get syncEmailLabel;

  /// No description provided for @syncPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get syncPasswordLabel;

  /// No description provided for @syncRegister.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get syncRegister;

  /// No description provided for @syncSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get syncSectionTitle;

  /// No description provided for @syncAutoSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Automatic sync'**
  String get syncAutoSyncTitle;

  /// No description provided for @syncAutoSyncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sync in the background on startup, foreground, and after changes.'**
  String get syncAutoSyncSubtitle;

  /// No description provided for @syncSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync Now'**
  String get syncSyncNow;

  /// No description provided for @syncAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get syncAccountTitle;

  /// No description provided for @syncLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get syncLogout;

  /// No description provided for @syncRecentErrors.
  ///
  /// In en, this message translates to:
  /// **'Recent Sync Errors'**
  String get syncRecentErrors;

  /// No description provided for @syncFailedToConnect.
  ///
  /// In en, this message translates to:
  /// **'Failed to connect: {error}'**
  String syncFailedToConnect({required Object error});

  /// No description provided for @syncRegistrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed: {error}'**
  String syncRegistrationFailed({required Object error});

  /// No description provided for @syncLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed: {error}'**
  String syncLoginFailed({required Object error});

  /// No description provided for @syncAuthExpired.
  ///
  /// In en, this message translates to:
  /// **'Authentication expired. Please log in again.'**
  String get syncAuthExpired;

  /// No description provided for @syncPartialFailure.
  ///
  /// In en, this message translates to:
  /// **'Sync partially failed: {collections}'**
  String syncPartialFailure({required Object collections});

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed: {error}'**
  String syncFailed({required Object error});

  /// No description provided for @syncFailedToConnectGeneric.
  ///
  /// In en, this message translates to:
  /// **'Failed to connect to the server.'**
  String get syncFailedToConnectGeneric;

  /// No description provided for @syncRegistrationFailedGeneric.
  ///
  /// In en, this message translates to:
  /// **'Registration failed. Please try again.'**
  String get syncRegistrationFailedGeneric;

  /// No description provided for @syncLoginFailedGeneric.
  ///
  /// In en, this message translates to:
  /// **'Login failed. Please check your credentials and try again.'**
  String get syncLoginFailedGeneric;

  /// No description provided for @syncFailedGeneric.
  ///
  /// In en, this message translates to:
  /// **'Sync failed. Please try again.'**
  String get syncFailedGeneric;

  /// No description provided for @syncErrorLogGenericMessage.
  ///
  /// In en, this message translates to:
  /// **'This data could not be synced.'**
  String get syncErrorLogGenericMessage;

  /// No description provided for @syncCollectionBooks.
  ///
  /// In en, this message translates to:
  /// **'Books'**
  String get syncCollectionBooks;

  /// No description provided for @syncCollectionReadingProgress.
  ///
  /// In en, this message translates to:
  /// **'Reading progress'**
  String get syncCollectionReadingProgress;

  /// No description provided for @syncCollectionBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get syncCollectionBookmarks;

  /// No description provided for @syncCollectionHighlights.
  ///
  /// In en, this message translates to:
  /// **'Highlights'**
  String get syncCollectionHighlights;

  /// No description provided for @syncCollectionShelves.
  ///
  /// In en, this message translates to:
  /// **'Shelves'**
  String get syncCollectionShelves;

  /// No description provided for @syncCollectionShelfBooks.
  ///
  /// In en, this message translates to:
  /// **'Shelf books'**
  String get syncCollectionShelfBooks;

  /// No description provided for @syncCollectionReadingSessions.
  ///
  /// In en, this message translates to:
  /// **'Reading sessions'**
  String get syncCollectionReadingSessions;

  /// No description provided for @syncCollectionReadingGoals.
  ///
  /// In en, this message translates to:
  /// **'Reading goals'**
  String get syncCollectionReadingGoals;

  /// No description provided for @syncCollectionUnknown.
  ///
  /// In en, this message translates to:
  /// **'Other data'**
  String get syncCollectionUnknown;

  /// No description provided for @collectionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Shelves'**
  String get collectionsTitle;

  /// No description provided for @collectionsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No shelves yet'**
  String get collectionsEmptyTitle;

  /// No description provided for @collectionsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Organize your books into collections'**
  String get collectionsEmptyBody;

  /// No description provided for @collectionsCreateShelf.
  ///
  /// In en, this message translates to:
  /// **'Create Shelf'**
  String get collectionsCreateShelf;

  /// No description provided for @collectionsNewShelfTitle.
  ///
  /// In en, this message translates to:
  /// **'New Shelf'**
  String get collectionsNewShelfTitle;

  /// No description provided for @collectionsNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get collectionsNameLabel;

  /// No description provided for @collectionsNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Favorites, To Read...'**
  String get collectionsNameHint;

  /// No description provided for @collectionsDescriptionOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get collectionsDescriptionOptionalLabel;

  /// No description provided for @collectionsDeleteShelfTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Shelf'**
  String get collectionsDeleteShelfTitle;

  /// No description provided for @collectionsDeleteShelfMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? Your books won\'\'t be removed from the library.'**
  String collectionsDeleteShelfMessage({required Object name});

  /// No description provided for @collectionDetailAddBooksTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add books'**
  String get collectionDetailAddBooksTooltip;

  /// No description provided for @collectionDetailEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No books in this collection'**
  String get collectionDetailEmptyTitle;

  /// No description provided for @collectionDetailAddBooks.
  ///
  /// In en, this message translates to:
  /// **'Add Books'**
  String get collectionDetailAddBooks;

  /// No description provided for @collectionDetailRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove from Collection'**
  String get collectionDetailRemoveTitle;

  /// No description provided for @collectionDetailRemoveMessage.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{title}\" from \"{collectionName}\"?'**
  String collectionDetailRemoveMessage({
    required Object title,
    required Object collectionName,
  });

  /// No description provided for @collectionDetailAllBooksAlreadyAdded.
  ///
  /// In en, this message translates to:
  /// **'All books are already in this collection'**
  String get collectionDetailAllBooksAlreadyAdded;

  /// No description provided for @collectionDetailAddBooksTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Books'**
  String get collectionDetailAddBooksTitle;

  /// No description provided for @collectionDetailAddedBook.
  ///
  /// In en, this message translates to:
  /// **'Added \"{title}\"'**
  String collectionDetailAddedBook({required Object title});

  /// No description provided for @readerAnnotations.
  ///
  /// In en, this message translates to:
  /// **'Annotations'**
  String get readerAnnotations;

  /// No description provided for @readerHighlightsTab.
  ///
  /// In en, this message translates to:
  /// **'Highlights ({count})'**
  String readerHighlightsTab({required int count});

  /// No description provided for @readerBookmarksTab.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks ({count})'**
  String readerBookmarksTab({required int count});

  /// No description provided for @readerNoHighlightsYet.
  ///
  /// In en, this message translates to:
  /// **'No highlights yet'**
  String get readerNoHighlightsYet;

  /// No description provided for @readerNoHighlightsHint.
  ///
  /// In en, this message translates to:
  /// **'Select text while reading to highlight it'**
  String get readerNoHighlightsHint;

  /// No description provided for @readerNoBookmarksYet.
  ///
  /// In en, this message translates to:
  /// **'No bookmarks yet'**
  String get readerNoBookmarksYet;

  /// No description provided for @readerQuotedSelection.
  ///
  /// In en, this message translates to:
  /// **'\"{text}\"'**
  String readerQuotedSelection({required Object text});

  /// No description provided for @readerChapterLabel.
  ///
  /// In en, this message translates to:
  /// **'Chapter {chapterNumber}'**
  String readerChapterLabel({required int chapterNumber});

  /// No description provided for @readerDeleteHighlightTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Highlight'**
  String get readerDeleteHighlightTitle;

  /// No description provided for @readerDeleteHighlightMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this highlight?'**
  String get readerDeleteHighlightMessage;

  /// No description provided for @readerEditNote.
  ///
  /// In en, this message translates to:
  /// **'Edit Note'**
  String get readerEditNote;

  /// No description provided for @readerAddNote.
  ///
  /// In en, this message translates to:
  /// **'Add Note'**
  String get readerAddNote;

  /// No description provided for @readerNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your note...'**
  String get readerNoteHint;

  /// No description provided for @readerHighlight.
  ///
  /// In en, this message translates to:
  /// **'Highlight'**
  String get readerHighlight;

  /// No description provided for @readerHighlightWithNote.
  ///
  /// In en, this message translates to:
  /// **'Highlight with Note'**
  String get readerHighlightWithNote;

  /// No description provided for @readerCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get readerCopiedToClipboard;

  /// No description provided for @readerErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Reader Error'**
  String get readerErrorTitle;

  /// No description provided for @readerLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load this book: {error}'**
  String readerLoadFailed({required Object error});

  /// No description provided for @readerUnknownError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong while opening this book.'**
  String get readerUnknownError;

  /// No description provided for @readerExitZenMode.
  ///
  /// In en, this message translates to:
  /// **'Exit Zen Mode'**
  String get readerExitZenMode;

  /// No description provided for @readerZenMode.
  ///
  /// In en, this message translates to:
  /// **'Zen Mode'**
  String get readerZenMode;

  /// No description provided for @readerTableOfContents.
  ///
  /// In en, this message translates to:
  /// **'Table of Contents'**
  String get readerTableOfContents;

  /// No description provided for @readerSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get readerSettings;

  /// No description provided for @readerBookmark.
  ///
  /// In en, this message translates to:
  /// **'Bookmark'**
  String get readerBookmark;

  /// No description provided for @readerTypography.
  ///
  /// In en, this message translates to:
  /// **'Typography'**
  String get readerTypography;

  /// No description provided for @readerReadingDirection.
  ///
  /// In en, this message translates to:
  /// **'Reading direction'**
  String get readerReadingDirection;

  /// No description provided for @readerDirectionAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get readerDirectionAuto;

  /// No description provided for @readerDirectionLeftToRight.
  ///
  /// In en, this message translates to:
  /// **'Left to right'**
  String get readerDirectionLeftToRight;

  /// No description provided for @readerDirectionRightToLeft.
  ///
  /// In en, this message translates to:
  /// **'Right to left'**
  String get readerDirectionRightToLeft;

  /// No description provided for @readerTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get readerTheme;

  /// No description provided for @readerContents.
  ///
  /// In en, this message translates to:
  /// **'Contents'**
  String get readerContents;

  /// No description provided for @readerPageOf.
  ///
  /// In en, this message translates to:
  /// **'Page {currentPage} of {totalPages}'**
  String readerPageOf({required int currentPage, required int totalPages});

  /// No description provided for @readerChapterProgress.
  ///
  /// In en, this message translates to:
  /// **'{chapterTitle} · {percent}%'**
  String readerChapterProgress({
    required Object chapterTitle,
    required int percent,
  });

  /// No description provided for @readerFontFamilySystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get readerFontFamilySystem;

  /// No description provided for @readerFontFamilySerif.
  ///
  /// In en, this message translates to:
  /// **'Serif'**
  String get readerFontFamilySerif;

  /// No description provided for @readerFontFamilySansSerif.
  ///
  /// In en, this message translates to:
  /// **'Sans Serif'**
  String get readerFontFamilySansSerif;

  /// No description provided for @readerFontFamilyMonospace.
  ///
  /// In en, this message translates to:
  /// **'Monospace'**
  String get readerFontFamilyMonospace;

  /// No description provided for @statsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reading Stats'**
  String get statsTitle;

  /// No description provided for @statsErrorFallback.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get statsErrorFallback;

  /// No description provided for @statsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load stats: {error}'**
  String statsLoadFailed({required Object error});

  /// No description provided for @statsTotalTime.
  ///
  /// In en, this message translates to:
  /// **'Total Time'**
  String get statsTotalTime;

  /// No description provided for @statsBooksStartedThisYear.
  ///
  /// In en, this message translates to:
  /// **'Books Started This Year'**
  String get statsBooksStartedThisYear;

  /// No description provided for @statsSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get statsSessions;

  /// No description provided for @statsRecentSessions.
  ///
  /// In en, this message translates to:
  /// **'Recent Sessions'**
  String get statsRecentSessions;

  /// No description provided for @statsCurrentStreak.
  ///
  /// In en, this message translates to:
  /// **'Current Streak'**
  String get statsCurrentStreak;

  /// No description provided for @statsLongestStreak.
  ///
  /// In en, this message translates to:
  /// **'Longest Streak'**
  String get statsLongestStreak;

  /// No description provided for @statsReadingActivity.
  ///
  /// In en, this message translates to:
  /// **'Reading Activity'**
  String get statsReadingActivity;

  /// No description provided for @statsHeatmapLess.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get statsHeatmapLess;

  /// No description provided for @statsHeatmapMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get statsHeatmapMore;

  /// No description provided for @statsHeatmapNoReading.
  ///
  /// In en, this message translates to:
  /// **'{date}: No reading'**
  String statsHeatmapNoReading({required Object date});

  /// No description provided for @statsHeatmapMinutes.
  ///
  /// In en, this message translates to:
  /// **'{date}: {minutes} min'**
  String statsHeatmapMinutes({required Object date, required int minutes});

  /// No description provided for @statsDurationHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String statsDurationHoursMinutes({required int hours, required int minutes});

  /// No description provided for @statsDurationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String statsDurationMinutes({required int minutes});
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
