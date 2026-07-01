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
    final l10n = context.l10n;
    return _SettingsSection(
      icon: Icons.person_rounded,
      iconColor: AppColors.primary500,
      title: l10n.settingsAccount,
      trailing: _SavedBadge(
        visible: saved,
        label: l10n.settingsAccountUpdated,
        compact: true,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final fields = [
            _TextSettingField(
              controller: usernameController,
              label: l10n.settingsUsername,
              icon: Icons.person_rounded,
            ),
            _TextSettingField(
              controller: passwordController,
              label: l10n.settingsPassword,
              hintText: l10n.settingsNewPassword,
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
                  label: l10n.settingsUpdateAccount,
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
          return Row(
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
                if (i != options.length - 1) SizedBox(width: compact ? 8 : 12),
              ],
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
  });

  final String language;
  final ValueChanged<String> onLanguage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _SettingsSection(
      icon: Icons.language_rounded,
      iconColor: Colors.cyan,
      title: l10n.settingsLanguage,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final copy = Text(
            l10n.settingsLanguageDescription,
            style: TextStyle(color: context.mutedText, fontSize: 13),
          );
          final dropdown = _LanguageDropdown(
            value: language,
            onChanged: onLanguage,
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
            children: [
              Expanded(child: copy),
              const SizedBox(width: 20),
              SizedBox(width: 240, child: dropdown),
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
