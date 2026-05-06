import 'package:flutter/material.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/widgets/app_asset_graphic.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/scaled_dialog.dart';
import '../../state/shell_state.dart';
import '../shell_layout.dart';

import '../../../../core/widgets/app_text.dart';
class ShellTopBar extends StatelessWidget {
  ShellTopBar({
    required this.state,
    required this.onNavigate,
    required this.onLogout,
    required this.onMarkAllRead,
    required this.onLoadProvinces,
    required this.onUpdateProvince,
    super.key,
  });

  final ShellState state;
  final ValueChanged<String> onNavigate;
  final Future<void> Function() onLogout;
  final Future<void> Function() onMarkAllRead;
  final Future<List<String>> Function() onLoadProvinces;
  final Future<String?> Function(String province) onUpdateProvince;

  /// 用户菜单触发按钮的位置 anchor，供自定义 popover 定位使用。
  final GlobalKey _userMenuKey = GlobalKey();

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
                onTap: () => onNavigate(RoutePaths.info),
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
                child: AppText(
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

    return GestureDetector(
      key: _userMenuKey,
      behavior: HitTestBehavior.opaque,
      onTap: () => _openUserMenu(context),
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
                child: AppText(
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

  Future<void> _openUserMenu(BuildContext context) async {
    final triggerBox =
        _userMenuKey.currentContext?.findRenderObject() as RenderBox?;
    if (triggerBox == null) {
      return;
    }
    final overlay = Overlay.of(context, rootOverlay: true);
    final overlayBox = overlay.context.findRenderObject() as RenderBox;
    // 提前抓取当前页面的 DashboardScaleScope，再透传到 root overlay 子树里，
    // 避免菜单 builder 的 context 找不到 scope 而触发 `scope != null` 断言。
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;
    final menuWidth = ui(220);
    final menuHeight = ui(168);

    // 与 1.0 `placement="bottom-end"` 对齐：弹出在按钮右下方。
    final triggerSize = triggerBox.size;
    final bottomRight = triggerBox.localToGlobal(
      triggerSize.bottomRight(Offset.zero),
      ancestor: overlayBox,
    );
    final overlaySize = overlayBox.size;
    var dx = bottomRight.dx - menuWidth;
    var dy = bottomRight.dy + ui(8);
    if (dx < ui(8)) {
      dx = ui(8);
    }
    if (dx + menuWidth > overlaySize.width - ui(8)) {
      dx = overlaySize.width - menuWidth - ui(8);
    }
    if (dy + menuHeight > overlaySize.height - ui(8)) {
      dy = overlaySize.height - menuHeight - ui(8);
    }

    final action = await showMenu<_UserMenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(dx, dy, dx + menuWidth, dy + menuHeight),
      color: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      constraints: BoxConstraints.tightFor(width: menuWidth),
      items: <PopupMenuEntry<_UserMenuAction>>[
        PopupMenuItem<_UserMenuAction>(
          padding: EdgeInsets.zero,
          enabled: false,
          child: DashboardScaleScope(
            data: scale,
            child: Builder(
              builder: (panelCtx) => _UserMenuPanel(
                width: menuWidth,
                province: state.user.province,
                onSelect: (value) => Navigator.of(panelCtx).pop(value),
              ),
            ),
          ),
        ),
      ],
    );

    if (action == null || !context.mounted) {
      return;
    }

    switch (action) {
      case _UserMenuAction.region:
        await _handleRegion(context);
        break;
      case _UserMenuAction.profile:
        onNavigate(RoutePaths.info);
        break;
      case _UserMenuAction.logout:
        await _handleLogout(context);
        break;
    }
  }

  Future<void> _handleRegion(BuildContext context) async {
    final provinces = await onLoadProvinces();
    if (!context.mounted) return;
    if (provinces.isEmpty) {
      _showToast(context, '加载省份失败，请稍后重试');
      return;
    }
    final selected = await showOptionsDialog(
      context: context,
      title: '选择地区',
      options: provinces,
      selected: state.user.province.isEmpty ? null : state.user.province,
    );
    if (selected == null || !context.mounted) return;
    final err = await onUpdateProvince(selected);
    if (!context.mounted) return;
    _showToast(context, err ?? '修改成功！');
  }

  Future<void> _handleLogout(BuildContext context) async {
    await onLogout();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        RoutePaths.login,
        (route) => false,
      );
    }
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
              child: AppText(
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
                      AppText('通知(${state.noticeItems.length})'),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await onMarkAllRead();
                        },
                        child: const AppText('批量已读'),
                      ),
                    ],
                  ),
                  const Divider(height: 1, color: Color(0x14050505)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: state.noticeItems.isEmpty
                        ? const Center(child: AppText('暂无通知'))
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
                                title: AppText(
                                  item.content,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                subtitle: AppText(
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
    AppToast.show(context, message);
  }
}

// ─────────────────────── 用户菜单（自定义弹层） ───────────────────────

enum _UserMenuAction { region, profile, logout }

class _UserMenuPanel extends StatelessWidget {
  const _UserMenuPanel({
    required this.width,
    required this.province,
    required this.onSelect,
  });

  final double width;
  final String province;
  final ValueChanged<_UserMenuAction> onSelect;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final regionText = province.trim().isEmpty ? '未设置' : province.trim();
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(12)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x1F000000),
            blurRadius: ui(24),
            offset: Offset(0, ui(8)),
          ),
          BoxShadow(
            color: const Color(0x12000000),
            blurRadius: ui(4),
            offset: Offset(0, ui(2)),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _UserMenuRegionRow(
            province: regionText,
            onTap: () => onSelect(_UserMenuAction.region),
          ),
          _UserMenuDivider(),
          _UserMenuRow(
            icon: Icons.person_outline_rounded,
            label: '资料修改',
            onTap: () => onSelect(_UserMenuAction.profile),
          ),
          _UserMenuDivider(),
          _UserMenuRow(
            icon: Icons.logout_rounded,
            label: '退出登录',
            danger: true,
            onTap: () => onSelect(_UserMenuAction.logout),
          ),
        ],
      ),
    );
  }
}

