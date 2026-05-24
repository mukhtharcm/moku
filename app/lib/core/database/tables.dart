import 'package:drift/drift.dart';

class Books extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get author => text()();
  TextColumn get description => text().nullable()();
  TextColumn get coverPath => text().nullable()();
  TextColumn get filePath => text()();
  TextColumn get format => text().withDefault(const Constant('epub'))();
  TextColumn get isbn => text().nullable()();
  TextColumn get language => text().nullable()();
  TextColumn get publisher => text().nullable()();
  DateTimeColumn get publishDate => dateTime().nullable()();
  IntColumn get totalChapters => integer().withDefault(const Constant(0))();
  TextColumn get fileHash => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get syncPending => boolean().withDefault(const Constant(false))();
  TextColumn get remoteId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ReadingProgress')
class ReadingProgresses extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text().references(Books, #id)();
  IntColumn get currentChapter => integer().withDefault(const Constant(0))();
  RealColumn get chapterProgress => real().withDefault(const Constant(0.0))();
  RealColumn get overallProgress => real().withDefault(const Constant(0.0))();
  TextColumn get lastPosition => text().nullable()();
  DateTimeColumn get lastReadAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get syncPending => boolean().withDefault(const Constant(false))();
  TextColumn get remoteId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Bookmarks extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text().references(Books, #id)();
  IntColumn get chapterIndex => integer()();
  TextColumn get cfi => text().nullable()();
  TextColumn get title => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get syncPending => boolean().withDefault(const Constant(false))();
  TextColumn get remoteId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Highlights extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text().references(Books, #id)();
  IntColumn get chapterIndex => integer()();
  TextColumn get startCfi => text().nullable()();
  TextColumn get endCfi => text().nullable()();
  TextColumn get selectedText => text()();
  TextColumn get color => text().withDefault(const Constant('#FFEB3B'))();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get syncPending => boolean().withDefault(const Constant(false))();
  TextColumn get remoteId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class BookCollections extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get coverPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get syncPending => boolean().withDefault(const Constant(false))();
  TextColumn get remoteId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class CollectionBooks extends Table {
  TextColumn get collectionId => text().references(BookCollections, #id)();
  TextColumn get bookId => text().references(Books, #id)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get syncPending => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {collectionId, bookId};
}

@DataClassName('ReadingSession')
class ReadingSessions extends Table {
  TextColumn get id => text()();
  TextColumn get bookId =>
      text().references(Books, #id, onDelete: KeyAction.cascade)();
  TextColumn get bookTitle => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  IntColumn get durationSeconds => integer().withDefault(const Constant(0))();
  IntColumn get startChapter => integer().withDefault(const Constant(0))();
  IntColumn get endChapter => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get syncPending => boolean().withDefault(const Constant(false))();
  TextColumn get remoteId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ReadingGoal')
class ReadingGoals extends Table {
  TextColumn get id => text()();
  IntColumn get year => integer().unique()();
  IntColumn get booksGoal => integer().withDefault(const Constant(12))();
  IntColumn get minutesPerDayGoal =>
      integer().withDefault(const Constant(30))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get syncPending => boolean().withDefault(const Constant(false))();
  TextColumn get remoteId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
