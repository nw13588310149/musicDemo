import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 与首页 [HomePage] 对齐的全局 loading 环尺寸（逻辑像素）。
const double kAppLoadingIndicatorSize = 22;

/// 全局统一的 loading 环粗细。
const double kAppLoadingIndicatorStrokeWidth = 2;

/// 项目统一的旋转 loading：22×22、strokeWidth 2、品牌紫。
///
/// 通过 [color] / [size] 可覆盖颜色与尺寸（如按钮内白圈、深色背景白圈）。
/// 带 [value] 时用于 determinate 进度（上传、PDF 等），视觉规格保持一致。
class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({
    super.key,
    this.color,
    this.size = kAppLoadingIndicatorSize,
    this.strokeWidth = kAppLoadingIndicatorStrokeWidth,
    this.value,
  });

  final Color? color;
  final double size;
  final double strokeWidth;

  /// `null` 为 indeterminate；`0..1` 为 determinate 进度。
  final double? value;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppTheme.brandColor;
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        value: value,
        strokeWidth: strokeWidth,
        color: effectiveColor,
        backgroundColor:
            value != null ? effectiveColor.withValues(alpha: 0.12) : null,
      ),
    );
  }
}

/// 首页同款全屏 loading 蒙层（35% 白 + 居中 indicator）。
class AppLoadingOverlay extends StatelessWidget {
  const AppLoadingOverlay({
    super.key,
    this.color,
    this.scrimColor = const Color(0x59FFFFFF),
    this.ignorePointer = true,
  });

  final Color? color;
  final Color scrimColor;
  final bool ignorePointer;

  @override
  Widget build(BuildContext context) {
    final body = ColoredBox(
      color: scrimColor,
      child: Center(
        child: AppLoadingIndicator(color: color),
      ),
    );
    return ignorePointer ? IgnorePointer(child: body) : body;
  }
}
