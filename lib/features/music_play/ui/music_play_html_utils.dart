/// 后端 `longText1` 富文本常带内联 `font-family`，会盖掉 Flutter 侧
/// [HtmlWidget] 的 `textStyle`。去掉字体声明后保留颜色/字号/粗细等样式。
String musicPlayHtmlForcePingFangSc(String html) {
  if (html.isEmpty) return html;

  var result = html.replaceAll(
    RegExp(
      r'font-family\s*:\s*[^;}>]+(?:\s*!important)?\s*;?',
      caseSensitive: false,
    ),
    '',
  );

  result = result.replaceAllMapped(
    RegExp(
      r'(\s)face\s*=\s*(?:"[^"]*"|[^\s>]+)',
      caseSensitive: false,
    ),
    (match) => match.group(1)!,
  );

  result = result.replaceAllMapped(
    RegExp(r'\sstyle\s*=\s*"\s*"\s*', caseSensitive: false),
    (_) => ' ',
  );
  result = result.replaceAllMapped(
    RegExp(r"\sstyle\s*=\s*'\s*'\s*", caseSensitive: false),
    (_) => ' ',
  );

  return result;
}

const Set<String> _musicPlayHtmlTextTags = <String>{
  'p',
  'span',
  'div',
  'li',
  'td',
  'th',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'strong',
  'em',
  'b',
  'i',
  'u',
  'a',
  'font',
  'label',
  'blockquote',
};

Map<String, String>? musicPlayHtmlCustomStyles(dynamic element) {
  final tag = element.localName?.toLowerCase();
  if (tag == null || !_musicPlayHtmlTextTags.contains(tag)) {
    return null;
  }
  final styles = <String, String>{'font-family': 'PingFang SC'};
  if (tag == 'p') {
    styles['margin'] = '0';
    styles['padding'] = '0';
  }
  return styles;
}
