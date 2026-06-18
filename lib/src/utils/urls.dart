import '../models/models.dart';
import '../state/app_state.dart';

String coverUrl(AppState appState,
    {String? url, String? libraryId, String? bookId}) {
  if (url == null || url.isEmpty) return '';
  if (_isLocalFilePath(url)) return url;
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
      if (url == 'embedded://first-chapter' && bookId != null) 'book_id': bookId,
      if (token != null && token.isNotEmpty) 'token': token,
    };
    return Uri.parse('$base/api/proxy/cover')
        .replace(queryParameters: params)
        .toString();
  }

  if (url.startsWith('/')) return '$base$url';
  return url;
}

bool _isLocalFilePath(String value) {
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
