part of 'personalization_page.dart';

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection({
    required this.theme,
    required this.onTheme,
    required this.toolMenuEnabled,
    required this.onToolMenuEnabled,
  });

  final String theme;
  final ValueChanged<String> onTheme;
  final bool toolMenuEnabled;
  final ValueChanged<bool> onToolMenuEnabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _SettingsSection(
      icon: Icons.monitor_rounded,
      iconColor: Colors.blue,
      title: l10n.settingsAppearance,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final options = [
            _ThemeOption(
              id: 'light',
              icon: Icons.light_mode_rounded,
              label: l10n.settingsLight,
            ),
            _ThemeOption(
              id: 'dark',
              icon: Icons.dark_mode_rounded,
              label: l10n.settingsDark,
            ),
            _ThemeOption(
              id: 'system',
              icon: Icons.monitor_rounded,
              label: l10n.settingsSystem,
            ),
          ];
          return Column(
            children: [
              Row(
                children: [
                  for (var i = 0; i < options.length; i++) ...[
                    Expanded(
                      child: _ThemeChoiceCard(
                        option: options[i],
                        selected: theme == options[i].id ||
                            (theme == 'auto' && options[i].id == 'system'),
                        onTap: () => onTheme(options[i].id),
                        compact: compact,
                      ),
                    ),
                    if (i != options.length - 1)
                      SizedBox(width: compact ? 8 : 12),
                  ],
                ],
              ),
              const SizedBox(height: 22),
              _SettingDivider(),
              _ToggleSettingRow(
                title: l10n.settingsPluginToolMenu,
                subtitle: l10n.settingsPluginToolMenuDescription,
                value: toolMenuEnabled,
                onChanged: onToolMenuEnabled,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LanguageSection extends StatelessWidget {
  const _LanguageSection({
    required this.language,
    required this.onLanguage,
    this.applicationTimeZone,
    this.timeZoneSaving = false,
    this.onTimeZoneChanged,
  });

  final String language;
  final ValueChanged<String> onLanguage;
  final String? applicationTimeZone;
  final bool timeZoneSaving;
  final ValueChanged<String>? onTimeZoneChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _SettingsSection(
      icon: Icons.language_rounded,
      iconColor: Colors.cyan,
      title: l10n.settingsLanguage,
      showHeader: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LanguageSettingRow(
            language: language,
            onLanguage: onLanguage,
          ),
          if (applicationTimeZone != null && onTimeZoneChanged != null) ...[
            const SizedBox(height: 22),
            _SettingDivider(),
            const SizedBox(height: 22),
            _ApplicationTimeZoneSettingRow(
              value: applicationTimeZone!,
              saving: timeZoneSaving,
              onChanged: onTimeZoneChanged!,
            ),
          ],
        ],
      ),
    );
  }
}

const _settingsSelectWidth = 280.0;

class _SettingsSelectRow extends StatelessWidget {
  const _SettingsSelectRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.dropdown,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final Widget dropdown;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(color: context.mutedText, fontSize: 13),
            ),
          ],
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              copy,
              const SizedBox(height: 14),
              dropdown,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: copy),
            const SizedBox(width: 20),
            SizedBox(width: _settingsSelectWidth, child: dropdown),
          ],
        );
      },
    );
  }
}

class _LanguageSettingRow extends StatelessWidget {
  const _LanguageSettingRow({
    required this.language,
    required this.onLanguage,
  });

  final String language;
  final ValueChanged<String> onLanguage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _SettingsSelectRow(
      icon: Icons.translate_rounded,
      iconColor: Colors.cyan,
      title: l10n.settingsLanguage,
      description: l10n.settingsLanguageDescription,
      dropdown: _LanguageDropdown(
        value: language,
        onChanged: onLanguage,
      ),
    );
  }
}

class _ApplicationTimeZoneSettingRow extends StatelessWidget {
  const _ApplicationTimeZoneSettingRow({
    required this.value,
    required this.saving,
    required this.onChanged,
  });

