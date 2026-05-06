import 'package:flutter/material.dart';

import '../theme/text_style_native_bold.dart';

/// [Text] 的透明替代品，用法与参数完全一致。
///
/// 区别：当 [style] 的 fontFamily 是 PingFang SC 系列、且 fontWeight ≤ w500
/// 时，自动在原生端（iOS / Android）追加一道同色阴影，模拟浏览器对中等
/// 字重的隐式 synthetic bold，缓解 iPad 上看起来"细一档"的问题。
///
/// Web 端 ([kIsWeb] = true) 不做任何处理，与原始 [Text] 行为完全一致。
///
/// 使用方式：把项目里 `Text(...)` 直接换成 `AppText(...)`，其它什么都不用改。
class AppText extends StatelessWidget {
  const AppText(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  final String data;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = needsNativeBolden(style) ? style!.nativeBolden() : style;
    return Text(
      data,
      style: effectiveStyle,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}
