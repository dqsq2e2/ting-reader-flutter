/// Domain model barrel.
///
/// Models are split by concern into sibling files. This file re-exports them so
/// existing imports (`import '.../models/models.dart';`) keep working with no
/// changes elsewhere.
library;

export '_helpers.dart' show asMap, asMapList;
export 'admin.dart';
export 'book.dart';
export 'cache.dart';
export 'chapter.dart';
export 'library.dart';
export 'notification.dart';
export 'playlist.dart';
export 'plugin.dart';
export 'progress.dart';
export 'series.dart';
export 'stats.dart';
export 'task.dart';
export 'user.dart';
