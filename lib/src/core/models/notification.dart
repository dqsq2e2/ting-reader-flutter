import '_helpers.dart';

class NotificationEventOption {
  const NotificationEventOption({
    required this.id,
    required this.label,
    required this.description,
  });

  final String id;
  final String label;
  final String description;

  factory NotificationEventOption.fromJson(Map<String, dynamic> json) {
    return NotificationEventOption(
      id: readString(json, 'id') ?? '',
      label: readString(json, 'label') ?? '',
      description: readString(json, 'description') ?? '',
    );
  }
}

class NotificationWebhook {
  const NotificationWebhook({
    required this.id,
    required this.name,
    required this.url,
    this.enabled = true,
    this.events = const [],
    this.secret,
    this.headers = const {},
    this.bodyTemplate = '{{json:payload}}',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String url;
  final bool enabled;
  final List<String> events;
  final String? secret;
  final Map<String, String> headers;
  final String bodyTemplate;
  final String? createdAt;
  final String? updatedAt;

  factory NotificationWebhook.fromJson(Map<String, dynamic> json) {
    return NotificationWebhook(
      id: readString(json, 'id') ?? '',
      name: readString(json, 'name') ?? 'Webhook',
      url: readString(json, 'url') ?? '',
      enabled: readBool(json, 'enabled') ?? true,
      events: readStringList(json['events']),
      secret: readString(json, 'secret'),
      headers: readStringMap(json['headers']),
      bodyTemplate: readString(json, 'body_template') ?? '{{json:payload}}',
      createdAt: readString(json, 'created_at'),
      updatedAt: readString(json, 'updated_at'),
    );
  }

  Map<String, dynamic> toRequestJson({bool? enabledOverride}) => {
        'name': name,
        'url': url,
        'enabled': enabledOverride ?? enabled,
        'events': events,
        'secret': secret,
        'headers': headers,
        'body_template': bodyTemplate,
      };
}
