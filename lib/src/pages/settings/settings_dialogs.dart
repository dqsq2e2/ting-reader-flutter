part of 'settings_page.dart';

class _AboutDialog extends StatelessWidget {
  const _AboutDialog({
    required this.backendVersion,
    required this.checking,
    required this.onClose,
    required this.onCheckUpdate,
  });

  final String backendVersion;
  final bool checking;
  final VoidCallback onClose;
  final VoidCallback onCheckUpdate;

  @override
  Widget build(BuildContext context) {
    return _ModalBarrier(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: TingCard(
          radius: 24,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/logo.png', width: 64, height: 64),
              const SizedBox(height: 16),
              const Text(
                '关于 Ting Reader',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      context.isDark ? AppColors.slate800 : AppColors.slate50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '服务端版本',
                        style: TextStyle(
                          color: context.mutedText,
                        ),
                      ),
                    ),
                    Text(
                      backendVersion.isEmpty ? 'Unknown' : 'v$backendVersion',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: checking ? null : onCheckUpdate,
                      child: Text(checking ? '检查中...' : '检查更新'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const SelectableText('官网地址  www.tingreader.cn'),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onClose,
                  child: const Text('关闭'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackendUpdateDialog extends StatelessWidget {
  const _BackendUpdateDialog({
    required this.update,
    required this.onClose,
    required this.onCopyUrl,
  });

  final Map<String, dynamic> update;
  final VoidCallback onClose;
  final VoidCallback onCopyUrl;

  @override
  Widget build(BuildContext context) {
    final version = _stringValue(update, 'version', fallback: 'Unknown');
    final date = _stringValue(update, 'date', fallback: '');
    return _ModalBarrier(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: TingCard(
          radius: 24,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.blue,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '发现服务端新版本 $version',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
              if (date.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '发布时间: ${_dateOnly(date)}',
                  style: TextStyle(color: context.mutedText),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onClose,
                      child: const Text('暂不更新'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onCopyUrl,
                      child: const Text('复制更新地址'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModalBarrier extends StatelessWidget {
  const _ModalBarrier({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.52),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

String _stringValue(
  Map<String, dynamic> data,
  String snake, {
  String? camel,
  Map<String, dynamic>? nested,
  String fallback = '',
}) {
  final value = data[snake] ??
      (camel == null ? null : data[camel]) ??
      nested?[snake] ??
      (camel == null ? null : nested?[camel]);
  return value?.toString() ?? fallback;
}

num _numValue(
  Map<String, dynamic> data,
  String snake,
  String camel, {
  num fallback = 0,
}) {
  final value = data[snake] ?? data[camel];
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '') ?? fallback;
}

bool _boolValue(
  Map<String, dynamic> data,
  String snake,
  String camel, {
  Map<String, dynamic>? nested,
  required bool fallback,
}) {
  final value = data[snake] ?? data[camel] ?? nested?[snake] ?? nested?[camel];
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value == null) return fallback;
  return value.toString() == 'true';
}

String _dateOnly(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
}
