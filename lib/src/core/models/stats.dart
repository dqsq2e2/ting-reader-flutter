import '_helpers.dart';

class Stats {
  const Stats({
    this.totalBooks = 0,
    this.totalChapters = 0,
    this.totalDuration = 0,
    this.lastScanTime,
  });

  final int totalBooks;
  final int totalChapters;
  final int totalDuration;
  final String? lastScanTime;

  factory Stats.fromJson(Map<String, dynamic> json) {
    return Stats(
      totalBooks: readInt(json, 'total_books') ?? 0,
      totalChapters: readInt(json, 'total_chapters') ?? 0,
      totalDuration: readInt(json, 'total_duration') ?? 0,
      lastScanTime: readString(json, 'last_scan_time'),
    );
  }
}
