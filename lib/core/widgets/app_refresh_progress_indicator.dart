import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Material 下拉刷新指示器默认外框尺寸（原白底圆盘直径）。
const double kAppRefreshIndicatorSize = 41.0;

/// 无白底圆盘、进度环铺满 [kAppRefreshIndicatorSize] 的刷新指示器。
///
/// 相对 [RefreshProgressIndicator] 默认样式：去掉 [Material] 底色与内外边距，
/// 让紫色旋转环占满原先白底圆的 41×41 区域。
class AppRefreshProgressIndicator extends RefreshProgressIndicator {
  const AppRefreshProgressIndicator({
    super.key,
    super.value,
    Color? color,
    super.valueColor,
    double? strokeWidth,
    super.semanticsLabel,
    super.semanticsValue,
  }) : super(
          backgroundColor: Colors.transparent,
          elevation: 0,
          indicatorMargin: EdgeInsets.zero,
          indicatorPadding: EdgeInsets.zero,
          color: color ?? AppTheme.brandColor,
          strokeWidth: strokeWidth ?? RefreshProgressIndicator.defaultStrokeWidth,
        );
}
