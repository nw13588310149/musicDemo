// Web-only implementation (dart:html).
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'courseware_file_picker.dart';

Future<List<CoursewarePickedFile>> pickCoursewareFilesImpl({
  required bool allowMultiple,
}) {
  final input = html.FileUploadInputElement()
    ..multiple = allowMultiple
    ..accept = '*/*'
    ..style.display = 'none';

  // 部分浏览器要求 input 在 DOM 中才能触发文件选择 / FileReader 才能稳定工作。
  html.document.body?.append(input);

  final completer = Completer<List<CoursewarePickedFile>>();

  void cleanup() {
    try {
      input.remove();
    } catch (_) {}
  }

  void completeWith(List<CoursewarePickedFile> files) {
    if (!completer.isCompleted) {
      completer.complete(files);
    }
    cleanup();
  }

  input.onChange.listen((_) async {
    final fileList = input.files;
    if (fileList == null || fileList.isEmpty) {
      completeWith(const <CoursewarePickedFile>[]);
      return;
    }

    final result = <CoursewarePickedFile>[];
    for (final file in fileList) {
      final bytes = await _readFileBytes(file);
      if (bytes == null || bytes.isEmpty) {
        continue;
      }
      result.add(CoursewarePickedFile(name: file.name, bytes: bytes));
    }
    completeWith(result);
  });

  // 取消选择时（点击 cancel）大部分浏览器只触发 'cancel' 事件，
  // 不会触发 onChange — 这里也兜底一下。
  input.addEventListener('cancel', (_) {
    completeWith(const <CoursewarePickedFile>[]);
  });

  // 必须由用户手势同步触发。
  input.click();

  return completer.future;
}

Future<Uint8List?> _readFileBytes(html.File file) {
  final completer = Completer<Uint8List?>();
  final reader = html.FileReader();

  reader.onLoadEnd.first.then((_) {
    final data = reader.result;
    if (data == null) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    // dart:html 在不同浏览器里 result 的具体类型可能是 ByteBuffer / TypedData / List<int>。
    // 全部尝试一遍，最大限度拿到 Uint8List。
    if (data is ByteBuffer) {
      if (!completer.isCompleted) completer.complete(data.asUint8List());
      return;
    }
    if (data is TypedData) {
      if (!completer.isCompleted) {
        completer.complete(
          Uint8List.view(
            data.buffer,
            data.offsetInBytes,
            data.lengthInBytes,
          ),
        );
      }
      return;
    }
    if (data is List<int>) {
      if (!completer.isCompleted) completer.complete(Uint8List.fromList(data));
      return;
    }
    if (!completer.isCompleted) completer.complete(null);
  });

  reader.onError.first.then((_) {
    if (!completer.isCompleted) completer.complete(null);
  });

  reader.readAsArrayBuffer(file);
  return completer.future;
}
