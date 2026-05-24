import 'package:flutter/material.dart';

import '../constants/app_assets.dart';
import '../../features/shell/ui/shell_layout.dart';
import 'cloud_folder_more_menu_button.dart';

/// 文件夹卡片底图（yp8 有内容 / yp9 空）与右上角 ⋯ 热区比例定位。
///
/// 菜单位置按卡片尺寸百分比计算，避免网格列数变化（5 列 → 4 列）后
/// 固定像素定位导致 ⋯ 溢出文件夹区域。
class CloudFolderCardArtwork extends StatelessWidget {
  const CloudFolderCardArtwork({
    super.key,
    required this.hasContent,
    this.isCreateShortcut = false,
    this.menuTriggerKey,
    this.onMenuTap,
  });

  final bool hasContent;
  final bool isCreateShortcut;
  final GlobalKey? menuTriggerKey;
  final VoidCallback? onMenuTap;

  /// ⋯ 相对文件夹底图的位置（对齐 yp8/yp9 上印刷的三点）。
  static const double menuTopFactor = 0.30;
  static const double menuRightFactor = 0.065;

  static String backgroundAsset({
    required bool hasContent,
    bool isCreateShortcut = false,
  }) {
    if (isCreateShortcut || !hasContent) {
      return AppAssets.cloudFolderEmptyBg;
    }
    return AppAssets.cloudFolderFilledBg;
  }

  /// ⋯ 在比例定位基础上的微调（逻辑像素，经 ui 缩放）。
  static const double menuTopOffset = -5;
  static const double menuRightOffset = -10;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final asset = backgroundAsset(
      hasContent: hasContent,
      isCreateShortcut: isCreateShortcut,
    );
    final showMenu =
        !isCreateShortcut && onMenuTap != null && menuTriggerKey != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              asset,
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              fit: BoxFit.fill,
              gaplessPlayback: true,
            ),
            if (showMenu)
              Positioned(
                top: constraints.maxHeight * menuTopFactor + ui(menuTopOffset),
                right:
                    constraints.maxWidth * menuRightFactor + ui(menuRightOffset),
                child: CloudFolderMoreMenuButton(
                  key: menuTriggerKey,
                  onTap: onMenuTap!,
                  iconOpacity: 0,
                ),
              ),
          ],
        );
      },
    );
  }
}
