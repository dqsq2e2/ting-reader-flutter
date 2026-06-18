import 'package:flutter/widgets.dart';

import '../state/app_state.dart';
import '../state/download_state.dart';
import '../state/player_state.dart';

class AppScope extends StatefulWidget {
  const AppScope({
    super.key,
    required this.appState,
    required this.downloadState,
    required this.playerState,
    required this.child,
  });

  final AppState appState;
  final DownloadState downloadState;
  final PlayerState playerState;
  final Widget child;

  static AppState appOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_AppStateScope>();
    assert(scope != null, 'No AppScope found in context');
    return scope!.appState;
  }

  static PlayerState playerOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_PlayerStateScope>();
    assert(scope != null, 'No PlayerScope found in context');
    return scope!.playerState;
  }

  static DownloadState downloadOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_DownloadStateScope>();
    assert(scope != null, 'No DownloadScope found in context');
    return scope!.downloadState;
  }

  @override
  State<AppScope> createState() => _AppScopeState();
}

class _AppScopeState extends State<AppScope> {
  @override
  Widget build(BuildContext context) {
    return _AppStateScope(
      appState: widget.appState,
      child: _DownloadStateScope(
        downloadState: widget.downloadState,
        child: _PlayerStateScope(
          playerState: widget.playerState,
          child: widget.child,
        ),
      ),
    );
  }
}

class _AppStateScope extends InheritedNotifier<AppState> {
  const _AppStateScope({
    required this.appState,
    required super.child,
  }) : super(notifier: appState);

  final AppState appState;
}

class _PlayerStateScope extends InheritedNotifier<PlayerState> {
  const _PlayerStateScope({
    required this.playerState,
    required super.child,
  }) : super(notifier: playerState);

  final PlayerState playerState;
}

class _DownloadStateScope extends InheritedNotifier<DownloadState> {
  const _DownloadStateScope({
    required this.downloadState,
    required super.child,
  }) : super(notifier: downloadState);

  final DownloadState downloadState;
}
