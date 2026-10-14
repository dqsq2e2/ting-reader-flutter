import 'dart:async';

/// Owns both minute and episode sleep policies independently of player views.
/// Minutes count only while playing; either policy replaces the other.
class PlaybackSleep {
  PlaybackSleep(
      {required this.isPlaying,
      required this.onChanged,
      required this.onExpire});
  final bool Function() isPlaying;
  final void Function() onChanged;
  final Future<void> Function() onExpire;
  Timer? _timer;
  int? seconds;
  int? episodes;
  String? _chapter;
  bool _disposed = false;

  void minutes(int value) {
    if (_disposed || value <= 0) return;
    _clear();
    seconds = value * 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed || !isPlaying()) return;
      final next = (seconds ?? 0) - 1;
      if (next <= 0) {
        _clear();
        onChanged();
        unawaited(onExpire());
      } else {
        seconds = next;
        onChanged();
      }
    });
    onChanged();
  }

  void chapterCount(int value, String? currentChapter) {
    if (_disposed || value <= 0) return;
    _clear();
    episodes = value;
    _chapter = currentChapter;
    onChanged();
  }

  bool chapterChanged(String? id) {
    if (_disposed || id == null || id == _chapter) return false;
    _chapter = id;
    final remaining = episodes;
    if (remaining == null) return false;
    if (remaining <= 1) {
      _clear();
      onChanged();
      return true;
    }
    episodes = remaining - 1;
    onChanged();
    return false;
  }

  void cancel() {
    if (_disposed) return;
    _clear();
    onChanged();
  }

  void _clear() {
    _timer?.cancel();
    _timer = null;
    seconds = null;
    episodes = null;
    _chapter = null;
  }

  void dispose() {
    _disposed = true;
    _clear();
  }
}
