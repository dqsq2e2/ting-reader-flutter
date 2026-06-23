import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/app_scope.dart';
import '../../../shared/common/common_widgets.dart';
import '../../../shared/dialogs/dialog_label.dart';

part 'admin_users_panel.dart';
part 'admin_user_dialogs.dart';
part 'admin_user_form_widgets.dart';

class AdminUsersV2Page extends StatefulWidget {
  const AdminUsersV2Page({super.key});

  @override
  State<AdminUsersV2Page> createState() => _AdminUsersV2PageState();
}

class _AdminUsersV2PageState extends State<AdminUsersV2Page> {
  bool _loading = true;
  List<User> _users = [];
  List<Library> _libraries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = AppScope.appOf(context).api;
    try {
      final results = await Future.wait([
        api.get('/api/users'),
        api.get('/api/libraries'),
      ]);
      if (!mounted) return;
      setState(() {
        _users = asMapList(results[0].data).map(User.fromJson).toList();
        _libraries = asMapList(results[1].data).map(Library.fromJson).toList();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openUserDialog([User? user]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _UserFormDialog(
        user: user,
        libraries: _libraries,
      ),
    );

    if (saved == true) await _load();
  }

  Future<void> _delete(User user) async {
    final api = AppScope.appOf(context).api;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmActionDialog(
        title: '删除用户？',
        message: '确定要删除用户 ${user.username} 吗？',
        confirmLabel: '删除',
        confirmColor: const Color(0xffef4444),
      ),
    );
    if (ok != true) return;
    await api.delete('/api/users/${user.id}');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    return PageListView(
      onRefresh: _load,
      children: [
        Padding(
          padding: _userPageHorizontalInset(context),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
              const header = HeaderText(
                icon: Icons.group_rounded,
                title: '用户管理',
                subtitle: '管理系统访问权限与账号',
              );
              final button =
                  _CreateUserButton(onPressed: () => _openUserDialog());
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: header),
                    const SizedBox(height: 20),
                    button,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(child: header),
                  button,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 40),
        Padding(
          padding: _userPageHorizontalInset(context),
          child: _UsersPanel(
            users: _users,
            currentUserId: AppScope.appOf(context).user?.id,
            onEdit: _openUserDialog,
            onDelete: _delete,
          ),
        ),
        const SafeBottomSpacer(),
      ],
    );
  }
}
