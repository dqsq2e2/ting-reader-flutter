import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/fn_connect_client.dart';
import '../../core/auth/fnos_gateway_auth.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/locale.dart';
import '../../shared/app_scope.dart';
import '../../shared/common/common_widgets.dart';
import '../../shared/fnos_logo.dart';

class FnConnectPage extends StatefulWidget {
  const FnConnectPage({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  State<FnConnectPage> createState() => _FnConnectPageState();
}

class _FnConnectPageState extends State<FnConnectPage> {
  String? _switchingUrl;
  final Set<FnConnectCandidateGroup> _expandedUnavailableGroups = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _probe();
    });
  }

  Future<void> _probe() async {
    setState(_expandedUnavailableGroups.clear);
    try {
      await AppScope.appOf(context).reprobeFnConnect();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorText(error))),
      );
    }
  }

  Future<void> _switchTo(FnConnectCandidate candidate) async {
    if (_switchingUrl != null) return;
    setState(() => _switchingUrl = candidate.rootUrl);
    try {
      await AppScope.appOf(context).switchFnConnectCandidate(candidate);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.localeText(
              '切换连接失败：${_errorText(error)}',
              'Could not switch connection: ${_errorText(error)}',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _switchingUrl = null);
    }
  }

  String _errorText(Object error) {
    return error.toString().replaceFirst('Bad state: ', '');
  }

  void _toggleUnavailable(FnConnectCandidateGroup group) {
    setState(() {
      if (!_expandedUnavailableGroups.add(group)) {
        _expandedUnavailableGroups.remove(group);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.appOf(context);
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final profile = appState.savedGatewayProfile;
        if (profile == null ||
            appState.serverMode != ServerProfileMode.fnosGateway) {
          return PageListView(
            children: [
              AppBackButton(onPressed: widget.onBack),
              const SizedBox(height: 28),
              EmptyState(
                icon: Icons.link_off_rounded,
                title: context.localeText(
                  '当前登录方式不支持 FN Connect',
                  'FN Connect is unavailable',
                ),
                message: context.localeText(
                  '请使用 FNID 档案登录后再管理连接链路。',
                  'Sign in with an FNID profile to manage connection links.',
                ),
              ),
            ],
          );
        }

        final candidates = appState.fnConnectCandidates;
        return PageListView(
          onRefresh: _probe,
          children: [
            AppBackButton(onPressed: widget.onBack),
            const SizedBox(height: 28),
            PageHeaderRow(
              iconWidget: const FnosLogo(width: 34, height: 27),
              title: context.localeText('FN Connect', 'FN Connect'),
              subtitle: context.localeText(
                '管理飞牛服务的连接方式与候选链路',
                'Manage fnOS connection preferences and candidate links',
              ),
            ),
            const SizedBox(height: 24),
            _CurrentConnectionCard(
              url: appState.activeUrl,
              relay: appState.fnConnectCurrentIsRelay,
            ),
            const SizedBox(height: 26),
            _SectionLabel(context.localeText('连接优先级', 'Priority')),
            const SizedBox(height: 10),
            _SettingsSurface(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                    child: Row(
                      children: [
                        Icon(
                          Icons.swap_vert_rounded,
                          size: 17,
                          color: context.mutedText,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.localeText(
                              '拖拽调整顺序，排在上方的连接优先尝试',
                              'Drag to reorder. Links near the top are tried first.',
                            ),
                            style: TextStyle(
                              color: context.mutedText,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: context.faintBorder),
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: appState.fnConnectOrder.length,
                    onReorderItem: (oldIndex, newIndex) {
                      final order = List<FnConnectCandidateGroup>.from(
                        appState.fnConnectOrder,
                      );
                      final item = order.removeAt(oldIndex);
                      order.insert(newIndex, item);
                      unawaited(appState.setFnConnectOrder(order));
                    },
                    itemBuilder: (context, index) {
                      final group = appState.fnConnectOrder[index];
                      final enabled =
                          !appState.fnConnectDisabledGroups.contains(group);
                      return _PriorityRow(
                        key: ValueKey(group),
                        group: group,
                        enabled: enabled,
                        index: index,
                        onChanged: (value) =>
                            appState.setFnConnectGroupEnabled(group, value),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            _SectionLabel(context.localeText('安全', 'Security')),
            const SizedBox(height: 10),
            _SettingsSurface(
              child: SwitchListTile(
                value: appState.fnConnectIgnoreSsl,
                onChanged: appState.setFnConnectIgnoreSsl,
                secondary: const Icon(Icons.verified_user_outlined),
                title: Text(
                  context.localeText(
                    '忽略 SSL 证书校验',
                    'Ignore SSL certificate errors',
                  ),
                ),
                subtitle: Text(
                  context.localeText(
                    '签名证书或 IP 直连时开启',
                    'Allows signed certificates and IP links',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 26),
            _SectionLabel(context.localeText('候选链路', 'Candidate links')),
            const SizedBox(height: 10),
            if (candidates.isEmpty)
              const _EmptyCandidates()
            else
              _CandidateGroups(
                order: appState.fnConnectOrder,
                results: candidates,
                disabledGroups: appState.fnConnectDisabledGroups,
                activeUrl: appState.activeUrl,
                switchingUrl: _switchingUrl,
                expandedUnavailableGroups: _expandedUnavailableGroups,
                onToggleUnavailable: _toggleUnavailable,
                onSwitch: _switchTo,
              ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                label: appState.fnConnectProbing
                    ? context.localeText('正在探测中...', 'Probing...')
                    : context.localeText('重新探测', 'Re-probe'),
                icon: Icons.refresh_rounded,
                loading: appState.fnConnectProbing,
                onPressed: appState.fnConnectProbing ? null : _probe,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.localeText(
                'FNID: ${FnosGateway.fnIdLabel(profile.fnId)}',
                'FNID: ${FnosGateway.fnIdLabel(profile.fnId)}',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.mutedText, fontSize: 12),
            ),
          ],
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: context.mutedText,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _SettingsSurface extends StatelessWidget {
  const _SettingsSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.faintBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _CurrentConnectionCard extends StatelessWidget {
  const _CurrentConnectionCard({
    required this.url,
    required this.relay,
  });

  final String url;
  final bool relay;

  @override
  Widget build(BuildContext context) {
    return _SettingsSurface(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              relay ? Icons.swap_horiz_rounded : Icons.link_rounded,
              size: 22,
              color: relay ? Colors.orange : Colors.green,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        relay
                            ? context.localeText('中继连接', 'Relay')
                            : context.localeText('直连', 'Direct'),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      _StatusBadge(
                        label: relay
                            ? context.localeText('中继', 'Relay')
                            : context.localeText('直连', 'Direct'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    _connectionDisplayUrl(url),
                    style: TextStyle(color: context.mutedText, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _connectionDisplayUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty) {
    return value;
  }
  return ApiClient.originFromUri(uri);
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.teal.shade700,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PriorityRow extends StatelessWidget {
  const _PriorityRow({
    required this.group,
    required this.enabled,
    required this.index,
    required this.onChanged,
    super.key,
  });

  final FnConnectCandidateGroup group;
  final bool enabled;
  final int index;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: index == 0
            ? null
            : Border(top: BorderSide(color: context.faintBorder)),
      ),
      child: ListTile(
        leading: Icon(_groupIcon(group), color: context.mutedText),
        title: Text(_groupTitle(context, group)),
        subtitle: Text(_groupSubtitle(context, group)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(value: enabled, onChanged: onChanged),
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child:
                    Icon(Icons.drag_handle_rounded, color: context.mutedText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CandidateGroups extends StatelessWidget {
  const _CandidateGroups({
    required this.order,
    required this.results,
    required this.disabledGroups,
    required this.activeUrl,
    required this.switchingUrl,
    required this.expandedUnavailableGroups,
    required this.onToggleUnavailable,
    required this.onSwitch,
  });

  final List<FnConnectCandidateGroup> order;
  final List<FnConnectCandidateResult> results;
  final Set<FnConnectCandidateGroup> disabledGroups;
  final String activeUrl;
  final String? switchingUrl;
  final Set<FnConnectCandidateGroup> expandedUnavailableGroups;
  final ValueChanged<FnConnectCandidateGroup> onToggleUnavailable;
  final ValueChanged<FnConnectCandidate> onSwitch;

  @override
  Widget build(BuildContext context) {
    final grouped = <FnConnectCandidateGroup, List<FnConnectCandidateResult>>{};
    for (final result in results) {
      final group = result.candidate.group;
      if (disabledGroups.contains(group)) continue;
      grouped.putIfAbsent(group, () => []).add(result);
    }
    final entries = grouped.entries.toList()
      ..sort((a, b) {
        final aUnavailable = a.value.any((item) => item.reachable) ? 0 : 1;
        final bUnavailable = b.value.any((item) => item.reachable) ? 0 : 1;
        if (aUnavailable != bUnavailable) {
          return aUnavailable.compareTo(bUnavailable);
        }
        return _orderIndex(a.key).compareTo(_orderIndex(b.key));
      });

    if (entries.isEmpty) {
      return _SettingsSurface(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Text(
            context.localeText(
              '当前没有已启用的候选链路',
              'No candidate link groups are enabled',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: context.mutedText),
          ),
        ),
      );
    }

    return _SettingsSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var groupIndex = 0;
              groupIndex < entries.length;
              groupIndex++) ...[
            if (groupIndex > 0)
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: context.faintBorder,
              ),
            _CandidateGroupContent(
              group: entries[groupIndex].key,
              results: entries[groupIndex].value,
              activeUrl: activeUrl,
              switchingUrl: switchingUrl,
              unavailableExpanded: expandedUnavailableGroups.contains(
                entries[groupIndex].key,
              ),
              onToggleUnavailable: () =>
                  onToggleUnavailable(entries[groupIndex].key),
              onSwitch: onSwitch,
            ),
          ],
        ],
      ),
    );
  }

  int _orderIndex(FnConnectCandidateGroup group) {
    final index = order.indexOf(group);
    return index < 0 ? order.length : index;
  }
}

class _CandidateGroupContent extends StatelessWidget {
  const _CandidateGroupContent({
    required this.group,
    required this.results,
    required this.activeUrl,
    required this.switchingUrl,
    required this.unavailableExpanded,
    required this.onToggleUnavailable,
    required this.onSwitch,
  });

  final FnConnectCandidateGroup group;
  final List<FnConnectCandidateResult> results;
  final String activeUrl;
  final String? switchingUrl;
  final bool unavailableExpanded;
  final VoidCallback onToggleUnavailable;
  final ValueChanged<FnConnectCandidate> onSwitch;

  @override
  Widget build(BuildContext context) {
    final reachable = results.where((item) => item.reachable).toList();
    final unavailable = results.where((item) => !item.reachable).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Text(
            _groupTitle(context, group),
            style: TextStyle(
              color: context.mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ..._buildCandidateRows(context, reachable),
        if (unavailable.isNotEmpty) ...[
          _UnavailableToggle(
            count: unavailable.length,
            expanded: unavailableExpanded,
            onTap: onToggleUnavailable,
          ),
          if (unavailableExpanded) ..._buildCandidateRows(context, unavailable),
        ],
        const SizedBox(height: 6),
      ],
    );
  }

  List<Widget> _buildCandidateRows(
    BuildContext context,
    List<FnConnectCandidateResult> candidates,
  ) {
    final byIp = <String?, List<FnConnectCandidateResult>>{};
    for (final result in candidates) {
      byIp.putIfAbsent(result.candidate.ipLabel, () => []).add(result);
    }
    final entries = byIp.entries.toList();
    final widgets = <Widget>[];
    for (var entryIndex = 0; entryIndex < entries.length; entryIndex++) {
      if (entryIndex > 0) {
        widgets.add(
          Divider(
            height: 9,
            indent: 56,
            endIndent: 16,
            color: context.faintBorder,
          ),
        );
      }
      for (final result in entries[entryIndex].value) {
        widgets.add(
          _CandidateRow(
            result: result,
            active: ApiClient.normalizeServerUrl(result.candidate.appBaseUrl) ==
                ApiClient.normalizeServerUrl(activeUrl),
            switching: switchingUrl == result.candidate.rootUrl,
            onTap: result.reachable ? () => onSwitch(result.candidate) : null,
          ),
        );
      }
    }
    return widgets;
  }
}

class _UnavailableToggle extends StatelessWidget {
  const _UnavailableToggle({
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  final int count;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(
        expanded ? Icons.unfold_less_rounded : Icons.unfold_more_rounded,
        color: context.mutedText,
      ),
      title: Text(
        expanded
            ? context.localeText('收起不可用连接', 'Hide unavailable links')
            : context.localeText(
                '展开 $count 个不可用连接',
                'Show $count unavailable links',
              ),
      ),
      trailing: Icon(
        expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
        color: context.mutedText,
      ),
    );
  }
}

class _CandidateRow extends StatelessWidget {
  const _CandidateRow({
    required this.result,
    required this.active,
    required this.switching,
    required this.onTap,
  });

  final FnConnectCandidateResult result;
  final bool active;
  final bool switching;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final reachable = result.reachable;
    return Opacity(
      opacity: reachable ? 1 : 0.55,
      child: ListTile(
        enabled: reachable,
        onTap: active || switching ? null : onTap,
        leading: Icon(
          reachable ? Icons.check_circle_rounded : Icons.cancel_rounded,
          color: reachable ? Colors.green.shade600 : Colors.red.shade400,
        ),
        title: Text(result.candidate.description),
        subtitle: Text(
          reachable
              ? context.localeText(
                  '可连接 · ${result.latency.inMilliseconds} ms',
                  'Reachable · ${result.latency.inMilliseconds} ms',
                )
              : result.localizedErrorText(chinese: !context.isEnglishLocale),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: switching
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : active
                ? const Icon(Icons.check_rounded, color: AppColors.primary600)
                : reachable
                    ? Icon(Icons.swap_horiz_rounded, color: context.mutedText)
                    : null,
      ),
    );
  }
}

class _EmptyCandidates extends StatelessWidget {
  const _EmptyCandidates();

  @override
  Widget build(BuildContext context) {
    return _SettingsSurface(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(Icons.radar_rounded, size: 30, color: context.mutedText),
            const SizedBox(height: 10),
            Text(
              context.localeText('尚未探测候选链路', 'No probe results yet'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            Text(
              context.localeText(
                '点击下方按钮开始全量探测',
                'Use the button below to probe all links',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.mutedText, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

String _groupTitle(BuildContext context, FnConnectCandidateGroup group) {
  return switch (group) {
    FnConnectCandidateGroup.lan => context.localeText('内网', 'LAN'),
    FnConnectCandidateGroup.publicIpv6 =>
      context.localeText('公网 IPv6', 'Public IPv6'),
    FnConnectCandidateGroup.publicIpv4 =>
      context.localeText('公网 IPv4', 'Public IPv4'),
    FnConnectCandidateGroup.relay => context.localeText('中继', 'Relay'),
  };
}

String _groupSubtitle(BuildContext context, FnConnectCandidateGroup group) {
  return switch (group) {
    FnConnectCandidateGroup.lan =>
      context.localeText('局域网直连，延迟最低', 'Direct, lowest latency'),
    FnConnectCandidateGroup.publicIpv6 =>
      context.localeText('IPv6 直连', 'Direct IPv6 connection'),
    FnConnectCandidateGroup.publicIpv4 =>
      context.localeText('运营商公网地址直连', 'Direct public IPv4 connection'),
    FnConnectCandidateGroup.relay =>
      context.localeText('飞牛转发，兜底链路', 'Via fnOS, fallback'),
  };
}

IconData _groupIcon(FnConnectCandidateGroup group) {
  return switch (group) {
    FnConnectCandidateGroup.lan => Icons.lan_outlined,
    FnConnectCandidateGroup.publicIpv6 => Icons.language_rounded,
    FnConnectCandidateGroup.publicIpv4 => Icons.public_rounded,
    FnConnectCandidateGroup.relay => Icons.cloud_outlined,
  };
}
