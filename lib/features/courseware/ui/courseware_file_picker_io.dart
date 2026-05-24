import 'dart:io';

import 'package:file_picker/file_picker.dart';

import 'courseware_file_picker.dart';

/// 与谱例上传提示、内联预览支持的音频格式保持一致。
const _kAudioExtensions = ['mp3', 'wav', 'm4a', 'aac', 'flac', 'ogg'];

Future<List<CoursewarePickedFile>> pickCoursewareFilesImpl({
  required bool allowMultiple,
  CoursewarePickType type = CoursewarePickType.any,
}) async {
  // FilePicker 的 FileType.image / video / audio 在 iOS / Android 上会直接走系统的
  // 相册 / 音频选择器；在桌面（Win / macOS / Linux）上则只是过滤可选
  // 扩展名 —— 两端语义都更贴近"上传图片/视频/音频"的真实意图。
  // iOS 的 FileType.audio 会打开「资料库」而非文件管理器，谱例音频上传改走
  // UIDocumentPicker（FileType.custom + 扩展名过滤）。
  final (FileType platformType, List<String>? allowedExtensions) = switch (type) {
    CoursewarePickType.image => (FileType.image, null),
    CoursewarePickType.video => (FileType.video, null),
    CoursewarePickType.audio => Platform.isIOS
        ? (FileType.custom, _kAudioExtensions)
        : (FileType.audio, null),
    CoursewarePickType.any => (FileType.any, null),
  };
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: allowMultiple,
    type: platformType,
    allowedExtensions: allowedExtensions,
    withData: false,
  );
  final files = result?.files ?? const <PlatformFile>[];
  if (files.isEmpty) {
    return const <CoursewarePickedFile>[];
  }
  return files
      .where((f) => f.path != null && f.path!.isNotEmpty)
      .map(
        (f) => CoursewarePickedFile(name: f.name, path: f.path, size: f.size),
      )
      .toList();
}
