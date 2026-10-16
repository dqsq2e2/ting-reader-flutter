import '_helpers.dart';
import '../api/api_error.dart';

const defaultWebhookBodyTemplate = '{{json:payload}}';

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
    this.bodyTemplate = defaultWebhookBodyTemplate,
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
      bodyTemplate:
          readString(json, 'body_template') ?? defaultWebhookBodyTemplate,
      createdAt: readString(json, 'created_at'),
      updatedAt: readString(json, 'updated_at'),
    );
  }

  Map<String, dynamic> toRequestJson({bool? enabledOverride}) => {
        'name': name,
        'url': url,
        'enabled': enabledOverride ?? enabled,
        'events': events,
        if (secret != null) 'secret': secret,
        'headers': headers,
        'body_template': bodyTemplate.trim().isEmpty
            ? defaultWebhookBodyTemplate
            : bodyTemplate,
      };
}

class WebhookPreset {
  const WebhookPreset({
    required this.id,
    required this.name,
    required this.urlPlaceholder,
    required this.headers,
    required this.bodyTemplate,
  });

  final String id;
  final String name;
  final String urlPlaceholder;
  final Map<String, String> headers;
  final String bodyTemplate;
}

class WebhookTestResult {
  const WebhookTestResult({
    required this.success,
    required this.status,
    this.responseBody = '',
    this.renderedBody = '',
    this.error,
  });

  final bool success;
  final int status;
  final String responseBody;
  final String renderedBody;
  final ApiError? error;

  factory WebhookTestResult.fromJson(Map<String, dynamic> json) {
    return WebhookTestResult(
      success: json['success'] == true,
      status: (json['status'] as num?)?.toInt() ?? 0,
      responseBody: (json['response_body'] ?? '').toString(),
      renderedBody: (json['rendered_body'] ?? '').toString(),
      error: json['error'] == null ? null : ApiError.from(json['error']),
    );
  }
}

const webhookPresets = [
  WebhookPreset(
    id: 'ting-json',
    name: 'raw-json',
    urlPlaceholder: 'https://example.com/webhook',
    headers: {'Content-Type': 'application/json'},
    bodyTemplate: defaultWebhookBodyTemplate,
  ),
  WebhookPreset(
    id: 'wecom-markdown',
    name: 'wecom-markdown',
    urlPlaceholder: 'https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=...',
    headers: {'Content-Type': 'application/json'},
    bodyTemplate: '''{
  "msgtype": "markdown",
  "markdown": {
    "content": {{json:notification}}
  }
}''',
  ),
  WebhookPreset(
    id: 'wecom-text',
    name: 'wecom-text',
    urlPlaceholder: 'https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=...',
    headers: {'Content-Type': 'application/json'},
    bodyTemplate: '''{
  "msgtype": "text",
  "text": {
    "content": {{json:notification}}
  }
}''',
  ),
  WebhookPreset(
    id: 'ntfy-json',
    name: 'ntfy JSON',
    urlPlaceholder: 'https://ntfy.example.com',
    headers: {'Content-Type': 'application/json'},
    bodyTemplate: '''{
  "topic": "ting-reader",
  "title": {{json:title}},
  "message": {{json:message}},
  "priority": 3,
  "tags": ["headphones"]
}''',
  ),
  WebhookPreset(
    id: 'gotify-json',
    name: 'Gotify JSON',
    urlPlaceholder: 'https://gotify.example.com/message?token=...',
    headers: {'Content-Type': 'application/json'},
    bodyTemplate: '''{
  "title": {{json:title}},
  "message": {{json:message}},
  "priority": 5
}''',
  ),
  WebhookPreset(
    id: 'plain-text',
    name: 'plain-text',
    urlPlaceholder: 'https://example.com/webhook',
    headers: {'Content-Type': 'text/plain; charset=utf-8'},
    bodyTemplate: '{{notification}}',
  ),
];
