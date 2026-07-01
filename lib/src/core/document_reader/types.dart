import '../models/_helpers.dart'
    show asMap, readBool, readDouble, readInt, readString;
import '../models/plugin.dart';

enum DocumentReaderOperation {
  probe('probe'),
  extractMetadata('extract_metadata'),
  listSections('list_sections'),
  readChunk('read_chunk'),
  renderPage('render_page');

  const DocumentReaderOperation(this.value);

  final String value;
}

class DocumentResourceRef {
  const DocumentResourceRef({
    required this.uri,
    this.extension,
    this.mimeType,
    this.bookId,
    this.chapterId,
  });

  final String uri;
  final String? extension;
  final String? mimeType;
  final String? bookId;
  final String? chapterId;

  Map<String, dynamic> toJson() => _compact({
        'uri': uri,
        'extension': extension,
        'mimeType': mimeType,
        'bookId': bookId,
        'chapterId': chapterId,
      });

  factory DocumentResourceRef.fromJson(Map<String, dynamic> json) {
    return DocumentResourceRef(
      uri: readString(json, 'uri') ?? '',
      extension: readString(json, 'extension'),
      mimeType: readString(json, 'mimeType') ?? readString(json, 'mime_type'),
      bookId: readString(json, 'bookId') ?? readString(json, 'book_id'),
      chapterId:
          readString(json, 'chapterId') ?? readString(json, 'chapter_id'),
    );
  }
}

class DocumentProbeResult {
  const DocumentProbeResult({
    required this.supported,
    this.confidence,
    this.reason,
  });

  final bool supported;
  final double? confidence;
  final String? reason;

  factory DocumentProbeResult.fromJson(Map<String, dynamic> json) {
    return DocumentProbeResult(
      supported: readBool(json, 'supported') ?? false,
      confidence: readDouble(json, 'confidence'),
      reason: readString(json, 'reason'),
    );
  }
}

class DocumentMetadata {
  const DocumentMetadata({
    this.title,
    this.author,
    this.language,
    this.pageCount,
    this.wordCount,
    this.extra = const {},
  });

  final String? title;
  final String? author;
  final String? language;
  final int? pageCount;
  final int? wordCount;
  final Map<String, dynamic> extra;

  factory DocumentMetadata.fromJson(Map<String, dynamic> json) {
    final extra = Map<String, dynamic>.from(json)
      ..remove('title')
      ..remove('author')
      ..remove('language')
      ..remove('pageCount')
      ..remove('page_count')
      ..remove('wordCount')
      ..remove('word_count');
    return DocumentMetadata(
      title: readString(json, 'title'),
      author: readString(json, 'author'),
      language: readString(json, 'language'),
      pageCount: readInt(json, 'pageCount') ?? readInt(json, 'page_count'),
      wordCount: readInt(json, 'wordCount') ?? readInt(json, 'word_count'),
      extra: Map.unmodifiable(extra),
    );
  }
}

class DocumentSection {
  const DocumentSection({
    required this.id,
    this.title,
    this.index,
    this.pageStart,
    this.pageEnd,
    this.extra = const {},
  });

  final String id;
  final String? title;
  final int? index;
  final int? pageStart;
  final int? pageEnd;
  final Map<String, dynamic> extra;

  factory DocumentSection.fromJson(Map<String, dynamic> json) {
    final extra = Map<String, dynamic>.from(json)
      ..remove('id')
      ..remove('title')
      ..remove('index')
      ..remove('pageStart')
      ..remove('page_start')
      ..remove('pageEnd')
      ..remove('page_end');
    return DocumentSection(
      id: readString(json, 'id') ?? '',
      title: readString(json, 'title'),
      index: readInt(json, 'index'),
      pageStart: readInt(json, 'pageStart') ?? readInt(json, 'page_start'),
      pageEnd: readInt(json, 'pageEnd') ?? readInt(json, 'page_end'),
      extra: Map.unmodifiable(extra),
    );
  }
}

class DocumentChunk {
  const DocumentChunk({
    this.sectionId,
    this.text,
    this.html,
    this.nextCursor,
    this.progress,
    this.extra = const {},
  });

  final String? sectionId;
  final String? text;
  final String? html;
  final String? nextCursor;
  final double? progress;
  final Map<String, dynamic> extra;

  factory DocumentChunk.fromJson(Map<String, dynamic> json) {
    final extra = Map<String, dynamic>.from(json)
      ..remove('sectionId')
      ..remove('section_id')
      ..remove('text')
      ..remove('html')
      ..remove('nextCursor')
      ..remove('next_cursor')
      ..remove('progress');
    return DocumentChunk(
      sectionId:
          readString(json, 'sectionId') ?? readString(json, 'section_id'),
      text: readString(json, 'text'),
      html: readString(json, 'html'),
      nextCursor:
          readString(json, 'nextCursor') ?? readString(json, 'next_cursor'),
      progress: readDouble(json, 'progress'),
      extra: Map.unmodifiable(extra),
    );
  }
}

class DocumentPageRender {
  const DocumentPageRender({
    required this.page,
    this.imageBase64,
    this.svg,
    this.text,
    this.width,
    this.height,
    this.extra = const {},
  });

  final int page;
  final String? imageBase64;
  final String? svg;
  final String? text;
  final double? width;
  final double? height;
  final Map<String, dynamic> extra;

  factory DocumentPageRender.fromJson(Map<String, dynamic> json) {
    final extra = Map<String, dynamic>.from(json)
      ..remove('page')
      ..remove('imageBase64')
      ..remove('image_base64')
      ..remove('svg')
      ..remove('text')
      ..remove('width')
      ..remove('height');
    return DocumentPageRender(
      page: readInt(json, 'page') ?? 0,
      imageBase64:
          readString(json, 'imageBase64') ?? readString(json, 'image_base64'),
      svg: readString(json, 'svg'),
      text: readString(json, 'text'),
      width: readDouble(json, 'width'),
      height: readDouble(json, 'height'),
      extra: Map.unmodifiable(extra),
    );
  }
}

typedef DocumentProcessorRegistration = PluginCapabilityRegistration;

class DocumentReaderSession {
  const DocumentReaderSession({
    required this.resource,
    required this.processor,
    this.probe,
  });

  final DocumentResourceRef resource;
  final DocumentProcessorRegistration processor;
  final DocumentProbeResult? probe;
}

Map<String, dynamic> documentOperationParams({
  required DocumentResourceRef resource,
  required DocumentReaderOperation operation,
  Map<String, Object?> extra = const {},
}) {
  return _compact({
    'resource': resource.toJson(),
    'operation': operation.value,
    ...extra,
  });
}

Map<String, dynamic> _compact(Map<String, Object?> source) {
  return Map<String, dynamic>.from(source)
    ..removeWhere((_, value) => value == null);
}

Map<String, dynamic> documentMap(Object? value) => asMap(value);
