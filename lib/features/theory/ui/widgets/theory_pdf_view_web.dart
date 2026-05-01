import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Web 端 PDF 显示：用 iframe 直接交给浏览器原生 PDF Viewer 渲染。
/// 这样可以避开浏览器对跨域 fetch 的 CORS 限制（PDF 静态 CDN 通常不会
/// 给前端 origin 配置 Access-Control-Allow-Origin），与 1.0 行为一致。
class TheoryPdfView extends StatefulWidget {
  const TheoryPdfView({
    super.key,
    required this.url,
    required this.authToken,
    this.interactive = true,
  });

  final String url;
  final String authToken;
  final bool interactive;

  @override
  State<TheoryPdfView> createState() => _TheoryPdfViewState();
}

class _TheoryPdfViewState extends State<TheoryPdfView> {
  static int _seq = 0;
  late String _viewType;
  web.HTMLIFrameElement? _iframe;

  @override
  void initState() {
    super.initState();
    _registerView();
  }

  @override
  void didUpdateWidget(covariant TheoryPdfView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // url 变化时重新注册一个新的 viewType，避免浏览器复用旧 iframe。
    if (oldWidget.url != widget.url) {
      setState(_registerView);
      return;
    }
    if (oldWidget.interactive != widget.interactive) {
      _applyInteractivity();
    }
  }

  void _registerView() {
    _viewType =
        'theory-pdf-iframe-${DateTime.now().millisecondsSinceEpoch}-${_seq++}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = widget.url
        ..allowFullscreen = true
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = '#FAFAFB';
      _iframe = iframe;
      _applyInteractivity();
      return iframe;
    });
  }

  void _applyInteractivity() {
    _iframe?.style.pointerEvents = widget.interactive ? 'auto' : 'none';
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
