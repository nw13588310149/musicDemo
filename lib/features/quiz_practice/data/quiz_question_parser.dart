import 'quiz_html.dart';

/// 供 [compute] 预热 isolate，避免首次进入做题页时才冷启动 worker。
List<Map<String, dynamic>> warmupQuizQuestionParser(void _) =>
    const <Map<String, dynamic>>[];

/// 单题解析入口，供懒加载 store 在 isolate 中按需调用。
Map<String, dynamic> parseQuizQuestionItem(dynamic item) {
  if (item is! Map) return const <String, dynamic>{};
  final list = parseQuizQuestionsPayload(<dynamic>[item]);
  if (list.isEmpty) return const <String, dynamic>{};
  return list.first;
}

/// 供 [compute] 在后台 isolate 解析题目列表，避免 HTML strip 阻塞 UI 线程。
List<Map<String, dynamic>> parseQuizQuestionsPayload(dynamic data) {
  if (data is! List) return const <Map<String, dynamic>>[];

  final list = <Map<String, dynamic>>[];
  for (final item in data) {
    if (item is! Map) continue;
    final question = item['question'];
    if (question is! Map) continue;

    final id = _toInt(item['id']);
    if (id == null) continue;

    final questionHtml = quizHtmlForcePingFangSc(
      _asString(question['question']),
    );
    final options = <String>[
      quizHtmlForcePingFangSc(_asString(question['param1'])),
      quizHtmlForcePingFangSc(_asString(question['param2'])),
      quizHtmlForcePingFangSc(_asString(question['param3'])),
      quizHtmlForcePingFangSc(_asString(question['param4'])),
    ];
    final parseHtml = quizHtmlForcePingFangSc(_asString(question['parse']));

    list.add(<String, dynamic>{
      'itemId': id,
      'questionHtml': questionHtml,
      'options': options,
      'correctAnswer': _toInt(question['answer']) ?? 0,
      'parseHtml': parseHtml,
      'userAnswer': _toInt(item['answer']),
      'status': _toInt(item['status']) ?? 0,
      'questionStripped': stripHtmlToText(questionHtml),
      'parseStripped': stripHtmlToText(parseHtml),
      'optionsStripped': options.map(stripHtmlToText).toList(growable: false),
      'questionHasMedia': htmlHasMedia(questionHtml),
      'questionHasInlineRich': htmlHasInlineRich(questionHtml),
      'parseHasMedia': htmlHasMedia(parseHtml),
      'parseHasInlineRich': htmlHasInlineRich(parseHtml),
      'optionsHasMedia': options.map(htmlHasMedia).toList(growable: false),
      'optionsHasInlineRich': options
          .map(htmlHasInlineRich)
          .toList(growable: false),
    });
  }
  return list;
}

String _asString(dynamic value) {
  if (value == null) return '';
  return value.toString();
}

int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}
