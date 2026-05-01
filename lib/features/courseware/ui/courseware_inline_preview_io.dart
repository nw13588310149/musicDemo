import 'package:flutter/material.dart';

/// Non-web 平台占位实现：原生平台暂未集成嵌入式预览，调用方按需自己
/// 走外部跳转或下载。这里返回一个简单提示。
class CoursewareInlinePreview extends StatelessWidget {
  const CoursewareInlinePreview({
    super.key,
    required this.url,
    this.placeholder,
  });

  final String url;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    return placeholder ??
        const Center(
          child: Text(
            '当前平台暂不支持内嵌预览，请在浏览器中查看。',
            style: TextStyle(color: Color(0xFF8F86A8)),
          ),
        );
  }
}
