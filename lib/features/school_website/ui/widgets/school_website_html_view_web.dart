import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'school_website_html_utils.dart';

/// Web：用 `<iframe srcdoc>` 内联渲染完整 HTML 文档。srcdoc 内的 CSS /
/// JS（轮播脚本）作为独立文档执行，样式与脚本都能完整生效。
class SchoolWebsiteHtmlView extends StatefulWidget {
  const SchoolWebsiteHtmlView({super.key, required this.html});

  final String html;

  @override
  State<SchoolWebsiteHtmlView> createState() => _SchoolWebsiteHtmlViewState();
}

class _SchoolWebsiteHtmlViewState extends State<SchoolWebsiteHtmlView> {
  static int _seq = 0;
  late String _viewType;

  @override
  void initState() {
    super.initState();
    _registerView();
  }

  @override
  void didUpdateWidget(covariant SchoolWebsiteHtmlView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) {
      setState(_registerView);
    }
  }

  void _registerView() {
    _viewType =
        'school-website-iframe-${DateTime.now().millisecondsSinceEpoch}-${_seq++}';
    final html = schoolWebsiteHtmlWithHiddenScrollbar(widget.html);
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..allowFullscreen = true
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = '#F7F7FB';
      // `srcdoc` 在 package:web 里是 JSAny 类型，用反射属性 setAttribute
      // 写入字符串最干净（srcdoc 是可反射 attribute）。
      iframe.setAttribute('srcdoc', html);
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
