import 'package:flutter/material.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/widgets/app_asset_graphic.dart';
import '../../state/shell_state.dart';
import '../shell_layout.dart';

class ShellTopBar extends StatelessWidget {
  const ShellTopBar({
    required this.state,
    required this.onNavigate,
    required this.onLogout,
    required this.onMarkAllRead,
    super.key,
  });

  final ShellState state;
  final ValueChanged<String> onNavigate;
  final Future<void> Function() onLogout;
  final Future<void> Function() onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < ui(720);
        final showUserName = constraints.maxWidth >= ui(560);
        final gap = compact ? ui(8) : ui(16);

        return SizedBox(
          height: ui(40),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: ui(324)),
                    child: _buildSearchBox(context),
                  ),
                ),
              ),
              SizedBox(width: gap),
              _buildToolButton(
                context: context,
                child: AppAssetGraphic(
                  AppAssets.shellV2Help,
                  width: ui(24),
                  height: ui(24),
                  fit: BoxFit.contain,
                ),
                onTap: () => _showToast(context, '帮助功能即将上线'),
              ),
              SizedBox(width: gap),
              _buildNotice(context),
              SizedBox(width: gap),
              _buildToolButton(
                context: context,
                child: AppAssetGraphic(
                  AppAssets.shellV2Setting,
                  width: ui(24),
                  height: ui(24),
                  fit: BoxFit.contain,
                ),
                onTap: () => onNavigate(RoutePaths.set),
              ),
              SizedBox(width: gap),
              _buildToolButton(
                context: context,
                child: AppAssetGraphic(
                  AppAssets.shellV2Scan,
                  width: ui(20),
                  height: ui(20),
                  fit: BoxFit.contain,
                ),
                onTap: () => _showToast(context, '扫码功能即将上线'),
              ),
              SizedBox(width: gap),
              _buildUserMenu(context, showUserName: showUserName),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBox(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      height: ui(40),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: ui(14)),
          child: Row(
            children: [
              AppAssetGraphic(
                AppAssets.shellV2Search,
                width: ui(16),
                height: ui(16),
                fit: BoxFit.contain,
              ),
              SizedBox(width: ui(8)),
              Expanded(
                child: Text(
                  '传统音乐',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(14),
                    color: const Color(0xFFD1D1D1),
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w400,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolButton({
    required BuildContext context,
    required Widget child,
    required VoidCallback onTap,
  }) {
    final ui = DashboardScaleScope.of(context).ui;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(ui(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ui(12)),
        child: SizedBox(
          width: ui(40),
          height: ui(40),
          child: Center(child: child),
        ),
      ),
    );
  }

  Widget _buildUserMenu(BuildContext context, {required bool showUserName}) {
    final ui = DashboardScaleScope.of(context).ui;
    final displayName = state.user.displayName.trim().isEmpty
        ? '用户'
        : state.user.displayName.trim();

    return PopupMenuButton<String>(
      offset: Offset(0, ui(44)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      onSelected: (value) async {
        if (value == 'profile') {
          onNavigate(RoutePaths.info);
          return;
        }
        if (value == 'logout') {
          await onLogout();
          if (context.mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              RoutePaths.login,
              (route) => false,
            );
          }
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          value: 'province',
          child: Text(
            state.user.province.isEmpty ? '未设置地区' : state.user.province,
          ),
        ),
        const PopupMenuItem<String>(value: 'profile', child: Text('资料修改')),
        const PopupMenuItem<String>(value: 'logout', child: Text('退出登录')),
      ],
      child: SizedBox(
        height: ui(40),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAvatar(context),
            if (showUserName) ...[
              SizedBox(width: ui(6)),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: ui(96)),
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(16),
                    height: 1,
                    color: const Color(0xFF1A1A1A),
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            SizedBox(width: ui(2)),
            AppAssetGraphic(
              AppAssets.leftNavBottom,
              width: ui(14),
              height: ui(14),
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final fallback = Container(
      width: ui(36),
      height: ui(36),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFE7ECFA), Color(0xFFD9E1F6)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        size: ui(20),
        color: const Color(0xFF7E879C),
      ),
    );
    final avatarWidget = state.user.avatarUrl.isNotEmpty
        ? Image.network(
            state.user.avatarUrl,
            width: ui(36),
            height: ui(36),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => fallback,
          )
        : fallback;

    return Container(
      width: ui(40),
      height: ui(40),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: ClipOval(
        child: SizedBox(width: ui(36), height: ui(36), child: avatarWidget),
      ),
    );
  }

  Widget _buildNotice(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final unread = state.unreadCount;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        _buildToolButton(
          context: context,
          child: AppAssetGraphic(
            AppAssets.shellV2Notice,
            width: ui(24),
            height: ui(24),
            fit: BoxFit.contain,
          ),
          onTap: () => _showNoticeDialog(context),
        ),
        if (unread > 0)
          Positioned(
            right: ui(-6),
            top: ui(-4),
            child: Container(
              height: ui(14),
              constraints: BoxConstraints(minWidth: ui(22)),
              padding: EdgeInsets.symmetric(horizontal: ui(4)),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF04545),
                borderRadius: BorderRadius.circular(ui(20)),
              ),
              child: Text(
                unread > 99 ? '99+' : (unread > 9 ? '$unread+' : '$unread'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: ui(9),
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showNoticeDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: SizedBox(
            width: 360,
            height: 460,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text('通知(${state.noticeItems.length})'),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await onMarkAllRead();
                        },
                        child: const Text('批量已读'),
                      ),
                    ],
                  ),
                  const Divider(height: 1, color: Color(0x14050505)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: state.noticeItems.isEmpty
                        ? const Center(child: Text('暂无通知'))
                        : ListView.builder(
                            itemCount: state.noticeItems.length,
                            itemBuilder: (context, index) {
                              final item = state.noticeItems[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                leading: Image.asset(
                                  _targetIcon(item.targetType),
                                  width: 30,
                                  height: 30,
                                ),
                                title: Text(
                                  item.content,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                subtitle: Text(
                                  item.createTime,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _targetIcon(int targetType) {
    switch (targetType) {
      case 0:
        return AppAssets.shellMsg1;
      case 1:
        return AppAssets.shellMsg2;
      case 2:
        return AppAssets.shellMsg3;
      case 3:
        return AppAssets.shellMsg4;
      default:
        return AppAssets.shellMsg1;
    }
  }

  void _showToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
