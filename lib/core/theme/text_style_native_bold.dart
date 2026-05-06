import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 在 iOS / Android 等原生端通过同色阴影做"伪加粗"，
/// 模拟浏览器对未注册字重做的 synthetic bold，让 Skia 渲染的中文
/// 在 iPad 等设备上视觉上能与 Web 对齐。
///
/// 使用场景：当某段文字按设计稿应该使用 PingFang SC Medium / Regular
/// 等字重，但在 iPad 上看起来比浏览器中明显细一档时，对该 TextStyle
/// 调一次 [TextStyleNativeBold.nativeBolden] 即可。
///
/// - Web 端 ([kIsWeb] = true) 不做任何处理（浏览器自身已经合成加粗）。
/// - 原生端会保留原 TextStyle 的所有属性（包括 fontWeight 与字体），
///   只在 [shadows] 数组里追加一道偏移极小的同色阴影；阴影颜色取自
///   `style.color`（缺省回退到黑色），偏移默认 0.4 逻辑像素。
extension TextStyleNativeBold on TextStyle {
  TextStyle nativeBolden({double offset = 0.4}) {
    if (kIsWeb) return this;
    final baseColor = color ?? const Color(0xFF000000);
    final injected = Shadow(color: baseColor, offset: Offset(offset, 0));
    final next = <Shadow>[
      ...?shadows,
      injected,
    ];
    return copyWith(shadows: next);
  }
}
