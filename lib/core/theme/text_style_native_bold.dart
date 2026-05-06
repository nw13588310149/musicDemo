import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 在 iOS / Android 等原生端通过同色阴影做"伪加粗"，
/// 模拟浏览器对中等字重隐式应用的 synthetic bold / subpixel 加粗，
/// 让 Skia 渲染的中文在 iPad 等设备上视觉上能与 Web 对齐。
///
/// - Web 端 ([kIsWeb] = true) 直接返回原 style，浏览器自身处理。
/// - 原生端只对会"显得偏细"的字重生效：[FontWeight.w400] / [FontWeight.w500]。
///   w600 起的字重物理上已经是 Semibold，再叠阴影会过厚，所以默认跳过。
extension TextStyleNativeBold on TextStyle {
  TextStyle nativeBolden({double offset = 0.4}) {
    if (kIsWeb) return this;
    final w = fontWeight ?? FontWeight.w400;
    if (w.value > FontWeight.w500.value) return this;
    final baseColor = color ?? const Color(0xFF000000);
    final injected = Shadow(color: baseColor, offset: Offset(offset, 0));
    final next = <Shadow>[
      ...?shadows,
      injected,
    ];
    return copyWith(shadows: next);
  }
}

/// 判断一个 [TextStyle] 是否需要在原生端做 synthetic bold 修正：
/// • fontFamily 是 'PingFang SC' 系列
/// • fontWeight ≤ w500（w600+ 已经是 Semibold，无需修正）
bool needsNativeBolden(TextStyle? style) {
  if (kIsWeb || style == null) return false;
  final family = style.fontFamily;
  if (family == null || !family.contains('PingFang')) return false;
  final w = (style.fontWeight ?? FontWeight.w400).value;
  return w <= FontWeight.w500.value;
}
