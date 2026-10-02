import 'package:flutter/material.dart';

import '../../core/models/plugin.dart';
import '../../core/utils/locale.dart';

class UnverifiedPluginDialog extends StatelessWidget {
  const UnverifiedPluginDialog({super.key, required this.confirmation});

  final UnverifiedPluginConfirmation confirmation;

  bool _sensitive(PluginPermission permission) =>
      permission.type == 'network_access' && permission.scope == '*' ||
      const {
        'file_write',
        'books_write',
        'chapters_write',
        'libraries_write',
        'metadata_write',
        'task_manage',
        'capability_invoke',
      }.contains(permission.type);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final kinds = confirmation.capabilities.map((item) => item.kind).toSet();
    return AlertDialog(
      title:
          Text(context.localeText('安装未经验证的插件', 'Install an unverified plugin')),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${confirmation.pluginName} · ${confirmation.version}',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                  '${context.localeText('未知发布者', 'Unknown publisher')} · ${confirmation.runtime ?? context.localeText('未知', 'Unknown')}'),
              const SizedBox(height: 16),
              Text(context.localeText(
                '此插件未经 Ting Reader 验证。请检查它申请的访问权限。继续安装即表示你接受使用该插件可能造成的设备损坏或数据丢失风险。',
                'This plugin has not been verified by Ting Reader. Review its requested access permissions. Continuing means you accept the risk of device damage or data loss caused by the plugin.',
              )),
              if (confirmation.packageChanged) ...[
                const SizedBox(height: 12),
                Text(
                    context.localeText(
                      '插件包已变化，请重新检查当前包的权限并确认。',
                      'The plugin package has changed. Review the current permissions and confirm again.',
                    ),
                    style: TextStyle(color: colors.error)),
              ],
              if (confirmation.runtime == 'native') ...[
                const SizedBox(height: 12),
                Text(
                    context.localeText(
                      '原生插件在宿主进程中执行，可直接操作系统资源。声明的权限不能约束其全部行为。',
                      'Native plugins execute in the host process and can access system resources directly. Declared permissions cannot constrain all their actions.',
                    ),
                    style: TextStyle(color: colors.error)),
              ],
              const SizedBox(height: 20),
              Text(
                  context.localeText('请求的访问权限', 'Requested access permissions'),
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              if (!confirmation.permissionsAvailable)
                Text(context.localeText('服务端未提供请求权限信息',
                    'The server did not provide permission information'))
              else if (confirmation.permissions.isEmpty)
                Text(context.localeText(
                    '未申请宿主访问权限', 'No host access permissions requested'))
              else
                ...confirmation.permissions.map((permission) {
                  final sensitive = _sensitive(permission);
                  final label =
                      context.l10n.pluginsPermissionLabel(permission.type);
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: sensitive
                          ? colors.errorContainer
                          : colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label),
                        if (permission.scope != null) Text(permission.scope!),
                        if (sensitive)
                          Text(
                              context.localeText(
                                '高风险权限',
                                'Sensitive permission',
                              ),
                              style: TextStyle(
                                  color: colors.onErrorContainer,
                                  fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                }),
              if (kinds.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(context.localeText('插件提供的功能', 'Plugin features'),
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Text(
                    kinds.map(context.l10n.pluginsCapabilityLabel).join(' · ')),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.localeText('同意并安装', 'Agree and install')),
        ),
      ],
    );
  }
}
