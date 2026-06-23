part of 'personalization_page.dart';

class _AccountSection extends StatelessWidget {
  const _AccountSection({
    required this.usernameController,
    required this.passwordController,
    required this.saving,
    required this.saved,
    required this.onSave,
  });

  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool saving;
  final bool saved;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      icon: Icons.person_rounded,
      iconColor: AppColors.primary500,
      title: '账号信息',
      trailing: _SavedBadge(visible: saved, label: '更新成功', compact: true),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final fields = [
            _TextSettingField(
              controller: usernameController,
              label: '用户名',
              icon: Icons.person_rounded,
            ),
            _TextSettingField(
              controller: passwordController,
              label: '修改密码 (留空则不修改)',
              hintText: '新密码',
              icon: Icons.key_rounded,
              obscureText: true,
            ),
          ];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              compact
                  ? Column(
                      children: [
                        for (final field in fields) ...[
                          field,
                          if (field != fields.last) const SizedBox(height: 14),
                        ],
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: fields.first),
                        const SizedBox(width: 16),
                        Expanded(child: fields.last),
                      ],
                    ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: PrimaryButton(
                  label: '更新账号信息',
                  icon: Icons.save_rounded,
                  loading: saving,
                  onPressed: onSave,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection({
    required this.theme,
    required this.onTheme,
  });

  final String theme;
  final ValueChanged<String> onTheme;

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      icon: Icons.monitor_rounded,
      iconColor: Colors.blue,
      title: '外观展示',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          const options = [
            _ThemeOption(
              id: 'light',
              icon: Icons.light_mode_rounded,
              label: '浅色模式',
            ),
            _ThemeOption(
              id: 'dark',
              icon: Icons.dark_mode_rounded,
              label: '深色模式',
            ),
            _ThemeOption(
              id: 'system',
              icon: Icons.monitor_rounded,
              label: '跟随系统',
            ),
          ];
          return GridView.count(
            crossAxisCount: 3,
            crossAxisSpacing: compact ? 8 : 12,
            mainAxisSpacing: compact ? 8 : 12,
            childAspectRatio: compact ? 1.06 : 2.3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final item in options)
                _ThemeChoiceCard(
                  option: item,
                  selected: theme == item.id ||
                      (theme == 'auto' && item.id == 'system'),
                  onTap: () => onTheme(item.id),
                  compact: compact,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _HomeLayoutSection extends StatelessWidget {
  const _HomeLayoutSection({
    required this.value,
    required this.onChanged,
  });

  final HomeLayoutSettings value;
  final ValueChanged<HomeLayoutSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = [
      _HomeLayoutItem(
        title: '顶部推荐',
        description: '展示继续收听和可点击切换的大封面 Hero',
        checked: value.showHero,
        onTap: () => onChanged(value.copyWith(showHero: !value.showHero)),
      ),
      _HomeLayoutItem(
        title: '听书数据',
        description: '展示最近已听、收藏、书单和当前播放',
        checked: value.showStats,
        onTap: () => onChanged(value.copyWith(showStats: !value.showStats)),
      ),
      _HomeLayoutItem(
        title: '为你推荐',
        description: '展示收藏、最近收听和最近上新的综合推荐',
        checked: value.showRecommended,
        onTap: () => onChanged(
          value.copyWith(showRecommended: !value.showRecommended),
        ),
      ),
      _HomeLayoutItem(
        title: '最近收听',
        description: '展示首页内的最近收听卡片',
        checked: value.showRecent,
        onTap: () => onChanged(value.copyWith(showRecent: !value.showRecent)),
      ),
      _HomeLayoutItem(
        title: '最近上新',
        description: '展示最新加入馆藏的作品列表',
        checked: value.showRecentlyAdded,
        onTap: () => onChanged(
          value.copyWith(showRecentlyAdded: !value.showRecentlyAdded),
        ),
      ),
      _HomeLayoutItem(
        title: '书单与系列',
        description: '展示我的书单和系列入口',
        checked: value.showCollections,
        onTap: () => onChanged(
          value.copyWith(showCollections: !value.showCollections),
        ),
      ),
    ];

    return _SettingsSection(
      icon: Icons.home_rounded,
      iconColor: const Color(0xff10b981),
      title: '首页调整',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth < 720 ? 1 : 2;
          const spacing = 12.0;
          final width =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final item in items)
                SizedBox(
                  width: width,
                  child: item,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _HomeLayoutItem extends StatelessWidget {
  const _HomeLayoutItem({
    required this.title,
    required this.description,
    required this.checked,
    required this.onTap,
  });

  final String title;
  final String description;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = checked
        ? (context.isDark
            ? AppColors.primary700.withValues(alpha: 0.16)
            : AppColors.primary50.withValues(alpha: 0.8))
        : (context.isDark
            ? AppColors.slate800.withValues(alpha: 0.5)
            : AppColors.slate50);
    final border = checked
        ? (context.isDark
            ? AppColors.primary700.withValues(alpha: 0.55)
            : AppColors.primary200)
        : context.faintBorder;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.mutedText,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              _CustomSwitch(value: checked, onChanged: (_) => onTap()),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaybackSection extends StatelessWidget {
  const _PlaybackSection({
    required this.playbackSpeed,
    required this.autoPreload,
    required this.autoCache,
    required this.ignoreAudioFocus,
    required this.showAudioFocusSetting,
    required this.onSpeed,
    required this.onAutoPreload,
    required this.onAutoCache,
    required this.onIgnoreAudioFocus,
  });

  final double playbackSpeed;
  final bool autoPreload;
  final bool autoCache;
  final bool ignoreAudioFocus;
  final bool showAudioFocusSetting;
  final ValueChanged<double> onSpeed;
  final ValueChanged<bool> onAutoPreload;
  final ValueChanged<bool> onAutoCache;
  final ValueChanged<bool> onIgnoreAudioFocus;

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      icon: Icons.fast_forward_rounded,
      iconColor: Colors.orange,
      title: '播放偏好',
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
              final speedPicker = _SpeedPicker(
                speed: playbackSpeed,
                onSpeed: onSpeed,
                expanded: compact,
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SettingCopy(
                      title: '默认播放倍速',
                      subtitle: '所有书籍开始播放时的初始倍速',
                    ),
                    const SizedBox(height: 14),
                    SizedBox(width: double.infinity, child: speedPicker),
                  ],
                );
              }
              return Row(
                children: [
                  const Expanded(
                    child: _SettingCopy(
                      title: '默认播放倍速',
                      subtitle: '所有书籍开始播放时的初始倍速',
                    ),
                  ),
                  speedPicker,
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          _SettingDivider(),
          _ToggleSettingRow(
            title: '自动预加载下一章',
            subtitle: '播放当前章节时，后台自动缓冲下一章节',
            value: autoPreload,
            onChanged: onAutoPreload,
          ),
          _SettingDivider(),
          _ToggleSettingRow(
            title: '服务端自动缓存 (WebDAV)',
            subtitle: '播放当前章节时，通知服务器预先缓存下一章节',
            value: autoCache,
            onChanged: onAutoCache,
          ),
          if (showAudioFocusSetting) ...[
            _SettingDivider(),
            _ToggleSettingRow(
              title: '与其他应用同时播放',
              subtitle: '允许和其他应用声音共存',
              value: ignoreAudioFocus,
              onChanged: onIgnoreAudioFocus,
            ),
          ],
        ],
      ),
    );
  }
}

class _WidgetSection extends StatelessWidget {
  const _WidgetSection({
    required this.controller,
    required this.embedType,
    required this.iframeCode,
    required this.fixedBottomCode,
    required this.floatingCode,
    required this.onEmbedType,
    required this.onSaveCss,
    required this.onCopy,
  });

  final TextEditingController controller;
  final String embedType;
  final String iframeCode;
  final String fixedBottomCode;
  final String floatingCode;
  final ValueChanged<String> onEmbedType;
  final VoidCallback onSaveCss;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      icon: Icons.code_rounded,
      iconColor: Colors.purple,
      title: '外挂组件 (Widget)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '自定义 CSS 注入',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '针对 Widget 生效',
                style: TextStyle(
                  color: context.tertiaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            minLines: 4,
            maxLines: 6,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(
              hintText: '.widget-mode { background: transparent !important; }',
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onSaveCss,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('保存 CSS'),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.isDark ? AppColors.slate800 : AppColors.slate50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.faintBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 640;
                    final title = Text(
                      '嵌入代码 (Iframe)',
                      style: TextStyle(
                        color: context.tertiaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                    final toggle = _EmbedTypeToggle(
                      value: embedType,
                      onChanged: onEmbedType,
                    );
                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          title,
                          const SizedBox(height: 10),
                          toggle,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: title),
                        toggle,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                _CodeBlock(code: iframeCode, onCopy: () => onCopy(iframeCode)),
                const SizedBox(height: 12),
                _WidgetSecurityHint(embedType: embedType),
                const SizedBox(height: 18),
                _SettingDivider(),
                Text(
                  '布局代码参考 (直接复制)',
                  style: TextStyle(
                    color: context.tertiaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 780;
                    final blocks = [
                      _LayoutCodePanel(
                        title: '1. 吸底模式 (Fixed Bottom)',
                        code: fixedBottomCode,
                        onCopy: () => onCopy(fixedBottomCode),
                      ),
                      _LayoutCodePanel(
                        title: '2. 右下角悬浮 (Floating Right)',
                        code: floatingCode,
                        onCopy: () => onCopy(floatingCode),
                      ),
                    ];
                    if (compact) {
                      return Column(
                        children: [
                          blocks.first,
                          const SizedBox(height: 12),
                          blocks.last,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: blocks.first),
                        const SizedBox(width: 12),
                        Expanded(child: blocks.last),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
