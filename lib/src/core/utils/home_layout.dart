import '../models/models.dart';

class HomeLayoutSettings {
  const HomeLayoutSettings({
    this.showHero = true,
    this.showStats = true,
    this.showRecommended = true,
    this.showRecent = true,
    this.showRecentlyAdded = true,
    this.showCollections = true,
  });

  final bool showHero;
  final bool showStats;
  final bool showRecommended;
  final bool showRecent;
  final bool showRecentlyAdded;
  final bool showCollections;

  factory HomeLayoutSettings.fromSettings(Map<String, dynamic> settings) {
    final settingsJson = asMap(settings['settings_json']);
    final source = asMap(
      settings['home_layout'] ?? settingsJson['home_layout'],
    );
    return HomeLayoutSettings(
      showHero: _bool(source, 'show_hero', fallback: true),
      showStats: _bool(source, 'show_stats', fallback: true),
      showRecommended: _bool(source, 'show_recommended', fallback: true),
      showRecent: _bool(source, 'show_recent', fallback: true),
      showRecentlyAdded: _bool(source, 'show_recently_added', fallback: true),
      showCollections: _bool(source, 'show_collections', fallback: true),
    );
  }

  HomeLayoutSettings copyWith({
    bool? showHero,
    bool? showStats,
    bool? showRecommended,
    bool? showRecent,
    bool? showRecentlyAdded,
    bool? showCollections,
  }) {
    return HomeLayoutSettings(
      showHero: showHero ?? this.showHero,
      showStats: showStats ?? this.showStats,
      showRecommended: showRecommended ?? this.showRecommended,
      showRecent: showRecent ?? this.showRecent,
      showRecentlyAdded: showRecentlyAdded ?? this.showRecentlyAdded,
      showCollections: showCollections ?? this.showCollections,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'show_hero': showHero,
      'show_stats': showStats,
      'show_recommended': showRecommended,
      'show_recent': showRecent,
      'show_recently_added': showRecentlyAdded,
      'show_collections': showCollections,
    };
  }

  bool get hasHeroArea => showHero || showStats;
}

bool _bool(
  Map<String, dynamic> source,
  String key, {
  required bool fallback,
}) {
  final value = source[key];
  return value is bool ? value : fallback;
}
