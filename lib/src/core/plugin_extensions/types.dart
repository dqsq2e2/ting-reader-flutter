import '../models/plugin.dart';

enum ClientExtensionSlot {
  globalFloatingAction('global.floating_action'),
  globalPanel('global.panel'),
  settingsSection('settings.section'),
  bookDetailAction('book.detail_action'),
  readerToolbarAction('reader.toolbar_action'),
  readerSidePanel('reader.side_panel'),
  readerDocumentViewer('reader.document_viewer');

  const ClientExtensionSlot(this.value);

  final String value;

  static ClientExtensionSlot? fromValue(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    for (final slot in values) {
      if (slot.value == text) return slot;
    }
    return null;
  }
}

enum ClientExtensionRenderMode {
  schema('schema'),
  builtin('builtin'),
  webContainer('web_container'),
  action('action');

  const ClientExtensionRenderMode(this.value);

  final String value;

  static ClientExtensionRenderMode fromValue(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return action;
    for (final mode in values) {
      if (mode.value == text) return mode;
    }
    return action;
  }
}

class ClientExtensionDescriptor {
  const ClientExtensionDescriptor({
    required this.id,
    required this.pluginId,
    required this.pluginName,
    this.adminOnly = false,
    required this.slot,
    required this.renderMode,
    required this.capability,
    this.render = const {},
    this.title,
    this.icon,
    this.priority = 100,
    this.contexts = const [],
  });

  final String id;
  final String pluginId;
  final String pluginName;
  final bool adminOnly;
  final ClientExtensionSlot slot;
  final ClientExtensionRenderMode renderMode;
  final PluginCapability capability;
  final Map<String, dynamic> render;
  final String? title;
  final Object? icon;
  final int priority;
  final List<String> contexts;

  String get label {
    final titleText = title?.trim();
    if (titleText != null && titleText.isNotEmpty) return titleText;
    if (pluginName.trim().isNotEmpty) return pluginName;
    return capability.id;
  }

  String? get entry {
    final value = render['entry'];
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}

class ClientExtensionRegistrySnapshot {
  const ClientExtensionRegistrySnapshot({
    this.extensions = const [],
    this.bySlot = const {},
  });

  final List<ClientExtensionDescriptor> extensions;
  final Map<ClientExtensionSlot, List<ClientExtensionDescriptor>> bySlot;

  static const empty = ClientExtensionRegistrySnapshot();
}