class _UserMenuDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: ui(12)),
      child: const Divider(height: 1, thickness: 1, color: Color(0xFFF3F2F3)),
    );
  }
}

class _UserMenuRegionRow extends StatelessWidget {
  const _UserMenuRegionRow({required this.province, required this.onTap});

  final String province;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: ui(14), vertical: ui(12)),
        child: Row(
          children: [
            Container(
              width: ui(28),
              height: ui(28),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F0FF),
                borderRadius: BorderRadius.circular(ui(8)),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.location_on_rounded,
                size: ui(16),
                color: const Color(0xFF8741FF),
              ),
            ),
            SizedBox(width: ui(10)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppText(
                    '所在地区',
                    style: TextStyle(
                      fontSize: ui(14),
                      color: const Color(0xFF0B081A),
                      fontFamily: 'PingFang SC',
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: ui(2)),
                  AppText(
                    province,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: ui(12),
                      color: const Color(0xFF8741FF),
                      fontFamily: 'PingFang SC',
                      fontWeight: FontWeight.w400,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: ui(18),
              color: const Color(0xFFB6B5BB),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserMenuRow extends StatelessWidget {
  const _UserMenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final color = danger ? const Color(0xFFFF323C) : const Color(0xFF0B081A);
    final iconBg = danger ? const Color(0xFFFFEEF0) : const Color(0xFFF4F0FF);
    final iconColor = danger
        ? const Color(0xFFFF323C)
        : const Color(0xFF8741FF);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: ui(14), vertical: ui(10)),
        child: Row(
          children: [
            Container(
              width: ui(28),
              height: ui(28),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(ui(8)),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: ui(16), color: iconColor),
            ),
            SizedBox(width: ui(10)),
            AppText(
              label,
              style: TextStyle(
                fontSize: ui(14),
                color: color,
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
