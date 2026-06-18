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
    final settingsJson = asMap(
      settings['settings_json'] ?? settings['settingsJson'],
    );
    final source = asMap(
      settings['homeLayout'] ??
          settings['home_layout'] ??
          settingsJson['homeLayout'] ??
          settingsJson['home_layout'],
    );
    return HomeLayoutSettings(
      showHero: _bool(source, 'showHero', fallback: true),
      showStats: _bool(source, 'showStats', fallback: true),
      showRecommended: _bool(source, 'showRecommended', fallback: true),
      showRecent: _bool(source, 'showRecent', fallback: true),
      showRecentlyAdded: _bool(source, 'showRecentlyAdded', fallback: true),
      showCollections: _bool(source, 'showCollections', fallback: true),
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
      'showHero': showHero,
      'showStats': showStats,
      'showRecommended': showRecommended,
      'showRecent': showRecent,
      'showRecentlyAdded': showRecentlyAdded,
      'showCollections': showCollections,
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
