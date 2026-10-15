part of 'plugin_extension_host.dart';

class _PluginDocumentReaderPanel extends StatefulWidget {
  const _PluginDocumentReaderPanel({required this.extensionContext});

  final Map<String, Object?> extensionContext;

  @override
  State<_PluginDocumentReaderPanel> createState() =>
      _PluginDocumentReaderPanelState();
}

class _PluginDocumentReaderPanelState
    extends State<_PluginDocumentReaderPanel> {
  late final TextEditingController _uriController =
      TextEditingController(text: _resourceFromContext().uri);
  late final TextEditingController _extensionController =
      TextEditingController(text: _resourceFromContext().extension ?? '');
  final TextEditingController _pageController =
      TextEditingController(text: '1');

  DocumentReaderSession? _session;
  DocumentMetadata? _metadata;
  List<DocumentSection> _sections = const [];
  String? _sectionId;
  DocumentChunk? _chunk;
  DocumentPageRender? _page;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _uriController.dispose();
    _extensionController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  DocumentResourceRef _resourceFromContext() {
    final context = widget.extensionContext;
    final uri = _contextString(context, 'document_uri') ??
        _contextString(context, 'uri') ??
        _contextString(context, 'chapter_path') ??
        _contextString(context, 'book_path') ??
        '';
    return DocumentResourceRef(
      uri: uri,
      extension: _contextString(context, 'extension') ??
          _contextString(context, 'document_extension') ??
          _extensionFromUri(uri),
      mimeType: _contextString(context, 'mime_type'),
      bookId: _contextString(context, 'book_id'),
      chapterId: _contextString(context, 'chapter_id'),
    );
  }

  DocumentResourceRef _resource() {
    final contextResource = _resourceFromContext();
    final uri = _uriController.text.trim();
    final extension = _extensionController.text.trim();
    return DocumentResourceRef(
      uri: uri,
      extension: extension.isNotEmpty ? extension : _extensionFromUri(uri),
      mimeType: contextResource.mimeType,
      bookId: contextResource.bookId,
      chapterId: contextResource.chapterId,
    );
  }

  Future<void> _open() async {
    if (_loading || _uriController.text.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _session = null;
      _metadata = null;
      _sections = const [];
      _sectionId = null;
      _chunk = null;
      _page = null;
    });
    try {
      final client = AppScope.appOf(context).documentReader;
      final session = await client.openDocumentSession(_resource());
      if (session == null) {
        if (!mounted) return;
        setState(() => _error = context.localeText(
              '没有内容处理器支持此文档。',
              'No content processor supports this document.',
            ));
        return;
      }
      final results = await Future.wait<Object?>([
        client
            .extractDocumentMetadata(session.resource, session: session)
            .catchError((_) => null),
        client
            .listDocumentSections(session.resource, session: session)
            .catchError((_) => const <DocumentSection>[]),
      ]);
      if (!mounted) return;
      final sections = results[1] as List<DocumentSection>;
      setState(() {
        _session = session;
        _metadata = results[0] as DocumentMetadata?;
        _sections = sections;
        _sectionId = sections.isNotEmpty ? sections.first.id : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _readChunk() async {
    final session = _session;
    if (_loading || session == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final chunk =
          await AppScope.appOf(context).documentReader.readDocumentChunk(
                session.resource,
                sectionId: _sectionId,
                limit: 4000,
                session: session,
              );
      if (!mounted) return;
      setState(() => _chunk = chunk);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _renderPage() async {
    final session = _session;
    if (_loading || session == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page =
          await AppScope.appOf(context).documentReader.renderDocumentPage(
                session.resource,
                page: int.tryParse(_pageController.text.trim()) ?? 1,
                session: session,
              );
      if (!mounted) return;
      setState(() => _page = page);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pageValue = _page;
    final chunkValue = _chunk;
    final errorValue = _error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _uriController,
          decoration: InputDecoration(
            labelText: context.localeText('资源 URI', 'URI'),
            hintText: context.localeText(
              '书籍/章节路径或插件资源 URI',
              'Book/chapter path or plugin resource URI',
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            SizedBox(
              width: 92,
              child: TextField(
                controller: _extensionController,
                decoration: InputDecoration(
                  labelText: context.localeText('扩展名', 'Ext'),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _open,
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_stories_rounded),
                label: Text(context.localeText('打开', 'Open')),
              ),
            ),
          ],
        ),
        if (errorValue != null) ...[
          const SizedBox(height: 12),
          _PluginActionMessage(message: errorValue, failed: true),
        ],
        if (_session != null) ...[
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PluginActionMessage(
                    message: _formatDocumentSummary(),
                    failed: false,
                  ),
                  const SizedBox(height: 12),
                  if (_sections.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue:
                          _sections.any((section) => section.id == _sectionId)
                              ? _sectionId
                              : _sections.first.id,
                      decoration: InputDecoration(
                        labelText: context.localeText('分区', 'Section'),
                      ),
                      items: [
                        for (final section in _sections)
                          DropdownMenuItem(
                            value: section.id,
                            child: Text(section.title ?? section.id),
                          ),
                      ],
                      onChanged: (value) => setState(() => _sectionId = value),
                    ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _loading ? null : _readChunk,
                    child: Text(context.localeText('读取片段', 'Chunk')),
                  ),
                  if (chunkValue != null) ...[
                    const SizedBox(height: 10),
                    _PluginActionMessage(
                      message: chunkValue.text ??
                          chunkValue.html ??
                          _jsonEncode(_chunkSummary(chunkValue)),
                      failed: false,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        width: 92,
                        child: TextField(
                          controller: _pageController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: context.localeText('页码', 'Page'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _loading ? null : _renderPage,
                          child:
                              Text(context.localeText('渲染页面', 'Render page')),
                        ),
                      ),
                    ],
                  ),
                  if (pageValue != null) ...[
                    const SizedBox(height: 10),
                    if (pageValue.imageBase64 case final imageBase64?)
                      Image.memory(
                        base64Decode(imageBase64),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => _PluginActionMessage(
                          message: _jsonEncode(_pageSummary(pageValue)),
                          failed: false,
                        ),
                      )
                    else
                      _PluginActionMessage(
                        message: pageValue.text ??
                            pageValue.svg ??
                            _jsonEncode(_pageSummary(pageValue)),
                        failed: false,
                      ),
                  ],
                ],
              ),
            ),
          ),
        ] else
          const Spacer(),
      ],
    );
  }

  String _formatDocumentSummary() {
    final session = _session;
    return _jsonEncode({
      'processor': session?.processor.capability.id,
      'probe': {
        'supported': session?.probe?.supported,
        'confidence': session?.probe?.confidence,
        'reason': session?.probe?.reason,
      },
      'metadata': {
        'title': _metadata?.title,
        'author': _metadata?.author,
        'language': _metadata?.language,
        'page_count': _metadata?.pageCount,
        'word_count': _metadata?.wordCount,
        ...?_metadata?.extra,
      },
    });
  }
}

String? _contextString(Map<String, Object?> context, String key) {
  final value = context[key];
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

String _extensionFromUri(String uri) {
  final match = RegExp(r'\.([a-z0-9]+)$', caseSensitive: false)
      .firstMatch(uri.split('?').first);
  return match?.group(1) ?? '';
}

String _jsonEncode(Object? value) =>
    const JsonEncoder.withIndent('  ').convert(value);

Map<String, Object?> _chunkSummary(DocumentChunk chunk) => {
      'section_id': chunk.sectionId,
      'text': chunk.text,
      'html': chunk.html,
      'next_cursor': chunk.nextCursor,
      'progress': chunk.progress,
      ...chunk.extra,
    };

Map<String, Object?> _pageSummary(DocumentPageRender page) => {
      'page': page.page,
      'text': page.text,
      'svg': page.svg,
      'width': page.width,
      'height': page.height,
      ...page.extra,
    };