  final String value;
  final bool saving;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final options = applicationTimeZoneOptions;
    final selected =
        options.contains(value) ? value : defaultApplicationTimeZone;
    final dropdown = DropdownButtonFormField<String>(
      initialValue: selected,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.public_rounded, size: 19),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.faintBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.faintBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary600, width: 1.5),
        ),
      ),
      items: options
          .map((zone) => DropdownMenuItem(value: zone, child: Text(zone)))
          .toList(),
      onChanged: saving
          ? null
          : (next) {
              if (next != null) onChanged(next);
            },
    );
    return _SettingsSelectRow(
      icon: Icons.public_rounded,
      iconColor: Colors.indigo,
      title: l10n.settingsTimeZone,
      description: l10n.settingsTimeZoneDescription,
      dropdown: dropdown,
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
    final l10n = context.l10n;
    final items = [
      _HomeLayoutItem(
        title: l10n.settingsHomeHero,
        description: l10n.settingsHomeHeroDescription,
        checked: value.showHero,
        onTap: () => onChanged(value.copyWith(showHero: !value.showHero)),
      ),
      _HomeLayoutItem(
        title: l10n.settingsHomeStats,
        description: l10n.settingsHomeStatsDescription,
        checked: value.showStats,
        onTap: () => onChanged(value.copyWith(showStats: !value.showStats)),
      ),
      _HomeLayoutItem(
        title: l10n.settingsHomeRecommended,
        description: l10n.settingsHomeRecommendedDescription,
        checked: value.showRecommended,
        onTap: () => onChanged(
          value.copyWith(showRecommended: !value.showRecommended),
        ),
      ),
      _HomeLayoutItem(
        title: l10n.settingsHomeRecent,
        description: l10n.settingsHomeRecentDescription,
        checked: value.showRecent,
        onTap: () => onChanged(value.copyWith(showRecent: !value.showRecent)),
      ),
      _HomeLayoutItem(
        title: l10n.settingsHomeRecentlyAdded,
        description: l10n.settingsHomeRecentlyAddedDescription,
        checked: value.showRecentlyAdded,
        onTap: () => onChanged(
          value.copyWith(showRecentlyAdded: !value.showRecentlyAdded),
        ),
      ),
      _HomeLayoutItem(
        title: l10n.settingsHomeCollections,
        description: l10n.settingsHomeCollectionsDescription,
        checked: value.showCollections,
        onTap: () => onChanged(
          value.copyWith(showCollections: !value.showCollections),
        ),
      ),
    ];

    return _SettingsSection(
      icon: Icons.home_rounded,
      iconColor: const Color(0xff10b981),
      title: l10n.settingsHomeLayout,
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
    final l10n = context.l10n;
    return _SettingsSection(
      icon: Icons.fast_forward_rounded,
      iconColor: Colors.orange,
      title: l10n.settingsPlayback,
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
                    _SettingCopy(
                      title: l10n.settingsPlaybackSpeed,
                      subtitle: l10n.settingsPlaybackSpeedDescription,
                    ),
                    const SizedBox(height: 14),
                    SizedBox(width: double.infinity, child: speedPicker),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: _SettingCopy(
                      title: l10n.settingsPlaybackSpeed,
                      subtitle: l10n.settingsPlaybackSpeedDescription,
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
            title: l10n.settingsAutoPreload,
            subtitle: l10n.settingsAutoPreloadDescription,
            value: autoPreload,
            onChanged: onAutoPreload,
          ),
          _SettingDivider(),
          _ToggleSettingRow(
            title: l10n.settingsAutoCache,
            subtitle: l10n.settingsAutoCacheDescription,
            value: autoCache,
            onChanged: onAutoCache,
          ),
          if (showAudioFocusSetting) ...[
            _SettingDivider(),
            _ToggleSettingRow(
              title: l10n.settingsAudioFocus,
              subtitle: l10n.settingsAudioFocusDescription,
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
    final l10n = context.l10n;
    return _SettingsSection(
      icon: Icons.code_rounded,
      iconColor: Colors.purple,
      title: l10n.settingsWidget,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.settingsCustomCss,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                l10n.settingsWidgetOnly,
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
              label: Text(l10n.settingsSaveCss),
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
                      l10n.settingsEmbedCode,
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
                  l10n.settingsLayoutCode,
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
                        title: l10n.settingsFixedBottom,
                        code: fixedBottomCode,
                        onCopy: () => onCopy(fixedBottomCode),
                      ),
                      _LayoutCodePanel(
                        title: l10n.settingsFloatingRight,
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
