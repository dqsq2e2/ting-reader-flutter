import '../models/_helpers.dart' show asMap, readInt, readStringList;
import '../models/plugin.dart';
import 'types.dart';

const _defaultSlots = [ClientExtensionSlot.globalPanel];

ClientExtensionRegistrySnapshot buildClientExtensionRegistry(
  List<PluginCapabilityRegistration> registrations,
) {
  final extensions = registrations
      .where((registration) =>
          registration.capability.kind == 'ui_extension' ||
          registration.capability.kind == 'client_extension')
      .expand((registration) {
    final slots = _normalizeSlots(registration.capability.extra);
    return slots.map((slot) => _createDescriptor(registration, slot));
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
  final renderMode = ClientExtensionRenderMode.fromValue(
    extra['render_mode'] ??
        (extra['render'] is String ? extra['render'] : null) ??
        render['mode'],
  );

  return ClientExtensionDescriptor(
    id: '${registration.pluginId}:${capability.id}:${slot.value}',
    pluginId: registration.pluginId,
    pluginName: registration.pluginName,
    adminOnly: registration.adminOnly,
    slot: slot,
    renderMode: renderMode,
    render: Map.unmodifiable(render),
    title: _localizedText(extra['title']) ?? _localizedText(extra['label']),
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

List<ClientExtensionSlot> _normalizeSlots(Map<String, dynamic> extra) {
  final slots = <ClientExtensionSlot>{};
  for (final value in readStringList(extra['slots'])) {
    final slot = ClientExtensionSlot.fromValue(value);
    if (slot != null) slots.add(slot);
  }
  final single = ClientExtensionSlot.fromValue(extra['slot']);
  if (single != null) slots.add(single);
  return slots.isEmpty ? _defaultSlots : slots.toList();
}

List<String> _normalizeContexts(Map<String, dynamic> extra) {
  final contexts = readStringList(extra['contexts']);
  if (contexts.isNotEmpty) return contexts;
  return readStringList(extra['context']);
}

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
