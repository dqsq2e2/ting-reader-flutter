import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/models.dart';
import '../state/app_state.dart';

final _coverRevisions = <String, int>{};
int _nextCoverRevision = 0;

void invalidateBookCover(AppState appState, String bookId) {
  final key = '${appState.activeUrl}|$bookId';
  _coverRevisions.remove(key);
  _coverRevisions[key] = ++_nextCoverRevision;
  if (_coverRevisions.length > 1024) {
    _coverRevisions.remove(_coverRevisions.keys.first);
  }
}

String coverUrl(AppState appState,
    {String? url, String? libraryId, String? bookId}) {
  if (url == null || url.isEmpty) return '';
  // Server filesystem paths need the cover API, even when the client runs on Windows.
  if (isLocalFilePath(url) &&
      (url.startsWith('file://') || libraryId == null || libraryId.isEmpty)) {
    return url;
  }
  final base = appState.activeUrl.replaceAll(RegExp(r'/$'), '');
  final token = appState.token;

  if (url.startsWith('http') && url.contains('#referer=')) {
    final params = <String, String>{
      'path': url,
      if (libraryId != null && libraryId.isNotEmpty) 'library_id': libraryId,
      if (token != null && token.isNotEmpty) 'token': token,
    };
    return Uri.parse('$base/api/proxy/cover')
        .replace(queryParameters: params)
        .toString();
  }

  if (url.startsWith('http')) return url;

  if (libraryId != null && libraryId.isNotEmpty) {
    final params = <String, String>{
      'path': url,
      'library_id': libraryId,
      if (bookId != null) 'book_id': bookId,
      if (bookId != null &&
          _coverRevisions.containsKey('${appState.activeUrl}|$bookId'))
        'v': _coverRevisions['${appState.activeUrl}|$bookId'].toString(),
      if (token != null && token.isNotEmpty) 'token': token,
    };
    return Uri.parse('$base/api/proxy/cover')
        .replace(queryParameters: params)
        .toString();
  }

  if (url.startsWith('/')) return '$base$url';
  return url;
}

bool isLocalFilePath(String value) {
  if (value.startsWith('file://')) return true;
  if (RegExp(r'^[A-Za-z]:[\\/]').hasMatch(value)) return true;
  if (value.startsWith('/data/') ||
      value.startsWith('/storage/') ||
      value.startsWith('/var/') ||
      value.startsWith('/Users/')) {
    return true;
  }
  return false;
}

String bookCoverUrl(AppState appState, Book book) {
  return coverUrl(
    appState,
    url: book.coverUrl,
    libraryId: book.libraryId,
    bookId: book.id,
  );
}

String seriesCoverUrl(AppState appState, Series series) {
  final firstBook = series.books.isNotEmpty ? series.books.first : null;
  return coverUrl(
    appState,
    url: series.coverUrl ?? firstBook?.coverUrl,
    libraryId: series.libraryId,
    bookId: firstBook?.id,
  );
}

String? localCoverFilePath(String value) {
  if (kIsWeb || !isLocalFilePath(value)) return null;
  if (value.startsWith('file://')) {
    try {
      return Uri.parse(value).toFilePath();
    } on FormatException {
      return null;
    }
  }
  return value;
}
