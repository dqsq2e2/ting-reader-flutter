import '_helpers.dart';

class AdminStatistics {
  const AdminStatistics({
    required this.overview,
    this.libraryBreakdown = const [],
    this.userActivity = const [],
    this.recentActivity = const [],
    this.topBooks = const [],
    this.generatedAt,
  });

  final Map<String, dynamic> overview;
  final List<Map<String, dynamic>> libraryBreakdown;
  final List<Map<String, dynamic>> userActivity;
  final List<Map<String, dynamic>> recentActivity;
  final List<Map<String, dynamic>> topBooks;
  final String? generatedAt;

  factory AdminStatistics.fromJson(Map<String, dynamic> json) {
    return AdminStatistics(
      overview: asMap(json['overview']),
      libraryBreakdown: asMapList(json['library_breakdown']),
      userActivity: asMapList(json['user_activity']),
      recentActivity: asMapList(json['recent_activity']),
      topBooks: asMapList(json['top_books']),
      generatedAt: readString(json, 'generated_at'),
    );
  }
}
