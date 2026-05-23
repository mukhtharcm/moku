// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'موكو';

  @override
  String get bookUnknownTitle => 'بدون عنوان';

  @override
  String get bookUnknownAuthor => 'مؤلف غير معروف';

  @override
  String get formatEpub => 'EPUB';

  @override
  String get formatPdf => 'PDF';

  @override
  String get formatText => 'نص';

  @override
  String get formatComicCbz => 'قصص مصورة (CBZ)';

  @override
  String get formatHtml => 'HTML';

  @override
  String get navLibrary => 'مكتبة';

  @override
  String get navDiscover => 'استكشاف';

  @override
  String get navShelves => 'رفوف';

  @override
  String get navStats => 'إحصاءات';

  @override
  String get navSettings => 'إعدادات';

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
  String get commonTryAgain => 'حاول ثانية';

  @override
  String get commonImportFiles => 'استيراد الملفات';

  @override
  String get onboardingSkip => 'تخطي';

  @override
  String get onboardingWelcomeTitle => 'مرحبا بكم في موكو';

  @override
  String get onboardingWelcomeSubtitle => 'رفيقك المريح في القراءة';

  @override
  String get onboardingWelcomeBody =>
      'قم باستيراد ملفات EPUB، وPDF، وTXT، وCBZ، وHTML، وتتبع التقدم، وقراءة خالية من التشتيت.';

  @override
  String get onboardingGetStarted => 'ابدأ';

  @override
  String get onboardingImportTitle => 'استيراد كتبك';

  @override
  String get onboardingImportBody =>
      'أضف ملفات EPUB، وPDF، وTXT، وCBZ، وHTML من جهازك.\nتبقى مكتبتك على جهازك، دون اتصال بالإنترنت بشكل كامل.';

  @override
  String get onboardingImportLater => 'سأفعل هذا لاحقًا';

  @override
  String get onboardingSyncTitle => 'المزامنة عبر الأجهزة';

  @override
  String get onboardingSyncOfflineBody =>
      'يعمل Moku بشكل كامل بدون اتصال بالإنترنت - لا حاجة إلى حساب.';

  @override
  String get onboardingSyncServerBody =>
      'هل تريد مزامنة الكتب والتقدم عبر الأجهزة؟\nقم بتوصيل خادم PocketBase الخاص بك في الإعدادات.';

  @override
  String get onboardingStartReading => 'ابدأ القراءة';

  @override
  String get librarySearchHint => 'ابحث في مكتبتك...';

  @override
  String get libraryErrorFallback => 'حدث خطأ ما';

  @override
  String get librarySectionTitle => 'مكتبة';

  @override
  String get libraryFabImport => 'استيراد';

  @override
  String get librarySortRecent => 'مؤخرًا';

  @override
  String get librarySortTitle => 'عنوان';

  @override
  String get librarySortAuthor => 'مؤلف';

  @override
  String get libraryBookInfo => 'معلومات الكتاب';

  @override
  String get libraryInfoChapters => 'فصول';

  @override
  String get libraryInfoPublisher => 'الناشر';

  @override
  String get libraryInfoLanguage => 'لغة';

  @override
  String get libraryInfoIsbn => 'رقم ISBN';

  @override
  String get libraryDeleteBookTitle => 'حذف الكتاب';

  @override
  String libraryDeleteBookMessage({required Object title}) {
    return 'هل تريد إزالة \"$title\" من مكتبتك؟';
  }

  @override
  String get libraryEmptySearchTitle => 'لم يتم العثور على كتب';

  @override
  String get libraryEmptySearchBody => 'حاول استخدام مصطلح بحث مختلف';

  @override
  String get libraryEmptyTitle => 'مكتبتك في انتظارك';

  @override
  String get libraryEmptyBody =>
      'قم باستيراد كتابك الأول أو كتابك الهزلي لبدء القراءة';

  @override
  String get libraryContinueReading => 'مواصلة القراءة';

  @override
  String libraryProgressRead({required int progress}) {
    return '$progress% قراءة';
  }

  @override
  String get searchTitle => 'استكشاف';

  @override
  String get searchCatalogOpenLibraryTitle => 'Open Library';

  @override
  String get searchCatalogProjectGutenbergTitle => 'Project Gutenberg';

  @override
  String get searchManageCatalogs => 'إدارة الكتالوجات';

  @override
  String get searchCatalogLabel => 'كتالوج';

  @override
  String get searchGenericCatalogName => 'كتالوج';

  @override
  String get searchPromptGenericCatalogName => 'كتالوج';

  @override
  String searchHint({required Object catalogTitle}) {
    return 'بحث $catalogTitle...';
  }

  @override
  String searchInitialPromptTitle({required Object catalogTitle}) {
    return 'بحث $catalogTitle';
  }

  @override
  String get searchInitialPromptBody =>
      'ابحث عن الكتب القابلة للتنزيل وأضفها مباشرة إلى مكتبتك.';

  @override
  String get searchErrorFallback => 'حدث خطأ ما.';

  @override
  String get searchErrorInvalidCatalogInput =>
      'أدخل اسمًا صالحًا للكتالوج وعنوان URL.';

  @override
  String get searchErrorDuplicateCatalog => 'تمت إضافة هذا الكتالوج بالفعل.';

  @override
  String get searchErrorDownloadRedirected =>
      'تمت إعادة توجيه التنزيل عدة مرات.';

  @override
  String get searchErrorDownloadFailed => 'فشل التنزيل.';

  @override
  String get searchErrorCatalogNotSearchable =>
      'لا يوفر هذا الكتالوج موجز OPDS قابلاً للبحث.';

  @override
  String get searchErrorSearchFailed => 'فشل البحث في الكتالوج.';

  @override
  String get searchErrorCatalogLoadFailed => 'تعذر تحميل هذا الكتالوج.';

  @override
  String get searchErrorCatalogMissingSearchLink =>
      'لا يعرض هذا الكتالوج رابط بحث قابل للاستخدام.';

  @override
  String get searchErrorCatalogSearchDescriptionFailed =>
      'تعذر تحميل وصف البحث في الكتالوج.';

  @override
  String get searchErrorCatalogSearchTemplateMissing =>
      'تعذر العثور على قالب بحث قابل للاستخدام لهذا الكتالوج.';

  @override
  String get searchEmptyResults => 'لم يتم العثور على كتب قابلة للتحميل';

  @override
  String get searchNoCatalogSelected => 'اختر كتالوجًا لبدء البحث';

  @override
  String searchBookAdded({required Object title}) {
    return 'تمت إضافة $title إلى مكتبتك';
  }

  @override
  String searchDownloadFailed({required Object error}) {
    return 'فشل التنزيل: $error';
  }

  @override
  String get searchCatalogsTitle => 'الكتالوجات';

  @override
  String get searchCatalogsBody =>
      'الكتالوجات المدمجة جاهزة للاستخدام. يمكنك أيضًا إضافة كتالوجات OPDS الخاصة بك.';

  @override
  String get searchRemoveCatalog => 'إزالة الكتالوج';

  @override
  String get searchNoCustomCatalogs => 'لا توجد كتالوجات مخصصة حتى الآن.';

  @override
  String get searchAddCustomCatalog => 'إضافة كتالوج مخصص';

  @override
  String get searchAddCustomCatalogTitle => 'إضافة كتالوج مخصص';

  @override
  String get searchCatalogNameLabel => 'اسم الكتالوج';

  @override
  String get searchCatalogUrlLabel => 'عنوان URL للكتالوج';

  @override
  String searchCouldNotAddCatalog({required Object error}) {
    return 'لا يمكن إضافة الكتالوج: $error';
  }

  @override
  String get searchCatalogTypeCustom => 'مخصص';

  @override
  String get searchOpenSourcePage => 'صفحة مفتوحة المصدر';

  @override
  String get searchDownloading => 'جارٍ التنزيل...';

  @override
  String searchDownloadFormat({required Object formatName}) {
    return 'تحميل $formatName';
  }

  @override
  String get settingsTitle => 'إعدادات';

  @override
  String get settingsSectionAppearance => 'مظهر';

  @override
  String get settingsLanguageTitle => 'لغة التطبيق';

  @override
  String get settingsLanguageSystem => 'النظام';

  @override
  String get settingsLanguageSystemSubtitle => 'اتبع لغة الجهاز';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageArabic => 'العربية';

  @override
  String get settingsSectionBattery => 'بطارية';

  @override
  String get settingsSectionSync => 'مزامنة';

  @override
  String get settingsSectionAbout => 'عن';

  @override
  String get settingsThemeSystem => 'نظام';

  @override
  String get settingsThemeSystemSubtitle => 'اتبع موضوع الجهاز';

  @override
  String get settingsThemeLight => 'فاتح';

  @override
  String get settingsThemeDark => 'مظلم';

  @override
  String get settingsPowerSaverTitle => 'موفر الطاقة';

  @override
  String get settingsPowerSaverSubtitle =>
      'تقليل الرسوم المتحركة وتحديثات التمرير';

  @override
  String get settingsSyncServerTitle => 'خادم المزامنة';

  @override
  String get settingsSyncConnected => 'متصل';

  @override
  String get settingsSyncNotLoggedIn => 'لم يتم تسجيل الدخول';

  @override
  String get settingsSyncNotConfigured => 'لم يتم تكوينه';

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
  String get settingsVersionUnavailable => 'الإصدار غير متوفر';

  @override
  String get settingsVersionLoading => 'جارٍ تحميل النسخة...';

  @override
  String get settingsOpenSourceTitle => 'مفتوح المصدر';

  @override
  String get settingsOpenSourceSubtitle => 'Flutter + PocketBase';

  @override
  String get syncSettingsTitle => 'إعدادات المزامنة';

  @override
  String get syncStatusDisconnected => 'غير متصل';

  @override
  String get syncStatusConnecting => 'جارٍ الاتصال...';

  @override
  String get syncStatusConnected => 'متصل';

  @override
  String get syncStatusSyncing => 'جارٍ المزامنة...';

  @override
  String get syncStatusError => 'خطأ';

  @override
  String syncLastSynced({required Object value}) {
    return 'آخر مزامنة: $value';
  }

  @override
  String get syncNeverSynced => 'لم تتم مزامنتها مطلقًا';

  @override
  String get syncServerSectionTitle => 'الخادم';

  @override
  String get syncServerUrlLabel => 'عنوان URL للخادم';

  @override
  String get syncServerUrlHint => 'https://your-server.com';

  @override
  String get syncConnect => 'اتصال';

  @override
  String get syncCreateAccount => 'إنشاء حساب';

  @override
  String get syncLogin => 'تسجيل الدخول';

  @override
  String get syncHaveAccountLogin => 'هل لديك حساب؟ تسجيل الدخول';

  @override
  String get syncNewRegister => 'مستخدم جديد؟ أنشئ حسابًا';

  @override
  String get syncEmailLabel => 'بريد إلكتروني';

  @override
  String get syncPasswordLabel => 'كلمة المرور';

  @override
  String get syncRegister => 'تسجيل';

  @override
  String get syncSectionTitle => 'مزامنة';

  @override
  String get syncAutoSyncTitle => 'المزامنة التلقائية';

  @override
  String get syncAutoSyncSubtitle =>
      'المزامنة في الخلفية عند بدء التشغيل والمقدمة وبعد التغييرات.';

  @override
  String get syncSyncNow => 'مزامنة الآن';

  @override
  String get syncAccountTitle => 'حساب';

  @override
  String get syncLogout => 'تسجيل الخروج';

  @override
  String get syncRecentErrors => 'أخطاء المزامنة الأخيرة';

  @override
  String syncFailedToConnect({required Object error}) {
    return 'فشل الاتصال: $error';
  }

  @override
  String syncRegistrationFailed({required Object error}) {
    return 'فشل التسجيل: $error';
  }

  @override
  String syncLoginFailed({required Object error}) {
    return 'فشل تسجيل الدخول: $error';
  }

  @override
  String get syncAuthExpired =>
      'انتهت صلاحية المصادقة. الرجاء تسجيل الدخول مرة أخرى.';

  @override
  String syncPartialFailure({required Object collections}) {
    return 'فشلت المزامنة جزئيًا: $collections';
  }

  @override
  String syncFailed({required Object error}) {
    return 'فشلت المزامنة: $error';
  }

  @override
  String get syncFailedToConnectGeneric => 'فشل الاتصال بالخادم.';

  @override
  String get syncRegistrationFailedGeneric =>
      'فشل التسجيل. يرجى المحاولة مرة أخرى.';

  @override
  String get syncLoginFailedGeneric =>
      'فشل تسجيل الدخول. يرجى التحقق من بيانات الاعتماد الخاصة بك وحاول مرة أخرى.';

  @override
  String get syncFailedGeneric => 'فشلت المزامنة. يرجى المحاولة مرة أخرى.';

  @override
  String get syncErrorLogGenericMessage => 'لا يمكن مزامنة هذه البيانات.';

  @override
  String get syncCollectionBooks => 'كتب';

  @override
  String get syncCollectionReadingProgress => 'تقدم القراءة';

  @override
  String get syncCollectionBookmarks => 'الإشارات المرجعية';

  @override
  String get syncCollectionHighlights => 'أبرز';

  @override
  String get syncCollectionShelves => 'رفوف';

  @override
  String get syncCollectionShelfBooks => 'كتب الرف';

  @override
  String get syncCollectionReadingSessions => 'جلسات القراءة';

  @override
  String get syncCollectionReadingGoals => 'أهداف القراءة';

  @override
  String get syncCollectionUnknown => 'بيانات أخرى';

  @override
  String get collectionsTitle => 'رفوف';

  @override
  String get collectionsEmptyTitle => 'لا يوجد رفوف بعد';

  @override
  String get collectionsEmptyBody => 'تنظيم كتبك في مجموعات';

  @override
  String get collectionsCreateShelf => 'إنشاء رف';

  @override
  String get collectionsNewShelfTitle => 'رف جديد';

  @override
  String get collectionsNameLabel => 'اسم';

  @override
  String get collectionsNameHint => 'مثال: المفضلة، للقراءة لاحقًا...';

  @override
  String get collectionsDescriptionOptionalLabel => 'الوصف (اختياري)';

  @override
  String get collectionsDeleteShelfTitle => 'حذف الرف';

  @override
  String collectionsDeleteShelfMessage({required Object name}) {
    return 'هل تريد حذف \"$name\"؟ لن تتم إزالة كتبك من المكتبة.';
  }

  @override
  String get collectionDetailAddBooksTooltip => 'إضافة كتب';

  @override
  String get collectionDetailEmptyTitle => 'لا توجد كتب في هذه المجموعة';

  @override
  String get collectionDetailAddBooks => 'إضافة كتب';

  @override
  String get collectionDetailRemoveTitle => 'إزالة من المجموعة';

  @override
  String collectionDetailRemoveMessage({
    required Object title,
    required Object collectionName,
  }) {
    return 'هل تريد إزالة \"$title\" من \"$collectionName\"؟';
  }

  @override
  String get collectionDetailAllBooksAlreadyAdded =>
      'جميع الكتب موجودة بالفعل في هذه المجموعة';

  @override
  String get collectionDetailAddBooksTitle => 'إضافة كتب';

  @override
  String collectionDetailAddedBook({required Object title}) {
    return 'تمت إضافة \"$title\"';
  }

  @override
  String get readerAnnotations => 'التعليقات';

  @override
  String readerHighlightsTab({required int count}) {
    return 'التظليلات ($count)';
  }

  @override
  String readerBookmarksTab({required int count}) {
    return 'الإشارات المرجعية ($count)';
  }

  @override
  String get readerNoHighlightsYet => 'لا توجد تظليلات بعد';

  @override
  String get readerNoHighlightsHint => 'حدد النص أثناء القراءة لتمييزه';

  @override
  String get readerNoBookmarksYet => 'لا توجد إشارات مرجعية حتى الآن';

  @override
  String readerQuotedSelection({required Object text}) {
    return '\"$text\"';
  }

  @override
  String readerChapterLabel({required int chapterNumber}) {
    return 'الفصل $chapterNumber';
  }

  @override
  String get readerDeleteHighlightTitle => 'حذف التمييز';

  @override
  String get readerDeleteHighlightMessage =>
      'هل أنت متأكد أنك تريد حذف هذا التمييز؟';

  @override
  String get readerEditNote => 'تحرير الملاحظة';

  @override
  String get readerAddNote => 'أضف ملاحظة';

  @override
  String get readerNoteHint => 'أدخل ملاحظتك...';

  @override
  String get readerHighlight => 'تظليل';

  @override
  String get readerHighlightWithNote => 'تسليط الضوء مع ملاحظة';

  @override
  String get readerCopiedToClipboard => 'تم النسخ إلى الحافظة';

  @override
  String get readerErrorTitle => 'خطأ القارئ';

  @override
  String readerLoadFailed({required Object error}) {
    return 'فشل تحميل هذا الكتاب: $error';
  }

  @override
  String get readerUnknownError => 'حدث خطأ ما أثناء فتح هذا الكتاب.';

  @override
  String get readerExitZenMode => 'الخروج من وضع زين';

  @override
  String get readerZenMode => 'وضع زين';

  @override
  String get readerTableOfContents => 'جدول المحتويات';

  @override
  String get readerSettings => 'إعدادات';

  @override
  String get readerBookmark => 'إشارة مرجعية';

  @override
  String get readerTypography => 'الطباعة';

  @override
  String get readerReadingDirection => 'اتجاه القراءة';

  @override
  String get readerDirectionAuto => 'آلي';

  @override
  String get readerDirectionLeftToRight => 'من اليسار إلى اليمين';

  @override
  String get readerDirectionRightToLeft => 'من اليمين إلى اليسار';

  @override
  String get readerTheme => 'سمة';

  @override
  String get readerContents => 'محتويات';

  @override
  String readerPageOf({required int currentPage, required int totalPages}) {
    return 'صفحة $currentPage من $totalPages';
  }

  @override
  String readerChapterProgress({
    required Object chapterTitle,
    required int percent,
  }) {
    return '$chapterTitle · $percent%';
  }

  @override
  String get readerFontFamilySystem => 'نظام';

  @override
  String get readerFontFamilySerif => 'Serif';

  @override
  String get readerFontFamilySansSerif => 'Sans Serif';

  @override
  String get readerFontFamilyMonospace => 'مونوسبيس';

  @override
  String get statsTitle => 'إحصائيات القراءة';

  @override
  String get statsErrorFallback => 'خطأ';

  @override
  String statsLoadFailed({required Object error}) {
    return 'فشل تحميل الإحصائيات: $error';
  }

  @override
  String get statsTotalTime => 'الوقت الإجمالي';

  @override
  String get statsBooksStartedThisYear => 'الكتب التي بدأت هذا العام';

  @override
  String get statsSessions => 'الجلسات';

  @override
  String get statsRecentSessions => 'الجلسات الأخيرة';

  @override
  String get statsCurrentStreak => 'الخط الحالي';

  @override
  String get statsLongestStreak => 'أطول خط';

  @override
  String get statsReadingActivity => 'نشاط القراءة';

  @override
  String get statsHeatmapLess => 'أقل';

  @override
  String get statsHeatmapMore => 'أكثر';

  @override
  String statsHeatmapNoReading({required Object date}) {
    return '$date: لا توجد قراءة';
  }

  @override
  String statsHeatmapMinutes({required Object date, required int minutes}) {
    return '$date: $minutes دقيقة';
  }

  @override
  String statsDurationHoursMinutes({required int hours, required int minutes}) {
    return '$hoursس $minutesد';
  }

  @override
  String statsDurationMinutes({required int minutes}) {
    return '$minutesم';
  }
}
