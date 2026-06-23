part of '../mini_player.dart';

double _playerThemeLuminance(Color color) {
  return 0.299 * color.r + 0.587 * color.g + 0.114 * color.b;
}


bool _isPlayerThemeLight(Color color) => _playerThemeLuminance(color) > 0.65;


String _formatPlaybackSpeed(double speed) {
  if ((speed - speed.roundToDouble()).abs() < 0.001) {
    return '${speed.round()}x';
  }
  var text = speed.toStringAsFixed(2);
  text = text.replaceFirst(RegExp(r'0+$'), '');
  text = text.replaceFirst(RegExp(r'\.$'), '');
  return '${text}x';
}


