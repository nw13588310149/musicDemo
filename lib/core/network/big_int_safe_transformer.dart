import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

/// Dio Transformer，在 JSON 解码前把 16+ 位整数替换成 JSON 字符串。
///
/// ### 背景
/// Web 端 Dart 使用 JavaScript `Number`（IEEE-754 双精度浮点），能精确表示的
/// 最大整数为 2^53 ≈ 9 × 10¹⁵（15~16 位）。后端雪花 ID（Snowflake）为
/// 19 位，直接交给 `jsonDecode` 解析后末几位会被截断：
///   `1801911384317390848` → `1801911384317390850`（丢 2）
///
/// ### 修复方案
/// 在 `jsonDecode` 之前，把 JSON 文本中作为 **值** 出现的 16+ 位整数
/// 用双引号包裹，使其在解码后保持为 `String` 而非精度受损的 `double`。
///
/// 正则只匹配"值位置"（冒号或左方括号/逗号之后），不会误改字段名或
/// 字符串内容中的数字序列。
class BigIntSafeTransformer implements Transformer {
  const BigIntSafeTransformer();

  /// 匹配 JSON 值位置的 16+ 位纯十进制整数：
  ///   - `([:\[,]\s*)` — 值上下文：对象的值（`:`）或数组元素（`[` / `,`）
  ///   - `(-?\d{16,})` — 可选负号 + 至少 16 位数字
  ///   - `(?=\s*[,\}\]])` — 后面紧跟值终止符（确认是独立值，非字段名）
  static final _bigIntRe = RegExp(
    r'([:\[,]\s*)(-?\d{16,})(?=\s*[,\}\]])',
  );

  /// 将 JSON 文本中的大整数包裹为字符串，再走标准 `jsonDecode`。
  static dynamic _safeDecode(String raw) {
    if (raw.isEmpty) return null;
    final patched = raw.replaceAllMapped(
      _bigIntRe,
      (m) => '${m.group(1)}"${m.group(2)}"',
    );
    return jsonDecode(patched);
  }

  // ── Transformer interface ──────────────────────────────────────────────────

  @override
  Future<String> transformRequest(RequestOptions options) async {
    final data = options.data;
    if (data == null) return '';
    if (data is String) return data;
    if (data is FormData) return data.toString();
    return jsonEncode(data);
  }

  @override
  Future<dynamic> transformResponse(
    RequestOptions options,
    ResponseBody responseBody,
  ) async {
    final responseType = options.responseType;

    // 流式响应：原样返回。
    if (responseType == ResponseType.stream) {
      return responseBody;
    }

    // 收集所有字节。
    final bytes = <int>[];
    await for (final chunk in responseBody.stream) {
      bytes.addAll(chunk);
    }

    // 二进制响应：返回 Uint8List。
    if (responseType == ResponseType.bytes) {
      return bytes;
    }

    // 文本 / JSON 响应：先解码为 String。
    final rawStr = utf8.decode(bytes, allowMalformed: true);

    if (responseType == ResponseType.plain) {
      return rawStr;
    }

    // JSON（默认）：替换大整数后再 decode。
    if (rawStr.trim().isEmpty) return null;
    try {
      return _safeDecode(rawStr);
    } catch (_) {
      // 解析失败时原样返回字符串，让上层 _toApiResponse 兜底。
      return rawStr;
    }
  }
}
