const _hideScrollbarStyle = '''
<style id="school-website-hide-scrollbar">
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
</style>
''';

/// 在官网 HTML 文档内注入隐藏滚动条样式，保留滚动能力。
String schoolWebsiteHtmlWithHiddenScrollbar(String html) {
  if (html.isEmpty) return html;

  final lower = html.toLowerCase();
  final headClose = lower.indexOf('</head>');
  if (headClose >= 0) {
    return '${html.substring(0, headClose)}$_hideScrollbarStyle${html.substring(headClose)}';
  }

  final bodyOpen = lower.indexOf('<body');
  if (bodyOpen >= 0) {
    return '$_hideScrollbarStyle$html';
  }

  return '$_hideScrollbarStyle$html';
}
