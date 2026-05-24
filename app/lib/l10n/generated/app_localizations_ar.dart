// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'Moku';

  @override
  String get bookUnknownTitle => 'بلا عنوان';

  @override
  String get bookUnknownAuthor => 'مؤلف مجهول';

  @override
  String get formatEpub => 'EPUB';

  @override
  String get formatPdf => 'PDF';

  @override
  String get formatText => 'نص';

  @override
  String get formatComicCbz => 'قصص مصوّرة (CBZ)';

  @override
  String get formatHtml => 'HTML';

  @override
  String get navLibrary => 'المكتبة';

  @override
  String get navDiscover => 'اكتشف';

  @override
  String get navShelves => 'الرفوف';

  @override
  String get navStats => 'الإحصاءات';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get commonDelete => 'حذف';

  @override
  String get commonCreate => 'إنشاء';

  @override
  String get commonAdd => 'إضافة';

  @override
  String get commonRemove => 'إزالة';

  @override
  String get commonClear => 'مسح';

  @override
  String get commonSave => 'حفظ';

  @override
  String get commonCopy => 'نسخ';

  @override
  String get commonTryAgain => 'حاوِل مجددًا';

  @override
  String get commonImportFiles => 'استيراد ملفات';

  @override
  String get onboardingSkip => 'تخطي';

  @override
  String get onboardingWelcomeTitle => 'مرحبًا بك في Moku';

  @override
  String get onboardingWelcomeSubtitle => 'رفيقك الهادئ للقراءة';

  @override
  String get onboardingWelcomeBody =>
      'استورد ملفات EPUB وPDF وTXT وCBZ وHTML، وتابع تقدّمك، واقرأ من دون تشتيت.';

  @override
  String get onboardingGetStarted => 'ابدأ';

  @override
  String get onboardingImportTitle => 'استيراد كتبك';

  @override
  String get onboardingImportBody =>
      'أضف ملفات EPUB وPDF وTXT وCBZ وHTML من جهازك.\nتظل مكتبتك على جهازك وتعمل بالكامل من دون اتصال بالإنترنت.';

  @override
  String get onboardingImportLater => 'لاحقًا';

  @override
  String get onboardingSyncTitle => 'المزامنة بين الأجهزة';

  @override
  String get onboardingSyncOfflineBody =>
      'يعمل Moku بالكامل من دون اتصال بالإنترنت، ولا يحتاج إلى حساب.';

  @override
  String get onboardingSyncServerBody =>
      'هل تريد مزامنة كتبك وتقدّمك بين الأجهزة؟\nاربط خادم PocketBase الخاص بك من الإعدادات.';

  @override
  String get onboardingStartReading => 'ابدأ القراءة';

  @override
  String get librarySearchHint => 'ابحث في المكتبة…';

  @override
  String get librarySearchAction => 'ابحث في المكتبة';

  @override
  String get libraryCloseSearch => 'إغلاق البحث';

  @override
  String get libraryErrorFallback => 'حدث خطأ ما';

  @override
  String get librarySectionTitle => 'المكتبة';

  @override
  String get libraryFabImport => 'استيراد';

  @override
  String get librarySwitchToListView => 'التبديل إلى عرض القائمة';

  @override
  String get librarySwitchToGridView => 'التبديل إلى عرض الشبكة';

  @override
  String get librarySortRecent => 'الأحدث';

  @override
  String get librarySortTitle => 'العنوان';

  @override
  String get librarySortAuthor => 'المؤلف';

  @override
  String get libraryBookInfo => 'معلومات الكتاب';

  @override
  String get libraryInfoChapters => 'الفصول';

  @override
  String get libraryInfoPublisher => 'الناشر';

  @override
  String get libraryInfoLanguage => 'اللغة';

  @override
  String get libraryInfoIsbn => 'ISBN';

  @override
  String get libraryDeleteBookTitle => 'حذف الكتاب';

  @override
  String libraryDeleteBookMessage({required Object title}) {
    return 'إزالة «$title» من مكتبتك؟';
  }

  @override
  String get libraryEmptySearchTitle => 'لم يتم العثور على كتب';

  @override
  String get libraryEmptySearchBody => 'جرّب كلمة بحث مختلفة';

  @override
  String get libraryEmptyTitle => 'مكتبتك بانتظارك';

  @override
  String get libraryEmptyBody => 'استورد أول كتاب أو قصة مصوّرة لتبدأ القراءة';

  @override
  String get libraryContinueReading => 'تابع القراءة';

  @override
  String libraryProgressRead({required int progress}) {
    return 'تمت قراءة $progress٪';
  }

  @override
  String get searchTitle => 'اكتشف';

  @override
  String get searchCatalogOpenLibraryTitle => 'Open Library';

  @override
  String get searchCatalogProjectGutenbergTitle => 'Project Gutenberg';

  @override
  String get searchManageCatalogs => 'إدارة الفهارس';

  @override
  String get searchCatalogLabel => 'الفهرس';

  @override
  String get searchGenericCatalogName => 'الفهرس';

  @override
  String get searchPromptGenericCatalogName => 'أحد الفهارس';

  @override
  String searchHint({required Object catalogTitle}) {
    return 'ابحث في $catalogTitle…';
  }

  @override
  String searchInitialPromptTitle({required Object catalogTitle}) {
    return 'ابحث في $catalogTitle';
  }

  @override
  String get searchInitialPromptBody =>
      'ابحث عن كتب قابلة للتنزيل وأضفها مباشرة إلى مكتبتك.';

  @override
  String get searchErrorFallback => 'حدث خطأ ما.';

  @override
  String get searchErrorInvalidCatalogInput => 'أدخل اسم فهرس ورابطًا صالحين.';

  @override
  String get searchErrorDuplicateCatalog => 'هذا الفهرس مضاف بالفعل.';

  @override
  String get searchErrorDownloadRedirected =>
      'أُعيد توجيه التنزيل مرات كثيرة جدًا.';

  @override
  String get searchErrorDownloadFailed => 'تعذّر التنزيل.';

  @override
  String get searchErrorCatalogNotSearchable =>
      'هذا الفهرس لا يوفّر موجز OPDS قابلًا للبحث.';

  @override
  String get searchErrorSearchFailed => 'تعذّر البحث في الفهرس.';

  @override
  String get searchErrorCatalogLoadFailed => 'تعذّر تحميل هذا الفهرس.';

  @override
  String get searchErrorCatalogMissingSearchLink =>
      'لا يوفّر هذا الفهرس رابط بحث صالحًا.';

  @override
  String get searchErrorCatalogSearchDescriptionFailed =>
      'تعذّر تحميل وصف البحث لهذا الفهرس.';

  @override
  String get searchErrorCatalogSearchTemplateMissing =>
      'تعذّر العثور على قالب بحث صالح لهذا الفهرس.';

  @override
  String get searchEmptyResults => 'لم نعثر على كتب قابلة للتنزيل';

  @override
  String get searchNoCatalogSelected => 'اختر فهرسًا لبدء البحث';

  @override
  String searchBookAdded({required Object title}) {
    return 'أُضيف $title إلى مكتبتك';
  }

  @override
  String searchDownloadFailed({required Object error}) {
    return 'تعذّر التنزيل: $error';
  }

  @override
  String get searchCatalogsTitle => 'الفهارس';

  @override
  String get searchCatalogsBody =>
      'الفهارس المضمّنة جاهزة للاستخدام. ويمكنك أيضًا إضافة فهارس OPDS الخاصة بك.';

  @override
  String get searchRemoveCatalog => 'إزالة الفهرس';

  @override
  String get searchNoCustomCatalogs => 'لا توجد فهارس مخصّصة حتى الآن.';

  @override
  String get searchAddCustomCatalog => 'إضافة فهرس مخصّص';

  @override
  String get searchAddCustomCatalogTitle => 'إضافة فهرس مخصّص';

  @override
  String get searchCatalogNameLabel => 'اسم الفهرس';

  @override
  String get searchCatalogUrlLabel => 'رابط الفهرس';

  @override
  String searchCouldNotAddCatalog({required Object error}) {
    return 'تعذّرت إضافة الفهرس: $error';
  }

  @override
  String get searchCatalogTypeCustom => 'مخصّص';

  @override
  String get searchOpenSourcePage => 'صفحة المصدر';

  @override
  String get searchDownloading => 'جارٍ التنزيل…';

  @override
  String searchDownloadFormat({required Object formatName}) {
    return 'تنزيل $formatName';
  }

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get settingsSectionAppearance => 'المظهر';

  @override
  String get settingsLanguageTitle => 'لغة التطبيق';

  @override
  String get settingsLanguageSystem => 'النظام';

  @override
  String get settingsLanguageSystemSubtitle => 'اتّباع لغة الجهاز';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageArabic => 'العربية';

  @override
  String get settingsSectionBattery => 'البطارية';

  @override
  String get settingsSectionSync => 'المزامنة';

  @override
  String get settingsSectionAbout => 'حول التطبيق';

  @override
  String get settingsThemeSystem => 'النظام';

  @override
  String get settingsThemeSystemSubtitle => 'اتّباع مظهر الجهاز';

  @override
  String get settingsThemeLight => 'فاتح';

  @override
  String get settingsThemeDark => 'داكن';

  @override
  String get settingsPowerSaverTitle => 'توفير الطاقة';

  @override
  String get settingsPowerSaverSubtitle =>
      'تقليل الرسوم المتحركة وتحديثات التمرير';

  @override
  String get settingsSyncServerTitle => 'خادم المزامنة';

  @override
  String get settingsSyncConnected => 'متصل';

  @override
  String get settingsSyncNotLoggedIn => 'غير مسجّل الدخول';

  @override
  String get settingsSyncNotConfigured => 'غير مهيّأ';

  @override
  String settingsVersion({required Object version}) {
    return 'الإصدار $version';
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
  String get settingsVersionUnavailable => 'الإصدار غير متاح';

  @override
  String get settingsVersionLoading => 'جارٍ تحميل الإصدار…';

  @override
  String get settingsOpenSourceTitle => 'مفتوح المصدر';

  @override
  String get settingsOpenSourceSubtitle => 'Flutter + PocketBase';

  @override
  String get syncSettingsTitle => 'إعدادات المزامنة';

  @override
  String get syncStatusDisconnected => 'غير متصل';

  @override
  String get syncStatusConnecting => 'جارٍ الاتصال…';

  @override
  String get syncStatusConnected => 'متصل';

  @override
  String get syncStatusSyncing => 'جارٍ المزامنة…';

  @override
  String get syncStatusError => 'خطأ';

  @override
  String syncLastSynced({required Object value}) {
    return 'آخر مزامنة: $value';
  }

  @override
  String get syncNeverSynced => 'لم تتم أي مزامنة بعد';

  @override
  String get syncServerSectionTitle => 'الخادم';

  @override
  String get syncServerUrlLabel => 'رابط الخادم';

  @override
  String get syncServerUrlHint => 'https://your-server.com';

  @override
  String get syncConnect => 'اتصل';

  @override
  String get syncCreateAccount => 'إنشاء حساب';

  @override
  String get syncLogin => 'تسجيل الدخول';

  @override
  String get syncHaveAccountLogin => 'لديك حساب؟ سجّل الدخول';

  @override
  String get syncNewRegister => 'مستخدم جديد؟ أنشئ حسابًا';

  @override
  String get syncEmailLabel => 'البريد الإلكتروني';

  @override
  String get syncPasswordLabel => 'كلمة المرور';

  @override
  String get syncRegister => 'إنشاء حساب';

  @override
  String get syncSectionTitle => 'المزامنة';

  @override
  String get syncAutoSyncTitle => 'المزامنة التلقائية';

  @override
  String get syncAutoSyncSubtitle =>
      'تُجرى المزامنة في الخلفية عند التشغيل، وعند العودة إلى التطبيق، وبعد إجراء تغييرات.';

  @override
  String get syncSyncNow => 'زامِن الآن';

  @override
  String get syncAccountTitle => 'الحساب';

  @override
  String get syncLogout => 'تسجيل الخروج';

  @override
  String get syncRecentErrors => 'أخطاء المزامنة الأخيرة';

  @override
  String syncFailedToConnect({required Object error}) {
    return 'تعذّر الاتصال: $error';
  }

  @override
  String syncRegistrationFailed({required Object error}) {
    return 'تعذّر إنشاء الحساب: $error';
  }

  @override
  String syncLoginFailed({required Object error}) {
    return 'تعذّر تسجيل الدخول: $error';
  }

  @override
  String get syncAuthExpired =>
      'انتهت صلاحية جلسة الدخول. يُرجى تسجيل الدخول مرة أخرى.';

  @override
  String syncPartialFailure({required Object collections}) {
    return 'تعذّرت مزامنة بعض البيانات: $collections';
  }

  @override
  String syncFailed({required Object error}) {
    return 'تعذّرت المزامنة: $error';
  }

  @override
  String get syncFailedToConnectGeneric => 'تعذّر الاتصال بالخادم.';

  @override
  String get syncRegistrationFailedGeneric =>
      'تعذّر إنشاء الحساب. يُرجى المحاولة مرة أخرى.';

  @override
  String get syncLoginFailedGeneric =>
      'تعذّر تسجيل الدخول. تحقّق من بياناتك ثم حاوِل مرة أخرى.';

  @override
  String get syncFailedGeneric => 'تعذّرت المزامنة. يُرجى المحاولة مرة أخرى.';

  @override
  String get syncErrorLogGenericMessage => 'تعذّرت مزامنة هذه البيانات.';

  @override
  String get syncCollectionBooks => 'الكتب';

  @override
  String get syncCollectionReadingProgress => 'تقدّم القراءة';

  @override
  String get syncCollectionBookmarks => 'الإشارات المرجعية';

  @override
  String get syncCollectionHighlights => 'التمييزات';

  @override
  String get syncCollectionShelves => 'الرفوف';

  @override
  String get syncCollectionShelfBooks => 'كتب الرفوف';

  @override
  String get syncCollectionReadingSessions => 'جلسات القراءة';

  @override
  String get syncCollectionReadingGoals => 'أهداف القراءة';

  @override
  String get syncCollectionUnknown => 'بيانات أخرى';

  @override
  String get collectionsTitle => 'الرفوف';

  @override
  String get collectionsEmptyTitle => 'لا توجد رفوف بعد';

  @override
  String get collectionsEmptyBody => 'نظّم كتبك في رفوف';

  @override
  String get collectionsCreateShelf => 'أنشئ رفًا';

  @override
  String get collectionsNewShelfTitle => 'رف جديد';

  @override
  String get collectionsNameLabel => 'الاسم';

  @override
  String get collectionsNameHint => 'مثل: المفضلة، للقراءة لاحقًا…';

  @override
  String get collectionsDescriptionOptionalLabel => 'الوصف (اختياري)';

  @override
  String get collectionsDeleteShelfTitle => 'حذف الرف';

  @override
  String collectionsDeleteShelfMessage({required Object name}) {
    return 'حذف «$name»؟ لن تُزال كتبك من المكتبة.';
  }

  @override
  String get collectionDetailAddBooksTooltip => 'أضف كتبًا';

  @override
  String get collectionDetailEmptyTitle => 'لا توجد كتب في هذا الرف';

  @override
  String get collectionDetailAddBooks => 'أضف كتبًا';

  @override
  String get collectionDetailRemoveTitle => 'إزالة من الرف';

  @override
  String collectionDetailRemoveMessage({
    required Object title,
    required Object collectionName,
  }) {
    return 'إزالة «$title» من «$collectionName»؟';
  }

  @override
  String get collectionDetailAllBooksAlreadyAdded =>
      'جميع الكتب مضافة بالفعل إلى هذا الرف';

  @override
  String get collectionDetailAddBooksTitle => 'إضافة كتب';

  @override
  String collectionDetailAddedBook({required Object title}) {
    return 'أُضيف «$title»';
  }

  @override
  String get readerAnnotations => 'التعليقات التوضيحية';

  @override
  String readerHighlightsTab({required int count}) {
    return 'التمييزات ($count)';
  }

  @override
  String readerBookmarksTab({required int count}) {
    return 'الإشارات المرجعية ($count)';
  }

  @override
  String get readerNoHighlightsYet => 'لا توجد تمييزات بعد';

  @override
  String get readerNoHighlightsHint =>
      'حدّد نصًا أثناء القراءة لتضيف إليه تمييزًا';

  @override
  String get readerNoBookmarksYet => 'لا توجد إشارات مرجعية بعد';

  @override
  String get readerDeleteBookmarkTitle => 'حذف الإشارة المرجعية';

  @override
  String get readerDeleteBookmarkMessage => 'هل تريد حذف هذه الإشارة المرجعية؟';

  @override
  String get readerBookmarkAdded => 'تمت إضافة الإشارة المرجعية';

  @override
  String readerQuotedSelection({required Object text}) {
    return '«$text»';
  }

  @override
  String readerChapterLabel({required int chapterNumber}) {
    return 'الفصل $chapterNumber';
  }

  @override
  String get readerDeleteHighlightTitle => 'حذف التمييز';

  @override
  String get readerDeleteHighlightMessage => 'هل تريد حذف هذا التمييز؟';

  @override
  String get readerEditNote => 'عدّل الملاحظة';

  @override
  String get readerAddNote => 'أضف ملاحظة';

  @override
  String get readerNoteHint => 'اكتب ملاحظتك…';

  @override
  String get readerHighlight => 'تمييز';

  @override
  String get readerHighlightWithNote => 'تمييز مع ملاحظة';

  @override
  String get readerCopiedToClipboard => 'نُسخ إلى الحافظة';

  @override
  String get readerErrorTitle => 'خطأ في القارئ';

  @override
  String readerLoadFailed({required Object error}) {
    return 'تعذّر فتح هذا الكتاب: $error';
  }

  @override
  String get readerUnknownError => 'حدث خطأ أثناء فتح هذا الكتاب.';

  @override
  String get readerExitZenMode => 'إنهاء وضع التركيز';

  @override
  String get readerZenMode => 'وضع التركيز';

  @override
  String get readerSwitchToLightMode => 'التبديل إلى الوضع الفاتح';

  @override
  String get readerSwitchToDarkMode => 'التبديل إلى الوضع الداكن';

  @override
  String get readerTableOfContents => 'جدول المحتويات';

  @override
  String get readerSettings => 'إعدادات القراءة';

  @override
  String get readerBookmark => 'إشارة مرجعية';

  @override
  String get readerTypography => 'تنسيق النص';

  @override
  String get readerReadingDirection => 'اتجاه القراءة';

  @override
  String get readerDirectionAuto => 'تلقائي';

  @override
  String get readerDirectionLeftToRight => 'من اليسار إلى اليمين';

  @override
  String get readerDirectionRightToLeft => 'من اليمين إلى اليسار';

  @override
  String get readerTheme => 'النسق';

  @override
  String get readerContents => 'المحتويات';

  @override
  String readerPageOf({required int currentPage, required int totalPages}) {
    return 'الصفحة $currentPage من $totalPages';
  }

  @override
  String readerChapterProgress({
    required Object chapterTitle,
    required int percent,
  }) {
    return '$chapterTitle · $percent٪';
  }

  @override
  String get readerFontFamilySystem => 'خط النظام';

  @override
  String get readerFontFamilySerif => 'سيريف';

  @override
  String get readerFontFamilySansSerif => 'سانس سيريف';

  @override
  String get readerFontFamilyMonospace => 'أحادي المسافة';

  @override
  String get statsTitle => 'إحصائيات القراءة';

  @override
  String get statsErrorFallback => 'حدث خطأ';

  @override
  String statsLoadFailed({required Object error}) {
    return 'تعذّر تحميل الإحصاءات: $error';
  }

  @override
  String get statsTotalTime => 'إجمالي وقت القراءة';

  @override
  String get statsBooksStartedThisYear => 'الكتب التي بدأت قراءتها هذا العام';

  @override
  String get statsSessions => 'جلسات القراءة';

  @override
  String statsSessionCount({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count جلسة قراءة',
      many: '$count جلسة قراءة',
      few: '$count جلسات قراءة',
      two: 'جلستا قراءة',
      one: 'جلسة قراءة واحدة',
      zero: 'لا توجد جلسات قراءة',
    );
    return '$_temp0';
  }

  @override
  String get statsRecentSessions => 'جلسات القراءة الأخيرة';

  @override
  String get statsCurrentStreak => 'سلسلة القراءة الحالية';

  @override
  String get statsLongestStreak => 'أطول سلسلة قراءة';

  @override
  String get statsReadingActivity => 'نشاط القراءة';

  @override
  String get statsHeatmapLess => 'أقل';

  @override
  String get statsHeatmapMore => 'أكثر';

  @override
  String statsHeatmapNoReading({required Object date}) {
    return 'لا توجد قراءة في $date';
  }

  @override
  String statsHeatmapMinutes({required Object date, required int minutes}) {
    return '$minutes دقيقة في $date';
  }

  @override
  String statsDurationHoursMinutes({required int hours, required int minutes}) {
    return '$hours س $minutes د';
  }

  @override
  String statsDurationMinutes({required int minutes}) {
    return '$minutes د';
  }
}
