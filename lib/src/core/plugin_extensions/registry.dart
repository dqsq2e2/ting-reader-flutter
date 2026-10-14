import '../models/_helpers.dart' show asMap, readInt, readStringList;
import '../models/plugin.dart';
import 'types.dart';

/// One registry owner per authenticated application. Shell navigation and
/// extension slots consume the same snapshot and never run their own loaders.
class ClientExtensionRegistryState {
  ClientExtensionRegistryState({required this.load, required this.onChanged});
  final Future<List<PluginCapabilityRegistration>> Function() load;
  final void Function() onChanged;
  ClientExtensionRegistrySnapshot snapshot =
      ClientExtensionRegistrySnapshot.empty;
  bool loading = false;
  String? _identity;
  int _revision = 0;
  bool _disposed = false;

  void sync(String? identity) {
    if (_disposed || identity == _identity) return;
    _identity = identity;
    final revision = ++_revision;
    snapshot = ClientExtensionRegistrySnapshot.empty;
    loading = identity != null;
    if (identity == null) return;
    load().then((registrations) {
      if (_disposed || revision != _revision) return;
      snapshot = buildClientExtensionRegistry(registrations);
      loading = false;
      onChanged();
    }).catchError((Object _) {
      if (_disposed || revision != _revision) return;
      snapshot = ClientExtensionRegistrySnapshot.empty;
      loading = false;
      onChanged();
    });
  }

  void dispose() {
    _disposed = true;
    _revision++;
  }
}

ClientExtensionRegistrySnapshot buildClientExtensionRegistry(
  List<PluginCapabilityRegistration> registrations,
) {
  final extensions = registrations
      .where((registration) => registration.capability.kind == 'ui_extension')
      .expand((registration) {
    final slots = _normalizeSlots(registration.capability.extra);
    return slots
        .where((slot) => slot.rendersInClient)
        .map((slot) => _createDescriptor(registration, slot));
  }).toList()
    ..sort(
      (left, right) {
        final priority = left.priority.compareTo(right.priority);
        return priority != 0 ? priority : left.id.compareTo(right.id);
      },
    );

  final bySlot = <ClientExtensionSlot, List<ClientExtensionDescriptor>>{};
  for (final extension in extensions) {
    bySlot[extension.slot] = [
      ...(bySlot[extension.slot] ?? const []),
      extension,
    ];
  }

  return ClientExtensionRegistrySnapshot(
    extensions: List.unmodifiable(extensions),
    bySlot: Map.unmodifiable(bySlot),
  );
}

ClientExtensionDescriptor _createDescriptor(
  PluginCapabilityRegistration registration,
  ClientExtensionSlot slot,
) {
  final capability = registration.capability;
  final extra = capability.extra;
  final render = asMap(extra['render']);
  final renderMode = ClientExtensionRenderMode.fromValue(render['mode']);

  return ClientExtensionDescriptor(
    id: '${registration.pluginId}:${capability.id}:${slot.value}',
    pluginId: registration.pluginId,
    pluginName: registration.pluginName,
    adminOnly: registration.adminOnly,
    clientGrant: registration.clientGrant,
    slot: slot,
    renderMode: renderMode,
    render: Map.unmodifiable(render),
    title: _localizedText(extra['title']),
    icon: _normalizeIcon(extra['icon']),
    capability: capability,
    priority: readInt(extra, 'priority') ?? 100,
    contexts: _normalizeContexts(extra),
  );
}

Object? _normalizeIcon(Object? value) {
  if (value is String) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }
  final map = asMap(value);
  return map.isEmpty ? null : Map<String, dynamic>.unmodifiable(map);
}

List<ClientExtensionSlot> _normalizeSlots(Map<String, dynamic> extra) =>
    readStringList(extra['slots'])
        .map(ClientExtensionSlot.fromValue)
        .whereType<ClientExtensionSlot>()
        .toSet()
        .toList();

List<String> _normalizeContexts(Map<String, dynamic> extra) =>
    readStringList(extra['contexts']);

String? _localizedText(Object? value) {
  if (value == null) return null;
  if (value is String) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }
  final map = asMap(value);
  final candidates = [
    map['zh-CN'],
    map['zh'],
    map['en-US'],
    map['en'],
    ...map.values,
  ];
  for (final candidate in candidates) {
    if (candidate is String && candidate.trim().isNotEmpty) {
      return candidate.trim();
    }
  }
  return null;
}
