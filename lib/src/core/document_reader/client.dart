import '../api/plugin_capabilities_api.dart';
import '../models/_helpers.dart' show asMap, asMapList;
import '../models/plugin.dart';
import 'types.dart';

class DocumentReaderClient {
  const DocumentReaderClient(this._plugins);

  final PluginCapabilitiesApi _plugins;

  Future<List<DocumentProcessorRegistration>> findDocumentProcessors(
    DocumentResourceRef resource, {
    DocumentReaderOperation? operation,
  }) {
    return _plugins.findContentProcessors(
      extension: _resourceExtension(resource),
      operation: operation?.value,
    );
  }

  Future<Object?> invokeDocumentProcessor(
    PluginCapabilityRegistration processor, {
    required DocumentResourceRef resource,
    required DocumentReaderOperation operation,
    Map<String, Object?> params = const {},
  }) {
    return _plugins.invokePluginCapability<Object?>(
      pluginId: processor.pluginId,
      capabilityId: processor.capability.id,
      params: documentOperationParams(
        resource: resource,
        operation: operation,
        extra: params,
      ),
    );
  }

  Future<DocumentProbeResult?> probeDocument(
    DocumentResourceRef resource,
  ) async {
    final session = await openDocumentSession(resource);
    return session?.probe;
  }

  Future<DocumentReaderSession?> openDocumentSession(
    DocumentResourceRef resource,
  ) async {
    final processors = await findDocumentProcessors(
      resource,
      operation: DocumentReaderOperation.probe,
    );
    DocumentReaderSession? best;

    for (final processor in processors) {
      try {
        final result = await invokeDocumentProcessor(
          processor,
          resource: resource,
          operation: DocumentReaderOperation.probe,
        );
        final probe = DocumentProbeResult.fromJson(asMap(result));
        if (!probe.supported) continue;

        final confidence = probe.confidence ?? 0;
        final bestConfidence = best?.probe?.confidence ?? 0;
        if (best == null || confidence > bestConfidence) {
          best = DocumentReaderSession(
            resource: resource,
            processor: processor,
            probe: probe,
          );
        }
      } catch (_) {
        // Keep trying other processors when one plugin fails to probe.
      }
    }
    return best;
  }

  Future<DocumentMetadata?> extractDocumentMetadata(
    DocumentResourceRef resource, {
    DocumentReaderSession? session,
    DocumentProcessorRegistration? processor,
  }) async {
    final selected = processor ??
        session?.processor ??
        await _firstProcessor(
          resource,
          DocumentReaderOperation.extractMetadata,
        );
    if (selected == null) return null;

    final result = await invokeDocumentProcessor(
      selected,
      resource: resource,
      operation: DocumentReaderOperation.extractMetadata,
    );
    return DocumentMetadata.fromJson(asMap(result));
  }

  Future<List<DocumentSection>> listDocumentSections(
    DocumentResourceRef resource, {
    DocumentReaderSession? session,
    DocumentProcessorRegistration? processor,
  }) async {
    final selected = processor ??
        session?.processor ??
        await _firstProcessor(
          resource,
          DocumentReaderOperation.listSections,
        );
    if (selected == null) return const [];

    final result = await invokeDocumentProcessor(
      selected,
      resource: resource,
      operation: DocumentReaderOperation.listSections,
    );
    return asMapList(result).map(DocumentSection.fromJson).toList();
  }

  Future<DocumentChunk?> readDocumentChunk(
    DocumentResourceRef resource, {
    String? sectionId,
    String? cursor,
    int? limit,
    DocumentReaderSession? session,
    DocumentProcessorRegistration? processor,
  }) async {
    final selected = processor ??
        session?.processor ??
        await _firstProcessor(
          resource,
          DocumentReaderOperation.readChunk,
        );
    if (selected == null) return null;

    final result = await invokeDocumentProcessor(
      selected,
      resource: resource,
      operation: DocumentReaderOperation.readChunk,
      params: {
        'sectionId': sectionId,
        'cursor': cursor,
        'limit': limit,
      },
    );
    return DocumentChunk.fromJson(asMap(result));
  }

  Future<DocumentPageRender?> renderDocumentPage(
    DocumentResourceRef resource, {
    required int page,
    DocumentReaderSession? session,
    DocumentProcessorRegistration? processor,
  }) async {
    final selected = processor ??
        session?.processor ??
        await _firstProcessor(
          resource,
          DocumentReaderOperation.renderPage,
        );
    if (selected == null) return null;

    final result = await invokeDocumentProcessor(
      selected,
      resource: resource,
      operation: DocumentReaderOperation.renderPage,
      params: {'page': page},
    );
    return DocumentPageRender.fromJson(asMap(result));
  }

  Future<DocumentProcessorRegistration?> _firstProcessor(
    DocumentResourceRef resource,
    DocumentReaderOperation operation,
  ) async {
    final processors = await findDocumentProcessors(
      resource,
      operation: operation,
    );
    return processors.isEmpty ? null : processors.first;
  }
}

String _resourceExtension(DocumentResourceRef resource) {
  final declared = resource.extension?.trim().replaceFirst(RegExp(r'^\.'), '');
  if (declared != null && declared.isNotEmpty) return declared;

  final path = resource.uri.split('?').first;
  final match =
      RegExp(r'\.([a-z0-9]+)$', caseSensitive: false).firstMatch(path);
  return match?.group(1) ?? '';
}
