part of 'admin_users_page.dart';

class _UsersPanel extends StatelessWidget {
  const _UsersPanel({
    required this.users,
    required this.currentUserId,
    required this.onEdit,
    required this.onDelete,
  });

  final List<User> users;
  final String? currentUserId;
  final ValueChanged<User> onEdit;
  final ValueChanged<User> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.faintBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(context.isDark ? 0.12 : 0.035),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 760) {
            return Column(
              children: [
                for (var i = 0; i < users.length; i++) ...[
                  _UserMobileCard(
                    user: users[i],
                    current: users[i].id == currentUserId,
                    onEdit: () => onEdit(users[i]),
                    onDelete: () => onDelete(users[i]),
                  ),
                  if (i != users.length - 1)
                    Divider(height: 1, color: context.faintBorder),
                ],
              ],
            );
          }

          return Table(
            columnWidths: const {
              0: FlexColumnWidth(2.2),
              1: FlexColumnWidth(1.1),
              2: FlexColumnWidth(1.25),
              3: FixedColumnWidth(132),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: context.isDark
                      ? AppColors.slate800.withOpacity(0.5)
                      : AppColors.slate50,
                ),
                children: const [
                  _UserHeaderCell('用户信息'),
                  _UserHeaderCell('角色'),
                  _UserHeaderCell('创建时间'),
                  _UserHeaderCell('操作', alignRight: true),
                ],
              ),
              for (final user in users)
                TableRow(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: context.faintBorder),
                    ),
                  ),
                  children: [
                    _UserInfoCell(user: user),
                    _UserRoleCell(role: user.role),
                    _UserDateCell(date: user.createdAt),
                    _UserActionCell(
                      current: user.id == currentUserId,
                      onEdit: () => onEdit(user),
                      onDelete: () => onDelete(user),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _UserHeaderCell extends StatelessWidget {
  const _UserHeaderCell(this.label, {this.alignRight = false});

  final String label;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Text(
        label,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: TextStyle(
          color: context.mutedText,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _UserInfoCell extends StatelessWidget {
  const _UserInfoCell({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final initial = user.username.isEmpty
        ? 'U'
        : user.username.substring(0, 1).toUpperCase();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary100,
            foregroundColor: AppColors.primary600,
            child: Text(
              initial,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  'ID: ${_shortUserId(user.id)}',
                  style: TextStyle(
                    color: context.tertiaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserRoleCell extends StatelessWidget {
  const _UserRoleCell({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 19),
      child: Align(
        alignment: Alignment.centerLeft,
        child: _UserRoleBadge(role: role),
      ),
    );
  }
}

class _UserDateCell extends StatelessWidget {
  const _UserDateCell({required this.date});

  final String? date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_rounded,
            size: 14,
            color: context.tertiaryText,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _formatUserDate(date),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.tertiaryText,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserActionCell extends StatelessWidget {
  const _UserActionCell({
    required this.current,
    required this.onEdit,
    required this.onDelete,
  });

  final bool current;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _UserIconButton(
            icon: Icons.edit_rounded,
            activeColor: AppColors.primary600,
            onPressed: onEdit,
          ),
          const SizedBox(width: 6),
          _UserIconButton(
            icon: Icons.delete_outline_rounded,
            activeColor: const Color(0xffef4444),
            onPressed: current ? null : onDelete,
          ),
        ],
      ),
    );
  }
}

class _UserMobileCard extends StatelessWidget {
  const _UserMobileCard({
    required this.user,
    required this.current,
    required this.onEdit,
    required this.onDelete,
  });

  final User user;
  final bool current;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final initial = user.username.isEmpty
        ? 'U'
        : user.username.substring(0, 1).toUpperCase();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary100,
                foregroundColor: AppColors.primary600,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'ID: ${_shortUserId(user.id, dotted: false)}',
                      style: TextStyle(
                        color: context.tertiaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _UserIconButton(
                icon: Icons.edit_rounded,
                activeColor: AppColors.primary600,
                onPressed: onEdit,
              ),
              const SizedBox(width: 6),
              _UserIconButton(
                icon: Icons.delete_outline_rounded,
                activeColor: const Color(0xffef4444),
                onPressed: current ? null : onDelete,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _UserRoleBadge(role: user.role, mobile: true),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: context.tertiaryText,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatUserDate(user.createdAt),
                    style: TextStyle(
                      color: context.tertiaryText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserRoleBadge extends StatelessWidget {
  const _UserRoleBadge({required this.role, this.mobile = false});

  final String role;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    final admin = role == 'admin';
    final color = admin ? const Color(0xff9333ea) : AppColors.primary600;
    final bg = admin ? const Color(0xfff3e8ff) : AppColors.primary50;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: mobile ? 7 : 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(mobile ? 12 : 99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            admin ? Icons.verified_user_rounded : Icons.shield_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            admin ? '管理员' : '普通用户',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserIconButton extends StatelessWidget {
  const _UserIconButton({
    required this.icon,
    required this.activeColor,
    required this.onPressed,
  });

  final IconData icon;
  final Color activeColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return IconButton(
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor:
            context.isDark ? AppColors.slate800 : AppColors.slate50,
        foregroundColor: enabled ? context.mutedText : AppColors.slate300,
        disabledForegroundColor: AppColors.slate300,
        minimumSize: const Size(40, 40),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      hoverColor: activeColor.withOpacity(0.08),
      icon: Icon(
        icon,
        size: 20,
        color: enabled ? context.mutedText : AppColors.slate300,
      ),
    );
  }
}

class _CreateUserButton extends StatelessWidget {
  const _CreateUserButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary600,
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: AppColors.primary500.withOpacity(0.3),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          '创建用户',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _UserRoleChoice extends StatelessWidget {
  const _UserRoleChoice({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.08) : context.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color.withOpacity(0.3) : context.faintBorder,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : context.mutedText,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
