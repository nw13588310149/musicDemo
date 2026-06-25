const _injectedStyles = '''
<style id="school-website-app-overrides">
html, body {
  -ms-overflow-style: none;
  scrollbar-width: none;
}
html::-webkit-scrollbar,
body::-webkit-scrollbar {
  display: none;
  width: 0;
  height: 0;
}
.hero-carousel-nav {
  display: none !important;
}
</style>
''';

/// 在官网 HTML 文档内注入 App 端样式覆盖：隐藏滚动条、隐藏轮播左右箭头。
String schoolWebsiteHtmlWithHiddenScrollbar(String html) {
  if (html.isEmpty) return html;

  final lower = html.toLowerCase();
  final headClose = lower.indexOf('</head>');
  if (headClose >= 0) {
    return '${html.substring(0, headClose)}$_injectedStyles${html.substring(headClose)}';
  }

  final bodyOpen = lower.indexOf('<body');
  if (bodyOpen >= 0) {
    return '$_injectedStyles$html';
  }

  return '$_injectedStyles$html';
}
