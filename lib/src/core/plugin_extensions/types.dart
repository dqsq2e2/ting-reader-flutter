import '../models/plugin.dart';

enum ClientExtensionSlot {
  globalFloatingAction('global.floating_action'),
  globalPanel('global.panel'),
  appSidebarPage('app.sidebar_page'),
  bookDetailAction('book.detail_action'),
  @Deprecated('Immersive player plugin entries are no longer rendered.')
  readerToolbarAction('reader.toolbar_action'),
  @Deprecated('Immersive player plugin entries are no longer rendered.')
  readerSidePanel('reader.side_panel'),
  @Deprecated(
      'reader.document_viewer is retained for manifest compatibility only.')
  readerDocumentViewer('reader.document_viewer');

  const ClientExtensionSlot(this.value);

  final String value;

  bool get rendersInClient => !value.startsWith('reader.');

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
    this.clientGrant,
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
  final String? clientGrant;
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

  Map<String, dynamic> get bridge {
    final value = render['bridge'];
    return value is Map ? Map<String, dynamic>.from(value) : const {};
  }

  bool get allowsCapabilityInvoke => bridge['allow_capability_invoke'] != false;

  Set<String> get allowedCapabilityIds {
    final value = bridge['capabilities'];
    final declared = value is List
        ? value
            .map((entry) => entry.toString().trim())
            .where((entry) => entry.isNotEmpty)
        : const Iterable<String>.empty();
    return {capability.id, ...declared};
  }

  Set<String> get allowedHostMethods {
    final value = bridge['host_methods'];
    if (value is! List) return const {};
    return value
        .map((entry) => entry.toString().trim())
        .where((entry) => entry.isNotEmpty)
        .toSet();
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
